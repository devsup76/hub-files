# CLAUDE.md — woahh Failsafe Context

> **SCOPE GUARD:** Only load and apply this context if the current conversation is about building, reviewing, or improving the woahh app. If the user has opened this session for an unrelated purpose (e.g. a quick question, a different project, general help), skip this file entirely and do not reference it — do not waste tokens on irrelevant context.

> This file is the single source of truth for woahh development sessions.
> Update it whenever a feature is completed, a key decision is made, or significant progress occurs.
> Last updated: 2026-05-29

---

## Lovable Prompt Constraints

- **5000 character limit per prompt** — always split large changes into multiple prompts
- Split by logical unit: one large file = one prompt; small wiring changes (route + sidebar link) can be grouped
- Never bundle a large component + edge function + migration into one prompt
- When in doubt, split further — a truncated prompt silently breaks the implementation

---

## What This App Is

**Woahh** is a multi-tenant SaaS platform for small business owners (restaurants + retail shops).

> **Brand casing rule:** UI / frontend = `Woahh` (capital W). Backend code, edge functions, email addresses, query keys, SMS bodies = `woahh` (lowercase).
It is built and hosted on **Lovable** (AI app builder). The repo in this container is **read-only for review and planning** — all actual edits are made in Lovable.

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

**Why single origin (and not the previous subdomain split):** Lovable's hosting does not support `public/_redirects`, `vercel.json`, or any edge-level redirect config. The subdomain split caused cross-origin localStorage issues for sessions, password reset flows, and magic links (`woahh.app` ↔ `business.woahh.app` are separate origins; localStorage doesn't share). Single origin makes all of these work first try.

**URL helpers** (`src/lib/hostUrls.ts`):
- `apexUrl(path)` → same-origin path (returns the path as-is)
- `businessUrl(path)` → `/business/<path>` (e.g. `businessUrl("/auth")` → `/business/auth`)
- Both are kept for readability and so we can flip back to a real subdomain later if needed.

**`docs/CROSS_DOMAIN_REDIRECTS.md` (in `repo/`)** documents the current architecture and includes Cloudflare edge rules to paste if you ever want true zero-flicker on the legacy subdomain.

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
| Payments | Stripe (env var exists, billing not yet integrated) |
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
  migrations/                         # All DB migrations (41 total as of last update)
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
| Stripe / billing | ❌ Not started | Env var only — no subscription management UI |
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

**Commission per order** (half each to charity and Woahh):
- **Online orders:** 4% merchant fee + 2% customer service fee → 3% charity, 3% Woahh
- **In-person orders (dine-in, counter, POS):** 4% merchant fee only → 2% charity, 2% Woahh; no customer-facing service fee shown; merchant absorbs the commission

The 2% customer service fee is collected via `application_fee_amount` on online Stripe charges only. In-person terminal charges use a reduced `application_fee_amount` (4% only).

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

- Repo is on **Lovable** — we review/plan here, implement there
- Local code lives in `/workspaces/GrowthHub/repo/` (Lovable-managed git repo)
- Planning docs (this file, todos, strategy) live one level up in `/workspaces/GrowthHub/`
- All DB changes go through Supabase migrations (never manual edits)
- Tier gating: email/promote = `solo`; CRM/SMS/loyalty = `marketplace`; donate = no gate
- Do not add Stripe billing until explicitly scoped
- Always `git pull` in the `repo/` subfolder before reviewing — Lovable pushes directly to the remote
- Update this file whenever a feature moves from "in progress" to "complete"
- Local edits + push from the repo subfolder IS a valid workflow when Lovable's prompt-based UX would be slow; Lovable's CI picks up the commits automatically
- Lovable's hosting has no edge-redirect / `_redirects` / `vercel.json` support — pre-mount JS redirects are the only option for cross-domain logic

---

## Supabase + Lovable gotchas (learned the hard way)

These are non-obvious Lovable-specific behaviors that have caused real bugs. Future debugging should consider them first.

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
