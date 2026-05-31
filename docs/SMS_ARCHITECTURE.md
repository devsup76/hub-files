# Woahh SMS Architecture & Migration Status

> **Durable record** — kept in the repo so it survives container/memory resets.
> Last updated: 2026-05-31 (audit-confirmed). Owner: pawit. Companion to `docs/MIGRATION_OFF_LOVABLE.md`.
> Status legend: ✅ built · 🟡 partial · ⬜ missing · ♻️ orphaned (defined but unused)

## TL;DR — where we are

Migrating Woahh off Lovable onto a fresh Supabase project (ref `pmnyhbhtkcfoozkinieo`);
in the same push we built **per-merchant SMS**. The code is written and audited; what's
left is **provisioning numbers + secrets, fixing a short bug list, then end-to-end test +
deploy**. Migration ~4.5 of 6 steps done (DB, functions, email, web push, build verified).
SMS code landed today (migration `20260531000000`).

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
- **STOP/opt-out NOT yet verifiable** — shared numbers don't reliably route inbound replies, and the ClickSend inbound/DLR webhook URL (`…/functions/v1/sms-webhook?secret=…`) isn't configured. Needs a **dedicated number** + webhook config. Outbound + the `sms-webhook` fixes are deployed and ready.

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

---
_Audit: 32 agents, 14 confirmed / 13 rejected findings, 2026-05-31. Full transcript under the workflow run `wf_2c9262fe-f61`._
