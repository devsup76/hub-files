# GrowthHub — Business Strategy & Financial Decisions

> **Purpose:** This document captures key legal, financial, and strategic decisions made during the planning of GrowthHub. It is intended to be shared with advisors, investors, partners, or co-founders to provide context and rationale behind each decision.
>
> Last updated: 2026-04-22

---

## Table of Contents

1. [Company Mission & Philosophy](#1-company-mission--philosophy)
2. [Payment Processing](#2-payment-processing)
3. [Subscription Pricing Model](#3-subscription-pricing-model)
4. [Revenue Projections](#4-revenue-projections)
5. [Infrastructure Costs & Scalability](#5-infrastructure-costs--scalability)
6. [GMV Tracking & Charitable Giving](#6-gmv-tracking--charitable-giving)
7. [Competitive Positioning](#7-competitive-positioning)
8. [Delivery Integration](#8-delivery-integration)

---

## 1. Company Mission & Philosophy

**What GrowthHub is:**
A multi-tenant SaaS platform for small business owners — restaurants and retail shops — providing two genuinely distinct value propositions under one flat monthly subscription:

1. **"Your own digital presence"** — branded storefront, orders, kitchen display, CRM, loyalty, SMS/email campaigns, reservations, and tables. The full tech stack that Dominos and Shake Shack have, available to a café at $49/month.
2. **"Discovery marketplace"** — the public `/eat` directory, zero-commission, where customers find new businesses. The alternative to Uber Eats that doesn't take 25–30% of every order.

These two axes are priced as a natural upgrade path. Not every business needs both — a reservation-only fine dining restaurant doesn't want to be on a public discovery page. GrowthHub respects that distinction.

**Financial philosophy:**
The goal is not maximum extraction from merchants. The intent is to build a sustainably profitable business that generates enough wealth to support the team and fund charitable causes, while genuinely helping small businesses grow. Pricing decisions reflect this — we do not charge per-transaction fees on top of subscriptions, and we do not impose volume caps that penalise business growth.

**Charity model:**
A percentage of platform-wide GMV (gross merchandise value processed through GrowthHub) will be donated to charitable causes. This is tracked automatically through our orders system. Every merchant's dashboard will show their individual contribution — e.g. "Your $28,400 in orders this month contributed $28 to [cause]". This is not a marketing gimmick; it is a structural commitment built into the platform from day one.

---

## 2. Payment Processing

### Problem
GrowthHub competes with Square, Toast, and Clover — all of which bundle payment processing with software. We needed to decide: do we become a payment processor, partner with one, or stay payment-agnostic?

### Options Evaluated

| Option | Model | Pros | Cons |
|---|---|---|---|
| **Stripe Connect Express** | GrowthHub is a payment platform; takes a cut of every transaction | Revenue from 0.3% platform fee at scale; automated splits; Stripe handles KYC | AUSTRAC registration likely required; dispute liability exposure; operational burden at scale; platform account freeze risk if a merchant commits fraud |
| **Stripe Standard** | Each merchant owns their Stripe account; GrowthHub is not in the payment flow | Zero regulatory exposure; zero compliance overhead; merchants handle all disputes | Cannot take a per-transaction fee; less integrated experience |
| **Stripe Connect + 0.3% fee** | Platform model with platform fee built into every charge | Significant revenue at scale ($90k/month at 5,000 merchants) | Requires compliance hire, AUSTRAC filing, and legal review — unsuitable for a 5–8 person team in early stages |
| **Tyro** (AU-specific) | Australian EFTPOS terminal integration | Dominant in Australian hospitality (~30% of restaurants); competitive local rates | In-person only; no online payment rails; harder developer experience |
| **Adyen** | Enterprise interchange++ pricing | Cheapest at massive scale ($50M+ GMV/month) | Minimum volume requirements; months-long onboarding; not viable at startup stage |
| **Square / Braintree** | Competitor / PayPal product | — | Square is a direct competitor; integrating their rails creates a dependency on a company actively trying to retain the same customers |

### Decision: Stripe Standard for Phase 1

**Rationale:**
A 5–8 person team cannot responsibly take on PayFac (payment facilitator) obligations at scale. Under Australia's AML/CTF Act 2006, operating as a payment facilitator likely requires AUSTRAC registration, appointment of a compliance officer, an AML/CTF program document, and annual reporting. This is manageable at scale but distracts from product development when the team is small.

Stripe Standard means:
- Merchants connect their own Stripe account
- All payment disputes, chargebacks, and compliance are between the merchant and Stripe
- GrowthHub has zero exposure to payment fraud or liability
- No AUSTRAC obligation
- Implementation takes 1–2 weeks vs 4–6 weeks for Connect

**Phase 2 (when viable):** Migrate to Stripe Connect Express once platform GMV exceeds ~$5M/month. At that point the 0.3% platform fee generates ~$15,000/month — enough to fund a compliance hire and the operational overhead. The migration path is straightforward.

**Tyro:** Offered as an optional integration for restaurants already using Tyro EFTPOS terminals, removing a switching objection without forcing hardware replacement.

### Fee Breakdown on a $30 Order

| Payment type | Customer pays | Stripe fee | Owner receives |
|---|---|---|---|
| Online (card not present) | $30.00 | $1.17 (2.9% + 30¢) | $28.83 |
| In-person (Stripe Terminal) | $30.00 | $0.86 (2.7% + 5¢) | $29.14 |

**Comparison to Square:** Square charges 2.6% + 10¢ in-person ($0.88 on $30) and 2.9% + 30¢ online ($1.17 on $30). The difference is negligible — less than 2¢ per transaction. The meaningful difference is that Square charges additional monthly software fees on top, while GrowthHub's subscription covers all features at a flat rate.

### Legal Considerations

- **AUSTRAC:** Not required under Stripe Standard. Required if we move to Stripe Connect. When we make that transition, we will engage a compliance-as-a-service provider (e.g. AML Shield or Comply Advantage) and register with AUSTRAC.
- **AFSL:** Stripe's own Australian Financial Services Licence covers platforms operating under Stripe Standard. Stripe Connect may require separate legal review — we will obtain this before Phase 2.
- **Australian Privacy Act:** Applicable now. GrowthHub stores customer data (names, emails, order history) on behalf of merchants. Privacy policy and data processing agreements will be required.

---

## 3. Subscription Pricing Model

### The Two-Axis Structure

The original tier model was a single-axis feature ladder (Starter → Growth → Scale). Adding the `/eat` public marketplace creates a second axis: **own presence** vs **discovery**. The pricing model was rebuilt to reflect this.

### Decision: Feature-Based Tiers, No GMV Caps (retained)

GMV caps were removed entirely. Tracking GMV to enforce tier limits creates significant operational overhead (grace periods, alerts, enforcement, support tickets) that a small team cannot manage cleanly. Penalising a merchant for a busy Christmas period is hostile to the customer relationship.

GMV is still tracked internally through the orders table — but purely to power charitable giving reports and impact dashboards. It is never used for billing decisions.

### Tier Structure

| Plan | Monthly Price | Target customer | What's included |
|---|---|---|---|
| **Solo** | $49/month | Single-location business that wants their own full-stack presence without marketplace listing | Full dashboard: orders, KDS, products, CRM, loyalty, email/SMS, reservations, tables, branding. Single location. **Not listed on the /eat marketplace.** |
| **Marketplace** | $99/month | Business that wants discovery alongside their own presence | Everything in Solo + listed on `/eat` (zero commission), badge system, paid promotions, up to 3 locations. |
| **Growth** | $199/month | Scaling or multi-location operator | Everything in Marketplace + unlimited locations, priority placement in `/eat` search, advanced analytics, API access, custom domain support (PWA-ready). |
| **Enterprise** | Custom | Chains, franchises, multi-location groups | White-label, dedicated support, volume pricing, negotiated terms. |

**Free trial:** 60 days of full Marketplace-tier access. No credit card required to start.

### Why the Solo Plan Is Not Just a Price Anchor

The Solo plan exists for a real market segment:
- High-end restaurants that are reservation-only and fully booked — they don't need more traffic, they need better operations
- B2B caterers or event companies — their customers are businesses, not random browsers
- Private members clubs and invitation-only dining
- Restaurants in small towns where everyone already knows them

Forcing these businesses onto a public directory they don't want is a dealbreaker. Respecting this distinction is how GrowthHub wins those accounts.

### The "App of Your Own" Opportunity (Growth Tier)

The Growth plan at $199/month unlocks what approximates a native app experience, without building native apps:

1. **Custom domain support** — `order.bellasbistro.com.au` points to their GrowthHub storefront. Looks like their own website. This is what Shopify Plus charges thousands for.
2. **PWA (Progressive Web App)** — Customers can "Add to Home Screen" on iPhone/Android. Full-screen icon with their logo, works offline. This IS an app — customers can't tell the difference from a native app.
3. **Push notifications** — Direct to customers who've installed their "app." "Your order from Bella's is ready."

Billion-dollar restaurant tech stack, available to a café at $199/month.

### Why This Pricing Is Competitive

Square for Restaurants charges $60–$165/month for software alone, before transaction fees. Uber Eats charges 25–30% commission per order with no storefront or CRM.

**The pitch:**
> "Square gives you a payment system. Uber Eats lists you in their directory and takes 30%. GrowthHub gives you your own full-stack presence — website, app, loyalty, CRM, kitchen display — AND lists you on our zero-commission marketplace where you keep every dollar. Starting at $49 a month."

No competitor offers both axes. Square/Toast have no marketplace. Uber Eats/DoorDash have no merchant-owned storefront. GrowthHub bridges both.

---

## 4. Revenue Projections

### Assumptions
- Tier distribution: 45% Solo ($49), 40% Marketplace ($99), 10% Growth ($199), 5% Enterprise (~$300 blended)
- Weighted average revenue per merchant: ~$95/month
- Figures are subscription revenue only — excludes any future payment processing fee revenue
- Infrastructure costs are estimates; SMS costs are the primary variable expense

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

**Net margin: 94–97%.** This is achievable because infrastructure costs are near-flat (CDN hosting) or scale in small steps (database), not proportionally with merchant count.

### Infrastructure Cost Breakdown

| Cost item | Small (100 merchants) | Medium (1,000) | Large (5,000) | What drives the cost |
|---|---|---|---|---|
| Supabase (DB + functions) | $25/mo | $200/mo | $800/mo | DB size, edge function calls, realtime connections |
| Resend (email sending) | $20/mo | $90/mo | $400/mo | Emails sent per month across all merchants |
| Clicksend (SMS) | $150/mo | $1,500/mo | $7,500/mo | SMS messages sent — main variable cost |
| Stripe billing fees | $42/mo | $420/mo | $2,100/mo | 0.5% of subscription revenue |
| Lovable (builder + hosting) | $50/mo | $50/mo | $100/mo | Near-flat; CDN hosting of the React frontend |

**SMS is the dominant variable cost.** At scale, Clicksend volume pricing negotiation is a priority. SMS is only available on Growth tier and above, and each org has a monthly cap — limiting exposure.

### Phase 2 Revenue (Stripe Connect, future)
When migrated to Stripe Connect Express with a 0.3% platform fee — of which 0.15% is donated to charity and 0.15% is retained by GrowthHub:

| Platform GMV/month | 0.3% total fee | 0.15% to charity | 0.15% net to GrowthHub |
|---|---|---|---|
| $500k | $1,500/mo | $750/mo | $750/mo |
| $5M | $15,000/mo | $7,500/mo | $7,500/mo |
| $50M | $150,000/mo | $75,000/mo | $75,000/mo |

The net 0.15% to GrowthHub becomes the dominant revenue stream at scale, exceeding subscription revenue — the same model used by Shopify and Toast. The matched 0.15% to charity means GrowthHub's transaction revenue growth is mirrored dollar-for-dollar by charitable impact growth.

---

## 5. Infrastructure Costs & Scalability

### How Lovable Hosting Works

GrowthHub is built on Lovable (an AI application builder). The frontend is a React single-page application compiled into static HTML, CSS, and JavaScript files. These are served from a CDN (content delivery network).

**A CDN does not scale costs with user count.** Whether 10 or 100,000 users visit the storefront, the CDN cost is essentially flat. There are no "bigger servers" to provision as user traffic grows.

The real infrastructure is **Supabase**, which provides:
- PostgreSQL database (scales with data volume, not request count)
- Authentication (scales with monthly active users)
- Edge Functions (scales with invocation count — SMS sends, email sends, etc.)
- Realtime subscriptions (scales with concurrent connections — orders page, kitchen display)
- File storage (scales with files stored — logos, images)

Supabase Pro at $25/month comfortably handles ~500 merchants. Beyond that, compute add-ons are purchased in increments of $10–50/month. There is no manual server management.

### Multi-Product Scalability

GrowthHub is architected for multiple product lines (e.g. shop mode, appointment mode, future verticals). If these run on the same Supabase project, they share infrastructure at no additional cost. Separate Supabase projects cost ~$25/month each — negligible at our scale.

---

## 6. GMV Tracking & Charitable Giving

### Structure

Every order created through GrowthHub contains a monetary value. The cumulative monthly GMV per merchant is tracked automatically in the database — the same infrastructure already used to track SMS and email usage caps. No merchant reporting is required. No additional infrastructure needs to be built beyond a monthly counter and a reset function.

### Donation Model

GrowthHub will donate a percentage of total platform-wide GMV to charitable causes. Proposed rate: **0.1% of platform GMV**.

| Platform GMV/month | Monthly donation at 0.1% |
|---|---|
| $500k (100 merchants avg $5k each) | $500 |
| $5M (500 merchants) | $5,000 |
| $50M (2,000 merchants) | $50,000 |

### Merchant Visibility

Each merchant's dashboard will display:
- Their total GMV processed through GrowthHub this month
- Their proportional charitable contribution ("Your orders this month contributed $X to [cause]")

A public impact page will show aggregate platform GMV and total donated to date.

Merchants will be able to display a "GrowthHub Impact Partner" badge on their storefront — connecting their customers to the charitable story.

### Public Transparency Portal

All charitable activity will be publicly verifiable — anyone can confirm GrowthHub's claims without taking our word for it. Planned in three phases:

**Phase 1 — Public `/impact` dashboard (early priority)**
A public page requiring no login. Shows real-time platform GMV, total donated to date, monthly and per-charity breakdowns, and charity receipt PDFs sourced from the receiving organisation (not GrowthHub). Includes a public feedback form for anyone who believes a figure is wrong — submissions are posted as issues to a public GitHub repository so both the concern and GrowthHub's response are on record.

**Phase 2 — Blockchain timestamping (within first year)**
Each month, after donations are made, GrowthHub hashes the full donation ledger and publishes that hash to a public blockchain (Ethereum, Polygon, or Bitcoin OP_RETURN — costs cents per entry). The dashboard links every monthly record to its on-chain proof. Anyone can hash the displayed data themselves and confirm it matches the chain entry, proving the records are authentic and unaltered.

**Phase 3 — On-chain donation flow (at scale, $50k+/month)**
Convert donation amounts to USDC and distribute directly to charity wallets via a public smart contract. Every transfer is visible on a block explorer — impossible to fake. Requires partner charities to accept crypto (via The Giving Block or equivalent) and legal review of AML implications.

The public GitHub issue tracker for concerns turns accountability into a visible, ongoing demonstration of good faith rather than a liability to manage privately.

### Why This Is Strategically Valuable

No competitor (Square, Toast, Clover, Lightspeed) donates any portion of merchant sales volume to charity. This creates:
- Genuine differentiation that cannot be easily copied without cultural commitment
- Word-of-mouth acquisition — merchants tell other merchants
- Press and partnership opportunities that a pure-software pitch cannot access
- A reason for mission-aligned merchants (cafes, local restaurants, independent retailers) to actively prefer GrowthHub

### Legal Structure (Charity)

The charitable giving arm will operate as a structurally separate entity from the GrowthHub SaaS business. This avoids:
- Mixing for-profit and nonprofit payment flows (AML complexity)
- ACNC registration requirements applying to the SaaS business
- Tax implications of co-mingled revenue

The SaaS entity transfers a calculated donation amount monthly to the charitable entity or directly to registered charities. If the charitable entity seeks DGR (Deductible Gift Recipient) status in Australia for tax-deductible donations, it must register separately with the ACNC and meet ATO requirements.

---

## 7. Competitive Positioning

### The Core Problem We Solve

Most small business owners use Square/Toast for their POS or Uber Eats/DoorDash for discovery. These are single-axis tools:
- **Square/Toast:** Great POS, no marketplace. Charges 2.6–2.9% per transaction plus monthly software. No discovery mechanism.
- **Uber Eats/DoorDash:** Great discovery, no owned storefront. 25–30% commission per order. Merchant never owns the customer relationship.

GrowthHub is two-axis: own presence + marketplace discovery, under one flat monthly subscription.

A restaurant doing $50,000/month in sales on Square pays approximately:
- $1,310/month in transaction fees (2.6% + 10¢)
- $165/month for Square for Restaurants Plus (loyalty, advanced features)
- **Total: $1,475/month, scaling indefinitely as revenue grows**

The same restaurant on GrowthHub's Marketplace plan pays **$99/month flat**, routes payments through their own Stripe account at standard Stripe rates, and also gets listed on `/eat` for zero commission.

### GrowthHub's Two-Axis Position

| Factor | Square / Toast | Uber Eats / DoorDash | GrowthHub |
|---|---|---|---|
| Transaction fees | 2.6–2.9% forever | N/A (they handle payment) | None (merchant uses Stripe directly) |
| Software cost | $60–$165/month + add-ons | None | $49–$199/month, all features included |
| Marketplace / discovery | None | Yes (30% commission) | Yes (zero commission, Marketplace+) |
| Owned storefront | Basic | None | Full-featured, branded |
| Customer data ownership | Partial | Never (Uber owns it) | Full — in merchant's CRM |
| Hardware requirement | Proprietary terminals | N/A | Any browser — tablet, phone, laptop |
| Loyalty program | Paid add-on | None | Included on Solo+ |
| Email marketing | Paid add-on | None | Included on Solo+ |
| SMS campaigns | Not offered | None | Included on Solo+ |
| Charity contribution | None | None | 0.1% of GMV donated |

**The pitch:** "Square gives you a payment system. Uber Eats lists you in their directory and takes 30%. GrowthHub gives you your own full-stack presence — website, app, loyalty, CRM, kitchen display — AND lists you on our zero-commission marketplace where you keep every dollar. Starting at $49 a month."

### Migration Strategy (Three Phases)

**Phase 1 — Run alongside (Solo, $49/month):** Merchant keeps Square for in-person payments, signs up to GrowthHub Solo for online orders, marketing, loyalty, and CRM. No disruption to existing operations. Demonstrates value risk-free.

**Phase 2 — Add discovery (Marketplace, $99/month):** Once the merchant has seen GrowthHub value from their own storefront, they upgrade to Marketplace and list on `/eat`. The $50/month upgrade cost is covered the first time a single new customer places an order. Square is still taking payments but GrowthHub owns the customer.

**Phase 3 — Full replacement:** Stripe Terminal added to GrowthHub. In-person payments move off Square. Square relationship ends. Monthly savings from eliminating Square software fees ($165/month) more than cover GrowthHub's cost ($99/month).

### Hardware Reality

The common objection: "We need 2–3 iPads to run Square." GrowthHub is browser-based. A $100 Android tablet running the kitchen display, a phone for order taking, and any screen for the dashboard. No proprietary hardware. No per-device fees.

---

---

## 8. Delivery Integration

### Problem
Small restaurants have two bad options for offering delivery:
1. List on marketplace apps (Uber Eats, DoorDash, Deliveroo) — lose 20–30% of every order to commission, and lose the customer relationship entirely
2. Run their own driver fleet — impossible at small scale

Most simply don't offer delivery, or accept marketplace terms as unavoidable.

### Decision: Delivery-as-a-Service via Uber Direct

Uber Direct is the white-label version of Uber's driver network. The merchant:
- Keeps the customer on their own GrowthHub storefront
- Charges the customer directly via their own Stripe account
- Pays Uber a **flat fee per delivery** (~$8–12 AUD), not a commission
- Keeps 100% of customer data — email, order history, dietary preferences, loyalty

GrowthHub orchestrates the API calls using the merchant's Uber Direct credentials. We never touch the money.

### Why This Beats Being on Uber Eats — Single Order

| | Uber Eats (marketplace) | Uber Direct (via GrowthHub) |
|---|---|---|
| Customer pays | $38 | $38 |
| Uber's cut | $9.50 (25% commission) | $9 (flat delivery fee) |
| Stripe fee | — (Uber handles) | $1.17 |
| **Merchant receives** | **$28.50** | **$27.83** |

Per order — effectively identical. 67¢ difference is noise.

### Why This Beats Uber Eats — Customer Lifetime

This is where the real difference lives.

Assume a customer places 12 orders/year at $38 each.

**Via Uber Eats:**
- Merchant receives 12 × $28.50 = **$342/year** from that customer
- Customer's email/phone belongs to Uber — merchant cannot contact them directly
- Uber's algorithm shows that customer competing menus at checkout
- If the customer stops ordering, merchant has no way to win them back
- Customer experiences Uber's branding, not the merchant's

**Via GrowthHub + Uber Direct:**
- Merchant receives 12 × $27.83 = **$334/year** directly
- Customer is in the merchant's CRM — email, phone, preferences, full history
- Merchant can send email/SMS campaigns ("new menu item", "loyalty reward", "we miss you")
- Loyalty program drives additional orders (industry avg: 15–20% frequency lift)
- With loyalty engagement, effective annual revenue ≈ 14 × $27.83 = **$390/year**
- Customer experiences the merchant's brand end-to-end, not Uber's

The $8/year per-customer "loss" in raw margin becomes a **$48/year gain** once marketing and retention are factored in. And the merchant owns the asset.

### The Compounding Effect

At 100 active delivery customers:

| Metric | Uber Eats | GrowthHub + Uber Direct |
|---|---|---|
| Annual revenue from those 100 | $34,200 | $33,400 base + ~$5,600 loyalty lift = **$39,000** |
| Marketing asset value | $0 (Uber's list) | CRM of 100 customers — reusable for every campaign |
| Protection from competitors | None — Uber promotes rivals | Total — competitors can't reach them |
| Cost to re-engage a churned customer | Can't — no contact | Free — email/SMS |

This is Shopify's entire pitch to e-commerce merchants: "don't rent your customers from Amazon, own them yourself." GrowthHub's delivery pitch is the identical argument applied to food.

### Where GrowthHub Sits in the Money Flow

Nowhere. Identical to the Stripe Standard stance:

- Merchant signs up directly with Uber Direct — their own account, their own billing
- Merchant's Uber Direct API credentials live encrypted in their GrowthHub org settings
- Our edge function calls Uber Direct's API *using the merchant's credentials*
- Uber invoices the merchant directly (weekly or monthly batched billing)
- GrowthHub sees zero dollars from delivery

This keeps us outside:
- Payment facilitator regulation (AUSTRAC obligations)
- Chargeback and dispute handling
- Driver tip processing
- Refund intermediation
- Insurance and liability for delivery incidents

We are software. The merchant's relationship with Uber is their own.

### Merchant Onboarding Flow

1. Merchant signs up at `direct.uber.com` (or equivalent — DoorDash Drive, Sherpa, Lalamove)
2. Receives API key + webhook secret from Uber
3. Pastes both into GrowthHub → Operations → Delivery Integration
4. GrowthHub stores credentials encrypted (row-level encryption via a dedicated `courier_credentials` table with strict RLS)
5. Done. Future delivery orders auto-dispatch a courier when the kitchen starts preparing.

### Phased Rollout

- **Phase 1 (now):** Build the infrastructure — DB columns, credentials storage, Operations UI, edge functions, customer-facing tracking. Demo mode shows the full flow with mock driver data. No Uber business agreement required yet.
- **Phase 2 (when first merchant onboards):** First merchant pastes real Uber Direct credentials, real deliveries flow. No code changes on our end.
- **Phase 3:** Multi-provider abstraction — add DoorDash Drive, Sherpa (AU-native), Lalamove (APAC). Owner selects which provider(s) to enable, smart routing picks cheapest/fastest per delivery.

### What This Unlocks Strategically

- A credible delivery offering without requiring merchants to use Uber Eats
- The "ditch the marketplace" pitch becomes concrete and easy to execute
- Merchants can show their customers "order direct and save us 25% vs Uber Eats" messaging — customer-facing differentiation
- GrowthHub becomes the central nervous system of the merchant's business: orders, customers, marketing, loyalty, kitchen, and now delivery — all under one flat subscription

---

*This document reflects decisions made as of 2026-04-23. It should be updated as pricing, legal requirements, or strategy evolves.*
