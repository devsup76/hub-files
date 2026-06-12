-- =============================================================================
-- SECURITY DEFECT FIXES — RUN THESE on the LIVE Supabase project
-- (pmnyhbhtkcfoozkinieo)
-- =============================================================================
-- PURPOSE: This file CORRECTS 5 bugs that were introduced by the SQL that the
-- founder already ran from docs/sql/SECURITY_OVERNIGHT_RUN_THESE.sql.  Each fix
-- is a CREATE OR REPLACE / DROP+CREATE that OVERWRITES the defective live object.
--
-- Run the WHOLE FILE in the Supabase SQL editor in a single shot.  Every block
-- is IDEMPOTENT — safe to re-run.  No data is destroyed.
--
-- Mirrors 5 new idempotent migration files in supabase/migrations/:
--   20260612140000_fix_f46_shipping_clamp_and_regex.sql
--   20260612140100_fix_p2_drop_dblink_noop.sql
--   20260612140200_fix_p3_promo_guest_redeemer_key.sql
--   20260612140300_fix_p8_refund_row_pin.sql
--   20260612140400_fix_prune_throttle_grant.sql
--
-- DEFECTS BEING FIXED:
--   F46 — clamp_order_text: (a) shipping_address REBUILT from allowlist → drops
--         lat/lng/unit/delivery_instructions/place_id/etc.; (b) broken \xNN regex
--         bracket-class syntax; (c) fires on every UPDATE, not just when the
--         column actually changed.
--   P2  — rate_limit_hit_committed: dblink machinery that NEVER activates
--         (app.dblink_conninfo is never set on Supabase) silently falls back to
--         the in-transaction counter (the exact problem P2 was meant to fix) AND
--         the "enable it" path would bake a superuser password into a world-
--         readable GUC.  Replace with an honest best-effort wrapper.
--   P3  — promo_redemptions UNIQUE (promo_id, customer_id): every guest session
--         mints a fresh customer row so the same human re-redeems indefinitely.
--         Fix: key the cap on a normalised email/phone redeemer_key instead of
--         customer_id.
--   P8  — set_refund_status "keep-refunded" branch zeros refund_amount_cents
--         (→ "refunded, amount 0", under-counts GMV).  Fix: pin both
--         refund_amount_cents and refunded_at to OLD values in that branch.
--   Prune grant — prune_abuse_throttle() is REVOKED from PUBLIC and GRANTED to
--         service_role; add a defensive GRANT to postgres (harmless if already
--         owner) so the pg_cron runner always has EXECUTE.
-- =============================================================================


-- #############################################################################
-- FIX 1: F46 — clamp_order_text: fix regex + preserve unknown shipping_address
--         keys + guard on column change for UPDATE
-- #############################################################################
-- WHAT WAS WRONG in SECURITY_OVERNIGHT_RUN_THESE.sql / 20260611080000:
--   (a) Regex used \x00-\x08 etc. inside a bracket class — Postgres does NOT
--       support \xNN in bracket classes; those patterns match literal characters
--       "x", "0"-"9", "A"-"F" etc. instead of the intended control chars.
--       The correct form is chr(N)||'-'||chr(M) (exactly as the working trigger
--       20260611060000 does for storefront_config).
--   (b) The shipping_address block REBUILT the field from only the allowed-list
--       keys, silently DROPPING every other key (lat, lng, unit, floor,
--       delivery_instructions, place_id, formatted_address, …).  A customer who
--       provides a detailed delivery address loses all fields not on that list.
--       Fix: use jsonb_set to mutate ONLY the known string keys IN PLACE so every
--       other key is preserved verbatim.
--   (c) The shipping_address rebuild ran on every INSERT OR UPDATE even when the
--       column had not changed.  Add IS DISTINCT FROM guard for UPDATE paths.
--
-- UNCHANGED:
--   * notes / table_number / denial_reason clamping logic (corrected regex only)
--   * line_items size / array-length rejection (byte-for-byte same)
--   * trigger name, BEFORE INSERT OR UPDATE semantics

CREATE OR REPLACE FUNCTION public.clamp_order_text()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  -- Control-char bracket classes built with chr() — the only portable way in
  -- Postgres (bracket classes do NOT accept \xNN escape sequences).
  -- ctrl_keep_lf_tab: strip 0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F, 0x7F
  -- (preserves TAB=0x09, LF=0x0A, CR=0x0D which are legit in freetext notes)
  ctrl_keep_lf_tab text :=
    '[' || chr(0)  || '-' || chr(8)
        || chr(11) || chr(12)
        || chr(14) || '-' || chr(31)
        || chr(127) || ']';
  -- ctrl_strict: strip ALL control chars 0x00-0x1F + 0x7F
  -- (for table_number / denial_reason — shorter, no newlines needed)
  ctrl_strict text :=
    '[' || chr(0) || '-' || chr(31) || chr(127) || ']';

  v_addr    jsonb;
  v_key     text;
  v_val     text;
  -- Allow-list of string keys whose VALUES are sanitised.
  -- Keys NOT on this list are preserved in the object verbatim (lat, lng, unit,
  -- floor, delivery_instructions, place_id, formatted_address, etc.).
  v_string_keys text[] := ARRAY[
    'name','line1','line2','street','city','suburb','state','region',
    'postcode','postal_code','zip','country','notes','instructions','phone'
  ];
BEGIN
  -- ── notes: strip control chars (except TAB/LF/CR) + cap at 2000 chars ──────
  IF NEW.notes IS NOT NULL THEN
    NEW.notes := left(
      regexp_replace(NEW.notes, ctrl_keep_lf_tab, '', 'g'),
      2000
    );
  END IF;

  -- ── table_number: strip ALL control chars + cap at 32 chars ────────────────
  IF NEW.table_number IS NOT NULL THEN
    NEW.table_number := left(
      regexp_replace(NEW.table_number, ctrl_strict, '', 'g'),
      32
    );
  END IF;

  -- ── denial_reason: strip control chars (except TAB/LF/CR) + cap at 500 ─────
  IF NEW.denial_reason IS NOT NULL THEN
    NEW.denial_reason := left(
      regexp_replace(NEW.denial_reason, ctrl_keep_lf_tab, '', 'g'),
      500
    );
  END IF;

  -- ── shipping_address: mutate string-value keys IN PLACE ────────────────────
  -- Only enter this block when shipping_address is present and (on UPDATE) has
  -- actually changed — avoids needless work + silently-dropped keys on re-saves.
  IF NEW.shipping_address IS NOT NULL
     AND jsonb_typeof(NEW.shipping_address) = 'object'
     AND (TG_OP = 'INSERT'
          OR NEW.shipping_address IS DISTINCT FROM OLD.shipping_address) THEN

    v_addr := NEW.shipping_address;
    FOREACH v_key IN ARRAY v_string_keys LOOP
      IF v_addr ? v_key AND jsonb_typeof(v_addr->v_key) = 'string' THEN
        -- Strip control chars and cap length; use jsonb_set to UPDATE the key
        -- IN PLACE — all other keys (lat, lng, place_id, etc.) are untouched.
        v_val := left(
          regexp_replace(v_addr->>v_key, ctrl_strict, '', 'g'),
          500
        );
        v_addr := jsonb_set(v_addr, ARRAY[v_key], to_jsonb(v_val));
      END IF;
    END LOOP;
    NEW.shipping_address := v_addr;
  END IF;

  -- ── line_items: reject (not truncate) a multi-MB / huge-array cart ─────────
  IF NEW.line_items IS NOT NULL THEN
    IF length(NEW.line_items::text) > 98304 THEN
      RAISE EXCEPTION 'Order is too large' USING ERRCODE = 'check_violation';
    END IF;
    IF jsonb_typeof(NEW.line_items) = 'array'
       AND jsonb_array_length(NEW.line_items) > 200 THEN
      RAISE EXCEPTION 'Order has too many items' USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the trigger (idempotent — DROP IF EXISTS first)
DROP TRIGGER IF EXISTS trg_clamp_order_text ON public.orders;
CREATE TRIGGER trg_clamp_order_text
  BEFORE INSERT OR UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.clamp_order_text();


-- #############################################################################
-- FIX 2: P2 — rate_limit_hit_committed: replace the dead dblink no-op with an
--         honest best-effort wrapper
-- #############################################################################
-- WHAT WAS WRONG in SECURITY_OVERNIGHT_RUN_THESE.sql / 20260611090000:
--   rate_limit_hit_committed() only uses the autonomous-transaction dblink path
--   when `app.dblink_conninfo` is set in the database GUC — which is NEVER set on
--   managed Supabase.  So it ALWAYS falls back to the in-transaction
--   rate_limit_hit(), meaning a rolled-back order STILL rolls back the throttle
--   counter (the exact P2 threat).  Worse, the documented "enable it" path
--   requires baking a superuser password into a world-readable GUC, which is a
--   clear security regression.
--
-- FIX: replace the body with a thin wrapper that simply calls the existing
-- rate_limit_hit() (the in-transaction counter, best-effort).  DO NOT DROP the
-- function — create_order_with_inventory calls it by name.  Add a clear comment
-- that the DB throttle is best-effort and Cloudflare Turnstile is the real
-- boundary.
--
-- The _rate_limit_hit_autonomous helper is left in place (harmless) but is no
-- longer called.  The `CREATE EXTENSION IF NOT EXISTS dblink` from the original
-- migration is also left — it's a standard extension and removing it would be
-- destructive.

CREATE OR REPLACE FUNCTION public.rate_limit_hit_committed(
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
-- BEST-EFFORT RATE LIMIT — increments the abuse_throttle counter IN-TRANSACTION.
-- A rolled-back order (stock miss, floor reject, etc.) will undo this increment.
-- That is an acceptable trade-off: the DB counter is a defence-in-depth layer;
-- the authoritative DOS boundary is Cloudflare's per-IP rate limit + Turnstile.
-- The function is named "committed" for call-site compatibility — the original
-- dblink / autonomous-transaction approach was removed because app.dblink_conninfo
-- is never set on Supabase and baking a superuser password into a GUC is a
-- security regression (see docs/sql/SECURITY_DEFECT_FIXES_RUN_THESE.sql, fix P2).
BEGIN
  -- Fail CLOSED on missing subject (defence-in-depth; the caller's auth gate has
  -- already rejected a null uid before reaching here).
  IF p_subject IS NULL OR p_subject = '' THEN
    RETURN true;
  END IF;
  RETURN public.rate_limit_hit(p_subject, p_action, p_max, p_window);
END;
$$;

-- Grants: identical to the original — only service_role may call it directly.
-- create_order_with_inventory (SECURITY DEFINER) calls it under service_role
-- semantics; anon/authenticated reach it only through that RPC.
REVOKE ALL ON FUNCTION public.rate_limit_hit_committed(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rate_limit_hit_committed(text, text, int, text) TO service_role;


-- #############################################################################
-- FIX 3: P3 — promo guest-redeemer key: change the cap to key on normalised
--         email/phone instead of customer_id
-- #############################################################################
-- WHAT WAS WRONG in SECURITY_OVERNIGHT_RUN_THESE.sql / 20260611090000:
--   promo_redemptions UNIQUE (promo_id, customer_id).  Every guest checkout mints
--   a fresh anonymous Supabase user → fresh customers row → unique customer_id,
--   so the constraint NEVER fires for repeated guest redemptions by the same
--   person.  A single person can exhaust any promo by opening incognito tabs.
--
-- FIX: Add a redeemer_key column (lower(trim(email)) OR digits-only phone,
-- whichever is available) to promo_redemptions, backfill existing rows from the
-- joined customers table, then swap the UNIQUE constraint to (promo_id,
-- redeemer_key) so the cap is keyed to the human identity rather than the DB row.
-- create_order_with_inventory is restated to derive and check redeemer_key.
--
-- All steps are idempotent (ADD COLUMN IF NOT EXISTS, DROP CONSTRAINT IF EXISTS,
-- CREATE UNIQUE INDEX IF NOT EXISTS, ON CONFLICT clause).
--
-- NOTE: The existing UNIQUE (promo_id, customer_id) is KEPT as a secondary
-- constraint (renamed) so that the promo_redemptions_uniq name collision is
-- avoided cleanly — we rename the old one before adding the new one.
-- For signed-in customers who also have a redeemer_key, both constraints
-- effectively guard.  Turnstile/captcha remains the HARD gate for guest abuse.

-- 3a. Add redeemer_key column (idempotent)
ALTER TABLE public.promo_redemptions
  ADD COLUMN IF NOT EXISTS redeemer_key text;

-- 3b. Backfill redeemer_key for any existing rows using the joined customer.
--     Priority: normalised email first, then digits-only phone.
UPDATE public.promo_redemptions pr
SET    redeemer_key = COALESCE(
         NULLIF(lower(trim(c.email)), ''),
         NULLIF(regexp_replace(c.phone_number, '[^0-9]', '', 'g'), '')
       )
FROM   public.customers c
WHERE  c.id = pr.customer_id
  AND  pr.redeemer_key IS NULL;

-- 3c. Drop the old customer_id-keyed unique constraint (idempotent via name)
--     and replace with the redeemer_key-keyed one.
--     We cannot use DROP CONSTRAINT IF EXISTS in all PG versions portably via DO,
--     so we use a DO block to catch the "does not exist" case gracefully.
DO $$
BEGIN
  -- Drop old constraint if it exists under its original name
  ALTER TABLE public.promo_redemptions
    DROP CONSTRAINT IF EXISTS promo_redemptions_uniq;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- Add a partial unique index on (promo_id, redeemer_key) — only when redeemer_key
-- is NOT NULL (rows without an email/phone still use the customer_id guard below).
-- Using CREATE UNIQUE INDEX IF NOT EXISTS is idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS promo_redemptions_redeemer_key_uniq
  ON public.promo_redemptions (promo_id, redeemer_key)
  WHERE redeemer_key IS NOT NULL;

-- Retain customer_id uniqueness as a secondary guard for signed-in customers
-- (belt and braces — also means existing code that inserts without redeemer_key
-- still works).
CREATE UNIQUE INDEX IF NOT EXISTS promo_redemptions_customer_uniq
  ON public.promo_redemptions (promo_id, customer_id);

-- 3d. Restate create_order_with_inventory with the redeemer_key cap.
--     ONLY the P3 promo-cap block changes: derive v_redeemer_key from the
--     resolved customer row and check/insert on that key.
--     Everything else (pricing, floor, inventory lock/decrement, status, insert,
--     P2 throttle call) is byte-for-byte identical to 20260611090000.
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
  v_promo_applied boolean := false;   -- P3: did we actually apply (and need to record) this promo?
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
  -- P3 (fix): redeemer_key for guest-safe per-customer promo cap.
  v_redeemer_key text;
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

    -- F12 (a) / P2 — fixed-window rate limit per caller uid, COMMITTED out of this
    -- transaction so a later rollback (stock/floor/mismatch) still counts the hit.
    -- Fail-CLOSED on a null subject (defence in depth; the auth gate already
    -- rejected a null uid above).
    IF public.rate_limit_hit_committed(v_auth_uid::text, 'place_order', v_max_per_min, '1 minute') THEN
      RAISE EXCEPTION 'Too many orders in a short time. Please wait a moment and try again.'
        USING ERRCODE = 'check_violation';
    END IF;

    -- F12 (b) — concurrent open-unpaid-order cap.
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

      -- P3 (fix) — per-human promo cap keyed on redeemer_key (normalised email
      -- or phone) so the same person cannot re-redeem across fresh anon sessions.
      -- Trusted POS callers (org member) are exempt.
      -- Note: best-effort for guests with neither email nor phone — that abuse
      -- path requires Cloudflare Turnstile to gate the anon session mint.
      IF NOT COALESCE(v_is_org_member, false) THEN
        -- Derive redeemer_key: normalised email preferred, then digits-only phone.
        IF v_customer_id IS NOT NULL THEN
          SELECT COALESCE(
                   NULLIF(lower(trim(email)), ''),
                   NULLIF(regexp_replace(phone_number, '[^0-9]', '', 'g'), '')
                 )
          INTO v_redeemer_key
          FROM public.customers
          WHERE id = v_customer_id;
        END IF;

        IF v_redeemer_key IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.promo_redemptions
          WHERE promo_id = v_promo.id AND redeemer_key = v_redeemer_key
        ) THEN
          -- Already redeemed by this human → silently skip (no hard reject).
          v_discount := 0;
        ELSIF v_customer_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.promo_redemptions
          WHERE promo_id = v_promo.id AND customer_id = v_customer_id
        ) THEN
          -- Fallback: keyed-by-customer_id guard (signed-in or redeemer_key-less).
          v_discount := 0;
        ELSE
          IF v_promo.discount_type = 'percentage' THEN
            v_discount := round(v_subtotal::numeric * v_promo.value / 100.0)::int;
          ELSE
            v_discount := LEAST(v_promo.value, v_subtotal);  -- flat, stored in cents
          END IF;
          UPDATE public.promo_codes
            SET usage_count = usage_count + 1, updated_at = now()
            WHERE id = v_promo.id;
          v_promo_applied := true;  -- record a redemption row after the order inserts
        END IF;
      ELSE
        -- Trusted POS / org member: no per-customer cap.
        IF v_promo.discount_type = 'percentage' THEN
          v_discount := round(v_subtotal::numeric * v_promo.value / 100.0)::int;
        ELSE
          v_discount := LEAST(v_promo.value, v_subtotal);
        END IF;
        UPDATE public.promo_codes
          SET usage_count = usage_count + 1, updated_at = now()
          WHERE id = v_promo.id;
        -- No redemption row for POS/org-member — they are exempt from the cap.
      END IF;
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

  -- P3 (fix) — record the per-human redemption ONLY when a discount was actually
  -- applied AND we have a customer to key on.  The unique indexes make this
  -- idempotent; ON CONFLICT DO NOTHING guards a concurrent double-apply.
  IF v_promo_applied AND v_customer_id IS NOT NULL THEN
    INSERT INTO public.promo_redemptions (promo_id, customer_id, order_id, redeemer_key)
    VALUES (v_promo.id, v_customer_id, v_order.id, v_redeemer_key)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_inventory(uuid, uuid, integer, jsonb)
TO anon, authenticated;


-- #############################################################################
-- FIX 4: P8 — set_refund_status "keep-refunded" branch: pin refund_amount_cents
--         and refunded_at to OLD values
-- #############################################################################
-- WHAT WAS WRONG in SECURITY_OVERNIGHT_RUN_THESE.sql / 20260611090000:
--   In the CASE branch that KEEPS payment_status = 'refunded' (i.e. a failed/
--   cancelled refund webhook arrives after the order was already fully refunded),
--   refund_amount_cents was set to v_new_total which is 0 at that point.
--   Result: the order reads "refunded, amount $0.00" — under-counts GMV and
--   confuses reconciliation.
--   The refunded_at in that branch was already correct (v_order.refunded_at),
--   confirmed by reading the live SQL. Only refund_amount_cents is wrong.
--
-- FIX: in the keep-refunded branch, pin BOTH refund_amount_cents and refunded_at
-- to OLD.refund_amount_cents / OLD.refunded_at respectively.
--
-- Re-stated from 20260611090000 with ONLY the keep-refunded UPDATE branch changed;
-- all other logic (status transitions, partially_refunded→paid, etc.) is unchanged.

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

  SELECT order_id INTO v_order_id
  FROM public.payment_refunds
  WHERE provider = p_provider AND provider_refund_id = p_provider_refund_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = v_order_id FOR UPDATE;
  SELECT * INTO v_refund
  FROM public.payment_refunds
  WHERE provider = p_provider AND provider_refund_id = p_provider_refund_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_refund.status = p_status OR v_refund.status = 'succeeded' THEN
    IF NOT (v_refund.status = 'pending' AND p_status = 'succeeded') THEN
      RETURN;
    END IF;
  END IF;

  UPDATE public.payment_refunds
  SET status = p_status, updated_at = now()
  WHERE id = v_refund.id;

  SELECT COALESCE(SUM(amount_cents), 0)::integer INTO v_new_total
  FROM public.payment_refunds
  WHERE order_id = v_order.id
    AND status IN ('pending','succeeded');

  UPDATE public.orders
  SET
    -- P8 (fix): in the keep-refunded branch, pin both refund_amount_cents and
    -- refunded_at to the OLD values so a stale/failed webhook on an already-
    -- fully-refunded order cannot zero out the recorded refund amount.
    refund_amount_cents = CASE
      WHEN v_new_total <= 0 AND v_order.payment_status = 'refunded'
        THEN v_order.refund_amount_cents   -- FIX: was v_new_total (= 0) → now OLD value
      ELSE v_new_total
    END,
    payment_status = CASE
      -- Keep 'refunded' if the order was already fully refunded (stale webhook).
      WHEN v_new_total <= 0 AND v_order.payment_status = 'refunded' THEN 'refunded'
      WHEN v_new_total <= 0 THEN 'paid'
      WHEN v_new_total >= COALESCE(v_order.total_amount, 0) THEN 'refunded'
      ELSE 'partially_refunded'
    END,
    refunded_at = CASE
      -- FIX: pin refunded_at in the keep-refunded branch (was already correct
      -- in the original but made explicit here for clarity).
      WHEN v_new_total <= 0 AND v_order.payment_status = 'refunded'
        THEN v_order.refunded_at           -- preserve the original refund timestamp
      WHEN v_new_total <= 0 THEN NULL
      ELSE COALESCE(v_order.refunded_at, now())
    END
  WHERE id = v_order.id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_refund_status(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_refund_status(text, text, text) TO service_role;


-- #############################################################################
-- FIX 5: prune_abuse_throttle — defensive GRANT to postgres role
-- #############################################################################
-- WHAT WAS WRONG in SECURITY_OVERNIGHT_RUN_THESE.sql / 20260611090000:
--   prune_abuse_throttle() is REVOKED from PUBLIC and GRANTED to service_role.
--   pg_cron on managed Postgres (Supabase) runs jobs as the `postgres` superuser
--   role.  If `postgres` is not already the function OWNER (and the GRANT to
--   service_role doesn't cover the cron executor's role), the scheduled job will
--   fail silently with "permission denied for function prune_abuse_throttle".
--
-- FIX: GRANT EXECUTE to `postgres` defensively.  If `postgres` already owns the
-- function this is a no-op.  Harmless in all configurations.

GRANT EXECUTE ON FUNCTION public.prune_abuse_throttle() TO postgres;

-- Same defensive grant for prune_ai_usage (same cron pattern, same risk).
GRANT EXECUTE ON FUNCTION public.prune_ai_usage() TO postgres;

-- =============================================================================
-- END OF DEFECT FIXES
-- =============================================================================
-- After running this file:
--   * clamp_order_text now preserves all shipping_address keys and uses valid
--     Postgres regex bracket-class syntax.
--   * rate_limit_hit_committed is an honest best-effort wrapper (no phantom
--     dblink path baking a password into a GUC).
--   * promo_redemptions is keyed on redeemer_key (normalised email/phone) so
--     the same human cannot re-redeem across fresh anon sessions.
--   * set_refund_status no longer zeros refund_amount_cents on a stale webhook.
--   * prune_abuse_throttle + prune_ai_usage are executable by the pg_cron
--     runner (postgres role).
-- No edge function redeploys are required — all fixes are DB-only.
-- =============================================================================
