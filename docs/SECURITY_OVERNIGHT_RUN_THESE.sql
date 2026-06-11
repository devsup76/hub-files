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





-- #############################################################################
-- PASS-2 SAFE REMEDIATION (P2, P3, P6-budget, P7, P8, P10, P11)
-- Mirrors supabase/migrations/20260611090000_pass2_safe_remediation.sql
-- Source audit: docs/SECURITY_AUDIT_PASS2_2026-06-11.md
-- #############################################################################

-- =============================================================================
-- PASS-2 SECURITY REMEDIATION (SAFE / code-level subset)
-- docs/SECURITY_AUDIT_PASS2_2026-06-11.md
-- =============================================================================
-- STRICTLY ADDITIVE + IDEMPOTENT. No change to the working money flows (online
-- card charge, capture/decline, refund, get_public_* RPCs, guest checkout). This
-- file implements ONLY the SAFE pass-2 findings that do not touch the
-- charge/capture/refund/checkout *core* logic (those are STAGED-FOR-REVIEW, see
-- the report):
--
--   P2  — order rate-limit counter must survive a rolled-back order. The throttle
--         hit is moved to an AUTONOMOUS (out-of-transaction) write via dblink so a
--         failed order (out-of-stock probe / floor reject) STILL counts.
--   P3  — per-customer promo redemption cap (promo_redemptions ledger + enforce
--         it inside create_order_with_inventory against the resolved customer).
--   P7  — prune abuse_throttle (daily cron), fail-CLOSED on a null subject for the
--         order/reservation paths, and add the supporting open-order index.
--   P8  — set_refund_status must NOT resurrect a fully-'refunded' order back to
--         'paid' on a stale/failed refund webhook.
--   P10 — guard_order_payment_columns also pins the attribution columns
--         (customer_id, order_number, organization_id) against same-org re-write.
--   P11 — wire the F11 restock helper into the order DELETE path (BEFORE DELETE
--         trigger) so a deleted stock-tracked, never-released order restocks.
--
-- NOT here (STAGED-FOR-REVIEW — touch the money/checkout core, see report):
--   P1 (loyalty award reversal on decline/refund), P4 (promo usage release),
--   P5 (anon payment-ownership binding).
--
-- SAFE TO RE-RUN. NOT auto-applied — the founder runs this in the Supabase SQL
-- editor against the live project (pmnyhbhtkcfoozkinieo).
-- =============================================================================


-- #############################################################################
-- P7 (b) — fail-CLOSED rate-limit variant for the order/reservation paths.
-- #############################################################################
-- The existing rate_limit_hit(text,text,int,text) fails OPEN on a null/empty
-- subject (returns false = allow). That is the right default for a generic
-- primitive, but the order + reservation RPCs already REJECT a null auth.uid()
-- before they ever throttle, so for those paths a null subject reaching the
-- throttle should be treated as "cannot verify => block" (defence in depth).
-- We add a thin fail-CLOSED wrapper rather than change the shared primitive's
-- contract (other callers rely on fail-open).
CREATE OR REPLACE FUNCTION public.rate_limit_hit_strict(
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
BEGIN
  -- Fail CLOSED: no subject to key on => treat as over-limit (block).
  IF p_subject IS NULL OR p_subject = '' THEN
    RETURN true;
  END IF;
  RETURN public.rate_limit_hit(p_subject, p_action, p_max, p_window);
END;
$$;

REVOKE ALL ON FUNCTION public.rate_limit_hit_strict(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rate_limit_hit_strict(text, text, int, text) TO service_role;


-- #############################################################################
-- P2 — record the throttle hit OUT-OF-TRANSACTION so a rolled-back order counts.
-- #############################################################################
-- THREAT: rate_limit_hit() runs INSIDE create_order_with_inventory's single
-- SECURITY DEFINER transaction. If the order later RAISEs (stock check, floor
-- reject, customer mismatch — all common attacker inputs) the whole transaction
-- rolls back, INCLUDING the throttle increment. An attacker who deliberately
-- submits orders that fail late is therefore NEVER throttled.
--
-- FIX: increment + read the counter in an AUTONOMOUS transaction via dblink, so
-- the hit is COMMITTED immediately and survives the outer order's rollback. We
-- keep the in-transaction rate_limit_hit() for callers that don't need this; the
-- order RPC switches to rate_limit_hit_committed() below.
--
-- dblink is a standard Supabase extension. The autonomous path only engages when
-- a working connection string is configured in `app.dblink_conninfo` (FOUNDER-
-- INPUT — see the conninfo note on rate_limit_hit_committed). Until then (and on
-- any connection failure) it FALLS BACK to the in-transaction counter, so this
-- migration is ALWAYS safe to run and NEVER worse than today's behaviour. The
-- reliable boundary remains the edge/Cloudflare per-IP limit + Turnstile.
CREATE EXTENSION IF NOT EXISTS dblink;

-- The autonomous worker that actually mutates the counter. It is called over a
-- fresh dblink connection (its own transaction), so its COMMIT is independent of
-- the caller. SECURITY DEFINER + service_role only.
CREATE OR REPLACE FUNCTION public._rate_limit_hit_autonomous(
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
BEGIN
  RETURN public.rate_limit_hit(p_subject, p_action, p_max, p_window);
END;
$$;

REVOKE ALL ON FUNCTION public._rate_limit_hit_autonomous(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._rate_limit_hit_autonomous(text, text, int, text) TO service_role;

-- Committed-counter wrapper: tries the autonomous (out-of-txn) path via dblink so
-- a later rollback of the OUTER order cannot un-count the hit. Falls back to the
-- in-transaction counter if dblink can't connect (e.g. local/CI without the
-- loopback). Returns TRUE when over the limit (caller should reject).
-- CONNINFO: dblink needs a connection string. A passwordless TCP self-connect is
-- usually REJECTED on managed Postgres (Supabase), so the founder should set a
-- working conninfo once via:
--     ALTER DATABASE postgres SET app.dblink_conninfo =
--       'dbname=postgres host=127.0.0.1 port=5432 user=postgres password=<svc-pw>';
-- (or a dedicated low-priv role with EXECUTE on _rate_limit_hit_autonomous).
-- When app.dblink_conninfo is unset OR the connection fails, this function FALLS
-- BACK to the in-transaction counter — i.e. behaviour is NEVER worse than today,
-- but the rollback-evasion fix (P2) only fully engages once the conninfo works.
-- The REAL boundary remains the edge/Cloudflare per-IP limit (FOUNDER-INPUT).
CREATE OR REPLACE FUNCTION public.rate_limit_hit_committed(
  p_subject text,
  p_action  text,
  p_max     int,
  p_window  text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_over boolean;
  v_sql  text;
  v_conn text := NULLIF(current_setting('app.dblink_conninfo', true), '');
BEGIN
  IF p_subject IS NULL OR p_subject = '' THEN
    RETURN true;  -- fail CLOSED (same as the strict variant)
  END IF;

  -- No configured conninfo => cannot run the autonomous (rollback-proof) counter.
  -- Fall back to the in-transaction counter (today's behaviour — no regression).
  IF v_conn IS NULL THEN
    RETURN public.rate_limit_hit(p_subject, p_action, p_max, p_window);
  END IF;

  -- dblink opens a SEPARATE backend with its OWN transaction, so the INSERT/UPDATE
  -- it performs COMMITS independently of the caller's transaction — surviving the
  -- outer order's rollback (the P2 fix).
  v_sql := format(
    'SELECT public._rate_limit_hit_autonomous(%L,%L,%s,%L)',
    p_subject, p_action, p_max::text, p_window
  );

  BEGIN
    SELECT t.over INTO v_over
    FROM dblink(v_conn, v_sql) AS t(over boolean);
  EXCEPTION WHEN OTHERS THEN
    -- conninfo present but the connection/call failed: fall back to the
    -- in-transaction counter rather than blocking checkout. No regression.
    v_over := public.rate_limit_hit(p_subject, p_action, p_max, p_window);
  END;

  RETURN COALESCE(v_over, false);
END;
$$;

REVOKE ALL ON FUNCTION public.rate_limit_hit_committed(text, text, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rate_limit_hit_committed(text, text, int, text) TO service_role;


-- #############################################################################
-- P3 — per-customer promo redemption cap.
-- #############################################################################
-- THREAT: promo_codes has only a GLOBAL usage_limit. Every fresh guest anon
-- session is a new customer row, so the same human redeems the same promo
-- repeatedly until the global cap is hit (and forever for an uncapped promo).
--
-- FIX: a promo_redemptions ledger with UNIQUE(promo_id, customer_id), enforced
-- inside create_order_with_inventory. A customer can redeem a given promo at most
-- once (the common "first order" / "one per customer" intent). Combine with
-- captcha (FOUNDER-INPUT) so minting fresh customers is itself gated.
--
-- NOTE: this does NOT release a redemption on decline/abandon — that asymmetry is
-- tracked as P4 (STAGED-FOR-REVIEW). A redemption row is written only when the
-- order row commits, so a fully rolled-back order leaves no row (it never
-- "consumes" the per-customer slot on a failed order).
CREATE TABLE IF NOT EXISTS public.promo_redemptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id    uuid NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id)   ON DELETE CASCADE,
  order_id    uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT promo_redemptions_uniq UNIQUE (promo_id, customer_id)
);

ALTER TABLE public.promo_redemptions ENABLE ROW LEVEL SECURITY;
-- Deny-by-default for anon/authenticated REST. Only the SECURITY DEFINER order
-- RPC (and service_role) ever writes/reads it.
REVOKE ALL ON TABLE public.promo_redemptions FROM PUBLIC;
GRANT SELECT, INSERT ON TABLE public.promo_redemptions TO service_role;

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_promo_customer
  ON public.promo_redemptions (promo_id, customer_id);


-- #############################################################################
-- P7 (c) — supporting index for the concurrent-open-order cap query.
-- #############################################################################
-- The cap query joins orders->customers on customers.user_id and filters on
-- orders(customer_id,status,payment_status,created_at). Add the missing
-- customers(user_id) index so the join is a lookup, not a scan, on every guest
-- order. orders already has idx_orders_status (org,status) + others.
CREATE INDEX IF NOT EXISTS idx_customers_user_id
  ON public.customers (user_id);

CREATE INDEX IF NOT EXISTS idx_orders_customer_status
  ON public.orders (customer_id, status, created_at);


-- #############################################################################
-- P2 + P3 + P7(b) — re-state create_order_with_inventory with the committed
-- throttle, the per-customer promo cap, and the fail-closed subject handling.
-- #############################################################################
-- Carries the FULL body from 20260611040000 (F12) UNCHANGED except:
--   * the throttle call switches rate_limit_hit -> rate_limit_hit_committed
--     (P2: survives a rolled-back order; fail-CLOSED on null subject — P7b);
--   * after promo validation, enforce the per-customer cap and write a
--     promo_redemptions row (P3).
-- Everything else (pricing, floor, inventory lock/decrement, status, insert) is
-- byte-for-byte identical to 20260611040000.
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

      -- P3 — per-customer cap. A given customer may redeem a given promo at most
      -- once. If they've already redeemed it (a row exists), the promo simply does
      -- NOT apply (the order proceeds at full price — we do NOT reject, so the
      -- checkout never hard-fails on a re-used code). Trusted POS (no resolved
      -- customer / org member) is exempt.
      IF v_customer_id IS NOT NULL
         AND NOT COALESCE(v_is_org_member, false)
         AND EXISTS (
           SELECT 1 FROM public.promo_redemptions
           WHERE promo_id = v_promo.id AND customer_id = v_customer_id
         ) THEN
        v_discount := 0;          -- already redeemed → no discount this time
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

  -- P3 — record the per-customer redemption ONLY when a discount was actually
  -- applied AND we have a customer to key on. The UNIQUE(promo_id, customer_id)
  -- makes this idempotent; ON CONFLICT DO NOTHING guards a concurrent double-apply.
  IF v_promo_applied AND v_customer_id IS NOT NULL THEN
    INSERT INTO public.promo_redemptions (promo_id, customer_id, order_id)
    VALUES (v_promo.id, v_customer_id, v_order.id)
    ON CONFLICT (promo_id, customer_id) DO NOTHING;
  END IF;

  RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order_with_inventory(uuid, uuid, integer, jsonb)
TO anon, authenticated;


-- #############################################################################
-- P8 — set_refund_status must NOT resurrect a 'refunded' order back to 'paid'.
-- #############################################################################
-- THREAT: when a money-moving refund row is flipped to failed/canceled by a
-- webhook AND it was the order's only such refund, v_new_total becomes 0 and the
-- order's payment_status is set back to 'paid' with refunded_at cleared. For a
-- spurious/duplicate/late 'failed' webhook on a refund that actually SUCCEEDED
-- (provider eventual-consistency), a fully-refunded order silently re-enters GMV
-- as 'paid' even though the customer has the money back.
--
-- FIX: never AUTO-revert an order that is currently 'refunded' back to 'paid'
-- from a webhook. If v_new_total <= 0 but the order was 'refunded', leave it
-- 'refunded' (require an explicit re-charge / manual reconciliation rather than
-- silently re-counting it as revenue). The 'partially_refunded' -> 'paid' case
-- (a partial refund that genuinely failed before the order was fully refunded) is
-- still allowed, since that order's captured charge is intact.
-- Re-stated from 20260610050000 with ONLY the CASE/refunded_at branch changed.
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
    refund_amount_cents = v_new_total,
    payment_status = CASE
      -- P8: do NOT silently resurrect a fully-'refunded' order to 'paid' from a
      -- webhook back-out. If a stale/failed refund webhook lands after a genuine
      -- full refund, keep it 'refunded' (manual reconciliation re-charges if the
      -- refund truly failed) rather than re-inflating GMV. A NON-refunded order
      -- whose pending refund failed correctly drops back to 'paid'.
      WHEN v_new_total <= 0 AND v_order.payment_status = 'refunded' THEN 'refunded'
      WHEN v_new_total <= 0 THEN 'paid'
      WHEN v_new_total >= COALESCE(v_order.total_amount, 0) THEN 'refunded'
      ELSE 'partially_refunded'
    END,
    refunded_at = CASE
      WHEN v_new_total <= 0 AND v_order.payment_status = 'refunded' THEN v_order.refunded_at
      WHEN v_new_total <= 0 THEN NULL
      ELSE COALESCE(v_order.refunded_at, now())
    END
  WHERE id = v_order.id;
END;
$$;

REVOKE ALL ON FUNCTION public.set_refund_status(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_refund_status(text, text, text) TO service_role;


-- #############################################################################
-- P10 — guard attribution/identity columns on orders (same-org re-write).
-- #############################################################################
-- THREAT: guard_order_payment_columns (20260611020000) pins settled-money cols
-- but NOT customer_id / order_number / organization_id. A same-org staff/owner
-- JWT can re-attribute an existing order to a different customer (loyalty/GMV-by-
-- customer skew), re-stamp its human-facing order_number, or move it to another
-- org. These are identity/attribution integrity columns that should be immutable
-- after creation.
--
-- FIX: pin customer_id, order_number, organization_id to OLD for any non-NULL
-- auth.uid() writer (trusted server paths with uid NULL still pass through). We
-- DELIBERATELY do NOT pin line_items / notes / shipping_address — those have
-- legitimate post-creation edit flows. Re-stated from 20260611020000 with the
-- three attribution pins ADDED; all existing pins preserved byte-for-byte.
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
  NEW.payment_status            := OLD.payment_status;
  NEW.payment_method            := OLD.payment_method;
  NEW.total_amount              := OLD.total_amount;
  NEW.stripe_payment_intent_id  := OLD.stripe_payment_intent_id;
  NEW.square_payment_id         := OLD.square_payment_id;
  NEW.square_location_id        := OLD.square_location_id;
  NEW.refund_amount_cents       := OLD.refund_amount_cents;
  NEW.refunded_at               := OLD.refunded_at;
  NEW.refund_reason             := OLD.refund_reason;

  -- P10: also pin attribution/identity columns. Immutable after creation for any
  -- end-user write — re-attribution would skew loyalty + GMV-by-customer and the
  -- human-facing receipt number. (Set via COALESCE so a NULL in NEW that matches
  -- OLD's NULL is unaffected; a non-NULL OLD can never be rewritten.)
  NEW.customer_id      := OLD.customer_id;
  NEW.order_number     := OLD.order_number;
  NEW.organization_id  := OLD.organization_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_order_payment_columns ON public.orders;
CREATE TRIGGER trg_guard_order_payment_columns
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.guard_order_payment_columns();


-- #############################################################################
-- P11 — restock a stock-tracked order on DELETE.
-- #############################################################################
-- THREAT: the F11 restock helper runs on decline/auto_decline/abandon-void, but
-- the order DELETE path (api.ts removeOrder -> DELETE orders) does NOT restock —
-- a deleted, never-released stock-tracked order leaks its inventory decrement.
--
-- FIX: a BEFORE DELETE trigger that restocks the order's committed inventory iff
-- it has NOT already been released (orders.stock_released = false) AND the order
-- is in a non-terminal/non-success state (a 'completed' order's stock was
-- legitimately consumed — never restock those; a 'declined' order already
-- released via the decline path so stock_released is true and the helper no-ops).
-- restock_order_inventory is idempotent via the stock_released compare-and-swap,
-- so even a delete of an already-released order is a safe no-op.
CREATE OR REPLACE FUNCTION public.restock_order_on_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only restock orders whose stock has NOT been released yet and that are not in
  -- a state where the stock was legitimately consumed (completed) or already
  -- given back (declined). The helper's CAS makes this idempotent regardless.
  IF NOT COALESCE(OLD.stock_released, false)
     AND OLD.status NOT IN ('completed'::public.order_status, 'declined'::public.order_status) THEN
    PERFORM public.restock_order_inventory(OLD.id);
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_restock_order_on_delete ON public.orders;
CREATE TRIGGER trg_restock_order_on_delete
  BEFORE DELETE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.restock_order_on_delete();


-- #############################################################################
-- P7 (a) — prune the unbounded abuse_throttle table (daily cron).
-- #############################################################################
-- THREAT: abuse_throttle rows are never pruned; one row per distinct
-- (subject, action) persists forever, and the anon faucet mints a new uid per
-- session => unbounded growth (a slow storage DoS that amplifies the abuse it
-- guards).
--
-- FIX: a small pruner that deletes buckets whose window is older than a day, run
-- on a daily pg_cron schedule. Idempotent: re-running unschedules the prior job
-- before re-adding it.
CREATE OR REPLACE FUNCTION public.prune_abuse_throttle()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.abuse_throttle
  WHERE window_start < now() - interval '1 day';
$$;

REVOKE ALL ON FUNCTION public.prune_abuse_throttle() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prune_abuse_throttle() TO service_role;

DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('prune-abuse-throttle')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'prune-abuse-throttle');
    PERFORM cron.schedule(
      'prune-abuse-throttle',
      '17 4 * * *',                              -- 04:17 daily
      $cronjob$SELECT public.prune_abuse_throttle()$cronjob$
    );
  END IF;
END
$cron$;


-- #############################################################################
-- P6 — per-org AI call budget (cost cap). The role-restriction half of P6 ships
-- in the edge functions (_shared/auth.ts allowRoles); this is the DB substrate
-- for the per-org daily call ceiling, mirroring increment_email_usage.
-- #############################################################################
-- A tiny per-(org, day) counter. consume_ai_budget() atomically increments the
-- day's count and returns TRUE iff the caller is STILL within the cap (i.e. the
-- AI call may proceed). The edge function calls it with the service-role key
-- AFTER it has authorised the caller; a FALSE return => respond 429, do NOT call
-- Anthropic. Self-pruning is unnecessary (one row per org per day; small), but a
-- cheap retention prune is added to the daily cron above's sibling.
CREATE TABLE IF NOT EXISTS public.ai_usage (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  usage_date      date NOT NULL DEFAULT current_date,
  calls           int  NOT NULL DEFAULT 0,
  PRIMARY KEY (organization_id, usage_date)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ai_usage FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON TABLE public.ai_usage TO service_role;

-- Atomic increment + cap check. Returns TRUE when the call is ALLOWED (within
-- cap), FALSE when the org has hit its daily ceiling. SECURITY DEFINER +
-- service_role only — never reachable from anon/authenticated REST.
CREATE OR REPLACE FUNCTION public.consume_ai_budget(
  p_org_id uuid,
  p_daily_cap int DEFAULT 300
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_calls int;
  v_cap int := GREATEST(1, COALESCE(p_daily_cap, 300));
BEGIN
  IF p_org_id IS NULL THEN
    RETURN false;  -- fail CLOSED: no org to bill => deny.
  END IF;

  INSERT INTO public.ai_usage AS u (organization_id, usage_date, calls)
  VALUES (p_org_id, current_date, 1)
  ON CONFLICT (organization_id, usage_date) DO UPDATE
    SET calls = u.calls + 1
  RETURNING calls INTO v_calls;

  RETURN v_calls <= v_cap;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_ai_budget(uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.consume_ai_budget(uuid, int) TO service_role;

-- Retention prune for ai_usage (keep ~60 days). Folded into the same daily cron.
CREATE OR REPLACE FUNCTION public.prune_ai_usage()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.ai_usage WHERE usage_date < current_date - 60;
$$;

REVOKE ALL ON FUNCTION public.prune_ai_usage() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prune_ai_usage() TO service_role;

DO $cron2$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('prune-ai-usage')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'prune-ai-usage');
    PERFORM cron.schedule(
      'prune-ai-usage',
      '23 4 * * *',                              -- 04:23 daily
      $cronjob$SELECT public.prune_ai_usage()$cronjob$
    );
  END IF;
END
$cron2$;
-- =============================================================================



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
--   -- PASS-2 P6 — AI COST CAP + ROLE GATE. _shared/auth.ts now (a) returns the
--   --   caller's role + supports an allowRoles allow-list (owner/manager-only on
--   --   the expensive/money-adjacent AI fns) and (b) exposes consumeAiBudget() — a
--   --   per-org daily AI-call cap via the new consume_ai_budget RPC (fail-OPEN on
--   --   RPC error; REQUIRES migration 20260611090000 ai_usage/consume_ai_budget).
--   --   Redeploy ALL functions that import _shared/auth.ts:
--   * ai-menu-copilot, ai-menu-import, ai-inventory-assistant, ai-campaign
--     (owner/manager-only + budget), ai-decline-reasons (budget only, any staff)
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
--
--   -- PASS-2 (docs/SECURITY_AUDIT_PASS2_2026-06-11.md) — money/checkout-core:
--   * P1 (HIGH) — loyalty points awarded at PLACEMENT, never reversed on
--     decline/abandon/refund => free-reward farming. FIX (staged): move
--     awardOrderPoints OUT of the storefront place-order path; award server-side
--     ONLY on a terminal SUCCESS — in order-respond's confirm-with-paid branch (or
--     a trigger on payment_status->'paid'), idempotent per order; for
--     pay-at-venue/auto-confirm award on completion; reverse proportionally on
--     refund. Touches the live award_order_loyalty_points DRIFT RPC (P9: commit it
--     as a migration first) + RestaurantStorefront/RetailStorefront/Published
--     storefront call sites. Staged: it rewrites the loyalty-economy money path.
--   * P4 (MEDIUM) — promo usage_count consumed at placement, never released on
--     decline/abandon => griefing exhausts a limited promo. FIX (staged): release
--     usage_count when the F11 restock fires (decline/auto_decline/void), gated by
--     a new promo_released flag (mirror stock_released), OR — cleaner, pairs with
--     P1 — only increment usage_count on the terminal SUCCESS. Either rewrites the
--     promo-consume half of create_order_with_inventory + claim_order_for_response
--     / void_my_unpaid_order, so it is staged with the checkout core. (P3's
--     per-customer cap + promo_redemptions ledger shipped here does NOT depend on
--     P4 — a fully rolled-back order writes no redemption row.)
--   * P5 (MEDIUM) — anon caller can authorize a Square/Stripe charge against ANY
--     order UUID (the `!isServiceRole && callerId` ownership block is SKIPPED when
--     callerId is null). FIX (staged): an anon GUEST session still carries a uid
--     (getUser() returns the anon user), so bind the order to the placing session:
--     in square-payment + stripe-payment-intent, resolve callerId even for anon
--     and require customerOwnsOrder(callerId, order) (order.customer.user_id ==
--     callerId) unless service-role/org-staff. Reject otherwise. Staged because it
--     touches the live charge-authorization path — must be verified against the
--     real guest-checkout flow (the anon session that PLACED the order is the only
--     one allowed to PAY it) before shipping; a mistake here breaks guest payment.
--   * P9 (MEDIUM) — award_order_loyalty_points + adjust_loyalty_points are SCHEMA
--     DRIFT (live-only, in NO migration). Dump pg_get_functiondef and commit them
--     as a migration, then audit org-scope/idempotency/award-bounds. Prereq for P1.
-- =============================================================================
