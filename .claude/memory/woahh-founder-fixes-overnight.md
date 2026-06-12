---
name: woahh-founder-fixes-overnight
description: "Overnight 2026-06-12 build of 9 WOAHH_FIXES_TODO items on branch feat/founder-fixes-2026-06-12 (pushed, NOT merged); + security audit fixes + the founder deploy/run checklist"
metadata:
  node_type: memory
  type: project
  originSessionId: 4a5c9742-6065-4dcb-b9ed-037257b18a15
---

Overnight autonomous build, 2026-06-12 → branch **`feat/founder-fixes-2026-06-12`** (off `main` @ `869d676`, **pushed for Cloudflare preview, NOT merged** — founder tests tomorrow). App repo stays branch→founder-review. Coordinated AWAY from teammates: **Adithya** owns `feat/sidebar-search-collapse` (#4 sidebar + #26 Analytics-into-Manage); **yieldarche** owns `new-landing` (marketing).

**First: an implementation audit (Workflow, 11 agents) found 2 unticked items ALREADY done** → #18 free-trial banner (live `trial_ends_at` compute), [6.4] customer-PII RLS (migration `20260611020000` dropped "Staff view customers"). Don't rebuild these.

**Built + pushed (9 items):**
- **#28** stale-chunk auto-reload (`src/lib/chunkReload.ts` + `main.tsx` `vite:preloadError`/`unhandledrejection` + ErrorBoundary "Updating…" reload) — kills "Something went wrong" after deploys.
- **#19** pending-order urgency: ApprovalCard pulses a red ring in the final minute (amber in warning window) + `usePendingOrderAlarm` Web-Audio chime escalating 18s→8s→4s + owner mute. (Backend auto-decline auth was fixed earlier this session — `order-respond` v40.)
- **#22** "Added ✓" toast on BOTH storefronts (`RestaurantStorefront.addToCart` + `useLiveCart.add`) + qty stepper in the default customize dialog.
- **#23** KDS on-board fulfillment filter tabs (All/Dine-in/Pickup/Delivery) with live counts (`KitchenDisplay.tsx`) — was settings-only.
- **#27** staff "View receipt" modal (`ReceiptView.tsx`, same `buildReceiptModel()` as the email) in the `ReceiptActions` dropdown.
- **#24** Order History page (`OrderHistory.tsx`, route `order-history`, linked from Orders header): completed log (search + 7/30/90d) + owner Refunds ledger + staff-PIN-gated refunds.
- **#31** "Customer queries email" field in Operations (writes `contact_email`; the transactional senders already set Reply-To from it).
- **#30** one-email-on-confirmation: `order-notify` preparing/ready flipped `!== false`→`=== true` + NotificationSettings DEFAULTS off.
- **#21-NOW** per-org `settings.storefront.self_edit_locked` flag (default off) → `StorefrontLockNotice` read-only on Branding + StorefrontTemplates; retail-only templates filtered from the picker.

**Tested:** all 5 new dashboard pages smoke-pass via Playwright (cached chromium `~/.cache/ms-playwright/chromium-1223`, `playwright-core` in /tmp/pwsmoke, `vite preview` on :4173, demo mode) — render clean, zero console errors. KDS filter bar confirmed. `tsc` + `vite build` green throughout. (#22 storefront toast = build-verified; demo path renders `DemoRestaurantPreview`, not the real storefront.)

**Security audit (3-dim Workflow, every MED+ finding verified) — FIXED on the branch:**
- **AUTH-002 (CRITICAL):** #24's staff refund PIN was CLIENT-side only; `refund-order` didn't re-check it → a manager could call it directly + skip the PIN. Fixed: `refund-order` now verifies the 6-digit PIN SERVER-SIDE for non-owner callers (constant-time + 5-attempt lockout); client passes `pin`. Removed the redundant client `verify_pin` path + the `staff-pin-login` `verify_pin` action (net-zero, no deploy).
- **RLS-001 (HIGH):** `payment_refunds` SELECT was any-staff (`current_org_id()`) → owner-only.
- **RLS-002 (HIGH, PRE-EXISTING):** `staff_accounts` "Owners manage their staff" was `FOR ALL` via `current_org_id()`, exposing colleagues' `pin_hash` (= SHA-256(pin:user_id), 6-digit → offline-brute-forceable) → owner-only; staff keep "Staff view own row". Verified every other reader filters to own row; Staff mgmt page is owner-only (`Staff.tsx:142`). Both RLS in migration `20260612210000`.
- **NOT-A-BUG:** AUTH-001 cross-org PIN (user_id UNIQUE), order isolation, XSS. **Flagged LOW (not fixed):** #21 lock is client-only (merchant's OWN data — not a breach; server-side enforce = deferred); `contact_email` no server validation (Resend reply_to is injection-safe).

**⚠️ FOUNDER DEPLOY/RUN to activate staged backend** (frontend already on the preview): (1) run migration `20260612210000`; (2) deploy `refund-order` + `order-notify`. staff-pin-login unchanged. Then merge when happy.

See `docs/WOAHH_FIXES_TODO.md` (ticked + the deploy checklist). Founder wants a critical advisor ([[user-wants-critical-advisor]]); push/merge policy [[woahh-push-merge-policy]] (hub-files only). Related: [[woahh-order-respond-autodecline-auth]], [[woahh-wallets-apple-google-pay]].
