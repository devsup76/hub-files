-- =====================================================================
-- FOUNDER_RUN_THESE.sql — overnight-fixes 2026-06-11
-- =====================================================================
-- Idempotent migrations from branch feat/overnight-fixes-2026-06-11.
-- Run in the Supabase SQL editor for project pmnyhbhtkcfoozkinieo, IN ORDER.
-- PREVIEW ONLY — do NOT apply until the founder signs off the branch.
-- After running, regenerate src/integrations/supabase/types.ts.
--
-- Each block is also a standalone file under repo/supabase/migrations/ — this
-- file is the consolidated copy for one-shot manual application.
-- =====================================================================


-- ---------------------------------------------------------------------
-- #7 — Unpublished storefronts must NOT be publicly reachable
--      (supabase/migrations/20260611000700_gate_public_storefront_on_publish.sql)
--
-- Gates the two anon storefront-read RPCs on a PUBLISHED storefront_config row,
-- matching the gate already on get_public_storefront_config. Pure tightening of
-- existing SECURITY DEFINER functions — no table policy loosened, owner-PII
-- null-out preserved. Frontend (Shop.tsx) degrades gracefully if not yet
-- applied (unpublished merchants simply keep loading as today).
-- ---------------------------------------------------------------------

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

  RETURN r;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_storefront(text) TO anon, authenticated;

-- DROP first: get_public_menu already exists with required_ingredients (added by
-- the ingredient-availability migration); Postgres cannot change a TABLE-returning
-- function's return type via CREATE OR REPLACE. Keep required_ingredients.
DROP FUNCTION IF EXISTS public.get_public_menu(uuid);

CREATE FUNCTION public.get_public_menu(p_org_id uuid)
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  title text,
  description text,
  price integer,
  price_unit text,
  sale_price integer,
  sale_starts_at timestamptz,
  sale_ends_at timestamptz,
  image_url text,
  category text,
  category_id uuid,
  tags text[],
  extras_list jsonb,
  ingredients_list text[],
  required_ingredients text[],
  allow_customization boolean,
  is_available boolean,
  stock_quantity integer,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.organization_id, p.title, p.description, p.price, p.price_unit,
         p.sale_price, p.sale_starts_at, p.sale_ends_at, p.image_url, p.category,
         p.category_id, p.tags, p.extras_list, p.ingredients_list, p.required_ingredients,
         p.allow_customization, p.is_available, p.stock_quantity, p.created_at
  FROM public.products p
  WHERE p.organization_id = p_org_id
    AND p.is_available = true
    AND EXISTS (
      SELECT 1
      FROM public.storefront_config c
      WHERE c.organization_id = p.organization_id
        AND c.is_published = true
    )
  ORDER BY p.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_menu(uuid) TO anon, authenticated;


-- ---------------------------------------------------------------------
-- #9 — Rate-limit storefront template + branding publish churn
--      (supabase/migrations/20260611000900_storefront_publish_rate_limit.sql)
--
-- Adds a rolling-24h publish counter to storefront_config and enforces it
-- inside the existing validate_storefront_config trigger (DB is authoritative —
-- a hand-rolled REST write can't bypass it). Limit: 10 publishes / 24h. Only an
-- actual publish (is_published = true) counts; unpublishing / reverting is free.
-- Idempotent (ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE). Frontend degrades
-- gracefully if NOT yet applied — without the columns the trigger never raises,
-- so publishing keeps working exactly as today.
-- ---------------------------------------------------------------------

ALTER TABLE public.storefront_config
  ADD COLUMN IF NOT EXISTS publish_count_today int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS publish_window_start timestamptz;

CREATE OR REPLACE FUNCTION public.validate_storefront_config()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  allowed_sections text[] := ARRAY[
    'hero','featured','categories','about','gallery','reviews','map','cta'
  ];
  s jsonb;
  k text;
  pk text;
  u jsonb;
  hsl_re text := '^\d{1,3}(\.\d+)?\s+\d{1,3}(\.\d+)?%\s+\d{1,3}(\.\d+)?%$';
  max_config_bytes int := 32768;  -- ~32 KB
  max_publishes_per_day int := 10;
BEGIN
  IF octet_length(NEW.sections::text)
     + octet_length(NEW.theme::text)
     + octet_length(NEW.hero::text) > max_config_bytes THEN
    RAISE EXCEPTION 'storefront config too large (max % bytes)', max_config_bytes;
  END IF;

  IF jsonb_typeof(NEW.sections) <> 'array' THEN
    RAISE EXCEPTION 'sections must be a json array';
  END IF;
  FOR s IN SELECT * FROM jsonb_array_elements(NEW.sections) LOOP
    IF NOT ((s->>'id') = ANY (allowed_sections)) THEN
      RAISE EXCEPTION 'bad section id %', s->>'id';
    END IF;
    IF jsonb_typeof(s->'props') = 'object' THEN
      FOR pk IN SELECT jsonb_object_keys(s->'props') LOOP
        IF pk LIKE '%\_url' OR pk LIKE '%\_urls' THEN
          IF jsonb_typeof(s->'props'->pk) = 'array' THEN
            FOR u IN SELECT * FROM jsonb_array_elements(s->'props'->pk) LOOP
              IF jsonb_typeof(u) = 'string'
                 AND left(u #>> '{}', 8) <> 'https://' THEN
                RAISE EXCEPTION 'section url must be https:// (% in %)', pk, s->>'id';
              END IF;
            END LOOP;
          ELSIF jsonb_typeof(s->'props'->pk) = 'string'
                AND left(s->'props'->>pk, 8) <> 'https://' THEN
            RAISE EXCEPTION 'section url must be https:// (% in %)', pk, s->>'id';
          END IF;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  FOR k IN SELECT jsonb_object_keys(NEW.theme) LOOP
    IF k LIKE '%_hsl' AND NOT ((NEW.theme->>k) ~ hsl_re) THEN
      RAISE EXCEPTION 'bad hsl token %', k;
    END IF;
    IF k = 'font_pair'
       AND NOT ((NEW.theme->>k) = ANY (ARRAY['modern','classic','bold'])) THEN
      RAISE EXCEPTION 'bad font_pair';
    END IF;
    IF k = 'radius'
       AND NOT ((NEW.theme->>k) = ANY (ARRAY['none','sm','md','lg','xl'])) THEN
      RAISE EXCEPTION 'bad radius';
    END IF;
  END LOOP;

  IF length(COALESCE(NEW.hero->>'headline', '')) > 120
     OR length(COALESCE(NEW.hero->>'subhead', '')) > 240
     OR length(COALESCE(NEW.hero->>'cta_label', '')) > 40 THEN
    RAISE EXCEPTION 'hero copy too long';
  END IF;

  -- Publish-rate limit (rolling 24h; only counts actual publishes).
  IF NEW.is_published THEN
    IF NEW.publish_window_start IS NULL
       OR NEW.publish_window_start < now() - interval '24 hours' THEN
      NEW.publish_window_start := now();
      NEW.publish_count_today := 1;
    ELSE
      IF COALESCE(NEW.publish_count_today, 0) >= max_publishes_per_day THEN
        RAISE EXCEPTION
          'storefront publish limit reached — try again later'
          USING ERRCODE = 'check_violation';
      END IF;
      NEW.publish_count_today := COALESCE(NEW.publish_count_today, 0) + 1;
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_storefront_config ON public.storefront_config;
CREATE TRIGGER trg_validate_storefront_config
  BEFORE INSERT OR UPDATE ON public.storefront_config
  FOR EACH ROW EXECUTE FUNCTION public.validate_storefront_config();


-- ---------------------------------------------------------------------
-- #16 — Smarter auto usernames (priya, priya2, priya17)
--      (supabase/migrations/20260611001100_next_available_username.sql)
--
-- SECURITY DEFINER helper that turns any base string (typically the business
-- name) into the FIRST AVAILABLE username, so owner signup can prefill a unique
-- suggestion + offer "use priyaN instead" on a clash. Modelled on
-- username_is_taken. Slugify mirrors the username_format CHECK
-- (^[a-z0-9._-]{3,30}$). GRANTed to anon + authenticated. Frontend (Auth.tsx)
-- degrades gracefully if not yet applied (falls back to the plain slug + the
-- existing username_is_taken check).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.next_available_username(_base text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base      text;
  v_candidate text;
  v_suffix    text;
  v_max_len   int := 30;
  v_n         int;
BEGIN
  v_base := lower(coalesce(_base, ''));
  v_base := regexp_replace(v_base, '[^a-z0-9._-]+', '', 'g');
  v_base := btrim(v_base, '._-');
  v_base := left(v_base, v_max_len);

  IF v_base IS NULL OR length(v_base) < 3 THEN
    v_base := 'user' || lpad((floor(random() * 10000))::int::text, 4, '0');
  END IF;

  FOR v_n IN 1..99 LOOP
    IF v_n = 1 THEN
      v_suffix := '';
    ELSE
      v_suffix := v_n::text;
    END IF;
    v_candidate := left(v_base, v_max_len - length(v_suffix)) || v_suffix;
    IF NOT EXISTS (SELECT 1 FROM public.usernames WHERE username = v_candidate) THEN
      RETURN v_candidate;
    END IF;
  END LOOP;

  FOR v_n IN 1..20 LOOP
    v_suffix := lpad((floor(random() * 10000))::int::text, 4, '0');
    v_candidate := left(v_base, v_max_len - length(v_suffix)) || v_suffix;
    IF NOT EXISTS (SELECT 1 FROM public.usernames WHERE username = v_candidate) THEN
      RETURN v_candidate;
    END IF;
  END LOOP;

  RETURN 'user' || lpad((floor(random() * 100000000))::bigint::text, 8, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_available_username(text) TO anon, authenticated;


-- ---------------------------------------------------------------------
-- #9 — Rate-limit storefront template + branding publish churn
--      (supabase/migrations/20260611001500_storefront_publish_rate_limit.sql)
--
-- DB-authoritative 10-publishes-per-24h cap on storefront_config.
-- Adds publish_count_today + publish_window_start columns and extends
-- the validate_storefront_config trigger. Also widens the template
-- allow-list in the trigger to include variants added since the original
-- migration (editorial/boutique/bold/kerb/daily/maison/rush/cantina).
-- Client-side 45s cooldown is a UX guard on top; the trigger is the hard gate.
-- ---------------------------------------------------------------------

ALTER TABLE public.storefront_config
  ADD COLUMN IF NOT EXISTS publish_count_today  int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS publish_window_start timestamptz;

CREATE OR REPLACE FUNCTION public.validate_storefront_config()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  allowed_sections text[] := ARRAY[
    'hero','featured','categories','about','gallery','reviews','map','cta'
  ];
  allowed_templates text[] := ARRAY[
    'classic','hero','grid','minimal','editorial','boutique','bold',
    'kerb','daily','maison','rush','cantina'
  ];
  s    jsonb;
  k    text;
  pk   text;
  u    jsonb;
  hsl_re text := '^\d{1,3}(\.\d+)?\s+\d{1,3}(\.\d+)?%\s+\d{1,3}(\.\d+)?%$';
  max_config_bytes  int := 32768;
  publish_day_limit int := 10;
BEGIN
  IF octet_length(NEW.sections::text)
     + octet_length(NEW.theme::text)
     + octet_length(NEW.hero::text) > max_config_bytes THEN
    RAISE EXCEPTION 'storefront config too large (max % bytes)', max_config_bytes;
  END IF;

  IF jsonb_typeof(NEW.sections) <> 'array' THEN
    RAISE EXCEPTION 'sections must be a json array';
  END IF;
  FOR s IN SELECT * FROM jsonb_array_elements(NEW.sections) LOOP
    IF NOT ((s->>'id') = ANY (allowed_sections)) THEN
      RAISE EXCEPTION 'bad section id %', s->>'id';
    END IF;
    IF jsonb_typeof(s->'props') = 'object' THEN
      FOR pk IN SELECT jsonb_object_keys(s->'props') LOOP
        IF pk LIKE '%\_url' OR pk LIKE '%\_urls' THEN
          IF jsonb_typeof(s->'props'->pk) = 'array' THEN
            FOR u IN SELECT * FROM jsonb_array_elements(s->'props'->pk) LOOP
              IF jsonb_typeof(u) = 'string'
                 AND left(u #>> '{}', 8) <> 'https://' THEN
                RAISE EXCEPTION 'section url must be https:// (% in %)', pk, s->>'id';
              END IF;
            END LOOP;
          ELSIF jsonb_typeof(s->'props'->pk) = 'string'
                AND left(s->'props'->>pk, 8) <> 'https://' THEN
            RAISE EXCEPTION 'section url must be https:// (% in %)', pk, s->>'id';
          END IF;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  IF NOT (NEW.template = ANY (allowed_templates)) THEN
    RAISE EXCEPTION 'unknown template %', NEW.template;
  END IF;

  FOR k IN SELECT jsonb_object_keys(NEW.theme) LOOP
    IF k LIKE '%_hsl' AND NOT ((NEW.theme->>k) ~ hsl_re) THEN
      RAISE EXCEPTION 'bad hsl token %', k;
    END IF;
    IF k = 'font_pair'
       AND NOT ((NEW.theme->>k) = ANY (ARRAY['modern','classic','bold'])) THEN
      RAISE EXCEPTION 'bad font_pair';
    END IF;
    IF k = 'radius'
       AND NOT ((NEW.theme->>k) = ANY (ARRAY['none','sm','md','lg','xl'])) THEN
      RAISE EXCEPTION 'bad radius';
    END IF;
  END LOOP;

  IF length(COALESCE(NEW.hero->>'headline', '')) > 120
     OR length(COALESCE(NEW.hero->>'subhead', '')) > 240
     OR length(COALESCE(NEW.hero->>'cta_label', '')) > 40 THEN
    RAISE EXCEPTION 'hero copy too long';
  END IF;

  IF NEW.is_published = true THEN
    IF NEW.publish_window_start IS NULL
       OR NEW.publish_window_start < (now() - interval '24 hours') THEN
      NEW.publish_window_start := now();
      NEW.publish_count_today  := 1;
    ELSE
      NEW.publish_count_today := COALESCE(NEW.publish_count_today, 0) + 1;
      IF NEW.publish_count_today > publish_day_limit THEN
        RAISE EXCEPTION 'storefront publish limit reached — try again later';
      END IF;
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_storefront_config ON public.storefront_config;
CREATE TRIGGER trg_validate_storefront_config
  BEFORE INSERT OR UPDATE ON public.storefront_config
  FOR EACH ROW EXECUTE FUNCTION public.validate_storefront_config();



-- ---------------------------------------------------------------------
-- #20 — "Order is only placed once paid": void an abandoned unpaid order
--       (supabase/migrations/20260611002000_void_my_unpaid_order.sql)
--
-- The card-required checkout creates the order (status='awaiting_confirmation',
-- payment_status='unpaid') BEFORE the card dialog. If the customer abandons
-- payment, the storefront calls this RPC to retire the never-paid order (bounced
-- back to the Payment step with a "not placed" message). Compare-and-swap that
-- ONLY voids a still-awaiting_confirmation, never-paid order owned by the caller
-- (customer.user_id = auth.uid()); a miss is a silent no-op. Frontend swallows a
-- missing-RPC error, so it degrades gracefully (auto-decline-stale cron is the
-- fallback). Strictly additive — C1 amount validation + pay-at-venue untouched.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.void_my_unpaid_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.void_my_unpaid_order(uuid) TO authenticated;
