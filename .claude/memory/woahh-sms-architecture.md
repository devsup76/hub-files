---
name: woahh-sms-architecture
description: "Woahh per-merchant SMS architecture, audit findings + migration status; full detail in docs/SMS_ARCHITECTURE.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2f9c900a-e1aa-4390-8662-6686a868ddd0
---

Woahh SMS uses a **two-number model**: a shared Woahh number (env secret `WOAHH_SMS_NUMBER`,
used by owner-verify + reservation-remind) for platform OTP/transactional, and a
**per-merchant dedicated number** (`organizations.sms_number`) for marketing — so a
customer's `STOP` opts out of ONE merchant only (sms-webhook resolves the org by the
inbound `to` number). Mirrors the email split (shared `mail.woahh.app` + per-merchant
`campaigns.woahh.app`).

Built (code landed 2026-05-31, migration `20260531000000`): provider abstraction
`_shared/sms.ts` (ClickSend, swappable via `SMS_PROVIDER`), `sms-send` + `sms-webhook`,
RPCs `admin_assign_sms_number` (platform-admin assigns a number) + `set_sms_consent`
(customer per-merchant toggle → writes through to `customers.sms_opted_out`, the source of
truth). `sms-webhook` has a `SMS_WEBHOOK_SECRET` gate (currently fail-open).

Audit (2026-05-31, 32 agents): `organizations.sms_sender_id` is ORPHANED (only mis-read by
reservation-confirm → falls back to literal sender `"growerr"` = a real bug). Confirmed
fixes — CRITICAL: `sms-webhook:87` undeclared `deliveryStatusRaw` crashes failed-DLR handling.
HIGH: reservation-confirm "growerr" sender; STOP `startsWith` false-positives (END/QUIT/CANCEL
substrings); opt-out confirmation SMS not logged/counted; `AdminSmsNumbers.tsx` provisioning
page built but never routed in App.tsx (unreachable). MEDIUM: fail-open webhook auth; sms-send
TOCTOU on quota.

**Left = test + deploy** (migration off Lovable ~4.5/6 done): set ClickSend secrets +
`WOAHH_SMS_NUMBER` + `SMS_WEBHOOK_SECRET` on new Supabase (ref `pmnyhbhtkcfoozkinieo`),
repoint ClickSend webhook URLs, fix bug list, provision a real per-merchant number, run an
end-to-end send/opt-out test.

Progress 2026-05-31: critical+high audit fixes applied in `repo/` (deliveryStatusRaw crash,
growerr sender, STOP exact-match, AdminSmsNumbers route, opt-out confirmation logging) —
frontend builds clean, NOT yet committed. ClickSend creds verified working (smoke-test SUCCESS
to +61435140245 from shared system number +61448653472). NO dedicated number provisioned yet —
need to buy one for org.sms_number. Deploy staged in `scripts/sms-deploy.sh`. Committed: app repo branch
`feat/per-merchant-sms` (pushed to origin devsup76/business-growth-hub; main untouched per
"merge to main only when functional"); planning repo docs commit `8a8b67a` LOCAL only (push to
master blocked by safety rule, persists in workspace). Browser re-added (Playwright MCP connected).
PAT received + validated; secrets set on pmnyhbhtkcfoozkinieo (CLICKSEND_*, SMS_WEBHOOK_SECRET,
WOAHH_SMS_NUMBER=+61448653472 interim shared); deployed sms-send/sms-webhook/reservation-confirm/
reservation-remind/owner-verify. **END-TO-END SEND VERIFIED 2026-05-31**: Test Bistro (35cf67fb…)
sms_number=+61448653472, owner-JWT invoke of sms-send → {sent:4} (3 fake seed nums + owner mobile
+61435140245, all sent). Owner-auth note: sms-send verify_jwt=true → sb_secret rejected by gateway,
legacy service_role JWT ≠ function SUPABASE_SERVICE_ROLE_KEY → must use owner/user JWT.
STOP/opt-out VERIFIED end-to-end 2026-05-31: bought dedicated ClickSend number +61455725154
(REGISTRATION_NOT_REQUIRED), assigned to Test Bistro sms_number, created ClickSend inbound rule
2327822 (action=URL, match-all) → sms-webhook?secret=05f9c6fe…. Sent campaign → replied STOP →
sms_log chain: campaign sent, inbound STOP logged opted_out, confirmation sent; customers.sms_opted_out
flipped true. SEND + STOP both fully functional. ClickSend inbound configurable via API
(/v3/automations/sms/inbound). Cellcast ~½ ClickSend per-SMS cost — drop-in via SMS_PROVIDER flag at volume.
CI workflow `.github/workflows/supabase-deploy.yml` held back (PAT lacks `workflow` scope) so GitOps
auto-deploy NOT live; deploy is manual via `npx supabase`. Branch feat/per-merchant-sms NOT merged
to main yet (per "merge only when fully functional"). Persistent memory: Option 2 (devcontainer
postStartCommand runs .claude/link-memory.sh).

PRE-MERGE GATE CHECK (2026-05-31 night) — NEXT SESSION READ `docs/MORNING_HANDOFF.md` FIRST. Caught:
(1) `_shared/sms.ts` + migration `20260531000000` were UNTRACKED → now committed to `feat/per-merchant-sms`
(else main would break — every SMS fn imports _shared/sms.ts). (2) Migration wasn't applied to the live
DB at first; user applied it via SQL editor. (3) **SECURITY (critical):** `admin_assign_sms_number` AND
`generate_founding_codes` (in `20260529090000_founding_access_codes.sql`, ALREADY IN MAIN/PROD) both use a
NULL-unsafe admin gate `(auth.jwt()->>'email') <> 'admin'` (NULL<>x = NULL = falsy) + default PUBLIC execute
→ **anon-exploitable** (confirmed live: anon reaches the body; could mint permanent founding/zero-commission
codes or hijack a merchant's sms_number). FIX = `IS DISTINCT FROM` + `REVOKE EXECUTE FROM PUBLIC`. SMS-RPC
fix committed to branch (`55e52fc`); founding fix pending a tracked migration. **MERGE IS BLOCKED** until the
user runs the combined security SQL (in `docs/MORNING_HANDOFF.md`) on the live DB (+ likely the old Lovable
DB if still serving) and I re-test anon=blocked. Overnight security sweep `wf_2a109cbd-20e` DONE + triaged: only new
live-exploitable bug = `generate_founding_codes` (already in morning SQL). Rest is hardening backlog
(owner-verify OTP no lockout [top]; reservation-remind `.includes(SERVICE_KEY)` substring auth;
sms-webhook fail-open secret + PII log + NULL-`to` guard; defense-in-depth REVOKE-FROM-PUBLIC on
intentionally-public token RPCs). Confirmed non-issues: sms_log RLS (org-scoped policy exists),
sms-send exact bearer. hardening NOT applied (kept verified state). **MERGED TO MAIN 2026-06-01** (origin/main `c0d99b2`):
main had moved twice (parallel `feature/ai-features` + auth-route cleanup); resolved 1 conflict in
`api.ts` updateConsent (kept set_sms_consent RPC, used `customerSupabase` client), re-synced, built
green, pushed. Tracked founding-fix migration `20260601090000` added. Security SQL was run on the live
DB (anon now blocked, verified). Post-merge OPEN: hardening backlog (owner-verify OTP lockout etc. in
docs/MORNING_HANDOFF.md); rotate exposed keys; SMS *frontend* (AdminSmsNumbers page + consent toggle)
not yet exercised against the live site; confirm whether the main push triggered a Lovable/Cloudflare
frontend rebuild.

UPDATE 2026-06-02 — RECONCILE + REMAINDER HARDENING (docs/MORNING_HANDOFF.md was STALE; corrected):
git ground-truth showed `origin/main` had moved to `2f485ec` ("harden-critical-and-high" merge) which had
ALREADY landed most of the old backlog — owner-verify OTP **attempt-counter** (simpler than docs' timed-lockout,
migration `20260602101000`), sms-webhook **fail-closed**, STOP exact-word, deliveryStatusRaw crash fix. The old
"branch security/sms-hardening-backlog" claim was wrong (that branch = old main `cace9df`; the hardening commit
`397a289` was stranded on `feat/ingredient-availability`). A fresh audit (workflow `wf_95ed0ae7-41c`, 22 agents,
adversarial) against REAL origin/main found **8 still-open gaps**; all implemented on clean branch
**`security/sms-hardening-remainder`** off origin/main, worktree **`/workspaces/GrowthHub/repo-sms`**:
(1) reservation-remind exact service-role auth; (2) sms-webhook drop PII payload log; (3 HIGH) sms-send atomic
campaign claim — **required client change: `SMSCampaigns.tsx` inserts immediate sends as `'draft'` not `'sending'`**
so the claim serializes (email-send + EmailCampaigns have the SAME latent bug = out-of-scope follow-up);
(4) sms-send atomic `increment_sms_usage` RPC (migration `20260602120000`); (5) sms-send try/catch + revertDraft +
stale-`sending`>10min re-claim guarded by `.lt(updated_at,tenMinAgo)`; (6 HIGH, Spam Act) sms-webhook STOP
**E.164 normalization** `phoneVariants()` + zero-row-opt-out warning + empty from/to guard; (7) admin_assign_sms_number
E.164 validation (migration `20260602120500`) + AdminSmsNumbers client check; (8) reservation-confirm SMS
**idempotency** (migration `20260602121000` adds `reservations.confirmation_sms_sent_at`) kills SMS-bomb/credit-drain,
revert-on-failure keeps retry.
**OWNER DECISION 2026-06-02: reservations = EMAIL-ONLY** to save credits. Env flag **`RESERVATION_SMS_ENABLED`
default OFF** gates the SMS leg of reservation-confirm + reservation-remind (email legs untouched). SMS reserved for
**sign-up OTP (owner-verify) only**; marketing held (no per-merchant numbers provisioned). Re-enable later via the
flag, or upgrade to per-merchant `settings.reservations.sms_enabled` (SMS-reminders upsell).
Review `wf_29ca92ed-6a4` caught 1 BLOCKING (sending-on-insert) + 1 HIGH (reservation-confirm flag burned pre-send)
+ 1 MEDIUM (stale double-claim) → all fixed; re-verify `wf_b1a642d6-444` = clean (0 problems).
**SIGNUP OTP SMS VERIFIED LIVE 2026-06-02** on `pmnyhbhtkcfoozkinieo`: owner-verify send_otp → text received at +61435140245 (from WOAHH_SMS_NUMBER +61448653472) → verify_otp(228596) → `phone_verified=true`. Earlier "no text" was an EMPTY CLICKSEND BALANCE (user topped up) — and owner-verify returned `{ok:true}` throughout because send_otp swallows the ClickSend result (only console.warn on !r.ok, line 114; always returns ok). **FOLLOW-UP DONE 2026-06-02: owner-verify now surfaces the real send result** — unset WOAHH_SMS_NUMBER→500, provider {ok:false}→502, both roll back the stored OTP (hash/expiry=null) so retry isn't 60s-throttled; success unchanged; all 3 frontend callers already guard on the invoke error. Reviewed clean (wf_0ede2e2d-8db), committed `d13ff19` (rebased onto the AI-features main merge `f9a881d`), pushed to main, deployed owner-verify v14 on pmnyhbhtkcfoozkinieo. (Note: AI features v2 got merged to main in parallel this session = origin/main `d13ff19`.) Also: ClickSend opt-out is ACCOUNT-WIDE (a STOP suppresses that recipient across all your numbers incl. transactional OTP) — relevant if an owner ever STOPs. NOTE: 3 migrations were ALREADY DEPLOYED LIVE + the 4 edge fns deployed (v14) earlier this session.

**STATE: FULLY SHIPPED 2026-06-02.** Committed `0c009b2` → MERGED to main (FF push to origin/main). 3 migrations run (SQL editor) + 4 edge fns deployed v14 on `pmnyhbhtkcfoozkinieo`. Frontend rebuilt + LIVE on woahh.app (bundle `index-CfTQPqSn.js`; chunk `AdminSmsNumbers-BTTnnZ6O.js` has the E.164 marker → confirms 0c009b2 frontend shipped). **woahh.app backend = pmnyhbhtkcfoozkinieo** (verified via CSP + bundle), so the signup-OTP test already covers woahh.app. **UI click-through signup-OTP test PASSED on woahh.app 2026-06-02** via the recovered Playwright harness (/tmp/pwtest, chromium-1223): real login (Business→Owner→creds) → Operations → Business Details → "Change & verify" → entered +61435140245 → "Send code" → "Code sent" toast + dialog advanced to OTP entry → user received code → verify_otp → phone_verified=true. So signup SMS is proven through the live UI, not just the API. Only un-done: ROTATE KEYS (incl. `sbp_c40f…` used for deploy).
Owner chose: keep env flag (not per-merchant toggle) + commit-to-branch (no push). TO SHIP (all owner-side):
run 3 migrations on `pmnyhbhtkcfoozkinieo` (`20260602120000`/`120500`/`121000`) · deploy
sms-send/sms-webhook/reservation-confirm/reservation-remind + frontend rebuild · leave RESERVATION_SMS_ENABLED
unset (email-only) · merge→main. **Rotate exposed keys still pending.** Follow-up: email-send/EmailCampaigns
share the same "Send now" latent claim bug (out of scope here).

Full durable detail: `docs/SMS_ARCHITECTURE.md` (→ "2026-06-02 RECONCILE" section) + `docs/MORNING_HANDOFF.md`
(superseded banner). Migration: `docs/MIGRATION_OFF_LOVABLE.md`. See [[persistent-memory-setup]].
