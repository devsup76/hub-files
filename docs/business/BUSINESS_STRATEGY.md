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
The goal is not maximum extraction from merchants. The intent is to build a sustainably profitable business that generates wealth to support the team and fund charitable causes, while genuinely helping small businesses grow. Pricing reflects this — commission is set at 2% on the merchant + 1% on the customer (3% gross online, vs. 30% industry standard), no volume caps that penalise growth, and half of all commission goes directly to charity.

> **Model base (updated 2026-06-02):** 2% merchant + 1% customer = 3% gross online (2% in-person); half to charity, half to Woahh. Average GMV assumption **$15,000/merchant/month**. Subscription prices unchanged ($49/$89/$150), split 50/50 with charity. All figures below use this base.

**The giving model:**
2% merchant commission + 1% customer service fee on online orders (3% gross). Half of each goes to charity. Half to Woahh. At scale this means ~1.5% of every online dollar (1% in-person) processed through Woahh goes to charity — automatically, publicly, and verifiably. Every merchant's dashboard shows their individual charitable contribution. A public `/impact` page shows the full donation ledger. No competitor does this at any percentage. It is a structural commitment built into the transaction layer from day one, not a marketing gimmick.

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

**Co-founders agreement:** Signed May 2026. Shareholders agreement to be completed before launch.

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

### Decision: Phased Stripe Connect Approach

Two distinct phases. The model changes once the platform has proven itself with founding merchants — not before, and not after.

**Phase 1 — Founding merchants: Stripe Connect Express (pass-through)**
- Customer pays at checkout — Woahh never holds funds
- `application_fee_amount: 0` for founding merchants = zero commission, always
- Merchant receives their share immediately; Stripe handles disputes
- No AFSL or AUSTRAC engagement required
- Works today, zero implementation complexity beyond basic Connect integration

**Phase 1 paid launch onwards — Stripe Connect Custom (fund-holding)**
- Woahh holds the full payment in merchant connected accounts before disbursing
- Configurable payout delay (T+1 or T+2) creates a dispute/refund buffer
- Woahh controls charity allocation timing and recipient selection
- Application fees flow into Woahh's Stripe balance; transferred to charity on a weekly or monthly schedule
- Woahh owns the payout UX — merchants see their balance in the dashboard, not a Stripe dashboard
- **Does NOT require Woahh's own AFSL** — Woahh operates under Stripe Payments Australia Pty Ltd's AFSL as a platform. Written confirmation from Stripe Australia required before go-live.
- Requires: Stripe Connect Custom application + Stripe review (allow 2–4 weeks); backend connected account creation per merchant; payout webhook handling

**Implementation timeline:**
- Week 2 (launch sprint): Integrate Connect Express, test end-to-end with founding merchants
- In parallel: Apply for Connect Custom; request written AFSL coverage confirmation from Stripe Australia
- Phase 1 paid launch: All new paying merchants on Connect Custom; founding merchants stay on Express with `application_fee_amount: 0` forever

### Options Evaluated

| Option | Model | Pros | Cons |
|---|---|---|---|
| **Stripe Connect Express (founding merchants)** ✓ | Pass-through split at charge | Works immediately; no AFSL; Stripe handles KYC + disputes | No fund control; can't delay payouts; charity allocation reactive not proactive |
| **Stripe Connect Custom (paying merchants)** ✓ | Woahh holds + disburses | Full payout control; dispute buffer; charity allocation on schedule; Woahh owns UX | 2–4 week Stripe approval; backend work required; need Stripe AU written AFSL confirmation |
| **Stripe Standard** | Merchant owns Stripe account | Zero regulatory exposure | Cannot take a platform fee at all |
| **Full AFSL fund-holding** | Woahh licensed financial service | Total control | 12+ months, $50k+ legal process — not viable until significant scale |
| **Tyro** (AU-specific) | EFTPOS terminal integration | ~30% of AU restaurants already on Tyro | In-person only; no online rails; optional add-on only |
| **Adyen** | Enterprise interchange++ pricing | Cheapest at $50M+ GMV/month | Minimum volumes; months-long onboarding |
| **Square / Braintree** | Competitor / PayPal product | — | Square is a direct competitor; creates dependency on a rival |

### Fee Breakdown on a $30 Order

**The 1% customer service fee applies to online orders only — not in-person (dine-in, counter pickup, POS walk-in). Customers at the counter see no service fee. The merchant absorbs only their 2% commission.**

| | Customer pays | Stripe fee | Woahh gross | → Charity | → Woahh net | Merchant receives |
|---|---|---|---|---|---|---|
| Online (domestic card) | $30.30 | $0.82 (1.7% + 30¢) | $0.90 (3%) | $0.45 (1.5%) | $0.45 (1.5%) | $28.58 |
| In-person (Stripe Terminal) | $30.00 | $0.55 (~1.7% + 5¢) | $0.60 (2%) | $0.30 (1%) | $0.30 (1%) | $28.85 |

*Online: customer pays $30 + $0.30 service fee; merchant commission = $0.60; service fee = $0.30; Woahh gross = $0.90; half each to charity and Woahh net.*

*In-person: customer pays $30 only; merchant commission = $0.60; no customer service fee; Woahh gross = $0.60; half each to charity and Woahh net.*

**Comparison to Uber Eats (same $30 order):**
Uber Eats takes 30% = $9.00. Merchant receives $21.00 and owns zero customer data.
Woahh's merchant commission is 2% = $0.60. Merchant receives $28.58 and owns the customer forever.
**Woahh costs the merchant ~93% less than Uber Eats on every single order.**

**Comparison to Square:** Square charges 2.2% online ($0.66 on $30) + $165/month software. Woahh's merchant commission is just $0.60 on the same order — and it includes a marketplace, CRM, loyalty, campaigns, and a $0.45 automatic charitable contribution that Square cannot match.

### Legal Considerations

- **AFSL:** Stripe Payments Australia Pty Ltd holds the AFSL. Woahh operates as a platform under it — no separate AFSL required for either Connect Express or Connect Custom, provided Woahh stays within Stripe's permitted platform use case. **Action required: obtain written confirmation from Stripe Australia before first live transaction under Connect Custom.**
- **AUSTRAC:** Not required at launch. Pass-through model (Express) is clearly outside remittance dealer scope. Connect Custom (platform holding funds pending payout) should be reviewed by a payments lawyer before scale — engage 3–6 months before AUSTRAC's digital currency threshold is relevant. Start with AML Shield or Comply Advantage.
- **Australian Privacy Act:** Applicable now. Woahh stores customer data on behalf of merchants. Privacy policy and Data Processing Agreements required before launch.
- **Founding merchant zero-commission:** Enforced via `application_fee_amount: 0` in Stripe — not a separate legal construct. The signed one-page agreement is the binding document; Stripe config is just the technical expression of it.

### Commission + Subscription Revenue at Scale

| Platform GMV/month | 3% gross commission | → Charity (1.5%) | → Woahh net (1.5%) | Sub MRR (half to Woahh) | **Total Woahh revenue/mo** | **Total charity/mo** |
|---|---|---|---|---|---|---|
| $150k (10 merchants) | $4,500 | $2,250 | $2,250 | ~$445 | **~$2,695** | **~$2,695** |
| $1.5M (100 merchants) | $45,000 | $22,500 | $22,500 | ~$4,450 | **~$26,950** | **~$26,950** |
| $7.5M (500 merchants) | $225,000 | $112,500 | $112,500 | ~$22,250 | **~$134,750** | **~$134,750** |
| $15M (1,000 merchants) | $450,000 | $225,000 | $225,000 | ~$44,500 | **~$269,500** | **~$269,500** |
| $75M (5,000 merchants) | $2,250,000 | $1,125,000 | $1,125,000 | ~$222,500 | **~$1,347,500** | **~$1,347,500** |

*GMV assumption: **$15k/month per merchant** (online/processed-through-Woahh volume). Blended subscription avg ~$89/month; half (~$44.50) to Woahh, half to charity. Commission is the dominant revenue stream — same model as Stripe and Shopify Payments. At 5,000 merchants: **~$16.2M/year to charity.** Capturing full in-store GMV via POS (3–4× the online volume) raises every row proportionally.*

**Founding merchant carve-out:** First 20–25 merchants locked at zero commission permanently. On $15k/month GMV each, this forgoes ~$225/month net per founding merchant (~$4,500–5,625/month total). Founding merchants still pay subscriptions — half of which goes to charity. The deliberate cost of the early adoption strategy.

---

## 5. Subscription Pricing Model

### Decision: Feature-Based Tiers, No GMV Caps

GMV caps were removed entirely. Penalising a merchant for a busy Christmas period is hostile to the customer relationship. GMV is tracked internally for charitable giving and analytics only — never for billing decisions.

### Tier Structure

| Plan | Monthly Price | Charity split | Target customer | What's included |
|---|---|---|---|---|
| **Solo** | $49/month | $24.50 to charity, $24.50 to Woahh | Single-location business wanting full-stack presence without marketplace listing | Orders, KDS, products, email campaigns, reservations, tables, branding, analytics, staff management. 1 location. Not listed on `/eat`. |
| **Marketplace** | $89/month | $44.50 to charity, $44.50 to Woahh | Business wanting discovery alongside their own presence | Everything in Solo + listed on `/eat`, Impact badge, sponsored listings, CRM, loyalty, SMS campaigns, customer notifications. Up to 3 locations. |
| **Growth** | $150/month | $75 to charity, $75 to Woahh | Multi-location operator | Everything in Marketplace + up to 7 locations, priority `/eat` placement, higher SMS/email caps, custom domain (PWA) |
| **Enterprise** | Custom | 50% to charity | Chains, franchises, multi-location groups | Unlimited locations, white-label, dedicated support, volume pricing, negotiated terms |

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

The Growth plan at $150/month delivers a near-native app experience without building native apps:

1. **Custom domain** — `order.bellasbistro.com.au` points to their Woahh storefront. Looks like their own website. Shopify Plus charges thousands for this.
2. **PWA** — Customers "Add to Home Screen" on iPhone/Android. Full-screen icon with their logo. Indistinguishable from a native app.
3. **7 locations** — Ideal for small chains and franchisees growing past a single site.

Billion-dollar restaurant tech stack, available to a café at $150/month.

### The Pitch

> "On every order, everyone chips in. Merchants pay 2% — half to charity. Customers pay 1% — half to charity. Half your subscription goes to charity too. That's ~1.5% of every online dollar processed through Woahh going to causes that matter. Not a feature. The whole model. Uber Eats takes 30% and gives nothing back. Starting at $49 a month."

---

## 6. Revenue Projections

### Assumptions
- Tier distribution: 45% Solo ($49), 40% Marketplace ($89), 10% Growth ($150), 5% Enterprise (~$300 blended)
- Weighted average subscription per merchant: ~$89/month (blended)
- Subscription split: 50% to charity, 50% to Woahh (~$44.50 Woahh, ~$44.50 charity)
- Average GMV per merchant per month: $15,000 (online / processed-through-Woahh volume — ~11 orders/day at $45 AOV; rises 3–4× once POS captures full in-store GMV)
- Commission net to Woahh: 1.5% of GMV (half of 3% gross online)
- Commission to charity: 1.5% of GMV
- Infrastructure costs are estimates; SMS is the primary variable cost
- **Net profit below is PRE-PAYROLL** (infra only). Team/salaries are the real fixed cost — see break-even note.

### Combined Revenue Projection (Subscription + Commission)

| Active merchants | Sub MRR (Woahh half) | Commission net (1.5%) | **Total Woahh revenue** | Infra costs | **Contribution/mo (pre-payroll)** | **Revenue ARR** |
|---|---|---|---|---|---|---|
| 50 | ~$2,225 | $11,250 | **$13,475** | ~$180 | **$13,295** | **$162k** |
| 100 | ~$4,450 | $22,500 | **$26,950** | ~$320 | **$26,630** | **$323k** |
| 250 | ~$11,125 | $56,250 | **$67,375** | ~$650 | **$66,725** | **$808k** |
| 500 | ~$22,250 | $112,500 | **$134,750** | ~$1,400 | **$133,350** | **$1.62M** |
| 1,000 | ~$44,500 | $225,000 | **$269,500** | ~$2,800 | **$266,700** | **$3.23M** |
| 2,000 | ~$89,000 | $450,000 | **$539,000** | ~$5,500 | **$533,500** | **$6.47M** |
| 5,000 | ~$222,500 | $1,125,000 | **$1,347,500** | ~$13,000 | **$1,334,500** | **$16.2M** |

**Contribution margin: ~93% (pre-payroll).** Infrastructure scales near-flat; commission revenue scales with merchant GMV. **The real fixed cost is the team** — these figures are *before* salaries. After a lean team (~$20k/mo early → ~$70–180k/mo at scale), **break-even is ~80–140 merchants** and net margin lands ~55–80% at scale.

*Note: Founding merchants (20–25) are zero-commission. All projections above assume full commission applies — the founding carve-out (~$225/merchant/mo forgone) reduces early numbers. Charity receives an equal amount to Woahh at every scale milestone.*

### Infrastructure Cost Breakdown

| Cost item | Small (100 merchants) | Medium (1,000) | Large (5,000) | What drives the cost |
|---|---|---|---|---|
| Supabase (DB + functions) | $25/mo | $200/mo | $800/mo | DB size, edge function calls, realtime connections |
| Resend (email sending) | $20/mo | $90/mo | $400/mo | Emails sent per month across all merchants |
| Clicksend (SMS) | $150/mo | $1,500/mo | $7,500/mo | SMS messages sent — main variable cost |
| Stripe billing fees | $42/mo | $420/mo | $2,100/mo | 0.5% of subscription revenue |
| Cloudflare Pages (hosting) | ~$0–20/mo | ~$20/mo | ~$50/mo | Near-flat; CDN hosting of the React frontend (off Lovable since 2026-05) |

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
| Merchant commission | 2% per order → 1% Woahh, 1% charity | Online + in-person. Automatic on every order |
| Customer service fee | 1% per order → 0.5% Woahh, 0.5% charity | **Online orders only.** Added at checkout, disclosed as "Platform service fee". In-person orders carry no customer fee. |
| **Online order total** | **1.5% of GMV → charity, 1.5% → Woahh** | Half of every online transaction dollar to charity |
| **In-person order total** | **1% of GMV → charity, 1% → Woahh** | Merchant commission only; no customer-facing fee |
| Subscription | 50% to charity, 50% to Woahh | Solo $49 ($24.50 each), Marketplace $89 ($44.50 each), Growth $150 ($75 each) |
| Voluntary rate | Merchant-configurable above floor | Slider in Donate dashboard |
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

| Factor | Square / Toast | Uber Eats / DoorDash | me&u / Bopple | **Woahh** |
|---|---|---|---|---|
| Commission per order | 2.2–2.9% (processing only) | 15–30% | None / low | **2% merchant + 1% customer** |
| Monthly platform cost ($80k GMV) | ~$1,925 | ~$12,000–24,000 | ~$299–600 | **$1,689** |
| Marketplace / discovery | None | Yes (30% commission) | Limited | **Yes (zero commission)** |
| Owned storefront | Basic | None | Yes | **Full-featured, branded** |
| Customer data ownership | Partial | Never | Partial | **Full — merchant's CRM** |
| Loyalty program | Paid add-on | None | Basic | **Built in, all tiers** |
| Email + SMS campaigns | Add-on or not offered | None | Not offered | **Built in, all tiers** |
| Staff management | Basic | None | None | **Full — PIN auth, roles, KDS** |
| Kitchen display | Paid add-on | None | None | **Built in, all tiers** |
| Reservations | Paid add-on | None | None | **Built in, all tiers** |
| Multi-courier dispatch | No | N/A | None | **Uber Direct + DoorDash + Sherpa** |
| Push notifications (no app) | No | App only | No | **Yes — web push** |
| Unified customer identity | No | No | No | **Yes — cross-merchant account** |
| Appointment booking | No | No | No | **Phase 1 roadmap** |
| Charity contribution | None | None | None | **1.5% of every online order + 50% of subscription** |
| Public giving transparency | None | None | None | **Yes — /impact page** |
| Hardware required | Yes (proprietary) | Smartphone | Tablet | **Any browser** |

### Marketing-Ready Cost Comparison (for Sales and Investor Decks)

**Headline:** "On every order, everyone chips in. Merchants pay 2% — half to charity. Customers pay 1% — half to charity. Half your subscription goes to charity too. Uber Eats takes 30% and gives nothing back."

| Competitor | Their model | Monthly cost on $80k GMV | Annual cost | vs. Woahh annual saving |
|---|---|---|---|---|
| Uber Eats | 30% commission | $24,000 | $288,000 | **$267,732 saved** |
| DoorDash Premier | 30% commission | $24,000 | $288,000 | **$267,732 saved** |
| DoorDash Basic | 15% commission | $12,000 | $144,000 | **$123,732 saved** |
| Square Online + Plus | 2.2% + $165 sub | $1,925 | $23,100 | *Woahh costs ~$2,832 **less** — and includes marketplace, CRM, loyalty, and ~$14,900/yr to charity* |
| me&u | ~$500 sub | $500 | $6,000 | *Woahh costs ~$14,268 more — but includes full feature stack + marketplace + charity model* |
| Bopple | ~$299 sub, 0% | $299 | $3,588 | *Woahh costs ~$16,680 more — but includes marketplace, CRM, campaigns, loyalty, and charity giving* |
| **Woahh** | **2% + 1% customer + $89 sub** | **$1,689** | **$20,268** | — |

*$1,644.50/year of every Woahh merchant's spend goes to charity — none of the competitors above contribute a cent.*

*Key investor talking point: Woahh is categorically cheaper than the platforms that dominate merchant discovery (Uber Eats, DoorDash). Compared to software-only tools (Square, Bopple), Woahh costs slightly more but delivers a marketplace, CRM, loyalty engine, and a charity model that software-only tools cannot replicate at any price.*

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
