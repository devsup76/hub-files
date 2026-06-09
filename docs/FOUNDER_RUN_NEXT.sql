-- =============================================================================
-- WOAHH — FOUNDER: run these UNRUN migrations IN ORDER in the Supabase SQL editor
-- (project pmnyhbhtkcfoozkinieo). All additive + idempotent (safe to re-run).
-- 11 NEW migrations from the overnight run. The LAST one (remask_get_order_by_id)
-- MUST run last (it re-masks get_order_by_id after the location column is added).
-- After ALL: regenerate src/integrations/supabase/types.ts; then deploy edge fns +
-- set Square OAuth secrets (see MORNING_REPORT_2026-06-10.md).
-- =============================================================================

-- ========== 20260609020000_square_payments ==========
-- =============================================================================
-- Square online card payments — second payment provider alongside Stripe.
-- =============================================================================
-- SANDBOX-FIRST. Adds the provider flag + the Square-side parallels of the
-- existing Stripe payment columns. STRICTLY ADDITIVE + idempotent:
--   * organizations.payment_provider DEFAULTS 'stripe' → every existing merchant
--     is byte-for-byte unaffected (the checkout + edge functions only take the
--     Square path when payment_provider = 'square').
--   * orders.square_payment_id / square_order_id parallel stripe_payment_intent_id.
--   * The orders.payment_status state machine + its CHECK constraint are REUSED
--     as-is — Square statuses (APPROVED/COMPLETED/CANCELED/FAILED) map onto the
--     existing values (authorized/paid/canceled/failed), so NO new states.
--
-- C1 dependency: like Stripe, square-payment charges orders.total_amount (read by
-- order id), so the C1 server-side order-total validation
-- (20260608020000_c1_server_side_order_total.sql) MUST be applied before real
-- cards. Sandbox testing is safe before then.
--
-- Token model (sandbox-first): the Square access token is a Supabase EDGE SECRET
-- (SQUARE_ACCESS_TOKEN, already set, sandbox) — a single sandbox merchant. The
-- full multi-tenant OAuth `square_connections` table (per-org access/refresh
-- token + 30-day refresh cron) from the integration plan is Phase-1-Connect and
-- is intentionally OUT OF SCOPE here.

-- 1. Provider flag on the org. DEFAULT 'stripe' so nothing existing changes.
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS payment_provider text NOT NULL DEFAULT 'stripe';

ALTER TABLE public.organizations DROP CONSTRAINT IF EXISTS organizations_payment_provider_check;
ALTER TABLE public.organizations ADD CONSTRAINT organizations_payment_provider_check
  CHECK (payment_provider IN ('stripe', 'square'));

-- 2. Square merchant identity + payment-readiness (mirror of charges_enabled).
--    square_location_id is optional — square-payment auto-discovers it via
--    ListLocations and caches it here. square_payment_ready gates whether the
--    storefront/edge fn will create a Square payment (set by an operator / a
--    future onboarding flow once the sandbox/live account is connected).
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS square_merchant_id text,
  ADD COLUMN IF NOT EXISTS square_location_id text,
  ADD COLUMN IF NOT EXISTS square_payment_ready boolean NOT NULL DEFAULT false;

-- 3. Per-order Square payment references (parallel to stripe_payment_intent_id).
--    payment_status + its CHECK are REUSED — no new column added there.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS square_payment_id text,
  ADD COLUMN IF NOT EXISTS square_order_id text;

CREATE INDEX IF NOT EXISTS orders_square_payment_id_idx
  ON public.orders (square_payment_id)
  WHERE square_payment_id IS NOT NULL;

-- ========== 20260609030000_storefront_template_cantina ==========
-- Widen the storefront template allow-list to include the 'cantina' bespoke-home
-- restaurant archetype (src/components/storefront/homes/registry.ts +
-- src/lib/storefrontTemplates.ts `cantina` preset). It was added to the client
-- `TEMPLATES` enum and registered as a blueprint, but was missed from the column
-- CHECK in 20260607010000_storefront_template_variants.sql — so any path that
-- persisted template='cantina' (e.g. a real merchant picking the Cantina preview
-- template and saving) would throw a check_violation. This migration closes that
-- gap. Purely additive: existing rows are unaffected, no data migration needed.
--
-- KEEP IN SYNC with src/lib/storefrontConfig.ts `TEMPLATES` and the renderer's
-- TEMPLATE_LAYOUT map. The client parser drops unknown templates; this makes the
-- DB the matching final authority. A parity test (storefrontConfig.test.ts)
-- asserts `TEMPLATES` ⊆ this CHECK array.
--
-- Idempotent + additive: DROP ... IF EXISTS then re-ADD the constraint with the
-- full widened allow-list (re-running just re-asserts the same constraint).

ALTER TABLE public.storefront_config
  DROP CONSTRAINT IF EXISTS storefront_config_template_check;

ALTER TABLE public.storefront_config
  ADD CONSTRAINT storefront_config_template_check
  CHECK (template IN (
    'classic', 'hero', 'grid', 'minimal', 'editorial', 'boutique', 'bold',
    'kerb', 'daily', 'maison', 'rush', 'cantina'
  ));

-- The validate_storefront_config() trigger does NOT constrain `template` (only
-- this column CHECK does), so its section/theme/hero validation is unaffected.
-- The CHECK above remains the single source of truth for the template allow-list.

-- ========== 20260609040000_respond_to_order_claim ==========
-- =============================================================================
-- BLK-1 + M-4 + L-2 — atomic claim-before-capture for order confirm/decline.
-- =============================================================================
-- THREAT (BLK-1): order-respond read the order status (line 113) then, much
-- later, wrote the new status UNCONDITIONALLY (`update(...).eq("id", order.id)`
-- with NO `.eq("status","awaiting_confirmation")`). At minute ~7 the per-minute
-- `auto_decline_stale_orders` cron fires `auto_decline` for the SAME order while
-- the owner clicks Confirm. Both invocations pass the line-113 read, both run
-- provider capture/cancel (CompletePayment vs CancelPayment / capture vs cancel),
-- and both write. Outcomes: a kitchen-REJECTED order gets CHARGED
-- (payment_status='paid' + status='declined', decline email already sent), or a
-- confirmed order's authorization is CANCELED (kitchen cooks, merchant never
-- paid). The same race exists owner-Confirm vs owner-Decline (two tabs) and the
-- cron racing ITSELF (M-4).
--
-- FIX: claim-before-capture. The status transition becomes a single conditional
-- statement (compare-and-swap on status='awaiting_confirmation'). ONLY the
-- invocation whose UPDATE actually flips the row (RETURNING yields 1 row)
-- proceeds to capture/cancel + email; a loser yields 0 rows and no-ops
-- idempotently — it NEVER touches the payment provider. This is the data-layer
-- guarantee that exactly ONE of {confirm, decline, auto_decline} ever captures
-- or cancels a given authorization.
--
-- M-4 (cron idempotency) is closed structurally by the SAME claim: even if the
-- read-only cron re-dispatches `auto_decline` for a still-awaiting_confirmation
-- row on the next minute (because a slow order-respond hasn't finished), the
-- second invocation's RPC claim returns 0 rows (the first invocation, or the
-- owner, already flipped it) → no second decline email, no second cancel. The
-- claim — not the cron — is the idempotency boundary, so the cron stays a simple
-- best-effort dispatcher.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: a new SECURITY DEFINER RPC (CREATE OR REPLACE)
-- granted to service_role only (the edge fn calls it with the service-role key);
-- the cron function is left functionally as-is (read-only dispatcher) but
-- restated here CREATE OR REPLACE for self-containment. No table, RLS, or column
-- changes. The Stripe path is unaffected — the claim flips `status` identically
-- for Stripe and Square; only the EDGE FN ordering changes (claim first, capture
-- second).

-- 1. Atomic claim. Returns the freshly-claimed order row (status already flipped)
--    to the SINGLE caller that won, or NO rows to every loser. The provider
--    capture/cancel + email run ONLY for a returned row.
--
--    p_action ∈ ('confirm','decline','auto_decline'). confirm → 'pending'
--    (+ confirmed_at); decline/auto_decline → 'declined' (+ declined_at +
--    denial_reason). denial_reason is set HERE (atomically with the flip) so the
--    winner's email reads a consistent row; the edge fn no longer writes status.
--    payment_status is intentionally NOT written here — the winner sets it from
--    the LIVE provider result (paid/canceled) in a follow-up patch.
CREATE OR REPLACE FUNCTION public.claim_order_for_response(
  p_order_id uuid,
  p_action text,
  p_reason text DEFAULT NULL
)
RETURNS SETOF public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.orders%ROWTYPE;
BEGIN
  IF p_action NOT IN ('confirm', 'decline', 'auto_decline') THEN
    RAISE EXCEPTION 'Invalid action %', p_action USING ERRCODE = 'check_violation';
  END IF;

  UPDATE public.orders
  SET
    status = CASE
      WHEN p_action = 'confirm' THEN 'pending'::public.order_status
      ELSE 'declined'::public.order_status
    END,
    confirmed_at = CASE WHEN p_action = 'confirm' THEN now() ELSE confirmed_at END,
    declined_at  = CASE WHEN p_action <> 'confirm' THEN now() ELSE declined_at END,
    denial_reason = CASE
      WHEN p_action <> 'confirm' THEN COALESCE(p_reason, denial_reason)
      ELSE denial_reason
    END
  WHERE id = p_order_id
    AND status = 'awaiting_confirmation'   -- <- the compare-and-swap guard
  RETURNING * INTO r;

  IF NOT FOUND THEN
    -- Someone else (the owner, another tab, or the cron) already transitioned
    -- this order. Return NO rows; the caller must NOT capture/cancel or email.
    RETURN;
  END IF;

  RETURN NEXT r;
END;
$$;

-- Edge fn authenticates with the service-role key; no anon/owner JWT ever calls
-- this directly (order-respond already enforces owner/staff/service auth before
-- invoking, and resolves which order/org the caller may act on).
GRANT EXECUTE ON FUNCTION public.claim_order_for_response(uuid, text, text) TO service_role;

-- 2. Cron stays a READ-ONLY dispatcher (restated for self-containment). It MUST
--    NOT flip status itself: order-respond's claim is the single status-flip
--    authority so that the provider CancelPayment + decline email run for the
--    same row that was flipped (do both, or neither). A slow order-respond can
--    cause the next minute to re-dispatch the same still-awaiting row — that is
--    now harmless: the second invocation's claim returns 0 rows and no-ops (M-4).
--    The per-org confirmation_timeout_minutes window is preserved verbatim.
CREATE OR REPLACE FUNCTION public.auto_decline_stale_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  r record;
  project_url text;
  service_key text;
BEGIN
  SELECT decrypted_secret INTO project_url FROM vault.decrypted_secrets WHERE name = 'project_url' LIMIT 1;
  SELECT decrypted_secret INTO service_key FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;
  IF project_url IS NULL OR service_key IS NULL THEN RETURN; END IF;

  FOR r IN
    SELECT o.id
    FROM public.orders o
    JOIN public.organizations org ON org.id = o.organization_id
    WHERE o.status = 'awaiting_confirmation'
      AND o.created_at < now() - (COALESCE((org.settings->'orders'->>'confirmation_timeout_minutes')::int, 7) || ' minutes')::interval
  LOOP
    PERFORM net.http_post(
      url := project_url || '/functions/v1/order-respond',
      body := jsonb_build_object('order_id', r.id, 'action', 'auto_decline'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      )
    );
  END LOOP;
END;
$$;

-- ========== 20260609050000_guard_org_payment_columns ==========
-- =============================================================================
-- H-6 — block owner self-set of payment-connection columns on organizations.
-- =============================================================================
-- THREAT: the RLS policy "Owners update their org" (20260418045819) is
-- `FOR UPDATE USING (owner_id = auth.uid())` with NO WITH CHECK. Postgres then
-- reuses the USING expression as the WITH CHECK, which only re-asserts ownership
-- — it does NOT restrict WHICH columns the owner may change. So an owner can
-- `UPDATE organizations SET payment_provider='square', square_payment_ready=true,
-- square_merchant_id='...', square_location_id='...', charges_enabled=true,
-- payouts_enabled=true, stripe_account_id='...'` straight over the REST API.
-- Combined with BLK-2 (single global SQUARE_ACCESS_TOKEN), a self-activated
-- square_payment_ready routes that merchant's card charges into the ONE shared
-- Square account; or flipping payment_provider with no readiness breaks their
-- own checkout. These columns are meant to be operator/server-owned (set by the
-- onboarding / connect edge functions via the service role, and by Stripe/Square
-- webhooks), never owner-settable.
--
-- FIX: a BEFORE UPDATE trigger (mirrors guard_subdomain_slug — chosen over a
-- policy WITH CHECK so it validates EVERY write path with zero frontend change).
-- For an UNTRUSTED caller (an owner via RLS — `auth.uid()` is non-null), it
-- silently FORCES each guarded column back to its OLD value, so the rest of the
-- owner's legitimate UPDATE (name, settings, branding, hours, ...) still
-- succeeds. A TRUSTED caller — service_role / SECURITY DEFINER, where
-- `auth.uid()` is NULL — passes through unchanged, so the onboarding/connect
-- edge functions and webhooks can still set these. This is the SAME
-- auth.uid()-null discriminator the masking RPCs rely on (edge fns use the
-- service client; owners carry a user JWT).
--
-- We REVERT (NEW.col := OLD.col) rather than RAISE so a benign owner UPDATE that
-- happens to re-send an unchanged value isn't rejected, and an attempted change
-- is a no-op rather than a hard error that could mask the rest of the form.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: only constrains UPDATEs; existing rows are
-- untouched; CREATE OR REPLACE + DROP TRIGGER IF EXISTS. No column/RLS/table
-- changes. NOTE: this is a security-boundary change — STAGE FOR FOUNDER REVIEW
-- before applying (it intentionally makes payment columns owner-immutable).

-- Not SECURITY DEFINER (mirrors guard_subdomain_slug): a trigger function runs in
-- the modifying statement's context, and auth.uid() reads the request JWT claim
-- the same way regardless. Keeping it INVOKER-context avoids a definer-owned
-- trigger subtly masking the caller for any future current_setting()-based check.
CREATE OR REPLACE FUNCTION public.guard_org_payment_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  -- Trusted server path: SECURITY DEFINER / service_role writes have no end-user
  -- JWT, so auth.uid() is NULL. Let those through (onboarding/connect edge fns,
  -- Stripe/Square webhooks set these columns legitimately).
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Untrusted owner path (owner_id = auth.uid() RLS write): pin every
  -- payment-connection column to its existing value. The rest of the UPDATE
  -- proceeds normally.
  NEW.payment_provider     := OLD.payment_provider;
  NEW.square_payment_ready := OLD.square_payment_ready;
  NEW.square_merchant_id   := OLD.square_merchant_id;
  NEW.square_location_id   := OLD.square_location_id;
  NEW.charges_enabled      := OLD.charges_enabled;
  NEW.payouts_enabled      := OLD.payouts_enabled;
  NEW.stripe_account_id    := OLD.stripe_account_id;

  RETURN NEW;
END;
$$;

-- Fires only on UPDATE (INSERT of a fresh org sets defaults via the schema /
-- handle_new_user_org and must not be blocked). Trigger name sorts after the
-- subdomain guard; ordering vs other BEFORE triggers is irrelevant — this one
-- only reads/writes the payment columns of NEW.
DROP TRIGGER IF EXISTS trg_guard_org_payment_columns ON public.organizations;
CREATE TRIGGER trg_guard_org_payment_columns
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.guard_org_payment_columns();

-- ========== 20260609060000_rpc_mask_square_and_counters ==========
-- =============================================================================
-- H-5 — mask Square merchant identity + financial counters in the org/order RPCs.
-- =============================================================================
-- THREAT: three SECURITY DEFINER read RPCs return the FULL row of a wide table
-- (`RETURNS public.organizations` / `SETOF public.orders`) and rely on a
-- hardcoded DENYLIST (`r.col := NULL`) to hide secrets. That is exposed-by-
-- default: every column added later (notably the Square columns from
-- 20260609020000 and the online-payments columns from 20260602130000) leaks
-- until someone remembers to add it to the denylist. Concretely:
--   * get_public_storefront (ANON, public slug) leaks square_merchant_id,
--     square_location_id, square_payment_ready, charges_enabled, payouts_enabled,
--     email_used_this_month, email_topup_credits, sms_topup_credits,
--     phone_otp_attempts → discloses the payment-processor identity + business
--     internals to the public internet.
--   * get_member_org (STAFF JWT) leaks the same Square identity to staff.
--   * get_order_by_id (ANON order tracker) leaks stripe_payment_intent_id,
--     square_payment_id, square_order_id.
--
-- FIX (this migration — immediate, additive/safe): EXTEND each denylist with the
-- missing :=NULL masks via CREATE OR REPLACE. The proper structural fix is an
-- ALLOWLIST projection shared by all three (IMP-1) — deferred.
--
-- WHAT STAYS VISIBLE (verified against src/ consumers, do NOT mask):
--   * get_public_storefront.payment_provider — read by
--     src/components/storefront/liveStorefrontData.ts to route the Square-vs-
--     Stripe card SDK on the public storefront. Not secret (it's just which
--     processor); masking it would break checkout. KEPT.
--   * get_public_storefront does NOT feed total_donations_cents / founding_merchant
--     to the public — those transparency fields come from the
--     `marketplace_organizations` ALLOWLIST view (Impact/Marketplace/Profile),
--     so masking them here is safe and we mask them too for defence in depth.
--   * get_member_org OWNER branch returns the full row unchanged — owners still
--     read charges_enabled (Operations.tsx) + email_used_this_month
--     (EmailCampaigns.tsx). Only the NON-owner (staff) branch is tightened.
--   * get_order_by_id keeps payment_status (the public tracker shows paid/unpaid)
--     and courier fields (already masking only courier_driver_phone).
--
-- STRICTLY ADDITIVE + IDEMPOTENT: CREATE OR REPLACE only; no table/RLS/grant
-- changes (grants restated for self-containment). Frontend tsc/vite stay green —
-- no src/ file reads the newly-masked columns off these RPCs (verified by grep).

-- ---------------------------------------------------------------------------
-- 1. get_public_storefront (anon) — keep payment_provider; null everything else
--    payment-/finance-/processor-identity. Re-states the existing denylist so
--    the function is self-contained.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_public_storefront(p_slug text)
RETURNS public.organizations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.organizations%ROWTYPE;
BEGIN
  SELECT * INTO r
  FROM public.organizations
  WHERE subdomain_slug = lower(p_slug)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Existing owner-PII / recovery / auth denylist (unchanged).
  r.owner_phone := NULL;
  r.owner_full_name := NULL;
  r.abn := NULL;
  r.business_address := NULL;
  r.stripe_account_id := NULL;
  r.phone_otp_hash := NULL;
  r.phone_otp_expires_at := NULL;
  r.security_questions := NULL;
  r.contact_email := NULL;

  -- H-5 ADDED: Square merchant identity + payment-processor internals. These are
  -- never read off the public storefront (payment_provider below is the only
  -- payment field the storefront needs, and it is intentionally LEFT INTACT).
  r.square_merchant_id := NULL;
  r.square_location_id := NULL;
  r.square_payment_ready := NULL;
  r.charges_enabled := NULL;
  r.payouts_enabled := NULL;

  -- H-5 ADDED: financial counters / business internals.
  r.email_used_this_month := NULL;
  r.email_topup_credits := NULL;
  r.sms_topup_credits := NULL;
  r.sms_used_this_month := NULL;
  r.phone_otp_attempts := NULL;
  r.total_donations_cents := NULL;  -- public transparency comes from the
                                    -- marketplace_organizations allowlist view,
                                    -- not this storefront RPC.
  r.founding_merchant := NULL;

  -- KEPT VISIBLE: r.payment_provider (routes the public card SDK — see header).

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_storefront(text) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. get_member_org (staff JWT) — owner branch unchanged (full row); tighten the
--    non-owner (staff) branch to also hide Square identity + payment internals.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_member_org()
RETURNS public.organizations
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_is_owner boolean := false;
  r public.organizations%ROWTYPE;
BEGIN
  -- Resolution order MUST match the latest existing definition
  -- (20260601090000_harden_auth_persona_boundaries): STAFF membership first,
  -- owner fallback second. A user who is BOTH staff of org A and owns org B
  -- (or owns a leftover phantom org per CLAUDE.md gotcha #1) must resolve to
  -- the STAFF org so the PII/payment mask below applies — flipping to
  -- owner-first would silently hand such a user the full unmasked owner row.
  SELECT organization_id INTO v_org_id
  FROM public.staff_accounts
  WHERE user_id = auth.uid() AND is_active = true
  LIMIT 1;

  IF v_org_id IS NULL THEN
    SELECT id INTO v_org_id FROM public.organizations WHERE owner_id = auth.uid() LIMIT 1;
    IF v_org_id IS NOT NULL THEN
      v_is_owner := true;
    END IF;
  END IF;

  IF v_org_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO r FROM public.organizations WHERE id = v_org_id;

  IF NOT v_is_owner THEN
    -- Existing owner-PII / financial mask for staff (unchanged).
    r.owner_phone := NULL;
    r.owner_full_name := NULL;
    r.abn := NULL;
    r.business_address := NULL;
    r.stripe_account_id := NULL;
    r.phone_otp_hash := NULL;
    r.phone_otp_expires_at := NULL;

    -- H-5 ADDED: staff must not read the merchant's Square identity / payment
    -- processor internals off the org row.
    r.square_merchant_id := NULL;
    r.square_location_id := NULL;
    -- payment_provider / square_payment_ready / charges_enabled stay so the staff
    -- dashboard can still tell which checkout is active; the SECRET identity
    -- (merchant/location id) is what's masked. phone_otp_attempts is owner-auth.
    r.phone_otp_attempts := NULL;

    -- H-5 ADDED: financial counters / billing internals are owner-only business
    -- data (the audit fix nulls "(+ financial counters) in all three denylists").
    -- Staff dashboards never read these off get_member_org (EmailCampaigns/usage
    -- are owner-tier surfaces); masking is safe and keeps the staff projection
    -- limited to operational fields.
    r.email_used_this_month := NULL;
    r.email_topup_credits := NULL;
    r.sms_used_this_month := NULL;
    r.sms_topup_credits := NULL;
    r.total_donations_cents := NULL;
  END IF;

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_member_org() TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. get_order_by_id (anon order tracker) — keep the existing courier mask; add
--    the provider payment-reference ids (not needed by the public tracker).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_order_by_id(p_id uuid)
RETURNS SETOF public.orders
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.orders%ROWTYPE;
  v_auth_uid uuid := auth.uid();
BEGIN
  SELECT * INTO r
  FROM public.orders
  WHERE receipt_token = p_id
  LIMIT 1;

  IF NOT FOUND AND v_auth_uid IS NOT NULL THEN
    SELECT * INTO r
    FROM public.orders o
    WHERE o.id = p_id
      AND (
        o.customer_id = public.customer_id_for_user(o.organization_id)
        OR EXISTS (
          SELECT 1
          FROM public.organizations org
          WHERE org.id = o.organization_id
            AND org.owner_id = v_auth_uid
        )
        OR public.is_staff_of_org(v_auth_uid, o.organization_id)
      )
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Existing mask.
  r.courier_driver_phone := NULL;

  -- H-5 ADDED: provider payment-reference ids — the public order tracker shows
  -- payment_status (paid/unpaid), never the raw PI/payment ids.
  r.stripe_payment_intent_id := NULL;
  r.square_payment_id := NULL;
  r.square_order_id := NULL;

  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_by_id(uuid) TO anon, authenticated;

-- ========== 20260610010000_square_connections ==========
-- =============================================================================
-- Square OAuth per-org connections — the ONE-AND-DONE multi-tenant Connect model.
-- =============================================================================
-- This is the proper structural fix for audit BLK-2 (the single global
-- SQUARE_ACCESS_TOKEN). Today square-payment reads ONE edge secret, so a second
-- square_payment_ready org would charge cards into the FIRST merchant's Square
-- account — fail-closed-guarded in code (square-payment/index.ts:181-229), but
-- only single-tenant. This migration introduces a per-ORG OAuth token store so
-- each merchant's payments route to THEIR OWN Square account, looked up by
-- order.organization_id. The single-tenant guard can then be retired (kept as
-- defence-in-depth) because there is no longer a shared token to misroute.
--
-- ORG-LEVEL, not per-staff/device: the row is keyed on org_id (PRIMARY KEY), set
-- only by the service-role onboarding edge function (which loads the org by
-- owner_id, exactly like stripe-connect-onboard) and the token-refresh cron.
-- Staff cannot create/alter it (no anon/authenticated write path at all).
--
-- SECRET HANDLING: access_token + refresh_token are OAuth bearer secrets. There
-- is therefore NO anon/authenticated SELECT on this table — under RLS with zero
-- policies the table is deny-by-default, so only the service role (edge fns +
-- cron) can read the tokens. The owner only ever needs a connected:true/false
-- summary, surfaced via the masked SECURITY DEFINER RPC
-- get_square_connection_status() below (mirrors the H-5 denylist pattern in
-- 20260609060000) which NEVER returns the tokens.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: CREATE TABLE IF NOT EXISTS / CREATE OR REPLACE;
-- no existing table/column/RLS/grant is modified. The founder runs this. Edge
-- functions deploy separately. NOTE: a security-boundary table — STAGE FOR
-- FOUNDER REVIEW (it stores payment-processor OAuth secrets).

-- 1. The per-org Square OAuth connection.
CREATE TABLE IF NOT EXISTS public.square_connections (
  org_id              uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  access_token        text NOT NULL,        -- OAuth bearer (Square access token; ~30-day expiry)
  refresh_token       text NOT NULL,        -- used to mint a new access_token before expiry
  expires_at          timestamptz NOT NULL, -- access_token expiry (refresh cron watches this)
  merchant_id         text NOT NULL,        -- Square merchant id (from ObtainToken)
  locations           jsonb NOT NULL DEFAULT '[]'::jsonb,  -- [{id,name,status,address}] from ListLocations
  default_location_id text,                 -- the merchant's chosen / first-ACTIVE location
  scopes              text,                 -- granted OAuth scopes (space-delimited)
  token_type          text NOT NULL DEFAULT 'bearer',
  connected_at        timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.square_connections IS
  'Per-org Square OAuth tokens (BLK-2 fix). SECRET: no anon/authenticated SELECT — service-role only. Owner reads status via get_square_connection_status().';

-- 2. RLS ON with NO policies = deny-by-default for anon/authenticated. The
--    service role bypasses RLS, so the onboarding/refresh edge fns + cron still
--    read/write freely; nothing else can touch the tokens. (Mirrors how secret
--    tables are protected elsewhere — there is intentionally no current_org_id()
--    SELECT policy, which would hand the tokens to the owner's JWT.)
ALTER TABLE public.square_connections ENABLE ROW LEVEL SECURITY;
-- (No CREATE POLICY: zero policies under RLS = no row is visible/writable to
-- anon or authenticated. Explicit and deliberate.)

-- 3. Touch updated_at on every write (the refresh cron + re-connect rely on it).
CREATE OR REPLACE FUNCTION public.touch_square_connection_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_square_connection ON public.square_connections;
CREATE TRIGGER trg_touch_square_connection
  BEFORE UPDATE ON public.square_connections
  FOR EACH ROW EXECUTE FUNCTION public.touch_square_connection_updated_at();

-- 4. Masked status RPC — the ONLY way the owner dashboard learns it's connected.
--    Returns a boolean + non-secret summary (merchant_id LAST 4 only, location
--    count, default location, expiry) — NEVER access_token / refresh_token /
--    the full merchant_id. SECURITY DEFINER so it can read the deny-by-default
--    table, but it is scoped to the CALLER'S OWN org (owner-only: resolves the
--    org by owner_id = auth.uid(), so staff / other orgs get nothing). Mirrors
--    the H-5 allow/deny philosophy: a thin, explicit projection of safe fields.
CREATE OR REPLACE FUNCTION public.get_square_connection_status()
RETURNS TABLE (
  connected           boolean,
  merchant_id_last4   text,
  default_location_id text,
  location_count      int,
  expires_at          timestamptz,
  connected_at        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  c        public.square_connections%ROWTYPE;
BEGIN
  -- Owner-only: resolve the caller's owned org. (Staff have no payment-config
  -- surface; matching get_member_org's owner branch keeps this owner-scoped.)
  SELECT id INTO v_org_id
  FROM public.organizations
  WHERE owner_id = auth.uid()
  LIMIT 1;

  IF v_org_id IS NULL THEN
    -- Not an owner (or no org) → report "not connected", reveal nothing.
    RETURN QUERY SELECT false, NULL::text, NULL::text, 0, NULL::timestamptz, NULL::timestamptz;
    RETURN;
  END IF;

  SELECT * INTO c FROM public.square_connections WHERE org_id = v_org_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::text, NULL::text, 0, NULL::timestamptz, NULL::timestamptz;
    RETURN;
  END IF;

  RETURN QUERY SELECT
    true,
    right(c.merchant_id, 4),
    c.default_location_id,
    COALESCE(jsonb_array_length(c.locations), 0),
    c.expires_at,
    c.connected_at;
END;
$$;

REVOKE ALL ON FUNCTION public.get_square_connection_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_square_connection_status() TO authenticated;

-- 5. Helper: the masked locations list for the Operations card (so the owner can
--    see / pick locations without the tokens). Owner-scoped, secret-free.
CREATE OR REPLACE FUNCTION public.get_square_locations()
RETURNS TABLE (
  location_id text,
  name        text,
  status      text,
  is_default  boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  c        public.square_connections%ROWTYPE;
  loc      jsonb;
BEGIN
  SELECT id INTO v_org_id
  FROM public.organizations
  WHERE owner_id = auth.uid()
  LIMIT 1;
  IF v_org_id IS NULL THEN RETURN; END IF;

  SELECT * INTO c FROM public.square_connections WHERE org_id = v_org_id;
  IF NOT FOUND THEN RETURN; END IF;

  FOR loc IN SELECT * FROM jsonb_array_elements(COALESCE(c.locations, '[]'::jsonb))
  LOOP
    RETURN QUERY SELECT
      loc->>'id',
      loc->>'name',
      loc->>'status',
      (loc->>'id') IS NOT DISTINCT FROM c.default_location_id;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.get_square_locations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_square_locations() TO authenticated;

-- 6. Owner-settable default location (multi-location). This is the ONE piece of
--    the connection an owner may change — but it must be a location that ALREADY
--    exists in the connection's locations jsonb (set by OAuth/ListLocations), so
--    the owner can never inject an arbitrary location id. SECURITY DEFINER +
--    owner-scoped; validates membership in locations before writing.
CREATE OR REPLACE FUNCTION public.set_square_default_location(p_location_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_valid  boolean;
BEGIN
  SELECT id INTO v_org_id
  FROM public.organizations
  WHERE owner_id = auth.uid()
  LIMIT 1;
  IF v_org_id IS NULL THEN RETURN false; END IF;

  -- The location must be one Square actually returned for this merchant.
  SELECT EXISTS (
    SELECT 1
    FROM public.square_connections sc,
         jsonb_array_elements(sc.locations) AS loc
    WHERE sc.org_id = v_org_id
      AND loc->>'id' = p_location_id
  ) INTO v_valid;
  IF NOT v_valid THEN RETURN false; END IF;

  UPDATE public.square_connections
     SET default_location_id = p_location_id
   WHERE org_id = v_org_id;

  -- Keep the denormalised org column in step (read by older code paths). This
  -- runs as the definer (service-role-equivalent), so the H-6 guard trigger —
  -- which pins payment columns for end-user JWT writes — does NOT block it:
  -- SECURITY DEFINER execution still carries the owner's auth.uid(), so to be
  -- safe we update square_location_id here in the SAME definer fn, which the
  -- guard does pin. To avoid that, we DO NOT touch organizations here; the
  -- edge fn (service role, auth.uid() NULL) owns organizations.square_location_id.
  -- The payment resolver reads square_connections.default_location_id first, so
  -- this is sufficient. (Left as a comment so the seam is explicit.)

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.set_square_default_location(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_square_default_location(text) TO authenticated;

-- ========== 20260610020000_square_token_refresh_cron ==========
-- =============================================================================
-- Square OAuth token refresh — daily pg_cron that renews tokens before expiry.
-- =============================================================================
-- Square OAuth access tokens expire ~30 days after issue; the refresh_token is
-- exchanged (ObtainToken grant_type=refresh_token) for a fresh access/refresh
-- pair. This cron finds connections whose access_token expires within 7 days and
-- POSTs each to the square-token-refresh edge fn (service-role), which does the
-- ObtainToken exchange and updates square_connections. square-payment ALSO
-- refreshes inline as a belt-and-braces fallback, so a missed cron run never
-- strands a merchant — but this keeps tokens fresh out-of-band.
--
-- Copies the EXACT vault + pg_net + cron pattern used by ~26 existing migrations
-- (see 20260529140000_marketplace_reminders_cron.sql): reads project_url +
-- service_role_key from vault.decrypted_secrets, loops rows, net.http_post per
-- row, schedules with the unschedule-if-exists guard.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: CREATE EXTENSION IF NOT EXISTS / CREATE OR
-- REPLACE / re-register the schedule cleanly. Founder runs it (after the
-- square-token-refresh edge fn is deployed + the vault secrets exist — the fn
-- returns early if vault secrets are missing, so an early run is a harmless no-op).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.refresh_expiring_square_tokens()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  proj_url text;
  svc_key  text;
  rec      record;
BEGIN
  SELECT decrypted_secret INTO proj_url FROM vault.decrypted_secrets WHERE name = 'project_url' LIMIT 1;
  SELECT decrypted_secret INTO svc_key  FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;
  IF proj_url IS NULL OR svc_key IS NULL THEN RETURN; END IF;

  FOR rec IN
    SELECT org_id
    FROM public.square_connections
    WHERE expires_at < now() + interval '7 days'
  LOOP
    PERFORM net.http_post(
      url     := proj_url || '/functions/v1/square-token-refresh',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || svc_key),
      body    := jsonb_build_object('org_id', rec.org_id)
    );
  END LOOP;
END;
$$;

-- Daily at 03:00 UTC. Re-register cleanly (unschedule the prior job if present).
DO $$ DECLARE jid bigint;
BEGIN
  SELECT jobid INTO jid FROM cron.job WHERE jobname = 'refresh-square-tokens';
  IF jid IS NOT NULL THEN PERFORM cron.unschedule(jid); END IF;
END $$;

SELECT cron.schedule(
  'refresh-square-tokens',
  '0 3 * * *',
  $cron$SELECT public.refresh_expiring_square_tokens()$cron$
);

-- ========== 20260610030000_orders_square_location ==========
-- =============================================================================
-- Multi-location — per-order Square location id.
-- =============================================================================
-- Today an order carries organization_id only; a multi-location merchant's
-- several Square locations all map to ONE org, so square-payment can only ever
-- charge to a single (arbitrarily-pinned-first) location. This adds an OPTIONAL
-- per-order location override. NULL (the default for single-location merchants,
-- i.e. every founding merchant today) falls through to
-- square_connections.default_location_id → first-ACTIVE — so behaviour is
-- byte-for-byte unchanged for single-location merchants.
--
-- The column is set by the POS / order-creation path for multi-location
-- merchants later; the resolver in square-payment uses:
--   order.square_location_id → square_connections.default_location_id
--   → first ACTIVE in square_connections.locations → ListLocations refresh.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: a single nullable column; no constraint, no
-- backfill, no RLS change. Founder runs it.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS square_location_id text;

COMMENT ON COLUMN public.orders.square_location_id IS
  'Optional per-order Square location override (multi-location). NULL = use the org default from square_connections.default_location_id.';

-- ========== 20260610040000_gmv_analytics_rpc ==========
-- =============================================================================
-- GMV analytics — server-side, org-scoped aggregate for the dashboard GMV widget.
-- =============================================================================
-- Founder: "we need to see how much GMV is being moved." This adds a read-only
-- aggregate RPC so the merchant dashboard can show GROSS MERCHANDISE VALUE moved
-- over a period WITHOUT pulling every order row to the client. Aggregating in
-- Postgres is the scale-correct choice: one round-trip, no per-row transfer, and
-- — crucially — it can NEVER leak across orgs because it filters on
-- current_org_id() (the same authority every orders RLS policy uses).
--
-- WHY AN RPC (not a client aggregate): the existing Analytics page already pulls
-- 90 days of orders client-side under RLS (safe but heavy, and it grows with
-- volume). For GMV we want paid/authorized splits, provider splits and a
-- per-location breakdown across the whole period — pushing that to SQL keeps the
-- payload to a handful of rows regardless of order count, and keeps the money
-- math on the server. RLS is respected: the function is SECURITY DEFINER but it
-- hard-scopes every query to current_org_id(), so a caller only ever sees their
-- OWN org's GMV. No cross-org path exists.
--
-- PROVIDER DERIVATION (per order, faithful to the payment edge fns): an order's
-- processor is derived from which reference id is populated, NOT from the org's
-- current payment_provider flag (which only says how NEW orders route today):
--   * square_payment_id  IS NOT NULL                      -> 'square'
--   * stripe_payment_intent_id IS NOT NULL                -> 'stripe'
--   * otherwise (paid/pay_in_person with no card ref)     -> 'venue'  (pay-at-venue:
--       dine-in / counter / cash / POS settled outside our online card rails)
-- This mirrors square-payment/index.ts (square_payment_id) and the Stripe path
-- (stripe_payment_intent_id), so historical orders bucket correctly even if the
-- merchant later switches providers.
--
-- GMV DEFINITION: sum of orders.total_amount (cents) for orders that represent
-- real merchandise movement — i.e. NOT declined and NOT a failed/canceled/refunded
-- payment. "paid" = payment_status IN ('paid','pay_in_person'); "authorized" =
-- payment_status = 'authorized' (card auth placed, capture pending owner-confirm).
-- 'unpaid' orders that are otherwise live (e.g. a pending dine-in not yet settled)
-- count toward GMV-moved but bucket as pay-at-venue/unsettled. We EXCLUDE
-- declined orders and refunded/failed/canceled payments from GMV so the number
-- reflects value actually transacted.
--
-- PER-ORDER LOCATION: orders.square_location_id (added in 20260610030000). NULL =
-- the org default / single-location (every founding merchant today) -> bucketed
-- as 'default'. Multi-location merchants get one row per location id.
--
-- STRICTLY ADDITIVE + IDEMPOTENT: CREATE OR REPLACE only; no table/column/RLS/
-- grant on existing objects is modified. Read-only (STABLE, no writes). Founder
-- runs it; nothing else depends on it being applied (the widget falls back to a
-- client aggregate path is NOT needed — but the frontend degrades gracefully if
-- the RPC is absent, see the widget's error handling).

-- ---------------------------------------------------------------------------
-- Supporting index: GMV queries scan orders by (org, created_at). The existing
-- idx_orders_org covers org; this partial-free composite makes the time-window
-- scan index-only-ish. IF NOT EXISTS = idempotent, additive.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_org_created_at
  ON public.orders (organization_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- get_gmv_analytics(p_days) — the GMV summary for the caller's org over the last
-- p_days days. Returns a SINGLE jsonb document (totals + splits + per-location)
-- so the client gets everything in one call. Org-scoped via current_org_id().
--
--   p_days: 1 | 7 | 30 | 90 (clamped to 1..366). Default 30.
--
-- Shape:
-- {
--   "currency": "AUD",
--   "window_days": 30,
--   "gmv_cents": 123456,            -- total GMV moved (paid+authorized+unsettled-live)
--   "order_count": 42,
--   "aov_cents": 2939,             -- gmv_cents / order_count (0 if no orders)
--   "by_status": {                -- settlement split (cents + count)
--       "paid":       { "cents": 90000, "count": 30 },
--       "authorized": { "cents": 20000, "count":  8 },
--       "unsettled":  { "cents": 13456, "count":  4 }   -- live but not yet paid/auth
--   },
--   "by_provider": [              -- card processor split, derived per order
--       { "provider": "square", "cents": 60000, "count": 20 },
--       { "provider": "stripe", "cents": 30000, "count": 10 },
--       { "provider": "venue",  "cents": 33456, "count": 12 }
--   ],
--   "by_location": [              -- multi-location breakdown ('default' = NULL loc)
--       { "location_id": "default", "cents": 100000, "count": 35 },
--       { "location_id": "L7H...",  "cents":  23456, "count":  7 }
--   ]
-- }
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_gmv_analytics(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid := public.current_org_id();
  v_days   integer := LEAST(GREATEST(COALESCE(p_days, 30), 1), 366);
  v_since  timestamptz := now() - make_interval(days => v_days);
  v_result jsonb;
BEGIN
  -- No org context (not a member/owner) -> empty, leak-free document.
  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object(
      'currency', 'AUD',
      'window_days', v_days,
      'gmv_cents', 0,
      'order_count', 0,
      'aov_cents', 0,
      'by_status',   jsonb_build_object(
                       'paid',       jsonb_build_object('cents', 0, 'count', 0),
                       'authorized', jsonb_build_object('cents', 0, 'count', 0),
                       'unsettled',  jsonb_build_object('cents', 0, 'count', 0)),
      'by_provider', '[]'::jsonb,
      'by_location', '[]'::jsonb
    );
  END IF;

  WITH gmv_orders AS (
    -- The GMV universe for THIS org in the window: real merchandise movement
    -- only. Exclude declined orders and refunded/failed/canceled payments.
    SELECT
      o.total_amount AS cents,
      -- Settlement bucket.
      CASE
        WHEN o.payment_status IN ('paid', 'pay_in_person') THEN 'paid'
        WHEN o.payment_status = 'authorized'               THEN 'authorized'
        ELSE 'unsettled'
      END AS settle,
      -- Provider bucket, derived from the populated reference id (faithful to the
      -- payment edge fns); pay-at-venue when no online card ref exists.
      CASE
        WHEN o.square_payment_id IS NOT NULL          THEN 'square'
        WHEN o.stripe_payment_intent_id IS NOT NULL   THEN 'stripe'
        ELSE 'venue'
      END AS provider,
      COALESCE(o.square_location_id, 'default') AS location_id
    FROM public.orders o
    WHERE o.organization_id = v_org_id
      AND o.created_at >= v_since
      AND o.status <> 'declined'
      AND COALESCE(o.payment_status, 'unpaid') NOT IN ('refunded', 'failed', 'canceled')
  ),
  totals AS (
    SELECT COALESCE(SUM(cents), 0)::bigint AS gmv_cents,
           COUNT(*)::bigint                AS order_count
    FROM gmv_orders
  ),
  by_status AS (
    SELECT settle,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY settle
  ),
  by_provider AS (
    SELECT provider,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY provider
  ),
  by_location AS (
    SELECT location_id,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY location_id
  )
  SELECT jsonb_build_object(
    'currency', 'AUD',
    'window_days', v_days,
    'gmv_cents', t.gmv_cents,
    'order_count', t.order_count,
    'aov_cents', CASE WHEN t.order_count > 0
                      THEN ROUND(t.gmv_cents::numeric / t.order_count)::bigint
                      ELSE 0 END,
    'by_status', jsonb_build_object(
      'paid', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'paid'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'paid'), 0)),
      'authorized', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'authorized'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'authorized'), 0)),
      'unsettled', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'unsettled'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'unsettled'), 0))
    ),
    'by_provider', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('provider', provider, 'cents', cents, 'count', count)
                       ORDER BY cents DESC)
      FROM by_provider
    ), '[]'::jsonb),
    'by_location', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('location_id', location_id, 'cents', cents, 'count', count)
                       ORDER BY cents DESC)
      FROM by_location
    ), '[]'::jsonb)
  )
  INTO v_result
  FROM totals t;

  RETURN v_result;
END;
$$;

-- Owner + staff of the org may read their own GMV. (current_org_id() already
-- resolves staff -> their org, so staff see only their org's aggregate. If you
-- want to restrict GMV to owners only later, add an owner check inside the fn;
-- the data is org-internal business intelligence, not PII/secrets.)
REVOKE ALL ON FUNCTION public.get_gmv_analytics(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_gmv_analytics(integer) TO authenticated;

COMMENT ON FUNCTION public.get_gmv_analytics(integer) IS
  'Read-only GMV aggregate for the caller''s org over the last N days (totals + paid/authorized/unsettled split + provider split + per-location). Org-scoped via current_org_id(); never leaks across orgs. Powers the dashboard GMV widget.';

-- ========== 20260610050000_order_refunds ==========
-- =============================================================================
-- Order refunds — full + partial, provider-agnostic, server-authoritative.
-- =============================================================================
-- Founder: "what is the refund policy if the customer needs to be refunded, how
-- will it work step by step?" This migration is the DATA-LAYER half of refunds
-- (the `refund-order` edge function is the provider half). Companion doc:
-- docs/REFUND_POLICY.md.
--
-- DESIGN — same trust model as the rest of the payment stack:
--   * The AMOUNT is server-authoritative. The edge fn never trusts a client
--     amount; it reads orders.total_amount (the C1-validated total) and the
--     already-refunded sum, and this RPC is the SINGLE writer that records a
--     refund + flips payment_status. A refund can NEVER exceed (captured total −
--     already-refunded) — enforced HERE in SQL, so even a buggy/forged edge call
--     can't over-refund (mirrors C1: the DB is the trust boundary, not the fn).
--   * IDEMPOTENT per (order, provider_refund_id): re-recording the same provider
--     refund (a retry / a webhook that races the fn) is a no-op that returns the
--     existing row, so an order is never double-decremented.
--   * Multiple PARTIAL refunds accumulate (Stripe + Square both allow refunding a
--     payment in parts until fully refunded). The order summary columns
--     (refund_amount_cents / refunded_at / refund_reason) track the running total;
--     the per-refund audit lives in public.payment_refunds.
--   * payment_status gains 'partially_refunded' (additive to the existing CHECK);
--     a full refund → 'refunded'. GMV nets out refunds (see the GMV RPC patch).
--
-- AUTHORIZED-NOT-CAPTURED orders are NOT refunded here — there is no captured
-- charge to reverse. The edge fn cancels the authorization instead (Stripe
-- paymentIntents.cancel / Square CancelPayment), which leaves payment_status
-- 'canceled' via the existing order-respond/webhook paths. This RPC refuses to
-- record a refund for a non-captured order (guard below), so the two paths can't
-- collide. See docs/REFUND_POLICY.md "Authorized-but-not-captured".
--
-- STRICTLY ADDITIVE + IDEMPOTENT: new columns (IF NOT EXISTS), a new table
-- (IF NOT EXISTS) + its RLS, a CHECK widened to ADD a value, CREATE OR REPLACE
-- functions. No existing column/row/grant is dropped or narrowed. The Stripe and
-- Square paths are symmetric — provider is recorded per-refund, never inferred
-- from the org's current flag. Founder runs this in the Supabase SQL editor; the
-- edge fn deploys separately. Safe to re-run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Order summary columns (running refund total + last reason/time).
--    The authoritative per-refund history is public.payment_refunds (below);
--    these denormalised columns let the Orders board show "Refunded $X" without
--    a join, and let the GMV RPC net refunds with a single column read.
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS refund_amount_cents integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refunded_at timestamptz,
  ADD COLUMN IF NOT EXISTS refund_reason text;

-- refund_amount_cents is a running total of all COMPLETED/PENDING refunds for the
-- order; it can never be negative and never exceed total_amount (the RPC enforces
-- the upper bound; this CHECK is a backstop).
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_refund_amount_nonneg_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_refund_amount_nonneg_check
  CHECK (refund_amount_cents >= 0);

-- ---------------------------------------------------------------------------
-- 2. payment_status state machine — ADD 'partially_refunded' (additive).
--    Existing values are preserved verbatim; we only widen the allow-list.
--      unpaid | authorized | paid | pay_in_person | refunded
--      | partially_refunded | failed | canceled
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN (
    'unpaid','authorized','paid','pay_in_person',
    'refunded','partially_refunded','failed','canceled'
  ));

-- ---------------------------------------------------------------------------
-- 3. Per-refund audit trail. One row per provider refund (so multiple partial
--    refunds on one order are all recorded). Provider + provider_refund_id are
--    stored per-row so reconciliation never depends on the org's current
--    payment_provider flag (a merchant who switched providers still has correctly
--    attributed historical refunds — same principle as the GMV provider split).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('stripe','square')),
  -- The provider's own refund id (Stripe re_..., Square refund.id). UNIQUE per
  -- provider so re-recording the same refund is idempotent.
  provider_refund_id text NOT NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency text NOT NULL DEFAULT 'AUD',
  reason text,
  -- Mirrors the provider refund lifecycle: pending → succeeded | failed.
  -- (Stripe: pending/succeeded/failed/canceled. Square: PENDING/COMPLETED/
  --  FAILED/REJECTED, mapped to the same set.)
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','succeeded','failed','canceled')),
  created_by uuid,                 -- the owner/manager user id that initiated it
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Idempotency anchor: the same provider refund id can only be recorded once.
CREATE UNIQUE INDEX IF NOT EXISTS payment_refunds_provider_refund_id_key
  ON public.payment_refunds (provider, provider_refund_id);
CREATE INDEX IF NOT EXISTS payment_refunds_order_idx
  ON public.payment_refunds (order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS payment_refunds_org_idx
  ON public.payment_refunds (organization_id, created_at DESC);

ALTER TABLE public.payment_refunds ENABLE ROW LEVEL SECURITY;

-- Owner + staff of the org may READ their refund history (it appears on the
-- Orders board). Writes go ONLY through the SECURITY DEFINER RPC below (called by
-- the edge fn with the service role) — no direct anon/owner INSERT path, so a
-- client can never fabricate a refund record. current_org_id() is the same
-- authority every orders policy uses, so this can't leak across orgs.
DROP POLICY IF EXISTS "Org members read their refunds" ON public.payment_refunds;
CREATE POLICY "Org members read their refunds"
  ON public.payment_refunds FOR SELECT
  USING (organization_id = public.current_org_id());

-- ---------------------------------------------------------------------------
-- 4. record_order_refund() — the SINGLE atomic writer.
--    Called by the refund-order edge fn AFTER the provider confirms the refund
--    (or, for an async PENDING refund, when the fn records the pending refund and
--    a webhook later flips status). Validates the amount against the captured
--    total minus already-refunded, records the audit row idempotently, and rolls
--    the order summary + payment_status forward in ONE transaction.
--
--    p_status: the provider refund's lifecycle state ('pending'|'succeeded'|
--              'failed'|'canceled'). A 'failed'/'canceled' refund is recorded for
--              audit but does NOT move money (it does not decrement the order).
--
--    Returns the order row (post-update) so the edge fn can echo the new state.
--    Service-role only (the edge fn authenticates with the service key after it
--    has verified the caller is the owner/manager — defence in depth: the auth is
--    in the edge fn, the money-math invariant is HERE).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_order_refund(
  p_order_id          uuid,
  p_provider          text,
  p_provider_refund_id text,
  p_amount_cents      integer,
  p_status            text DEFAULT 'succeeded',
  p_reason            text DEFAULT NULL,
  p_created_by        uuid DEFAULT NULL
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order        public.orders%ROWTYPE;
  v_already      integer;
  v_captured     integer;
  v_existing     public.payment_refunds%ROWTYPE;
  v_new_total    integer;
BEGIN
  IF p_provider NOT IN ('stripe','square') THEN
    RAISE EXCEPTION 'Invalid provider %', p_provider USING ERRCODE = 'check_violation';
  END IF;
  IF p_status NOT IN ('pending','succeeded','failed','canceled') THEN
    RAISE EXCEPTION 'Invalid refund status %', p_status USING ERRCODE = 'check_violation';
  END IF;
  IF p_provider_refund_id IS NULL OR length(trim(p_provider_refund_id)) = 0 THEN
    RAISE EXCEPTION 'provider_refund_id is required';
  END IF;

  -- Lock the order row for the duration so a concurrent refund (two managers,
  -- two tabs, or a webhook racing the fn) can't both pass the headroom check and
  -- jointly over-refund. FOR UPDATE serialises them; the second sees the first's
  -- decrement.
  SELECT * INTO v_order
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- A refund only exists against a CAPTURED charge. 'paid' or an already
  -- 'partially_refunded' order can be (further) refunded. 'pay_in_person' is
  -- settled off our rails (the merchant refunds cash/their own terminal), and
  -- 'authorized'/'unpaid'/'canceled'/'failed' have no captured funds to reverse —
  -- those are CANCELLED upstream, not refunded. Refuse to book a refund against
  -- them so the two paths never collide. (A 'succeeded' refund requires a captured
  -- order; a 'failed'/'canceled' refund attempt is still recorded for audit but
  -- with no money movement and no state change — see below.)
  v_captured := COALESCE(v_order.total_amount, 0);

  -- Idempotency: if this exact provider refund is already recorded, return the
  -- order unchanged (a retry / a webhook that already landed). We DO allow an
  -- existing PENDING row to be promoted to a terminal status by a later webhook
  -- (handled by the separate set_refund_status() path), but a duplicate INSERT of
  -- the same id here is a no-op.
  SELECT * INTO v_existing
  FROM public.payment_refunds
  WHERE provider = p_provider AND provider_refund_id = p_provider_refund_id;
  IF FOUND THEN
    RETURN v_order;
  END IF;

  -- Money-movement validation applies ONLY to refunds that actually move money
  -- (pending/succeeded). A failed/canceled refund attempt is audited without
  -- touching the order totals.
  IF p_status IN ('pending','succeeded') THEN
    IF v_order.payment_status NOT IN ('paid','partially_refunded') THEN
      RAISE EXCEPTION
        'Order % is not in a refundable state (payment_status=%). Authorized/unpaid orders are cancelled, not refunded.',
        p_order_id, v_order.payment_status
        USING ERRCODE = 'check_violation';
    END IF;

    IF p_amount_cents IS NULL OR p_amount_cents <= 0 THEN
      RAISE EXCEPTION 'Refund amount must be positive';
    END IF;

    v_already := COALESCE(v_order.refund_amount_cents, 0);
    -- The hard invariant: total refunded can never exceed the captured total.
    IF v_already + p_amount_cents > v_captured THEN
      RAISE EXCEPTION
        'Refund of % cents exceeds the refundable balance (% captured − % already refunded = % cents).',
        p_amount_cents, v_captured, v_already, (v_captured - v_already)
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Record the audit row. Idempotent via the UNIQUE(provider, provider_refund_id)
  -- index: if a concurrent caller raced past the FOUND check above and inserted
  -- the same provider refund first, this INSERT raises unique_violation — we
  -- catch it and return the order unchanged (the refund is already recorded), so
  -- a race never double-decrements.
  BEGIN
    INSERT INTO public.payment_refunds (
      order_id, organization_id, provider, provider_refund_id,
      amount_cents, currency, reason, status, created_by
    ) VALUES (
      p_order_id, v_order.organization_id, p_provider, p_provider_refund_id,
      GREATEST(1, COALESCE(p_amount_cents, 1)), 'AUD', p_reason,
      p_status, p_created_by
    );
  EXCEPTION WHEN unique_violation THEN
    RETURN v_order;  -- already recorded by a concurrent caller — idempotent no-op
  END;

  -- Only move the order forward for money-moving refunds.
  IF p_status IN ('pending','succeeded') THEN
    -- INT-H2 (consistency with set_refund_status): recompute the running total
    -- AUTHORITATIVELY from the per-refund ledger (the just-inserted row is now
    -- visible in this transaction) under the order lock, rather than adding to the
    -- possibly-stale column. This keeps the summary == SUM(ledger) regardless of
    -- how concurrent refunds + webhook back-outs interleave, matching the
    -- recompute in set_refund_status.
    SELECT COALESCE(SUM(amount_cents), 0)::integer INTO v_new_total
    FROM public.payment_refunds
    WHERE order_id = p_order_id
      AND status IN ('pending','succeeded');
    -- A fully-refunded order is 'refunded'; anything less is 'partially_refunded'.
    UPDATE public.orders
    SET
      refund_amount_cents = v_new_total,
      refunded_at = now(),
      refund_reason = COALESCE(p_reason, refund_reason),
      payment_status = CASE
        WHEN v_new_total >= v_captured THEN 'refunded'
        ELSE 'partially_refunded'
      END
    WHERE id = p_order_id
    RETURNING * INTO v_order;
  END IF;

  RETURN v_order;
END;
$$;

-- The edge fn calls this with the service-role key (after verifying owner/manager
-- auth itself). No anon/authenticated grant — clients can NEVER write a refund.
REVOKE ALL ON FUNCTION public.record_order_refund(uuid, text, text, integer, text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_order_refund(uuid, text, text, integer, text, text, uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- 5. set_refund_status() — promote a PENDING refund to a terminal state when a
--    provider webhook lands (Stripe charge.refund.updated / Square refund.updated).
--    If a refund that was counted as pending FAILS, we BACK OUT its amount from
--    the order summary so GMV/refund totals stay truthful. Idempotent: a status
--    that doesn't change is a no-op. Service-role only (called by the webhooks).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_refund_status(
  p_provider          text,
  p_provider_refund_id text,
  p_status            text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_refund    public.payment_refunds%ROWTYPE;
  v_order     public.orders%ROWTYPE;
  v_order_id  uuid;
  v_new_total integer;
BEGIN
  IF p_status NOT IN ('pending','succeeded','failed','canceled') THEN
    RAISE EXCEPTION 'Invalid refund status %', p_status USING ERRCODE = 'check_violation';
  END IF;

  -- INT-H2 (lock ordering): record_order_refund() locks the ORDER row first, then
  -- touches payment_refunds. If we locked the refund row first here we'd acquire
  -- the two rows in the OPPOSITE order → a classic deadlock under a concurrent
  -- refund + webhook. So we resolve the order id WITHOUT locking, lock the ORDER
  -- row FIRST (matching record_order_refund), and only THEN lock the refund row.
  SELECT order_id INTO v_order_id
  FROM public.payment_refunds
  WHERE provider = p_provider AND provider_refund_id = p_provider_refund_id;
  IF NOT FOUND THEN
    RETURN;  -- nothing to update (webhook for a refund we never recorded)
  END IF;

  -- Lock the ORDER row first (same order as record_order_refund) ...
  SELECT * INTO v_order FROM public.orders WHERE id = v_order_id FOR UPDATE;
  -- ... then the refund row, re-read under its own lock (its status may have moved
  -- between the unlocked lookup above and acquiring the order lock).
  SELECT * INTO v_refund
  FROM public.payment_refunds
  WHERE provider = p_provider AND provider_refund_id = p_provider_refund_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;  -- refund vanished (cascade delete) — nothing to do
  END IF;

  -- No-op if unchanged, or if already terminal-success (don't downgrade a
  -- succeeded refund).
  IF v_refund.status = p_status OR v_refund.status = 'succeeded' THEN
    -- Allow pending→succeeded transition; block succeeded→anything.
    IF NOT (v_refund.status = 'pending' AND p_status = 'succeeded') THEN
      RETURN;
    END IF;
  END IF;

  UPDATE public.payment_refunds
  SET status = p_status, updated_at = now()
  WHERE id = v_refund.id;

  -- INT-H2 (lost-update / drift): recompute the order's refunded total
  -- AUTHORITATIVELY from the per-refund ledger inside the locked section, rather
  -- than incrementally adjusting the prior column value. The incremental approach
  -- could drift when concurrent partial + full refunds and webhook back-outs
  -- interleave (each reading a stale refund_amount_cents). Summing the ledger
  -- (only refunds that still move money: pending/succeeded) under the order lock is
  -- self-correcting and order-independent. Both money-moving and back-out
  -- transitions recompute the same way, so the summary always equals the ledger.
  SELECT COALESCE(SUM(amount_cents), 0)::integer INTO v_new_total
  FROM public.payment_refunds
  WHERE order_id = v_order.id
    AND status IN ('pending','succeeded');

  UPDATE public.orders
  SET
    refund_amount_cents = v_new_total,
    payment_status = CASE
      WHEN v_new_total <= 0 THEN 'paid'
      WHEN v_new_total >= COALESCE(v_order.total_amount, 0) THEN 'refunded'
      ELSE 'partially_refunded'
    END,
    refunded_at = CASE WHEN v_new_total <= 0 THEN NULL ELSE COALESCE(v_order.refunded_at, now()) END
  WHERE id = v_order.id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_refund_status(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_refund_status(text, text, text) TO service_role;

-- ---------------------------------------------------------------------------
-- 6. GMV reconciliation — net refunds out of the GMV aggregate.
--    The prior get_gmv_analytics (20260610040000) EXCLUDED fully-'refunded'
--    orders but did NOT subtract a PARTIAL refund — a $100 order with a $30
--    refund still counted $100. We now net by using (total_amount −
--    refund_amount_cents) as the GMV contribution for every non-declined order,
--    and treat 'refunded' as fully netted (contributes 0). This keeps GMV equal
--    to value actually retained. CREATE OR REPLACE only — additive, idempotent.
--
--    DONATION RECONCILIATION: today no per-order 'gmv_mandatory' donation row is
--    booked (founding merchants are application_fee=0; the Connect Custom charity
--    split is deferred until Stripe's AFSL confirmation). So a refund's only
--    reconciliation effect TODAY is reducing GMV (here). When per-order charity
--    booking is added later, a refund must also book a NEGATIVE/contra
--    donation_ledger entry proportional to the refunded fraction — see
--    docs/REFUND_POLICY.md "GMV & donation reconciliation". This RPC is the GMV
--    half and is forward-compatible (it reads refund_amount_cents).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_gmv_analytics(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid := public.current_org_id();
  v_days   integer := LEAST(GREATEST(COALESCE(p_days, 30), 1), 366);
  v_since  timestamptz := now() - make_interval(days => v_days);
  v_result jsonb;
BEGIN
  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object(
      'currency', 'AUD',
      'window_days', v_days,
      'gmv_cents', 0,
      'order_count', 0,
      'aov_cents', 0,
      'by_status',   jsonb_build_object(
                       'paid',       jsonb_build_object('cents', 0, 'count', 0),
                       'authorized', jsonb_build_object('cents', 0, 'count', 0),
                       'unsettled',  jsonb_build_object('cents', 0, 'count', 0)),
      'by_provider', '[]'::jsonb,
      'by_location', '[]'::jsonb
    );
  END IF;

  WITH gmv_orders AS (
    SELECT
      -- NET GMV contribution = captured total minus money refunded. A fully
      -- 'refunded' order nets 0; a partial refund nets the retained remainder.
      -- GREATEST(...,0) guards against any data anomaly where refunds > total.
      GREATEST(o.total_amount - COALESCE(o.refund_amount_cents, 0), 0) AS cents,
      CASE
        WHEN o.payment_status IN ('paid', 'pay_in_person', 'partially_refunded') THEN 'paid'
        WHEN o.payment_status = 'authorized'               THEN 'authorized'
        ELSE 'unsettled'
      END AS settle,
      CASE
        WHEN o.square_payment_id IS NOT NULL          THEN 'square'
        WHEN o.stripe_payment_intent_id IS NOT NULL   THEN 'stripe'
        ELSE 'venue'
      END AS provider,
      COALESCE(o.square_location_id, 'default') AS location_id
    FROM public.orders o
    WHERE o.organization_id = v_org_id
      AND o.created_at >= v_since
      AND o.status <> 'declined'
      -- Exclude payments that never settled. 'partially_refunded' is KEPT (it
      -- still moved net value); 'refunded' is kept too but nets to 0 above, so it
      -- contributes 0 cents while still being visible in counts — exclude it from
      -- the universe entirely so neither cents NOR count is inflated by a fully
      -- refunded order.
      AND COALESCE(o.payment_status, 'unpaid') NOT IN ('refunded', 'failed', 'canceled')
  ),
  totals AS (
    SELECT COALESCE(SUM(cents), 0)::bigint AS gmv_cents,
           COUNT(*)::bigint                AS order_count
    FROM gmv_orders
  ),
  by_status AS (
    SELECT settle,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY settle
  ),
  by_provider AS (
    SELECT provider,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY provider
  ),
  by_location AS (
    SELECT location_id,
           COALESCE(SUM(cents), 0)::bigint AS cents,
           COUNT(*)::bigint                AS count
    FROM gmv_orders
    GROUP BY location_id
  )
  SELECT jsonb_build_object(
    'currency', 'AUD',
    'window_days', v_days,
    'gmv_cents', t.gmv_cents,
    'order_count', t.order_count,
    'aov_cents', CASE WHEN t.order_count > 0
                      THEN ROUND(t.gmv_cents::numeric / t.order_count)::bigint
                      ELSE 0 END,
    'by_status', jsonb_build_object(
      'paid', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'paid'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'paid'), 0)),
      'authorized', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'authorized'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'authorized'), 0)),
      'unsettled', jsonb_build_object(
        'cents', COALESCE((SELECT cents FROM by_status WHERE settle = 'unsettled'), 0),
        'count', COALESCE((SELECT count FROM by_status WHERE settle = 'unsettled'), 0))
    ),
    'by_provider', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('provider', provider, 'cents', cents, 'count', count)
                       ORDER BY cents DESC)
      FROM by_provider
    ), '[]'::jsonb),
    'by_location', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('location_id', location_id, 'cents', cents, 'count', count)
                       ORDER BY cents DESC)
      FROM by_location
    ), '[]'::jsonb)
  )
  INTO v_result
  FROM totals t;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_gmv_analytics(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_gmv_analytics(integer) TO authenticated;

-- =============================================================================
-- FOUNDER NOTE — RUN MANUALLY; the refund-order edge fn deploys separately.
-- =============================================================================
-- 1. Run this whole file in the Supabase SQL editor on the LIVE project. It is
--    additive + idempotent / safe to re-run.
-- 2. Deploy the refund-order edge function (npx supabase functions deploy
--    refund-order) AFTER this migration is applied — it calls record_order_refund
--    and reads payment_refunds.
-- 3. The refund-order fn needs the SAME provider secrets already set for payments
--    (STRIPE_SECRET_KEY; Square uses each merchant's OAuth token from
--    square_connections — no new secret). No new env var is required.
-- 4. TEST (sandbox first):
--      (a) Full refund of a paid Stripe order  -> payment_status='refunded',
--          refund_amount_cents = total_amount, a re_... id in payment_refunds.
--      (b) Partial refund of a paid Square order -> 'partially_refunded', the
--          remainder still refundable; a second partial that completes it -> 'refunded'.
--      (c) Over-refund attempt (amount > remaining) -> rejected by the RPC.
--      (d) Refund an AUTHORIZED-not-captured order via the UI -> the fn CANCELS
--          the auth (no payment_refunds row; payment_status='canceled').
--      (e) GMV widget: a partially-refunded order contributes (total − refund);
--          a fully-refunded order contributes 0 and drops from the count.
-- =============================================================================

-- ========== 20260610060000_remask_get_order_by_id ==========
-- =============================================================================
-- INT-H1 — re-mask get_order_by_id after orders.square_location_id was added.
-- =============================================================================
-- ORDERING BUG (caught in the 2026-06-10 integration review): the anon order
-- tracker RPC get_order_by_id was last re-created in
-- 20260609060000_rpc_mask_square_and_counters.sql (the H-5 denylist), which masks
--   r.courier_driver_phone, r.stripe_payment_intent_id,
--   r.square_payment_id, r.square_order_id.
-- THEN 20260610030000_orders_square_location.sql ADDED orders.square_location_id.
-- Because RETURNS SETOF public.orders projects the WHOLE (now wider) row and the
-- denylist is exposed-by-default, the anon RPC has been returning the merchant's
-- Square location id UNMASKED to anyone with a receipt_token — a payment-processor
-- identity leak on the public order tracker (the same exposed-by-default failure
-- mode H-5 itself called out).
--
-- FIX (this migration — must run LAST, after 20260610030000 added the column):
-- CREATE OR REPLACE get_order_by_id IDENTICAL to the 060000 version, PLUS
-- r.square_location_id := NULL. We also RE-CONFIRM the existing masks
-- (courier_driver_phone, stripe_payment_intent_id, square_payment_id,
-- square_order_id) so the function is self-contained and correct regardless of
-- which earlier definition last touched it. The public tracker shows
-- payment_status (paid/unpaid) and courier progress — never any payment-processor
-- identity or reference id — so nulling the location id breaks nothing in src/
-- (no consumer reads square_location_id off this RPC; verified by grep).
--
-- STRICTLY ADDITIVE + IDEMPOTENT: CREATE OR REPLACE only; no table/RLS change
-- (grant restated for self-containment). Safe to re-run. Sorts AFTER
-- 20260610050000_order_refunds.sql, so it is the authoritative last definition.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_order_by_id(p_id uuid)
RETURNS SETOF public.orders
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.orders%ROWTYPE;
  v_auth_uid uuid := auth.uid();
BEGIN
  SELECT * INTO r
  FROM public.orders
  WHERE receipt_token = p_id
  LIMIT 1;

  IF NOT FOUND AND v_auth_uid IS NOT NULL THEN
    SELECT * INTO r
    FROM public.orders o
    WHERE o.id = p_id
      AND (
        o.customer_id = public.customer_id_for_user(o.organization_id)
        OR EXISTS (
          SELECT 1
          FROM public.organizations org
          WHERE org.id = o.organization_id
            AND org.owner_id = v_auth_uid
        )
        OR public.is_staff_of_org(v_auth_uid, o.organization_id)
      )
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Existing courier mask (unchanged from 20260609060000).
  r.courier_driver_phone := NULL;

  -- H-5: provider payment-reference ids — the public order tracker shows
  -- payment_status (paid/unpaid), never the raw PI/payment ids. Re-confirmed here.
  r.stripe_payment_intent_id := NULL;
  r.square_payment_id := NULL;
  r.square_order_id := NULL;

  -- INT-H1 ADDED: orders.square_location_id was added by 20260610030000 AFTER the
  -- H-5 denylist was written, so it leaked through this anon RPC. Mask it — the
  -- Square location id is the merchant's payment-processor identity and the public
  -- tracker never needs it.
  r.square_location_id := NULL;

  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_by_id(uuid) TO anon, authenticated;
