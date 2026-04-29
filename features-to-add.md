# woahh — Feature Tracker

> Organised by status: what's done, what's core, and what's optional.
> Legal & compliance operational tasks are tracked in [`non-dev-implementations.md`](./non-dev-implementations.md).
> Sprint plan and phase timelines are in [`docs/business/MASTER_PLAN.md`](./docs/business/MASTER_PLAN.md).
> Last updated: 2026-04-29

---

## ✅ Completed

Everything below is fully built and live.

### Platform & Infrastructure
- Multi-tenant architecture — full RLS isolation per organisation
- Subscription tier system — free_trial → solo → marketplace → growth → enterprise; `apply_tier_caps()` trigger, top-up credits
- Owner auth (Supabase), customer auth (magic link + username lookup)
- Staff accounts — manager / service / kitchen roles; synthetic email auth; 6-digit PIN only; `staff-manage` + `staff-pin-login` edge functions; 5-attempt lockout + 15-min cooldown; constant-time comparison; role-based sidebar + route guards; session ban on deactivate
- Merchant onboarding & compliance — business type, legal entity type, owner full name, phone OTP (Clicksend), ABN checksum + uniqueness, business address, ToS acceptance timestamp + version, Spam Act acknowledgement; `owner-verify` edge function; `OnboardingChecklist` component (5-step)
- Demo mode — full in-memory DemoStore, seeded Bella's Bistro, complete feature coverage

### Orders & Kitchen
- Order management — kanban, real-time, confirmation flow (awaiting_confirmation → pending / declined), auto-decline cron
- Kitchen Display System (KDS) — full-width fulfillment colour bar, status strip, elapsed timer, pool + kanban modes
- KDS keyboard shortcuts — owner-customisable via KitchenSettings KeyCapture UI; deep-merged into settings
- Order confirmation flow — owner confirm / decline with reason; `order-respond` edge function; customer notified on decline
- Courier / delivery — Uber Direct, DoorDash Drive, Sherpa, Lalamove; `courier-dispatch` edge function; auto-dispatch on `preparing`; tracking columns on orders

### Products & Menu
- Product / menu catalog — CRUD, extras JSONB, stock, sale windows, images, tags, ingredients
- Menu categories — LTO windows, category-level discount
- Combos — bundle products at fixed price, sale windows, `combo_items` junction

### Customers & Marketing
- Customer CRM — list, manage, dietary prefs, saved addresses, birthday, opt-in tracking (marketplace tier+)
- Loyalty rewards — points + milestone, birthday rewards, in-person rotating 6-digit codes; `loyalty_code_sessions` table + upsert/validate RPCs (marketplace tier+)
- SMS campaigns — full UI, Clicksend batch API, delivery tracking, opt-out, top-up credits; scheduled sends with timezone label (marketplace tier+)
- Email campaigns — full UI, Resend batch API, open/click tracking, unsubscribe, top-up credits; scheduled sends (solo tier+)
- Promo codes — CRUD, usage limits, expiry
- Unified customer identity — `woahh_profiles` + `merchant_connections`; merge by email + phone on sign-in; cross-merchant Account hub (My Merchants, Orders, Notifications tabs); GH badge in owner CRM

### Storefront & Marketplace
- Public storefront — restaurant + retail variants; branded, customer-facing
- `/eat` Marketplace — discovery, cuisine filter, ratings, Impact badge, `Marketplace.tsx` + `MarketplaceProfile.tsx`
- Sponsored listings — `Promote.tsx`; `promotions` table; charity / platform fee split (solo tier+)
- Reviews — customer reviews; aggregate rating trigger on `organizations`
- Customer portal — rewards, order history, profile, cross-merchant account hub

### Tables & Reservations
- Dine-in table management — zones, bulk add, QR codes; `dine_in` + `table_number` on orders
- Reservations — public booking widget (`/book/:slug`), cancellation (`/cancel-reservation/:token`), waitlist, deposit config, 24h + 2h reminder cron; `reservation-confirm` + `reservation-remind` edge functions; timezone selector in Operations

### Operations & Settings
- Operations dashboard — hours, fulfillment settings, courier credentials, Business Details (ABN, address, phone)
- KitchenSettings — courier config, KDS preferences, keyboard shortcut editor
- Branding — logo upload, HSL colour tokens, font pairs
- Analytics dashboard — 7 togglable widgets (revenue, fulfillment mix, top products, peak hours, new/returning customers, categories, marketing); 90-day synthetic demo history; date range tabs; widget customisation via localStorage

### Giving & Impact
- Donation model — GMV 0.15% to charity, voluntary rate slider, one-time donations, subscription fixed amounts, promotion share; `donation_ledger` table
- Public `/impact` dashboard — totals, leaderboard, by-cause chart; `DonationBadge` component
- Donate dashboard — voluntary giving rate, one-time donations (all tiers)

### Launch Readiness (Prompts 1–6)
- Brand rename — Woahh throughout UI; woahh in backend/code
- Error boundary — class component, `getDerivedStateFromError`, `componentDidCatch`, reset + reload; `app-loading` spinner removed on mount
- Legal pages — `/privacy` + `/terms` public routes; Australian Privacy Act 1988 + QLD jurisdiction; footer links in Storefront + Marketplace
- `robots.txt` — `Disallow: /dashboard/`, `Disallow: /auth`
- Dynamic SEO meta — `lib/seo.ts` `updateMeta()` helper; called on Marketplace, MarketplaceProfile, Impact, Account, Shop, Privacy, Terms
- Code splitting — all 20 dashboard routes `React.lazy` + `Suspense`; themed fallback spinner
- PWA `manifest.json` — name, icons, display standalone, theme colour
- `sitemap.xml` — all public routes with priorities

---

## 🔲 Core Functionality — To Build

Features that are essential to the business working properly. Build these before or immediately after the soft launch.

---

### CRITICAL — Before First Paying Merchant

#### Stripe Billing & Subscription Management
**Why:** This is how Woahh makes money. Without it, no merchant can be charged.

**What to build:**
- Stripe Connect Express onboarding for merchants — `stripe_account_id` stored on `organizations`
- Platform fee split: 0.15% to Woahh on every order via `transfer_data` + `application_fee_amount`
- Subscription creation flow — Stripe Checkout session or embedded Elements for Solo / Marketplace / Growth / Enterprise; monthly + annual toggle
- Pricing page inside the dashboard
- Webhook handler edge function — `customer.subscription.updated`, `invoice.payment_failed`, `customer.subscription.deleted` → sync `organizations.tier`
- Billing portal link (Stripe Customer Portal) — update card, download invoices, cancel
- Grace period: payment failure → set `billing_status = 'grace'` flag, 3-day window before feature lock
- `stripe_customer_id` + `stripe_subscription_id` columns on `organizations` (migration)

**Watch out for:**
- Stripe webhook signature verification is mandatory — `stripe.webhooks.constructEvent` with endpoint secret
- Idempotency — Stripe replays webhooks; make upserts idempotent
- `free_trial` tier has `trial_ends_at` — decide downgrade behaviour before building (downgrade to free or prompt upgrade)
- Platform fee must be disclosed to merchants in Terms of Service

---

### Phase 1 — First 4 Months Post-Launch

#### Customer-Facing Order Notifications
**Why:** Customers need to know their order status without refreshing the page.

**What to build:**
- Email: extend `email-send` edge function with `type: 'order_status'` — transactional template for confirmed, preparing, ready, declined
- SMS: extend `sms-send` similarly for opted-in customers
- Web push: service worker on `/order/:id`, VAPID keys, `push_subscriptions` table, `web-push` in edge function

**Watch out for:**
- Always check `customers.sms_opt_out` and `customers.email_opt_out` before sending
- Order status messages are transactional — do not require marketing consent

---

#### Retail / Shop Features
**Why:** The second major vertical. Gives physical retail the same tools restaurants have.

**What to build:**
- Retail-mode storefront — product grid, category browse, add to cart, checkout (pickup / in-store / shipping)
- Inventory management UI — stock levels, low-stock alerts, restock actions
- Retail-specific POS flow — barcode/SKU lookup (see below), walk-in sales
- Shipping fulfillment type — address collection at checkout, postage label generation (optional Phase 2)
- `business_type = 'retail'` already exists — wire conditional UI paths

---

#### Appointment Booking
**Why:** Core Phase 1 vertical — salons, gyms, healthcare, all service businesses.

**What to build:**
- `services` table: `id, org_id, name, duration_minutes, price, buffer_minutes, category`
- `staff_schedules` table: `org_id, staff_id, day_of_week, start_time, end_time`
- `appointments` table: `id, org_id, service_id, staff_id, customer_id, start_at, end_at, status, notes, cancellation_token`
- Public booking widget at `/book/:slug` (extend existing ReservationBooking) — service picker, staff picker, calendar, time slots
- Owner dashboard: Appointments page — day/week view, confirm/cancel, block time
- Customer notifications: confirmation email + SMS, 24h reminder
- Cancellation flow via token link (extend existing reservation pattern)

---

#### Inventory Alerts & Low-Stock Management
**Why:** Essential for retail; also useful for restaurants tracking ingredients or bottled items.

**What to build:**
- `low_stock_threshold` integer column on `products` (migration, nullable)
- DB trigger: when order placed, decrement `products.stock` for each line item (skip declined orders)
- When `stock <= low_stock_threshold`: insert into `notifications` table, email org owner via `email-send`
- Menu page: amber low-stock badge, red out-of-stock badge on product cards
- Quick-restock button on product card

**Watch out for:**
- Atomic stock decrement: `UPDATE products SET stock = stock - qty WHERE id = ? AND stock >= qty` — prevents overselling under concurrent load
- Never decrement for `status = 'declined'` orders

---

#### Table QR Code Ordering (Dine-in Self-Service)
**Why:** Customers scan their table QR, browse the menu, and order from their phone — no staff needed.

**What to build:**
- Public route `/table/:orgSlug/:tableNumber` — loads storefront in dine-in mode, pre-fills `table_number` + `dine_in: true` at checkout
- Validate `table_number` against the org's actual `tables` table — prevent URL manipulation
- Orders enter normal queue; KDS and kanban already show `table_number`
- "Pay at table" option: Stripe Payment Link shown when order status reaches `ready`

---

#### Cookie Consent Banner
**Why:** Australian Privacy Act 1988 + best practice for any site running analytics.

**What to build:**
- Banner on first visit to all public pages (Storefront, Marketplace, Shop, `/eat`) — not inside the dashboard
- Three categories: Strictly Necessary / Analytics / Marketing
- Consent stored in `localStorage` under a versioned key — re-prompts on version bump
- Only load analytics scripts after analytics consent granted
- "Manage Cookies" link in footer reopens the preference panel

---

#### GDPR / Privacy Rights Flows
**Why:** Australian Privacy Act + future GDPR compliance for UK/EU expansion.

**What to build:**
- "Download my data" in customer Account — exports profile, orders, loyalty, consent history as JSON
- "Delete my account" — anonymises PII on customer record; retains order rows with `customer_id = null` for financial records
- `privacy_requests` audit table — logs all access and erasure requests with timestamps
- Merchant-side: owner can download a customer's data in response to a subject access request

---

#### Business Address in Email Footers
**Why:** Spam Act 2003 requires a physical address in every commercial email.

**What to build:**
- `email-send` edge function: inject `org.business_address` into the footer of every outgoing campaign email
- Format: street, suburb, state, postcode, country on one line
- `business_address` JSONB already exists on `organizations` and is collected via onboarding

---

#### ABN + GST Line on POS Receipts
**Why:** Tax invoice compliance — any receipt over $75 requires ABN and GST breakdown.

**What to build:**
- POS receipt view: display `org.abn` in the header
- GST line: `GST included: $${(total / 11).toFixed(2)}` in the receipt totals
- Marketplace profile: display ABN in the merchant info section

**ABN validation + storage is already built** — this is purely the display layer.

---

#### Age Verification (Alcohol / Restricted Items)
**Why:** Required before any merchant can sell alcohol through the platform.

**What to build:**
- `requires_age_verification boolean` column on `products` (migration)
- At checkout in `Shop.tsx`: if any cart item has the flag, show a self-declaration modal ("I confirm I am 18 or over") before proceeding
- POS: prompt staff to check ID on the payment screen when restricted items are in the order

---

#### ToS Version Re-gate
**Why:** When Terms of Service are updated, existing merchants must accept the new version.

**What to build:**
- Store current ToS version string as a constant (e.g. `"2026-04-29"`)
- In `DashboardLayout`: if `org.tos_version !== CURRENT_TOS_VERSION`, show a full-screen re-acceptance gate before allowing dashboard access
- On acceptance: update `tos_accepted_at` + `tos_version` on the org

---

## 💡 Optional Features — Future Phases

Add these after the core product is stable. Most are Phase 2+ or post-Series A.

---

### POS Enhancements

#### Split Tender
- In `WalkInOrderDialog.tsx`, allow up to 2 payment splits (e.g. $20 cash + remainder on card)
- Second split auto-calculates as `total - split1`; cash change only on the cash portion

#### POS Order History & Receipts
- "Recent" tab in POS showing last 10 walk-in orders for the day
- Re-print receipt from past order
- `source` column on orders: `online | pos | phone` for cleaner filtering

#### Barcode / SKU Lookup (Retail POS)
- `sku` column on `products` (migration, unique per org)
- Barcode input in `WalkInOrderDialog.tsx` — scan or type to add to cart
- USB scanner support (keyboard emulation + Enter trigger)
- Optional: `@zxing/browser` for camera-based scanning on tablet

#### Waitlist Management (Walk-in Tables)
- When tables are full, host adds walk-in party to queue: name, party size, phone, estimated wait
- `waitlist_entries` table; SMS notification when table is ready
- "Seat now" action links to first available table

---

### Payment Enhancements

#### Stripe Terminal (In-Person Card Payments)
- `@stripe/terminal-js` in POS dialog — "Card" activates a physical reader
- `terminal-intent` edge function creates PaymentIntent; reader processes it
- `terminal_reader_id` stored on org in Operations > POS Settings

#### Apple Pay & Google Pay
- Stripe Payment Request Button — auto-detects Apple Pay / Google Pay on device
- Requires HTTPS + verified domain (Stripe domain verification file)
- Always keep standard card form as fallback

---

### Integrations

#### Accounting Export (Xero / QuickBooks)
- OAuth2 connect in Operations > Integrations
- Push completed orders as invoices; daily Z-report as journal entry
- `xero_tenant_id` / tokens stored encrypted on org
- Track `xero_invoice_id` on orders to prevent duplicate sync

#### Google Maps + Delivery Radius Validation
- Google Maps embed on storefront and marketplace profile (lat/lng already stored)
- Distance Matrix API validates customer address against `delivery_radius_km` at checkout
- Estimated delivery time shown at checkout

#### Delivery Aggregator Sync (Uber Eats / DoorDash)
- Pull orders from Uber Eats and DoorDash into the Woahh kanban
- Map to `orders` schema; tag with `source: 'uber_eats'` or `source: 'doordash'`
- Push Woahh menu updates to aggregator menus
- Note: requires formal merchant partnership / developer programme with both platforms

#### Review Aggregation (Google, TripAdvisor)
- Pull Google Business Profile reviews via My Business API; display alongside Woahh native reviews
- Optional auto-respond using configurable templates
- TripAdvisor read-only reviews for restaurant orgs
- Sentiment tagging for Analytics dashboard

---

### Customer Experience

#### Advanced Analytics
- Cohort retention chart — customer re-order rates by first-order month
- Customer lifetime value (CLV) by acquisition channel
- Menu profitability — sort by margin if cost price added to products
- Promotion ROI — orders per promo code, average order value with/without code
- 7-day revenue forecast using linear trend
- Use Postgres materialized views refreshed nightly — not on-demand queries

#### Loyalty Card / NFC Tap
- Physical loyalty cards with QR or NFC chip encoding customer `woahh_profile` ID
- QR: links to `/account?merchant=slug` where in-store code is auto-displayed
- NFC: Web NFC API (Chrome Android only) — always offer QR as fallback
- PDF export of printable cards per customer from CRM

---

### Native Apps (Expo)

#### Merchant App (iOS + Android)
- React Native via Expo, same Supabase backend
- Supabase Realtime for live order alerts — audio alert when new order arrives
- No push notifications needed — app stays open on the merchant's device
- Core screens: Orders, KDS, Menu quick-edit

#### Customer App (iOS + Android)
- React Native via Expo
- Push notifications via Expo Push API — order status updates, loyalty rewards, campaigns
- `push_tokens` table on Supabase per customer per device
- Core screens: Browse marketplace, order, track, account/rewards

---
