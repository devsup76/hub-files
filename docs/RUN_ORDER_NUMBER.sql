-- =============================================================================
-- Short human-friendly ORDER NUMBER — DAILY-RESETTING: #101..#999, resets to 101
-- each day, wraps back to 101 after 999.
-- =============================================================================
-- orders.id (UUID) stays the internal id + the /order/:id tracker token. orders.
-- order_number is the short reference people read (receipt, tracker, Orders, KDS,
-- docket). Per merchant: the first order of each day is #101, then 102, 103…; if a
-- merchant passes #999 in one day it wraps to #101. The day boundary is the
-- merchant's local day (Australia/Brisbane — the app default; per-merchant tz is a
-- later refinement). order_number is therefore NOT globally unique (it repeats
-- across days / on wrap) — that's fine, the UUID is the key; this is a display ref.
-- Additive + idempotent.
-- =============================================================================

-- Per-org daily counter: the last number issued + the local day it belongs to.
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS order_seq int NOT NULL DEFAULT 100;
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS order_seq_date date;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS order_number int;

-- Atomic per-org assignment with daily reset + wrap. UPDATE ... RETURNING locks the
-- org row so concurrent inserts for one merchant get distinct sequential numbers.
CREATE OR REPLACE FUNCTION public.assign_order_number()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Australia/Brisbane')::date;
BEGIN
  IF NEW.order_number IS NULL AND NEW.organization_id IS NOT NULL THEN
    UPDATE public.organizations
      SET order_seq = CASE
            WHEN order_seq_date IS DISTINCT FROM v_today THEN 101  -- first order today
            WHEN order_seq >= 999 THEN 101                         -- wrap after 999
            ELSE order_seq + 1
          END,
          order_seq_date = v_today
      WHERE id = NEW.organization_id
      RETURNING order_seq INTO NEW.order_number;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_order_number ON public.orders;
CREATE TRIGGER trg_assign_order_number
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_order_number();

-- Backfill existing orders: per org, per local DAY, 101..999 wrapping (so historical
-- orders read consistently with the live scheme).
WITH numbered AS (
  SELECT id,
         101 + ((row_number() OVER (
                   PARTITION BY organization_id,
                                (created_at AT TIME ZONE 'Australia/Brisbane')::date
                   ORDER BY created_at, id) - 1) % 899)::int AS n
  FROM public.orders
  WHERE order_number IS NULL
)
UPDATE public.orders o
  SET order_number = numbered.n
  FROM numbered
  WHERE o.id = numbered.id;

-- Seed each org's live counter from its most-recent order so the next live order
-- continues today's sequence (or resets to 101 if its last order was a prior day).
UPDATE public.organizations org
  SET order_seq = sub.last_num,
      order_seq_date = sub.last_day
  FROM (
    SELECT DISTINCT ON (organization_id) organization_id,
           order_number AS last_num,
           (created_at AT TIME ZONE 'Australia/Brisbane')::date AS last_day
    FROM public.orders
    WHERE order_number IS NOT NULL
    ORDER BY organization_id, created_at DESC, id DESC
  ) sub
  WHERE org.id = sub.organization_id;

CREATE INDEX IF NOT EXISTS orders_org_order_number_idx
  ON public.orders (organization_id, order_number);

-- Re-create get_order_by_id (live-schema-correct) so the anon tracker RPC is
-- re-planned WITH order_number (returns SETOF orders via %ROWTYPE → flows through).
-- All masks preserved.
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
  RETURN NEXT r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_by_id(uuid) TO anon, authenticated;
