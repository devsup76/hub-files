-- =============================================================================
-- ALIGN repo<->live schema drift — backfill the security columns that 2 edge
-- functions need but live never received.
-- =============================================================================
-- The repo migration history drifted ahead of live: 20260602101000 (OTP attempt
-- counter) + 20260602101500 (recovery-log IP) were never applied to the live DB.
-- As a result owner-verify (phone OTP) + account-recover (password recovery) — if
-- (re)deployed from the repo — 42703 at runtime against live. These columns are
-- legitimate security controls (OTP brute-force rate-limit + recovery audit/IP
-- rate-limit), so the correct reconciliation is to BACKFILL them on live, not strip
-- them from the code. Additive + idempotent. No data change to existing rows
-- (phone_otp_attempts defaults 0; ip is nullable).
--
-- NOTE: orders.receipt_token stays RE-BASELINED (the 20260610070000 hotfix uses
-- the order UUID as the public tracker token; we do NOT add receipt_token). See
-- docs/SCHEMA_DRIFT_RECONCILIATION.md.
-- =============================================================================

-- 1. OTP attempt counter (owner-verify increments this to lock after N attempts).
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS phone_otp_attempts int NOT NULL DEFAULT 0;

-- 2. Recovery-log IP (account-recover logs + rate-limits by IP).
ALTER TABLE public.account_recovery_log
  ADD COLUMN IF NOT EXISTS ip text;

CREATE INDEX IF NOT EXISTS account_recovery_log_ip_attempted_at_idx
  ON public.account_recovery_log (ip, attempted_at DESC);

-- After applying: redeploy owner-verify + account-recover so live runs the repo
-- versions (they now have their columns). Until then, the OLD live versions of
-- those functions keep working (they don't reference these columns).
