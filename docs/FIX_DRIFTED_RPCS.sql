-- =============================================================================
-- HOTFIX — repair get_public_storefront + get_order_by_id broken by schema drift.
-- =============================================================================
-- The H-5 / INT-H1 masking migrations (20260609060000, 20260610060000) re-created
-- these two PUBLIC, customer-facing RPCs reproducing the repo's function bodies,
-- which reference columns that DO NOT EXIST on the live DB (the repo migration
-- history drifted ahead of live):
--   * organizations.phone_otp_attempts  -> get_public_storefront 42703 at runtime
--   * orders.receipt_token              -> get_order_by_id 42703 at runtime
-- Both RPCs therefore error for every caller (storefront load + order tracker).
-- This migration re-creates BOTH against the ACTUAL live schema (verified column
-- by column): get_public_storefront WITHOUT the phone_otp_attempts mask (that
-- column isn't on live; nothing to mask), and get_order_by_id looking up the anon
-- path by orders.id (the order UUID IS the public tracker token on this DB; there
-- is no receipt_token column). ALL the security masks are preserved.
-- Idempotent CREATE OR REPLACE. Run LAST. No data change.
-- (Follow-up, separate: reconcile the repo migration history with the live schema.)
-- =============================================================================

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

  -- Owner-PII / recovery / auth denylist.
  r.owner_phone := NULL;
  r.owner_full_name := NULL;
  r.abn := NULL;
  r.business_address := NULL;
  r.stripe_account_id := NULL;
  r.phone_otp_hash := NULL;
  r.phone_otp_expires_at := NULL;
  r.security_questions := NULL;
  r.contact_email := NULL;

  -- Square merchant identity + payment-processor internals (payment_provider kept).
  r.square_merchant_id := NULL;
  r.square_location_id := NULL;
  r.square_payment_ready := NULL;
  r.charges_enabled := NULL;
  r.payouts_enabled := NULL;

  -- Financial counters / business internals.
  r.email_used_this_month := NULL;
  r.email_topup_credits := NULL;
  r.sms_topup_credits := NULL;
  r.sms_used_this_month := NULL;
  -- NOTE: organizations.phone_otp_attempts does NOT exist on this DB -> mask removed.
  r.total_donations_cents := NULL;
  r.founding_merchant := NULL;

  -- KEPT VISIBLE: r.payment_provider (routes the public card SDK).

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_storefront(text) TO anon, authenticated;

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
  -- This DB has no orders.receipt_token; the order UUID is the public tracker
  -- token (the /order/:id link). Anon look-up is by id, with sensitive fields
  -- masked below (unguessable UUID acts as the bearer token).
  SELECT * INTO r
  FROM public.orders
  WHERE id = p_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Courier mask.
  r.courier_driver_phone := NULL;

  -- H-5: provider payment-reference ids — tracker shows payment_status only.
  r.stripe_payment_intent_id := NULL;
  r.square_payment_id := NULL;
  r.square_order_id := NULL;

  -- INT-H1: Square location id is payment-processor identity — never on the tracker.
  r.square_location_id := NULL;

  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_by_id(uuid) TO anon, authenticated;
