# Woahh — Fixes & Polish TODO

> Single source of truth for the open punch list.
> Closed items at the bottom for context.
> Last updated: 2026-05-29

---

## Architecture state (2026-05-28)

- **Live at `https://woahh.app`** — single origin, path-based split
- Merchant portal at `/business/*`; customer at apex
- Legacy `business.woahh.app` 301s pre-mount in `src/main.tsx`
- Email infrastructure verified at Resend (`mail.woahh.app`, `campaigns.woahh.app`)
- Test merchant: `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` (slug `test-bistro`)

See `CLAUDE.md` for full architecture details.

---

## 🔴 Open

### Security review — triaged 2026-05-29 (each item audited, not trusted blindly)

**✅ Fixed this session**
- **SMS webhook unauthenticated** (forge opt-outs / delivery receipts) → added `SMS_WEBHOOK_SECRET` shared-secret gate, commit `aac3316`. *Activation (non-dev): set `SMS_WEBHOOK_SECRET` in edge-function secrets, then append `?secret=<value>` to the Clicksend delivery + inbound webhook URLs.*
- **Webhook JWT exemption was implicit** → declared `email-webhook` / `courier-webhook` / `sms-webhook` as `verify_jwt=false` in `config.toml` with in-function auth documented, commit `69b96f4`.

**🟢 False positives — verified, no action**
- *Recovery/notification logs "no SELECT policy"* — RLS ENABLED + no policy = **deny-all by default** (service role bypasses for writes). Already locked; flag is cosmetic.
- *Realtime "subscribe to any org"* — `postgres_changes` enforces table RLS; org-scoped SELECT policies mean a client only receives changes for rows it can already read (its own org). Not exploitable.

**🟡 Demoted — real but ~zero current exposure**
- *Stripe payment-intent no auth* — function is **dormant** (nothing in client calls it; only `stripe-connect-onboard` is wired). Harden before a live checkout. Billing not integrated yet.
- *Product `cost_price_cents` readable by staff via `productApi.list` `select("*")`* — real over-the-wire leak, BUT only the **retail** inventory page sets it and retail signup is hidden (restaurants only) → no merchant has cost data. **Fix before enabling retail.** Plan: move `cost_price_cents` to an owner/manager-only `product_costs` table (only `ShopInventory.tsx` + `demo.ts` touch it).
- *Courier webhook skips HMAC when no secret configured* — low risk (forging needs a known `courier_delivery_id`). Make fail-closed when courier goes GA.

**✅ Fixed & VERIFIED (2026-05-29)**
- **Org PII readable by staff over the wire.** Solved without a table split: `get_member_org()` SECURITY DEFINER RPC returns the caller's org with owner PII (`owner_phone`, `owner_full_name`, `abn`, `business_address`, `stripe_account_id`, OTP hash) **nulled for non-owners**; the `"Staff view their org"` policy is dropped so staff have no direct read path. Client (`orgApi.getMine`) calls the RPC for staff with a direct-read fallback so deploy ordering can't break staff dashboards. Commit `745860b` (client + migration `20260529080000`).
  - **Verified via browser:** staff resolve their org through `get_member_org` (`[org-query] live (staff, masked)`), the dashboard still loads, and a raw REST `owner_phone` (and `select *`) query with the staff's own token returns **0 rows** — the `"Staff view their org"` policy is gone.

**🟢 Minor**
- *Waitlist entries: customer can't read their own.* Harmless. Add a tokened SELECT if booking confirmations should show status.

### -1.2 Founding-merchant sign-up code gating — ✅ VERIFIED LIVE (2026-05-29)

- **Status:** Client live (commits `9d67112` + merge `0b79557`). **Activate by running migration `20260529090000` SQL in the Lovable editor.** Until then sign-up fails closed (invite-only by default — the intended state).
- **What shipped:**
  - `founding_access_codes` table + admin-only RLS (`auth.jwt()->>'email' = pawitsingh23@gmail.com`).
  - `redeem_founding_code(code,email)` (anon, atomic consume) + `release_founding_code(code)` (un-consume on signUp failure) + `generate_founding_codes(n,note)` (admin batch).
  - Auth.tsx: required "Founding access code" field; redeems fail-closed before `signUp`, releases on error.
  - Admin page `/business/dashboard/admin/codes` (generate / copy / revoke) — double-gated by admin email + RLS.
- **Verify after SQL:** browser — sign-up blocked without a code; admin page generates codes; a generated code lets one sign-up through then is marked used.

### 1.2 Replace email-confirmation popup with dedicated page — 🟢 SHIPPED (commit `5ccb30b`)

- AdminForm now swaps to a dedicated "Check your email" screen after a confirmation-required sign-up (instead of a toast): shows the destination address, spam-folder hint, a Resend button with a 30s cooldown (`supabase.auth.resend`), and a "Back to sign in" link. Immediate-session signups still go straight to the dashboard.
- **Verify:** needs a valid founding code to reach the success branch (gate is live) — bundle with founding-flow verification.

### 2.1 Replace manual "Add Customer" with invite-to-consent flow — 🟢 SHIPPED (commit `f9ec2d5`, run migration `20260530090000`)

- `customer_invites` table + RPCs (`get_customer_invite`, `accept_customer_invite` → creates customer WITH consent, `decline_customer_invite`); `customer-invite-send` edge fn (owner JWT, emails one-tap consent link); public `/i/:token` accept page (CustomerInvite.tsx); Customers.tsx "Add" → "Invite customer" + pending-invites list (resend/cancel). Manual free-type add removed.
- **Verify after SQL:** invite a +alias email → email arrives → click → accept → customer appears with email_consent_method='invite_link'.
- **Status (was):** ⬜ Open — Spam-Act compliance requirement before scale
- **Current:** Customers.tsx form lets merchants type customer details directly. Band-aid for consent timestamps already applied (commit `ffb9f1b`).
- **Wanted:** Rename "Add Customer" → "Invite Customer". Merchant enters name + email → invite email sent → customer clicks `/i/:token` → consents → customer row created with `email_consent_at = now()`, `email_consent_method = 'invite_link'`.
- **Scope (~3 Lovable prompts):**
  - DB: `customer_invites` table (org_id, email, name?, token, expires_at, accepted_at, customer_id FK)
  - Dashboard: rename button, pending invites tab with resend / cancel
  - Public: `/i/:token` accept page + `customer-invite-send` and `customer-invite-accept` edge functions + transactional email template

### 2.3 Notify customer when their record is removed — 🟢 SHIPPED (commit `d5662c8`)

- `customer-removed-notify` edge fn (owner/manager JWT, verifies org membership before sending) emails the customer that their record was removed (loyalty/history gone, reply if a mistake); logs to email_log. Customers.tsx delete flow fires it fire-and-forget after a successful delete, only when the customer has an email. Hard delete retained (behind AlertDialog); soft-delete + 30-day grace = future enhancement.
- **Verify:** add a throwaway customer with a +alias email, delete it, confirm the notice email arrives.
- **Status (was):** ⬜ Open
- **Wanted:** When merchant deletes a customer, send email: "Your account at {Org Name} has been removed. Your loyalty points and order history with this merchant are no longer accessible. If you believe this was a mistake, reply to this email."
- **Open question:** Soft-delete (30-day grace + scheduled hard purge) vs hard-delete. Recommend soft-delete.

### 3.1 Hard separation of merchant vs customer auth identities

- **Status:** 🟡 Partially solved by routing — `/signin` is customer-only on apex; `/business/auth` is merchant-only. But same email can still be both a merchant `auth.users` row AND a customer `growthhub_profiles` row, and the routing doesn't force a chooser.
- **Wanted:** Hard separation in DB and in flow. Merchant doesn't auto-become a customer at their own shop.

### 3.2 Add "View as customer" button in merchant sidebar

- **Where:** `src/components/dashboard/AppSidebar.tsx`
- **Status:** 🟢 SHIPPED by Lovable (commit `89152ff`, "View-as-customer sidebar button"). Verify it points to the customer surface correctly when convenient.

### 3.3 "Back to site" on auth pages + log-out-to-leave for authed users — 🟢 SHIPPED (commit `4ae5718`, verifying)

- **Done:** Auth.tsx now shows a persistent "Back to site" → `/` on every state (was only on the picker); CustomerSignIn reworded to "Back to site"; DashboardLayout's authed-header "← Back to site" removed (merchants leave via sidebar Log out; "View Storefront" still previews the public page in a new tab). Account.tsx customer portal already compliant (Sign out in authed header; back-link only on signed-out card).
- **Two parts:**
  1. **"Back to site" button on the login/auth screens.** Both `/business/auth` (merchant) and `/signin` (customer) should show a clear "← Back to site" link/button that returns to the public landing (`/`) without authenticating. A visitor who clicked "Sign in" by mistake currently has no obvious escape back to the marketing site.
  2. **Authed users leave only by logging out.** Once a merchant or customer is signed in, the way out of their portal should be an explicit **Log out** — not a stray "back to site" affordance that drops them onto the public site while still authenticated (confusing session state). So: show "Back to site" only on the *unauthenticated* auth screens; for authed sessions, surface Log out instead.
- **Where:** `src/pages/Auth.tsx`, `src/pages/CustomerSignIn.tsx` (auth screens); merchant header/sidebar (`AppSidebar.tsx`) + customer `Account.tsx` shell for the authed log-out path.
- **Note:** keep merchant vs customer log-out distinct — relates to [[3.1 hard separation of auth identities]].

### Tables: managed dining zones — 🟢 SHIPPED (pending SQL)

- **Was:** a table's zone was free text retyped on every add/edit (typos, case drift split groups).
- **Now:** zones are a per-org managed list (`table_zones`). Zones manager on the Tables tab (add chip / remove); single-add, bulk-add, and edit forms use a Zone **dropdown** sourced from the list ("No zone" = null). Existing typed zones backfilled. Tables stay restaurant-only. Commit `306de52` (client + migration `20260529120000`).
- **Activation:** run migration `20260529120000` SQL in the Lovable editor; then verify via browser (create zone → add table via dropdown → groups correctly).

### 4.1 AI menu import — scan a PDF/image to bulk-create the menu at onboarding

- **Status:** ⬜ Open — onboarding accelerator (new feature, not a fix)
- **Why:** New merchants drop off when they have to hand-key every product. Let them upload an existing menu (PDF, photo of a printed menu, or screenshot) and have an AI agent parse it into draft products they can review and accept in one pass.
- **Wanted flow:**
  1. During onboarding (and as an "Import menu" button on the Menu page), merchant uploads a PDF or image.
  2. Edge function sends the file to a vision-capable model (Claude with the latest Opus/Sonnet — vision + structured output) with a prompt to extract `{ category, name, description, price, options/extras }` per item.
  3. Model returns structured JSON → mapped to draft `products` + `menu_categories` rows.
  4. **Review-before-commit screen:** merchant sees the parsed items in an editable table (fix prices/names, drop junk, assign categories) → confirm → bulk insert. Never auto-publish unreviewed AI output.
- **Build approach:** integrate directly in the repo (local edits + push, not Lovable prompts) — no 5000-char splitting needed. Lovable CI picks up the commits.
- **Scope:**
  - Edge function `menu-import` (Deno): accepts uploaded file (Supabase Storage), calls the model, returns normalised JSON. API key in edge-function secrets.
  - Storage bucket for uploaded source menus (private, owner-only RLS).
  - Frontend: upload dropzone in onboarding + Menu page; parsing/progress state; editable review table; bulk-create on confirm (reuse existing product/category create paths).
- **Considerations:** price parsing (currency symbols, cents), multi-size items → extras/options, categories inferred from headings, dietary tags from menu icons. Token/cost guardrail per import. PDF → may need page-image conversion before vision.
- **Note:** ties into merchant onboarding & compliance flow; surface alongside `OnboardingChecklist`.

### 4.2 In-person checkout: add/invite customer to grant loyalty perks at point of service

- **Status:** ⬜ Open — new feature
- **Why:** When a staff member serves a walk-in / dine-in / counter customer, there's currently no smooth way to attach that customer to the order so they earn loyalty points and perks. Capture them at the moment of checkout — consent-compliant.
- **Wanted flow (at in-person checkout / when staff completes an order):**
  1. On the order/checkout screen, staff can **attach a customer** by any of three identifiers: a **generated loyalty code** (the customer's rotating in-store code from their Account), their **phone number**, or their **email**.
     - *Generated code* → looks up the already-consented member instantly (no invite needed) and attaches directly.
     - *Phone / email* → search existing customer; if found and consented, attach directly.
  2. If new (or not yet consented), **send an invite** rather than silently creating a marketing record — customer gets an SMS/email link to confirm + opt in, then loyalty points for that order are credited on accept. Aligns with [[2.1 invite-to-consent customer flow]] (Spam Act).
  3. If the customer is already a consented member, attach directly and credit points immediately.
  4. On order completion, loyalty points/perks apply to the attached customer (in-person orders → earn rule per `loyalty_config`).
- **Surfaces:** in-person checkout / walk-in order dialog (Orders.tsx + KDS walk-in flow), tie to the in-store loyalty code path already built (the code lookup reuses `loyalty_code_sessions` + validate RPC). Staff roles (manager/service) can attach; respect consent before any marketing send.
- **Build approach:** integrate directly in the repo (local edits + push). Reuse `customer_invites` (from 2.1) for the invite path so consent timestamps are consistent; reuse the in-store loyalty code validate RPC for the code path.
- **Considerations:** don't create a marketing-eligible row without consent; loyalty earn can be credited to a pending/invited customer and finalised on accept; idempotency so re-completing an order doesn't double-credit; phone/email/code dedupe against existing customers + `growthhub_profiles`.

### 4.3 Receipts — print + email (must-have)

- **Status:** ⬜ Open — **must-have** feature
- **Why:** Merchants need to give customers a receipt. Two paths, both required:
  1. **Email receipt** — already have the email infra; send a receipt for an order to the customer's email.
  2. **Physical receipt** — a customer can ask for a paper receipt even if they haven't opted in (no consent needed for a one-off transaction record), and many restaurants will want to print every receipt regardless.
- **Open problem — how merchants print from an iPad / tablet / computer:** we need a printing path that works off the devices merchants actually use. Options to evaluate:
  - **Browser print (zero hardware lock-in):** generate a print-optimised receipt (HTML/CSS `@media print`, 58mm/80mm thermal width) and trigger the device's native print dialog → works to any AirPrint / system printer from iPad/tablet/computer. Lowest barrier, no SDK.
  - **Thermal receipt printers:** common in hospitality (Epson TM-series, Star). Evaluate cloud-print (Epson Connect / Star CloudPRNT — server pushes receipt, printer polls) vs. local (Bluetooth/USB/LAN via WebUSB/Web Bluetooth — limited on iPad Safari).
  - **PDF fallback:** generate a downloadable/printable PDF receipt for any device.
- **Wanted:**
  - A receipt record/template per order (org branding, line items, taxes/fees, totals, GST/ABN once registered, donation line if applicable, order #/timestamp).
  - On any order (online + in-person), buttons: **Email receipt**, **Print receipt**, **Download PDF**.
  - In-person checkout: prompt "Receipt? — Email / Print / None" at completion.
- **Build approach:** integrate directly in the repo (local edits + push). Start with browser-print + PDF (no hardware dependency, works everywhere), then layer thermal/cloud-print for merchants who want auto-print every ticket.
- **Considerations:** thermal width formatting (58mm/80mm), legal/tax fields (GST once ABN-registered — see ABN guide), no marketing consent required for a transactional receipt, reprint/duplicate handling, KDS vs front-of-house printer routing if we go hardware.

### 4.4 Installable app on phone/tablet (PWA — no app store required)

- **Status:** ⬜ Open — revisit (we discussed this before; planning to deploy)
- **Why:** Merchants want woahh on a phone/tablet like a native app, without going through the App Store / Play Store review process. A **PWA (installable web app)** gives an icon on the home screen, full-screen launch, and offline-ish behaviour — installed straight from `woahh.app` via "Add to Home Screen".
- **What we likely already have:** a service worker exists (`public/sw.js`, built for Web Push order notifications). PWA install needs that plus a web app manifest. CLAUDE.md lists "custom domain/PWA" as a growth-tier perk — confirm whether that gating still applies or if install should be available to all.
- **Wanted:**
  - `manifest.webmanifest` (name, short_name, icons 192/512 + maskable, theme/background color, `display: standalone`, `start_url`, scope) linked from `index.html`.
  - Decide **which surface installs**: the merchant dashboard (`/business/*`) as a "run the shop" app, the customer surface (storefront/account) as an "order again" app, or both — possibly two manifests / scopes.
  - In-app **Install prompt** (capture `beforeinstallprompt` on Android/desktop; show iOS "Add to Home Screen" instructions since Safari has no prompt API).
  - Offline shell / sensible offline fallback so a cold launch without network isn't a blank page.
- **Build approach:** integrate directly in the repo (local edits + push). PWA is the no-store route; if we ever want a true store listing later, wrap the PWA (e.g. Capacitor / TWA) — note for the future, not now.
- **Considerations:** iOS PWA limits (no install prompt API, push works on iOS 16.4+ for installed PWAs only, storage eviction); icon/splash assets; make sure the single-origin routing + legacy redirect don't break `start_url`/scope; KDS as an installed tablet app is a strong use case (kitchen runs it full-screen).
- **TODO before building:** find the earlier discussion notes on this and reconcile (we had a plan) — check older docs / chat history.

### 5.1 Storefront mobile checkout — floating cart bar → popup (no scroll)

- **Status:** ⬜ Open — plan ready, not started. Frontend-only.
- **Why:** On the restaurant storefront the cart lives in an `<aside>` inside `lg:grid-cols-[1fr_380px]`, so below `lg` (every phone) it stacks **under the entire menu**. A customer adds an item then has to scroll past every category to reach the cart + "Go to Checkout" button. Retail (`RetailStorefront.tsx`) already avoids this with a `Dialog` checkout from a sticky header button — **this is restaurant-only.**
- **Plan:**
  1. **Sticky bottom cart bar (mobile only):** fixed bar pinned to the viewport bottom, shown only below `lg` and only when `cart.length > 0`; shows `itemCount` + live `total` + a "View order" button. Tapping opens the cart popup.
  2. **Cart in a popup (`Sheet`, slide-up):** move the existing cart body (lines list, fulfillment selector, promo code, totals, "Go to Checkout") into a bottom `Sheet` for mobile. Its "Go to Checkout" calls the existing `startCheckout` → the upsell → checkout → auth dialog chain is unchanged.
  3. **Desktop unchanged:** at `lg+` the sticky sidebar `<aside>` stays as-is; bar + sheet are `lg:hidden`.
- **Reuses:** `cart`, `itemCount`, `total`, `startCheckout`, the existing checkout `Dialog` chain, and `Sheet` from `ui/`. Likely extract the cart JSX into a small local component so it isn't duplicated between sidebar and sheet. The fly-to-cart anchor (`cartAnchorRef`) becomes the bottom bar on mobile.
- **Scope:** one file — `repo/src/pages/storefront/RestaurantStorefront.tsx`. No DB / edge functions / new deps. Implement directly in `repo/` on a branch.

### Marketplace visibility & off-marketplace reminders — ✅ COMPLETE (all 4 phases, 2026-05-29/30)

Goal: new restaurants auto-listed; merchant can temporarily hide (still takes orders); escalating reminder emails while off-marketplace; whole feature gated to marketplace tier+ (or active free trial).

- **Phase 1 — foundation ✅ VERIFIED (2026-05-29, migration `20260529130000_marketplace_visibility_foundation`).** New restaurants `marketplace_visible=true` by default; public `marketplace_organizations` view gated by **readiness** (>=1 available product), **tier** (marketplace/growth/enterprise OR active free_trial), and **not paused**; tracking cols (`marketplace_hidden_at`, `marketplace_reminder_stage`, `marketplace_reminders_opted_out`, `marketplace_paused_until`); BEFORE-update trigger maintains hidden_at + resets reminders. Verified: test-bistro now shows on `/eat` + profile loads; "Open now" badge already present.
- **Phase 2 — merchant controls ✅ SHIPPED (commit `dbd3808`).** Operations card: clearer "Listed on Marketplace" toggle (hidden ≠ closed — storefront/QR still take orders), completeness meter + "Preview listing", vacation "pause until" date (auto-relist, suppresses reminders), reminder-email opt-out.
- **Phase 3 — reminder emails ✅ SHIPPED (commit `c1a6acd`, run migration `20260529140000`).** `marketplace-reminders` edge fn (escalating copy 1d/3d/7d/14d/30d, opt-out note, email_log audit) + `dispatch_marketplace_reminders()` daily 09:00 UTC cron; targets owner-hidden restaurants, skips opted-out + paused.
- **Phase 4 — open/closed badge ✅ ALREADY DONE.** `isOpenNow()` drives Open/Closed on both `/eat` list cards (Marketplace.tsx) and the profile (MarketplaceProfile.tsx). No work needed.

### Reviews edge cases

- **Latent:** Reviews `INSERT` requires matching order via `customer_id_for_user(org)`. Reviews `SELECT` / `UPDATE` policies should be audited for consistency (e.g., can a customer edit their own review post-submission? can a merchant flag spam?). Not blocking; flag for future audit.

---

## ✅ Closed (recent — 2026-05-29)

| # | Item | How resolved |
|---|---|---|
| Phantom-org bug | Staff users were owners of empty phantom orgs (trigger fired on staff-manage's createUser call), breaking `.maybeSingle()` in `orgApi.getMine` | Pushed `b51b045`. Trigger now skips `kind=staff`; existing phantoms cleaned up; new `my_org_id()` RPC + client uses it for deterministic resolution. |
| Products INSERT RLS failure | `current_org_id()` returning NULL in RLS contexts because of a fragile `auth.users` JOIN | Pushed `90e5f2f`. Reverted `current_org_id()` to simple priority-ordered version; rewrote products policy to use direct EXISTS subqueries instead of `current_org_id()`. |
| Realtime menu sync — service + manager weren't seeing owner's adds | (a) ShiftAvailabilityPanel was UPDATE-only filter; (b) hook subscribed under anon JWT pre-PIN-login; (c) missing queryKey invalidation for shift-availability-products | Pushed `e66aa2c`. Auth-aware re-subscription, all 3 queryKeys invalidated, ShiftAvailabilityPanel expanded to `event:"*"`, 30s polling fallback added. |
| **Staff saw empty menu (VERIFIED FIXED 2026-05-29)** | Staff logins get a junk phantom org from `handle_new_user_org`; `orgApi.getMine` was picking that empty phantom over the real staff org → staff queried an org with no products | Pushed `9b175da`. `getMine` branches on `user_metadata.kind`: staff resolve via their `staff_accounts` row (never a phantom owned org); owners use the owned-org path. **User confirmed working end-to-end** — owner adds → service sees it live. |
| Owner add showed success popup but no item | `getMine` depended on `my_org_id()` RPC that wasn't deployed → undefined orgId; fallback RPC inserted server-side (success toast) but list queried undefined org | Pushed `903da2a`. `getMine` resolves org with no RPC dependency. |
| Diagnostic logging | Hard to debug staff session without DB access | Pushed `ea759c7` + `5df23a7`. Console logs at `[session]`, `[org-query]`, `[products-query]`, `[products-create]` with explicit demo-mode warning. |
| Defensive staff view policies | Belt-and-suspenders re-assertion in case any policy got dropped | Pushed `bd50ba9`. Idempotent re-creation of staff SELECT policies on products, menu_categories, combos, organizations. |

---

## ✅ Closed (earlier — 2026-05-28)

| # | Item | How resolved |
|---|---|---|
| -1.1 | Publish Lovable app to `woahh.app` | ✅ Done. Migrated to single origin after subdomain split caused cross-origin session issues. |
| 0.1 | Campaign send error | ✅ Pushed `0573c29` + `e17483f`. Lovable shipped stale-claim self-heal; we added try/catch revert + structured logging. |
| 0.2 | Customers form null consent timestamps | ✅ Pushed `0573c29`. `*_consent_at` now derived from `marketing_opt_in` toggle at insert time. Real fix (2.1) still pending. |
| 1.1 | Hide retail at sign-up | ✅ Pushed `0573c29`. Picker hidden, default to restaurant. |
| 1.3 | Don't re-prompt business type after email verification | ✅ Pushed `0573c29`. Org metadata fields flow through `auth.users.user_metadata`; `BusinessTypeGate` auto-hydrates the org row from metadata when the legacy gate would fire. |
| 2.2 | Double-confirm customer delete | ✅ Pushed `0573c29`. AlertDialog with destructive action. |
| Routing pivot | Subdomain split → single origin with `/business/*` | ✅ Lovable migration commit `d903a87`. Pre-mount redirect in `src/main.tsx` handles legacy subdomain visitors. |
| Multi-tenant lockdown | Orders, reservations, organizations, promotions, courier_credentials, reviews, signup_codes, growthhub_profiles, product-images storage | ✅ Migrations `20260528115310`, `131845`, `131923`, `134549`. Replaced public-SELECT policies with SECURITY DEFINER RPCs and safe views (`marketplace_organizations`, `active_promotions`). |
| `current_org_id()` determinism | Stable resolution for users in multiple orgs | ✅ Migration `134549`. `ORDER BY priority, tiebreak`. |
| Customer reset password flow | Customers can reset on apex, session sticks | ✅ Pushed `1b21b4a`. `/reset-password` moved to customer paths. |
| Storefront sign-in CTAs | Header + footer "Sign in" point at merchant `/business/auth` | ✅ Pushed `1b21b4a`. Internal consistency with "Start free" merchant signup. |
| Email infrastructure | mail.woahh.app + campaigns.woahh.app DKIM/SPF/DMARC | ✅ Resend domains verified, all 6 hardening prompts (A–F) shipped earlier in session. |
| Customer sign-in split | `/signin` on apex + Customer persona hidden from `/business/auth` | ✅ Pushed via Lovable in `c90f5d7` and downstream. Reuses `CustomerForm` (named export from Auth.tsx). |
| Staff PIN 3-step verify | UX win, no security regression | ✅ Lovable commit `66f7e95`. |
| Products realtime | Owner changes propagate to KDS + storefront without refresh | ✅ Migration `152014` + `useProductsRealtime` hook + Lovable commit `e1c85a1`. |
| Side-effects-during-render in redirects | useEffect wrapping | ✅ Pushed `e17483f` (later superseded by single-origin pivot which removed the redirect components). |
| Hash fragment preservation | Deep-link `#anchor` survives host redirect | ✅ Pushed `e17483f`. |
| Path-injection (`//`) normalization | Defensive `normalizePath` in `apexUrl`/`businessUrl` | ✅ Pushed `e17483f`. |
| `/join` mis-categorization | Customer sign-up correctly on apex | ✅ Pushed `e17483f`. |

---

## Test-merchant cleanup reminder

When you're done with the seeded test merchant:

```sql
DELETE FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111';
```

The org and related rows cascade via `owner_id` FK.
