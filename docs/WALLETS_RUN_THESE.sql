-- =============================================================================
-- WALLETS — run these in the Supabase SQL editor BEFORE deploying the edge fns.
-- Both are ADDITIVE + IDEMPOTENT (safe to re-run). Order doesn't matter between
-- them, but BOTH must run before square-payment / order-respond are deployed:
--   * 20260612170000 creates try_claim_square_auth() — square-payment CALLS it,
--     so deploying square-payment first would break the live Square card flow.
--   * 20260612160000 adds orders.customer_email — order-respond READS it.
-- =============================================================================

-- ----- (1) R7 guest-PII: freeze the receipt recipient on the order -----------
-- =============================================================================
-- R7 — freeze the receipt recipient onto the order at creation time.
-- =============================================================================
-- order-respond resolves the receipt recipient LIVE from the customers row. A
-- guest's anonymous session persists across DIFFERENT people on a shared device
-- (kiosk / family iPad), and upsert_my_consent overwrites customers.email — so a
-- still-pending order's receipt (full items, total, AU tax-invoice PII) could be
-- emailed to the NEXT guest. Layer A (guestCheckout.ts) gives each guest order its
-- own anon uid → its own customers row; Layer B (this migration) freezes the
-- recipient onto the order so it can NEVER move after placement, even if the row
-- is later mutated.
--
-- Additive + idempotent: a BEFORE INSERT trigger snapshots customers.email/name
-- onto the order. create_order_with_inventory is NOT modified (the order RPC that
-- already bit us with chr(0) is left untouched). order-respond prefers
-- orders.customer_email over the live join; old orders (null snapshot) fall back.
-- =============================================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS customer_email text,
  ADD COLUMN IF NOT EXISTS customer_name  text;

CREATE OR REPLACE FUNCTION public.snapshot_order_customer()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER          -- read customers regardless of the inserter's RLS context
SET search_path = public
AS $$
BEGIN
  -- Fill only when not already supplied; INSERT only — never re-point an existing
  -- order's recipient on a later UPDATE.
  IF NEW.customer_email IS NULL AND NEW.customer_id IS NOT NULL THEN
    SELECT email, name
      INTO NEW.customer_email, NEW.customer_name
      FROM public.customers
     WHERE id = NEW.customer_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_snapshot_order_customer ON public.orders;
CREATE TRIGGER trg_snapshot_order_customer
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.snapshot_order_customer();

-- =============================================================================
-- END 20260612160000
-- =============================================================================

-- ----- (2) R15/R16: Square atomic auth claim (no wallet double-authorize) -----
-- =============================================================================
-- R15/R16 — atomic claim so a Square WALLET double-tap can't double-authorize.
-- =============================================================================
-- Apple/Google Pay mint a NEW single-use source_id per tap, so a double-tap yields
-- two DIFFERENT idempotency keys -> Square does NOT dedup -> two authorizations (the
-- 2nd silently orphaning the 1st, which then lingers ~7 days). The client-side latch
-- covers a single tab; this is the cross-tab / concurrent-request fix: square-payment
-- claims the order atomically BEFORE CreatePayment, and only the winner proceeds.
-- Additive + idempotent.
-- =============================================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS square_auth_claim_at timestamptz;

-- Atomic conditional claim. Succeeds (returns true) only when the order has no Square
-- payment yet AND no live (<90s) claim. The UPDATE...WHERE is a single atomic
-- statement, so two concurrent callers serialize and exactly one wins. The 90s TTL
-- lets a retry reclaim if a winner crashed mid-authorize.
CREATE OR REPLACE FUNCTION public.try_claim_square_auth(p_order_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH claimed AS (
    UPDATE public.orders
       SET square_auth_claim_at = now()
     WHERE id = p_order_id
       AND square_payment_id IS NULL
       AND (square_auth_claim_at IS NULL
            OR square_auth_claim_at < now() - interval '90 seconds')
    RETURNING id
  )
  SELECT EXISTS (SELECT 1 FROM claimed);
$$;

-- Only the service-role edge function may claim (guests / anon must never call it
-- directly to grief an order's authorize).
REVOKE ALL ON FUNCTION public.try_claim_square_auth(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.try_claim_square_auth(uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.try_claim_square_auth(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.try_claim_square_auth(uuid) TO postgres;

-- =============================================================================
-- END 20260612170000
-- =============================================================================
