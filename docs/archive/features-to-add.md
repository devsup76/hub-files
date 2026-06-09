# woahh — Feature Tracker

> Organised by status: what's done, what's core, and what's optional.
> Legal & compliance operational tasks are tracked in [`non-dev-implementations.md`](./non-dev-implementations.md).
> Sprint plan and phase timelines are in [`docs/business/MASTER_PLAN.md`](./docs/business/MASTER_PLAN.md).
> Last updated: 2026-04-30

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
- Customer-facing order notifications — email (Resend) + web push (VAPID RFC 8291); `push_subscriptions` + `order_notification_log` tables; `order-notify` edge function (accepts owner JWT or service-role key); service worker; status stepper on `/order/:id`; PushOptIn Bell; auto-trigger + manual Bell in Orders + KDS; `NotificationSettings` page (triggers, channels, email footer customisation); dine-in excluded; **marketplace tier+**
- Account recovery — `/recover` page; security questions (hashed); owner phone number change flow (`PhoneChangeDialog`); customer dual-verification prompt; `account-recover` edge function
- Staff shift availability — `ShiftAvailabilityPanel` in KDS + Orders; toggle product sold-out/available; toggle extras on/off; manager + service roles only
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

#### ~~Customer-Facing Order Notifications~~ ✅ Built
#### ~~Account Recovery~~ ✅ Built
#### ~~Staff Menu Editing (Availability + Add-on Toggle)~~ ✅ Built

---

#### Customer-Facing Order Notifications — built, kept for reference
**Why:** Customers need to know their order status without refreshing the page.

**What to build:**
- `push_subscriptions` table: customer_id, org_id, endpoint, p256dh, auth (unique per customer+org+endpoint)
- `order_notification_log` table: order_id, channel, event — idempotency guard to prevent duplicate sends
- `order-notify` edge function: accepts `{ order_id, event }` (service-role only); sends email via Resend + web push via VAPID; delivery/takeaway orders only (`dine_in = false`)
- Service worker at `public/sw.js` — push event handler + notification click → open `/order/:id`
- Push subscription opt-in UI on `/order/:id` — "Get notified" Bell button; only shows if customer is identified and `dine_in = false`
- Status stepper progress bar on `/order/:id` — Confirmed → Preparing → Out for Delivery / Ready for Pickup → Done; declined state shows denial_reason
- Live tracking button on `/order/:id` when `courier_tracking_url` is set
- Auto-trigger in Orders.tsx and KDS on status change to preparing/ready/declined
- Manual "Notify customer" Bell button on order cards in Orders.tsx and KDS

**Tier decision:** Customer notifications (Bell button, auto-trigger, push, NotificationSettings page) require marketplace tier or above. Email channel alone remains functional at all tiers via the edge function's `emailEnabled` flag. Transactional notifications never count against the marketing SMS/email cap.

**Watch out for:**
- Always check `customers.email_opt_out` before sending (transactional don't require marketing consent but do respect hard opt-outs)
- Idempotency is critical — Realtime can trigger multiple updates; `order_notification_log` unique constraint prevents duplicate sends
- VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT env secrets required in Supabase dashboard

---

#### AI Features
**Why:** AI dramatically reduces merchant onboarding friction and gives the /eat marketplace a search experience no AU competitor has. All calls go server-side via Supabase edge functions — `ANTHROPIC_API_KEY` never touches the frontend.

**Model choice:** Claude Haiku 4.5 for real-time/chat tasks (~$0.001/call); Claude Sonnet 4.6 for vision + complex generation (~$0.02/call). Cost per feature is negligible at early scale.

---

##### Menu Import from Photo / PDF *(Phase 1 — highest priority)*
**Why:** Typing 40 products into a web form is the #1 onboarding drop-off point. Toast, Square, and Clover are all racing to build this. Woahh should have it at launch.

**What to build:**
- Upload button on the Menu page: "Import menu from photo or PDF"
- Edge function `ai-menu-import`: accepts base64 image or PDF, calls Claude Sonnet 4.6 with vision + structured output prompt, returns JSON matching the `products` + `menu_categories` schema
- Merchant sees a pre-filled review screen — confirm, edit, or discard each item
- One-click confirm saves all to DB
- Supports: photo of physical menu, PDF menu, handwritten menus, multi-column layouts

**Watch out for:**
- Validate prices are numbers before saving (Claude may OCR "$12.50" as "12.50" — handle both)
- Cap file size at 10MB; show error for multi-page PDFs > 20 pages
- Always require merchant review before saving — never auto-insert without confirmation

---

##### Onboarding Assistant (Dashboard Chat) *(Phase 1)*
**Why:** Replaces WhatsApp support at scale. An AI assistant in the dashboard sidebar handles 80% of setup questions before a human needs to get involved.

**What to build:**
- Persistent chat widget in `DashboardLayout.tsx` sidebar (collapsed by default, expand on click)
- Reads current org state on each message: what's set up, what's missing, current tier
- Streaming response via edge function `ai-assistant` calling Claude Haiku 4.5
- Can answer platform questions, suggest next setup steps, write storefront descriptions
- System prompt includes: org state, business type, tier, what features are available
- Escalation: if it can't answer, offers "Contact support" link

**Watch out for:**
- Never expose sensitive org data (payment credentials, customer PII) in the system prompt
- Rate limit: max 20 messages/hour per org to prevent abuse

---

##### Campaign Copy Generator *(Phase 1)*
**Why:** Removes the blank-page problem — the biggest reason merchants don't send campaigns.

**What to build:**
- "Generate with AI" button in `SMSCampaigns.tsx` and `EmailCampaigns.tsx`
- Merchant selects: goal (promo / win-back / loyalty reward / new item / event) + tone (casual / professional / urgent)
- Edge function `ai-campaign` calls Claude Haiku with campaign context + audience type
- SMS output: ≤160 chars with opt-out reminder; Email output: subject line + body + CTA text
- Merchant edits or uses directly

---

##### Marketplace AI Search *(Phase 1)*
**Why:** "Find me cheap Thai food open now" beats a cuisine dropdown. No AU competitor has this.

**What to build:**
- `pgvector` extension migration on Supabase (single SQL line)
- `merchant_embeddings` table: org_id, embedding vector, updated_at
- Nightly pg_cron job: regenerate embeddings for orgs with updated menus (concatenate name + cuisine_tags + description + top menu items → embed via Claude or text-embedding-3-small)
- Edge function `ai-search`: embed query → pgvector similarity search → Claude Haiku re-ranks top 10 → returns results with a one-line match explanation
- Replace/augment existing cuisine filter on `/eat` with a natural language search box
- Graceful degradation: if AI search fails, fall back to existing SQL search

**Watch out for:**
- pgvector requires the extension to be enabled in Supabase dashboard (Settings → Extensions)
- Embedding generation cost: ~$0.0001 per merchant per nightly run — negligible

---

##### Analytics Insights Narrator *(Phase 1)*
**Why:** Charts show numbers. Merchants need to know what to do about them.

**What to build:**
- On `Analytics.tsx` page load, stream a 3–4 sentence AI insight from Claude Haiku
- Reads: last 30 days revenue trend, top products, peak hours, new vs. returning customer ratio
- Produces: specific, actionable observation — "Your Tuesday lunch drops 40% vs. weekly average — consider a Tuesday promotion"
- Cached per org per day (store result in `localStorage` with a date key) — don't re-call on every page load
- Show as a subtle card at the top of the analytics page with a sparkle icon

---

##### AI Decline Reason Suggestions *(Phase 1— quick win)*
**Why:** Most merchants type nothing when declining an order. Customers get confused. This fixes it in 10 seconds.

**What to build:**
- When the decline dialog opens in `Orders.tsx`, show 3 pre-written suggested reasons (generated by Claude Haiku based on the order contents and time of day)
- Merchant taps one or types their own
- Suggested reasons: ingredient shortage, capacity, early closing, etc.
- Single Haiku call, ~100 tokens, instant

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
**Why:** Customers scan a single QR code per restaurant, input their own table number, and order from their phone — no staff needed. One QR per venue eliminates the cost of printing and replacing per-table codes.

**What to build:**
- Public route `/table/:orgSlug` — loads storefront in dine-in mode; customer enters their table number on a prompt screen before browsing
- Validate entered `table_number` against the org's `tables` table — reject unknown numbers with a friendly error
- Pre-fills `table_number` + `dine_in: true` at checkout once confirmed
- Orders enter normal queue; KDS and kanban already show `table_number`
- "Pay at table" option: Stripe Payment Link shown when order status reaches `ready`
- QR code generation in `Tables.tsx`: single QR linking to `/table/:slug` (not per-table URLs)

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

#### Account Recovery
**Why:** Both owners and customers need a reliable path back into their account if they lose access to their primary login method.

**What to build:**
- **Dual verification at all times — owner:** Ensure both email + phone are always on record and verified. If one is lost, the other can be used to recover. Phone number change flow: owner enters new number → OTP sent to new number → updates `owner_phone` + resets `phone_verified`.
- **Dual verification at all times — customer:** On the customer Account page, prompt to add both email and phone if only one is present. Magic link covers email recovery; if phone is also on record, allow SMS OTP as an alternative sign-in path.
- **Owner security questions:** During onboarding (or in Account Settings), owner sets 2–3 security questions. Stored hashed (SHA-256). Recovery flow: enter email → answer security questions → reset session. If security questions also fail: account is permanently unrecoverable — no support bypass.
- **Customer unrecoverable state:** If customer loses both email and phone access, account is unrecoverable by design. Display a clear warning on the Account page about keeping contact info up to date.
- `security_questions` JSONB column on `organizations` (hashed answers); `account_recovery_log` table for audit trail.

**Watch out for:**
- Security question answers must be hashed before storage — never store plaintext
- Constant-time comparison on answer verification (same pattern as staff PIN)
- Rate-limit recovery attempts: max 3 tries per hour per email

---

#### Staff Menu Editing (Availability + Add-on Toggle)
**Why:** During a shift, items run out and add-ons become unavailable. Staff need to update this in real time without accessing full menu CRUD.

**What to build:**
- In `KDS.tsx` and `Orders.tsx`, add a "Menu Availability" quick-access panel (accessible to manager + service roles; not kitchen role)
- Product list with a toggle per item: Available / Sold Out — updates `products.stock` to 0 (sold out) or restores to a non-zero value (back in stock)
- Extras/add-ons toggle per product: each extra in the `extras` JSONB array gets an `available: boolean` flag — staff can flip it off for the session
- Changes are live immediately: storefront hides sold-out items and greyed-out extras in real time (Realtime subscription on products table already exists)
- Staff cannot see or edit price, description, or any other fields — availability only
- Owner retains full menu CRUD via the Menu dashboard page

**Watch out for:**
- Extra availability stored in `extras` JSONB: extend each extra object with `"available": true` (default); filter on storefront before rendering add-on options
- Stock restore on "mark available" should not blindly set a number — use a sensible default (e.g. 99) or prompt staff for a count

---

## 💡 Optional Features — Future Phases

Add these after the core product is stable. Most are Phase 2+ or post-Series A.

---

### Pricing Model Evolution

#### Commission-Based Pricing (Future Consideration)
**Confirmed model — implement with Stripe billing.**

- **4% merchant commission** on each order → 2% to charity, 2% to Woahh
- **2% customer service fee** added at checkout → 1% to charity, 1% to Woahh
- **Total per order: 3% of GMV to charity, 3% net to Woahh**
- **Subscriptions: Solo $49 / Marketplace $89 / Growth $150 (7 locations) / Enterprise custom — 50% to charity, 50% to Woahh**
- Founding merchants (first 20–25): locked at zero commission permanently; still pay subscriptions

**Why:**
- Aligns Woahh revenue entirely with merchant success
- 87% cheaper than Uber Eats / DoorDash (30%+)
- Charity grows to $18.5M/year at 1,000 merchants — equal to Woahh's own revenue
- Customer 2% is fully transparent and disclosed at checkout; half goes to charity
- "On every order, everyone chips in. Merchants pay 4% — half to charity. Customers pay 2% — half to charity. Half your subscription goes to charity too."

**When to implement:** Stripe billing (next critical build). Requires ToS re-gate before activation.

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
