# GrowthHub — Features To Add

> Priority order: **App Functionality → 3rd Party Integrations**
> Legal & Compliance items (Privacy Policy, ToS, GDPR flows, PCI, GST, Age Verification, etc.) have been moved to [`non-dev-implementations.md`](./non-dev-implementations.md) — resolve those operationally/legally first, then wire them into the app via the dev tasks below.
> Each entry includes what to build, why it matters, and what to watch out for.
> Update status as work progresses.

---

## Status Key
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete

---

## 1. App Functionality

### 1.1 Stripe Billing & Subscription Management
**Status:** `[ ]`

**What to build:**
- Subscription creation flow when a merchant signs up or upgrades: Stripe Checkout session or embedded Stripe Elements form
- Pricing page inside the dashboard showing Solo / Marketplace / Growth / Enterprise plans with monthly/annual toggle
- Webhook handler (edge function) to receive `customer.subscription.updated`, `invoice.payment_failed`, `customer.subscription.deleted` events and sync `organizations.tier` accordingly
- Billing portal link (Stripe Customer Portal) so merchants can update card, download invoices, cancel
- Grace period handling: when payment fails, set a `billing_status` flag rather than immediately downgrading — give a 3-day window before locking features
- `apply_tier_caps()` trigger already exists and will fire automatically when tier changes

**Watch out for:**
- Stripe webhook signature verification is mandatory — use `stripe.webhooks.constructEvent` with the endpoint secret
- Idempotency: Stripe can replay webhooks; make upserts idempotent using `organizations.stripe_customer_id` and `stripe_subscription_id` columns (add via migration)
- Trial period: `free_trial` tier already has `trial_ends_at`; when it expires, downgrade to `free` or prompt upgrade — decide the downgrade behavior before building

---

### 1.2 Scheduled SMS & Email Sends
**Status:** `[x]`

**What to build:**
- "Schedule for later" option in SMSCampaigns.tsx and EmailCampaigns.tsx — a date/time picker alongside the existing "Send now" button
- Store `scheduled_for timestamptz` on `sms_campaigns` / `email_campaigns` rows when scheduling
- A pg_cron job (or Supabase scheduled function) that runs every minute, queries campaigns where `status = 'scheduled' AND scheduled_for <= now()`, and calls the existing `sms-send` / `email-send` edge functions with `{ campaign_id }`
- UI state: campaigns show "Scheduled for [date]" badge and a "Cancel schedule" button that nulls `scheduled_for` and reverts status to `draft`

**Watch out for:**
- Timezone display: always show the scheduled time in the org's local timezone (use `settings.reservations.timezone` already on the org) but store UTC in the DB
- Double-send guard: after the cron triggers a send, immediately set `status = 'sending'` before dispatching so a second cron tick doesn't fire a duplicate

---

### 1.3 Split Tender (POS)
**Status:** `[ ]`

**What to build:**
- In `WalkInOrderDialog.tsx`, replace the single payment method selector on the Pay step with a split-tender UI
- Allow up to 2 payment splits: e.g. "$20 Cash + remainder on Card"
- First split: user enters a partial amount + method; second split is auto-calculated as `total - split1`
- Show both splits on the receipt and in `completedOrder` state
- Store split detail in order `notes` or a new `payment_breakdown` JSONB field on orders (migration required if persisted)

**Watch out for:**
- The sum of splits must equal the total exactly — validate before allowing Confirm
- Cash change only applies to the cash portion, not the full total

---

### 1.4 Barcode / SKU Lookup (Retail POS)
**Status:** `[ ]`

**What to build:**
- Add a `sku` column to the `products` table (migration)
- In the Menu page for retail orgs, expose a SKU field in the product form
- In `WalkInOrderDialog.tsx`, add a barcode input at the top of the product grid — when a SKU is typed or scanned, match against `products.sku` and instantly add to cart
- Support USB barcode scanners (they emulate keyboard input followed by Enter) — listen for `keydown Enter` on the SKU field
- Optionally: integrate a camera-based scanner using the `@zxing/browser` library for tablet-based setups

**Watch out for:**
- SKU should be unique per org — add a `UNIQUE(org_id, sku)` constraint
- Scanners emit input very fast; debounce or use the Enter key as the trigger rather than `onChange`

---

### 1.5 Staff Accounts (Multi-user per Org)
**Status:** `[x]`

**Built:**
- `staff_accounts` table with manager / service / kitchen roles; username + display_name per org; `is_active` toggle
- `staff-manage` edge function (owner-only): create, reset_pin, set_active (bans/unbans JWT), update_role, reset_lockout, delete (revokes auth first)
- Synthetic email auth (`username@slug.staff.local`) — internal password auto-generated, never shown; staff log in via 6-digit PIN only
- `staff-pin-login` edge function: verifies SHA-256(pin:userId) hash, constant-time comparison, 5-attempt lockout + 15-min cooldown, `admin.auth.admin.createSession()`
- PIN keypad UI in Auth.tsx StaffForm (auto-submit on 6th digit); owner sets/resets PIN per staff member in Staff.tsx
- Role-based PERMISSIONS map; sidebar filters by role; `RouteGuard` component blocks direct URL access
- `DashboardLayout` route guard: kitchen → `/dashboard/kitchen`; segment-based guard redirects to first permitted route
- Inline role editing in Staff.tsx; session ban on deactivate for instant access revocation; 🔒 Locked badge + owner one-click unlock

---

### 1.6 Inventory Alerts & Low-Stock Management
**Status:** `[ ]`

**What to build:**
- `products` table already has a `stock` integer column
- Add `low_stock_threshold` integer column (migration, nullable — null = no alerts)
- When an order is placed and `line_items` reduce stock, a DB trigger decrements `stock` for each product
- When `stock <= low_stock_threshold`, trigger a notification: insert into a new `notifications` table, and optionally send an email to the org owner via the existing `email-send` edge function
- In the Menu page, show a low-stock badge (amber) and out-of-stock badge (red) on product cards
- Optional: "restock" quick-action button that increments stock by a configurable amount

**Watch out for:**
- Stock decrement should only fire for `status != 'declined'` orders — don't deduct stock for declined orders
- Race condition: two simultaneous orders could both read `stock = 1` and both succeed — use a Postgres `UPDATE products SET stock = stock - qty WHERE id = ? AND stock >= qty` atomic update with a check

---

### 1.7 POS Order History & Receipts
**Status:** `[ ]`

**What to build:**
- In the POS (`WalkInOrderDialog.tsx`), a "Recent" tab or button that shows the last 10 walk-in orders for the day
- Allows re-printing a receipt from a past order
- In Orders.tsx, a filter to show only walk-in / POS orders (identifiable by `initial_status = 'preparing'` + no online source)
- Consider adding a `source` column to orders: `online | pos | phone` — makes filtering and reporting cleaner

**Watch out for:**
- The receipt data (discount, tax, tip breakdown) isn't currently persisted on the order row — only `total_amount` is stored. To enable reprinting, either store a `receipt_data` JSONB column or reconstruct from `line_items`

---

### 1.8 Customer-Facing Order Notifications (Push / Email)
**Status:** `[ ]`

**What to build:**
- When an order status changes (confirmed, preparing, ready, declined), send a notification to the customer
- Email channel: extend the existing `email-send` edge function with a new `type: 'order_status'` path — use a simple transactional template
- SMS channel: extend `sms-send` similarly for customers who have opted in to SMS
- Web push: register a service worker on the `/order/:id` status page and send a push when status changes (requires VAPID keys, a `push_subscriptions` table, and a `web-push` npm package in an edge function)
- The `order-respond` edge function already handles decline notifications — generalise it

**Watch out for:**
- Respect `customers.sms_opt_out` and `customers.email_opt_out` flags — always check before sending
- Transactional vs marketing consent: order status messages are transactional and can be sent without marketing opt-in

---

### 1.9 Table QR Code Ordering (Dine-in Self-Service)
**Status:** `[ ]`

**What to build:**
- Each table already has a QR code (Tables.tsx) — wire it to a `/table/:orgSlug/:tableNumber` public route
- That route loads the storefront in dine-in mode, pre-filling `table_number` and `dine_in: true` on checkout
- Customer places order from their phone; it enters the normal order queue with `awaiting_confirmation` or `preparing` depending on org settings
- The kitchen display and Orders kanban already show `table_number` — no backend changes needed
- Add a "Pay at table" option: order is placed and a payment link (Stripe Payment Link or manual) is shown when the order is ready

**Watch out for:**
- Prevent customers from entering arbitrary table numbers via URL manipulation — validate `table_number` against the org's actual tables table

---

### 1.10 Waitlist Management (Walk-in Tables)
**Status:** `[ ]`

**What to build:**
- When all tables are occupied, allow a host to add a walk-in party to a waitlist queue: name, party size, phone, estimated wait
- Waitlist view in the Tables page: ordered queue with "Seat now" action that links to the first available table
- SMS notification when their table is ready (via existing `sms-send` edge function)
- New `waitlist_entries` table: `id, org_id, name, phone, party_size, notes, joined_at, notified_at, seated_at, status (waiting | notified | seated | left)`

**Watch out for:**
- SMS to non-customers (walkins who haven't opted in) — include opt-out language in the message and a short unsubscribe link as required by TCPA/Spam Act

---

### 1.11 Advanced Analytics — Deeper Insights
**Status:** `[ ]`

**What to build on top of the existing Analytics dashboard:**
- **Cohort retention chart:** group customers by first-order month, track what % re-ordered in subsequent months — standard SaaS retention grid
- **Customer lifetime value (CLV):** average revenue per customer segmented by acquisition channel (online vs walk-in vs marketplace)
- **Menu performance:** attach a profitability column (if cost price is added to products) — sort by margin, not just revenue
- **Promotion ROI:** link promo_codes usage to revenue — show orders per code, average order value with code vs without
- **Forecast widget:** simple 7-day revenue forecast using a linear trend on the last 30 days
- Extend the `getDemoHistory()` function to generate synthetic customer IDs that match demo CRM customers for retention chart accuracy

**Watch out for:**
- Cohort and CLV queries are expensive on large datasets — use Postgres materialized views refreshed nightly rather than on-demand queries

---

## 2. Third-Party Integrations

### 2.1 Stripe Terminal (In-Person Card Payments)
**Status:** `[ ]`

**What to build:**
- Integrate Stripe Terminal SDK (`@stripe/terminal-js`) into the POS dialog
- "Card" payment method in the Pay step activates a Terminal reader instead of just recording "paid by card"
- Backend: new edge function `terminal-intent` that creates a `PaymentIntent` and returns a client secret; reader processes it
- Stripe Terminal requires a physical reader (BBPOS WisePOS E, Stripe Reader M2, etc.)
- Merchant registers their reader in Operations > POS Settings (store `terminal_reader_id` on org)
- The `completedOrder` receipt confirms actual card charge, not just staff's word

**Watch out for:**
- Terminal SDK is browser-only, not React Native — works in the current web dashboard
- Requires `STRIPE_SECRET_KEY` server-side in the edge function; never expose it client-side
- Connection token endpoint must be secured — only callable by authenticated org owners/staff

---

### 2.2 Stripe Connect (Marketplace Payments)
**Status:** `[ ]`

**What to build:**
- Allow marketplace customers to pay merchants directly through GrowthHub (currently payments are handled outside the platform)
- Each merchant completes Stripe Connect onboarding (Express account) — store `stripe_account_id` on `organizations`
- On checkout, create a `PaymentIntent` with `transfer_data.destination = org.stripe_account_id` and GrowthHub takes a platform fee
- Funds settle to the merchant's Stripe account; GrowthHub's fee is retained automatically
- Webhook: `payment_intent.succeeded` → mark order paid, trigger loyalty points, donation ledger entry

**Watch out for:**
- Connect onboarding requires the merchant to complete KYC with Stripe — build a clear "Connect your bank" CTA in the Billing/Operations page
- Platform fee percentage must be disclosed to merchants in your terms

---

### 2.3 Accounting Export (Xero / QuickBooks)
**Status:** `[ ]`

**What to build:**
- OAuth2 connect flow for Xero or QuickBooks in Operations > Integrations
- Store `xero_tenant_id` / `xero_access_token` / `xero_refresh_token` on `organizations` (encrypted)
- A "Sync to Xero" button (and optional nightly cron) that pushes completed orders as invoices and cash receipts
- Map GrowthHub line items → Xero/QBO account codes (configurable per product category)
- Export summary: daily Z-report as a journal entry (total sales, total discounts, total tax collected, total tips)

**Watch out for:**
- Token refresh: Xero tokens expire in 30 minutes; implement background token refresh in the edge function
- Duplicate sync prevention: track `xero_invoice_id` on orders to avoid pushing the same order twice

---

### 2.4 Google / Apple Maps + Delivery Radius
**Status:** `[ ]`

**What to build:**
- Show the merchant's location on a Google Maps embed on their storefront and marketplace profile (lat/lng already stored on `organizations`)
- Delivery radius validation at checkout: calculate distance from merchant to customer's entered address using Google Maps Distance Matrix API; block checkout if outside the delivery radius set in Operations
- Store `delivery_radius_km` in `settings.delivery` on the org
- Display an estimated delivery time on the checkout page using the Distance Matrix response

**Watch out for:**
- Google Maps API key must be server-side only for Distance Matrix (billing exposure risk if exposed client-side without HTTP referrer restrictions)
- Apple Maps doesn't have a Distance Matrix equivalent — use Google for backend validation, MapKit JS optionally for display

---

### 2.5 Apple Pay & Google Pay
**Status:** `[ ]`

**What to build:**
- These come nearly for free via Stripe Elements / Stripe Payment Request Button — wrap the existing checkout in Stripe's Payment Request Button component
- The button auto-detects whether the device has Apple Pay or Google Pay configured and shows the appropriate button
- Requires a verified domain (Stripe domain verification file at `/.well-known/apple-developer-merchantid-domain-association`)

**Watch out for:**
- Must be served over HTTPS — already true in production but test environment needs a tunnel (ngrok etc.)
- Payment Request Button only works on devices with a saved payment method — always keep the standard card form as fallback

---

### 2.6 Loyalty Card / NFC Tap (Physical Cards)
**Status:** `[ ]`

**What to build:**
- Physical loyalty cards with a QR code or NFC chip that encodes the customer's GrowthHub profile ID
- QR: use the existing 6-digit in-person code system — print a QR that links to `/account?merchant=slug` where the code is auto-displayed
- NFC: Web NFC API (Chrome Android only) — on a compatible kiosk tablet, tap the card to read the customer ID and auto-validate the loyalty session
- Card generation: a PDF export from the customer CRM showing printable cards per customer

**Watch out for:**
- Web NFC is only available in Chrome on Android (not iOS, not desktop) — always offer QR as fallback
- NFC card contains the customer ID which is a UUID — ensure the lookup RLS policy doesn't expose other customers' data

---

### 2.7 Delivery Aggregator Sync (Uber Eats / DoorDash)
**Status:** `[ ]`

**What to build:**
- Pull orders from Uber Eats and DoorDash directly into the GrowthHub Orders kanban
- Use Uber Eats Order Management API and DoorDash Drive / Merchant API webhooks
- Map incoming orders to GrowthHub's `orders` schema; tag with `source: 'uber_eats'` or `source: 'doordash'`
- Menu sync: push GrowthHub product catalog updates to Uber Eats / DoorDash menus automatically
- Reject from GrowthHub: a "Decline" in the kanban sends a rejection back to the aggregator

**Watch out for:**
- Both APIs require a formal merchant partnership / developer programme — not self-serve. Plan for a waitlist or manual onboarding step
- Menu sync is complex: extras, modifiers, categories, images all need mapping to the aggregator's schema

---

### 2.8 Review Aggregation (Google, TripAdvisor)
**Status:** `[ ]`

**What to build:**
- Pull Google Business Profile reviews via the Google My Business API and display them alongside GrowthHub native reviews in the marketplace profile
- Auto-respond to new Google reviews using a templated response (configurable in Branding/Operations)
- TripAdvisor reviews (read-only API) — display in marketplace profile for restaurant orgs
- Sentiment score: tag each imported review as positive/neutral/negative for the Analytics dashboard

**Watch out for:**
- Google My Business API requires OAuth2 per-merchant and a verified Google Business Profile — not all merchants will have one
- APIs have rate limits and require approved API access (Google My Business is invite-only for some regions)

---

## 3. Legal & Compliance — Dev Tasks

> The operational and legal groundwork (drafting policies, insurance, GST registration, PCI self-assessment, etc.) is tracked in [`non-dev-implementations.md`](./non-dev-implementations.md). The items below are the **in-app dev tasks** that follow once the legal side is resolved.

---

### 3.1 Privacy Policy & Terms of Service Pages
**Status:** `[ ]`
**Depends on:** non-dev-implementations.md §2.1 (policies drafted by lawyer)

- Public `/privacy` and `/terms` routes rendering the approved markdown/HTML
- Link from Storefront footer, Auth signup form, and customer Account page
- "Last updated" date at the top; easy to bump when policies change

---

### 3.2 Cookie Consent Banner
**Status:** `[ ]`

- Banner on first visit to any public page (Storefront, Marketplace, Shop, /eat) — not inside the authenticated dashboard
- Three categories: Strictly Necessary / Analytics / Marketing
- Consent stored in `localStorage` under a versioned key — re-show if version bumps
- Only load analytics scripts after analytics consent is granted
- "Manage Cookies" link in footer re-opens the preference panel

---

### 3.3 GDPR / Privacy Rights Flows
**Status:** `[ ]`
**Depends on:** non-dev-implementations.md §2.6 (data retention policy defined)

- "Download my data" button in customer Account — exports profile, orders, loyalty, consent history as JSON
- "Delete my account" flow — anonymises customer record (null PII), retains order rows with `customer_id = null` for financial records
- `privacy_requests` audit table logging all access/erasure requests with timestamps
- Merchant-side export: admin can download a customer's data in response to a subject access request

---

### 3.4 Merchant ToS Acceptance Gate
**Status:** `[x]`

**Built:** ToS + Privacy Policy checkbox at signup (clickwrap); `tos_accepted_at` + `tos_version` stored on organizations at signup time. Spam Act acknowledgement checkbox also required. Version bump re-gate in DashboardLayout still `[ ]` — depends on non-dev-implementations.md §2.2 (ToS drafted and versioned).

---

### 3.5 Age Verification (Alcohol / Restricted Items)
**Status:** `[ ]`
**Depends on:** non-dev-implementations.md §2.7 (legal wrapper in merchant terms)

- `requires_age_verification boolean` column on `products` (migration)
- At checkout in `Shop.tsx`: if any cart item has the flag, show a self-declaration modal before proceeding
- POS: prompt staff to check ID on the payment screen when restricted items are in the order

---

### 3.6 ABN & GST on Receipts
**Status:** `[~]`
**Depends on:** non-dev-implementations.md §2.3 (GST registration confirmed)

- `abn` column on `organizations` now exists + validated via checksum + unique index ✅
- ABN input in Operations > Business Details ✅
- POS receipt ABN display + GST breakdown line (GST = total ÷ 11) `[ ]` — wire in when POS receipt view is built
- Marketplace profile ABN display `[ ]`

---

### 3.7 Business Address in Email Footers
**Status:** `[~]`
**Depends on:** non-dev-implementations.md §2.5 (Spam Act compliance)

- `business_address` JSONB column on `organizations` now exists + collected via onboarding checklist ✅
- `email-send` edge function still needs to inject merchant address into outgoing campaign email footer `[ ]`

---
