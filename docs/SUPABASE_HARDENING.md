# Supabase Hardening — Founder Dashboard Checklist

> **Audience:** the founder, clicking through the Supabase dashboard.
> **Project:** `pmnyhbhtkcfoozkinieo` (the LIVE woahh backend).
> **Why this exists:** the code-level hardening (RLS, SECURITY DEFINER RPCs,
> rate-limit RPCs, CORS pinning, no-internal-detail errors, input bounds) is
> shipped in migrations + edge functions. But a payment platform's security also
> depends on **project-level settings that can only be set in the dashboard** —
> they are NOT in any migration and will silently sit at insecure defaults until a
> human turns them on. This is that list.
>
> Each item: **what**, **where in the dashboard**, **recommended value**, **why**.
> Work top-to-bottom; nothing here can break the running app (these are guards,
> not behaviour changes) **except** where explicitly flagged "⚠️ test after".
> Created 2026-06-11 (overnight hardening pass). Pair with `repo/docs/SECURITY.md`
> (code-level fixes) and `docs/SECURITY_OVERNIGHT_RUN_THESE.sql` (the migrations).

---

## 0. TL;DR — the high-value five (do these first)

1. **Leaked-password protection: ON** (Authentication → Policies / Password) — blocks
   HaveIBeenPwned-known passwords on signup/reset. One toggle, large payoff.
2. **PITR / point-in-time-recovery + verified backups** (Database → Backups) — a
   live payment platform must be able to roll back. Confirm the schedule + restore.
3. **Anonymous sign-in abuse controls** (Authentication → Providers → Anonymous +
   Turnstile/captcha) — guest checkout mints anon sessions; cap the faucet.
4. **OTP + email/SMS send rate limits** (Authentication → Rate Limits) — stop OTP
   spam / cost-blowout / enumeration.
5. **Shorten JWT access-token expiry + keep refresh-token rotation ON**
   (Authentication → Sessions) — limits a leaked access token's blast radius.

---

## 1. Authentication — passwords

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Leaked password protection** | Auth → Providers → Email (or Auth → Policies) | **ON** | Rejects passwords found in the HaveIBeenPwned breach corpus at signup/reset. The single highest-ROI auth toggle. |
| **Minimum password length** | Auth → Providers → Email | **≥ 12** | The custom `customer-signup` edge function already enforces 12-char + complexity; set the GoTrue floor to match so the hosted `/signup` and password-reset paths can't undercut it. |
| **Password required characters** | Auth → Providers → Email | lower + upper + digit + symbol | Mirror the `STRONG_PASSWORD_RE` in `customer-signup`. |

> Note: woahh routes customer signup through the `customer-signup` edge function
> (strong-password + rate-limited), but the **owner/merchant** signup and ALL
> password resets use GoTrue directly — so these dashboard settings DO matter.

---

## 2. Authentication — sessions, JWT & refresh tokens

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Access token (JWT) expiry** | Auth → Sessions | **3600 s (1 h)** or less | A leaked access token is bearer-only and can't be revoked until it expires. Shorter = smaller blast radius. Default is often 3600; do not raise it. |
| **Refresh token rotation** | Auth → Sessions | **ON** | Each refresh issues a new refresh token and invalidates the old one → a stolen refresh token is detectable (reuse = breach) and short-lived. |
| **Refresh token reuse interval** | Auth → Sessions | small (e.g. 10 s) | Tolerates a legitimate double-refresh race without permanently widening the reuse window. |
| **Inactivity / time-box session timeout** | Auth → Sessions | set a max session lifetime (e.g. 30 days) | Bounds how long a never-refreshed-out session can live. |
| **JWT signing keys** | Auth → Signing Keys | rotate on a schedule; rotate IMMEDIATELY if a service-role/JWT-secret leak is suspected | The service-role key + JWT secret have appeared in chat during dev — see the "ROTATE keys" notes in MEMORY. Treat as compromised until rotated. |

> ⚠️ test after shortening JWT expiry: confirm the dashboard, KDS realtime, and an
> in-progress checkout all silently refresh (they should — the client auto-refreshes).

---

## 3. Authentication — OTP & email/SMS rate limits

woahh sends: owner phone OTP (`owner-verify`, ClickSend), customer magic links,
signup confirmation emails, password resets. Each is a cost + abuse + enumeration
surface. Set hosted-side limits so an attacker can't loop them.

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Email OTP / magic-link send rate** | Auth → Rate Limits | tight (e.g. 3–5 / hour / identifier) | Stops magic-link / reset spam and email-bombing a victim address. |
| **SMS OTP send rate** | Auth → Rate Limits | tight (e.g. 3 / 15 min / number) | OTP SMS costs real money (ClickSend); a loop is a billing-DoS. The app's own `owner-verify` has counters, but set the hosted floor too. |
| **OTP verify (failed) rate** | Auth → Rate Limits | tight | A 6-digit OTP is brute-forceable; limit verify attempts per identifier. |
| **OTP length** | Auth → Providers | **≥ 6 digits** | More entropy per code. |
| **OTP expiry** | Auth → Providers | **≤ 600 s (10 min)**, ideally shorter | Short-lived codes shrink the brute-force window. |
| **Token (email confirm / recovery) expiry** | Auth → Providers | short (e.g. 1 h) | Limits the window a leaked confirm link is usable. |

> The app-level account-recovery throttle (max 3 attempts/hr, `account_recovery_log`)
> and the loyalty-code throttle (`loyalty_code_attempts`, F21) are already in
> migrations — these dashboard limits are the complementary GoTrue-side guard.

---

## 4. Anonymous sign-ins — abuse controls (guest checkout)

Guest checkout mints a **real anonymous session** (`auth.uid()` non-null) so consent
+ the customer row can be written via `upsert_my_consent`. That faucet must be
capped or it becomes a free user-creation / order-spam vector.

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Anonymous sign-ins** | Auth → Providers → Anonymous | **ON, but gated** | Required for guest checkout. Do NOT leave it ungated at scale. |
| **CAPTCHA / Turnstile on auth** | Auth → Bot & Abuse Protection (Attack Protection) | **ON (Cloudflare Turnstile)** | Already allowed in CSP (`challenges.cloudflare.com`). Forces a human gate before an anon session (and before signup/OTP) — the single best control on the guest faucet. **FOUNDER-INPUT:** needs the Turnstile site/secret keys wired. |
| **Anonymous sign-in rate limit** | Auth → Rate Limits | tight per-IP | Caps how fast one source can mint anon sessions. |
| **Periodic anon-user cleanup** | Database (scheduled job) | delete anon users with no order + older than N days | The app guards org-provisioning triggers for anon users (`20260609010000`); add a janitor so abandoned anon rows don't accumulate. The app-side `rate_limit_hit('place_order')` + open-order cap (F12) already blunt order-spam. |

---

## 5. Backups, PITR & disaster recovery

A live payment platform MUST be restorable. This is non-negotiable.

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Point-in-time recovery (PITR)** | Database → Backups → PITR | **ON** (needs a paid compute add-on) | Roll back to any second — essential after a bad migration, a deletion, or a breach. Daily snapshots alone lose up to 24 h. |
| **Daily backups** | Database → Backups | verify retention (≥ 7 days) | Baseline even with PITR. |
| **Restore drill** | — | do ONE test restore into a scratch project | A backup you've never restored is a hope, not a backup. Confirm `auth.users`, `orders`, `donation_ledger`, `square_connections` all come back intact. |
| **Off-platform export** | — | periodic `pg_dump` to cold storage you control | Survives a Supabase-account-level incident (lockout / billing). |

---

## 6. Database / network exposure

| Setting | Where | Set to | Why |
|---|---|---|---|
| **Network restrictions / IP allowlist** | Database → Network Restrictions | restrict direct Postgres (5432/6543) to known IPs; the app uses PostgREST/edge, not raw Postgres | Closes direct DB connections from the internet. The app never needs a public 5432. |
| **SSL enforcement** | Database → Settings | **Enforce SSL** | Reject non-TLS DB connections. |
| **Service-role key handling** | Project Settings → API | never ship to the client; only in edge-function secrets | The service-role key bypasses RLS. It belongs ONLY in `SUPABASE_SERVICE_ROLE_KEY` (edge secret), never in `VITE_*`. Confirm no `VITE_*SERVICE*` anywhere. |
| **`anon` / `authenticated` role grants** | (migrations) | least-privilege | Already handled in code: public reads go through `SECURITY DEFINER` RPCs (`get_public_storefront`, `get_public_menu`, …); `rate_limit_hit` and the throttle tables are `REVOKE ALL FROM PUBLIC`. No action unless you add a new public RPC — then mirror the pattern. |
| **Leaked-secret rotation** | Project Settings → API + all providers | rotate anything pasted in chat/logs | Per MEMORY: several `sbp_…` / `ghp_…` / ClickSend / Anthropic keys were exposed during dev. Rotate: Supabase access tokens + service-role + JWT secret, ClickSend, Resend, Stripe (restricted keys), Square, GitHub PATs, Anthropic. |

---

## 7. Edge functions — runtime config

| Setting | Where | Set to | Why |
|---|---|---|---|
| **`verify_jwt` per function** | Function config | OFF only where a public/guest/webhook caller is intended (`square-payment`, `stripe-payment-intent`, `customer-signup`, `*-webhook`, public-reservation paths); ON elsewhere | These functions enforce their own auth (bearer check + order-ownership, or webhook-signature verification). Anything that should be owner/staff-only must keep `verify_jwt` ON. Audit the list. |
| **Webhook signature secrets present** | Function secrets | `STRIPE_WEBHOOK_SECRET`, Square webhook signature key, `SVIX`/Resend HMAC | The webhooks verify signatures in code — they fail-closed only if the secret is set. Confirm each is populated. |
| **`CORS_EXTRA_ORIGINS`** | Function secrets | leave UNSET in prod (or apex-only) | CORS is origin-pinned to `*.woahh.app` + `*.pages.dev` in `_shared/cors.ts`. Only add an extra origin here if a real integration needs it; never `*`. |
| **Secrets inventory** | Function secrets | confirm all set | `SUPABASE_SERVICE_ROLE_KEY`, `CLICKSEND_*`, `RESEND_API_KEY`, `APP_URL`, Stripe (`STRIPE_SECRET_KEY` live), Square OAuth app id/secret + `SQUARE_API_BASE` (must be exactly the sandbox/prod host — `square-payment` fails closed otherwise), VAPID push keys. |

---

## 8. Monitoring — pg_cron, audit trail & alert wiring

The audit-trail + anomaly **data layer** is shipped (migration
`20260611070000_security_audit_log.sql`: `security_audit_log` + sensitive-action
triggers + the `security_anomalies` view). The **alert hop is NOT wired** — that's
the open founder action.

| Item | Where | Action | Why |
|---|---|---|---|
| **pg_cron extension** | Database → Extensions | confirm `pg_cron` enabled | The app relies on it: `auto_decline_stale_orders` (every min), `dispatch_scheduled_campaigns` (every min), monthly SMS/email usage resets, reservation reminders. |
| **pg_cron job health** | `cron.job` / `cron.job_run_details` | spot-check `status='succeeded'` recently for each job | A silently-failing auto-decline cron means stale orders never time out / never auto-void a card hold. **FOUNDER-INPUT:** add a heartbeat (last-success-per-job) reconcile. |
| **`pg_net` for outbound alerts** | Database → Extensions | enable if you choose the cron→webhook alert path | Needed for `net.http_post()` to Slack/Resend. |
| **Anomaly alerting (close F27)** | — | **FOUNDER-INPUT — pick a channel:** (1) pg_cron polls `security_anomalies` → `net.http_post()` to Slack/Resend (needs a webhook URL as a Vault secret), or (2) a Supabase Database Webhook on the high-severity `security_audit_log` actions, or (3) a log drain → Sentry/Datadog. | The trail + signal exist; nothing PUSHES on an anomaly yet. Until wired, anomalies are pull-only (operator reads the view). |
| **Log drains / observability** | Project → Logs / Integrations | enable a drain (Logflare/Sentry/Datadog) | The F43 `_shared/errors.ts` change logs full error detail server-side with a short `ref` — those logs are only useful if retained/searchable. Wire a drain so an incident can be reconstructed from the `ref`. |
| **Supabase security/Postgres advisors** | Advisors (Security + Performance) | review + clear | Catches missing-RLS, SECURITY DEFINER without `search_path`, exposed-extension warnings the migrations may not cover. |

---

## 9. Quick verification (after you've clicked through)

- [ ] Place a **real guest order** end-to-end on a test merchant — still works (anon
      session + Turnstile gate + consent + receipt).
- [ ] Trigger a **failed payment / forced edge-function error** — confirm the client
      response is generic (`{"error":"…","ref":"…"}`) with NO stack/DB/Stripe detail,
      and the full detail IS in the function logs under that `ref` (F43).
- [ ] Submit an **over-long name / 1MB notes** at checkout/booking — rejected/clamped
      cleanly, order/booking otherwise unaffected (F46).
- [ ] Hammer **`customer-signup`** > 4×/email or > 12×/I/hr — get a 429 (F45).
- [ ] Confirm a **password from a breach list** is rejected at signup/reset (§1).
- [ ] Do ONE **backup restore drill** into a scratch project (§5).

---

## Cross-references

- Code-level fixes (RLS, RPCs, CORS, errors, bounds): `repo/docs/SECURITY.md`
- Migrations to run (incl. F43/F45/F46 from this pass): `docs/SECURITY_OVERNIGHT_RUN_THESE.sql`
- Guest-checkout / anon-session design: `repo/docs/GUEST_CHECKOUT_DESIGN.md`
- Audit findings + deferred items: `docs/AUDIT_FINDINGS_2026-06-09.md`
