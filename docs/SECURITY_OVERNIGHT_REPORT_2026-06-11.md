# Overnight security-hardening report — 2026-06-11

**Industry-level hardening pass on the now-live payment platform. Everything is committed; only the *low-risk frontend* was deployed overnight — all edge-function + migration work is STAGED for your review this morning (a guided ~20-min session).**

Branch with the staged work: **`security/overnight-hardening-2026-06-11`** (13 commits, build green).

---

## ✅ Deployed overnight (live on `main`, verified)
Pure-frontend, no payment-logic touched — `main` commit `671d27b`:
- **15 dependency CVE patches** (`npm audit fix`, no breaking majors)
- **F24/F25** — real storefront orders can no longer be misrouted into the in-memory demo store
- **F44** — tighter security headers (Permissions-Policy deny-list, `Cross-Origin-Resource-Policy: same-site`); Square/Stripe/Turnstile/fonts CSP preserved

**Verified after deploy:** storefront still masks (no PII leak), order places at `awaiting_confirmation`, `square-payment` reaches Square (`400 Card nonce not found`) — **charge path intact.**

---

## 🗂️ Staged for your morning — do these in order

### 1. Review the branch
`git diff main..security/overnight-hardening-2026-06-11` — especially the **STAGED-FOR-REVIEW** items below (money/checkout core).

### 2. Run the migrations — `docs/SECURITY_OVERNIGHT_RUN_THESE.sql`
Idempotent, additive. (Run after a quick guest-order + booking smoke test, since F46 adds write-path triggers.) Contents:
- **F21** loyalty-code brute-force throttle · **F34** storefront_config text caps
- **F27** `security_audit_log` + sensitive-action triggers + `security_anomalies` view (monitoring)
- **F46** RPC input-length bounds (orders/customers/reservations triggers)
- **Pass-2**: P2 (rate-limit counts even on rolled-back orders), P3 (per-customer promo cap), P6 (per-org AI budget), P7 (throttle prune + fail-closed), P8 (refund can't resurrect a refunded order), P10 (attribution guard), P11 (restock on order DELETE)

### 3. Merge the branch → main, then redeploy the edge functions (AFTER step 2 migrations)
The error-handling + AI + rate-limit edge changes. Preserve each `verify_jwt` (use `--no-verify-jwt` for the 4 webhook/payment fns as before):
- **Error-leak fix (F43)** + carried fixes: `square-payment`, `stripe-payment-intent`, `refund-order`, `order-respond`, `sms-send`, `email-send`, `customer-signup`
- **F22** `account-recover` · **F29** `square-webhook` · **F45** `customer-signup` (needs migration `20260611040000`, already applied)
- **P6 AI budget/role-gate** (need the pass-2 migration first): `ai-menu-copilot`, `ai-menu-import`, `ai-inventory-assistant`, `ai-campaign`, `ai-decline-reasons`

### 4. Verify live
Place a Test Pizza pickup order → `square-payment` should still return `400 Card nonce not found`; storefront still masks. (I can drive this with you.)

### 5. Finish the CORS-hardening sweep
Redeploy the remaining ~18 unchanged functions to pick up the origin-pinned `_shared/cors.ts` (defense-in-depth, low priority).

---

## ⚠️ STAGED-FOR-REVIEW — money/checkout core (exact fixes written into the run-these doc, NOT applied)
These touch the charge/loyalty/promo path; I deliberately did **not** ship them blind:
- **P1** — loyalty points are awarded at *placement* and never reversed on decline/refund (a guest could farm points behind the captcha-less faucet). Fix: award on `payment_status→paid`, reverse on refund.
- **P4** — promo `usage_count` consumed at placement, never released on decline/abandon. Fix: release on the F11 restock path.
- **P5** — an anon caller can authorize a charge against *any* order UUID (`square-payment` / `stripe-payment-intent` let `callerId===null` pass ownership). Fix: bind the anon session to the order's customer.
- **F43** on the 4 payment fns (error-body only, no control-flow change) and **F46** (write-path triggers) — low-risk but on the money path, so review before deploy.

---

## 🔑 Founder-only (in `docs/SUPABASE_HARDENING.md`)
- **Finish key rotation** — `ghp_` PAT out of `.git/config` + rotate, plus the rest (the `sbp_` you gave is 1-day temp; rotate after).
- **Cloudflare Turnstile** — site/secret keys to arm the captcha (CSP already prepped). This is the *real* boundary the DB rate-limits only approximate.
- **Anomaly alerting** — the audit-log + `security_anomalies` view ship, but nothing *pushes* yet; pick a channel (cron→Slack/Resend, or Sentry).
- Supabase dashboard: leaked-password protection ON, JWT/OTP expiry + rate limits, PITR + a restore drill.

---

## Still open (documented, not fixed)
- **Pass-1**: F1/F2 credentials (you're rotating), F14 (charity/donation can be fabricated by an owner), F19 (consent auto-claim), F20 (enumeration), F17/F32 (the larger allowlist-projection RPC refactor — scoped "this month").
- **Pass-2 LOW**: P12–P15 (uid-only throttle bypass, consent self-tamper, attribution columns, email-escape watch-item) — see `docs/SECURITY_AUDIT_PASS2_2026-06-11.md`.

---

## Posture
Pass-1 closed the CRITICAL/HIGH money + tenant risks (deployed). Pass-2 found no regression in that work and surfaced 21 deeper issues — the safe ones are fixed-and-staged, the money-core ones are written-up for your sign-off. After you run the migrations + redeploy the edge fns this morning, the platform is materially hardened to an industry baseline, with monitoring/audit-trail in place for the first time.

*All docs: `SECURITY_AUDIT_2026-06-11.md` (pass-1), `SECURITY_AUDIT_PASS2_2026-06-11.md` (pass-2), `SECURITY_OVERNIGHT_RUN_THESE.sql` (migrations), `SUPABASE_HARDENING.md` (dashboard checklist), this report.*
