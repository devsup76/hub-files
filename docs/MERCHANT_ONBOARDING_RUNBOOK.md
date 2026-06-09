# Merchant Onboarding & Go-Live RUNBOOK

> **From zero to taking online orders + payments on `name.woahh.app`.**
> The complete, end-to-end, dependency-ordered runbook for onboarding the **first 1-5 merchants** (restaurants) onto woahh.
> Last updated: 2026-06-09. Scope: woahh storefront-platform go-live.
> Source of truth: this repo + branch `feat/storefront-platform` (verified at HEAD `7228919`, worktree `repo-audit`).
>
> **WHO legend** — every step is labelled:
> - **MERCHANT** — self-serve, in the merchant dashboard (route given).
> - **FOUNDER** — human-only console work (Supabase / Stripe / Cloudflare).
> - **CLAUDE** — run SQL / publish config / verify on the operator's behalf.

---

## QUICK CHECKLIST (skim this)

| # | Phase | Owner | One line |
|---|---|---|---|
| **0** | Prerequisites / infra (do ONCE) | FOUNDER + CLAUDE | Apply 3 storefront migrations + C1 + guest-consent + anon-guard migs; merge `feat/storefront-platform`→`main`; set edge secrets (Anthropic/Stripe/ClickSend/Resend); Supabase Auth allow-list; mint a founding code. |
| **1** | Create merchant account + compliance | MERCHANT (+ FOUNDER code) | Merchant signs up at `/business/auth` with the founding code → org + 60-day `free_trial` auto-created → completes the 5-step onboarding checklist (email, phone OTP, ABN, address). |
| **2** | Build the menu (manual + AI import) | MERCHANT | `/business/dashboard/menu` — add items/categories/combos by hand, or "Import menu with AI" from a photo/PDF. |
| **3** | Branding | MERCHANT | `/business/dashboard/branding` — logo, primary/secondary HSL colors, font pair. |
| **4** | Pick + publish storefront template | MERCHANT (gaps: migs live) | `/business/dashboard/storefront` — pick a curated template, tweak hero/colors, **Publish** (writes `storefront_config`). |
| **5** | Operations / hours / fulfillment + notifications | MERCHANT | `/business/dashboard/operations` (hours, fulfillment, confirmation) + `/business/dashboard/notifications` (marketplace tier+). |
| **6** | Connect Stripe (Connect Express) | MERCHANT | `/business/dashboard/operations` → "Stripe payouts" card → Stripe-hosted onboarding → "Payment-ready". |
| **7** | `name.woahh.app` go-live | FOUNDER + CLAUDE | Cloudflare CNAME + Pages custom domain + guarded `subdomain_slug` UPDATE. **Interim, zero-infra option: `woahh.app/shop/<slug>` works today.** |
| **8** | Flip on real card capture | FOUNDER + CLAUDE | Verify C1 applied → SQL `settings.payments.online_card_enabled = true` (no UI). **Hard gate — do not skip C1.** |
| **9** | End-to-end go-live verification | CLAUDE + MERCHANT | Place a test order + payment → owner confirms → appears in Kitchen/KDS. |

**Dependency order is real:** 0 → 1 → (2,3,4,5 can interleave) → 6 → 7 → 8 → 9. You cannot flip card capture (8) before C1 is applied (0). You cannot serve `name.woahh.app` (7) before the storefront migrations are live + branch is merged (0).

**Verified-live status (confirmed by direct live testing this session):** the **guest-consent (#2)**, **C1 server-side order-total (#3)**, and **anon-trigger-guard (#4)** migrations are **applied + verified live** (guest sign-in → consent → real order → C1 rejects a tampered $0.01 order, all confirmed against the live DB on 2026-06-09). The three *storefront-platform* migrations (`storefront_config`, `guard_subdomain_slug`, `template_variants`) are **ALSO applied + verified live** (founder ran them 2026-06-08; a published `kerb`/`maison` template renders end-to-end on `woahh.app/shop/test-bistro`). So Phase 0a's migrations are **DONE** — only `types.ts` regen + the branch merge remain pending in Phase 0.

---

## PHASE 0 — Prerequisites / infra (do ONCE, before any merchant)

All FOUNDER / CLAUDE. None of this is a merchant step.

### 0a. Apply the platform migrations to the LIVE DB (Supabase project `pmnyhbhtkcfoozkinieo`)

| Migration | Purpose | Owner | Status |
|---|---|---|---|
| `20260603010000_storefront_config.sql` | `storefront_config` table + `get_public_storefront_config(p_slug)` anon RPC | FOUNDER ran / CLAUDE verified | ✅ **Applied + verified live** (RPC 200; config publishes) |
| `20260603020000_guard_subdomain_slug.sql` | `guard_subdomain_slug` trigger — rejects reserved slugs (`mail`/`admin`/`www`/`eat`/`shop`…) on UPDATE, auto-suffixes on INSERT | FOUNDER / CLAUDE | ✅ **Applied + verified live** |
| `20260607010000_storefront_template_variants.sql` | widens the `template` CHECK so the 10 curated presets (`editorial`/`boutique`/`bold`/`kerb`/`daily`/`maison`/`rush`…) can be published | FOUNDER / CLAUDE | ✅ **Applied** (kerb/maison published + rendered live) |
| C1 — `20260608020000_c1_server_side_order_total.sql` | server-side order-total floor; rejects under-totaled orders | FOUNDER / CLAUDE | ✅ **Verified live** (per memory) — confirm before Phase 8 |
| Guest-consent (#2) | guest-checkout consent capture | already applied | ✅ Verified live |
| Anon-trigger-guard (#4) — `20260609010000_guard_anon_user_triggers.sql` | `handle_new_user_org` short-circuits anon/guest/staff/customer (no phantom orgs) | already applied | ✅ Verified live |

Run order for the three storefront migrations: `010000` → `020000` → `070...10000`. Do **not** set any `subdomain_slug` (Phase 7) before `20260603020000` is live.

### 0b. Regenerate Supabase types — FOUNDER / CLAUDE
After the storefront migrations apply, regen + commit `src/integrations/supabase/types.ts`:
```
npx supabase gen types typescript --project-id pmnyhbhtkcfoozkinieo > src/integrations/supabase/types.ts
```
(`storefrontConfig.ts` still casts `as any` until this is regenerated.)

### 0c. Merge `feat/storefront-platform` → `main` — FOUNDER
Cloudflare rebuilds prod from `main`. A branch push only builds a *preview*, and **the custom subdomain cannot be tested on a preview**. Verify apex (`woahh.app` marketing / `/eat` / `/business/*`) is byte-for-byte unchanged after deploy.

### 0d. Edge-function secrets — FOUNDER (one-time)
| Secret | Needed by | If missing |
|---|---|---|
| `ANTHROPIC_API_KEY` | `ai-menu-copilot` (Phase 2 AI import) | AI import fails; manual menu still works |
| `STRIPE_SECRET_KEY` (`sk_live`) | `stripe-connect-onboard`, `stripe-payment-intent`, `order-respond` | No Stripe |
| `STRIPE_WEBHOOK_SECRET` | `stripe-webhook` | Webhook fail-closes; readiness still flips via eager-refresh |
| `CLICKSEND_USERNAME` / `CLICKSEND_API_KEY` + `WOAHH_SMS_NUMBER` | `owner-verify` (Phase 1 phone OTP) | Phone OTP returns "SMS sending isn't configured" |
| `RESEND_API_KEY` | order/decline emails (`order-respond`, `order-notify`) | No customer email |
| `APP_URL` | unsubscribe / redirect links | Broken links |

Also configure the **Stripe Connect webhook** to subscribe to `payment_intent.*` + `account.updated`.

### 0e. Supabase Auth redirect allow-list — FOUNDER
Supabase → Auth → URL Configuration:
- **Pilot (per-host):** add each `https://<name>.woahh.app/**` you go live with.
- **Scale:** add `https://*.woahh.app/**` once.

(Merchant control plane `/business/*` and `/signin` are forced back to apex by the `ApexOnly` guard, so the cross-origin-session concern does not apply to customer subdomains.)

### 0f. Mint a founding access code — FOUNDER
Public merchant signup is **invite-only / fail-closed** — the signup form hard-requires a single-use `WOAHH-XXXXXX` code.
- Sign in as `pawitsingh23@gmail.com` (admin email is hard-coded in 3 places) and navigate **directly by URL** to `/business/dashboard/admin/codes` (route `App.tsx:200`). **There is no sidebar link** — URL-only, admin-gated.
- Click **Generate** → `generate_founding_codes(p_count, p_note)` RPC → rows in `founding_access_codes`. Copy a code.
- ⚠️ **MANUAL:** delivery of the code to the merchant is out-of-band (no email is sent).

---

## PHASE 1 — Create the merchant account + compliance onboarding

### 1a. Merchant signs up — MERCHANT
**Route:** `/business/auth?as=admin` (or `?mode=signup`). Component: `AdminForm` (`Auth.tsx`). Validated by `adminSignupSchema`.

Fields collected: business name, owner full legal name, business structure (sole_trader/company/partnership/trust/other), **business type = `restaurant` (hidden, hard-defaulted during founding phase)**, username (live availability check), email, business phone, password (12+ strength meter), **founding access code (required)**, optional promo code, ToS+Privacy checkbox, Spam Act 2003 ack checkbox. The submit button is disabled without the founding code.

### 1b. What happens on submit (automated server flow)
1. Validate + reject taken username.
2. **Consume the founding code FIRST, fail-closed** — `redeem_founding_code(code, email)`; aborts before any account is created if invalid/used.
3. `supabase.auth.signUp` with all org fields stuffed into `user_metadata` (so the org hydrates even when email confirmation defers the session).
4. If signUp errors → `release_founding_code` (so the code isn't wasted).
5. **Org auto-created by DB trigger** `handle_new_user_org()` — `owner_id`, `name`, a unique de-duped `subdomain_slug` from the name, `trial_ends_at = now()+60d`, `marketplace_visible=true`. Short-circuits for anon/guest/staff/customer (no phantom orgs — anon-guard #4).
6. Client back-fills compliance columns **if a session exists** (no email-confirm); otherwise `BusinessTypeGate` (mounted in `DashboardLayout`) writes them from `user_metadata` on first dashboard load.
7. Optional promo code → `redeem_signup_code`.
8. Session present → toast + navigate to `/business/dashboard`; else "Check your email" screen with 30s-cooldown resend.

**Tier:** `organizations.tier` DB-defaults to **`free_trial`** (full marketplace-tier access for 60 days). "Founding" is **not a tier or a flag** — at signup it means only that a founding code was consumed; the 0%-commission / free-sub terms are operational + Stripe-side (set FOUNDER-side via SQL, see Phase 8). There is **no `is_founding` column written at signup.**

### 1c. The 5-step onboarding checklist — MERCHANT (in dashboard)
On `/business/dashboard` overview, `OnboardingChecklist` (hidden once `onboarding_completed_at` is set):

| Step | What | How |
|---|---|---|
| 1. Verify email | `user.email_confirmed_at` set | MERCHANT clicks the inbox confirmation link |
| 2. Verify business phone (OTP) | `phone_verified=true` | "Verify now" → `PhoneVerifyDialog` → `owner-verify` edge fn `send_otp`/`verify_otp` (6-digit, SHA-256-hashed, 10-min expiry, 5-attempt cap, sent via ClickSend `WOAHH_SMS_NUMBER`) |
| 3. Set business type | `org.business_type` set | Already `restaurant` from signup → **auto-ticks**; no control here (OnboardingChecklist copy mentioning "account settings" has no matching UI) |
| 4. Verify ABN | `abn_verified=true` | Inline 11-digit input → `owner-verify` `check_abn` (mod-89 checksum + uniqueness) |
| 5. Add business address | `business_address` jsonb | `AddressDialog` (street/suburb/state/postcode/country) |

**Honest gate note:** the checklist is **NOT a hard gate to selling** — `onboarding_completed_at` only dismisses the card. What phone/ABN verification *does* gate elsewhere is **SMS campaigns + sponsored listings (Promote)**. Phone OTP can silently fail if `WOAHH_SMS_NUMBER`/ClickSend aren't set (Phase 0d).

---

## PHASE 2 — Build the menu (manual + AI import)

All MERCHANT. **Route:** `/business/dashboard/menu` (sidebar "Menu"; renders `Menu.tsx` for restaurants). Three tabs: **Items / Categories / Combos.**

### 2a. Manual build — MERCHANT
- **Add menu item:** "Add menu item" dialog — title (req), description, **price** (stored as integer cents), category, sale price + window, image **URL only** (no upload widget), "Allow customization" → standard ingredients, **required ingredients** (★ — a ★ ingredient out of stock makes the dish "Temporarily sold out"; unmarked stays orderable), paid extras (name + price). Created with `is_available: true`, `stock_quantity: null` for restaurants.
- **Per-card controls:** Live/Hidden switch (`is_available`), edit, delete. Realtime keeps KDS/storefront in sync.
- **Categories tab:** name, sort order, discount %, optional limited-time-offer window.
- **Combos tab:** title, bundle price (cents), optional sale window, ≥1 included product. (Must add items first.)

### 2b. AI import — MERCHANT (restaurants only)
Two buttons on the Items tab → `MenuImportDialog` (calls the **`ai-menu-copilot`** edge fn; Sonnet `claude-sonnet-4-6`):
- **"Import menu with AI"** — upload images/PDFs (multiple, PDFs ≤10MB) → "Build my menu" → model returns a structured draft `{categories, items, combos}` with prices in cents (null + flagged if illegible). Two-pane copilot: chat to refine + an editable review table (the source of truth). Rows with null price are flagged amber and block import. "Import N items" creates products via `productApi.create` (`is_available: true`).
- **"Edit menu with AI"** — no upload; seeds from the live menu, chat to mutate ("86 the salmon", "add a dessert"), "Apply changes" reconciles by id with delete-confirm.

**Gap/infra note:** AI import needs the `ai-menu-copilot` edge fn deployed + `ANTHROPIC_API_KEY` (Phase 0d) — that's a FOUNDER/CLAUDE one-time backend dependency, not a merchant click. Per memory, AI v2 is merged + redeployed (live). Adding dish **photos** is a manual URL paste (AI import sets `image_url: null`).

### 2c. What makes a dish orderable on the storefront
The storefront reads the `get_public_menu(org_id)` RPC, gated `WHERE is_available = true`. Net checklist: (1) `is_available=true` (default on create), (2) valid price, (3) `stock_quantity` null or >0 (null for restaurants → auto-pass), (4) no **required** ingredient out of stock.

---

## PHASE 3 — Branding

All MERCHANT. **Route:** `/business/dashboard/branding` (sidebar "Branding", no tier gate).

| Set | Persists to | Note |
|---|---|---|
| Logo | `organizations.logo_url` (uploaded to `branding-assets` storage bucket via `settingsApi.uploadLogo`) | file picker |
| Primary / secondary color | `settings.branding.primary_hsl` / `secondary_hsl` (HSL) | hex→HSL; strict HSL regex guard against CSS injection |
| Font pair | `settings.branding.font_pair` (modern/classic/bold) | |

"Save changes" runs both `settingsApi.update` (settings JSONB) + `settingsApi.updateBranding` (logo). Branding reaches the customer storefront via `useStorefrontSettings(org)` (sets `:root` CSS vars + font stack) — applies **with or without** a published template.

---

## PHASE 4 — Pick + publish the storefront template

All MERCHANT. **Route:** `/business/dashboard/storefront` (`StorefrontTemplates.tsx`; sidebar "Storefront"; **solo tier-gated**).

> ⚠️ **CLAUDE.md is STALE here.** It says the template-picker UI is "PENDING / not built." On branch `feat/storefront-platform` the **picker EXISTS, is routed, and is in the sidebar.** This runbook reflects the branch.

### 4a. Merchant flow — MERCHANT
1. **Pick** one of the **10 curated templates** (`storefrontTemplates.ts`: `modern-minimal`, `bold-appetite`, `editorial-boutique`, `fresh-organic`, `luxe-noir`, `vibrant-market`, + `kerb`/`daily`/`maison`/`rush`). It's a **picker, not a builder** — no section toggle/reorder/drag (founder decision).
2. **Tweak** logo (reuses `uploadLogo`), primary/accent/background colors, hero headline/subhead/CTA copy.
3. See a **live preview** rendered with the merchant's real catalogue (`StorefrontRenderer`), desktop/mobile.
4. **Publish** → persists logo if changed, then `storefrontConfigApi.upsert(config, is_published=true)` — upserts one row into `storefront_config` keyed on `organization_id`, authorized by RLS (`organization_id = current_org_id()`). **This is a self-serve write — NOT a manual SQL step on this branch.**
5. **Revert to default** ("Unpublish") → `upsert(config, false)`.

### 4b. Honest gaps for Phase 4
- **Hard prerequisite:** the `storefront_config` + `template_variants` migrations (Phase 0a) **must be live**, or Publish is rejected by the DB CHECK / the config never resolves. Until then, **CLAUDE publishes the `storefront_config` with the merchant** (run the upsert / apply the row by hand) as the fallback — and the picker UI is the follow-up once migs are live.
- **Default fallback is safe:** with no published config, `get_public_storefront_config` returns null and the storefront renders the default `RestaurantStorefront` (branding still applies). A brand-new merchant needs **zero** template action to have a working, branded, order-taking storefront.
- **⚠️ Payment caveat:** the curated `PublishedStorefront` **does not trigger card capture** (by design, C1 hold) — it creates the order at `awaiting_confirmation` and hands off to `/order/:token`. Online **card capture lives only on the default `RestaurantStorefront` path.** So a merchant who publishes a curated template currently takes **orders but not online card payments** from that storefront. (Pilot accordingly, or stay on the default storefront if online card is the priority.)

---

## PHASE 5 — Operations / hours / fulfillment + notifications

All MERCHANT. **Route:** `/business/dashboard/operations` (sidebar "Operations") + `/business/dashboard/notifications` (sidebar "Notifications", marketplace tier+).

> Honest framing: **almost nothing is hard-required to accept an order** — defaults are permissive (all 3 fulfillment methods on; closed hours still allow pre-orders). Configure what actually matters:

### 5a. Operations page — MERCHANT
| Setting | Path | Effect |
|---|---|---|
| Weekly trading hours | `settings.hours` | Presentational — when "closed" the storefront shows "Pre-order only" but **still places orders**. Does not block ordering. |
| Fulfillment methods | `settings.fulfillment.{dine_in,takeaway,delivery}.enabled` | All 3 default ON. Enabling Delivery reveals radius/min-order/courier-fee config. |
| **Order confirmation** | `settings.orders.auto_confirm` (default **false**) + `confirmation_timeout_minutes` (default 7) | OFF → non-dine-in orders land at `awaiting_confirmation` (human approves). ON → straight to `pending` (kitchen). Dine-in always skips confirmation. |
| Business details | org compliance columns | Owner name, entity, phone (OTP), ABN, address. |
| Stripe payouts card | — | Phase 6. |
| Delivery integration (courier) | `courier_credentials` | Optional — Uber Direct/etc. key for auto-dispatch. |

Checkout logic: `needsApproval = payOnline || (fulfillment !== dine_in && !auto_confirm)` → `awaiting_confirmation`, else `pending`.

### 5b. Customer notifications — MERCHANT (marketplace tier+)
`/business/dashboard/notifications`: triggers `notify_on_preparing` / `notify_on_ready` (on) / `notify_on_declined` (forced on); channels email (all plans) + web push (needs customer opt-in); optional email footer. Below marketplace tier the per-order Bell shows a Lock.

**Known copy bug:** the notify-disabled tooltip says "Upgrade to **Growth**" but the actual gate is **marketplace** (`Orders.tsx` / `KitchenDisplay.tsx`). Cosmetic; will mislead a marketplace-tier merchant. Follow-up.

### 5c. The incoming-order flow (for Phase 9 verification)
- `awaiting_confirmation` → Kitchen Orders "Awaiting Your Approval" cards (5s poll) → **Confirm** (`order-respond` confirm → status `pending`, **captures Stripe hold**, emails customer) / **Decline** (cancels the hold, emails reason). pg_cron `auto_decline_stale_orders` after the timeout.
- `pending` → Kitchen Orders kanban + full-screen KDS (`/business/dashboard/kitchen`, Realtime + 30s poll, alert sound on new order, BUMP to advance).

---

## PHASE 6 — Connect Stripe (Connect Express)

### 6a. Merchant connects Stripe — MERCHANT
**Route:** `/business/dashboard/operations` → **"Stripe payouts" card** (`StripeConnectCard`). **There is no separate "Payments" sidebar link** — this card is the only entry point.

Click **"Connect Stripe account"** → invokes `stripe-connect-onboard` edge fn → creates an Express account (`type: express`, `country: AU`, card_payments+transfers capabilities) → saves `organizations.stripe_account_id` → returns a Stripe-hosted onboarding URL → `window.location.assign(url)`. Merchant completes ID + bank details on Stripe.

Architecture: **destination charges, `application_fee_amount: 0`** (founding pass-through), `on_behalf_of` + `transfer_data.destination` = merchant account → merchant is merchant-of-record, Woahh holds no funds → no AFSL needed.

### 6b. Readiness — MERCHANT sees / CLAUDE verifies
The card shows "Payment-ready · account ending {last4}" once `org.charges_enabled` is true. Set true two ways: the `account.updated` **webhook** (needs Phase 0d webhook config), **and** an eager refresh on every connect/"Finish setup" click (fallback). CLAUDE can verify: `SELECT charges_enabled, payouts_enabled, stripe_account_id FROM organizations WHERE id = …`.

**Honest note:** return_url is the legacy `/dashboard/operations` (relies on the `LegacyRedirect` to land at `/business/dashboard/operations`). `application_fee` is hardcoded 0 for all merchants today; the charity-split (non-founding) is deferred to Stripe AFSL / Connect Custom (not built). `organizations.founding_merchant` is **never written by app code** — set FOUNDER-side via SQL if needed.

---

## PHASE 7 — `name.woahh.app` subdomain go-live

> **Interim, zero-infra option (works TODAY, no DNS/TLS):** `https://woahh.app/shop/<slug>` already serves the same storefront — the `/shop/:slug` route resolves the slug from the route param. **No CNAME, no Pages domain, no wildcard TLS, no extra Auth entry.** Trade-offs: no per-merchant PWA branding (installs as generic "Woahh"), and it's under `woahh.app/...` not a vanity host. **Recommended pilot path while subdomain infra is pending.**

The vanity `name.woahh.app` adds: per-merchant PWA branding + the merchant's own brand origin. Steps (all FOUNDER / CLAUDE; all human-only console work):

### 7a. Cloudflare DNS — FOUNDER
Add a CNAME: `<name>` → `woahh-app.pages.dev`, **proxied (orange cloud)**. (Wildcard `*.woahh.app` only when scaling past a handful.)

### 7b. Cloudflare Pages custom domain — FOUNDER
`woahh-app` Pages project → Custom domains → add `<name>.woahh.app` (or `*.woahh.app`). Wait for **Active**. Load-bearing: Pages won't serve a host it wasn't told is a custom domain.

### 7c. Wildcard TLS — FOUNDER (mostly automatic)
Universal SSL covers **exactly one** wildcard level → single-label `<name>.woahh.app` is covered automatically; `a.b.woahh.app` is **not**. The code enforces single-label slugs (`tenant.ts`). At scale you may need an Advanced Certificate (still one level).

### 7d. SPA fallback + CSP — nobody (host-agnostic)
`public/_redirects` (`/* /index.html 200`) and `public/_headers` (CSP incl. `manifest-src 'self' blob:`, `connect-src` → `pmnyhbhtkcfoozkinieo.supabase.co`) are path-based and inherit to every host. Just verify post-cutover.

### 7e. Set the slug — FOUNDER / CLAUDE (SQL)
**There is NO `set_subdomain_slug` RPC and no merchant UI** (Operations only *links* to the slug). Set it with a guarded literal UPDATE in the Supabase SQL editor:
```sql
UPDATE public.organizations
SET subdomain_slug = 'name'   -- single-label, lowercase
WHERE id = '<ORG_UUID>';
```
The `guard_subdomain_slug` trigger (Phase 0a) **HARD-REJECTS** reserved (`mail`/`admin`/`www`/`eat`/`shop`…) or malformed slugs on UPDATE. **If the UPDATE errors → the name is reserved or invalid → pick another single-label slug.** (On INSERT the trigger auto-suffixes so signup never breaks; UPDATE rejects, so an explicit set must use a clean name.) Uniqueness is enforced by the pre-existing UNIQUE index. Do **not** run this before the guard migration is live.

### 7f. Auth allow-list (if single-host) — FOUNDER
If you went per-host in Phase 0e, add `https://<name>.woahh.app/**` now. (Skip if you added `https://*.woahh.app/**`.)

**Resolution recap:** `resolveTenant(host)` strips `.woahh.app`; a single non-reserved label → `{merchant, slug}`; apex/`www`/multi-label/IPs/`*.pages.dev`/reserved → apex (fail-safe). `App.tsx` root route: `tenantSlug ? <Shop forcedSlug/> : <Storefront/>`. `ApexOnly` forces `/business`, `/eat`, `/signin` back to apex on a subdomain.

---

## PHASE 8 — Flip on real card capture

> **HARD GATE — do this LAST, and only after C1 is verified live.** The order RPC inserts the **client-supplied** total as `orders.total_amount`, and `stripe-payment-intent` charges that stored amount. Before C1, a tampered client could be charged 1 cent for an $80 order. C1 (`20260608020000_c1_server_side_order_total.sql`) adds the server-side floor. **C1 is verified live per memory — re-confirm before flipping.**

### 8a. Verify C1 is applied — CLAUDE
Confirm the C1 migration is on the live DB and the order-total floor rejects under-totaled orders (test with a tampered total → expect rejection).

### 8b. Flip the switch — FOUNDER / CLAUDE (SQL only)
`settings.payments.online_card_enabled` **defaults FALSE** and has **NO dashboard UI** (grep finds no toggle). Set it per-merchant by SQL:
```sql
UPDATE public.organizations
SET settings = jsonb_set(settings, '{payments,online_card_enabled}', 'true')
WHERE id = '<ORG_UUID>';
```

### 8c. Runtime once flipped
Two gates must BOTH be true to take a card: merchant `charges_enabled` (Phase 6) AND `online_card_enabled` (8b). Flow: customer places card order → `stripe-payment-intent` creates a **manual-capture** PI (recomputes amount server-side, `application_fee=0`, `transfer_data.destination` = merchant) → card **authorized** (hold) → owner **confirms** in Orders → `order-respond` captures the hold (`payment_status='paid'`) → kitchen. Owner declines → hold cancelled. When OFF, orders place at `awaiting_confirmation` with pay-at-venue semantics and no card is taken.

---

## PHASE 9 — End-to-end go-live verification

CLAUDE + MERCHANT. Open the live storefront (`name.woahh.app/`, or interim `woahh.app/shop/<slug>`) in a fresh browser:

- [ ] Storefront boots **their** template + branding (subdomain) / their storefront (interim), not the marketing landing.
- [ ] The menu shown is their **live** menu (add/edit a product in `/business/dashboard/menu` → appears via realtime/refresh).
- [ ] (Subdomain only) `name.woahh.app/business` and `/eat` **redirect to apex** (ApexOnly guard); apex `woahh.app` is **unchanged**.
- [ ] (Subdomain only) Installing the PWA installs as **their** brand (name/icon from the org), not "Woahh".
- [ ] **Place a test order:** pay-at-venue / dine-in, or — only after Phase 8 — a Stripe **test card** (never a real card before C1 is confirmed). Order lands at `awaiting_confirmation` (or `pending` if auto-confirm / dine-in).
- [ ] **Owner confirms** in `/business/dashboard/orders` → status → `pending` → the order appears on the **Kitchen Orders kanban** and full-screen **KDS** (`/business/dashboard/kitchen`) with alert sound.
- [ ] (If card) the Stripe hold **captures** on confirm (`payment_status='paid'`); declining releases it.
- [ ] Customer notification fires (marketplace tier+) on preparing/ready.

---

## KNOWN GAPS / FOLLOW-UPS

- **Template-picker UI vs CLAUDE.md:** the picker (`/business/dashboard/storefront`) **exists on `feat/storefront-platform`** — CLAUDE.md's "PENDING / not built" is **stale**. Until the storefront migrations are live, **CLAUDE publishes the `storefront_config` with the merchant** (manual upsert) as the fallback.
- ~~Storefront migrations not confirmed live~~ — **DONE.** `20260603010000` / `20260603020000` / `20260607010000` are applied + verified live (config publishes; `kerb`/`maison` render on `/shop/test-bistro`).
- ~~`PublishedStorefront` integration unfinished~~ — **CORRECTED:** the bespoke `ThemeShell` stack **does render live** via `PublishedStorefront` on `woahh.app/shop/<slug>` (verified this session: a published `kerb` template renders its bespoke food-truck layout with the live menu). Shop.tsx gates `publishedConfig → PublishedStorefront`, else default. (The earlier "only in StorefrontPreview" read was stale.)
- **⚠️ KEY GAP — curated/bespoke template takes ORDERS but NOT online card payments:** the bespoke `PublishedStorefront` checkout hands off at `awaiting_confirmation` (no `CardPaymentDialog`); **online card capture is wired only on the default `RestaurantStorefront` path.** So a merchant on a **published premium template** can take orders + pay-at-venue, but **online card requires either the default storefront OR a small follow-up to wire `CardPayment` into the bespoke checkout.** This is the one real decision for "premium look + online cards." (~1 focused task to close.)
- **`online_card_enabled` is SQL-only:** no dashboard toggle; flipped per-merchant by FOUNDER/CLAUDE after C1. Follow-up: a gated dashboard control once C1 is broadly trusted.
- **`subdomain_slug` is SQL-only:** no `set_subdomain_slug` RPC and no merchant UI; set by a guarded literal UPDATE. Follow-up: a self-serve (rate-limited) slug control + alias.
- **`name.woahh.app` wildcard DNS / Pages custom domain / TLS = human-only** (FOUNDER). Single-label slugs only (one TLS wildcard level). Custom subdomains can't be tested on a branch preview — must merge to `main` first.
- **Reserved-slug parity:** `RESERVED_HOSTS` (`tenant.ts`) and the SQL guard's `reserved` array are identical today but have **no parity test** — edit both together. Follow-up: add a parity test.
- **Founding code delivery is manual:** generated in `/business/dashboard/admin/codes` (URL-only, no sidebar link), handed to the merchant out-of-band (no email).
- **`founding_merchant` / zero-commission terms not set at signup:** no app-code writer; FOUNDER sets via SQL. `application_fee` is hardcoded 0 for all merchants; non-founding charity-split deferred to Stripe AFSL / Connect Custom.
- **Anon-user cleanup cron:** guest/anon checkout users are guarded from spawning orgs (#4), but a cleanup cron for stale anon users / an upgraded-guest-profile path is a follow-up.
- **Captcha widget:** signup/auth captcha is a noted follow-up (widget + re-enable).
- **Notify tooltip copy bug:** says "Upgrade to Growth" but the gate is marketplace — cosmetic, fix the string.
- **Menu dish photos are URL-paste only:** no image upload widget in the item dialog; AI import sets `image_url: null`.
- **Phone OTP depends on ClickSend config:** `owner-verify` returns "SMS sending isn't configured" without `WOAHH_SMS_NUMBER` + ClickSend secrets (Phase 0d).
