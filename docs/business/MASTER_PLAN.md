# Woahh — Master Business & Sprint Plan

> Last updated: 2026-04-29
> Status: Active — update whenever a phase is completed, a key decision changes, or a milestone is hit.

---

## Table of Contents

1. [The Business](#1-the-business)
2. [Team & Roles](#2-team--roles)
3. [3-Week Launch Sprint](#3-3-week-launch-sprint)
4. [Founding Merchant Program](#4-founding-merchant-program)
5. [Product Roadmap](#5-product-roadmap)
6. [Phase Overview](#6-phase-overview)
7. [Funding Strategy](#7-funding-strategy)
8. [Legal & Compliance Timeline](#8-legal--compliance-timeline)
9. [Hardware Strategy](#9-hardware-strategy)
10. [Merchant Support Strategy](#10-merchant-support-strategy)
11. [Marketing Strategy](#11-marketing-strategy)
12. [Key Metrics](#12-key-metrics)

---

## 1. The Business

**What it is:**
Woahh is a full-stack SaaS platform for small business owners — restaurants, retail, and services. It gives independent merchants the tools that only large chains or high-commission platforms have had access to: direct ordering, loyalty, CRM, email/SMS campaigns, marketplace listing, and a built-in giving model — all in one place, no commissions.

**Core value prop:**
Give a small business owner a single dashboard to manage orders, products, customers, loyalty, promotions, and marketing — with a public-facing storefront, marketplace listing, and customer portal included. No commissions, no lock-in, no complexity.

**Differentiator:**
The giving model is the hook no competitor has. Every order processed through Woahh contributes to charity. Every merchant gets a transparent public impact ledger and an Impact Partner badge. This is both a genuine social value and a PR engine that compounds over time.

**Revenue model:**
- Monthly SaaS subscriptions: solo → marketplace → growth → enterprise
- 0.3% GMV fee per order (0.15% to charity, 0.15% net to Woahh)
- Optional hardware lease (Phase 2+)
- Pass-through payments via Stripe Connect — no AFSL required

**Starting point:** Brisbane, personal connections → national → US + UK

---

## 2. Team & Roles

Three co-founders. Each owns their lane completely — no hand-holding between roles.

| Role | Owner | Responsibilities |
|---|---|---|
| CEO + Tech Lead | You | Product vision, strategy, merchant relationships, investor conversations, app development, Lovable prompts, architecture, security |
| Marketing Lead | Co-founder 2 | Social media, content, brand, campaigns, PR, launch, marketing site — fully autonomous |
| Operations | Co-founder 3 | Legal admin, compliance, Xero, support coordination, hardware logistics, processes — picks up overflow wherever needed |

**Note on the CEO + Tech Lead split:**
Lovable removes the bulk of raw development workload, keeping the CEO seat accessible. However, the first hire post-investment should be a developer to pull the technical weight off the CEO so they can focus fully on growth, sales, and fundraising. The Operations co-founder must be fully autonomous on all legal and admin tasks — zero dependency on the CEO.

---

## 3. Three-Week Launch Sprint

Target launch date: mid-May 2026. Soft launch to personal connections and founding merchants only.

---

### Week 1 — Foundation (Apr 29 – May 5)

**Operations (owns all of these):**
- [ ] Register Woahh Pty Ltd via ASIC (asic.gov.au) — $576, 1-3 business days
- [ ] Apply for ABN immediately after company registration (ATO, free, 24-48hrs)
- [ ] Apply for GST registration (ATO — register now, don't wait for $75k threshold)
- [ ] Register business name "Woahh" with ASIC (~$39/yr)
- [ ] Search trademark availability at search.ipaustralia.gov.au — confirm "Woahh" is clear
- [ ] File trademark — IP Australia, 4 classes: 35 (marketplace/retail services), 36 (payment/financial), 38 (SMS/telecommunications), 42 (SaaS/software) — ~$1,000 total
- [ ] Buy domain variants: woahhapp.com, woahhapp.com.au, woahh.app, woahhapp.co
- [ ] Register R&D Tax Incentive activities with ATO (43.5% cash back on eligible dev costs)
- [ ] Get cyber liability + professional indemnity insurance quotes via BizCover

**Tech Lead (CEO):**
- [ ] Complete all remaining app features — done by Friday
- [ ] Send Lovable prompts 1–6 in order (brand rename → error boundary → legal pages → SEO meta → code splitting → PWA manifest)

**Marketing Lead:**
- [ ] Secure @woahhapp on Instagram, TikTok, X, LinkedIn, YouTube — today, before anything is announced
- [ ] Plan launch content strategy and content calendar

**CEO:**
- [ ] Reach out to first 15-20 merchant connections — brief them on the Founding Merchant offer
- [ ] Set onboarding dates in Week 3

---

### Week 2 — Integration & Testing (May 6–12)

**Operations:**
- [ ] ABN and GST registration confirmed
- [ ] Open business bank account (ANZ, CBA, or Westpac startup — requires company registration)
- [ ] Set up Xero — chart of accounts, connect bank
- [ ] Purchase insurance once quotes confirmed
- [ ] Set up business email: hello@, support@, legal@, founders@ woahhapp.com
- [ ] Draft shareholders agreement using AI — all 3 co-founders sign before launch
- [ ] Draft merchant Terms of Service using AI — book a single lawyer session for review before money flows

**Tech Lead (CEO):**
- [ ] Stripe Connect fully integrated and tested end-to-end
- [ ] Security review: manual walkthrough of all auth flows, check all RLS policies, verify no exposed secrets, run OWASP ZAP automated scan
- [ ] Full end-to-end test: merchant signup → menu setup → customer order → payment → payout
- [ ] Fix all bugs identified in testing
- [ ] Set up Apple Developer Program account ($149 USD/yr) — requires company
- [ ] Set up Google Play Console account ($25 USD one-time) — requires company

**Marketing Lead:**
- [ ] Marketing site live on woahhapp.com — full landing page, intense and distinct, not just the app login
- [ ] Social accounts active, first content posted
- [ ] Founding Merchant offer messaging finalised — what they receive, how it is communicated

**CEO:**
- [ ] Shareholders agreement signed by all 3 co-founders
- [ ] Confirm all 15-20 merchant onboarding dates for Week 3
- [ ] Begin pitch deck draft

---

### Week 3 — Soft Launch (May 13–19)

**All hands — merchant onboarding:**
- [ ] Onboard founding merchants in person: menus, branding, settings, first test order
- [ ] Go live — first real orders processed
- [ ] WhatsApp group set up with all founding merchants for direct support
- [ ] On-call rotation between the 3 co-founders during lunch and dinner service — 10-minute response maximum

**Tech Lead (CEO):**
- [ ] Monitor for errors in real time — fix immediately
- [ ] Collect merchant and customer feedback

**Marketing Lead:**
- [ ] Document merchant #1 story — photo, quote, real numbers
- [ ] First social posts featuring live merchants on the platform
- [ ] Push the giving angle — every order = impact. This is the lead message.

**CEO:**
- [ ] Pitch deck drafted and ready for investor conversations
- [ ] ATO R&D Tax Incentive registration confirmed

---

## 4. Founding Merchant Program

- Capped at **20-25 merchants** — do not exceed this or the benefit becomes diluted
- 2 months free trial, startup costs waived
- After trial: locked in at the lowest available rate permanently — "Founding Merchant" status
- Communicated and documented as: *"Founding Merchant — your rate is locked at [amount] permanently"* — not "free for life" language, which creates unstructured legal liability
- In writing via a signed one-page agreement
- What Woahh gets in return: testimonials, referrals, case studies, direct product feedback, social proof for investors

---

## 5. Product Roadmap

### Now — End of Week (Complete before launch)
- All restaurant features finalised
- Lovable prompts 1–6 implemented and live
- Stripe Connect integrated
- Security testing passed
- 6 pending code fixes resolved (see pending-fixes memory)

### Phase 1 — Q3 2026 (Months 1–4)
- Retail / shop features — physical small business ordering and inventory management, giving independents what major chains already have, without high commissions
- Performance and UX polish based on founding merchant feedback
- iOS + Android native apps via Expo (Supabase Realtime on merchant side, push notifications on customer side)
- Multi-location merchant support

### Phase 2 — Q4 2026 (Months 4–8)
- Appointment booking — salons, barbershops, gyms, healthcare, all service verticals
- Woahh hardware kit — sourced, configured, leased or sold as an add-on
- Advanced campaign tools (SMS/email automations, scheduling improvements)
- Professional cybersecurity penetration test (pre-Series A, non-negotiable before handling scale)

### Phase 3 — Q1–Q2 2027 (Months 8–18)
- US + UK localisation — currency, tax, compliance, separate Stripe platform accounts per region
- Enterprise tier
- Ticketing platform — decision point based on resources and market demand at the time
- Third-party integrations: Xero, Google Business, aggregator menu sync (Uber Eats, DoorDash pull)

---

## 6. Phase Overview

### Phase 0 — Soft Launch (Now, 3 weeks)
**Goal:** First real orders processed, founding merchants stable, platform proven

- Brisbane — personal connections only
- 15-25 founding merchants
- Free 2-month trial
- All 3 co-founders handle support directly

---

### Phase 1 — Brisbane Beachhead (Months 1–4)
**Goal:** Density in Brisbane, product-market fit proven, investor-ready metrics

- Expand to 50-100 Brisbane merchants via referrals and in-person outreach
- Convert founding merchants from free trial to paid after 2 months
- Retail features live
- Strong social presence, merchant testimonials, local PR
- Apply to Startmate (check current application cycle immediately)
- Angel investor conversations underway
- Hardware: merchants source their own — provide a recommended list (iPad + Star Micronics receipt printer + Stripe Terminal)
- ATO R&D Tax Incentive claim at tax time

**Target metrics:**
- 50+ active merchants
- $10k+ GMV/month
- $3–8k MRR
- Merchant monthly retention >85%

---

### Phase 2 — National Expansion (Months 4–12)
**Goal:** 3 cities live, first raise closed, retail and appointments live

- Sydney, Melbourne, Gold Coast
- Close angel or seed round: $500k–$2M
- Use of funds: first developer hire, merchant success hire, support hire, hardware kit inventory, paid marketing
- Native apps live on App Store and Google Play
- Woahh hardware kit available for new merchants
- Support transitions to Intercom or Crisp with AI-first response
- US + UK trademarks filed (within 6 months of AU filing — Paris Convention window)
- Delaware C-Corp assessed pre-Series A

**Target metrics:**
- 300+ active merchants nationally
- $25–40k MRR
- Strong case studies across restaurant and retail verticals
- Series A conversations ready

---

### Phase 3 — International Entry (Months 12–30)
**Goal:** US and UK markets open, Series A closed, 1,000+ merchants globally

- US entry — Texas or California first (high small business density, underserved by quality affordable tech)
- UK entry
- Delaware C-Corp / flip structure completed (required for US VC investment)
- Series A: $3–8M
- Full GDPR compliance for EU and UK customers
- Appointment booking fully live across all verticals
- Ticketing platform decision made
- Enterprise tier launched

**Target metrics:**
- 1,000+ merchants globally
- $100k+ MRR
- Series A closed

---

## 7. Funding Strategy

| Round | When | Target Amount | Equity | Use of Funds |
|---|---|---|---|---|
| ATO R&D Tax Incentive | Register now, claim at tax time | 43.5% cash back on dev costs | None | Ongoing offset |
| Advance Queensland Grant | Apply Month 1 | $10–50k | None | Early operational costs |
| Angel Round | Month 1–3 | $250k–$750k | 8–15% | Hardware, ops, marketing, developer hire |
| Accelerator (Startmate / Antler) | Month 2–4 | $75–150k | 7–10% | Capital + network (network worth more than capital) |
| Seed Round | Month 6–10 | $1–3M | 15–20% | National expansion, team, hardware kit at scale |
| Series A | Month 18–24 | $5–10M | Negotiate | International expansion, enterprise, team scale |

**What investors will want to see before writing a cheque:**
- Clear CEO with defined team and signed co-founder agreement ✓
- Active merchants with real GMV flowing
- Merchant retention data (month 2 retention is the key number)
- The giving model story — lead every investor conversation with it
- A clear path to $1M ARR

**Key investor targets (Australia):**
- Blackbird Ventures — largest AU VC, invests from pre-seed
- AirTree Ventures — AU-focused, active at seed
- Square Peg Capital — strong AU presence
- Brisbane Angels, Sydney Angels — for angel round

---

## 8. Legal & Compliance Timeline

### Immediate (Week 1–2)
- Register Woahh Pty Ltd via ASIC
- ABN + GST + business name registration
- Trademark filing — IP Australia (4 classes)
- Domain variants secured
- Shareholders agreement drafted with AI and signed by all 3 co-founders
- Cyber liability + professional indemnity insurance
- Xero set up from first transaction

### Before Money Flows (Week 3)
- Merchant Terms of Service — AI drafted, lawyer reviewed once before signing
- Business bank account open

### Month 1–2
- R&D Tax Incentive registered with ATO
- Advance Queensland grant application submitted
- Apple Developer + Google Play accounts active

### Within 6 Months of AU Trademark Filing
- File US trademark via USPTO (~$250–350/class)
- File UK trademark (~£170/class)
- Paris Convention priority — same AU filing date applies globally

### Pre-Series A
- Delaware C-Corp / flip structure assessed and executed
- All agreements reviewed by a startup lawyer

### Pre-US Launch
- US legal entity established (Delaware C-Corp or subsidiary)
- US Stripe platform account (separate from AU account)
- GDPR-compliant data handling for EU/UK customers
- Localised Terms of Service (Delaware jurisdiction for US)

### International Architecture (Build Now, Execute at Launch)
- Privacy policy written to GDPR standard from day one — costs nothing to do right the first time
- No hardcoded AUD, AU phone formats, or locale strings in the app — all configurable per org
- Data residency: Supabase on AWS ap-southeast-2 (Sydney) for AU. Separate EU-region Supabase project when entering EU/UK.
- Multi-currency support in Stripe architecture — designed to accept USD/GBP when needed

---

## 9. Hardware Strategy

**Phase 0–1 (Now — merchant sources own):**
- Woahh provides a recommended hardware list
- Recommended kit: iPad (any recent model), Star Micronics receipt printer, Stripe Terminal card reader
- Co-founders configure software during in-person onboarding for founding merchants
- Zero capital cost to Woahh — move fast and prove the model first

**Phase 2 (Post-investment — Woahh Kit):**
- Source, configure, and offer hardware as a monthly lease add-on or one-time startup fee
- Pre-configured: Woahh PWA locked to screen, receipt printer paired, auto-launches on boot
- Merchant options: lease the Woahh Kit, or source own hardware and have Woahh configure it
- Hardware lease cost recoverable through LTV — do not subsidise without a lease agreement

**Long term:**
- Fully branded Woahh hardware
- Bulk sourcing reduces unit cost
- Hardware becomes an onboarding advantage and a switching cost

---

## 10. Merchant Support Strategy

| Phase | Approach |
|---|---|
| Phase 0–1 | All 3 co-founders on shared WhatsApp group with merchants. On-call rotation — 10-minute response maximum during lunch and dinner service. |
| Phase 1–2 | Intercom or Crisp with AI-first response. Common issues documented in a runbook. Escalation to founders for anything unresolved. |
| Phase 2 | Dedicated support hire. Documented SLAs. AI handles >70% of tickets. |
| Phase 3+ | Small support team. Contracted call centre for peak hours. Formal SLA guarantees per tier. |

**Critical rule:** Merchants operate during lunch and dinner service. A platform issue at 12:30pm Saturday that goes unanswered for 30 minutes kills that merchant's revenue and kills your relationship with them. The on-call habit must be built from day one and maintained until a proper support structure is in place.

---

## 11. Marketing Strategy

### Pre-Launch
- All social handles secured before any public announcement (@woahhapp)
- Marketing site live on woahhapp.com — high-quality, distinct, not a placeholder
- Founding Merchant offer messaging locked in and tested

### Launch
- Lead with the giving model: *every order on Woahh contributes to something bigger* — no competitor has this and it is genuinely true
- Real merchant faces and real businesses — not stock photos, not mockups
- Brisbane-first positioning: built here, for here
- Urgency: founding merchant spots are capped, first-come

### Phase 1 (Brisbane)
- Merchant stories: before/after, real GMV numbers, real impact stats
- UGC from merchants and customers — encourage and reshare
- Local food and lifestyle content creators and community pages
- Weekly public impact stats (total donations, causes supported) — feeds the narrative
- Google Business integration for merchants drives discoverability

### Phase 2 (National)
- National PR push — the giving model is the press hook
- Paid social (Meta + TikTok) targeted at small business owners
- Business association partnerships (chamber of commerce, local councils)
- App Store optimisation for organic discovery

### Phase 3 (International)
- Localised content and influencer partnerships per market
- US small business community outreach (high engagement, underserved)
- The impact/giving angle works universally — do not strip it for international markets

---

## 12. Key Metrics

Track these from day one. Review weekly during Phase 0–1, monthly from Phase 2.

| Metric | Why It Matters |
|---|---|
| MRR (Monthly Recurring Revenue) | Health of the subscription business |
| GMV (Gross Merchandise Value) | Scale of orders flowing through the platform |
| Active merchant count | Growth rate |
| Merchant monthly retention rate | Most important number — product stickiness |
| CAC per merchant | Cost to acquire — target under 3 months of their subscription revenue |
| LTV per merchant | Long-term value — target 24+ month average lifespan |
| Orders per merchant per week | Are they actually using it actively? |
| Customer repeat order rate | Value of the platform to end consumers |
| Time to first order per merchant | Onboarding efficiency — shorter = better product |
| NPS (merchants + customers) | Leading indicator of retention and referrals |

---

> This document is a living plan. Update it when phases complete, when funding closes, when the product roadmap shifts, or when key decisions change. Do not let it go stale.
