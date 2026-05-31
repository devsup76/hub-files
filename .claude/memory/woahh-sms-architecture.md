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
sms-send exact bearer. NOT applied overnight (kept verified state intact). Branch `feat/per-merchant-sms`
complete + pushed; NOT merged to main. Still TODO: create tracked migration for the founding fix.

Full durable detail: `docs/SMS_ARCHITECTURE.md` + `docs/MORNING_HANDOFF.md`. Migration:
`docs/MIGRATION_OFF_LOVABLE.md`. See [[persistent-memory-setup]].
