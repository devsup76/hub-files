-- =============================================================================
-- WOAHH — FOUNDER: run these in the Supabase SQL editor (project pmnyhbhtkcfoozkinieo)
-- IN ORDER. The 3 storefront migrations (20260603010000 / 020000 / 20260607010000)
-- are ALREADY applied. These two are NEW. Safe to re-run (idempotent).
-- After running: regenerate types (Dashboard -> API, or supabase gen types).
-- Also enable: Auth -> Providers -> Anonymous sign-ins (guest checkout) + Turnstile.
-- =============================================================================

-- ========== #2 GUEST-CHECKOUT CONSENT (T&C cols + claim-or-reject upsert_my_consent) ==========
-- Guest checkout — consent plumbing (single-writer shared layer).
--
-- Adds an auditable T&C acceptance trail to `customers` (mirrors the existing
-- email/sms consent columns) and a single SECURITY DEFINER entry point that
-- records consent + (gets-or-creates) the caller's customer row at checkout.
--
-- Mechanism: guest checkout mints a Supabase ANONYMOUS session at place-order
-- time, so the caller carries a non-null auth.uid() with the `authenticated`
-- Postgres role (an anonymous signed-in user IS in the `authenticated` role —
-- it's just an authenticated user flagged `is_anonymous = true`). This RPC keys
-- the write to that auth.uid() server-side, so it never depends on a public
-- table policy and never elevates beyond the caller's own (org, uid) row.
--
-- IDENTITY / CLAIM-OR-REJECT rule (the function ALWAYS returns a row whose
-- user_id = auth.uid(), so the order RPC's customer_id_for_user(auth.uid())
-- deterministically links the order to it):
--   1. Row already exists for (org, auth.uid()) -> UPDATE consent, return it.
--   2. Else a candidate row matches in the org by phone OR email:
--        - if its user_id IS NULL (an unclaimed CRM contact / prior guest):
--          CLAIM it (set user_id = auth.uid()), merge name/email/phone/consent,
--          return it. This avoids the customers_org_phone_uidx /
--          customers_org_user_uidx unique collisions a blind INSERT would hit,
--          and folds an email match into the same identity instead of forking a
--          duplicate.
--        - if its user_id IS NOT NULL and != auth.uid() (a REAL registered
--          account): RAISE a friendly error ("an account already exists ...")
--          and DO NOT take over their row.
--   3. Else INSERT a fresh row (org, auth.uid(), name, email, phone, consent).
-- Every branch is collision-free on both (org, user_id) and (org, phone).
--
-- Additive only: NO change to the `customers` RLS policies, the order RPC
-- (create_order_with_inventory), or any existing function. Idempotent.
--
-- NOT auto-applied — the founder runs this in the Supabase SQL editor, then
-- regenerates src/integrations/supabase/types.ts.

-- 1. T&C acceptance audit columns on customers (only if missing).
--    Presentation-neutral; written by the consent RPC below.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS tos_accepted_at   timestamptz,
  ADD COLUMN IF NOT EXISTS tos_accept_method text;   -- e.g. 'checkout_checkbox'

COMMENT ON COLUMN public.customers.tos_accepted_at IS
  'When this customer accepted the merchant/Woahh terms (guest checkout or account create).';
COMMENT ON COLUMN public.customers.tos_accept_method IS
  'How T&C was accepted, e.g. checkout_checkbox.';

-- 2. Consent upsert RPC — one SECURITY DEFINER entry point for guest/customer
--    consent at checkout. Mirrors accept_customer_invite (20260530090000): the
--    function — not a public RLS policy — owns the write, keyed to the CALLER's
--    auth.uid(). ALWAYS returns a row whose user_id = auth.uid() (claim-or-reject;
--    see header). Idempotent. Two partial unique indexes are in play and must NOT
--    be violated in any branch:
--      customers_org_user_uidx  (organization_id, user_id)      WHERE user_id     IS NOT NULL
--      customers_org_phone_uidx (organization_id, phone_number) WHERE phone_number IS NOT NULL
CREATE OR REPLACE FUNCTION public.upsert_my_consent(
  p_org_id        uuid,
  p_name          text,
  p_email         text,
  p_phone         text    DEFAULT NULL,
  p_tos           boolean DEFAULT false,
  p_email_opt_in  boolean DEFAULT false,
  p_sms_opt_in    boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_email   text := NULLIF(trim(p_email), '');
  v_phone   text := NULLIF(trim(p_phone), '');
  v_name    text;
  v_id      uuid;
  v_owner   uuid;   -- user_id of a candidate row matched by phone/email
  -- Derived consent values (so the INSERT and the two UPDATE branches stay in
  -- lock-step and a phone is required before SMS consent is recorded).
  v_email_at     timestamptz := CASE WHEN p_email_opt_in THEN now() END;
  v_email_method text        := CASE WHEN p_email_opt_in THEN 'checkout_checkbox' END;
  v_sms_at       timestamptz := CASE WHEN p_sms_opt_in AND v_phone IS NOT NULL THEN now() END;
  v_sms_method   text        := CASE WHEN p_sms_opt_in AND v_phone IS NOT NULL THEN 'checkout_checkbox' END;
BEGIN
  -- An anonymous session still has a non-null uid; only a truly-unauthenticated
  -- (anon-key, no session) caller is rejected.
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sign in is required';
  END IF;

  -- T&C is mandatory to create a consent row (matches the required checkout box).
  IF p_tos IS NOT TRUE THEN
    RAISE EXCEPTION 'Terms must be accepted';
  END IF;

  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'Organization is required';
  END IF;

  v_name := COALESCE(NULLIF(trim(p_name), ''), split_part(COALESCE(v_email, ''), '@', 1));

  -- ── Branch 1: this caller already has a row in the org → just update it. ─────
  SELECT id INTO v_id
  FROM public.customers
  WHERE organization_id = p_org_id AND user_id = v_uid
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE public.customers SET
      name                 = COALESCE(NULLIF(trim(v_name), ''), name),
      email                = COALESCE(v_email, email),
      -- Only adopt the supplied phone if it won't collide with ANOTHER row in
      -- this org (the partial unique index on (org, phone_number)).
      phone_number         = CASE
                               WHEN v_phone IS NOT NULL AND NOT EXISTS (
                                 SELECT 1 FROM public.customers c2
                                 WHERE c2.organization_id = p_org_id
                                   AND c2.phone_number = v_phone
                                   AND c2.id <> public.customers.id
                               ) THEN v_phone
                               ELSE phone_number
                             END,
      tos_accepted_at      = COALESCE(tos_accepted_at, now()),
      tos_accept_method    = COALESCE(tos_accept_method, 'checkout_checkbox'),
      marketing_opt_in     = marketing_opt_in OR p_email_opt_in,
      email_consent_at     = COALESCE(email_consent_at, v_email_at),
      email_consent_method = COALESCE(email_consent_method, v_email_method),
      sms_consent_at       = COALESCE(sms_consent_at, v_sms_at),
      sms_consent_method   = COALESCE(sms_consent_method, v_sms_method),
      updated_at           = now()
    WHERE id = v_id;
    RETURN v_id;
  END IF;

  -- ── Branch 2: a candidate row in the org matches the given phone OR email. ──
  -- Phone is the stronger key (it's uniquely indexed); fall back to email.
  IF v_phone IS NOT NULL THEN
    SELECT id, user_id INTO v_id, v_owner
    FROM public.customers
    WHERE organization_id = p_org_id AND phone_number = v_phone
    LIMIT 1;
  END IF;

  IF v_id IS NULL AND v_email IS NOT NULL THEN
    SELECT id, user_id INTO v_id, v_owner
    FROM public.customers
    WHERE organization_id = p_org_id AND lower(email) = lower(v_email)
    LIMIT 1;
  END IF;

  IF v_id IS NOT NULL THEN
    -- Belongs to a real, registered account that isn't this caller → reject.
    -- (Anonymous guests get a fresh uid each time, so they can never be the
    -- v_owner here unless it's literally the same session — handled in branch 1.)
    IF v_owner IS NOT NULL AND v_owner <> v_uid THEN
      RAISE EXCEPTION
        'An account already exists for this email or phone — please sign in';
    END IF;

    -- Unclaimed CRM contact / prior guest row → CLAIM it for this caller and
    -- merge details + consent. Setting user_id is safe: branch 1 already proved
    -- this caller has no other (org, uid) row, so customers_org_user_uidx holds.
    UPDATE public.customers SET
      user_id              = v_uid,
      name                 = COALESCE(NULLIF(trim(v_name), ''), name),
      email                = COALESCE(v_email, email),
      -- When this row was matched by EMAIL, the supplied phone could belong to a
      -- DIFFERENT row — only adopt it if it won't collide on (org, phone_number).
      phone_number         = CASE
                               WHEN v_phone IS NOT NULL AND NOT EXISTS (
                                 SELECT 1 FROM public.customers c2
                                 WHERE c2.organization_id = p_org_id
                                   AND c2.phone_number = v_phone
                                   AND c2.id <> public.customers.id
                               ) THEN v_phone
                               ELSE phone_number
                             END,
      tos_accepted_at      = COALESCE(tos_accepted_at, now()),
      tos_accept_method    = COALESCE(tos_accept_method, 'checkout_checkbox'),
      marketing_opt_in     = marketing_opt_in OR p_email_opt_in,
      email_consent_at     = COALESCE(email_consent_at, v_email_at),
      email_consent_method = COALESCE(email_consent_method, v_email_method),
      sms_consent_at       = COALESCE(sms_consent_at, v_sms_at),
      sms_consent_method   = COALESCE(sms_consent_method, v_sms_method),
      updated_at           = now()
    WHERE id = v_id;
    RETURN v_id;
  END IF;

  -- ── Branch 3: nothing matched → insert a fresh row for this caller. ─────────
  -- Collision-free: branch 1 ruled out an (org, uid) row, branch 2 ruled out an
  -- (org, phone) row.
  INSERT INTO public.customers (
    organization_id, user_id, name, email, phone_number,
    tos_accepted_at, tos_accept_method,
    marketing_opt_in,
    email_consent_at, email_consent_method, email_opted_out,
    sms_consent_at,   sms_consent_method,   sms_opted_out
  ) VALUES (
    p_org_id, v_uid,
    v_name, v_email, v_phone,
    now(), 'checkout_checkbox',
    p_email_opt_in,
    v_email_at, v_email_method, false,
    v_sms_at,   v_sms_method,   false
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- An anonymous signed-in user holds the `authenticated` role, so granting to
-- `authenticated` covers guests too; `anon` is granted for parity with the
-- accept_customer_invite pattern (a no-session anon-key caller is still rejected
-- inside the function by the auth.uid() IS NULL guard).
GRANT EXECUTE ON FUNCTION public.upsert_my_consent(uuid, text, text, text, boolean, boolean, boolean)
  TO anon, authenticated;

-- ========== #3 C1 — SERVER-SIDE ORDER TOTAL (apply, then TEST before real cards) ==========
-- =============================================================================
-- C1 (CRITICAL) — Server-side authoritative order total.
-- =============================================================================
-- PROBLEM
--   create_order_with_inventory() stored the CLIENT-supplied p_total directly
--   into orders.total_amount without recomputing anything from the database.
--   stripe-payment-intent charges orders.total_amount (read by order id), so a
--   manipulated client could place a real $80 order with p_total = 1 and be
--   charged 1 cent once real cards are live. The order RPC was the single trust
--   boundary (the Stripe edge functions are already server-derived from the
--   order row), so the fix lives here.
--
-- FIX (floor / lower-bound model)
--   Recompute an AUTHORITATIVE item subtotal SERVER-SIDE from the products table
--   (sale-window aware, mirroring effectiveProductPrice in src/services/api.ts),
--   add validated extras priced from the product's OWN extras_list (the client's
--   price_delta is ignored), multiply by quantity, sum to v_subtotal, then apply
--   a SERVER-VALIDATED promo discount. The result (v_floor = subtotal - discount)
--   is the minimum a legitimate order can possibly cost. For an untrusted
--   guest/customer order (the Stripe-charged path) we REJECT any p_total below
--   that floor — that is the exact tamper the attack relies on (lowering item
--   prices). Delivery / service / shipping fees only ADD to the customer total,
--   so the floor is a safe lower bound that never falsely rejects a legitimate
--   higher total. The displayed p_total is stored verbatim as total_amount, so
--   the customer is charged exactly what they saw (no mischarge of valid orders).
--
--   The promo is validated + its usage_count incremented in the SAME transaction
--   (also closes the "promo enforced client-side only / usage never increments
--   for customer orders" gap).
--
-- WHY NOT store a fully server-recomputed total instead of p_total?
--   The customer-facing fees (1% service fee on the published storefront, flat
--   $4.99 published delivery, settings-driven restaurant delivery, $8/free-over-
--   $75 retail shipping) are computed in CLIENT code and are NOT carried in the
--   order payload — the row only holds the opaque total + fulfillment_type. The
--   server therefore CANNOT reconstruct the displayed total to the cent without
--   guessing which storefront produced the order. Overwriting total_amount with a
--   server figure that omits fees would UNDERCHARGE every legitimate order;
--   guessing fees would MISCHARGE. So we recompute the part that IS authoritative
--   (items + promo), reject anything below it, and keep the agreed displayed
--   total as the charge. See the founder note at the bottom of this file.
--
-- SCOPE
--   The floor is enforced ONLY for untrusted callers (guest/customer checkout).
--   Trusted org owners/staff (POS / WalkInOrderDialog) may legitimately apply
--   manual discounts / comps / negotiated walk-in prices, so the floor is skipped
--   for them (v_is_org_member). Everything else (inventory decrement, customer
--   linkage, receipt_token via the orders default, initial_status, dine-in
--   handling, shipping_address/notes/table_number, the auth gate) is BYTE-FOR-BYTE
--   identical to migration 20260601093000.
--
-- SAFE TO RE-RUN: pure CREATE OR REPLACE FUNCTION (idempotent). No DDL/data change.
-- NOT auto-applied — the founder runs this in the Supabase SQL editor against the
-- live project and TESTS (place real orders, verify totals match) BEFORE enabling
-- real card acceptance.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_order_with_inventory(
  p_org_id uuid,
  p_customer_id uuid,
  p_total integer,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS public.orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.orders;
  v_auth_uid uuid := auth.uid();
  v_is_org_member boolean;
  v_customer_id uuid;
  v_line_items jsonb;
  v_item jsonb;
  v_product_id uuid;
  v_quantity int;
  v_stock int;
  v_is_available boolean;
  v_fulfillment public.fulfillment_type;
  v_status public.order_status;
  -- C1 additions: authoritative pricing recompute.
  v_price int;
  v_sale int;
  v_sale_start timestamptz;
  v_sale_end timestamptz;
  v_extras_list jsonb;
  v_unit int;
  v_extras int;
  v_subtotal int := 0;
  v_promo_code text;
  v_promo public.promo_codes%ROWTYPE;
  v_discount int := 0;
  v_floor int;
  -- Small tolerance (cents) absorbing sale-window clock skew between the
  -- client's new Date() and the server's now() at a sale boundary, and any
  -- benign client/server rounding. Far below any item price, so it cannot be
  -- abused to underpay a meal — it only prevents false rejects at the edge.
  v_tolerance constant int := 1;
BEGIN
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'Organization is required';
  END IF;
  IF p_total IS NULL OR p_total < 0 THEN
    RAISE EXCEPTION 'Invalid order total';
  END IF;

  -- Trusted = owner or active staff of this org (POS / dashboard order entry).
  SELECT EXISTS (
    SELECT 1 FROM public.organizations
    WHERE id = p_org_id AND owner_id = v_auth_uid
  ) OR public.is_staff_of_org(v_auth_uid, p_org_id)
  INTO v_is_org_member;

  IF NOT COALESCE(v_is_org_member, false) THEN
    IF v_auth_uid IS NULL THEN
      RAISE EXCEPTION 'Sign in is required to place an order';
    END IF;

    v_customer_id := public.customer_id_for_user(p_org_id);
    IF p_customer_id IS NOT NULL AND p_customer_id <> v_customer_id THEN
      RAISE EXCEPTION 'Customer does not belong to this account';
    END IF;
  ELSE
    v_customer_id := p_customer_id;
    IF v_customer_id IS NOT NULL AND NOT EXISTS (
      SELECT 1
      FROM public.customers
      WHERE id = v_customer_id
        AND organization_id = p_org_id
    ) THEN
      RAISE EXCEPTION 'Customer does not belong to this organization';
    END IF;
  END IF;

  v_line_items := COALESCE(p_payload->'line_items', '[]'::jsonb);
  IF jsonb_typeof(v_line_items) <> 'array' THEN
    RAISE EXCEPTION 'Invalid line items';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_line_items)
  LOOP
    IF NULLIF(v_item->>'product_id', '') IS NULL THEN
      RAISE EXCEPTION 'Line item is missing a product';
    END IF;

    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := GREATEST(1, COALESCE(NULLIF(v_item->>'quantity', '')::int, 1));

    -- Lock the product row ONCE and read both the availability/stock fields and
    -- the authoritative pricing fields (price/sale in cents) from the same row,
    -- so there is no extra lock and no TOCTOU window between price-read and the
    -- stock decrement.
    SELECT stock_quantity, is_available, price, sale_price,
           sale_starts_at, sale_ends_at, extras_list
      INTO v_stock, v_is_available, v_price, v_sale,
           v_sale_start, v_sale_end, v_extras_list
      FROM public.products
      WHERE id = v_product_id
        AND organization_id = p_org_id
      FOR UPDATE;

    IF NOT FOUND OR NOT COALESCE(v_is_available, false) THEN
      RAISE EXCEPTION 'An item in your cart is no longer available';
    END IF;

    IF v_stock IS NOT NULL AND v_stock < v_quantity THEN
      RAISE EXCEPTION 'Not enough stock for an item in your cart';
    END IF;

    UPDATE public.products
    SET stock_quantity = stock_quantity - v_quantity
    WHERE id = v_product_id
      AND stock_quantity IS NOT NULL;

    -- ---- Effective unit price (sale-window aware) --------------------------
    -- Two client price helpers exist and disagree at the edges:
    --   * effectiveProductPrice (RestaurantStorefront + RetailStorefront): uses
    --     sale_price whenever the window is current, even if sale_price > price
    --     (no clamp).
    --   * priceState (published-template storefront): uses sale_price only when
    --     sale_price < price (clamps to the lower of the two).
    -- To NEVER falsely reject either client path, the server takes the LOWER of
    -- the two interpretations: when the sale window is current, the effective
    -- unit is LEAST(price, sale_price); otherwise it is price. This is <= the
    -- price any client would have billed, so v_floor can never exceed a
    -- legitimate p_total.
    IF v_sale IS NOT NULL
       AND (v_sale_start IS NULL OR v_sale_start <= now())
       AND (v_sale_end   IS NULL OR v_sale_end   >= now()) THEN
      v_unit := LEAST(COALESCE(v_price, 0), v_sale);
    ELSE
      v_unit := COALESCE(v_price, 0);
    END IF;
    v_unit := GREATEST(0, v_unit);

    -- ---- Extras (priced from the DB, never from the client) ---------------
    -- For EACH requested added_extras entry, resolve its per-unit price from
    -- this product's OWN extras_list (the client's price_delta is IGNORED —
    -- only the catalogue price_delta counts) and sum them. Matching mirrors the
    -- client exactly: by EXACT name, and only against extras still offered
    -- (available != false). An unmatched / unavailable / fabricated extra
    -- resolves to 0, and a negative catalogue delta is floored at 0, so a
    -- tampered added_extras can neither inflate nor deflate the subtotal.
    -- The LATERAL + LIMIT 1 resolves each requested extra to at most ONE
    -- catalogue entry (mirroring the client's name->extra Map), so a duplicate
    -- name in extras_list cannot double-count and push the floor above a
    -- legitimate p_total (a false reject). Matching the client's exact-name +
    -- available filter is deliberate for the same reason — a broader match
    -- could add a cost the client never billed.
    v_extras := COALESCE((
      SELECT SUM(GREATEST(0, COALESCE(m.price_delta, 0)))
      FROM jsonb_array_elements(COALESCE(v_item->'added_extras', '[]'::jsonb)) AS ae(value)
      LEFT JOIN LATERAL (
        -- ::numeric then round handles a stray non-integer price_delta in the
        -- catalogue without raising (which would otherwise block the order).
        SELECT round((el.value->>'price_delta')::numeric)::int AS price_delta
        FROM jsonb_array_elements(COALESCE(v_extras_list, '[]'::jsonb)) AS el(value)
        WHERE (el.value->>'name') = (ae.value->>'name')
          AND COALESCE((el.value->>'available')::boolean, true) <> false
        LIMIT 1
      ) AS m ON true
    ), 0);

    v_subtotal := v_subtotal + (v_unit + v_extras) * v_quantity;
  END LOOP;

  -- ---- Promo (server-validated + consumed in this transaction) ------------
  -- Mirrors usePromoCode: must exist for this org, be active, not expired, and
  -- (if usage_limit set) under the limit. percentage => round(subtotal*value/100);
  -- flat => min(value, subtotal) with value stored in CENTS. The discount is
  -- applied to the item subtotal only (delivery/fees are never discounted), the
  -- same as the client.
  v_promo_code := upper(trim(COALESCE(p_payload->>'promo_code', '')));
  IF v_promo_code <> '' THEN
    SELECT * INTO v_promo
      FROM public.promo_codes
      WHERE organization_id = p_org_id AND upper(code) = v_promo_code
      FOR UPDATE;
    IF FOUND
       AND v_promo.is_active
       AND (v_promo.expires_at IS NULL OR v_promo.expires_at > now())
       AND (v_promo.usage_limit IS NULL OR v_promo.usage_count < v_promo.usage_limit) THEN
      IF v_promo.discount_type = 'percentage' THEN
        v_discount := round(v_subtotal::numeric * v_promo.value / 100.0)::int;
      ELSE
        v_discount := LEAST(v_promo.value, v_subtotal);  -- flat, stored in cents
      END IF;
      UPDATE public.promo_codes
        SET usage_count = usage_count + 1, updated_at = now()
        WHERE id = v_promo.id;
    END IF;
  END IF;

  -- ---- Authoritative floor + tamper check ---------------------------------
  -- v_floor = the minimum a legitimate order for these exact items can cost.
  -- Customer-facing fees (service fee / delivery / shipping) only ADD to the
  -- charged total, so any legitimate p_total is >= v_floor.
  v_floor := GREATEST(0, v_subtotal - v_discount);

  IF NOT COALESCE(v_is_org_member, false) AND p_total < (v_floor - v_tolerance) THEN
    RAISE EXCEPTION
      'Order total (% cents) is below the authoritative minimum for these items (% cents). Please refresh your cart and try again.',
      p_total, v_floor;
  END IF;

  v_fulfillment := NULLIF(p_payload->>'fulfillment_type', '')::public.fulfillment_type;
  v_status := COALESCE(NULLIF(p_payload->>'initial_status', '')::public.order_status, 'pending'::public.order_status);

  -- Stored total = the displayed p_total the customer agreed to (>= v_floor for
  -- untrusted orders, validated above). This is what stripe-payment-intent
  -- charges. We deliberately do NOT overwrite it with a server figure, because
  -- the path-dependent fees that make up the difference (p_total - v_floor) are
  -- not carried in the payload (see the header note). The floor guarantees the
  -- stored/charged amount can never be below the true item value.
  INSERT INTO public.orders (
    organization_id,
    customer_id,
    total_amount,
    status,
    line_items,
    fulfillment_type,
    shipping_address,
    notes,
    dine_in,
    table_number
  ) VALUES (
    p_org_id,
    v_customer_id,
    p_total,
    v_status,
    v_line_items,
    v_fulfillment,
    CASE
      WHEN p_payload ? 'shipping_address' AND p_payload->'shipping_address' <> 'null'::jsonb
        THEN p_payload->'shipping_address'
      ELSE NULL
    END,
    NULLIF(p_payload->>'notes', ''),
    COALESCE((p_payload->>'dine_in')::boolean, false),
    NULLIF(p_payload->>'table_number', '')
  )
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$$;

-- CREATE OR REPLACE preserves existing grants, but re-state them to be explicit
-- and so this migration is self-contained / safe to run on a fresh schema.
GRANT EXECUTE ON FUNCTION public.create_order_with_inventory(uuid, uuid, integer, jsonb)
TO anon, authenticated;

-- =============================================================================
-- FOUNDER NOTE — RUN MANUALLY + TEST BEFORE ENABLING REAL CARDS
-- =============================================================================
-- 1. Run this whole file in the Supabase SQL editor on the LIVE project
--    (pmnyhbhtkcfoozkinieo). It is idempotent / safe to re-run.
-- 2. No edge-function change is required: stripe-payment-intent already reads
--    orders.total_amount by order id (never a client amount), and order-respond
--    captures the full authorized amount. Once this RPC writes a validated
--    total_amount, the charge is automatically correct.
-- 3. TEST end-to-end BEFORE flipping on real-card acceptance — confirm the
--    recompute does not falsely reject a legitimate order and does block a
--    tampered one:
--      (a) Place a normal full-price order (with extras + an active sale-window
--          item + a valid promo + delivery) as a guest/customer -> ACCEPTED,
--          and the charged amount matches the cart to the cent.
--      (b) Tamper the client to send a tiny p_total with real line_items ->
--          REJECTED with the "below the authoritative minimum" error.
--      (c) Owner / staff POS order with a manual discount -> still ACCEPTED
--          (floor skipped for org members).
--      (d) Confirm the promo flat-discount `value` is stored in CENTS in your
--          Promotions data (this RPC and usePromoCode both treat flat value as
--          cents). If any flat code stores dollars, fix the data or the floor
--          could over-reject flat-promo orders.
-- =============================================================================

-- ========== #4 GUARD ANON USER TRIGGERS (run this to fix 'Database error creating anonymous user') ==========
-- =============================================================================
-- Guard the auth.users INSERT triggers against ANONYMOUS users (guest checkout).
-- =============================================================================
-- Enabling Supabase Anonymous sign-ins surfaced "Database error creating
-- anonymous user": an AFTER INSERT trigger on auth.users runs merchant/customer
-- provisioning that must NOT run for an anonymous guest. We add an explicit
-- `is_anonymous` short-circuit to BOTH auth.users triggers so a guest sign-in
-- never touches org/profile provisioning. This also corrects any live drift.
--
-- A guest's identity for an order is its `customers` row (created by
-- upsert_my_consent keyed to the anon auth.uid()); the cross-merchant
-- growthhub_profile is created when the guest UPGRADES to a real account.
--
-- Bodies below are the EXACT current definitions (handle_new_user_org from
-- 20260601090000; handle_new_customer_profile from 20260425120106) plus the one
-- guard line. Pure CREATE OR REPLACE — idempotent, no DDL/data change.
-- NOT auto-applied — run in the Supabase SQL editor.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user_org()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
  v_base text;
  v_slug text;
  v_n int := 0;
  v_kind text;
  v_username text;
BEGIN
  -- Guest checkout: an anonymous user is never a merchant.
  IF COALESCE(NEW.is_anonymous, false) THEN
    RETURN NEW;
  END IF;

  v_kind := COALESCE(NEW.raw_user_meta_data->>'kind', '');

  IF v_kind IN ('staff', 'customer') THEN
    RETURN NEW;
  END IF;

  v_name := NULLIF(trim(COALESCE(NEW.raw_user_meta_data->>'business_name', '')), '');
  IF v_name IS NULL THEN
    RETURN NEW;
  END IF;

  v_base := trim(both '-' from regexp_replace(
    lower(COALESCE(NEW.raw_user_meta_data->>'subdomain_slug', v_name)),
    '[^a-z0-9]+', '-', 'g'
  ));

  IF v_base = '' OR length(v_base) < 2 THEN
    v_base := 'shop-' || substr(md5(NEW.id::text), 1, 8);
  END IF;

  v_slug := v_base;
  WHILE EXISTS (SELECT 1 FROM public.organizations WHERE subdomain_slug = v_slug) LOOP
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n;
  END LOOP;

  INSERT INTO public.organizations (owner_id, name, subdomain_slug, trial_ends_at, marketplace_visible)
  VALUES (NEW.id, v_name, v_slug, now() + interval '60 days', true);

  v_username := lower(trim(COALESCE(NEW.raw_user_meta_data->>'username', '')));
  IF v_username ~ '^[a-z0-9._-]{3,30}$' THEN
    INSERT INTO public.usernames (user_id, username)
    VALUES (NEW.id, v_username);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_customer_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Guest checkout: anon users get no cross-merchant profile (created on upgrade).
  IF COALESCE(NEW.is_anonymous, false) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.growthhub_profiles (id)
  VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
