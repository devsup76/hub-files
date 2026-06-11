-- =============================================================================
-- SECURITY OVERNIGHT — RUN THESE on the LIVE Supabase project (pmnyhbhtkcfoozkinieo)
-- =============================================================================
-- DB migrations from the 2026-06-11 OVERNIGHT pass (medium-low code-level fixes)
-- on top of the audit's already-shipped CRITICAL/HIGH set. Source audit:
-- docs/SECURITY_AUDIT_2026-06-11.md. Earlier (CRITICAL/HIGH) migrations are in
-- docs/SECURITY_FIXES_RUN_THESE.sql — run that FIRST if not already applied.
--
-- Each block is IDEMPOTENT / safe to re-run and mirrors a numbered file in
-- supabase/migrations/. Run the WHOLE file in the Supabase SQL editor; do NOT
-- auto-apply. After running, deploy the edge functions listed at the very end.
--
-- Sections are appended per audit finding, in ascending migration order.
-- =============================================================================



-- #############################################################################
-- F21 (MEDIUM) — validate_loyalty_code: per-(org, staff) brute-force throttle
-- Mirrors supabase/migrations/20260611050000_f21_loyalty_code_attempt_throttle.sql
-- #############################################################################
--
-- THREAT: validate_loyalty_code(p_code, p_org_id) is callable by the org owner OR
-- ANY active staff with NO attempt limit. The redeem code is a 6-digit value
-- (~900k) with a 5-minute lifetime; on a hit it returns customer name + email +
-- points. A compromised low-trust staff account (kitchen/service; staff auth is a
-- 6-digit PIN) can brute-force the whole space inside the 5-min window and harvest
-- customer PII. FIX: per-(org, staff) rate limit (>20 attempts/min -> reject) via
-- a small attempt-log table. Return shape UNCHANGED (email kept so the live
-- Loyalty validator panel still renders; dropping email is STAGED-FOR-REVIEW —
-- needs a coordinated frontend change in Loyalty.tsx).

CREATE TABLE IF NOT EXISTS public.loyalty_code_attempts (
  id           uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id       uuid NOT NULL,
  staff_uid    uuid NOT NULL,
  attempted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.loyalty_code_attempts ENABLE ROW LEVEL SECURITY;
-- No policies: deny-by-default. Only the SECURITY DEFINER validator + service-role
-- touch it; never read/written directly by end users.

CREATE INDEX IF NOT EXISTS loyalty_code_attempts_org_staff_time_idx
  ON public.loyalty_code_attempts (org_id, staff_uid, attempted_at DESC);

CREATE OR REPLACE FUNCTION public.validate_loyalty_code(p_code text, p_org_id uuid)
RETURNS TABLE(
  customer_id uuid,
  customer_name text,
  customer_email text,
  loyalty_points int,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid    uuid := COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);
  v_recent int;
BEGIN
  IF NOT (p_org_id = public.current_org_id()
          OR public.is_staff_of_org(auth.uid(), p_org_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT count(*) INTO v_recent
  FROM public.loyalty_code_attempts
  WHERE org_id = p_org_id
    AND staff_uid = v_uid
    AND attempted_at > now() - interval '1 minute';

  IF v_recent >= 20 THEN
    RAISE EXCEPTION 'Too many attempts — wait a moment and try again';
  END IF;

  INSERT INTO public.loyalty_code_attempts (org_id, staff_uid)
  VALUES (p_org_id, v_uid);

  DELETE FROM public.loyalty_code_attempts
  WHERE attempted_at < now() - interval '1 hour';

  RETURN QUERY
  SELECT c.id, c.name, c.email, c.total_points, s.expires_at
  FROM public.loyalty_code_sessions s
  JOIN public.customers c ON c.id = s.customer_id
  WHERE s.code = p_code
    AND s.org_id = p_org_id
    AND s.expires_at > now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validate_loyalty_code(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_loyalty_code(text, uuid) TO authenticated;



-- #############################################################################
-- F34 (LOW) — storefront_config: cap + sanitise arbitrary section text props
-- Mirrors supabase/migrations/20260611060000_f34_storefront_config_text_caps.sql
-- #############################################################################
--
-- THREAT: validate_storefront_config() does NOT cap length / restrict charset of
-- arbitrary NON-_url scalar string props in section `props`. A hand-rolled REST
-- write (bypassing the client parser) can store ~32KB of arbitrary unicode /
-- control chars per prop, served to every anon visitor — single-layer (React-only)
-- XSS defence. FIX (idempotent CREATE OR REPLACE of the trigger fn): recursively
-- cap every string value (<=500 chars) + reject ASCII control chars (0x00-0x1F
-- except tab/LF/CR, + 0x7F). _url https-only + hero/theme/size caps unchanged.
-- Existing rows are not re-validated on apply (fires on next INSERT/UPDATE);
-- curated templates already comply.

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
  txt text;
  hsl_re text := '^\d{1,3}(\.\d+)?\s+\d{1,3}(\.\d+)?%\s+\d{1,3}(\.\d+)?%$';
  ctrl_re text := '[' || chr(1) || '-' || chr(8)
                       || chr(11) || chr(12)
                       || chr(14) || '-' || chr(31)
                       || chr(127) || ']';
  max_text_len int := 500;
  max_config_bytes int := 32768;
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
      FOR u IN SELECT jsonb_path_query(s->'props', '$.**') LOOP
        IF jsonb_typeof(u) = 'string' THEN
          txt := u #>> '{}';
          IF length(txt) > max_text_len THEN
            RAISE EXCEPTION 'section text too long (max % chars) in %', max_text_len, s->>'id';
          END IF;
          IF txt ~ ctrl_re THEN
            RAISE EXCEPTION 'section text contains control characters in %', s->>'id';
          END IF;
        END IF;
      END LOOP;
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

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_storefront_config ON public.storefront_config;
CREATE TRIGGER trg_validate_storefront_config
  BEFORE INSERT OR UPDATE ON public.storefront_config
  FOR EACH ROW EXECUTE FUNCTION public.validate_storefront_config();





-- #############################################################################
-- F27 / MONITORING (the audit flagged NO audit log exists) — security_audit_log
-- + sensitive-action triggers + security_anomalies view (owner-only read).
-- Mirrors supabase/migrations/20260611070000_security_audit_log.sql
-- #############################################################################

-- ---------------------------------------------------------------------------
-- 1. The append-only audit table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.security_audit_log (
  id           uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  -- The user who performed the action, as seen at write time. NULL for a
  -- service-role / cron / webhook actor (auth.uid() is NULL on those paths).
  actor        uuid,
  -- A coarse label for the actor: 'owner' | 'staff' | 'service' | 'anon' |
  -- 'unknown'. Best-effort; derived in record_security_event from auth context.
  actor_role   text,
  -- A stable, low-cardinality verb describing WHAT happened, e.g.
  -- 'refund.recorded', 'refund.status_changed', 'order.captured',
  -- 'staff.role_changed', 'staff.deactivated', 'staff.created',
  -- 'org.payment_config_changed', 'account_recovery.attempt'.
  action       text NOT NULL,
  -- The KIND of thing acted on ('order','staff_account','organization',
  -- 'payment_refund','account_recovery') ...
  target_type  text,
  -- ... and its id (uuid as text so heterogeneous targets fit one column;
  -- account_recovery targets an email, not a uuid).
  target_id    text,
  -- The org the action belongs to, for owner-scoped RLS reads + per-org anomaly
  -- detection. NULL only when it genuinely can't be resolved.
  org_id       uuid,
  -- Structured before/after detail (old_role/new_role, amount_cents, provider,
  -- success flag, ip, ...). Never contains secrets — callers pass only
  -- non-sensitive descriptors.
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Append-only: no updated_at, no soft-delete. Indexes for the two dominant
-- read patterns — per-org timeline and global anomaly scans by action+time.
CREATE INDEX IF NOT EXISTS security_audit_log_org_time_idx
  ON public.security_audit_log (org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS security_audit_log_action_time_idx
  ON public.security_audit_log (action, created_at DESC);
CREATE INDEX IF NOT EXISTS security_audit_log_actor_time_idx
  ON public.security_audit_log (actor, created_at DESC);

ALTER TABLE public.security_audit_log ENABLE ROW LEVEL SECURITY;

-- Owner-only READ, scoped to their org. No INSERT/UPDATE/DELETE policy exists →
-- RLS denies all of those for any non-service caller, so the log is immutable
-- and unforgeable from the client. The service role bypasses RLS entirely for
-- writes (via record_security_event) and operator reconciliation.
DROP POLICY IF EXISTS "Owners read their org audit log" ON public.security_audit_log;
CREATE POLICY "Owners read their org audit log"
  ON public.security_audit_log
  FOR SELECT
  USING (
    org_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.organizations o
      WHERE o.id = public.security_audit_log.org_id
        AND o.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 2. record_security_event() — the SINGLE writer.
--    SECURITY DEFINER so the triggers below (which run in the modifying user's
--    context) and the service role can both insert regardless of RLS. It derives
--    actor_role from the current auth context unless the caller overrides it.
--    Marked to NEVER raise: a logging failure must not break a money/auth path
--    (the trigger wrappers also trap, this is belt-and-braces).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_security_event(
  p_action      text,
  p_target_type text DEFAULT NULL,
  p_target_id   text DEFAULT NULL,
  p_org_id      uuid DEFAULT NULL,
  p_metadata    jsonb DEFAULT '{}'::jsonb,
  p_actor       uuid DEFAULT NULL,
  p_actor_role  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := COALESCE(p_actor, auth.uid());
  v_role  text := p_actor_role;
BEGIN
  IF v_role IS NULL THEN
    IF v_actor IS NULL THEN
      v_role := 'service';            -- service role / cron / webhook (no JWT)
    ELSIF EXISTS (SELECT 1 FROM public.organizations o WHERE o.owner_id = v_actor) THEN
      v_role := 'owner';
    ELSIF EXISTS (SELECT 1 FROM public.staff_accounts s WHERE s.user_id = v_actor) THEN
      v_role := 'staff';
    ELSE
      v_role := 'unknown';
    END IF;
  END IF;

  INSERT INTO public.security_audit_log
    (actor, actor_role, action, target_type, target_id, org_id, metadata)
  VALUES
    (v_actor, v_role, p_action, p_target_type, p_target_id, p_org_id,
     COALESCE(p_metadata, '{}'::jsonb));
EXCEPTION WHEN OTHERS THEN
  -- Audit logging is best-effort. NEVER let it abort the caller's statement
  -- (a refund/capture/role-change must complete even if this write fails).
  NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.record_security_event(text, text, text, uuid, jsonb, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_security_event(text, text, text, uuid, jsonb, uuid, text) TO service_role;

-- ---------------------------------------------------------------------------
-- 3. Trigger: REFUNDS — audit every refund insert + status transition.
--    Fires on public.payment_refunds (written ONLY by record_order_refund /
--    set_refund_status under the service role). AFTER so the row is durable.
--    Wrapped to swallow any error → can't break the money RPC.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_payment_refund()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.record_security_event(
        'refund.recorded',
        'payment_refund',
        NEW.id::text,
        NEW.organization_id,
        jsonb_build_object(
          'order_id',           NEW.order_id,
          'provider',           NEW.provider,
          'provider_refund_id', NEW.provider_refund_id,
          'amount_cents',       NEW.amount_cents,
          'status',             NEW.status,
          'reason',             left(COALESCE(NEW.reason, ''), 200)
        ),
        NEW.created_by
      );
    ELSIF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
      PERFORM public.record_security_event(
        'refund.status_changed',
        'payment_refund',
        NEW.id::text,
        NEW.organization_id,
        jsonb_build_object(
          'order_id',     NEW.order_id,
          'provider',     NEW.provider,
          'amount_cents', NEW.amount_cents,
          'old_status',   OLD.status,
          'new_status',   NEW.status
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- never break the refund path
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_payment_refund ON public.payment_refunds;
CREATE TRIGGER trg_audit_payment_refund
  AFTER INSERT OR UPDATE ON public.payment_refunds
  FOR EACH ROW EXECUTE FUNCTION public.audit_payment_refund();

-- ---------------------------------------------------------------------------
-- 4. Trigger: ORDER CAPTURE — audit the authorize→capture money transition.
--    A capture is the moment a manual-capture authorization becomes a real
--    charge (order-respond on owner-confirm flips payment_status to 'paid').
--    We audit the payment_status transition into 'paid' (and the terminal
--    refund states for completeness) without touching order-respond. AFTER
--    UPDATE only; we ignore the high-volume status/kanban churn and only log
--    payment_status changes.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_order_payment_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
      PERFORM public.record_security_event(
        CASE
          WHEN NEW.payment_status = 'paid'     THEN 'order.captured'
          WHEN NEW.payment_status = 'canceled' THEN 'order.authorization_voided'
          ELSE 'order.payment_status_changed'
        END,
        'order',
        NEW.id::text,
        NEW.organization_id,
        jsonb_build_object(
          'old_payment_status', OLD.payment_status,
          'new_payment_status', NEW.payment_status,
          'total_amount',       NEW.total_amount,
          'payment_provider',   NEW.payment_provider
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- never break the order/capture path
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_order_payment_status ON public.orders;
CREATE TRIGGER trg_audit_order_payment_status
  AFTER UPDATE OF payment_status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.audit_order_payment_status();

-- ---------------------------------------------------------------------------
-- 5. Trigger: STAFF changes — role escalation / deactivation / creation.
--    A staff role change (service→manager) or reactivation is a privilege event;
--    deactivation bans a session. All flow through staff_accounts (the
--    staff-manage edge fn writes here under the service role). AFTER on the row.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_staff_account()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    IF TG_OP = 'INSERT' THEN
      PERFORM public.record_security_event(
        'staff.created',
        'staff_account',
        NEW.id::text,
        NEW.organization_id,
        jsonb_build_object(
          'staff_user_id', NEW.user_id,
          'username',      NEW.username,
          'role',          NEW.role,
          'is_active',     NEW.is_active,
          'created_by',    NEW.created_by
        )
      );
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.role IS DISTINCT FROM OLD.role THEN
        PERFORM public.record_security_event(
          'staff.role_changed',
          'staff_account',
          NEW.id::text,
          NEW.organization_id,
          jsonb_build_object(
            'staff_user_id', NEW.user_id,
            'username',      NEW.username,
            'old_role',      OLD.role,
            'new_role',      NEW.role
          )
        );
      END IF;
      IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
        PERFORM public.record_security_event(
          CASE WHEN NEW.is_active THEN 'staff.reactivated' ELSE 'staff.deactivated' END,
          'staff_account',
          NEW.id::text,
          NEW.organization_id,
          jsonb_build_object(
            'staff_user_id', NEW.user_id,
            'username',      NEW.username,
            'role',          NEW.role
          )
        );
      END IF;
    ELSIF TG_OP = 'DELETE' THEN
      PERFORM public.record_security_event(
        'staff.deleted',
        'staff_account',
        OLD.id::text,
        OLD.organization_id,
        jsonb_build_object(
          'staff_user_id', OLD.user_id,
          'username',      OLD.username,
          'role',          OLD.role
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- never break staff management
  END;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_staff_account ON public.staff_accounts;
CREATE TRIGGER trg_audit_staff_account
  AFTER INSERT OR UPDATE OR DELETE ON public.staff_accounts
  FOR EACH ROW EXECUTE FUNCTION public.audit_staff_account();

-- ---------------------------------------------------------------------------
-- 6. Trigger: ORG PAYMENT-CONFIG changes — record any change to the
--    payment-connection columns. These are operator/webhook-owned (the BEFORE
--    guard trigger 20260609050000 already PINS them against owner self-set);
--    auditing the change captures the legitimate server-side activations and
--    flags any that slip the guard. Only logs when a guarded column actually
--    changes (the guard reverts owner attempts to no-ops, so those won't fire).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_org_payment_config()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    IF NEW.payment_provider     IS DISTINCT FROM OLD.payment_provider
       OR NEW.square_payment_ready IS DISTINCT FROM OLD.square_payment_ready
       OR NEW.square_merchant_id   IS DISTINCT FROM OLD.square_merchant_id
       OR NEW.square_location_id   IS DISTINCT FROM OLD.square_location_id
       OR NEW.charges_enabled      IS DISTINCT FROM OLD.charges_enabled
       OR NEW.payouts_enabled      IS DISTINCT FROM OLD.payouts_enabled
       OR NEW.stripe_account_id    IS DISTINCT FROM OLD.stripe_account_id THEN
      PERFORM public.record_security_event(
        'org.payment_config_changed',
        'organization',
        NEW.id::text,
        NEW.id,
        jsonb_build_object(
          'old_provider',           OLD.payment_provider,
          'new_provider',           NEW.payment_provider,
          'old_square_ready',       OLD.square_payment_ready,
          'new_square_ready',       NEW.square_payment_ready,
          'old_charges_enabled',    OLD.charges_enabled,
          'new_charges_enabled',    NEW.charges_enabled,
          'old_payouts_enabled',    OLD.payouts_enabled,
          'new_payouts_enabled',    NEW.payouts_enabled,
          'stripe_account_changed', (NEW.stripe_account_id IS DISTINCT FROM OLD.stripe_account_id),
          'square_merchant_changed',(NEW.square_merchant_id IS DISTINCT FROM OLD.square_merchant_id)
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- never break the org update path
  END;
  RETURN NEW;
END;
$$;

-- Fires AFTER the BEFORE guard (20260609050000) has already pinned owner writes,
-- so an owner's blocked self-activation reverts to a no-op and is NOT logged as a
-- spurious change. Only genuine (server/webhook) changes reach here as a delta.
DROP TRIGGER IF EXISTS trg_audit_org_payment_config ON public.organizations;
CREATE TRIGGER trg_audit_org_payment_config
  AFTER UPDATE OF payment_provider, square_payment_ready, square_merchant_id,
                  square_location_id, charges_enabled, payouts_enabled,
                  stripe_account_id
  ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.audit_org_payment_config();

-- ---------------------------------------------------------------------------
-- 7. Trigger: ACCOUNT-RECOVERY attempts — mirror each attempt into the audit log.
--    account_recovery_log already records attempts for rate-limiting; copying
--    them here gives the unified security timeline + feeds the anomaly view. The
--    row carries org_id + email + action + success natively (+ ip from a later
--    migration), so we read those directly. We deliberately do NOT join auth.users
--    here (gotcha #2: auth.users joins in a SECURITY DEFINER/RLS context can
--    return NULL); the native org_id is authoritative and avoids that trap.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_account_recovery()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_success boolean;
BEGIN
  BEGIN
    -- success is a native NOT NULL boolean on the row; read defensively via
    -- to_jsonb so this trigger is robust if the column set ever shifts.
    v_success := COALESCE((to_jsonb(NEW) ->> 'success')::boolean, false);

    PERFORM public.record_security_event(
      'account_recovery.attempt',
      'account_recovery',
      NEW.email,
      NEW.org_id,
      jsonb_build_object(
        'email',   NEW.email,
        'action',  (to_jsonb(NEW) ->> 'action'),
        'success', v_success,
        'ip',      (to_jsonb(NEW) ->> 'ip')
      ),
      NULL,
      'anon'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- never break account recovery
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_account_recovery ON public.account_recovery_log;
CREATE TRIGGER trg_audit_account_recovery
  AFTER INSERT ON public.account_recovery_log
  FOR EACH ROW EXECUTE FUNCTION public.audit_account_recovery();

-- ---------------------------------------------------------------------------
-- 8. security_anomalies — a read-only view of the obvious "something's wrong"
--    signals, computed from the audit log + the existing attempt tables. An
--    operator dashboard reads it; a future cron can poll it and alert.
--    Each row: org_id, anomaly type, a count, a window, and a severity hint.
--    SECURITY-wise it's a security_invoker view: it executes with the querying
--    user's rights, so the owner-only RLS on security_audit_log applies
--    transitively and an owner only ever sees anomalies for their own org.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.security_anomalies
WITH (security_invoker = true) AS
  -- (a) Refund spike: > 5 refunds recorded for one org in the last hour.
  SELECT
    a.org_id,
    'refund_spike'::text                         AS anomaly,
    count(*)                                      AS event_count,
    '1 hour'::text                                AS window_label,
    'high'::text                                  AS severity,
    max(a.created_at)                             AS last_seen
  FROM public.security_audit_log a
  WHERE a.action = 'refund.recorded'
    AND a.created_at > now() - interval '1 hour'
    AND a.org_id IS NOT NULL
  GROUP BY a.org_id
  HAVING count(*) > 5

  UNION ALL
  -- (b) Privilege churn: > 3 staff role/active changes for one org in 24h.
  SELECT
    a.org_id,
    'staff_privilege_churn'::text,
    count(*),
    '24 hours'::text,
    'medium'::text,
    max(a.created_at)
  FROM public.security_audit_log a
  WHERE a.action IN ('staff.role_changed','staff.deactivated','staff.reactivated')
    AND a.created_at > now() - interval '24 hours'
    AND a.org_id IS NOT NULL
  GROUP BY a.org_id
  HAVING count(*) > 3

  UNION ALL
  -- (c) Payment-config churn: any change to payment-connection columns in 24h
  -- is rare + sensitive — surface even a single one for review.
  SELECT
    a.org_id,
    'payment_config_change'::text,
    count(*),
    '24 hours'::text,
    'high'::text,
    max(a.created_at)
  FROM public.security_audit_log a
  WHERE a.action = 'org.payment_config_changed'
    AND a.created_at > now() - interval '24 hours'
    AND a.org_id IS NOT NULL
  GROUP BY a.org_id

  UNION ALL
  -- (d) Repeated failed account-recovery attempts for an org's owner in 1h.
  SELECT
    a.org_id,
    'account_recovery_failures'::text,
    count(*),
    '1 hour'::text,
    'high'::text,
    max(a.created_at)
  FROM public.security_audit_log a
  WHERE a.action = 'account_recovery.attempt'
    AND (a.metadata ->> 'success') IS DISTINCT FROM 'true'
    AND a.created_at > now() - interval '1 hour'
    AND a.org_id IS NOT NULL
  GROUP BY a.org_id
  HAVING count(*) >= 5;

-- security_invoker view → it executes with the QUERYING user's rights, so the
-- owner-only RLS on security_audit_log applies transitively: an owner only ever
-- sees anomalies for their own org. No extra GRANT beyond the table's RLS.
REVOKE ALL ON public.security_anomalies FROM PUBLIC, anon;
GRANT SELECT ON public.security_anomalies TO authenticated, service_role;

-- =============================================================================
-- FOUNDER-INPUT (NOT wired here — needs a channel decision):
--   External alerting. This migration gives you the trail (security_audit_log)
--   + the signal (security_anomalies) but does NOT send email/Slack/PagerDuty
--   when an anomaly appears. To close the loop, add ONE of:
--     (1) a pg_cron job that polls security_anomalies every N minutes and
--         net.http_post()s to a Slack/Resend webhook (needs the webhook URL as a
--         Vault secret), OR
--     (2) a Supabase Database Webhook on security_audit_log filtered to the
--         high-severity actions, OR
--     (3) a log drain → Sentry/Datadog on the edge functions.
--   Pick the channel + provide the secret, then the cron/webhook is a few lines.
--   Until then anomalies are visible only by reading the view (operator pull,
--   not push). This is the same monitoring gap called out as F27 — the data
--   layer is now in place; the notify hop is the remaining founder action.
-- =============================================================================



-- #############################################################################
-- F46 — INPUT VALIDATION + LENGTH BOUNDS — order / consent / reservation paths
-- Mirrors supabase/migrations/20260611080000_f46_rpc_input_length_bounds.sql
-- #############################################################################
--
-- THREAT: order-placement + guest-consent recompute money/status correctly, but
-- the guest-controlled FREE-TEXT fields (orders.notes / table_number /
-- shipping_address; upsert_my_consent name/email/phone) have NO length or charset
-- bound. An anon guest (free, captcha-less session) can write megabytes of
-- arbitrary unicode/control chars into the CRM, kitchen docket, order tracker and
-- Uber manifest — storage-abuse + log-spam + latent display-injection riding on
-- the same bot-order faucet F12 only partly closes.
--
-- FIX (additive, write-path-agnostic, idempotent):
--   1. trg_clamp_order_text — BEFORE INSERT OR UPDATE on orders: length-caps +
--      control-char-strips notes (<=2000) / table_number (<=32) / denial_reason
--      (<=500) / shipping_address (allow-listed string keys, <=500 each); rejects
--      a >96KB / >200-item line_items array. TRUNCATES free text (never rejects an
--      order → the money path is untouched). Catches EVERY writer (the order RPC,
--      POS, direct REST) so a future path can't reopen the hole.
--   2. trg_customers_input_bounds — BEFORE INSERT OR UPDATE on customers: REJECTS
--      over-long name(<=200)/email(<=320)/phone(<=40) + basic email-shape check
--      (don't store a truncated identity). Catches upsert_my_consent + owner CRM.
--   3. trg_reservations_input_bounds — BEFORE INSERT OR UPDATE on reservations:
--      REJECTS over-long customer_name(<=200)/email(<=320)/phone(<=40)/notes
--      (<=2000)/cancellation_reason(<=500). Catches create_public_reservation.
-- Normal orders/checkouts/bookings are byte-for-byte unchanged. NOTE: the trigger
-- approach means NO RPC body is re-stated here — zero drift risk vs the live RPCs.

CREATE OR REPLACE FUNCTION public.clamp_order_text()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_addr     jsonb;
  v_clean    jsonb := '{}'::jsonb;
  v_key      text;
  v_val      text;
  v_allowed  text[] := ARRAY[
    'name','line1','line2','street','city','suburb','state','region',
    'postcode','postal_code','zip','country','notes','instructions','phone'
  ];
BEGIN
  IF NEW.notes IS NOT NULL THEN
    NEW.notes := left(regexp_replace(NEW.notes, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', 'g'), 2000);
  END IF;

  IF NEW.table_number IS NOT NULL THEN
    NEW.table_number := left(regexp_replace(NEW.table_number, '[\x00-\x1F\x7F]', '', 'g'), 32);
  END IF;

  IF NEW.denial_reason IS NOT NULL THEN
    NEW.denial_reason := left(regexp_replace(NEW.denial_reason, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', 'g'), 500);
  END IF;

  IF NEW.shipping_address IS NOT NULL AND jsonb_typeof(NEW.shipping_address) = 'object' THEN
    v_addr := NEW.shipping_address;
    FOR v_key IN SELECT * FROM unnest(v_allowed) LOOP
      IF v_addr ? v_key AND jsonb_typeof(v_addr->v_key) = 'string' THEN
        v_val := left(regexp_replace(v_addr->>v_key, '[\x00-\x1F\x7F]', '', 'g'), 500);
        IF length(v_val) > 0 THEN
          v_clean := v_clean || jsonb_build_object(v_key, v_val);
        END IF;
      END IF;
    END LOOP;
    NEW.shipping_address := v_clean;
  END IF;

  -- line_items — reject a multi-MB / huge-array cart (never legitimate), AFTER the
  -- C1 total-validation RPC has accepted the order shape.
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

DROP TRIGGER IF EXISTS trg_clamp_order_text ON public.orders;
CREATE TRIGGER trg_clamp_order_text
  BEFORE INSERT OR UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.clamp_order_text();

-- customers — REJECT over-long identity (catches upsert_my_consent + owner CRM).
-- Trigger, NOT an RPC re-statement → zero drift vs the live upsert_my_consent.
CREATE OR REPLACE FUNCTION public.enforce_customer_input_bounds()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.name IS NOT NULL AND length(NEW.name) > 200 THEN
    RAISE EXCEPTION 'Name is too long' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.email IS NOT NULL THEN
    IF length(NEW.email) > 320 THEN
      RAISE EXCEPTION 'Email is too long' USING ERRCODE = 'check_violation';
    END IF;
    IF position('@' IN NEW.email) = 0 OR position(' ' IN NEW.email) > 0 THEN
      RAISE EXCEPTION 'Email is not valid' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.phone_number IS NOT NULL AND length(NEW.phone_number) > 40 THEN
    RAISE EXCEPTION 'Phone number is too long' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customers_input_bounds ON public.customers;
CREATE TRIGGER trg_customers_input_bounds
  BEFORE INSERT OR UPDATE ON public.customers
  FOR EACH ROW EXECUTE FUNCTION public.enforce_customer_input_bounds();

-- reservations — REJECT over-long (catches create_public_reservation).
CREATE OR REPLACE FUNCTION public.enforce_reservation_input_bounds()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.customer_name IS NOT NULL AND length(NEW.customer_name) > 200 THEN
    RAISE EXCEPTION 'Name is too long' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.customer_email IS NOT NULL AND length(NEW.customer_email) > 320 THEN
    RAISE EXCEPTION 'Email is too long' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.customer_phone IS NOT NULL AND length(NEW.customer_phone) > 40 THEN
    RAISE EXCEPTION 'Phone number is too long' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.notes IS NOT NULL AND length(NEW.notes) > 2000 THEN
    RAISE EXCEPTION 'Notes are too long' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.cancellation_reason IS NOT NULL AND length(NEW.cancellation_reason) > 500 THEN
    RAISE EXCEPTION 'Reason is too long' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reservations_input_bounds ON public.reservations;
CREATE TRIGGER trg_reservations_input_bounds
  BEFORE INSERT OR UPDATE ON public.reservations
  FOR EACH ROW EXECUTE FUNCTION public.enforce_reservation_input_bounds();



-- =============================================================================
-- =============================================================================
-- AFTER RUNNING THE MIGRATIONS ABOVE — DEPLOY THESE EDGE FUNCTIONS
-- (code-level fixes committed alongside this run-these doc; deploy with
--  `npx supabase functions deploy <name>`):
--   * stripe-payment-intent  (F28 — amount-bound idempotency key + resume re-check)
--   * square-webhook         (F29 — handle oauth.authorization.revoked)
--   * account-recover        (F22 — paginate owner lookup; was capped at 200 owners)
--   -- F43 NO-INTERNAL-DETAIL error handling — generic client message + ref,
--   --     raw detail logged server-side only (new _shared/errors.ts helper).
--   --     Top-level catch + the raw DB/provider-message early returns now return
--   --     a generic body; full detail goes to the function logs only:
--   * square-payment, stripe-payment-intent, refund-order, order-respond,
--     sms-send, email-send, customer-signup
--   -- F45 RATE-LIMIT added to the previously-unthrottled PUBLIC mutating endpoint:
--   * customer-signup  (per-email 4/hr + per-IP 12/hr via rate_limit_hit; fail-OPEN;
--                       REQUIRES migration 20260611040000 already applied)
-- The frontend fixes (F24/F25 demo-mode lost-order guard) ship via the normal
-- Cloudflare Pages build of the branch — no manual step.
--
-- F29 NOTE: for the revoke handler to fire, subscribe to the
-- `oauth.authorization.revoked` event in the Square Developer dashboard webhook
-- config (same endpoint as payment.*/refund.*). No-op until subscribed.
-- =============================================================================
--
-- =============================================================================
-- STAGED-FOR-REVIEW (NOT in this run — deliberately deferred; need a coordinated
-- frontend/data change or a founder decision — see report):
--   * F21 follow-up — drop customer_email from validate_loyalty_code's RETURNS.
--     Needs a matching change in src/pages/dashboard/Loyalty.tsx (it renders
--     result.customer_email). The rate-limit shipped here already defangs the
--     brute-force PII harvest.
--   * F22 follow-up — per-user SALT on organizations.security_questions answer
--     hashes. Requires re-hashing existing stored answers (a data migration the
--     founder must run knowingly) + an account-recover verify change. The
--     pagination fix (availability) IS shipped here.
--   * F27 follow-up — EXTERNAL ALERTING. The audit-trail + anomaly-view substrate
--     IS shipped here (security_audit_log + sensitive-action triggers +
--     security_anomalies). The remaining piece is the NOTIFY hop (cron/webhook →
--     Slack/Resend/Sentry on a high-severity anomaly), which needs a founder
--     channel decision + secret. See the FOUNDER-INPUT note in the
--     security_audit_log section above. The cron-heartbeat half (reconcile
--     net.http_post results / last-success-per-job) is still open too.
--   * F14 (donation/charity fabrication), F17/F32 (allowlist-projection refactor
--     of the public RPCs), F20 (username->email enumeration) — each either alters
--     a working money/RLS/auth path or needs an alert-channel / captcha decision.
--     Left for review.
-- =============================================================================
