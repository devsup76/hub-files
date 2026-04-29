# Woahh — Business Strategy & Financial Decisions

> **Purpose:** This document captures the key strategic, financial, and product decisions behind Woahh. It is intended for advisors, investors, co-founders, and partners who need context and rationale behind how and why the business is built the way it is.
>
> Last updated: 2026-04-29
> Status: Near-launch — soft launch to founding merchants within 3 weeks. See `MASTER_PLAN.md` for sprint plan and phases.

---

## Table of Contents

1. [What Woahh Is](#1-what-woahh-is)
2. [Team](#2-team)
3. [Current Build Status](#3-current-build-status)
4. [Payment Processing](#4-payment-processing)
5. [Subscription Pricing Model](#5-subscription-pricing-model)
6. [Revenue Projections](#6-revenue-projections)
7. [Infrastructure Costs & Scalability](#7-infrastructure-costs--scalability)
8. [GMV Tracking & Charitable Giving](#8-gmv-tracking--charitable-giving)
9. [Competitive Positioning](#9-competitive-positioning)
10. [Delivery Integration](#10-delivery-integration)
11. [Go-to-Market Strategy](#11-go-to-market-strategy)
12. [Hardware Strategy](#12-hardware-strategy)

---

## 1. What Woahh Is

Woahh is a full-stack SaaS platform for small business owners — restaurants, retail shops, and service businesses — built to give independent operators the technology stack that only large chains have had access to, at a price point they can actually afford.

**Two core value propositions under one flat monthly subscription:**

1. **Own digital presence** — branded storefront, direct ordering, kitchen display, CRM, loyalty program, SMS and email campaigns, reservations, dine-in table management, staff management, analytics, and branding tools. The complete tech stack that Dominos and Shake Shack run internally, available to a café for $49/month.

2. **Discovery marketplace** — the public `/eat` directory, zero-commission, where customers find and order from local businesses. The alternative to Uber Eats that doesn't take 25–30% of every order.

**Financial philosophy:**
The goal is not maximum extraction from merchants. The intent is to build a sustainably profitable business that generates wealth to support the team and fund charitable causes, while genuinely helping small businesses grow. Pricing reflects this — no per-transaction fees on top of subscriptions, no volume caps that penalise growth.

**The giving model:**
0.15% of every order processed through Woahh goes to charity. 0.15% is retained by Woahh as a platform fee. Every merchant's dashboard shows their individual charitable contribution. A public `/impact` page shows the full donation ledger — transparent, auditable, and verifiable by anyone. No competitor does this. It is a structural commitment built into the platform from day one, not a marketing gimmick.

**Expanding verticals:**
- Restaurants and retail: live at launch
- Appointment booking (salons, gyms, healthcare, all service verticals): Phase 2
- Ticketing: to be scoped post-Phase 2

---

## 2. Team

Three co-founders. Each owns their lane completely.

| Role | Responsibilities |
|---|---|
| **CEO + Tech Lead** | Product vision, strategy, investor relations, merchant relationships, app development, Lovable, architecture, security |
| **Marketing Lead** | Brand, social media, content, campaigns, PR, launch strategy, marketing site |
| **Operations** | Legal admin, compliance, Xero, support coordination, hardware logistics, processes — picks up overflow across the business |

**First hire post-investment:** A developer to take technical workload off the CEO so they can focus fully on growth and fundraising.

**Co-founders agreement:** Signed April 2026. Shareholders agreement to be completed before launch.

---

## 3. Current Build Status

The product is near-launch ready. The following features are fully built and tested:

**Core platform:**
- Multi-tenant architecture with full RLS isolation per organisation
- Owner auth (Supabase), customer auth (magic link + username lookup), staff auth (6-digit PIN, constant-time comparison, 5-attempt lockout)
- Subscription tier system (free_trial → solo → marketplace → growth → enterprise) with automated cap management
- Merchant onboarding and compliance: business type, legal entity, phone OTP verification (Clicksend), ABN checksum validation, business address, ToS acceptance timestamp, Spam Act acknowledgement

**Operations:**
- Order management: kanban, real-time updates, confirmation flow, auto-decline cron
- Kitchen Display System (KDS): colour-coded by fulfillment type, elapsed timer, keyboard shortcuts (owner-customisable)
- Product/menu catalog: CRUD, extras, stock, sale windows, categories, combos
- Dine-in table management: zones, bulk add, QR codes
- Reservations: public booking widget, waitlist, deposit config, 24h + 2h reminder cron, cancellation tokens
- Courier/delivery: Uber Direct, DoorDash Drive, Sherpa, Lalamove — auto-dispatch trigger on order preparing

**Customers & marketing:**
- CRM: full customer list, opt-in tracking, dietary preferences, saved addresses
- Loyalty: points + milestone rewards, birthday rewards, in-person rotating 6-digit codes
- SMS campaigns: full UI, Clicksend batch API, delivery tracking, opt-out, top-up credits
- Email campaigns: full UI, Resend batch API, open/click tracking, unsubscribe, top-up credits
- Scheduled sends: timezone-aware, best-time tips, pg_cron dispatch
- Promo codes: CRUD, usage limits, expiry

**Marketplace & public:**
- `/eat` marketplace: discovery, cuisine filter, ratings, Impact badge
- Public storefront (restaurant + retail variants)
- Customer portal: rewards, order history, profile, cross-merchant identity
- Unified customer identity: `woahh_profiles` + `merchant_connections`; merge by email + phone; cross-merchant account hub
- Public `/impact` transparency dashboard: donation ledger, leaderboard, by-cause chart
- Reviews: customer reviews, aggregate rating trigger

**Management:**
- Staff accounts: manager/service/kitchen roles, PIN login, role-based sidebar, session management
- Analytics dashboard: 7 togglable widgets, 90-day history, date range tabs
- Branding: logo upload, HSL colours, font pairs
- Promote: sponsored marketplace listings with charity/platform fee split
- Donate: voluntary giving rate slider, one-time donations

**Not yet built (pre-launch priority):**
- Stripe billing integration (subscription management — in progress, completes before launch)
- iOS/Android native apps (Phase 1, via Expo)
- Retail/shop features (Phase 1)
- Appointment booking (Phase 2)

---

## 4. Payment Processing

### Decision: Stripe Connect Express (Pass-Through Model)

**How it works:**
- Customer pays at checkout via Stripe
- Woahh automatically splits the charge: 0.15% platform fee to Woahh, remainder to the merchant
- Merchant receives their share immediately — Woahh never holds funds
- All disputes, chargebacks, and compliance remain between the merchant and Stripe
- No AFSL required — Woahh does not hold or transmit funds, it facilitates a split at point of charge

This is distinct from a "payment facilitator" or "marketplace payout" model where Woahh holds funds and batches payouts. The pass-through model keeps Woahh outside AFSL and AUSTRAC scope at launch.

### Options Evaluated

| Option | Model | Pros | Cons |
|---|---|---|---|
| **Stripe Connect Express (pass-through)** ✓ | Split at charge — merchant receives instantly | 0.15% platform fee revenue; no fund holding; Stripe handles KYC; automated splits | Requires AUSTRAC engagement at scale when fee volume becomes significant |
| **Stripe Standard** | Each merchant owns their Stripe account; Woahh not in payment flow | Zero regulatory exposure | Cannot take a platform fee; no revenue from transactions |
| **Fund-holding marketplace model** | Woahh holds customer payment, batches payouts to merchants | Control over payout timing | Requires AFSL — a 12+ month, $50k+ process; not viable at launch |
| **Tyro** (AU-specific) | EFTPOS terminal integration | ~30% of AU restaurants already on Tyro | In-person only; no online rails; optional add-on only |
| **Adyen** | Enterprise interchange++ pricing | Cheapest at $50M+ GMV/month | Minimum volumes; months-long onboarding |
| **Square / Braintree** | Competitor / PayPal product | — | Square is a direct competitor; creates dependency on a rival |

### Fee Breakdown on a $30 Order

| Payment type | Customer pays | Stripe fee | Woahh platform fee (0.15%) | Merchant receives |
|---|---|---|---|---|
| Online (card not present) | $30.00 | $1.17 (2.9% + 30¢) | $0.045 | $28.79 |
| In-person (Stripe Terminal) | $30.00 | $0.86 (2.7% + 5¢) | $0.045 | $29.10 |

**Comparison to Square:** Square charges 2.6% + 10¢ in-person ($0.88 on $30) and 2.9% + 30¢ online ($1.17 on $30). Woahh's platform fee is effectively invisible by comparison. The meaningful difference is Square charges monthly software fees on top of every transaction; Woahh's flat subscription covers everything.

### Legal Considerations

- **AUSTRAC:** Not required at launch under the pass-through model. Required when platform fee volume becomes significant — engage AML Shield or Comply Advantage 3–6 months before that threshold.
- **AFSL:** Stripe's own AFSL covers platforms operating under Stripe Connect. Written confirmation from Stripe Australia to be obtained before launch.
- **Australian Privacy Act:** Applicable now. Woahh stores customer data on behalf of merchants. Privacy policy and DPAs required before launch.

### Phase 2 (Stripe Connect — Platform Fee Revenue at Scale)

| Platform GMV/month | 0.3% total fee | 0.15% to charity | 0.15% net to Woahh |
|---|---|---|---|
| $500k | $1,500/mo | $750/mo | $750/mo |
| $5M | $15,000/mo | $7,500/mo | $7,500/mo |
| $50M | $150,000/mo | $75,000/mo | $75,000/mo |

The net 0.15% to Woahh becomes the dominant revenue stream at scale — the same model used by Shopify and Toast. The matched 0.15% to charity means Woahh's transaction revenue growth is mirrored dollar-for-dollar by charitable impact.

---

## 5. Subscription Pricing Model

### Decision: Feature-Based Tiers, No GMV Caps

GMV caps were removed entirely. Penalising a merchant for a busy Christmas period is hostile to the customer relationship. GMV is tracked internally for charitable giving and analytics only — never for billing decisions.

### Tier Structure

| Plan | Monthly Price | Target customer | What's included |
|---|---|---|---|
| **Solo** | $49/month | Single-location business wanting full-stack presence without marketplace listing | Orders, KDS, products, CRM, loyalty, email campaigns, reservations, tables, branding, analytics, staff management. Single location. Not listed on `/eat`. |
| **Marketplace** | $99/month | Business wanting discovery alongside their own presence | Everything in Solo + listed on `/eat` (zero commission), Impact badge, sponsored listings, up to 3 locations |
| **Growth** | $199/month | Scaling or multi-location operator | Everything in Marketplace + unlimited locations, priority `/eat` placement, advanced analytics, custom domain (PWA), API access |
| **Enterprise** | Custom | Chains, franchises, multi-location groups | White-label, dedicated support, volume pricing, negotiated terms |

**Free trial:** 60 days of full Marketplace-tier access. No credit card required to start.

**Founding Merchant program:** First 20-25 merchants locked in at their starting rate permanently. Capped and documented in a signed agreement.

### Why the Solo Plan Is Not Just a Price Anchor

Real segments that need operations without discovery:
- Reservation-only fine dining restaurants — fully booked, don't want more traffic
- B2B caterers and event companies — their customers are businesses
- Private members clubs and invitation-only dining
- Restaurants in small towns where everyone already knows them

Forcing these onto a public directory is a dealbreaker. Respecting this distinction wins those accounts.

### The "App of Your Own" Opportunity (Growth Tier)

The Growth plan at $199/month delivers a near-native app experience without building native apps:

1. **Custom domain** — `order.bellasbistro.com.au` points to their Woahh storefront. Looks like their own website. Shopify Plus charges thousands for this.
2. **PWA** — Customers "Add to Home Screen" on iPhone/Android. Full-screen icon with their logo. Indistinguishable from a native app.
3. **Push notifications** — Direct to customers who've installed their "app."

Billion-dollar restaurant tech stack, available to a café at $199/month.

### The Pitch

> "Square gives you a payment system. Uber Eats lists you in their directory and takes 30%. Woahh gives you your own full-stack presence — website, app, loyalty, CRM, kitchen display — AND lists you on our zero-commission marketplace where you keep every dollar. Starting at $49 a month."

---

## 6. Revenue Projections

### Assumptions
- Tier distribution: 45% Solo ($49), 40% Marketplace ($99), 10% Growth ($199), 5% Enterprise (~$300 blended)
- Weighted average revenue per merchant: ~$95/month
- Subscription revenue only — excludes platform fee revenue
- Infrastructure costs are estimates; SMS is the primary variable cost

### Subscription Profit Table

| Active merchants | Gross revenue/month | Infrastructure costs/month | Estimated profit/month | Estimated profit/year |
|---|---|---|---|---|
| 50 | $4,750 | ~$180 | $4,570 | $54,840 |
| 100 | $9,500 | ~$320 | $9,180 | $110,160 |
| 250 | $23,750 | ~$650 | $23,100 | $277,200 |
| 500 | $47,500 | ~$1,400 | $46,100 | $553,200 |
| 1,000 | $95,000 | ~$2,800 | $92,200 | $1,106,400 |
| 2,000 | $190,000 | ~$5,500 | $184,500 | $2,214,000 |
| 5,000 | $475,000 | ~$13,000 | $462,000 | $5,544,000 |

**Net margin: 94–97%.** Infrastructure costs are near-flat (CDN hosting) or scale in small steps (Supabase), not proportionally with merchant count.

### Infrastructure Cost Breakdown

| Cost item | Small (100 merchants) | Medium (1,000) | Large (5,000) | What drives the cost |
|---|---|---|---|---|
| Supabase (DB + functions) | $25/mo | $200/mo | $800/mo | DB size, edge function calls, realtime connections |
| Resend (email sending) | $20/mo | $90/mo | $400/mo | Emails sent per month across all merchants |
| Clicksend (SMS) | $150/mo | $1,500/mo | $7,500/mo | SMS messages sent — main variable cost |
| Stripe billing fees | $42/mo | $420/mo | $2,100/mo | 0.5% of subscription revenue |
| Lovable (builder + hosting) | $50/mo | $50/mo | $100/mo | Near-flat; CDN hosting of the React frontend |

**SMS is the dominant variable cost.** Volume pricing negotiation with Clicksend is a priority at scale. SMS is marketplace tier and above only, with monthly caps per org — limits exposure.

---

## 7. Infrastructure Costs & Scalability

### How Lovable Hosting Works

Woahh is built on Lovable — an AI-driven application builder. The frontend is a React SPA served from a CDN.

**CDN costs do not scale with user count.** Whether 10 or 100,000 users visit the storefront, the CDN cost is essentially flat. No server provisioning as traffic grows.

The real infrastructure is Supabase:
- PostgreSQL database (scales with data volume)
- Auth (scales with monthly active users)
- Edge Functions (scales with invocation count — SMS, email, courier dispatch, PIN login)
- Realtime subscriptions (scales with concurrent connections — orders page, KDS)
- File storage (scales with files stored — logos, images)

Supabase Pro at $25/month handles ~500 merchants comfortably. Beyond that, compute add-ons scale in $10–50/month increments. No manual server management.

### Multi-Vertical Scalability

Woahh is architected for multiple verticals (restaurant, retail, appointments, events). All verticals run on the same Supabase project — shared infrastructure at no additional cost. If data residency requirements demand separate projects for international markets, each Supabase project costs ~$25/month — negligible.

---

## 8. GMV Tracking & Charitable Giving

### How It Works (Built and Live)

Every order processed through Woahh records its value. GMV is accumulated automatically per merchant, per month — the same infrastructure that tracks SMS and email usage. No merchant reporting required. Monthly resets run via pg_cron.

The `donation_ledger` table records every charitable contribution: source (GMV-mandatory, voluntary, promotion share, one-time), amount, cause, and timestamp. This is the public record.

### Giving Model

| Source | Rate | Notes |
|---|---|---|
| GMV (every order) | 0.15% → charity, 0.15% → Woahh | Built into every transaction automatically |
| Voluntary rate | Merchant-configurable above 0.1% floor | Slider in Donate dashboard |
| Subscription | Fixed monthly donation included per tier | Solo $10, Marketplace $25, Growth $40 |
| Promoted listings | 70% → charity, 30% → Woahh | Promotion fee split on `/eat` sponsored listings |
| One-time donations | Merchant-initiated | Available in Donate dashboard |

### Merchant Visibility (Live)

Each merchant's dashboard shows:
- Their total GMV this month
- Their proportional charitable contribution ("Your orders this month contributed $X to [cause]")
- An Impact Partner badge displayable on their public storefront

The public `/impact` page shows platform-wide GMV, total donated to date, monthly breakdowns, by-cause chart, and a merchant leaderboard. All data sourced from the `donation_ledger` table — real-time, verifiable.

### Transparency Roadmap

**Phase 1 (Live):** Public `/impact` dashboard — real-time aggregates, charity receipt PDFs, public GitHub issue tracker for concerns.

**Phase 2 (Within year 1):** Blockchain timestamping — hash the monthly donation ledger and publish to a public blockchain. Anyone can verify the records are authentic and unaltered.

**Phase 3 (At scale, $50k+/month donated):** On-chain donation flows — convert to USDC, distribute directly to charity wallets via public smart contract. Requires AUSTRAC DCE registration and legal review before a single crypto transaction.

### Why This Is Strategically Valuable

No competitor — Square, Toast, Clover, Lightspeed, me&u, Hey You — donates any portion of merchant GMV to charity. This creates:
- Genuine differentiation that cannot be copied without deep cultural commitment
- Word-of-mouth acquisition — merchants actively recruit other merchants
- Press and partnership opportunities a pure-software pitch cannot access
- Mission-aligned merchants who will choose Woahh specifically because of this

---

## 9. Competitive Positioning

### The Market Problem

Small business owners face a forced choice between two broken options:
- **POS/software tools** (Square, Toast, Lightspeed): great for operations, no discovery mechanism, high transaction fees, merchants never own the customer relationship
- **Marketplace platforms** (Uber Eats, DoorDash, me&u): great for discovery, 25–30% commission on every order, no owned storefront, customer data stays with the platform

Woahh is both: owned operations stack + zero-commission marketplace, under one flat monthly subscription.

### Australian-Specific Competitive Landscape

| Competitor | What they do | Their weakness | Woahh's position |
|---|---|---|---|
| **me&u (formerly Mr Yum)** | QR-code table ordering, raised $89M AUD | Expensive, focused on mid-to-large venues, no full merchant stack, no giving model, in restructuring | Woahh targets the full small business market they ignore — and has features they'd take 12-18 months to replicate |
| **Hey You** | Pre-order app for coffee and quick service | Acquired by a payments company, narrow use case (coffee/QSR only), no CRM, no campaigns, no marketplace | Different segment for Woahh; serves as a switching entry point |
| **Bopple** | White-label online ordering for restaurants | No marketplace, no CRM, no loyalty, no campaigns, no giving model — just ordering | Woahh delivers 10x the feature set at a similar price point |
| **Square for Restaurants** | POS and software | 2.6–2.9% transaction fees forever, no marketplace, no zero-commission delivery, software fees on top of transaction fees | Merchants paying Square $1,475/month can run the same business on Woahh for $99/month |
| **Uber Eats / DoorDash** | Marketplace discovery | 25–30% commission, merchant never owns the customer, no storefront, no CRM | Woahh + Uber Direct delivers the same delivery radius at a flat fee; merchant keeps the customer |
| **Lightspeed** | Enterprise POS | Expensive, complex, designed for large retailers — not small business | Different target customer, but creates a clear upgrade path: start Woahh, grow into Enterprise tier |

**The competitor risk:** me&u and others could adopt elements of Woahh's feature set. The defence is speed — get 200 Brisbane merchants deeply embedded with high ROI before any competitor notices, and the switching cost becomes enormous. The giving model is the hardest to copy because it requires genuine cultural commitment, not just engineering.

### The Full Competitive Table

| Factor | Square / Toast | Uber Eats / DoorDash | me&u / Bopple | Woahh |
|---|---|---|---|---|
| Transaction fees | 2.6–2.9% forever | N/A | None / low | 0.15% platform fee only |
| Software cost | $60–$165/month + add-ons | None | $99–$299/month | $49–$199/month, all features |
| Marketplace / discovery | None | Yes (30% commission) | Limited | Yes (zero commission) |
| Owned storefront | Basic | None | Yes | Full-featured, branded |
| Customer data ownership | Partial | Never | Partial | Full — merchant's CRM |
| Loyalty program | Paid add-on | None | Basic | Built in, Solo+ |
| Email + SMS campaigns | Add-on or not offered | None | Not offered | Built in, Solo+ |
| Staff management | Basic | None | None | Full — PIN auth, roles, KDS |
| Kitchen display | Paid add-on | None | None | Built in, all tiers |
| Reservations | Paid add-on | None | None | Built in, all tiers |
| Appointment booking | No | No | No | Coming Phase 2 |
| Charity contribution | None | None | None | 0.15% of every order |
| Hardware | Proprietary, expensive | N/A | Any browser | Any browser — tablet, phone, laptop |

### Merchant Migration Path

**Step 1 — Run alongside (Solo, $49/month):** Merchant keeps Square for in-person payments, adds Woahh for online orders, CRM, loyalty, email/SMS campaigns. No disruption. Demonstrates value risk-free within 30 days.

**Step 2 — Add discovery (Marketplace, $99/month):** Once the merchant has seen real value from their storefront, they list on `/eat`. The $50/month upgrade is covered the first time a single new customer orders. Square still takes in-person payments but Woahh owns the customer relationship.

**Step 3 — Full replacement:** Add Stripe Terminal to Woahh. In-person payments move off Square. Square relationship ends. Monthly savings from eliminating Square fees ($165/month) more than cover Woahh ($99/month). Merchant is now saving money and owns everything.

---

## 10. Delivery Integration

### Decision: Delivery-as-a-Service via Uber Direct (Built and Live)

Uber Direct is the white-label version of Uber's driver network. The merchant:
- Keeps the customer on their own Woahh storefront
- Charges the customer directly via their own Stripe account
- Pays Uber a flat fee per delivery (~$8–12 AUD) — not a commission
- Keeps 100% of customer data: email, order history, preferences, loyalty points

Woahh orchestrates the dispatch using the merchant's own Uber Direct credentials. Woahh sees zero dollars from delivery.

### Why This Beats Uber Eats — Single Order

| | Uber Eats (marketplace) | Uber Direct (via Woahh) |
|---|---|---|
| Customer pays | $38 | $38 |
| Uber's cut | $9.50 (25% commission) | $9 (flat delivery fee) |
| Stripe fee | — (Uber handles) | $1.17 |
| **Merchant receives** | **$28.50** | **$27.83** |

Per order — effectively identical. The 67¢ difference is noise.

### Why This Beats Uber Eats — Customer Lifetime Value

Assume 12 orders/year at $38 each, from a single customer.

**Via Uber Eats:**
- Merchant receives 12 × $28.50 = **$342/year**
- Customer data belongs to Uber — merchant cannot contact them
- Uber's algorithm promotes competing menus at every checkout
- If the customer churns, the merchant has no way to win them back

**Via Woahh + Uber Direct:**
- Merchant receives 12 × $27.83 = **$334/year** baseline
- Customer is in the merchant's CRM — email, phone, preferences, full history
- Loyalty program drives additional orders (industry avg: 15–20% frequency lift)
- With loyalty: effective annual value ≈ 14 × $27.83 = **$390/year**
- Customer experiences the merchant's brand end-to-end

The $8/year "loss" in raw margin becomes a **$48/year gain** once marketing and retention are factored in. And the merchant owns the asset permanently.

### The Compounding Effect (100 active delivery customers)

| Metric | Uber Eats | Woahh + Uber Direct |
|---|---|---|
| Annual revenue | $34,200 | $39,000 (inc. loyalty lift) |
| Marketing asset value | $0 — Uber's list | CRM of 100 reusable contacts |
| Competitor protection | None — Uber promotes rivals | Total — competitors can't reach them |
| Cost to re-engage churned customer | Impossible | Free — email/SMS |

This is Shopify's entire pitch to e-commerce merchants: "don't rent your customers from Amazon, own them yourself." Woahh's delivery argument is identical, applied to food.

### Woahh's Position in the Money Flow

Nowhere. The merchant's relationship with Uber Direct is entirely their own:
- Merchant registers directly with Uber Direct
- API credentials stored encrypted in Woahh's `courier_credentials` table (strict RLS, row-level encryption)
- Woahh's edge function calls Uber Direct using the merchant's credentials
- Uber invoices the merchant directly
- Woahh handles zero dollars from delivery

This keeps Woahh outside payment facilitator regulation, chargeback exposure, driver tip processing, refund intermediation, and delivery liability.

### Multi-Provider Support (Live)

Courier dispatch supports: Uber Direct, DoorDash Drive, Sherpa (AU-native), Lalamove (APAC). Owner selects enabled providers in KitchenSettings. Auto-dispatch fires when an order moves to `preparing` status.

---

## 11. Go-to-Market Strategy

### Phase 0 — Soft Launch (Now, 3 weeks)
- Brisbane only — personal connections
- 15-25 founding merchants, 2-month free trial, Founding Merchant rate locked permanently
- Goal: first real orders, platform stability, product-market fit signals

### Phase 1 — Brisbane Beachhead (Months 1–4)
- Expand to 50-100 Brisbane merchants via referrals and in-person outreach
- Convert founding merchants to paid after trial
- Retail/shop features live
- First angel/accelerator raise
- Target: $5-10k MRR, >85% monthly merchant retention

### Phase 2 — National (Months 4–12)
- Sydney, Melbourne, Gold Coast
- Seed round: $500k–$2M
- Appointment booking live
- Native iOS/Android apps via Expo
- Target: 300+ merchants, $25-40k MRR

### Phase 3 — International (Months 12–30)
- US entry: Texas or California first
- UK entry
- Delaware C-Corp / flip structure
- Series A: $3-8M
- Target: 1,000+ merchants globally, $100k+ MRR

### Acquisition Strategy

- **Founding merchants:** Personal connections, in-person onboarding, high-touch
- **Phase 1 expansion:** Referrals from founding merchants, in-person strip outreach, local food/lifestyle content
- **Phase 2+:** Paid social (Meta + TikTok), business association partnerships, local council programs, PR on the giving model
- **The giving model as a PR engine:** No competitor donates from every order. This is the press hook, the word-of-mouth hook, and the mission hook simultaneously.

---

## 12. Hardware Strategy

### Phase 0–1: Merchant Sources Own Hardware

Woahh is entirely browser-based — any screen with a browser becomes a terminal. Merchants source their own hardware:

- **Recommended kit:** iPad (any recent model) + Star Micronics receipt printer + Stripe Terminal card reader
- **KDS:** Any Android tablet ($100+) or TV with browser pointed to `/dashboard/kitchen`
- **Cost to merchant:** $200–600 one-time, no per-device fees, no proprietary lock-in

Woahh co-founders configure the software in person during founding merchant onboarding.

### Phase 2: Woahh Kit (Post-Investment)

A pre-configured hardware bundle available as a monthly lease add-on or one-time startup fee:
- iPad or Android tablet — Woahh PWA auto-launches on boot, locked to screen
- Receipt printer paired and configured
- Stripe Terminal paired for in-person payments
- Sourced in bulk, reduces per-unit cost

Lease cost is recoverable through merchant LTV. Not given away — always a lease or purchase agreement.

**The competitive angle:** Square requires proprietary hardware and charges for it. Woahh's hardware is optional, affordable, and uses off-the-shelf components the merchant can source independently if they prefer.

---

*This document reflects the state of Woahh as of April 2026. Update whenever a major product, financial, or strategic decision changes. See `MASTER_PLAN.md` for the sprint plan, phase timelines, funding targets, and legal checklist.*
