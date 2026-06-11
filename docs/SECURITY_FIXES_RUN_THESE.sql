-- =============================================================================
-- SECURITY FIXES — RUN THESE on the LIVE Supabase project (pmnyhbhtkcfoozkinieo)
-- =============================================================================
-- Aggregated DB migrations from the 2026-06-11 security audit
-- (docs/SECURITY_AUDIT_2026-06-11.md). Each block is IDEMPOTENT / safe to re-run
-- and mirrors a numbered file in supabase/migrations/. Run the WHOLE file in the
-- Supabase SQL editor; do NOT auto-apply. After running, deploy the edge functions
-- listed at the end of each section.
--
-- Sections are appended per audit area; keep them in ascending migration order.
-- =============================================================================



-- #############################################################################
-- PAYMENTS AREA — F4: server-authoritative initial_status
-- Mirrors supabase/migrations/20260611010000_f4_server_authoritative_initial_status.sql
-- #############################################################################

-- =============================================================================
-- F4 (HIGH) — Server-authoritative initial_status for untrusted order callers.
-- =============================================================================
-- PROBLEM (audit F4)
--   create_order_with_inventory() set the new order's status to whatever the
--   client put in p_payload->>'initial_status' (default 'pending'). The
--   v_is_org_member trust gate governed only the PRICE FLOOR (C1), never the
--   status. The RPC is GRANTed to anon + authenticated, so an anonymous guest
--   could call it with real line_items, a valid p_total >= floor, and
--   initial_status = 'pending' (or 'preparing'/'completed') to:
--     (a) DROP AN UNPAID ORDER STRAIGHT INTO THE KITCHEN — bypassing the
--         awaiting_confirmation hold that keeps a card-required order out of the
--         queue until the owner's confirm captures the authorization; and
--     (b) ESCAPE THE AUTO-DECLINE BACKSTOP — auto_decline_stale_orders only reaps
--         status = 'awaiting_confirmation', so an injected 'pending' unpaid order
--         is never reaped and the manual-capture invariant is lost.
--   Net: free meals at scale, and lingering/abandoned card holds.
--
-- FIX (constrain + force the card gate for untrusted callers)
--   For an UNTRUSTED caller (guest / customer — NOT v_is_org_member) the RPC now:
--     1. FORCES 'awaiting_confirmation' for a CARD-REQUIRED order — i.e. one where
--        the merchant takes online card (settings.payments.online_card_enabled is
--        true AND pay_mode != 'venue') and the order is not dine-in. The client
--        value is IGNORED. This is the core fix: an unpaid card order can never be
--        injected straight into the kitchen, and never escapes the
--        awaiting_confirmation auto-decline that voids the manual-capture hold.
--     2. For any OTHER (non-card / dine-in) order, HONOURS the client status ONLY
--        when it is 'pending' or 'awaiting_confirmation' (the exact two values the
--        storefronts send); ANY other value
--        ('preparing'/'ready'/'completed'/'declined') is coerced to
--        'awaiting_confirmation'. So a guest can never force 'preparing'/'completed'.
--   This mirrors the storefront's own needsApproval card-hold logic
--   (src/pages/storefront/RestaurantStorefront.tsx), enforced server-side, while
--   leaving every legitimate non-card flow byte-for-byte unchanged (we DON'T flip a
--   client 'pending' to 'awaiting_confirmation' on non-card orders, so an
--   auto-confirm merchant's kitchen tickets are untouched).
--
--   TRUSTED org members (owner / active staff — POS / WalkInOrderDialog) keep
--   FULL control of initial_status (e.g. 'preparing' for a walk-in), exactly as
--   before — the WalkInOrderDialog "preparing" path is unchanged.
--
-- WORKING FLOWS PRESERVED
--   * Guest/customer card checkout already sent 'awaiting_confirmation' → identical.
--   * Guest/customer non-card order sending 'pending'/'awaiting_confirmation' →
--     honoured verbatim (no behaviour change for auto-confirm or non-auto-confirm).
--   * Guest/customer dine-in → client 'pending'/'awaiting_confirmation' honoured.
--   * Owner/staff POS → client status honoured (e.g. 'preparing') — unchanged.
--   * Pricing/floor/promo/inventory/customer-linkage logic is BYTE-FOR-BYTE the
--     same as 20260608020000; ONLY the status assignment block changed.
--
-- SAFE TO RE-RUN: pure CREATE OR REPLACE FUNCTION (idempotent). No DDL/data change.
-- NOT auto-applied — the founder runs this in the Supabase SQL editor against the
-- live project after the C1 migration (20260608020000) is already applied.
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
  -- F4 additions: server-authoritative confirmation gate inputs.
  v_settings jsonb;
  v_dine_in boolean;
  v_online_card_enabled boolean;
  v_pay_mode text;
  v_needs_approval boolean;
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
    IF v_sale IS NOT NULL
       AND (v_sale_start IS NULL OR v_sale_start <= now())
       AND (v_sale_end   IS NULL OR v_sale_end   >= now()) THEN
      v_unit := LEAST(COALESCE(v_price, 0), v_sale);
    ELSE
      v_unit := COALESCE(v_price, 0);
    END IF;
    v_unit := GREATEST(0, v_unit);

    -- ---- Extras (priced from the DB, never from the client) ---------------
    v_extras := COALESCE((
      SELECT SUM(GREATEST(0, COALESCE(m.price_delta, 0)))
      FROM jsonb_array_elements(COALESCE(v_item->'added_extras', '[]'::jsonb)) AS ae(value)
      LEFT JOIN LATERAL (
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
  v_floor := GREATEST(0, v_subtotal - v_discount);

  IF NOT COALESCE(v_is_org_member, false) AND p_total < (v_floor - v_tolerance) THEN
    RAISE EXCEPTION
      'Order total (% cents) is below the authoritative minimum for these items (% cents). Please refresh your cart and try again.',
      p_total, v_floor;
  END IF;

  v_fulfillment := NULLIF(p_payload->>'fulfillment_type', '')::public.fulfillment_type;
  v_dine_in := COALESCE((p_payload->>'dine_in')::boolean, false);

  -- ========================================================================
  -- F4 — SERVER-AUTHORITATIVE initial_status (for untrusted callers).
  -- ========================================================================
  -- TRUSTED org members (owner / active staff — POS / WalkInOrderDialog) keep FULL
  -- control of initial_status (e.g. 'preparing' for a walk-in) — unchanged.
  --
  -- For an UNTRUSTED guest/customer caller we constrain the status to ONLY the two
  -- legitimate storefront values and force the card-hold gate server-side:
  --   1. CARD-REQUIRED order (the merchant takes online card for this fulfillment)
  --      ⇒ FORCE 'awaiting_confirmation', ignoring the client value. This is the
  --      core fix: an unpaid card order can NEVER be injected straight into the
  --      kitchen, and can never escape the awaiting_confirmation auto-decline that
  --      voids the manual-capture hold.
  --   2. Otherwise (non-card / dine-in) HONOUR the client's choice ONLY if it is
  --      'pending' or 'awaiting_confirmation' (the exact two values the storefronts
  --      send today); ANY other value ('preparing'/'ready'/'completed'/'declined')
  --      is coerced to 'awaiting_confirmation'. This closes the free-meal injection
  --      while leaving every legitimate non-card flow byte-for-byte unchanged.
  IF COALESCE(v_is_org_member, false) THEN
    v_status := COALESCE(
      NULLIF(p_payload->>'initial_status', '')::public.order_status,
      'pending'::public.order_status
    );
  ELSE
    SELECT settings INTO v_settings
      FROM public.organizations
      WHERE id = p_org_id;

    v_online_card_enabled := COALESCE((v_settings->'payments'->>'online_card_enabled')::boolean, false);
    -- BACK-COMPAT (mirrors parseSettings in src/services/settings.ts): a merchant
    -- who enabled online card BEFORE pay_mode existed has no stored pay_mode —
    -- derive it as card-enabled→'both' so a legacy card order is still recognised
    -- as card-required and held for confirmation.
    v_pay_mode := COALESCE(
      NULLIF(v_settings->'payments'->>'pay_mode', ''),
      CASE WHEN v_online_card_enabled THEN 'both' ELSE 'venue' END
    );

    -- A card-required order = the merchant takes online card AND this is not a
    -- dine-in order (dine-in always pays at the venue, mirrors the storefronts).
    v_needs_approval :=
      v_online_card_enabled AND v_pay_mode <> 'venue' AND NOT v_dine_in;

    IF v_needs_approval THEN
      -- Card order — the hold must wait for owner-confirm. Non-negotiable.
      v_status := 'awaiting_confirmation'::public.order_status;
    ELSE
      -- Non-card / dine-in — honour ONLY the two safe storefront values; coerce
      -- anything else (an injected kitchen-bound status) to awaiting_confirmation.
      v_status := COALESCE(
        NULLIF(p_payload->>'initial_status', '')::public.order_status,
        'pending'::public.order_status
      );
      IF v_status NOT IN ('pending'::public.order_status, 'awaiting_confirmation'::public.order_status) THEN
        v_status := 'awaiting_confirmation'::public.order_status;
      END IF;
    END IF;
  END IF;

  -- Stored total = the displayed p_total the customer agreed to (>= v_floor for
  -- untrusted orders, validated above).
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
    v_dine_in,
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
-- NOTE on the auto-decline backstop (intentionally NOT changed here).
-- =============================================================================
-- The audit's F4 also floated extending auto_decline_stale_orders to reap stale
-- UNPAID 'pending'/'preparing' orders. That backstop is UNNECESSARY once the
-- status is server-authoritative above: an untrusted (guest/customer) caller can
-- no longer create an unpaid CARD-REQUIRED order at 'pending' — any order that
-- pays online by card is FORCED to 'awaiting_confirmation', which the existing
-- cron already reaps. A 'pending' untrusted order is only ever produced when the
-- merchant's own settings say no card / auto-confirm (a legitimate kitchen
-- ticket), so it must NOT be auto-killed. We therefore deliberately leave
-- auto_decline_stale_orders (20260609040000) UNCHANGED — adding a pending/preparing
-- sweep would also be a NO-OP at order-respond (its claim RPC only transitions
-- status='awaiting_confirmation') and could wrongly target legitimate paid/cash
-- tickets. The source fix is the correct and sufficient boundary.
--
-- =============================================================================
-- FOUNDER NOTE — RUN MANUALLY in the Supabase SQL editor (idempotent / safe).
-- No edge-function deploy required for this migration. After applying:
--   (a) Guest card order on an online-card merchant (non-dine-in)
--       -> 'awaiting_confirmation' (forced, even if the client tampers it).
--   (b) Guest tampered initial_status='preparing'/'completed' on a card order
--       -> 'awaiting_confirmation'; on a non-card order -> coerced to
--       'awaiting_confirmation' too (never the injected kitchen-bound status).
--   (c) Guest non-card order sending 'pending' (e.g. auto-confirm merchant) or
--       'awaiting_confirmation' -> honoured verbatim (unchanged behaviour).
--   (d) Owner/staff walk-in (WalkInOrderDialog) -> 'preparing' honoured (unchanged).
-- =============================================================================


-- #############################################################################
-- RLS & WRITE-GUARDS AREA — F6 (loyalty self-edit), F7 (org payment cols),
-- F16 (orders money cols), todo-6.4 (customer PII scope), search_path sweep
-- Mirrors supabase/migrations/20260611020000_rls_write_guards.sql
-- No edge-function deploy required for this section.
-- #############################################################################

-- =============================================================================
-- RLS & WRITE-GUARDS — 2026-06-11 security audit (docs/SECURITY_AUDIT_2026-06-11.md)
-- Area: rls-writeguards.  Closes F6, F7, F16, todo-6.4 PII scope, and the
-- SECURITY-DEFINER search_path-hijack class.  STRICTLY ADDITIVE + IDEMPOTENT:
-- only BEFORE-UPDATE guard triggers + a policy swap + ALTER FUNCTION SET
-- search_path on already-existing functions.  No table/column/enum changes; no
-- change to the working flows (online card charge, capture/decline, refund,
-- guest checkout, get_public_* RPCs).
-- =============================================================================
--
-- Trust model used by every guard below (matches guard_org_payment_columns /
-- guard_subdomain_slug):
--   * auth.uid() IS NULL  -> a TRUSTED server write (service_role key or a
--     SECURITY DEFINER path invoked by an edge function carrying no end-user JWT,
--     e.g. order-respond / refund-order via record_order_refund / stripe+square
--     webhooks). These set settled-money state legitimately -> PASS THROUGH.
--   * auth.uid() IS NOT NULL -> an UNTRUSTED end-user REST write (owner, staff,
--     or customer/guest JWT). For these we PIN the protected columns back to OLD
--     so the rest of the UPDATE still succeeds (we revert, never RAISE, so a
--     benign form re-send of an unchanged value is not rejected and the rest of
--     the row still saves).


-- =============================================================================
-- F6 (HIGH) — customers may NOT self-edit their redeemable loyalty balance.
-- =============================================================================
-- THREAT: policy "Customers update own record" (20260419061246) is
-- FOR UPDATE USING/CHECK (user_id = auth.uid()) with NO column restriction
-- (RLS has no column-level WITH CHECK). So a logged-in customer can
-- `PATCH /rest/v1/customers?user_id=eq.<self> {"total_points":9999999}` and
-- redeem rewards never earned. The legitimate award/redeem path is the
-- server-side adjust_loyalty_points RPC (called ONLY from the owner/staff
-- dashboard — Loyalty.tsx / WalkInOrderDialog.tsx — never by the customer).
--
-- FIX: pin total_points / milestone_spend_cents ONLY when the writer IS the
-- customer whose row this is (auth.uid() = OLD.user_id) — i.e. exactly the
-- customer-self-UPDATE path. This is surgically narrow:
--   * customer self-edit (auth.uid() = OLD.user_id) -> PINNED  ✅ closes F6
--   * owner / manager / adjust_loyalty_points (auth.uid() <> customer.user_id,
--     a DIFFERENT person) -> NOT pinned, award/redeem still works
--   * service_role / SECURITY DEFINER server write (auth.uid() NULL) -> PASS
-- We deliberately DO NOT pin the consent/opt-in columns here: upsert_my_consent
-- (guest-checkout, 20260608010000) is a SECURITY DEFINER RPC that legitimately
-- writes consent on the caller's OWN row (auth.uid() = user_id) — pinning those
-- would break guest consent capture. The money risk in F6 is the redeemable
-- points balance; consent-record takeover is tracked separately as F19.
CREATE OR REPLACE FUNCTION public.guard_customer_loyalty_self_edit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  -- Trusted server path (service_role / definer edge write): allow.
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Only the customer editing their OWN row may hit this branch's pin. Staff/
  -- owner writes target a row whose user_id is the CUSTOMER's (not the staff's),
  -- so v_uid <> OLD.user_id and they pass through untouched (adjust_loyalty_points
  -- runs in the owner/staff session and must keep working).
  IF OLD.user_id IS NOT NULL AND OLD.user_id = v_uid THEN
    NEW.total_points          := OLD.total_points;
    NEW.milestone_spend_cents := OLD.milestone_spend_cents;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_customer_loyalty_self_edit ON public.customers;
CREATE TRIGGER trg_guard_customer_loyalty_self_edit
  BEFORE UPDATE ON public.customers
  FOR EACH ROW EXECUTE FUNCTION public.guard_customer_loyalty_self_edit();


-- =============================================================================
-- F7 (HIGH) — apply the staged org payment-column write guard to live.
-- =============================================================================
-- guard_org_payment_columns (20260609050000) was authored but headed
-- "STAGE FOR FOUNDER REVIEW before applying", so it is plausibly NOT live.
-- Re-assert it here (idempotent CREATE OR REPLACE + DROP/CREATE TRIGGER) so an
-- owner can never self-activate payment routing
-- (payment_provider / square_payment_ready / square_merchant_id /
-- square_location_id / charges_enabled / payouts_enabled / stripe_account_id)
-- over REST. Definition is byte-identical to 20260609050000 — re-running both
-- is a no-op.
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
  -- (name, settings, branding, hours, ...) proceeds normally.
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

DROP TRIGGER IF EXISTS trg_guard_org_payment_columns ON public.organizations;
CREATE TRIGGER trg_guard_org_payment_columns
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.guard_org_payment_columns();


-- =============================================================================
-- F16 (MEDIUM) — org members (incl. low-trust "service" staff) may NOT directly
-- UPDATE settled-money columns on orders.
-- =============================================================================
-- THREAT: orders RLS is a blanket FOR ALL ("Org members manage orders" +
-- "Staff manage org orders") with no column restriction, and no payment guard
-- exists on public.orders. So any owner/manager/service JWT can
-- `PATCH /rest/v1/orders?id=eq.<id> {"payment_status":"paid"}` (or rewrite
-- refund/total columns) with no real capture/refund behind it, skewing the
-- denormalized GMV + /impact numbers.
--
-- FIX: BEFORE UPDATE trigger pinning the SETTLED-MONEY columns for any non-NULL
-- auth.uid() writer. Only the trusted service-role / SECURITY DEFINER money
-- paths (auth.uid() NULL) may mutate them:
--   * order-respond (service client)            -> sets payment_status on capture/decline
--   * stripe-webhook / square-webhook (service) -> payment_status / payment ids
--   * record_order_refund (definer, granted service_role; called by refund-order
--     edge fn with the service key) -> refund_amount_cents / refunded_at / payment_status
-- We pin ONLY money columns — NOT status / declined_at / denial_reason — so the
-- authenticated-JWT SECURITY DEFINER void_my_unpaid_order (guest abandon path,
-- 20260611002000, auth.uid() NON-null) keeps working: it only touches status /
-- declined_at / denial_reason, none of which are pinned here.
CREATE OR REPLACE FUNCTION public.guard_order_payment_columns()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  -- Trusted server path (service_role / definer money RPCs): allow.
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Untrusted org-member / staff REST write: pin settled-money state to OLD.
  -- (The rest of the order — status moves through the kanban, notes, courier
  -- fields, table_number, etc. — still updates normally.)
  NEW.payment_status            := OLD.payment_status;
  NEW.payment_method            := OLD.payment_method;
  NEW.total_amount              := OLD.total_amount;
  NEW.stripe_payment_intent_id  := OLD.stripe_payment_intent_id;
  NEW.square_payment_id         := OLD.square_payment_id;
  NEW.square_location_id        := OLD.square_location_id;
  NEW.refund_amount_cents       := OLD.refund_amount_cents;
  NEW.refunded_at               := OLD.refunded_at;
  NEW.refund_reason             := OLD.refund_reason;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_payment_columns ON public.orders;
CREATE TRIGGER trg_guard_order_payment_columns
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.guard_order_payment_columns();


-- =============================================================================
-- todo-6.4 — restrict customer PII (SELECT) to owner + manager only.
-- =============================================================================
-- THREAT: "Staff view customers" (20260427063540) granted SELECT on the full
-- customers row (name / email / phone / addresses / birthday) to ANY active
-- staff via is_staff_of_org(...) — including kitchen/service roles who have no
-- business reading the CRM. The companion write policy "Managers manage
-- customers" is already correctly scoped to role='manager', and owners reach
-- customers via "Org members manage customers" (current_org_id()). So dropping
-- the broad staff-SELECT policy leaves owner + manager access intact and removes
-- only the over-broad kitchen/service read.
DROP POLICY IF EXISTS "Staff view customers" ON public.customers;

-- Re-create the SELECT explicitly scoped to manager-role staff (owners keep
-- access through the org-members FOR ALL policy; this only re-adds the manager
-- read that the dropped broad policy used to also cover).
DROP POLICY IF EXISTS "Managers view customers" ON public.customers;
CREATE POLICY "Managers view customers"
ON public.customers FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.staff_accounts
  WHERE user_id = auth.uid()
    AND organization_id = customers.organization_id
    AND role = 'manager'
    AND is_active = true
));


-- =============================================================================
-- search_path-hijack — every SECURITY DEFINER function MUST pin search_path.
-- =============================================================================
-- A SECURITY DEFINER function with no `SET search_path` resolves unqualified
-- names against the CALLER's search_path, so an attacker who can create objects
-- in a schema earlier on that path can shadow a referenced table/function and
-- have it run as the function owner (privilege escalation). Every definer fn in
-- the migrations already pins it; this catalog-driven sweep is a belt-and-braces
-- backstop that also covers any DRIFT-created definer functions on live
-- (e.g. adjust_loyalty_points, which exists only on the live DB and is not in
-- any migration). Idempotent: it ALTERs ONLY definer functions in `public` that
-- currently have NO search_path set, to `SET search_path = public, extensions`
-- (the extensions schema is included so that pgcrypto functions — digest, crypt,
-- gen_salt — resolved unqualified inside any affected SECURITY DEFINER function
-- continue to work without fully-qualified names).
DO $sweep$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name,
           p.oid::regprocedure AS fn_sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true                                   -- SECURITY DEFINER
      AND NOT EXISTS (                                          -- no search_path config yet
        SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}'::text[])) AS cfg
        WHERE cfg ILIKE 'search_path=%'
      )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions', r.fn_sig);
    RAISE NOTICE 'search_path pinned on %', r.fn_sig;
  END LOOP;
END
$sweep$;


-- #############################################################################
-- RPC-MASKING AREA — F3 (CRITICAL), F30 (LOW), F18 (MEDIUM)
-- Restore the full denylist on the public/member SECURITY DEFINER read RPCs.
-- Mirrors supabase/migrations/20260611030000_remask_public_rpcs.sql
-- #############################################################################

-- =============================================================================
-- WHY (audit F3/F30/F18)
--   * F3 (CRITICAL): migration ordering left the AUTHORITATIVE live body of
--     get_public_storefront at 20260611000700 (publish-gate), which re-created
--     it with only the ORIGINAL 7-column denylist — silently DROPPING the ~13
--     masks 20260610070000 had added. Every PUBLISHED storefront's anon read
--     re-leaks Square merchant identity, payment-readiness flags, contact_email,
--     unsalted account-recovery answer hashes (security_questions), and per-org
--     financial counters to ANY anonymous visitor → an account-takeover chain
--     via account-recover. This block sorts AFTER 20260611000700, merging the
--     publish-gate JOIN with the COMPLETE denylist (the exact column set
--     20260610070000 proved valid on live — phone_otp_attempts does NOT exist on
--     live and is therefore NOT masked, avoiding a 42703 drift error).
--   * F30 (LOW): get_member_org's staff (NOT-owner) branch left contact_email,
--     security_questions, square_payment_ready, charges_enabled, payouts_enabled,
--     payment_provider, founding_merchant, and settings.payments VISIBLE to
--     low-trust staff (kitchen/service auth = a 6-digit PIN). security_questions
--     are unsalted recovery-answer hashes. Closed here; OWNER branch unchanged.
--   * F18 (MEDIUM): get_order_by_id (anon /order/:id tracker) left orders.notes
--     UNMASKED — guest checkout stuffs the guest's full name+phone+EMAIL into it.
--     The tracker never renders notes, so we null it (customer_id +
--     shipping_address KEPT — the tracker reads both).
--   Idempotent (CREATE OR REPLACE). No data change. RUN LAST.
-- =============================================================================

-- F3 — get_public_storefront(slug): publish gate + FULL denylist.
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
  SELECT o.* INTO r
  FROM public.organizations o
  JOIN public.storefront_config c
    ON c.organization_id = o.id
   AND c.is_published = true
  WHERE o.subdomain_slug = lower(p_slug)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  r.owner_phone := NULL;
  r.owner_full_name := NULL;
  r.abn := NULL;
  r.business_address := NULL;
  r.stripe_account_id := NULL;
  r.phone_otp_hash := NULL;
  r.phone_otp_expires_at := NULL;
  r.security_questions := NULL;
  r.contact_email := NULL;

  r.square_merchant_id := NULL;
  r.square_location_id := NULL;
  r.square_payment_ready := NULL;
  r.charges_enabled := NULL;
  r.payouts_enabled := NULL;

  r.email_used_this_month := NULL;
  r.email_topup_credits := NULL;
  r.sms_topup_credits := NULL;
  r.sms_used_this_month := NULL;
  r.total_donations_cents := NULL;
  r.founding_merchant := NULL;

  -- KEPT VISIBLE: r.payment_provider (public card SDK routes on it), r.settings.
  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_storefront(text) TO anon, authenticated;

-- F30 — get_member_org(): close the staff-branch leak.
-- R3 refinement: payment_provider and settings.payments are NOT masked for staff
-- (Operations payments page needs them; they contain only {stripe|square} +
-- online_card_enabled/pay_mode — merchant config, not secrets).
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
    r.owner_phone := NULL;
    r.owner_full_name := NULL;
    r.abn := NULL;
    r.business_address := NULL;
    r.stripe_account_id := NULL;
    r.phone_otp_hash := NULL;
    r.phone_otp_expires_at := NULL;
    r.security_questions := NULL;       -- F30
    r.contact_email := NULL;            -- F30

    r.square_merchant_id := NULL;
    r.square_location_id := NULL;
    r.square_payment_ready := NULL;     -- F30
    r.charges_enabled := NULL;          -- F30
    r.payouts_enabled := NULL;          -- F30
    -- payment_provider: NOT nulled — staff need it for the Operations payments page
    -- (routes the card SDK; value is only {stripe|square}, not a secret).
    r.founding_merchant := NULL;        -- F30

    r.email_used_this_month := NULL;
    r.email_topup_credits := NULL;
    r.sms_used_this_month := NULL;
    r.sms_topup_credits := NULL;
    r.total_donations_cents := NULL;

    -- settings.payments: NOT stripped — contains only online_card_enabled +
    -- pay_mode (merchant config the Operations page legitimately reads).
  END IF;

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_member_org() TO authenticated;

-- F18 — get_order_by_id(id): mask guest PII stuffed into notes.
CREATE OR REPLACE FUNCTION public.get_order_by_id(p_id uuid)
RETURNS SETOF public.orders
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.orders%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.orders WHERE id = p_id LIMIT 1;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  r.courier_driver_phone := NULL;
  r.stripe_payment_intent_id := NULL;
  r.square_payment_id := NULL;
  r.square_order_id := NULL;
  r.square_location_id := NULL;
  r.notes := NULL;                       -- F18: guest name·phone·EMAIL live here

  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_by_id(uuid) TO anon, authenticated;



-- #############################################################################
-- ABUSE / DoS / INVENTORY AREA — F11 (inventory restock), F12 (order-placement
-- rate-limit + concurrent-open cap), F13 (reservation rate-limit) + the captcha
-- founder-input note. Mirrors
-- supabase/migrations/20260611040000_abuse_dos_inventory_ratelimit.sql
-- NO edge-function redeploy required: the restock is done DB-side inside the
-- updated claim_order_for_response / void_my_unpaid_order RPCs, which order-respond
-- and the storefront already call by name (signatures unchanged). The rate-limit +
-- captcha integration ship in the FRONTEND bundle (Cloudflare rebuild).
-- #############################################################################

-- =============================================================================
-- ABUSE / DoS / INVENTORY — 2026-06-11 security audit
-- (docs/SECURITY_AUDIT_2026-06-11.md). Area: abuse-dos. Closes F11, F12, F13.
-- =============================================================================
-- STRICTLY ADDITIVE + IDEMPOTENT. No change to the working money flows (online
-- card charge, capture/decline, refund, get_public_* RPCs, guest checkout). This
-- file only:
--   1. adds an idempotent `orders.stock_released` flag + a restock helper, then
--      restocks committed inventory on EVERY terminal non-success transition
--      (decline / auto_decline / abandon-void) — closing the inventory-DoS (F11);
--   2. adds a tiny server-side rate-limit primitive (`abuse_throttle` table +
--      `rate_limit_hit` helper) and applies it to the two anon-reachable abuse
--      surfaces — `create_order_with_inventory` order placement (F12) and
--      `create_public_reservation` (F13) — for UNTRUSTED callers only, plus a
--      concurrent-open-unpaid-order cap on order placement.
--
-- CAPTCHA (Turnstile) is wired at the FRONTEND + Supabase-Auth-provider level —
-- see src/services/guestCheckout.ts + the FOUNDER-INPUT note at the bottom of
-- this file. There is no DB change needed for captcha; the founder must provision
-- the Turnstile site/secret keys and enable the Anonymous-provider captcha in the
-- Supabase Auth settings. This migration is the DEFENCE-IN-DEPTH server throttle
-- behind that captcha.
--
-- SAFE TO RE-RUN. NOT auto-applied — the founder runs this in the Supabase SQL
-- editor against the live project (pmnyhbhtkcfoozkinieo).
-- =============================================================================


-- #############################################################################
-- F11 (HIGH) — Restock committed inventory on decline / auto_decline / abandon.
-- #############################################################################
-- THREAT: create_order_with_inventory() permanently decrements products.stock_
-- quantity the instant the order row is written — BEFORE any payment authorizes.
-- The decline / auto_decline / abandon-void paths only release the card hold;
-- NOTHING restocks. So every abandoned/declined/timed-out order leaks tracked
-- stock forever — a trivial way to "sell out" limited items in seconds (loop
-- fresh anon sessions, add qty = current stock, abandon the card dialog).
--
-- FIX: restock on every terminal non-success transition, IDEMPOTENTLY. A one-way
-- `stock_released` flag guarantees a retried cron / double-call can never
-- double-restock. Only stock-TRACKED products (stock_quantity IS NOT NULL) and
-- only within the order's own org are touched.

-- 1a. One-way idempotency flag. DEFAULT false; existing rows get false.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS stock_released boolean NOT NULL DEFAULT false;

-- 1b. Idempotent restock helper. Returns true if it restocked THIS call (i.e. it
--     won the compare-and-swap on stock_released), false if already released.
--     SECURITY DEFINER so it can UPDATE products regardless of the caller's RLS;
--     it is only ever invoked from the two trusted server paths below
--     (claim_order_for_response decline branch + void_my_unpaid_order), so it is
--     granted to service_role only and NOT to anon/authenticated.
CREATE OR REPLACE FUNCTION public.restock_order_inventory(p_order_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org uuid;
  v_items jsonb;
  v_item jsonb;
  v_pid uuid;
  v_qty int;
BEGIN
  -- Compare-and-swap: claim the release in ONE statement. If stock_released was
  -- already true (a prior decline/abandon/cron already restocked) this updates 0
  -- rows and we no-op — so a racing/retried caller can never double-restock.
  UPDATE public.orders
  SET stock_released = true
  WHERE id = p_order_id
    AND stock_released = false
  RETURNING organization_id, COALESCE(line_items, '[]'::jsonb)
    INTO v_org, v_items;

  IF NOT FOUND THEN
    RETURN false;  -- already released (or unknown id) — nothing to do.
  END IF;

  IF jsonb_typeof(v_items) <> 'array' THEN
    RETURN true;   -- nothing sensible to restock, but the flag is set.
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items)
  LOOP
    v_pid := NULLIF(v_item->>'product_id', '')::uuid;
    v_qty := GREATEST(0, COALESCE(NULLIF(v_item->>'quantity', '')::int, 0));
    IF v_pid IS NOT NULL AND v_qty > 0 THEN
      -- Restock ONLY stock-tracked products (stock_quantity IS NOT NULL) in this
      -- order's OWN org — mirrors the decrement guard in create_order_with_inventory.
      UPDATE public.products
      SET stock_quantity = stock_quantity + v_qty
      WHERE id = v_pid
        AND organization_id = v_org
        AND stock_quantity IS NOT NULL;
    END IF;
  END LOOP;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.restock_order_inventory(uuid) TO service_role;


-- 1c. Wire restock into the DECLINE / AUTO_DECLINE path. claim_order_for_response
--     is the single authority that flips awaiting_confirmation -> declined (the
--     compare-and-swap that guarantees exactly one winner). Restocking HERE — in
--     the same transaction as the flip, for the decline actions only — ties the
--     restock to the terminal transition and inherits that exactly-once property
--     (restock_order_inventory is itself idempotent as a second belt). A CONFIRM
--     never restocks (the kitchen IS making the food). This is a pure additive
--     edit to the function body; the claim/CAS semantics + grants are unchanged.
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

  -- F11: a decline/auto_decline is a terminal non-success state — give the
  -- committed inventory back (idempotent; a CONFIRM intentionally does not).
  IF p_action <> 'confirm' THEN
    PERFORM public.restock_order_inventory(p_order_id);
  END IF;

  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_order_for_response(uuid, text, text) TO service_role;


-- 1d. Wire restock into the ABANDON-VOID path (the storefront's fast-path when a
--     customer closes the card dialog without paying). Same compare-and-swap +
--     ownership guard as before; we simply restock when the void actually flips a
--     row. The auth.uid() ownership EXISTS clause remains the boundary.
CREATE OR REPLACE FUNCTION public.void_my_unpaid_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voided boolean := false;
BEGIN
  UPDATE public.orders o
  SET
    status        = 'declined'::public.order_status,
    declined_at   = now(),
    denial_reason = 'Payment not completed'
  WHERE o.id = p_order_id
    AND o.status = 'awaiting_confirmation'                       -- compare-and-swap guard
    AND COALESCE(o.payment_status, 'unpaid') IN ('unpaid', 'pending')
    AND o.customer_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.id = o.customer_id
        AND c.user_id = auth.uid()                               -- caller owns this order
    );

  GET DIAGNOSTICS v_voided = ROW_COUNT;

  -- F11: only restock when THIS call actually voided the order (a miss — someone
  -- else's order, already paid/moved on, or unknown id — restocks nothing). The
  -- restock helper is itself idempotent via orders.stock_released.
  IF v_voided THEN
    PERFORM public.restock_order_inventory(p_order_id);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.void_my_unpaid_order(uuid) TO authenticated;


-- #############################################################################
-- F12 / F13 — Server-side rate-limiting for anon-reachable abuse surfaces.
-- #############################################################################
-- THREAT: guest checkout (create_order_with_inventory) + public reservations
-- (create_public_reservation) are GRANTed to anon and have NO server throttle, so
-- a bot mints unlimited anon sessions and floods orders / books every table /
-- burns email reputation. Captcha (below) is the front line; this is the
-- defence-in-depth DB throttle that holds even if a token-less call slips through.
--
-- A tiny fixed-window counter table keyed by (subject, action). subject = the
-- caller's auth.uid() (every order/reservation caller carries one — guests via
-- the anon session). It is intentionally simple + self-pruning per key; it is NOT
-- a substitute for an edge/Cloudflare rate-limit, it is a cheap last line.

CREATE TABLE IF NOT EXISTS public.abuse_throttle (
  subject     text        NOT NULL,
  action      text        NOT NULL,
  window_start timestamptz NOT NULL DEFAULT now(),
  hits        int         NOT NULL DEFAULT 0,
  PRIMARY KEY (subject, action)
);

ALTER TABLE public.abuse_throttle ENABLE ROW LEVEL SECURITY;
-- No policies => deny-by-default for anon/authenticated REST. Only the SECURITY
-- DEFINER rate_limit_hit() function (and service_role) ever touches it.

-- Fixed-window counter. Returns TRUE when the caller is OVER the limit (i.e. the
-- caller should be rejected). p_window is a Postgres interval literal text like
-- '1 minute' / '1 hour'. SECURITY DEFINER so it can write the deny-by-default
-- table; STABLE-unsafe (it mutates), so plain VOLATILE.
CREATE OR REPLACE FUNCTION public.rate_limit_hit(
  p_subject text,
  p_action  text,
  p_max     int,
  p_window  text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window interval := p_window::interval;
  v_hits int;
BEGIN
  IF p_subject IS NULL OR p_subject = '' THEN
    -- No subject to key on => cannot throttle; do not block (the auth gate /
    -- captcha is the real boundary). Fail-open here is deliberate: blocking on a
    -- null key would reject legitimate callers, not bots.
    RETURN false;
  END IF;

  -- Upsert the per-(subject,action) bucket. If the existing window has elapsed,
  -- RESET it (new window, hits = 1); otherwise INCREMENT.
  INSERT INTO public.abuse_throttle AS t (subject, action, window_start, hits)
  VALUES (p_subject, p_action, now(), 1)
  ON CONFLICT (subject, action) DO UPDATE
    SET window_start = CASE
          WHEN t.window_start < now() - v_window THEN now()
          ELSE t.window_start
        END,
        hits = CASE
          WHEN t.window_start < now() - v_window THEN 1
          ELSE t.hits + 1
        END
  RETURNING hits INTO v_hits;

  RETURN v_hits > p_max;
END;
$$;

REVOKE ALL ON FUNCTION public.rate_limit_hit(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rate_limit_hit(text, text, int, text) TO service_role;


-- #############################################################################
-- F12 — Throttle + concurrent-open-order cap on create_order_with_inventory.
-- #############################################################################
-- We re-state the function (CREATE OR REPLACE) carrying the FULL body from
-- 20260611010000 (F4) UNCHANGED, inserting two guards right after the
-- v_is_org_member trust resolution and BEFORE any inventory decrement:
--   (a) a fixed-window rate limit (max N orders / window) per caller uid, and
--   (b) a concurrent-open-unpaid-order cap (no more than M live
--       awaiting_confirmation/pending orders open at once per caller).
-- BOTH apply to UNTRUSTED callers only (guests/customers) — trusted owner/staff
-- POS is never throttled. Everything else is byte-for-byte identical to F4.

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
  v_settings jsonb;
  v_dine_in boolean;
  v_online_card_enabled boolean;
  v_pay_mode text;
  v_needs_approval boolean;
  -- F12 abuse guards.
  v_open_orders int;
  v_tolerance constant int := 1;
  -- Tunables: max orders / minute per caller, and max concurrently-open unpaid
  -- orders. Generous for a real human, lethal for a bot loop.
  v_max_per_min constant int := 8;
  v_max_open    constant int := 12;
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

    -- F12 (a) — fixed-window rate limit per caller uid. A real customer never
    -- places > v_max_per_min orders/minute; a bot loop does. Rejected BEFORE any
    -- inventory is touched, so a throttled call cannot leak stock.
    IF public.rate_limit_hit(v_auth_uid::text, 'place_order', v_max_per_min, '1 minute') THEN
      RAISE EXCEPTION 'Too many orders in a short time. Please wait a moment and try again.'
        USING ERRCODE = 'check_violation';
    END IF;

    -- F12 (b) — concurrent open-unpaid-order cap. Caps how many live
    -- awaiting_confirmation/pending orders this caller can have open at once, so a
    -- bot cannot accumulate thousands of phantom tickets even under the rate limit.
    SELECT count(*) INTO v_open_orders
    FROM public.orders o
    JOIN public.customers c ON c.id = o.customer_id
    WHERE c.user_id = v_auth_uid
      AND o.status IN ('awaiting_confirmation'::public.order_status, 'pending'::public.order_status)
      AND COALESCE(o.payment_status, 'unpaid') IN ('unpaid', 'pending')
      AND o.created_at > now() - interval '1 hour';
    IF v_open_orders >= v_max_open THEN
      RAISE EXCEPTION 'You have too many orders awaiting payment. Please complete or cancel them first.'
        USING ERRCODE = 'check_violation';
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

    IF v_sale IS NOT NULL
       AND (v_sale_start IS NULL OR v_sale_start <= now())
       AND (v_sale_end   IS NULL OR v_sale_end   >= now()) THEN
      v_unit := LEAST(COALESCE(v_price, 0), v_sale);
    ELSE
      v_unit := COALESCE(v_price, 0);
    END IF;
    v_unit := GREATEST(0, v_unit);

    v_extras := COALESCE((
      SELECT SUM(GREATEST(0, COALESCE(m.price_delta, 0)))
      FROM jsonb_array_elements(COALESCE(v_item->'added_extras', '[]'::jsonb)) AS ae(value)
      LEFT JOIN LATERAL (
        SELECT round((el.value->>'price_delta')::numeric)::int AS price_delta
        FROM jsonb_array_elements(COALESCE(v_extras_list, '[]'::jsonb)) AS el(value)
        WHERE (el.value->>'name') = (ae.value->>'name')
          AND COALESCE((el.value->>'available')::boolean, true) <> false
        LIMIT 1
      ) AS m ON true
    ), 0);

    v_subtotal := v_subtotal + (v_unit + v_extras) * v_quantity;
  END LOOP;

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

  v_floor := GREATEST(0, v_subtotal - v_discount);

  IF NOT COALESCE(v_is_org_member, false) AND p_total < (v_floor - v_tolerance) THEN
    RAISE EXCEPTION
      'Order total (% cents) is below the authoritative minimum for these items (% cents). Please refresh your cart and try again.',
      p_total, v_floor;
  END IF;

  v_fulfillment := NULLIF(p_payload->>'fulfillment_type', '')::public.fulfillment_type;
  v_dine_in := COALESCE((p_payload->>'dine_in')::boolean, false);

  -- F4 — SERVER-AUTHORITATIVE initial_status (for untrusted callers). UNCHANGED.
  IF COALESCE(v_is_org_member, false) THEN
    v_status := COALESCE(
      NULLIF(p_payload->>'initial_status', '')::public.order_status,
      'pending'::public.order_status
    );
  ELSE
    SELECT settings INTO v_settings
      FROM public.organizations
      WHERE id = p_org_id;

    v_online_card_enabled := COALESCE((v_settings->'payments'->>'online_card_enabled')::boolean, false);
    v_pay_mode := COALESCE(
      NULLIF(v_settings->'payments'->>'pay_mode', ''),
      CASE WHEN v_online_card_enabled THEN 'both' ELSE 'venue' END
    );

    v_needs_approval :=
      v_online_card_enabled AND v_pay_mode <> 'venue' AND NOT v_dine_in;

    IF v_needs_approval THEN
      v_status := 'awaiting_confirmation'::public.order_status;
    ELSE
      v_status := COALESCE(
        NULLIF(p_payload->>'initial_status', '')::public.order_status,
        'pending'::public.order_status
      );
      IF v_status NOT IN ('pending'::public.order_status, 'awaiting_confirmation'::public.order_status) THEN
        v_status := 'awaiting_confirmation'::public.order_status;
      END IF;
    END IF;
  END IF;

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
    v_dine_in,
    NULLIF(p_payload->>'table_number', '')
  )
  RETURNING * INTO v_order;

  RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_inventory(uuid, uuid, integer, jsonb)
TO anon, authenticated;


-- #############################################################################
-- F13 — Throttle on create_public_reservation (anon-reachable table booking).
-- #############################################################################
-- We re-state the function carrying the FULL body from 20260529110000 UNCHANGED,
-- inserting ONE rate-limit guard at the top for UNTRUSTED callers (a caller that
-- is NOT the org owner/staff). Keyed on auth.uid() (booking carries one — guests
-- via the anon session). Generous per-window cap so a real human booking a couple
-- of tables is fine; a bot looping every (table,slot) is stopped. Everything else
-- is byte-for-byte identical to 20260529110000.

CREATE OR REPLACE FUNCTION public.create_public_reservation(
  p_org_id uuid,
  p_customer_name text,
  p_customer_email text,
  p_customer_phone text,
  p_party_size int,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_notes text,
  p_table_id uuid,
  p_auto_confirm boolean
)
RETURNS TABLE (
  id uuid,
  status reservation_status,
  cancellation_token uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_accepts boolean;
  v_id uuid;
  v_status reservation_status;
  v_token uuid;
  v_name text;
  v_table_id uuid;
  v_settings jsonb;
  v_max_party_size int;
  v_min_lead_hours int;
  v_booking_window_days int;
  -- F13 abuse guard.
  v_auth_uid uuid := auth.uid();
  v_is_member boolean;
  v_max_per_window constant int := 6;   -- bookings per caller per window
BEGIN
  -- F13 — rate limit anon/customer callers (NOT the org's own owner/staff who may
  -- legitimately key in many bookings from the dashboard). Keyed on auth.uid().
  v_is_member :=
    EXISTS (SELECT 1 FROM public.organizations WHERE id = p_org_id AND owner_id = v_auth_uid)
    OR public.is_staff_of_org(v_auth_uid, p_org_id);
  IF NOT COALESCE(v_is_member, false)
     AND v_auth_uid IS NOT NULL
     AND public.rate_limit_hit(v_auth_uid::text, 'create_reservation', v_max_per_window, '10 minutes') THEN
    RAISE EXCEPTION 'Too many booking attempts. Please wait a few minutes and try again.'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT reservation_accept_online, COALESCE(settings->'reservations', '{}'::jsonb)
    INTO v_accepts, v_settings
    FROM public.organizations
    WHERE id = p_org_id;

  IF NOT COALESCE(v_accepts, false) THEN
    RAISE EXCEPTION 'This business is not accepting online bookings';
  END IF;

  v_name := trim(COALESCE(p_customer_name, ''));
  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Customer name is required';
  END IF;

  v_max_party_size := COALESCE((v_settings->>'max_party_size')::int, 50);
  IF p_party_size IS NULL OR p_party_size < 1 OR p_party_size > v_max_party_size THEN
    RAISE EXCEPTION 'Invalid party size';
  END IF;

  IF p_start_at IS NULL OR p_end_at IS NULL OR p_end_at <= p_start_at THEN
    RAISE EXCEPTION 'Invalid time window';
  END IF;

  v_min_lead_hours := COALESCE((v_settings->>'min_lead_hours')::int, 2);
  IF p_start_at <= now() + (v_min_lead_hours || ' hours')::interval THEN
    RAISE EXCEPTION 'Reservation time is too soon';
  END IF;

  v_booking_window_days := COALESCE((v_settings->>'booking_window_days')::int, 90);
  IF p_start_at > now() + (v_booking_window_days || ' days')::interval THEN
    RAISE EXCEPTION 'Reservation time is outside the booking window';
  END IF;

  SELECT t.id INTO v_table_id
  FROM public.tables AS t
  WHERE t.organization_id = p_org_id
    AND t.is_active = true
    AND t.seats >= p_party_size
    AND (p_table_id IS NULL OR t.id = p_table_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.reservations AS r
      WHERE r.table_id = t.id
        AND r.status IN ('requested', 'confirmed', 'seated')
        AND r.start_at < p_end_at
        AND r.end_at > p_start_at
    )
  ORDER BY t.seats ASC, t.number ASC
  LIMIT 1
  FOR UPDATE;

  IF v_table_id IS NULL THEN
    RAISE EXCEPTION 'No available table for that time';
  END IF;

  INSERT INTO public.reservations (
    organization_id, customer_name, customer_email, customer_phone,
    party_size, start_at, end_at, notes, table_id, status
  ) VALUES (
    p_org_id,
    v_name,
    NULLIF(trim(COALESCE(p_customer_email, '')), ''),
    NULLIF(trim(COALESCE(p_customer_phone, '')), ''),
    p_party_size,
    p_start_at,
    p_end_at,
    NULLIF(trim(COALESCE(p_notes, '')), ''),
    v_table_id,
    CASE WHEN p_auto_confirm
      THEN 'confirmed'::reservation_status
      ELSE 'requested'::reservation_status
    END
  )
  RETURNING reservations.id, reservations.status, reservations.cancellation_token
    INTO v_id, v_status, v_token;

  id := v_id;
  status := v_status;
  cancellation_token := v_token;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_public_reservation(
  uuid, text, text, text, int, timestamptz, timestamptz, text, uuid, boolean
) TO anon, authenticated;


-- =============================================================================
-- FOUNDER-INPUT — CAPTCHA (Cloudflare Turnstile). REQUIRED before wide launch.
-- =============================================================================
-- The frontend (src/services/guestCheckout.ts + the storefront/reservation call
-- sites) now threads a Turnstile token through guest-checkout anon sign-in when
-- VITE_TURNSTILE_SITE_KEY is set. To ACTIVATE captcha end-to-end the founder must:
--   1. Create a Cloudflare Turnstile widget; note the SITE key + SECRET key.
--   2. Set VITE_TURNSTILE_SITE_KEY in the Cloudflare Pages build env (frontend).
--   3. In the Supabase dashboard: Auth -> Settings -> Bot & Abuse Protection,
--      enable CAPTCHA (Turnstile) and paste the SECRET key. This makes Supabase
--      REJECT token-less signInAnonymously() — closing the unbounded anon-row
--      faucet at the provider, which is the real F12/F13 front line.
-- This migration's rate-limit is the defence-in-depth layer BEHIND that captcha;
-- it is NOT a replacement for it. A per-IP Cloudflare edge rate-limit on the
-- storefront origin is also recommended.
-- =============================================================================
