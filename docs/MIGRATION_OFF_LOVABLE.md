# Migration off Lovable → self-owned Supabase + Cloudflare Pages

> **Resume doc.** Last worked: 2026-05-30 (night). Status: backend done, frontend repointed + **build-verified**, all secrets set except ClickSend. Next big step: commit scaffolding → Cloudflare Pages → DNS cutover.
> Plain-English working agreement: **explain each step before doing it, then wait for the OK.** Recommendations welcome; avoid unexplained jargon.
> 👉 **For the non-technical morning summary, see `docs/MORNING_CHECKLIST.md`.**

---

## Goal

Get Woahh **off Lovable** onto infrastructure the user owns:
- **Backend** → self-owned Supabase project (done)
- **Frontend host** → Cloudflare Pages (not started)
- **Domain** `woahh.app` is already owned on Cloudflare (currently wired to Lovable hosting + Resend)

User is **prelaunch — no real customer data**. So: fresh DB, no data copy; replay migrations as-is; do everything backend-first and treat DNS as the final, reversible switch.

---

## The two Supabase projects

| | Project ref | Role |
|---|---|---|
| **OLD** (Lovable-managed) | `ujmjbzsocqrxlqapwskb` | What the live app + Lovable still use. Leave running until cutover is verified. |
| **NEW** (self-owned target) | `pmnyhbhtkcfoozkinieo` — "Woahh DBS", region **ap-southeast-2 (Sydney)** | The migration target. Already provisioned. |

---

## ✅ STATUS: LIVE — woahh.app is OFF LOVABLE (2026-05-31)
woahh.app now serves the new app via Cloudflare Pages (`woahh-app` project) → new Supabase (`pmnyhbhtkcfoozkinieo`). Verified from the public internet: HTTP 200, live bundle references new project ×2 / old ×0. Resend webhook wired. Email subdomains untouched.

`www.woahh.app` added as a custom domain, and a www→apex 301 redirect is live and working (`www.woahh.app/eat` → `woahh.app/eat`, path+query preserved, single hop). An earlier attempt caused an apex redirect loop (rule matched the apex too) — fixed by scoping the rule strictly to `http.host eq "www.woahh.app"` and purging Cloudflare cache (it edge-caches 301s).

**Remaining finishing touches:** (1) **security: rotate GitHub PAT, rotate Resend keys, REVOKE the Supabase access token** — all were pasted in chat; (2) ClickSend (SMS) when ready; (3) commit the CI workflow after its 3 repo secrets are set; (4) optional: og-image.png, www→apex redirect (carefully).

## Progress log
- **2026-05-31 — End-to-end VERIFIED on preview:** logged in (dashboard + data), **writes work** (menu edit/add saved — RLS write policies good on new DB), **email works** (campaign sent 3/3, arrived in inbox — Resend domains campaigns.woahh.app + mail.woahh.app both verified/sending-enabled on the account behind the new `re_` key). Test merchant org id `35cf67fb-bd48-45ec-8032-32debbca84b1`. Only a transient browser popup on one campaign send (server-side send succeeded when invoked directly) — deemed non-blocking. Remaining: D repoint Resend webhook → new backend, E attach woahh.app domain (DNS cutover), F rotate exposed tokens.
- **2026-05-31 — Preview verified GREEN + test login fixed:** automated checks confirm woahh-app.pages.dev loads, references NEW project (pmnyhbhtkcfoozkinieo ×2, OLD ×0), SPA fallback + CSP + sw.js/manifest/icon all 200. Test-merchant password login first returned `invalid_credentials` (seeded hash didn't match) → reset on the new DB via `UPDATE auth.users SET encrypted_password = crypt('WoahhTest2026!', gen_salt('bf'))`; re-tested the real `/auth/v1/token?grant_type=password` endpoint → HTTP 200 with access_token. **Test login = `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` at `/business/auth`.** Business sign-in is email+password (no OTP); phone-OTP only gates new-merchant onboarding + SMS campaigns (deferred w/ ClickSend).
- **2026-05-31 — Step C (Cloudflare Pages) build SUCCESS:** Pages project `woahh-app`, preview live at **https://woahh-app.pages.dev**. Connected to GitHub repo (Pages flow, not Workers). Build command `npm run build` (first attempt failed on a `nom run build` typo — fixed), output dir `dist`, Node 20. CF uses `bun install --frozen-lockfile` for deps (reads bun.lock) then runs the npm build script. 4 env vars set in CF dashboard (VITE_SUPABASE_URL/PROJECT_ID/PUBLISHABLE_KEY, NODE_VERSION=20). Domain NOT yet attached — still on pages.dev preview; Lovable still serving production. Next: verify preview points at new DB, then C-final = attach woahh.app domain (DNS cutover).
- **2026-05-31 — Step B DONE:** committed `4ad1437` + pushed to `origin/main`. Project flip (`.env`, `config.toml`), Cloudflare files (`_headers`, `_redirects`, `.npmrc`), asset fixes (manifest icon, sitemap domain), GoTrue seed fix, migration rename, `.gitignore` for `supabase/.temp`. CI workflow `.github/workflows/supabase-deploy.yml` was **intentionally left uncommitted** (untracked) — add after its 3 repo secrets are set, to avoid a failing run. Planning docs live in `/workspaces/GrowthHub/docs/` (outside the git repo) so they're not part of repo commits.
- Step A (ClickSend SMS secrets) deferred — user will sort the SMS API later. SMS send + onboarding phone-OTP won't work on new backend until `CLICKSEND_USERNAME` + `CLICKSEND_API_KEY` are set.

---

## ✅ What's DONE (verified live on the NEW project)

- **Database:** all **70/70 migrations** applied. `pg_cron` + `pg_net` enabled. **7 cron jobs** present (auto-decline-stale-orders, dispatch-scheduled-campaigns, dispatch-marketplace-reminders, reservation-remind-every-15min, reset-sms-monthly, reset-email-monthly, flag-expired-trials-daily). **2 storage buckets** (product-images, branding-assets). **Both Vault secrets** seeded (project_url, service_role_key) — without these every cron job + courier auto-dispatch silently no-op, so this mattered.
- **All 21 edge functions deployed** (NEW is actually ahead of OLD — 4 functions never existed on Lovable).
- **Seed data present:** test merchant "Test Bistro", owner `pawitsingh23+merchant@gmail.com`, 3 customers, 1 email campaign.
- **Frontend repointed to NEW** (uncommitted working-tree changes):
  - `.env` → NEW url + real anon key (ref `pmnyhbhtkcfoozkinieo`)
  - `supabase/config.toml` → `project_id = "pmnyhbhtkcfoozkinieo"`
- **Edge-function secrets set** (Lovable parity, except ClickSend):
  - ✅ `APP_URL`, `PUBLIC_APP_URL` (=`https://woahh.app`)
  - ✅ `RESEND_API_KEY` (new key — user deleted the old Resend key, so this replacement was required)
  - ✅ `RESEND_WEBHOOK_SECRET` (`whsec_…` — for email delivery/open/click tracking)
  - ✅ `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT` (fresh keypair generated; web push. Safe — push-subscriber list was empty)
  - ✅ `SMS_WEBHOOK_SECRET` + auto-injected `SUPABASE_*`
- **Production build verified** (`npm run build`, twice, exit 0): built JS contains the NEW project URL ×6 and **0** occurrences of the old ref; `_headers` + `_redirects` correctly emitted into `dist/`. CSP `connect-src` already includes `https://` **and** `wss://` for the new project, so realtime (KDS/live updates) will work after cutover.
- **Asset fixes applied** (local, uncommitted): `public/manifest.json` icon `/icon-192.png → /icons/icon-192.png`; `public/sitemap.xml` domain `woahhapp.com → woahh.app` (+ dates bumped to 2026-05-30). Still missing: `public/og-image.png` (referenced 4× in `index.html`) — needs a real brand image; left for the user (cosmetic social-preview only).

---

## 🔜 What's LEFT (in order) — resume here

1. **ClickSend secrets** *(user paused this; will paste in the morning)*
   - Need `CLICKSEND_USERNAME` + `CLICKSEND_API_KEY`. Until set, **SMS sending won't work** on the new backend (email + web push already work).
   - Set via: `POST https://api.supabase.com/v1/projects/pmnyhbhtkcfoozkinieo/secrets` body `[{"name":"…","value":"…"}]`.

2. **Commit the migration scaffolding** to `main` *(explain before committing)*
   - Working tree to commit: modified `.env`, `supabase/config.toml`, migration `20260528052109`; staged rename `20260529130000 → 20260529131000_public_storefront_read_rpcs.sql`; **untracked** `.github/workflows/supabase-deploy.yml`, `.npmrc`, `public/_headers`, `public/_redirects`.
   - Leave `supabase/.temp/` untracked. (Per user: `.env` stays tracked for now.)

3. **Pre-cutover asset fixes** (small)
   - `public/sitemap.xml` — uses wrong domain `woahhapp.com` → fix to `woahh.app` (5 URLs).
   - `public/manifest.json` — icon `/icon-192.png` 404s; real file is `/icons/icon-192.png`.
   - `public/og-image.png` — referenced in `index.html` but missing.

4. **Cloudflare Pages setup** (the main "leave Lovable" step — user does the dashboard clicks; Claude provides exact steps)
   - Create Pages project from GitHub repo `devsup76/business-growth-hub`.
   - Build command `npm run build`, output dir `dist`, Node version 20.
   - Build-time env vars: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_PROJECT_ID`, `VITE_STRIPE_PUBLISHABLE_KEY`.
   - `_headers` (CSP already scoped to the new project) + `_redirects` (SPA fallback) ship from `public/`.

5. **Repoint 3rd-party webhooks** to the new functions domain. Exact URLs:
   - **Resend** (Dashboard → Webhooks → edit endpoint URL): `https://pmnyhbhtkcfoozkinieo.supabase.co/functions/v1/email-webhook` — already paired with the `whsec_` secret now set on the project.
   - **ClickSend** (delivery-receipt + inbound URL): `https://pmnyhbhtkcfoozkinieo.supabase.co/functions/v1/sms-webhook?secret=<SMS_WEBHOOK_SECRET>` — the `SMS_WEBHOOK_SECRET` value is already on the project (Management API can read it back when needed).
   - **Courier** → `https://pmnyhbhtkcfoozkinieo.supabase.co/functions/v1/courier-webhook` (only if dispatching couriers at launch; per-org HMAC).

6. **Verify end-to-end, then flip DNS** (apex `woahh.app`, `www` → apex, legacy `business.woahh.app` redirect). Keep OLD project + Lovable serving until verified. Rollback = revert `.env` + DNS.

7. **Security cleanup** *(user: do tomorrow)*
   - Rotate the GitHub PAT embedded in the git remote URL.
   - Rotate the Resend `re_…` / `whsec_…` values (they were pasted in chat).
   - Revoke the Supabase personal access token once the migration is finished.

---

## Notes / gotchas

- **Dev-container network:** Supabase Management API (`api.supabase.com`) works normally; the project data-plane (`*.supabase.co` — REST, functions, realtime) is blocked in the sandbox and needs sandbox-off to reach. Run network calls one at a time.
- **Stripe / billing is deferred** (was never live on Lovable). `stripe-connect-onboard` + `stripe-payment-intent` functions exist as dormant groundwork; subscription UI not built.
- **CLAUDE.md is stale** — says 41 migrations (actually 70), branch `master` (actually `main`), Stripe "not started" (functions exist), and lists TODOs 2.1/2.3 as pending though both shipped. Worth a refresh pass later.
- **Deeper app/architecture understanding** was captured this session (route model, 3 auth identities, RLS/RPC model, tier gating is visual-only not a security boundary, etc.). Ask Claude to recall it next session if needed.
