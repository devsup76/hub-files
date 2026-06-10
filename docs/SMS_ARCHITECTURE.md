# Woahh SMS Architecture & Migration Status

> **Durable record** — kept in the repo so it survives container/memory resets.
> Last updated: 2026-05-31 (audit-confirmed). Owner: pawit. (The off-Lovable migration handoff docs were deleted in the 2026-06-10 docs cleanup — migration long done; history in git.)
> Status legend: ✅ built · 🟡 partial · ⬜ missing · ♻️ orphaned (defined but unused)

## TL;DR — where we are

Migrating Woahh off Lovable onto a fresh Supabase project (ref `pmnyhbhtkcfoozkinieo`);
in the same push we built **per-merchant SMS**. **STATUS (2026-05-31): audit-fixed, deployed,
and verified end-to-end on the new backend — both outbound campaigns AND inbound STOP/opt-out
work** (see Live test log). Remaining: merge `feat/per-merchant-sms` → `main`, and for production
buy a dedicated ClickSend number per real merchant (+ a shared OTP number) and assign via the
AdminSmsNumbers page. SMS code landed in migration `20260531000000`.

## The two-number model (the core idea)

Mirrors the email split (shared `mail.woahh.app` transactional + per-merchant
`campaigns.woahh.app` marketing):

| Number | Purpose | Source | Opt-out scope |
|---|---|---|---|
| **Shared Woahh number** | Platform OTP (owner phone verification) + transactional (reservation reminders) | **`WOAHH_SMS_NUMBER` env secret** — used by `owner-verify` + `reservation-remind` | n/a (transactional) |
| **Per-merchant number** (`organizations.sms_number`) | Each merchant's **marketing** campaigns | Platform-admin assigns a purchased ClickSend number per org (`admin_assign_sms_number`) | **STOP opts out of that ONE merchant only** |

**Why per-merchant numbers:** a customer's `STOP` must unsubscribe them from that merchant
alone. `sms-webhook` resolves the org by the inbound `to` number (the merchant's
`sms_number`), so the opt-out is naturally scoped.

## Components (audit-confirmed)

### Database (`repo/supabase/migrations`)
- ✅ `organizations.sms_number` (text) — per-merchant dedicated number. Added `20260420035346`. **Canonical sender** for all live sends.
- ♻️ `organizations.sms_sender_id` (text) — **ORPHANED.** Never written anywhere; only *read* by `reservation-confirm` (which is a bug — see issues). Defaults null → that read falls back to the literal `"growerr"`. Not in `demo.ts`, no UI. **Should be removed or unified onto `sms_number`.**
- ✅ `organizations.sms_monthly_cap` / `sms_used_this_month` / `sms_topup_credits` — quota. Caps via `apply_tier_caps()` (solo=0, marketplace=700, growth=1000, enterprise=2500). _Open: confirm the `reset_monthly_sms_usage()` pg_cron job is actually scheduled on the new project._
- ✅ `customers.sms_opted_out` / `sms_opted_out_at` / `sms_consent_at` / `sms_consent_method` — **`sms_opted_out` is the single source of truth** `sms-send` filters on.
- ✅ `merchant_connections.sms_marketing_consent` — per-merchant per-customer consent mirror driving the Account-portal toggle.
- ✅ RPC `admin_assign_sms_number(p_org, p_number)` — platform-admin only (hardcoded JWT email `pawitsingh23@gmail.com`); asserts SMS-enabled tier + uniqueness. Migration `20260531000000`.
- ✅ RPC `set_sms_consent(p_org, p_consent)` — customer per-merchant toggle; SECURITY DEFINER; authorizes via caller's own `merchant_connections` row; writes through to `customers.sms_opted_out` + mirrors `merchant_connections.sms_marketing_consent`. Migration `20260531000000`.
- ✅ `sms_campaigns` + `sms_log` tables with appropriate RLS.

### Edge functions (`repo/supabase/functions`)
- ✅ `_shared/sms.ts` — provider abstraction. `SmsProvider` + `ClickSendProvider`; swap via `SMS_PROVIDER` env, no call-site changes. Reads `CLICKSEND_USERNAME` / `CLICKSEND_API_KEY`; fails safe ("credentials missing") when unset.
- ✅ `sms-send/index.ts` — campaign sender. Owner-JWT or service-role. Requires `org.sms_number` (400 if unprovisioned). Audience filters; sends from `org.sms_number`; appends `"- {org.name}. Reply STOP to opt out."`; logs + consumes monthly-then-topup quota. (Correctly **ignores** `sms_sender_id` — that's by design, not a bug.)
- ✅ `sms-webhook/index.ts` — DLR + inbound STOP, scoped per-merchant by `to`==`sms_number`. `SMS_WEBHOOK_SECRET` shared-secret gate (currently **fail-open**: warns-but-allows when unset). Has the confirmed bugs below.
- ✅ `owner-verify` / `reservation-remind` — send from the shared `WOAHH_SMS_NUMBER`.
- 🐞 `reservation-confirm` — sends from orphaned `sms_sender_id` (→ "growerr"); also has dead ClickSend-cred reads. See issues.

### Frontend (`repo/src`)
- ✅ `pages/dashboard/SMSCampaigns.tsx` — campaign builder + send (130-char body, audience, schedule presets, usage meter, sender-number display, phone-verify gate). Gates "Send" on `org.sms_number` present (else a "contact support" message — by design).
- ✅ `pages/Account.tsx` — per-merchant SMS consent toggle → `profileApi.updateConsent` → `set_sms_consent` RPC (api.ts ~1404).
- 🐞 `pages/dashboard/AdminSmsNumbers.tsx` — **fully built** admin provisioning UI (assigns `sms_number` via `admin_assign_sms_number`, gated to owner email) **but imported and never routed** in `App.tsx` → unreachable. See issues.
- ⬜ `pages/dashboard/Operations.tsx` — no SMS section (no number/sender display). _Optional polish, not required for launch; the campaign page already shows the number._

## Consent & compliance (ACMA / Spam Act)
- Spam Act needs **consent + identification + functional unsubscribe** — pipeline enforces all three (require `sms_consent_at`; append `- {org.name}`; STOP handled + confirmed).
- ACMA **SMS Sender ID Registry** (2024+): alphanumeric Sender IDs must be carrier/provider-registered (ClickSend). See `docs/legal/legalities.md` §6.5. **Decision needed:** numeric per-merchant numbers only (no registration), or alpha Sender IDs (needs an ABN-collection + registration ops flow). The stray `"growerr"` alpha literal must go regardless.

---

## Confirmed audit findings (2026-05-31) — deduped & reconciled

> 14 confirmed by adversarial verifiers; 13 candidate findings were rejected as false (notably:
> `sms-send` ignoring `sms_sender_id` is **correct by design**; the monthly/topup usage updates
> are a **single atomic `update()`**; STOP footer enforcement is fine). Below is the reconciled set.

### 🔴 Critical
1. **`deliveryStatusRaw` undefined crash** — `sms-webhook/index.ts:87` references an undeclared variable; on a *failed* delivery receipt this throws (swallowed by the outer catch), so failed-DLR status updates are silently lost. **Fix:** `failed_reason: newStatus === "failed" ? status : null`.

### 🟠 High
2. **`AdminSmsNumbers` unreachable** — component imported in `App.tsx:54` but has **no `<Route>`** (and no sidebar link) → the only per-merchant number-provisioning UI can't be opened. **Fix:** add `<Route path="admin/sms" element={<AdminSmsNumbers />} />` beside the `admin/codes` route (~App.tsx:141).
3. **`reservation-confirm` sends from `"growerr"`** — reads orphaned, always-null `sms_sender_id` and falls back to the literal alpha sender `"growerr"`. **Fix:** select+use `sms_number` (mirror `reservation-remind`), or `WOAHH_SMS_NUMBER` for the transactional path.
4. **STOP false positives** — `sms-webhook/index.ts:112` uses `startsWith` on keywords incl. "END"/"QUIT"/"CANCEL", so "ENDORSE", "QUITE", "CANCELLATION"… trigger an opt-out. **Fix:** match the message's first word exactly.
5. **Opt-out confirmation SMS not logged/counted** — `sms-webhook` sends the unsubscribe-confirmation but writes no `sms_log` row and doesn't decrement quota. **Fix:** log it + count it (the confirmation must still always send — Spam Act).
6. **ClickSend secrets unset on new project** — `CLICKSEND_USERNAME` / `CLICKSEND_API_KEY` not yet set on `pmnyhbhtkcfoozkinieo` → all sends fail "credentials missing." Ops step (checklist #1). Code already fails safe.
7. **`WOAHH_SMS_NUMBER` undocumented + unset** — the shared OTP/transactional number; referenced by `owner-verify`/`reservation-remind` but not documented as a required secret and not yet set on the new project.

### 🟡 Medium
8. **`sms-webhook` fail-open auth** — accepts unauthenticated webhooks when `SMS_WEBHOOK_SECRET` is unset (backward-compat warn). **Fix:** make it fail-closed once the secret is confirmed set on the new backend (match `email-webhook`).
9. **TOCTOU in `sms-send`** — capacity read and usage increment are non-atomic and there's no atomic campaign claim; concurrent sends on one org can over-consume / double-send. **Fix:** add an `increment_sms_usage` RPC + atomic campaign-status claim, mirroring `email-send` hardening.
10. **Orphaned `sms_sender_id` column** — remove it (after #3 stops reading it) or unify onto `sms_number`.

### ⚪ Low
11. **Dead code in `reservation-confirm`** — declares `CLICKSEND_USERNAME`/`CLICKSEND_API_KEY` it never uses (`index.ts:59-60`). Delete.
12. **Opt-out confirmation failure not persisted** — capture the `SendResult` and record a failed row instead of relying on a catch that won't fire.

---

## Live test log
- **2026-05-31** — ClickSend creds (`adminwoahhapp@proton.me`) **verified working**: direct API smoke-test to `+61435140245` returned `SUCCESS` (`message_id 1F15CDDE-…`, Optus, $0.079 AUD). **Sent from ClickSend _shared_ system number `+61448653472`** (`is_shared_system_number: true`) → **no dedicated number is provisioned yet.** The per-merchant model needs a purchased ClickSend dedicated number to assign as `organizations.sms_number`; `WOAHH_SMS_NUMBER` (shared OTP) can be a second dedicated number or, interim, the shared pool.
- **2026-05-31 (cont.)** — Supabase PAT validated. **Secrets set** on `pmnyhbhtkcfoozkinieo`: `CLICKSEND_USERNAME`, `CLICKSEND_API_KEY`, `SMS_WEBHOOK_SECRET`, `WOAHH_SMS_NUMBER=+61448653472` (interim shared) (`RESEND_*` already present). **Deployed** fixed functions: `sms-send`, `sms-webhook`, `reservation-confirm`, `reservation-remind`, `owner-verify`.
- **2026-05-31 — END-TO-END SEND VERIFIED.** Decision: **use shared number for now** (`+61448653472`). Assigned Test Bistro (`35cf67fb…`, marketplace) `sms_number=+61448653472`; created a consented test customer at the owner mobile `+61435140245`; signed in as owner `pawitsingh23+merchant@gmail.com` (password reset to documented `WoahhTest2026!`) and invoked deployed `sms-send` → `{sent:4}`. `sms_log`: 3 fake seed numbers (`+6140000000x`) + owner mobile, all `sent` from `+61448653472`. Confirms owner-auth + consent filter + ClickSend send + logging + usage. **Owner-auth note:** `sms-send` has `verify_jwt=true`; the new `sb_secret_` key is rejected by the gateway (not JWT) and the legacy service-role JWT doesn't match the function's `SUPABASE_SERVICE_ROLE_KEY` — so service-role invocation fails; use an owner/user JWT (as the dashboard does).
- **2026-05-31 — STOP / OPT-OUT VERIFIED end-to-end** with a real dedicated number. Bought `+61455725154` (ClickSend, status `REGISTRATION_NOT_REQUIRED` — numeric numbers are ACMA-exempt), assigned it to Test Bistro `sms_number`, and created a ClickSend inbound rule (`rule_id 2327822`, `action=URL`, match-all) forwarding replies to `…/functions/v1/sms-webhook?secret=05f9c6fe…`. Sent a campaign from `+61455725154` → replied STOP → `sms_log` shows the full chain: campaign `sent`, inbound `STOP` logged as `opted_out`, and the unsubscribe-confirmation `sent` (the new logged-confirmation fix). `customers.sms_opted_out` flipped to `true`, scoped to Test Bistro via the webhook's org-by-`to`-number lookup. **Send + STOP both fully functional on the new backend.** (Configured via the ClickSend automations API — no dashboard step needed.)

## What's left — TEST + DEPLOY checklist
1. ⬜ Set ClickSend secrets on the new project: `CLICKSEND_USERNAME`, `CLICKSEND_API_KEY`.
2. ⬜ Set `WOAHH_SMS_NUMBER` (E.164 AU number) for OTP/transactional.
3. ⬜ Set `SMS_WEBHOOK_SECRET`, then append `?secret=<value>` to the ClickSend delivery + inbound webhook URLs (repoints them at the new backend).
4. ⬜ Fix the bug list above — at minimum the **critical** (#1) and the **growerr** (#3) and **STOP false-positive** (#4) issues before any live send.
5. ⬜ Route `AdminSmsNumbers` (#2), then provision a per-merchant number for the test org via `admin_assign_sms_number`.
6. ⬜ Confirm `reset_monthly_sms_usage()` pg_cron job exists/active on the new project.
7. ⬜ **End-to-end test:** create a campaign from the test merchant → confirm DLR updates `sms_log` → reply STOP → confirm scoped opt-out + confirmation SMS + `opted_out_count` increment → confirm the customer is excluded from the next send.
8. ⬜ Deploy `sms-send` + `sms-webhook` (verify `config.toml`: `sms-webhook` must be `verify_jwt=false`; `sms-send` correctly defaults to `verify_jwt=true`).

## Resolved open questions
- **Shared OTP number source?** → `WOAHH_SMS_NUMBER` env secret. ✅
- **Is `sms_sender_id` used?** → No — orphaned; only mis-read by `reservation-confirm`. ✅
- **Admin provisioning UI?** → Exists (`AdminSmsNumbers.tsx`) but unrouted/unreachable. ✅

## Still-open (product decisions, not code)
- Numeric-only sender numbers vs alphanumeric Sender IDs (latter needs ABN + ACMA/ClickSend registration ops flow).
- ClickSend bulk pricing tier vs projected volume (e.g. 700/mo × N merchants).
- Whether to add a merchant-facing SMS section in Operations (display the assigned number + a Sender-ID-registration surface per legalities §6.5).

## SMS provider pricing (AU, researched 2026-05-31)
All AU, ex-GST (+10%), per 160-char GSM-7 segment (marketing msgs often 2–3 segments):

| Provider | Outbound/seg | Inbound (STOP) | Dedicated AU #/mo | Billing |
|---|---|---|---|---|
| **ClickSend** (current) | ~$0.072 → $0.057 @150k+ | **free** | $20.71 | AUD, GST handled |
| **Twilio** | ~$0.072 (USD $0.0515) | ~$0.010 (charged) | ~$11.50 (USD $8.25) | **USD (FX risk)** |
| **Cellcast** (cheapest AU) | ~$0.037 → $0.028 | free | ~$18–19 | AUD |
| SMSGlobal | $0.038 → $0.016 (subscription) | — | quote | AUD |
| MessageMedia | $0.079 → $0.059 (+ plan fee) | — | from $115 plan | AUD |

**Verdict:** ClickSend ≈ Twilio on outbound, but **ClickSend is cheaper all-in for AU** (free inbound STOP replies; AUD billing, no FX; only loses on number rental). **Cellcast is ~half the per-SMS cost** — worth a switch at volume; the `SMS_PROVIDER` abstraction makes it a drop-in. Stay on ClickSend for now (verified working); revisit Cellcast when volume grows.

**⚠️ ACMA SMS Sender ID Register** — registration opens **30 Nov 2025**, enforced **1 Jul 2026**. From then, unregistered *alphanumeric* sender IDs to AU mobiles are flagged "Unverified". **Numeric dedicated/virtual mobile numbers are EXEMPT** — which validates the per-merchant *numeric* `sms_number` model (you can't realistically register a unique alpha sender ID per merchant). Keep senders numeric; avoid alpha tags per-tenant.

## Security review (2026-05-31, pre-merge gate + sweep `wf_2a109cbd-20e`)

**Live-exploitable bugs found + fix (caught by attack-testing, missed by static audit):**
- 🔴 `admin_assign_sms_number` AND `generate_founding_codes` used a NULL-unsafe admin gate
  `(auth.jwt()->>'email') <> 'admin'` — `NULL <> 'x'` is `NULL` (falsy), so any caller without an
  email claim (anon) slipped past, and the default `CREATE FUNCTION` grants EXECUTE to PUBLIC.
  Confirmed live: anon reached the function body (could hijack a merchant's `sms_number` / mint
  permanent zero-commission founding codes). **Fix:** `IS DISTINCT FROM` (NULL-safe) + `REVOKE
  EXECUTE FROM PUBLIC`. SMS RPC fixed on the branch; founding fix + both live-DB re-applies are the
  morning SQL in `docs/MORNING_HANDOFF.md` (run live; doc deleted 2026-06-10, in git history). **`founding_access_codes` is already in `main`/prod.**
- **Lesson:** static review missed both; the live anon attack test caught them. Attack-test every
  SECURITY DEFINER admin gate.

**Hardening backlog (not live-exploitable; original list lived in the deleted `MORNING_HANDOFF.md` — items reconciled below):**
owner-verify OTP lacks brute-force lockout (top); `reservation-remind` uses `.includes(SERVICE_KEY)`
substring auth; `sms-webhook` fail-open secret gate + PII payload log + NULL-`to` opt-out guard;
explicit `REVOKE FROM PUBLIC` on the intentionally-public token RPCs. Confirmed NON-issues: `sms_log`
RLS (proper org-scoped SELECT policy), `sms-send` exact bearer compare.

### ⚠️ 2026-06-02 RECONCILE — the section below CORRECTS the stale "branch security/sms-hardening-backlog" claim

**What the old notes got wrong:** they said the hardening backlog (#1 owner-verify OTP lockout, #2
reservation-remind, #3 sms-webhook) was implemented on a branch `security/sms-hardening-backlog` off
`origin/main`. Git did NOT match: that branch points at *old* main (`cace9df`), and the hardening commit
(`397a289`) was actually stranded on `feat/ingredient-availability` mixed with unrelated WIP. Meanwhile a
**separate** security merge — `origin/main` `2f485ec` "harden-critical-and-high" — had landed *after* those
notes and **already covered most of the backlog**: it added an `owner-verify` OTP **attempt-counter** (a
simpler variant than the docs' timed-lockout, migration `20260602101000_owner_otp_attempts.sql`), made
`sms-webhook` **fail-closed**, and fixed STOP exact-word matching + the `deliveryStatusRaw` crash. So #1 and
most of #3 were already done; only a slice of the backlog genuinely remained.

**Ground-truth audit (2026-06-02, workflow `wf_95ed0ae7-41c`, 22 agents, adversarially verified)** against the
REAL `origin/main` code found **8 still-open gaps**. All 8 implemented on a clean branch
**`security/sms-hardening-remainder`** off `origin/main` (worktree `/workspaces/GrowthHub/repo-sms`):

1. `reservation-remind` — substring `auth.includes(SERVICE_KEY)` → strip-prefix + exact `bearer === SERVICE_KEY`.
2. `sms-webhook` — dropped the raw-payload `console.log` (logged customer phone + body = PII); logs only contentType + byte length now.
3. **`sms-send` atomic campaign claim** (HIGH) — mirrors `email-send`; a user double-click / cron-retry no longer double-sends + double-charges. *Required a client change:* `SMSCampaigns.tsx` now inserts an immediate send as `'draft'` (not `'sending'`) so the claim `draft→sending` genuinely serializes (a `'sending'→'sending'` claim is a no-op both racers would match). NOTE: `email-send` + `EmailCampaigns.tsx` carry the **same latent shape** — out of scope here, follow-up.
4. **`sms-send` atomic `increment_sms_usage` RPC** (new migration `20260602120000`) replaces the read-modify-write that lost updates under concurrent sends.
5. `sms-send` outer try/catch + status-guarded `revertDraft` + stale-`sending`(>10min) re-claim guarded by `.lt(updated_at, tenMinAgo)` so a crashed send can't wedge a campaign and two recoverers can't both win.
6. **`sms-webhook` STOP E.164 normalization** (HIGH, Spam Act) — `phoneVariants()` matches the inbound `to`/`from` across `+61…/61…/0…/bare` so a format mismatch can't silently drop a STOP; warns (no PII) on a zero-row opt-out; guards empty `from`/`to`.
7. `admin_assign_sms_number` E.164 validation (new migration `20260602120500`) + client check in `AdminSmsNumbers.tsx` — can't store an unroutable/alpha number that would break that merchant's STOP.
8. **`reservation-confirm` SMS idempotency** (new migration `20260602121000` adds `reservations.confirmation_sms_sent_at`) — a conditional UPDATE makes the unauth endpoint's SMS leg once-only (kills the SMS-bomb / credit-drain), with revert-on-failure so a transient provider error still allows a retry.

**Already in `origin/main` (NO work needed):** owner-verify OTP attempt-counter; reservation-confirm "growerr"
sender gone; admin-gate NULL-safety + REVOKE-FROM-PUBLIC; webhook fail-closed; STOP exact-word match; frontend routing/consent wiring.

### 📵 Reservations = EMAIL-ONLY for now (cost decision, 2026-06-02)

Per owner: conserve SMS credits → **SMS is reserved for sign-up OTP (`owner-verify`) only**; reservations
stick with email; marketing is held (naturally — no per-merchant numbers provisioned). Implemented as an env
flag **`RESERVATION_SMS_ENABLED`** (default **OFF** = email-only) gating the SMS leg of both
`reservation-confirm` and `reservation-remind`; the email legs are untouched. Re-enable globally by setting it
`true`, or upgrade to a per-merchant/per-tier `settings.reservations.sms_enabled` (a possible "SMS reminders"
upsell — SMS reminders cut no-shows harder than email).

### Review + state

Pre-commit adversarial review (`wf_29ca92ed-6a4`) caught 1 BLOCKING regression (the `'sending'`-on-insert →
new claim rejected "Send now") + 1 HIGH (`reservation-confirm` burned the idempotency flag before send, so a
transient failure suppressed the confirmation) + 1 MEDIUM (stale-claim double-match) — all fixed; re-verify
(`wf_b1a642d6-444`) returned clean (0 problems). **Status: ✅ COMMITTED `0c009b2` + DEPLOYED LIVE
2026-06-02 05:03 UTC on `pmnyhbhtkcfoozkinieo`.**

**Shipped:** ✅ committed `security/sms-hardening-remainder` · ✅ 3 migrations
(`20260602120000`, `20260602120500`, `20260602121000`) run in the SQL editor (owner) · ✅ deployed `sms-webhook`,
`sms-send`, `reservation-confirm`, `reservation-remind` (all v14 ACTIVE; `sms-webhook` stays `verify_jwt=false`
per `config.toml`) · ✅ `RESERVATION_SMS_ENABLED` left unset → **reservations email-only LIVE**.
✅ **MERGED to `main`** (FF push `2f485ec..0c009b2` → origin/main) and the **frontend is LIVE on woahh.app** —
Lovable/Cloudflare rebuilt to bundle `index-CfTQPqSn.js`; the `AdminSmsNumbers-BTTnnZ6O.js` chunk contains the
E.164 marker, confirming the `0c009b2` frontend (incl. `SMSCampaigns` insert-`draft`) shipped. **woahh.app's
backend is `pmnyhbhtkcfoozkinieo`** (CSP `connect-src` + bundle), so the deployed functions/migrations are exactly
what woahh.app uses → the verified signup-OTP test already covers woahh.app.

**Remaining:** ⬜ **rotate exposed keys** (ClickSend, GitHub PATs, Supabase `sbp_`/`sb_secret_` incl. the deploy
token `sbp_c40f…` pasted 2026-06-02, Anthropic, **Resend `re_…`/`whsec_…`** — pasted in chat ~2026-05-30 during the off-Lovable migration, never recorded as rotated). ✅ live UI click-through signup-OTP test PASSED on
woahh.app (Playwright: login → Operations → "Change & verify" → "Send code" → code received → verified). ✅
`owner-verify` now surfaces the real ClickSend send result (500 unset / 502 on `{ok:false}` + rolls back the
stored OTP; previously returned `{ok:true}` even on failure — this hid the empty-balance failure during testing) —
committed `d13ff19`, deployed v14. Follow-up (still open): `email-send`/`EmailCampaigns` carry the same latent
"Send now" claim shape fixed here for SMS (out of scope).

---
_Audit: 32 agents, 14 confirmed / 13 rejected findings, 2026-05-31. Full transcript under the workflow run `wf_2c9262fe-f61`. Security sweep: `wf_2a109cbd-20e`. Remainder audit: `wf_95ed0ae7-41c`; review: `wf_29ca92ed-6a4`; re-verify: `wf_b1a642d6-444` (2026-06-02)._
