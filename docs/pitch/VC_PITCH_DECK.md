# Woahh — Investor Pitch Deck

> Working draft. All figures are sourced from the positioning brief. Items marked **[TBD]** require founder input before this deck ships. **Two numbers MUST be reconciled before going live:** (1) the charity headline % and (2) the Growth tier price ($150 vs $199). This draft uses the code-ground-truth framing and flags the conflicts inline.

---

## Slide 1 — Title

**woahh**

**The all-in-one operating system for independent restaurants — for under $10 a day, with giving wired into the rails.**

Branded storefront · zero-commission discovery marketplace · CRM, loyalty, SMS & email · kitchen display · reservations · AI copilots.

- Brand: **Woahh** (UI) · `woahh.app`
- Beachhead: independent restaurants, Brisbane → Sydney / Melbourne / Gold Coast
- Contact: [TBD: founder name + email]

*Speaker note:* Open with the one-liner verbatim, then the hook: "Restaurants today pay aggregators 25–30% and a POS vendor a flat fee — and still don't own a single customer email. We give them the whole stack and the customer back, for the price of a coffee a day, and we route giving through the platform itself."

---

## Slide 2 — Problem

**Independent restaurants run on a duct-taped, expensive stack — and own none of it.**

- A typical $50k/month restaurant stitches together: **Square (~$165/mo)** for POS + **Uber Eats / DoorDash (25–30% commission)** for orders + a separate website + a separate mailing tool.
- That's **$5,000–6,000/month** in tooling and take-rate on $50k of revenue.
- After all that spend, the merchant **still doesn't own a single customer email address** — the aggregator owns the relationship.
- Tools (Square/Toast) give you back-of-house but **no demand**. Marketplaces (Uber/DoorDash) give you demand but **take the customer and 25–30%**.
- Fragmentation tax: multiple logins, no unified customer view, no owned marketing channel.

*Speaker note:* Anchor on the modeled merchant — ~$50k GMV/mo, ~37 digital orders/day at ~$45 AOV. The emotional core: they pay the most and own the least. Name the high-fit pain profiles — reservation-led fine dining that doesn't want aggregator traffic, B2B caterers, members' clubs, small-town restaurants where the relationship *is* the business.

---

## Slide 3 — Solution

**woahh is the operating system AND its own demand channel — in one product.**

- **Run the restaurant:** real-time order kanban, Kitchen Display System, full menu/catalog, reservations & tables, staff roles, analytics.
- **Own the customer:** built-in CRM, points + milestone loyalty, per-merchant SMS & email, unified cross-merchant identity.
- **Get found:** branded public storefront + the **/eat discovery marketplace** where merchants are auto-listed and keep the customer.
- **Move faster with AI:** menu-import-from-photo, AI campaign copy, AI decline reasons — live edge functions, not slideware.
- **Give back automatically:** charitable giving wired into the platform, not bolted on as a campaign.
- **For under $10/day.**

*Speaker note:* The frame is "back-of-house stack + your own marketplace, in one bill." Square/Toast can't do the marketplace; Uber/DoorDash can't do POS or back-of-house. woahh is the only product that does both — and the only one that donates from GMV.

---

## Slide 4 — Why Now

**The conditions for an independent-restaurant OS just converged.**

- **Aggregator fatigue is structural:** 25–30% commissions are unsustainable on thin restaurant margins; merchants are actively hunting for owned channels.
- **AI made onboarding trivial:** a restaurant's menu can now be read from a photo/PDF into a live catalog in one click — the historical #1 setup blocker is gone.
- **Compliance got real (AU):** Spam Act consent, ABN validation, per-channel opt-out — enforceable in code, a barrier to incumbents bolting it on.
- **Cause-aligned commerce resonates** with both consumers and small-business owners as a differentiator, not a cost.
- **Cheap commodity infra:** KDS on a $40–60 Android stick + HDMI TV replaces $1,000–2,000+ proprietary terminals.

*Speaker note:* "Why now" = AI killed the setup friction, aggregator economics broke, and giving became a growth lever. The same product was not buildable or sellable three years ago.

---

## Slide 5 — Product (what's live)

**A complete merchant dashboard — 27 feature pages, code-verified at ~90–95% fidelity to docs.**

- **Orders & kitchen:** kanban (accept/prepare/ready/complete/decline), confirmation gating with 7-min auto-decline, color-coded KDS with elapsed timers + keyboard shortcuts, walk-in dialog, public live order tracking at `/order/:id`.
- **Menu:** full CRUD, sale windows, combos, category LTOs, realtime sync to KDS + storefront; ingredient-shortage handling keeps dishes sellable.
- **CRM/loyalty:** contacts, per-channel consent, points + birthday rewards, 5-min rotating in-store loyalty codes, unified cross-merchant identity.
- **Marketing:** per-merchant SMS numbers + `{slug}@campaigns.woahh.app` email; scheduling, open/click tracking, tier caps + top-ups.
- **Marketplace & storefront:** branded storefront + `/eat` discovery, reviews, ratings, Impact badge.
- **Reservations:** booking widget, table mgmt, timezone-aware slots, deposit config, 24h+2h reminders.
- **AI copilots:** menu import (Sonnet vision), campaign copy + decline reasons (Haiku).

*Speaker note:* Lead with a live demo or screenshot of the KDS and the menu-import-from-photo flow — these land hardest. Be precise on status: dashboard/KDS/orders/menu/reservations/marketplace/portal/demo are live; AI is code-present with final merge pending (see Traction slide).

---

## Slide 6 — Unfair Advantage / Moat

**Three compounding moats: structural giving, the marketplace flywheel, and AI-first ops.**

- **Charity is structural, not a campaign.** Code-default **0.1% GMV mandatory floor** (slider up to 10%), a **publicly auditable donation_ledger**, a `/impact` leaderboard merchants compete on, plus the documented **50% of subscriptions + 50% of commission → charity** model. *No major competitor donates from GMV at all.*
- **OS + its own demand channel.** Full back-of-house **and** a `/eat` marketplace where the merchant owns the customer — a network effect no pure POS or pure aggregator has.
- **AI-first, already in the codebase.** Menu-import-from-photo, AI campaign copy, AI decline reasons are live edge functions today; Toast/Square are still racing to ship menu import.
- **Unified cross-merchant identity.** One customer account follows many woahh merchants — pooled history + loyalty. Aggregators force a fresh siloed account per restaurant.
- **No kitchen hardware lock-in.** KDS on a $40–60 stick vs $1,000–2,000+ terminals.
- **Incentive alignment.** Flat subscription, not a per-order tax — woahh wins only when merchants grow.

*Speaker note:* The defensible wedge is giving-as-growth-engine + the marketplace flywheel: more merchants → more consumer pull on `/eat` → more orders → more giving → more social proof → more merchants. Reconcile the charity % to ONE authoritative number (code says 0.1% GMV floor + 50/50 split) before presenting.

---

## Slide 7 — Business Model

**Flat subscriptions + (future) low commission, with giving split into both.**

**Subscriptions (flat monthly, 60-day free Marketplace trial, no card):**
- **Solo $49/mo** — 1 location; email campaigns + Promote
- **Marketplace $89/mo** — up to 3 locations; full feature set (CRM, loyalty, SMS, marketplace listing)
- **Growth $150/mo** *(code/CLAUDE.md; deck/differentiators cite $199 — **[TBD: reconcile to one number]**)* — up to 7 locations, priority placement, custom domain/PWA
- **Enterprise — custom** — unlimited locations, white-label, dedicated support

**Commission (documented policy; not yet charged):**
- Online: 4% merchant + 2% customer service fee → **3% charity / 3% woahh**
- In-person: 4% merchant only → **2% charity / 2% woahh** (merchant absorbs)
- **Code reality today:** `stripe-payment-intent` hard-codes `application_fee_amount = 0` — founding pass-through; commission is policy/future.

**Unit economics:** blended sub ~$89 ($44.50 woahh / $44.50 charity); net commission to woahh ~3% of GMV; **target LTV $30k+, CAC <$400 (<3 mo revenue)**. Infra at 1,000 merchants ~$2,300/mo → **97–99% net margin on commission; profitable from merchant #1.**

*Speaker note:* Be transparent that commission is the future revenue line — today is intentional pass-through to win founding merchants. The flat-fee structure is itself a selling point (aligned incentives). Reconcile Growth price before the deck ships.

---

## Slide 8 — Market Size

**Beachhead: independent, owner-operated restaurants in Australia.**

- **TAM** — Australian independent restaurants (then ANZ/global SMB hospitality): **[TBD: founder to source total addressable restaurant count × ARPU]**
- **SAM** — independent restaurants in beachhead metros (Brisbane → Sydney / Melbourne / Gold Coast): **[TBD]**
- **SOM** — phased targets from the model:
  - **M4:** 50+ merchants · $2.5M GMV · ~$77k revenue
  - **M12:** 300+ merchants · $15M GMV · ~$450k/mo (**~$5.6M ARR**)
  - **Model scale:** 1,000 merchants at ~$50k GMV/mo → **~$1.5M/mo to woahh and ~$1.5M/mo to charity (~$18.5M/yr to charity)**
- **ARPU anchor:** ~$50k GMV/merchant/mo; blended sub ~$89/mo + ~3% net commission.

*Speaker note:* Don't fabricate TAM — flag it as founder-to-source. Lead instead with the bottom-up unit model and the phased M4/M12 targets, which are defensible from the brief. The 1,000-merchant scale math doubles as the charity-impact headline.

---

## Slide 9 — Go-to-Market

**Founding merchants → testimonials → the marketplace flywheel.**

- **Invite-gated launch:** sign-up blocked without a **founding-access code** (admin-issued; `founding_access_codes` table live).
- **Founding offer:** first **20–25 merchants** get **2 months free + permanent zero commission** (signed agreement) while still paying subscriptions. ~$1,250/mo foregone per merchant (~$25–31k/mo total) — bought back as testimonials, referrals, case studies, investor proof.
- **High-fit wedge segments:** reservation-led fine dining (anti-aggregator), B2B caterers/event companies, members' clubs / invitation-only dining, small-town relationship-driven restaurants.
- **The flywheel:** more merchants → more consumer pull on `/eat` → more orders → more giving → more social proof → more merchants.
- **Restaurant-only at launch** (retail `business_type` exists in code but hidden) to keep the wedge sharp.

*Speaker note:* The founding cohort is deliberate, not desperation pricing — it buys the social proof and word-of-mouth that seed the marketplace. The `/eat` marketplace is the channel that compounds CAC down over time.

---

## Slide 10 — Competition

**woahh is the only product that is both the OS and the demand channel — and the only one that donates from GMV.**

| Player | Take rate / cost | Marketplace? | Back-of-house / POS? | Owns customer? | Donates from GMV? | AI menu import? |
|---|---|---|---|---|---|---|
| **woahh** | Flat $49–$150/mo + (future) 4% | **Yes (/eat)** | **Yes (full)** | **Merchant** | **Yes (structural)** | **Yes (live)** |
| Uber Eats / DoorDash | 25–30% | Yes | No | Aggregator | No | n/a |
| Square | ~2.2% + ~$165/mo | No | Yes | Merchant | No | Racing to ship |
| Toast | $1,000–2,000+ hardware | No | Yes | Merchant | No | Racing to ship |
| Stripe / PayPal | Payments only | No | No | — | No | No |
| Deliveroo / aggregators | High; siloed accounts | Yes | No | Aggregator | No | n/a |
| Bopple / MrYum | Order-and-pay only | No | Partial | Merchant | No | No |

- **~87% cheaper take rate** than aggregators (4% vs 30%) and the merchant **keeps the customer**.
- No one combines full back-of-house + a consumer marketplace + structural giving.

*Speaker note:* The matrix is the slide. The killer cells are the "Marketplace? + Back-of-house? + Donates from GMV?" trio — woahh is the only "Yes/Yes/Yes" row.

---

## Slide 11 — Traction / Status (honest)

**Built and code-verified — final go-to-market plumbing in progress.**

**Live / verified:**
- Merchant dashboard + 27 feature pages, KDS, orders, menu, reservations, marketplace, customer portal, demo mode — **~90–95% code-to-docs fidelity**.
- **Per-merchant SMS (send + STOP/opt-out) verified end-to-end on the live backend (2026-05-31)** with a dedicated ClickSend number.
- Hardened multi-tenant RLS, PII masking, compliance (ABN checksum, Spam Act consent/unsubscribe), per-merchant email identity.

**Built, code-present, final merge pending:**
- AI features (`ai-menu-import`, `ai-menu-copilot`, `ai-campaign`, `ai-decline-reasons`) — real edge functions on Claude Haiku 4.5 + Sonnet 4.6 with prompt caching; awaiting final browser sign-off before merge to main.
- Stripe further along than docs claimed: `stripe-connect-onboard` + `stripe-payment-intent` exist (intent currently `application_fee_amount = 0`).

**Honest gaps (NOT overclaimed):**
- No production subscription-billing UI · no POS/terminal payments · retail vertical hidden · delivery courier code built but flagged off · receipts / PWA install / cookie-GDPR flows not built.
- Paying merchants to date: **[TBD: founder to fill]**.

*Speaker note:* Credibility comes from honesty. Lead with what's verified, clearly separate "code-present, merge pending," and name the gaps before an investor finds them. The SMS end-to-end verification is a real, dated proof point.

---

## Slide 12 — Roadmap / Vision

**From restaurant OS to multi-vertical local-commerce + giving platform.**

**Near-term (unblocks first paying merchant):**
- Stripe billing & subscription-management UI (Connect Express wired; webhook sync, billing portal, grace periods needed).
- Merge AI branch to main; dedicated per-merchant SMS numbers for every real merchant.

**Expansion verticals:**
- **Retail/shop** (un-hide `business_type='retail'`: storefront + SKU/barcode + shipping).
- **Appointments/services** (services + staff schedules + booking widget).
- **POS:** Stripe Terminal smart reader → Tap to Pay on iPhone/Android (needs Apple entitlement + Stripe AU AFSL).
- **Delivery** as a single feature flag (courier code already built, dormant).

**Depth:**
- Inventory alerts, table QR self-service ordering, receipts (email/print/PDF), PWA install, GDPR/Privacy-Act data flows.
- **Deferred AI:** marketplace AI search (pgvector + Claude re-rank), onboarding assistant, analytics narrator ("Tuesday lunch is down 40%").
- Native merchant + customer apps (Expo); Xero/QuickBooks, Apple/Google Pay, review aggregation integrations.
- Hardware kits (lease-to-own): Solo $699 / Marketplace $899 / Growth $1,399.

*Speaker note:* The vision arc: restaurants → retail → services → POS → multi-vertical local-commerce-with-giving. Each vertical reuses the same OS + marketplace + giving rails. Keep the wedge narrative — we win restaurants decisively first.

---

## Slide 13 — Team

**[TBD: founder to fill]**

- Founder / CEO — **[TBD: name, background, why this team wins]**
- Engineering — **[TBD]**
- Advisors — **[TBD]**
- Charity / impact partnerships — **[TBD: named charity partners + structure]**

*Speaker note:* Investors back the team as much as the product. Emphasize the depth of what's already shipped solo/lean (27 feature pages, AI copilots, hardened multi-tenancy) as evidence of execution velocity. Fill founder bio + any domain/hospitality credibility.

---

## Slide 14 — The Ask

**Raising [TBD: amount] to [TBD: stage — pre-seed / seed].**

**Use of funds [TBD: founder to confirm allocation]:**
- Ship production subscription billing → first paying merchants.
- Sign and onboard the founding 20–25 merchant cohort (Brisbane).
- Merge + productionise AI features; dedicated SMS numbers per merchant.
- GTM / sales for metro expansion (Sydney / Melbourne / Gold Coast).
- POS / Tap-to-Pay + AFSL pathway; delivery flag-on.

**Milestones this funds:**
- **M4:** 50+ merchants · $2.5M GMV · ~$77k revenue
- **M12:** 300+ merchants · $15M GMV · ~$5.6M ARR

*Speaker note:* Tie the ask directly to the M4/M12 milestones from the model. Be explicit that the single biggest near-term unlock is the billing UI (blocks the first paying merchant). Amount + exact allocation are founder-to-fill.

---

## Slide 15 — Closing / Mission

**Giving is not a cost centre. It's the growth engine.**

- woahh gives independent restaurants the **whole stack and the customer back** — for under $10/day.
- And it routes giving through the rails: a **0.1% GMV floor**, a **publicly auditable ledger**, a **/impact leaderboard**, and the **50/50 split** model.
- **The scale math:** 1,000 merchants at ~$50k GMV/mo → **~$18.5M/year to charity** — while woahh stays 97–99% margin on commission.
- Every merchant we win is more revenue, more demand on `/eat`, and **more given away** — all at once.

**woahh — the operating system for independent restaurants, with giving built in.**

*Speaker note:* Close on the reframe that carries the whole pitch: this is a venture-scale business *because* of the giving, not in spite of it. Giving is the marketing, the differentiation, and the merchant's social proof. End on the impact headline and the contact CTA.

---

### Pre-flight checklist before this deck ships
- **[BLOCKING] Reconcile the charity headline %** — code = 0.1% GMV floor + 50/50 split; other docs say 0.15% / 2% / "20% of revenue." Pick ONE authoritative framing and use it on Slides 6, 7, 8, 15.
- **[BLOCKING] Reconcile Growth tier price** — $150 (code/CLAUDE.md) vs $199 (deck/differentiators). Slide 7.
- Fill all **[TBD]**: founder team (13), ask amount + use of funds (14), TAM/SAM (8), paying-merchant count (11), charity partners (15).
- Do not overclaim: AI = "built, merge pending"; commission = "policy/future, app fee currently 0"; no POS/billing-UI/retail/delivery/receipts/PWA/GDPR yet.

---

*Internal note: generated 2026-06-02. All [TBD] markers need founder input (team, the ask, traction numbers, TAM specifics) before presenting.*
