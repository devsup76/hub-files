# Woahh — Positioning Brief

> Internal source-of-truth for what we offer and what no one else does.
> Generated 2026-06-02. Feeds the restaurant pitch + VC deck.

---

## One-liner

woahh is the all-in-one operating system for independent restaurants — branded storefront, a zero-commission discovery marketplace, full CRM/loyalty/SMS/email, kitchen display, reservations, and AI copilots — for under $10 a day, with charitable giving wired into the platform itself rather than bolted on as a campaign.

## Target merchant

Independent, owner-operated restaurants in Australia (Brisbane beachhead first, then Sydney/Melbourne/Gold Coast). The exact buyer is a small-business owner currently stitching together Square (~$165/mo) for POS plus Uber Eats/DoorDash (25-30% commission) for orders, plus a separate website and mailing tool — paying $5,000-6,000/month on a $50k/month restaurant and still not owning a single customer email address. Sign-up is currently restaurant-only (retail business_type exists in code but is hidden), invite-gated by founding-access codes. Specific high-fit profiles already named: reservation-led fine dining that does NOT want aggregator traffic, B2B caterers and event companies, private/members clubs and invitation-only dining, and small-town restaurants where the relationship is the business. Average modeled merchant: ~$15k GMV/month through woahh (~11 digital orders/day at ~$45 AOV; rising as POS captures full in-store volume).

## Feature inventory (shipped)

### AI copilots (code-verified live in repo: ai-menu-import, ai-menu-copilot, ai-campaign, ai-decline-reasons edge functions; multi-model Haiku 4.5 + Sonnet 4.6 with 5-min prompt caching)

- Menu import from photo or PDF — Claude Sonnet 4.6 vision reads a menu image/PDF into an editable review table of categories, items and prices, then one-click publish
- Campaign copy generator — 'Generate with AI' (Claude Haiku 4.5) writes SMS and email subject + body from the merchant's goal (promo / win-back / loyalty) and tone, killing blank-page paralysis
- AI decline-reason suggestions — when an order is declined, AI proposes customer-friendly reasons from the items, fulfillment type and time of day
- Prompt caching + deliberate model tiering (cheap Haiku for text, Sonnet vision for menu import) for cost control

### Orders, kitchen & fulfillment

- Real-time order kanban with accept / prepare / ready / complete / decline
- Order-confirmation gating with per-merchant auto-decline timeout (default 7 min, pg_cron enforced)
- Kitchen Display System on any HDMI TV + Android stick — color-coded by fulfillment (dine-in blue / pickup purple / delivery orange / in-store teal), elapsed timers, owner-customizable keyboard shortcuts
- KDS walk-in order dialog for in-person orders without the storefront
- Staff shift availability — manager/service toggle items sold-out and extras on/off in real time, synced to all stations via Realtime
- Multiple fulfillment types: pickup, dine-in, in-store pickup, shipping (delivery courier code built but flagged off pending funding)
- Public live order tracking at /order/:id (5s polling, no login; driver phone scrubbed)
- Courier auto-dispatch trigger to Uber Direct / DoorDash Drive / Sherpa / Lalamove (built, currently dormant)

### Menu & catalog

- Full product CRUD with price, sale price + timed sale windows, stock, extras (JSONB modifiers), tags, ingredients
- Menu categories with limited-time-offer windows and category-level discounts
- Fixed-price combo bundles with their own sale windows
- Ingredient shortages: dishes with an out-of-stock ingredient stay orderable but show 'temporarily unavailable' and stamp the removed ingredient on the kitchen ticket (most POS hard-block instead)
- Realtime menu sync — owner edits push live to KDS, walk-in dialog and public storefront with no refresh

### CRM, loyalty & customer identity

- Customer CRM: contacts, loyalty balance, dietary prefs, saved addresses, birthdays, per-channel consent
- Invite-to-consent flow (/i/:token) replacing manual add — records stamped email_consent_method='invite_link' for Spam Act compliance
- Unified cross-merchant identity: growthhub_profiles + merchant_connections merge a customer by email/phone across all woahh merchants; customer sees every merchant under one Account 'My Merchants' hub; GrowthHub badge surfaces this in the owner CRM
- Points + milestone loyalty with automatic birthday rewards
- In-person loyalty: McDonald's-style 5-min rotating 6-digit codes — customer shows code in Account > In-Store, staff validate in the dashboard panel; same points pool as online (no NFC/card hardware)

### Marketing — owned channels

- SMS campaign builder with audience filtering, scheduling presets, 'Sends in X' pill, best-time tips, cancel action
- Per-merchant SMS numbers (organizations.sms_number) so each merchant owns its sender; shared OTP number for transactional; STOP/opt-out scoped per merchant (verified end-to-end send + STOP on live backend 2026-05-31)
- Email campaign builder via Resend batch API with open/click/bounce tracking
- Per-merchant marketing email identity ({slug}@campaigns.woahh.app), reply-to to the merchant's own contact email
- Top-up credits for SMS and email beyond the monthly tier cap (no rollover; zeroed monthly)
- Tier-based monthly caps auto-set by trigger: email 2k/15k/50k/100k, SMS 0/700/1k/2.5k across solo/marketplace/growth/enterprise
- Hardened email infra: atomic claim, stale-claim self-heal, idempotency keys, HMAC webhook verification, safe-from-name sanitiser, preheader injection

### Storefront, marketplace & discovery

- Public branded storefront (restaurant + retail variants) with cart, promo codes, fulfillment selection, checkout
- /eat discovery marketplace — restaurants auto-listed, filterable by cuisine, rating, open/closed (isOpenNow from hours) and Impact badge
- Merchant /eat/:slug profile with reviews, hours, impact metrics and order CTA
- Marketplace visibility control + auto-list with escalating re-list reminder emails (1d/3d/7d/14d/30d, opt-out + pause-until)
- Customer 1-5 star reviews feeding a live aggregate rating trigger
- Branding: logo upload, HSL color pairs, curated Google-font pairs applied to public pages

### Reservations & tables

- Public booking widget /book/:slug with date/time, party size, customer capture
- Table CRUD with managed zones, seat counts, bulk add and QR codes
- find_available_table RPC auto-assigns a suitable table; reservation status lifecycle requested→confirmed→seated→completed→cancelled→no_show
- Self-cancel link /cancel-reservation/:token; cancellation reopens slots
- Timezone-aware availability (list_available_slots, default Australia/Brisbane), deposit config, and 24h+2h reminder emails via pg_cron
- Confirmation + reminder edge functions (reservation-confirm, reservation-remind)

### Notifications

- Order status emails via Resend (confirmed / preparing / ready / completed)
- Web push (RFC 8291 VAPID) with service worker, push_subscriptions + order_notification_log, opt-in Bell on /order/:id and in Orders/KDS
- NotificationSettings page to choose which states trigger email vs push; dine-in excluded from push (marketplace tier+)

### Charity & impact

- Public /impact transparency dashboard: donation_ledger aggregates, leaderboard, by-cause breakdown
- Donate dashboard with voluntary giving-rate slider — code default 0.1% GMV floor (10 bp), adjustable up to 10% (1000 bp)
- One-time donations and an Impact Partner / DonationBadge shown on marketplace + storefront
- donation_ledger is publicly readable (RLS) sourcing gmv_mandatory / voluntary / promotion_share / one_time

### Payments (code beyond docs)

- Stripe Connect onboarding edge function (stripe-connect-onboard) — live in repo
- Stripe payment-intent edge function (stripe-payment-intent) — live in repo; currently hard-codes application_fee_amount = 0 (founding pass-through model)
- Order receipt email (order-receipt-email edge function)

### Staff, auth & multi-tenancy

- Staff accounts with manager/service/kitchen roles; owner-only PIN-based staff-manage (no Supabase admin API)
- Staff PIN login (6-digit, SHA-256 pin:userId, 5-attempt lockout + 15-min cooldown, constant-time compare, 3-step org/user/pin verify to block enumeration)
- Role-based sidebar + route guards + auto-redirect by role; session ban on deactivate; inline role editing
- Owner email/password auth; customer magic-link + username lookup; hard persona separation (/signin customer-only, /business/auth merchant-only, 'View as customer')
- Multi-tenant RLS on every table via current_org_id() with deterministic owner>staff priority resolution; PII masking (get_member_org nulls owner phone/name/ABN/address for non-owners); safe public views + RPCs (get_public_menu, get_order_by_id, create_public_reservation)

### Onboarding, compliance & admin

- Merchant onboarding: business type, owner legal name, legal entity type, phone OTP (Clicksend via owner-verify), ABN checksum-validated + unique, business address, ToS version + timestamp, Spam Act acknowledgement; 5-step OnboardingChecklist
- Founding-merchant invite gating: admin-only /business/dashboard/admin/codes, founding_access_codes table, generate/redeem/release RPCs; sign-up blocked without a code
- Account recovery (/recover): security questions (SHA-256), 3 attempts/hour, owner phone-change OTP, customer dual-verification
- Privacy surfaces: /unsubscribe/:token, /privacy, /terms, per-channel consent timestamps
- Customer-removal notification email (customer-removed-notify)

### Analytics & operations

- Analytics dashboard: 7 toggleable widgets (revenue trend, fulfillment mix, top products, peak-hours heatmap, new/returning customers, categories, marketing channels) with Today/7d/30d/90d ranges and localStorage layout persistence
- Operations hub: hours (drives open/closed badge), fulfillment toggles, reservation/deposit/timezone settings, business-details edit, tier + cap usage display
- KitchenSettings: courier credentials, KDS display + keyboard-shortcut KeyCapture
- Promotions / promo codes (percentage or flat, usage limits, expiry); Promote sponsored marketplace listings with charity/platform fee split
- Full demo mode: in-memory DemoStore (Bella's Bistro) with 90-day synthetic history, ?demo=role bootstrap

## Differentiators — what no one else does

- Charity is structural, not a campaign — giving is wired into the platform: a code-default 0.1% GMV mandatory floor (slider up to 10%), a public donation_ledger anyone can audit, a /impact leaderboard merchants compete on, and the documented model of 50% of every subscription + 50% of every order commission flowing to charity. No major competitor donates from GMV at all.
- Operating system AND its own demand channel in one product — woahh ships the full back-of-house stack (orders, KDS, menu, CRM, loyalty, campaigns, reservations, analytics) plus a /eat discovery marketplace where merchants are auto-listed and own the customer. Square/Toast give you tools but no marketplace; DoorDash/Uber own the marketplace but take 25-30% and the customer.
- AI-first onboarding and operations, already in the codebase — menu-import-from-photo (Sonnet vision), AI campaign copy and AI decline reasons (Haiku) are live edge functions today, not slideware. Toast/Square are still racing to ship menu import; Bopple/MrYum don't have it.
- Unified cross-merchant customer identity — one customer account follows many woahh merchants with pooled order history and loyalty in a single Account hub. Deliveroo and most POS systems force a fresh siloed account per restaurant.
- Same loyalty pool online and in-store via 5-min rotating 6-digit codes — McDonald's-grade in-person loyalty with zero NFC/card hardware cost, unified with online points.
- Ingredient-shortage handling that keeps dishes sellable — items with one out-of-stock ingredient stay orderable, flagged to the customer, with the removed ingredient stamped on the kitchen ticket. Most systems just hide the dish.
- No hardware lock-in for kitchen — KDS runs on any HDMI TV + a $40-60 Android stick versus $1,000-2,000+ proprietary terminals, with online and walk-in orders unified on one screen.
- Each merchant owns its messaging identity — per-merchant SMS numbers and per-merchant {slug}@campaigns.woahh.app email sender, with consent and STOP scoped per merchant, verified end-to-end on the live backend.
- Compliance enforced in code, not a checklist — Spam Act consent/unsubscribe/physical-address, ABN checksum + uniqueness, ToS versioning, RLS PII masking and safe public RPCs are built into the platform.
- Incentive alignment via fixed subscription pricing — merchants pay a flat monthly fee, not a per-order tax, so woahh only grows when merchants grow; the launch model runs an actual application_fee of 0 (true pass-through) for founding merchants.

## The charity / impact angle

Giving is built into the rails, with three reinforcing layers. (1) Mandatory floor: the code default for voluntary_donation_rate_bp is 10 basis points — a 0.1% of GMV floor on every order — and merchants can raise it up to 10% via the Donate slider. (2) Structural split (documented model): 50% of every subscription and 50% of every order commission is earmarked for charity; the documented commission policy is 3% on the merchant (1.5% charity / 1.5% woahh) plus a 1% online customer service fee (0.5%/0.5%), netting 2% charity on a fully-loaded online order. (3) Radical transparency as the growth hook: every dollar is written to a publicly-readable donation_ledger and surfaced on a /impact dashboard with a by-cause breakdown and a merchant leaderboard, plus an Impact Partner badge on each storefront and marketplace card. The reframe that carries the pitch: giving is a growth engine, not a cost centre — it is the marketing, the differentiation, and the merchant's social proof, all at once. Scale math from the model: 1,000 merchants at ~$15k GMV/month ≈ $344.5k/month each to woahh and to charity, ~$4.13M/year to charity (5,000 merchants → ~$20.7M/year). Charity headline (locked 2026-06-02): ~2% of every online order + 50% of every subscription (50/50 split); the 0.1% GMV floor is the separate voluntary-rate default, not the headline.

## Business model

Subscriptions (flat monthly, 60-day free trial of Marketplace tier, no credit card): Solo $49/mo (1 location; email campaigns + Promote). Marketplace $89/mo (up to 3 locations; full feature set — CRM, loyalty, SMS, marketplace listing). Growth $150/mo (up to 7 locations, priority placement, custom domain/PWA). Enterprise: custom (unlimited locations, white-label, dedicated support). Commission (documented policy): online orders 3% merchant + 1% customer service fee = 2% charity / 2% woahh; in-person orders 3% merchant only = 1.5% charity / 1.5% woahh (merchant absorbs, no customer-facing fee). Code reality today: stripe-payment-intent hard-codes application_fee_amount = 0 — the founding-merchant pass-through model — so commission is policy/future, not yet charged. Founding offer: first 20-25 merchants get 2 months free + permanent zero commission (signed agreement) while still paying subscriptions; ~$300/mo foregone per merchant (~$6-7.5k/mo total) bought back as testimonials, referrals, case studies and investor social proof. Unit economics: ~$15k GMV/merchant/month assumption; blended sub ~$89 ($44.50 woahh / $44.50 charity); net commission to woahh 2% of GMV (~$300/merchant/mo → ~$344.50/merchant/mo total to woahh, equal to charity); LTV ~$8-12k, CAC <$400 (<3 months revenue). Infra at 1,000 merchants ~$2,300/mo (ClickSend SMS ~$1,500 dominant, then Stripe $420, Supabase $200, Resend $90, Cloudflare ~$20) → ~94% contribution margin (pre-payroll); break-even ~60-110 merchants. Phase targets: M4 50+ merchants / ~$0.75M GMV/mo / ~$17k revenue/mo; M12 300+ merchants / ~$4.5M GMV/mo / ~$103k/mo (~$1.24M ARR). Promoted listings split 70% charity / 30% woahh.

## Competitor gaps

- Uber Eats / DoorDash: take 25-30% commission, own the customer relationship and email list, and donate nothing from GMV; they cannot do POS or back-of-house. woahh is ~90% cheaper on take rate (3% vs 30%) and the merchant keeps the customer.
- Square: ~2.2% + ~$165/mo software, has dine-in/QR but no discovery marketplace and no built-in charitable giving; merchants still need a separate delivery channel.
- Toast: powerful but expensive proprietary hardware ($1,000-2,000+), no consumer-facing marketplace, charity is absent, and simpler staff auth than woahh's PIN + role model; still racing to ship AI menu import woahh already has.
- Stripe / PayPal: payments only — no CRM, loyalty, marketplace, KDS, or founding/giving tier.
- Deliveroo / aggregators generally: force the merchant into a split stack and force customers into a fresh siloed account per restaurant, versus woahh's unified cross-merchant identity.
- Bopple / MrYum and similar order-and-pay tools: lack AI menu import and lack a charity/impact layer; narrower than woahh's full operations + marketplace footprint.

## Future roadmap (planned, not yet built)

- Stripe billing & subscription management UI (Connect Express onboarding wired; webhook sync, billing portal, grace periods still needed — blocks first paying merchant)
- Merge and productionise the AI features branch to main, and per-merchant dedicated SMS numbers for every real merchant
- Retail / shop vertical — un-hide business_type='retail', wire conditional storefront + inventory + SKU/barcode + shipping (cost_price_cents leak to fix first)
- Appointment booking (services vertical): services + staff_schedules + appointments tables and booking widget
- Inventory alerts & low-stock thresholds with stock decrement on order and owner email alert
- Table QR-code self-service ordering (/table/:orgSlug) with 'Pay at table' option
- Receipts — email + browser print + PDF (thermal printer SDKs optional later)
- Make delivery a single feature flag (courier code already built but dormant pending funding/AFSL/insurance)
- Cookie consent banner + GDPR/Privacy-Act data-download and account-deletion flows; ToS version re-gate; ABN/GST line and age verification on POS receipts
- PWA install (manifest + install prompts) for merchant and/or customer surfaces
- POS: Stripe Terminal smart reader (S700 / WisePOS E) then Tap to Pay on iPhone/Android via a React Native app (needs Apple proximity-reader entitlement + Stripe AU AFSL written confirmation for Connect Custom)
- Deferred AI: marketplace AI search (pgvector + Claude re-rank), dashboard onboarding assistant, and an analytics insights narrator ('Tuesday lunch is down 40%')
- Native merchant and customer apps (Expo) for live order alerts and organic app-store discovery
- Integrations: Xero/QuickBooks accounting export, Google Maps + delivery-radius validation, Apple/Google Pay, aggregator order sync, Google/TripAdvisor review aggregation, advanced cohort/CLV analytics, physical loyalty cards/NFC
- Hardware kits (lease-to-own): Solo $699 / Marketplace $899 / Growth $1,399; ACMA sender-ID strategy (numeric-only per-merchant numbers)

## Production status (honest — do not overclaim)

Live/verified: the merchant dashboard and 27 feature pages, KDS, orders, menu, reservations, marketplace, customer portal and demo mode are all present in code and match docs at ~90-95% fidelity (code-groundtruth review). Per-merchant SMS (send + STOP/opt-out) was verified end-to-end on the live Supabase backend on 2026-05-31 with a dedicated ClickSend number. AI features (ai-menu-copilot, ai-campaign, ai-decline-reasons) are real edge functions on Claude Sonnet 4.6 with prompt caching — **browser-verified end-to-end, merged to main + deployed on 2026-06-02** (treat as live/shipped). Stripe is further along than CLAUDE.md's 'not started' claims: stripe-connect-onboard and stripe-payment-intent edge functions exist — but the payment intent currently hard-codes application_fee_amount = 0, i.e. the founding pass-through model; commission charging and the full subscription-billing UI are NOT yet implemented. Honest gaps to NOT overclaim in the pitch: no production subscription billing UI; no POS/terminal payments; retail vertical hidden; delivery courier code built but flagged off; receipts, PWA install, cookie/GDPR flows not built. Model locked (2026-06-02, all docs reconciled): commission 3% merchant + 1% customer = 4% gross online (3% in-person) → 2% woahh / 2% charity online; $15k GMV/merchant base; Growth tier $150 ($199 removed); charity headline = ~2% of every online order + 50% of every subscription (the 0.1% GMV floor is the separate voluntary-rate default). Source of truth: docs/business/BUSINESS_STRATEGY.md.
