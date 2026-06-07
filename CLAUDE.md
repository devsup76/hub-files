# CLAUDE.md — woahh Failsafe Context

> **SCOPE GUARD:** Only load and apply this context if the current conversation is about building, reviewing, or improving the woahh app. If the user has opened this session for an unrelated purpose (e.g. a quick question, a different project, general help), skip this file entirely and do not reference it — do not waste tokens on irrelevant context.

> This file is the single source of truth for woahh development sessions.
> Update it whenever a feature is completed, a key decision is made, or significant progress occurs.
> Last updated: 2026-06-07
>
> **How we work now (2026-06-07) — woahh.app is OFF Lovable.** It runs on **Cloudflare Pages** (frontend) → **Supabase `pmnyhbhtkcfoozkinieo`** (Postgres/RLS, Auth, Storage, Edge Functions). We **edit code directly and push to `main` of `devsup76/business-growth-hub`**; Cloudflare rebuilds prod from `main` (a branch push = a Cloudflare *preview*). DB changes = SQL migrations the owner runs in the Supabase SQL editor; edge functions deploy via `npx supabase functions deploy`. The "Lovable prompt" workflow described below is historical.

---

## ~~Lovable Prompt Constraints~~ — OBSOLETE (off Lovable)

woahh.app no longer builds on Lovable; we edit code directly and push to `main`. The old 5000-char Lovable-prompt-splitting rule no longer applies. (Kept only as a historical marker — ignore for current work.)

---

## What This App Is

**Woahh** is a multi-tenant SaaS platform for small business owners (restaurants + retail shops).

> **Brand casing rule:** UI / frontend = `Woahh` (capital W). Backend code, edge functions, email addresses, query keys, SMS bodies = `woahh` (lowercase).
It runs on **Cloudflare Pages** (frontend) + **Supabase `pmnyhbhtkcfoozkinieo`** (Postgres/RLS, Auth, Storage, Edge Functions). Code is edited directly in this repo and pushed to `main` of `devsup76/business-growth-hub`; Cloudflare rebuilds prod from `main`.

**Core value prop:** Give a small business owner a single dashboard to manage orders, products, customers, loyalty, promotions, and marketing — with a public-facing storefront, marketplace listing, and customer portal included.

---

## Hosting & Domain Architecture (as of 2026-05-28)

**Live at:** `https://woahh.app` — single origin, path-based split.

| Path | Surface | Notes |
|---|---|---|
| `/` | Marketing landing (Storefront.tsx) | Header "Sign in" + "Start free" point at `/business/auth` |
| `/eat`, `/eat/:slug`, `/shop`, `/order/:id`, `/account`, `/book/:slug`, `/cancel-reservation/:token`, `/impact`, `/signin`, `/reset-password`, `/join`, `/unsubscribe/:token`, `/privacy`, `/terms`, `/demo` | Customer surfaces | All same-origin |
| `/business/auth`, `/business/recover` | Merchant auth | |
| `/business/dashboard/*` | Merchant portal | All dashboard pages live here |
| `/auth`, `/recover`, `/dashboard/*` | Legacy paths | Same-origin `<Navigate>` to `/business/*` |

**Legacy `business.woahh.app` subdomain** still resolves but `src/main.tsx` synchronously redirects to `https://woahh.app/business/<path>` before React mounts. Old email links + bookmarks keep working.

**Why single origin (historical):** an earlier subdomain split caused cross-origin localStorage issues for sessions, password reset, and magic links (`woahh.app` ↔ `business.woahh.app` are separate origins; localStorage doesn't share). Single origin fixed those. **Now on Cloudflare Pages** (which DOES support `public/_headers` + `_redirects` — we use `_headers` for CSP), we are introducing **per-merchant `<slug>.woahh.app` subdomains for storefronts** (see "Storefront Platform" below). The merchant *dashboard/auth* stays single-origin on the apex, so the cross-origin-session concern doesn't apply to public storefronts (no merchant login on a storefront subdomain).

**URL helpers** (`src/lib/hostUrls.ts`):
- `apexUrl(path)` → same-origin path (returns the path as-is)
- `businessUrl(path)` → `/business/<path>` (e.g. `businessUrl("/auth")` → `/business/auth`)
- Both are kept for readability and so we can flip back to a real subdomain later if needed.

**`docs/CROSS_DOMAIN_REDIRECTS.md` (in `repo/`)** documents the current architecture and includes Cloudflare edge rules to paste if you ever want true zero-flicker on the legacy subdomain.

---

## Storefront Platform — per-merchant subdomains + config-driven UI + per-merchant PWA (branch `feat/storefront-platform`, SCAFFOLDED 2026-06-07, NOT merged/deployed)

Three additive pillars layered **on top of** the existing single-origin stack. Apex (`woahh.app` marketing + `/eat` marketplace + `/business/*` dashboard) behaviour is intended to stay byte-for-byte unchanged; subdomains are a routing/presentation layer over the existing `subdomain_slug` + `get_public_storefront` RPC — **no new data path, no new RLS surface, no change to the isolation boundary** (a subdomain deterministically resolves to exactly one slug → exactly one org via the same SECURITY DEFINER RPC already in production).

**Pillar 1 — `<slug>.woahh.app` subdomain tenant resolution.** `src/lib/tenant.ts` (NEW, scaffolded) is the single host→slug authority: pure/SSR-safe, `RESERVED_HOSTS` set (apex/system labels never resolve to an org — fail-safe to apex), `SLUG_RE` mirroring the DB rule, `resolveTenant`/`getTenantSlug`/`isMerchantSubdomain`/`tenantUrl`. Apex, `www`, localhost, IPs, `*.pages.dev`, `capacitor://`, `file://` all resolve to `apex` (apex unchanged off prod). `src/App.tsx` root route is wired: `tenantSlug ? <Shop forcedSlug={tenantSlug}/> : <Storefront/>` so `<slug>.woahh.app/` boots the merchant storefront, marketing on apex. `src/pages/Shop.tsx` accepts `forcedSlug`. (Designs also call for a pre-mount `/business`+`/eat`→apex redirect on tenant hosts and a `set_subdomain_slug` RPC + reserved-slug DB guard — **NOT yet built**.)

**Pillar 2 — config-driven custom storefront UI.** Dedicated `storefront_config` table (migration `20260603010000_storefront_config.sql`, NEW, **NOT applied to live DB**): one row per org, presentation-only (`template` ∈ classic|hero|grid|minimal, `theme` jsonb tokens, `sections` jsonb ordered/toggleable, `hero` copy, `is_published`). RLS via `current_org_id()` (owner+staff write); server-side `validate_storefront_config` trigger (allow-listed section ids, HSL-regex theme tokens, length-capped copy); anon read **only** via `get_public_storefront_config(slug)` SECURITY DEFINER RPC (published-only), mirroring `get_public_storefront`/`get_public_menu`. Frontend: `src/lib/storefrontConfig.ts` (types, `DEFAULT_STOREFRONT_CONFIG`, `parseStorefrontConfig` sanitiser, `visibleSections`), `src/components/storefront/StorefrontRenderer.tsx` (section registry → ordered/toggled render; template = layout-wrapper only) + `src/components/storefront/sections/*` (Hero, FeaturedProducts, Categories, About, Gallery, Reviews, Map, CTA). Theme tokens reuse the existing `useStorefrontSettings` HSL-allowlist guard (no raw merchant CSS). Config-driven, not bespoke per-merchant code, not a drag-drop builder. **PENDING integration:** `StorefrontRenderer` is NOT yet in the render path — `Shop.tsx` still renders `RestaurantStorefront`/`RetailStorefront`; nothing yet calls `get_public_storefront_config` / a `storefrontConfigApi`; **no editor UI** (no `StorefrontDesigner`/`Design` dashboard page, route, or sidebar link).

**Pillar 3 — per-merchant installable PWA (dynamic manifest).** `src/lib/pwaManifest.ts` (NEW, scaffolded): `buildTenantManifest`/`applyTenantManifest` build a per-merchant Web App Manifest (name/icon/theme from the org + branding) as a `blob:` URL and swap `<link rel="manifest">` at runtime — invoked from `Shop.tsx` **only on a merchant subdomain** (apex keeps the static `public/manifest.json` = "Woahh"). The service worker is per-origin so caches/push are tenant-isolated automatically. **Capacitor-wrapped native app = later** (outline only; `resolveTenant` already returns `apex` for `capacitor://` so it's the single seam to extend with a build-time forced slug). PENDING polish: per-merchant 192/512 maskable icons (currently falls back to `logo_url` / Woahh defaults); optional edge-rendered manifest (Cloudflare Pages Function / Supabase fn) for launcher fidelity.

**Status — scaffolded vs pending:**
- ✅ **Committed + pushed on `feat/storefront-platform`** (foundation `8b29b03` + hardening `60b7831`; `vite build` + `tsc` green, 48 `tenant.test.ts` tests pass, apex byte-unchanged, NOT merged): `tenant.ts`, `storefrontConfig.ts`, `StorefrontRenderer.tsx` + `sections/*`, `pwaManifest.ts`, migration `20260603010000_storefront_config.sql`; `App.tsx` root-route + `Shop.tsx` `forcedSlug`/manifest wiring.
- ✅ **Hardening done** (`60b7831`): CSP `manifest-src 'self' blob:`; apex-only route guard (`ApexOnly.tsx` — `/business`+`/eat`→apex on tenant hosts); reserved-slug DB guard trigger (migration `20260603020000_guard_subdomain_slug.sql` — UPDATE rejects reserved/malformed `subdomain_slug`, INSERT auto-suffixes so signup never breaks); `storefront_config` 32KB + https-URL bounds; `tenant.test.ts`.
- ⏳ Pending — **DNS/infra (human-only):** wildcard `*.woahh.app` CNAME → Cloudflare Pages project, add `*.woahh.app` as a Pages custom domain, wildcard TLS (Universal/Advanced cert covers one level only — single-label slugs enforced by the regex). `_redirects` SPA fallback + `_headers` CSP are path-based/host-agnostic so they inherit fine; verify post-cutover.
- ⏳ Pending — **integration:** wire `StorefrontRenderer` + `get_public_storefront_config` into the storefront render path (default config = today's layout, so unconfigured merchants render unchanged); apply the migration to live (`pmnyhbhtkcfoozkinieo`) + regenerate `types.ts`.
- ⏳ Pending — **template selection (NOT a builder — founder decision 2026-06-07):** merchants do NOT get a page/section builder ("above their level + time-consuming"). Ship **a curated set of premium, state-of-the-art ready-made templates** (each = a vetted `storefront_config`: template + sections + theme) that the merchant simply **picks** in a small dashboard page, plus basic branding (logo / colors / copy). No drag-drop, no section-reorder UI. The `sections`/`StorefrontRenderer` machinery exists to power *our* templates, not a merchant editor.
- ⏳ Pending (remaining) — slug-change rate-limit/alias (optional); keep the reserved-list in sync across `tenant.ts` ↔ the SQL guard (verify-noted MEDIUM — add a parity test). *(Reserved-slug DB guard + the `/business`+`/eat`→apex redirect are now DONE in `60b7831`.)*
- ⏳ Pending — **native:** Capacitor per-merchant build pipeline (Growth/Enterprise tier; outline only).

**Benchmark framing:** measurably better than Bopple/Shopline/Shopify for small AU merchants — one org row drives a branded subdomain + installable app + the discovery marketplace + the dashboard with zero per-merchant code or theme store. See `docs/POSITIONING_STOREFRONT.md` (in repo) for the competitive positioning.

---

## Email Domain Setup (Resend, as of 2026-05-28)

Two Resend-verified sub-domains on Cloudflare DNS:

| Subdomain | Purpose | Used by |
|---|---|---|
| `mail.woahh.app` | Transactional email (sender domain) | `order-respond`, `order-notify`, `send-transactional-email`, `reservation-confirm`, `reservation-remind` edge functions |
| `campaigns.woahh.app` | Marketing email (per-merchant slug addressing) | `email-send` — `<slug>@campaigns.woahh.app` |

Each merchant gets a unique sender `<safeFromName(org.name)> <{slug}@campaigns.woahh.app>`. Reply-To uses `organizations.contact_email`. Unsubscribe header includes both Gmail's one-click POST URL and the in-body unsubscribe link.

Email infrastructure is fully hardened: stale-claim self-heal + structured logging + atomic claim, Svix HMAC verification on `email-webhook`, idempotency keys on transactional sends, safe-from-name sanitiser, preheader injection, atomic `increment_email_usage` RPC.

---

## Tech Stack

| Layer | Tech |
|---|---|
| Frontend | React 18.3 + TypeScript + Vite 5 |
| UI | shadcn/ui + Radix UI + Tailwind CSS 3.4 |
| State / data | TanStack React Query 5 |
| Forms | React Hook Form + Zod |
| Backend / DB | Supabase (PostgreSQL, Auth, RLS, Storage, Realtime) |
| Edge Functions | Deno (Supabase Functions) |
| SMS | Clicksend API |
| Email | Resend API (email-send + email-webhook edge functions) |
| Payments | Stripe — Connect Express online card payments built + Connect **live-activated** (2026-06-07); Stripe Billing (subscriptions) not yet built |
| Charts | Recharts |
| Testing | Vitest + Testing Library + JSDOM |

---

## Repo Structure (key paths)

```
src/
  main.tsx                            # Pre-mount: legacy subdomain redirect + demo bootstrap
  App.tsx                             # Route table — customer paths + /business/* merchant paths
  lib/
    hostUrls.ts                       # apexUrl() / businessUrl() / canonicalRedirectFor()
    demoBootstrap.ts                  # ?demo=role URL handler
  pages/
    Auth.tsx                          # Persona picker + Business Admin form + StaffForm + CustomerForm (exported)
    CustomerSignIn.tsx                # /signin — wraps CustomerForm in apex shell
    Storefront.tsx                    # Public landing page (merchant storefront entry)
    Shop.tsx                          # Customer-facing product browse + cart
    OrderStatus.tsx                   # Real-time order tracker (public by order UUID)
    Account.tsx                       # Customer portal (rewards, orders, preferences)
    DemoEntry.tsx                     # Activates demo mode
    DemoRestaurantPreview.tsx         # Preview page for demo restaurant
    Marketplace.tsx                   # Public /eat marketplace (discover all merchants)
    MarketplaceProfile.tsx            # /eat/:slug merchant profile + order CTA
    Impact.tsx                        # Public /impact transparency dashboard
    Unsubscribe.tsx                   # /unsubscribe/:token email opt-out
    storefront/
      RestaurantStorefront.tsx
      RetailStorefront.tsx
    dashboard/
      DashboardLayout.tsx             # Sidebar + nav shell
      DashboardOverview.tsx           # Stats + quick start guide
      Orders.tsx                      # Order management (kanban + confirmation flow)
      Menu.tsx                        # Product/menu catalog + categories + combos
      Customers.tsx                   # CRM (marketplace tier+)
      Loyalty.tsx                     # Loyalty config (marketplace tier+)
      SMSCampaigns.tsx                # SMS campaign builder (marketplace tier+)
      EmailCampaigns.tsx              # Email campaign builder (solo tier+)
      Operations.tsx                  # Hours, fulfillment, courier credentials
      Promotions.tsx                  # Promo codes
      Promote.tsx                     # Sponsored marketplace listings (solo tier+)
      Donate.tsx                      # Voluntary giving rate + one-time donations
      Branding.tsx                    # Logo, colors, fonts
      Tables.tsx                      # Dine-in table management
      Reservations.tsx                # Reservations management (Phase 1)
      KitchenSettings.tsx             # Kitchen display + courier config
  components/
    TierGate.tsx                      # Feature access gating wrapper
    DonationBadge.tsx                 # Impact Partner badge component
    dashboard/AppSidebar.tsx          # Left nav
    ui/                               # 50+ shadcn/ui components
  hooks/
    useAuth.tsx                       # Owner auth context
    useCustomerAuth.ts                # Customer magic-link auth
    useOrg.ts                         # Fetch current user's org
    usePromoCode.ts
    useStorefrontSettings.ts
  services/
    api.ts                            # Decoupled API layer (routes to demo or Supabase)
    settings.ts
    customerAccount.ts
  lib/
    demo.ts                           # In-memory DemoStore (full seeded data for demo mode)
    tier.ts                           # Plan tier helpers + feature access logic
    badges.ts                         # Merchant badge/achievement system
  integrations/supabase/
    client.ts                         # Supabase client
    types.ts                          # Auto-generated DB types

supabase/
  functions/
    sms-send/index.ts                 # Edge Function: sends SMS via Clicksend
    sms-webhook/index.ts              # Edge Function: delivery receipts + opt-out handling
    email-send/index.ts               # Edge Function: sends email via Resend batch API
    email-webhook/index.ts            # Edge Function: Resend delivery events + opt-out
    courier-dispatch/index.ts         # Edge Function: dispatches Uber Direct orders
    order-respond/index.ts            # Edge Function: confirm/decline + auto-decline stale
    staff-manage/index.ts             # Edge Function: owner-only staff account CRUD (PIN-based)
    staff-pin-login/index.ts          # Edge Function: staff PIN login → createSession; 5-attempt lockout
    owner-verify/index.ts             # Edge Function: owner phone OTP + ABN checksum validation
  migrations/                         # All DB migrations (~86 as of 2026-06)
```

---

## Database Schema (key tables)

### Enums
- `org_tier`: `free_trial | solo | marketplace | growth | enterprise`
- `order_status`: `pending | awaiting_confirmation | preparing | ready | completed | declined`
- `business_type`: `restaurant | retail`
- `fulfillment_type`: `delivery | pickup | shipping | in_store_pickup`
- `discount_type`: `percentage | flat`
- `reservation_status`: `requested | confirmed | seated | completed | cancelled | no_show`

### Core Tables
| Table | Purpose |
|---|---|
| `organizations` | One per owner; tier, settings JSONB, loyalty_config JSONB, SMS/email caps + top-up credits, marketplace fields (visible, tagline, cover, cuisine_tags, lat/lng, rating), total_donations_cents, voluntary_donation_rate_bp; compliance: owner_full_name, legal_entity_type, owner_phone, phone_verified, phone_otp_hash/expires_at, abn, abn_verified, business_address JSONB, tos_accepted_at, tos_version, spam_act_acknowledged, onboarding_completed_at |
| `customers` | CRM records; loyalty points, dietary prefs, saved addresses, birthday, SMS + email opt-out tracking |
| `products` | Menu/inventory; price, sale_price + sale window, stock, extras JSONB, ingredients[], tags[], category_id |
| `menu_categories` | Named categories with optional LTO window (starts_at/ends_at) and category-level discount_percent |
| `combos` | Product bundles at a fixed bundle_price with sale window; linked via combo_items |
| `combo_items` | Junction: combo_id + product_id + quantity |
| `orders` | Orders with line_items JSONB, fulfillment_type, dine_in flag, table_number, confirmation fields (confirmed_at, declined_at, denial_reason), courier tracking columns |
| `tables` | Dine-in tables with zone, seats, QR support |
| `reservations` | Table reservations with party_size, time window, status, cancellation_token |
| `sms_campaigns` | SMS broadcasts; audience, status, recipient/delivered/opted_out counts |
| `sms_log` | Per-message delivery audit trail |
| `email_campaigns` | Email broadcasts; status, audience, open/click/bounce counts |
| `email_log` | Per-email delivery audit trail |
| `promo_codes` | Discount codes with usage limits and expiry |
| `reviews` | Customer reviews (1–5 stars); triggers aggregate update on organizations.marketplace_rating |
| `promotions` | Sponsored marketplace listings; amount_cents split into charity_cents + platform_cents |
| `donation_ledger` | Public audit trail for all charitable giving; sources: gmv_mandatory, voluntary, promotion_share, one_time |
| `courier_credentials` | Per-org API keys for uber_direct, doordash_drive, sherpa, lalamove |
| `usernames` | Username → user_id mapping for customer sign-in |
| `signup_codes` | Manual tier upgrade codes |

### Key DB Functions + Triggers
- `current_org_id()` — used in all RLS policies
- `handle_new_user_org()` — trigger: auto-creates org on owner signup
- `apply_tier_caps()` — trigger: sets correct SMS/email monthly caps on INSERT/UPDATE OF tier
- `reset_monthly_sms_usage()` / `reset_monthly_email_usage()` — pg_cron monthly resets (also zeroes top-up credits)
- `redeem_signup_code(code)` — upgrades org tier
- `lookup_email_for_username(username)` — customer sign-in helper
- `find_available_table(_org_id, _start, _end, _party_size)` — returns first suitable table for reservation
- `auto_dispatch_courier()` — trigger: fires courier-dispatch edge function when order → 'preparing'
- `auto_decline_stale_orders()` — pg_cron every minute: calls order-respond for timed-out awaiting_confirmation orders
- `update_org_rating()` — trigger: keeps organizations.marketplace_rating in sync with reviews
- `update_org_donations()` — trigger: increments organizations.total_donations_cents on donation_ledger insert
- `validate_reservation()` — trigger: end_at must be after start_at

---

## Tier / Feature Gating

```
free_trial  → full marketplace-tier access until trial_ends_at (60 days)
solo        → email campaigns, promote (sponsored listings)
marketplace → + CRM, Loyalty, SMS Campaigns, marketplace listing, customer order notifications
growth      → + higher SMS/email caps, priority placement, custom domain/PWA
enterprise  → unlimited everything
```

SMS/email caps are set automatically by `apply_tier_caps()` trigger:
| Tier | Email cap | SMS cap |
|---|---|---|
| solo | 2,000/mo | 0 |
| marketplace | 15,000/mo | 700/mo |
| growth | 50,000/mo | 1,000/mo |
| enterprise | 100,000/mo | 2,500/mo |

Top-up credits: `sms_topup_credits` and `email_topup_credits` on organizations. No rollover — zeroed by monthly reset functions.

TierGate in `App.tsx`:
- `loyalty`, `customers`, `sms`, `notifications` → `minTier="marketplace"`
- `email`, `promote` → `minTier="solo"`
- `donate` → no gate (all tiers)

---

## Feature Status

| Feature | Status | Notes |
|---|---|---|
| Order management | ✅ Complete | Kanban, real-time, confirmation flow (awaiting_confirmation / declined), auto-decline cron |
| Product / menu catalog | ✅ Complete | CRUD, extras, stock, sale windows, categories, combos |
| Menu categories | ✅ Complete | LTO windows, category-level discounts |
| Combos | ✅ Complete | Bundle products at fixed price, sale windows |
| Customer CRM | ✅ Complete | List, manage, opt-in tracking (marketplace tier+) |
| Loyalty rewards | ✅ Complete | Points + milestone, birthday rewards (marketplace tier+) |
| SMS campaigns | ✅ Complete | Full UI + Clicksend + delivery tracking + opt-out + top-up credits |
| Per-merchant SMS | ✅ Verified end-to-end on new backend (send + STOP); not yet merged to main | Two-number model (shared `WOAHH_SMS_NUMBER` OTP + per-merchant `organizations.sms_number` marketing; STOP scoped per merchant). Migration `20260531000000` (`admin_assign_sms_number`, `set_sms_consent`), provider abstraction `_shared/sms.ts`. Deployed to `pmnyhbhtkcfoozkinieo` + tested 2026-05-31 (dedicated number `+61455725154`, ClickSend inbound rule → `sms-webhook`). Audit-fixed (14 findings). Branch `feat/per-merchant-sms`. **See `docs/SMS_ARCHITECTURE.md`**. |
| Email campaigns | ✅ Complete | Full UI + Resend batch API + open/click tracking + unsubscribe + top-up credits |
| Storefront (public) | ✅ Complete | Restaurant + retail variants |
| /eat Marketplace | ✅ Complete | Marketplace.tsx + MarketplaceProfile.tsx; discovery, cuisine filter, ratings, Impact badge |
| Impact portal | ✅ Complete | Public /impact dashboard; donation_ledger aggregates, leaderboard, by-cause chart |
| Donation features | ✅ Complete | DonationBadge, Donate dashboard, voluntary giving rate slider, one-time donations |
| Sponsored listings | ✅ Complete | Promote.tsx; promotions table with charity/platform split (solo tier+) |
| Reviews | ✅ Complete | Customer reviews table; aggregate rating trigger on organizations |
| Courier / delivery | ✅ Complete | courier_credentials, auto_dispatch_courier trigger, order tracking columns, demo mock |
| Dine-in tables | ✅ Complete | Tables CRUD, zones, bulk add, QR codes, dine_in + table_number on orders |
| Reservations | ✅ Complete | Public booking widget (/book/:slug), cancel page (/cancel-reservation/:token), waitlist, reminders (24h+2h cron), deposit config, owner settings in Operations, reservation-confirm + reservation-remind edge functions |
| Customer portal | ✅ Complete | Rewards, order history, profile |
| Promo codes | ✅ Complete | CRUD, usage limits, expiry |
| Branding | ✅ Complete | Logo upload, HSL colors, font pairs |
| Auth (owner) | ✅ Complete | Supabase Auth |
| Auth (customer) | ✅ Complete | Magic link + username lookup |
| Unsubscribe page | ✅ Complete | /unsubscribe/:token public route |
| Demo mode | ✅ Complete | In-memory DemoStore, seeded Bella's Bistro, full feature coverage |
| Multi-tenancy / RLS | ✅ Complete | All tables isolated by org |
| Subscription tier system | ✅ Complete | solo/marketplace/growth/enterprise; apply_tier_caps trigger; top-up credits |
| KitchenSettings | ✅ Complete | Courier credentials config, kitchen display settings |
| Unified customer identity | ✅ Complete | growthhub_profiles + merchant_connections tables; merge by email + phone on sign-in; cross-merchant Account hub (My Merchants, Orders, Notifications tabs); per-merchant per-channel consent; GH badge in owner CRM; post-order account prompt on Shop + ReservationBooking |
| Stripe online payments | ✅ Built + Connect **live-activated** (2026-06-07) | Connect Express **destination charges** (founding merchant = `application_fee` 0); edge fns `stripe-payment-intent` / `stripe-webhook` / `stripe-connect-onboard` / `order-respond` (manual capture on owner-confirm); `pk_live` in prod. ⚠️ **C1 (server-side order-total validation) is staged/ON-HOLD** for the restaurant-inventory rebuild — the order RPC currently trusts the client total, so **do not take real cards until C1's fix is applied**. |
| Stripe Billing (subscriptions) | ❌ Not started | No subscription-management UI yet (separate from the order-payment flow above). |
| Reservation timezone | ✅ Complete | settings.reservations.timezone selector in Operations; list_available_slots RPC uses AT TIME ZONE; defaults to Australia/Brisbane |
| Analytics dashboard | ✅ Complete | 7 togglable widgets: revenue trend, fulfillment mix, top products, peak hours heatmap, new/returning customers, categories, marketing; 90-day synthetic demo history; date range tabs (Today/7d/30d/90d); widget customisation via localStorage |
| In-person loyalty codes | ✅ Complete | McDonald's-style 5-min rotating 6-digit codes; earn + redeem; customer Account In-Store tab + dashboard Loyalty validator panel; loyalty_code_sessions table + upsert/validate RPCs |
| Scheduled sends | ✅ Complete | Quick presets, timezone label, "Sends in X" pill, best-time tip, cancel action; pg_cron dispatch_scheduled_campaigns() fires every minute |
| Staff accounts | ✅ Complete | staff_accounts table; manager/service/kitchen roles; owner-only staff-manage edge function; synthetic email auth; route guards (DashboardLayout + RouteGuard); role-based sidebar; auto-redirect by role on sign-in; session ban on deactivate; inline role editing |
| KDS color coding | ✅ Complete | Full-width fulfillment header bar (dine-in=blue, pickup=purple, delivery=orange, in-store pickup=teal); thin status strip + card border for order state; elapsed timer in header |
| KDS keyboard shortcuts | ✅ Complete | Pool + kanban mode-aware navigation (↑↓←→ + bump/recall); owner-customisable via KitchenSettings KeyCapture UI; shortcuts deep-merged into kds.shortcuts in settings |
| Staff PIN login | ✅ Complete | 6-digit PIN only (no password for staff); pin_hash = SHA-256(pin:userId); staff-pin-login edge function; 5-attempt lockout + 15-min cooldown; constant-time comparison; owner reset_lockout action; PIN keypad in Auth.tsx; owner sets/resets PIN in Staff.tsx |
| Merchant onboarding & compliance | ✅ Complete | Legal minimum + industry level: business type, owner full legal name, legal entity type, phone (OTP verified via Clicksend), ABN (checksum validated + unique), business address, ToS acceptance timestamp + version, Spam Act acknowledgement; owner-verify edge function; OnboardingChecklist component (5-step progress card); PhoneVerifyDialog (InputOTP); SMS/Promote guards; Business Details section in Operations |
| Customer order notifications | ✅ Complete | Email (Resend) + Web Push (VAPID RFC 8291); `push_subscriptions` + `order_notification_log` tables; `order-notify` edge function (accepts owner JWT or service-role key; fixed auth bug); service worker at public/sw.js; PushOptIn Bell on /order/:id; auto-trigger + manual Bell in Orders + KDS; NotificationSettings page (triggers, channels, email footer); dine-in excluded; marketplace tier+ |
| Staff shift availability | ✅ Complete | ShiftAvailabilityPanel in KDS + Orders; toggle product sold-out/available (stock 0/99); toggle extras on/off in JSONB; manager + service roles only; Realtime subscription |
| Account recovery | ✅ Complete | /recover page; security questions (SHA-256 hashed); max 3 attempts/hour; account_recovery_log; owner phone change flow (PhoneChangeDialog + OTP); customer dual-verification prompt |
| Single-origin routing | ✅ Complete | woahh.app serves both customer (`/`, `/eat`, `/account`, ...) and merchant (`/business/*`) surfaces. Legacy `business.woahh.app` redirects pre-mount in `src/main.tsx`. Legacy in-app paths (`/auth`, `/dashboard/*`) `<Navigate>` to `/business/*`. |
| Customer sign-in route | ✅ Complete | Dedicated `/signin` page on apex (CustomerSignIn.tsx). Reuses CustomerForm from Auth.tsx (named export). Business Admin / Service personas are the only options at `/business/auth`. |
| Email domain integration | ✅ Complete | `mail.woahh.app` (transactional) + `campaigns.woahh.app` (per-merchant marketing). DKIM/SPF/DMARC verified at Resend. Cloudflare DNS records. |
| Email send hardening | ✅ Complete | `email-send` edge function: atomic claim, stale-claim self-heal (>10min), try/catch revert on uncaught error, structured `[email-send]` JSON logging at every external call, safeFromName sanitiser, idempotency keys on transactional sends, atomic `increment_email_usage` RPC. |
| Multi-tenant data isolation | ✅ Complete | Multiple migrations (20260528115310, 131845, 131923, 134549) closed public-SELECT leaks on: orders, reservations, organizations, promotions, courier_credentials, growthhub_profiles, reviews, signup_codes, storage product-images. Replaced with SECURITY DEFINER RPCs (`get_order_by_id`, `get_reservation_by_token`, `cancel_reservation_by_token`, `create_public_reservation`) and safe views (`marketplace_organizations`, `active_promotions`). |
| `current_org_id` determinism | ✅ Complete | `ORDER BY priority(owner=0, staff=1), tiebreak` ensures stable resolution for users in multiple orgs. Closes a real cross-org data-leak risk. |
| Public order tracking | ✅ Complete | `OrderStatus.tsx` polls every 5s via `get_order_by_id` RPC; courier driver phone is scrubbed from the RPC's response. |
| Sign-up flow polish | ✅ Complete | Retail option hidden at sign-up (restaurants only for founding-merchant phase). All org fields (business_type, owner_full_name, legal_entity_type, owner_phone, tos_version) flow through `auth.users.user_metadata` so the dashboard hydrates the org row even when email confirmation is required. `BusinessTypeGate` auto-applies from metadata. |
| Customer consent timestamps | ✅ Complete | Customers.tsx "Add Customer" toggle now derives `email_consent_at` / `sms_consent_at` from `marketing_opt_in` at insert. Delete wrapped in AlertDialog. |
| Staff PIN 3-step verify | ✅ Complete | `staff-pin-login` edge function actions: `verify_org` (returns minimal org info), `verify_user` (checks username), `login` (verifies PIN). Generic 404 prevents handle enumeration. |
| Products realtime | ✅ Complete | `useProductsRealtime` hook + `ALTER TABLE products REPLICA IDENTITY FULL` + supabase_realtime publication. Owner adds menu item → KDS, walk-in dialog, public storefront update without refresh. |
| Ingredient availability | ✅ Complete (branch `feat/ingredient-availability`, committed not pushed) | Org-wide "temporarily unavailable ingredient" registry. Staff toggle an ingredient Out in the Shift Availability panel ("Menu availability" sheet on Orders + KDS); every restaurant dish whose `ingredients_list` contains it shows "temporarily unavailable" on the storefront card + struck-through in the customize dialog, **but stays orderable**. Out ingredients are stamped into `removed_ingredients` at add-to-cart so the kitchen ticket/KDS/receipt show "− No X". `ingredient_shortages` table (migration `20260602100000`, APPLIED to live DB) + RLS via `current_org_id()` + anon `get_public_ingredient_shortages` RPC (mirrors `get_public_menu`). Adversarial-reviewed (17 agents) + Playwright-verified end-to-end (incl. real order → KDS ticket "NO Coriander"). Out-of-stock ingredients computed **live at order time** (commit `0351633`). **Essential-ingredient hard-block shipped** (commit `cd758a3`, migration `20260602120000`): per-product `required_ingredients`; a required ingredient out → item "Temporarily sold out" + Add disabled + checkout guard; optional ingredients still stay-orderable. Menu editor ★ toggle marks required. **Deferred:** demo-mode seeding. |
| Storefront platform (subdomains + config UI + per-merchant PWA) | 🚧 Scaffolded, not merged/deployed (branch `feat/storefront-platform`) | Three additive pillars: (1) `<slug>.woahh.app` wildcard subdomain → branded storefront via `src/lib/tenant.ts` resolution (wired into `App.tsx` root route + `Shop.tsx` `forcedSlug`); (2) config-driven UI — `storefront_config` table + `get_public_storefront_config` anon RPC (migration `20260603010000`, NOT applied to live), `src/lib/storefrontConfig.ts` + `StorefrontRenderer` + `sections/*` (merchant **picks from curated premium ready-made templates — NOT a builder**, founder decision 2026-06-07; theme tokens reuse the `useStorefrontSettings` HSL guard); (3) per-merchant installable PWA via dynamic blob manifest (`src/lib/pwaManifest.ts`, applied subdomain-only; apex keeps static "Woahh" manifest), Capacitor native later. **Isolation unchanged** — subdomain → one slug → one org via the existing `get_public_storefront` RPC; apex byte-for-byte unchanged. **PENDING:** wildcard DNS/TLS + Pages custom domain (human), wiring `StorefrontRenderer`+RPC into the render path (default config = today's layout), a **template-picker** dashboard page (curated templates, NOT a builder), native app. (Hardening — CSP, apex-guard, reserved-slug DB guard, config bounds — **DONE** in `60b7831`.) See **Storefront Platform** section above the feature table. |

---

## Order Confirmation Flow

Orders can require owner confirmation before entering the kitchen queue:

1. Customer places order → status `awaiting_confirmation` (if org has confirmation enabled in settings)
2. Owner sees a confirmation banner in Orders.tsx; can confirm or decline with a reason
3. Confirming → status `pending` (enters normal kanban flow); `confirmed_at` set
4. Declining → status `declined`; `declined_at` + `denial_reason` set; customer notified via `order-respond` edge function
5. pg_cron runs `auto_decline_stale_orders()` every minute; timeout is `settings.orders.confirmation_timeout_minutes` (default 7)

---

## Courier / Delivery Flow

1. Order enters `preparing` status
2. `auto_dispatch_courier` DB trigger fires → calls `courier-dispatch` edge function
3. Edge function reads org's `courier_credentials` for `uber_direct` (or configured provider)
4. Dispatches to courier API; writes back `courier_delivery_id`, `courier_tracking_url`, `courier_status`, `courier_driver_*`, `courier_fee_cents`, `courier_dispatched_at` to the order row
5. Orders.tsx shows courier status badge and tracking link in real time

---

## SMS / Email Sending Flow

Both follow the same pattern:

1. Owner creates campaign in SMSCampaigns.tsx / EmailCampaigns.tsx
2. "Send now" → `supabase.functions.invoke("sms-send"` / `"email-send"`, `{ body: { campaign_id } })`
3. Edge function: loads campaign + org, builds recipient list by audience filter, checks monthly cap + top-up credits, calls Clicksend / Resend batch API, inserts log rows, increments `*_used_this_month`, updates campaign status
4. Webhook (sms-webhook / email-webhook): updates delivery status, handles opt-out, auto-opts-out on bounce/complained

---

## Pricing & Giving Model

**Subscriptions** (50% to charity, 50% to Woahh):
- Solo: $49/month — 1 location
- Marketplace: $89/month — up to 3 locations
- Growth: $150/month — up to 7 locations
- Enterprise: custom — unlimited locations

**Commission per order** — **LOCKED financial model (2026-06-02)**, split half charity / half Woahh:
- **Online orders:** 3% merchant fee + 1% customer service fee = **4% gross → 2% charity, 2% Woahh**
- **In-person orders (dine-in, counter, POS):** lower merchant fee, no customer-facing service fee (merchant absorbs); same half-charity/half-Woahh split. (Exact in-person % per the locked model — see `docs/BUSINESS_STRATEGY` / the financial-model note; don't invent.)

The customer service fee is collected via `application_fee_amount` on online Stripe charges only. **⚠️ The earlier 4%+2%=6% → 3%/3% numbers are DEAD** — superseded by the locked 3%+1%=4% → 2%/2% model.

**Stripe Connect model (phased):**
- **Founding merchants:** Connect Express, `application_fee_amount: 0` — zero commission, pass-through, works at launch
- **All paying merchants:** Connect Custom — Woahh holds funds, T+1/T+2 payout delay for disputes, full charity allocation control; operates under Stripe AU AFSL (written confirmation required before go-live with Custom)

**Other giving sources:**
- **Voluntary rate**: merchant can increase their giving rate above the floor via the Donate dashboard (slider)
- **One-time donations**: available in Donate dashboard
- **Promotion share**: sponsored listing fee split between charity and platform
- All donations recorded in `donation_ledger` (public RLS — anyone can read for transparency)
- Public `/impact` page shows totals, leaderboard, by-cause breakdown
- **Founding merchants (first 20–25)**: zero commission permanently; still pay subscriptions

---

## Environment Variables Required

```
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
VITE_SUPABASE_PROJECT_ID
VITE_STRIPE_PUBLISHABLE_KEY
# Server-side (Edge Functions secrets, not in repo):
SUPABASE_SERVICE_ROLE_KEY
CLICKSEND_USERNAME
CLICKSEND_API_KEY
RESEND_API_KEY
APP_URL                    # Used by email-send for unsubscribe links
```

---

## Working Conventions

- **App code** lives in `/workspaces/GrowthHub/repo` (+ feature **worktrees**: `repo-pay`, `repo-audit`, `repo-ai`, `repo-sms`, …) — GitHub `devsup76/business-growth-hub`. **Planning docs** (this file, todos, strategy) live one level up in `/workspaces/GrowthHub/` — GitHub `devsup76/hub-files`.
- **Edit code directly + push to `main`** → Cloudflare rebuilds prod from `main`; a branch push = a Cloudflare *preview*. `git pull`/`git fetch` before reviewing.
- All DB changes go through Supabase migrations; the **owner runs them in the Supabase SQL editor** (no GitOps auto-apply). Edge functions deploy via `npx supabase functions deploy`.
- Cloudflare Pages **supports `public/_headers` + `_redirects`** (we use `_headers` for CSP) — the old "Lovable can't do edge redirects, use pre-mount JS" constraint no longer applies (the legacy `business.woahh.app` pre-mount redirect in `main.tsx` stays for back-compat).
- Tier gating: email/promote = `solo`; CRM/SMS/loyalty = `marketplace`; donate = no gate.
- Update this file whenever a feature moves from "in progress" to "complete", or a key decision is made.

---

## Supabase gotchas (learned the hard way)

These are non-obvious behaviors that have caused real bugs. Future debugging should consider them first.

### 1. `handle_new_user_org` fires for staff users → phantom orgs

The `auth.users` insert trigger creates an org owned by the new user. The `staff-manage` edge function uses `admin.auth.admin.createUser()` for staff accounts, which **also** fires the trigger — leaving every staff member as the owner of a useless empty "phantom" org in addition to being a member of the real one.

**Symptom:** Staff session's `orgApi.getMine()` errors with `"JSON object requested, multiple (or no) rows returned"` because `.maybeSingle()` sees both the phantom + real orgs via RLS. Dashboard hangs with no `orgId`. Manager opens `/business/dashboard/menu` and sees an empty page.

**Fix (migration `20260529040000`):** trigger now skips when `raw_user_meta_data.kind = 'staff'`. Existing phantom orgs deleted by criteria (owner has `kind=staff` AND no products/orders/customers). Defensive client-side: `orgApi.getMine` now uses `my_org_id()` RPC + `.eq("id", ...)` instead of unfiltered `.maybeSingle()`.

### 2. `auth.users` JOINs in SECURITY DEFINER functions can return NULL in RLS contexts

A SECURITY DEFINER function that joins `auth.users` may return NULL when called from an RLS WITH CHECK clause on Lovable's Supabase, even though the same function works fine when called directly from the client. Caused a cascading failure across many tables when `current_org_id()` was rewritten to JOIN `auth.users`.

**Rule:** keep `current_org_id()` and similar RLS-helper functions free of `auth.users` joins. Use direct EXISTS subqueries against `organizations` and `staff_accounts` instead.

**Fix (migration `20260529050000`):** reverted `current_org_id()` to the simpler priority-ordered version without the JOIN. Products policy rewritten to check ownership and staff membership directly via EXISTS, no `current_org_id()` dependency.

### 3. Realtime auth context

Supabase Realtime channels bind to the auth context at `.subscribe()` time. If a hook subscribes before `supabase.auth.setSession()` (common during PIN sign-in race), the channel runs with anon JWT and RLS silently drops every event. The fix is to depend on `user.id` in the hook's effect deps so it re-subscribes after auth lands. See `src/hooks/useProductsRealtime.ts`.

### 4. Always pair realtime with a polling fallback

Realtime is a best-effort delivery layer. For "industry-grade live updates", combine `postgres_changes` with a 30-second polling fallback (`refetchInterval` or a `setInterval(invalidate)`). Linear and Vercel do this. The polling makes the UI heal within 30s regardless of realtime state.

---

## Test Merchant (seeded for end-to-end testing)

```
Email:     pawitsingh23+merchant@gmail.com
Password:  WoahhTest2026!
Org slug:  test-bistro
Tier:      marketplace
User ID:   11111111-1111-1111-1111-111111111111
```

Seeded by migration `20260528052109_9ab8f77c-...sql`. Three test customers (`+customer1/2/3@gmail.com`) with `email_consent_at` set so campaigns include them.

Owner email is `pawitsingh23@gmail.com` (Gmail + alias trick — every test email lands in the same inbox). Production user email throughout.

**Cleanup:**
```sql
DELETE FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111';
```

---

## Outstanding TODOs

See `/workspaces/GrowthHub/docs/WOAHH_FIXES_TODO.md` for the current punch list.

Top items as of 2026-05-28:
- **`-1.2` Founding-merchant sign-up code gating** — not started. Hidden admin page + `founding_access_codes` table + redeem RPC.
- **`1.2` Replace email-confirmation popup with dedicated page** — small UX win, not started.
- **`2.1` Invite-to-consent customer flow** — replace manual Add Customer. Spam-Act compliance requirement before scale.
- **`2.3` Notify customer on removal** — privacy hygiene.
- **`3.1` Hard separation of merchant vs customer auth identities** — partly delivered via the routing pivot (`/signin` is customer-only). Hard separation in DB still pending.
- **`3.2` "View as customer" sidebar button** — UX polish.

**Per-merchant SMS — merge + productionise** — see `/workspaces/GrowthHub/docs/SMS_ARCHITECTURE.md`. Audit-fixed, deployed, and **verified end-to-end on the new backend (send + STOP/opt-out)** on 2026-05-31. Remaining: merge `feat/per-merchant-sms` → `main`; for production, buy a dedicated ClickSend number per real merchant (+ a shared OTP number) and assign via the AdminSmsNumbers page (now routed at `/business/dashboard/admin/sms`); add `.github/workflows/supabase-deploy.yml` to the remote (needs a `workflow`-scoped PAT) to enable GitOps auto-deploy. Consider Cellcast (~½ the per-SMS cost) at volume — drop-in via the `SMS_PROVIDER` flag.

**POS & in-person payments** — see `/workspaces/GrowthHub/docs/POS_TERMINAL_PLAN.md`. Stripe Terminal (smart reader S700/WisePOS E from the web app, Phase 1) + Tap to Pay via a React Native merchant app (Phase 2). Preserves the in-person 4% → 2%/2% charity split via `application_fee_amount`. Long-lead blockers: Apple Tap to Pay entitlement + Stripe AFSL written confirmation for Connect Custom.

**Franchise / multi-location** — see `/workspaces/GrowthHub/docs/FRANCHISE_ARCHITECTURE.md` (todo `6.5`). Designed + approved 2026-06-02, **not built yet** (build later, post-onboarding). Strictly **additive**: a franchise layer *above* organizations (each location stays its own org); cross-org access via a `franchise_members` membership overlay (so `organizations.owner_id`/`staff_accounts.user_id` UNIQUE are NOT relaxed); nullable `organizations.franchise_id` (NULL = standalone, unaffected); additive grant-only RLS via `franchise_org_ids()`; reuses `growthhub_profiles`/`merchant_connections` for configurable shared loyalty + franchise-wide campaigns. 10 additive stages. Only non-additive item: a `kind='franchise'` skip branch in `handle_new_user_org()`.

**Storefront platform — finish + ship (todo `6.6`, branch `feat/storefront-platform`)** — SCAFFOLDED 2026-06-07, **not merged/deployed**. See the **Storefront Platform** section under Hosting & Domain Architecture for the full scaffolded-vs-pending breakdown. Three additive pillars (per-merchant `<slug>.woahh.app` subdomains; config-driven storefront UI via `storefront_config` + `StorefrontRenderer`; per-merchant dynamic-manifest PWA → Capacitor native later), all riding the existing `subdomain_slug` + `get_public_storefront` RPC so isolation + apex are unchanged. **Remaining to ship:** (1) human/infra — wildcard `*.woahh.app` CNAME → Cloudflare Pages project + add `*.woahh.app` as a Pages custom domain + wildcard TLS (one level only; single-label slugs enforced by regex); (2) wire `StorefrontRenderer` + `get_public_storefront_config` into the storefront render path (default config reproduces today's layout so unconfigured merchants are unchanged) + apply migration `20260603010000` to live (`pmnyhbhtkcfoozkinieo`) + regen `types.ts`; (3) **design N premium, state-of-the-art ready-made templates** + a simple **template-picker** dashboard page (merchant selects a template + basic branding/logo/colors/copy; **NOT a section builder** — founder decision 2026-06-07; route + sidebar link; solo tier-gate); (4) PWA polish — per-merchant 192/512 maskable icons; (5) native — Capacitor per-merchant build pipeline (Growth/Enterprise, outline only); (6) optional slug-change rate-limit/alias + a reserved-list parity test (`tenant.ts` ↔ SQL). *(DONE in `60b7831`: reserved-slug DB guard, apex-only route guard, CSP manifest fix, config bounds, tenant tests.)* Positioning in `docs/POSITIONING_STOREFRONT.md` (frame as better-than-Bopple/Shopline/Shopify for small AU merchants).

**New TODOs added 2026-06-02** (see `WOAHH_FIXES_TODO.md`): `6.1` make delivery temporarily unavailable behind a feature flag (needs funding+code; keep courier code dormant); `6.2` founding launch promo — free subscription (1yr/lifetime OPEN) + temporary zero commission for first N sign-ups (reconcile with existing founding terms); `6.3` UI uplift (scope TBD); `6.4` restrict customer/CRM details to owner+manager only — drop the `"Staff view customers"` RLS policy (client already gates it; check `current_org_id()` doesn't still cover staff); `6.5` franchise (above).

**SHIPPED to `main` 2026-06-02 (app repo `devsup76/business-growth-hub`; live on woahh.app via Cloudflare):** Marketing-landing v2 redesign — `src/pages/Storefront.tsx` now leads with the full real feature set, an AI section (menu import described as a chatbot), the founding-merchant offer (0% commission + free subscription), a 16-row competitor comparison table (incl. online/QR ordering, KDS, reservations, in-store loyalty; delivery/install-app/tap-to-pay shown as "Soon"), and an FAQ; removed prior overclaims (delivery + native apps now "on the way"); email marketing = live, SMS marketing = "shipping very shortly". **SEO/AI discoverability:** `index.html` JSON-LD (Organization + SoftwareApplication w/ pricing Offers + FAQPage), `public/llms.txt`, richer meta + canonical, `sitemap.xml`. **App-wide green/gold theme + dark mode:** `src/index.css` semantic tokens remapped to brand forest-green primary + gold accents (was ink-black/indigo), `next-themes` `ThemeProvider` + `ThemeToggle` in the dashboard header; **buttons are green + white text, gold kept as accents** (rings/highlights/badges/"Soon" pills) — the main marketing page keeps its fixed `brand-*` gold palette. **Merchant branding consistent on customer surfaces:** `useStorefrontSettings(org)` now applied on RetailStorefront (+logo), OrderStatus, ReservationBooking (was storefront-only); `marketplaceApi.getById` returns `settings`. This substantially advances `6.3` (UI uplift) and surfaces `6.1`/`6.2` on the landing (backend enforcement still per those TODOs). Open polish: founding-offer **duration** wording; a real 1200×630 `og-image.png` (og:image currently → `/icon-512.png`).

**Pitch & positioning materials** — `docs/pitch/RESTAURANT_PITCH.md` (merchant sign-up pitch: numbers, full daily loop, hardware/tablet+terminal story), `docs/pitch/VC_PITCH_DECK.md` (15-slide investor deck + speaker notes), `docs/pitch/POSITIONING_BRIEF.md` (feature inventory + differentiators + roadmap). Open before sending: founding-offer terms (6.2), hardware lease-vs-included (BUSINESS_STRATEGY §12), and reconcile charity-% + Growth-price conflicts flagged in the deck.

**Planning/docs repo remote** — this repo (`/workspaces/GrowthHub`, the docs/CLAUDE.md repo, distinct from the Lovable `repo/`) is now GitHub **`devsup76/hub-files`** (was `Pawit12-spec/hub-files`; that account's PAT is revoked/401). Push needs a current **devsup76** PAT.
