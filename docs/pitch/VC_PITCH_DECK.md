# Woahh — Investor Pitch Deck

> **Presentable deck:** `docs/pitch/woahh-vc-deck.html` — branded HTML deck (forest/gold). **This markdown is the content source-of-truth; the HTML needs regenerating to match this 2026-06-03 repositioning.**

> **Repositioned 2026-06-03:** the **consumer `/eat` marketplace is no longer a pitch pillar** — the story is now the **all-in-one operating system that's *smarter* (AI inventory + margin intelligence) and *gives back***, beating the point-solution stack (**Toast, Square, Bopple, me&u, MarketMan/MarginEdge**) rather than the delivery aggregators (Uber Eats / DoorDash). Tier names (Solo/Marketplace/Growth) are product SKUs and unchanged.

> Figures use the **locked model (BUSINESS_STRATEGY.md):** 3% merchant + 1% customer = 4% gross online → 2% charity / 2% woahh; **$15k GMV/merchant** base; Growth tier **$150**; charity headline = **~2% of every online order + 50% of every subscription**. Items marked **[TBD]** need founder input (TAM, team, the ask, traction).

---

## Slide 1 — Title

**woahh**

**The all-in-one operating system for independent restaurants — it runs the kitchen, learns your inventory, and tells you how to make more money. Under $10 a day, with giving wired into the rails.**

Online ordering + your own storefront · kitchen display · menu & recipes · **AI inventory + margin intelligence** · CRM, loyalty, SMS & email · reservations · AI copilots.

- Brand: **Woahh** (UI) · `woahh.app`
- Beachhead: independent restaurants, Brisbane → Sydney / Melbourne / Gold Coast
- Contact: [TBD: founder name + email]

*Speaker note:* Open with the one-liner, then the hook: "A restaurant today pays for a POS, a separate online-ordering tool, a separate inventory tool, and a separate marketing tool — four bills, four logins, none of them talk, and none of them are smart. We replace the whole stack with one system that actually thinks — it learns your kitchen and tells you what to put on special — for the price of a coffee a day, and routes giving through the platform itself."

---

## Slide 2 — Problem

**Independent restaurants run on a duct-taped stack of single-purpose tools — expensive, fragmented, and dumb.**

- A typical independent stitches together: **a POS (Toast / Square — hardware + ~$165/mo + add-ons)**, **a separate online-ordering tool (Bopple / me&u)**, **a separate inventory/cost tool (MarketMan / MarginEdge)**, and **a separate mailing tool** — four vendors, four logins.
- That's **hundreds to thousands a month** before a single smart decision is made for them.
- **None of it is intelligent.** Inventory is a paper clipboard or a tool that only *reports* a price went up. Nobody tells the owner *which dish just stopped making money, or when to run a sale.*
- **No unified view:** orders, stock, customers and margins live in separate silos that never reconcile.

*Speaker note:* Anchor on the modeled merchant — ~$15k GMV/mo through woahh, ~11 digital orders/day at ~$45 AOV (rising as POS captures full in-store volume). Emotional core: they pay for four tools, do stock-takes on paper, and *still* don't know which plate makes money when potato prices double. High-fit pain profiles: reservation-led fine dining, B2B caterers, members' clubs, small-town relationship-driven restaurants.

---

## Slide 3 — Solution

**One operating system that replaces the whole stack — and is the only one that thinks for the owner.**

- **Run the restaurant:** real-time order kanban, Kitchen Display System, full menu/catalog, reservations & tables, staff roles, analytics.
- **Sell direct:** branded online-ordering storefront + live order tracking — your brand, your customer, no per-order aggregator tax.
- **Know your kitchen:** **AI builds your recipes, stock auto-depletes as you sell, and margin intelligence tells you the live cost of every plate** (more on the next slide).
- **Own the customer:** built-in CRM, points + milestone loyalty, per-merchant SMS & email.
- **Move faster with AI:** menu-import-from-photo, AI campaign copy, AI decline reasons — live edge functions, not slideware.
- **Give back automatically:** charitable giving wired into the platform, not bolted on. **For under $10/day.**

*Speaker note:* The frame is "replace four point tools with one system that's actually smart, for a fraction of the combined cost." POS vendors run the till but are dumb about margin; ordering tools (Bopple/me&u) are just a checkout; inventory tools only report. woahh does all of it **and** turns the data into decisions — and gives from every sale.

---

## Slide 4 — Why Now

**The conditions for a smart, all-in-one restaurant OS just converged.**

- **AI made the hard parts trivial:** a menu reads from a photo into a live catalog *and* AI now drafts the recipes — the two historical setup blockers (catalog + inventory recipes) are gone.
- **Margin pressure is acute:** food-cost inflation and volatile produce prices are crushing thin margins — owners desperately need to know their real plate costs, and nobody gives it to them simply.
- **The stack is unbundleable:** owners are tired of paying four vendors that don't talk; the appetite for one system is real.
- **Compliance got real (AU):** Spam Act consent, ABN validation, per-channel opt-out — enforceable in code.
- **Cheap commodity infra:** KDS on a $40–60 Android stick + HDMI TV replaces $1,000–2,000+ proprietary terminals.

*Speaker note:* "Why now" = AI killed the setup friction (catalog + recipes), cost inflation made margin intelligence urgent, and giving became a growth lever. This product wasn't buildable or sellable three years ago.

---

## Slide 5 — Product (what's live)

**A complete merchant dashboard — 27 feature pages, code-verified at ~90–95% fidelity to docs.**

- **Orders & kitchen:** kanban (accept/prepare/ready/complete/decline), confirmation gating with 7-min auto-decline, color-coded KDS with elapsed timers + keyboard shortcuts, walk-in dialog, public live order tracking at `/order/:id`.
- **Menu:** full CRUD, sale windows, combos, category LTOs, realtime sync to KDS + storefront; ingredient-shortage handling keeps dishes sellable.
- **CRM/loyalty:** contacts, per-channel consent, points + birthday rewards, 5-min rotating in-store loyalty codes.
- **Marketing:** per-merchant SMS numbers + `{slug}@campaigns.woahh.app` email; scheduling, open/click tracking, tier caps + top-ups.
- **Storefront:** branded online-ordering site, reviews, ratings, Impact badge.
- **Reservations:** booking widget, table mgmt, timezone-aware slots, deposit config, 24h+2h reminders.
- **AI copilots:** menu import (Sonnet vision), campaign copy + decline reasons (Sonnet 4.6).

*Speaker note:* Lead with a live demo or screenshot of the KDS and the menu-import-from-photo flow — these land hardest. Be precise on status: dashboard/KDS/orders/menu/reservations/storefront/portal/demo are live; AI is live (merged + deployed 2026-06-02). The inventory engine (next slide) is built and next-phase.

---

## Slide 6 — Smart Inventory & Plate Economics  *(the differentiator)*

**Inventory that runs — and thinks — for you. This is what no competitor has.**

**Tier 1 — it runs itself (built, next-phase launch):**
- AI reads your menu and **drafts every recipe** — the setup step that makes MarketMan/xtraCHEF users quit.
- Stock **auto-depletes as orders complete**; an ingredient hitting zero **auto-pulls the dish** from your storefront. No clipboards.

**Tier 2 — it learns your kitchen (roadmap):**
- A few stock-takes teach it how much each dish really uses → it **predicts** your stock and cuts manual counting **~75%**. *No incumbent closes this loop.*

**Tier 3 — it prices every plate (roadmap flagship):**
- Knows the **live cost & contribution margin of every dish** as ingredient prices swing.
- Tells you **when to run a sale and when not to** — "potatoes are cheap, push the fries; tomatoes spiked, pull the caprese."

> Tools like **MarketMan and MarginEdge tell you a price went up.** **Woahh tells you what to cook, what to push, and what to put on special to make the most money** — and donates half of what it earns. A profit copilot, not a cost report.

*Speaker note:* This is the slide that separates us from "another all-in-one." Because we hold the recipe BOM *and* the sales data on one spine, we connect a price spike to the exact dishes it hurts and recommend the action — in plain English, before it eats the margin. Tier 1 is built and verified in demo; tiers 2–3 are designed on additive schema atop the same foundation (`docs/RESTAURANT_INVENTORY.md`). Be honest: the predictive margin layer is the next build, the data foundation ships with v1.

---

## Slide 7 — Unfair Advantage / Moat

**Three compounding moats: a smart data spine, structural giving, and AI-first ops.**

- **One data spine, three layers of intelligence.** The same recipe + sales data **auto-depletes stock**, **self-calibrates recipes**, and **prices every plate**. Point tools (POS, ordering, inventory) each hold one slice; only we hold all of it together — so only we can turn it into decisions. *This is the deep moat.*
- **Charity is structural, not a campaign.** Code-default **0.1% GMV mandatory floor** (slider up to 10%), a **publicly auditable donation_ledger**, a `/impact` leaderboard, plus **50% of subscriptions + 50% of commission → charity**. *No major competitor donates from sales at all.*
- **AI-first, already in the codebase.** Menu-import-from-photo, AI recipe builder, AI campaign copy, AI decline reasons — real edge functions today; Toast/Square are still racing to ship menu import.
- **All-in-one replaces the stack.** Full back-of-house + own-brand ordering + inventory + CRM/marketing in one flat bill — the bundle no point-solution can match without becoming us.
- **No kitchen hardware lock-in.** KDS on a $40–60 stick vs $1,000–2,000+ terminals.
- **Incentive alignment.** Flat subscription, not a per-order tax — woahh wins only when merchants grow.

*Speaker note:* The defensible wedge is the smart data spine + giving-as-growth-engine. A competitor can copy one feature, but not the combination of full back-of-house, AI margin intelligence, and structural giving on one ledger. Charity headline is locked: ~2% of every online order + 50% of every subscription (the 0.1% GMV floor is the separate voluntary-rate default).

---

## Slide 8 — Business Model

**Flat subscriptions + (future) low commission, with giving split into both.**

**Subscriptions (flat monthly, no card to start):**
- **Solo $49/mo** — 1 location; storefront, orders, kitchen, menu, reservations, email
- **Marketplace $89/mo** — up to 3 locations; full feature set (CRM, loyalty, SMS, smart inventory)
- **Growth $150/mo** — up to 7 locations, priority support, custom domain/PWA, advanced analytics
- **Enterprise — custom** — unlimited locations, white-label, dedicated support

**Commission (documented policy; not yet charged):**
- Online: 3% merchant + 1% customer service fee (4% gross) → **2% charity / 2% woahh**
- In-person: 3% merchant only → **1.5% charity / 1.5% woahh** (merchant absorbs)
- **Code reality today:** `stripe-payment-intent` hard-codes `application_fee_amount = 0` — founding pass-through; commission is policy/future.

**Unit economics ($15k GMV/merchant base):** blended sub ~$89 ($44.50 woahh / $44.50 charity); net commission to woahh ~2% of GMV (~$300/merchant/mo) → **~$344.50/merchant/mo to woahh and the same to charity; LTV ~$8–12k, CAC <$400**. Infra ~$2,300/mo at 1,000 merchants → **~94% contribution margin (pre-payroll); break-even ~60–110 merchants.**

*Speaker note:* Commission is the future revenue line — today is intentional pass-through to win founding merchants. The flat-fee structure is itself a selling point (aligned incentives, unlike the per-order tax of aggregators or the add-on-per-feature model of POS vendors).

---

## Slide 9 — Market Size

**Beachhead: independent, owner-operated restaurants in Australia.**

- **TAM** — Australian independent restaurants (then ANZ/global SMB hospitality): **[TBD: founder to source restaurant count × ARPU]**
- **SAM** — independents in beachhead metros (Brisbane → Sydney / Melbourne / Gold Coast): **[TBD]**
- **SOM** — phased targets from the model:
  - **M4:** 50+ merchants · ~$0.75M GMV/mo · ~$17k revenue/mo
  - **M12:** 300+ merchants · ~$4.5M GMV/mo · ~$103k/mo (**~$1.24M ARR**)
  - **Model scale:** 1,000 merchants at ~$15k GMV/mo → **~$344.5k/mo to woahh and ~$344.5k/mo to charity (~$4.13M/yr); 5,000 merchants → ~$20.7M/yr to charity**
- **ARPU anchor:** ~$15k GMV/merchant/mo; blended sub ~$89/mo + ~2% net commission (~$344.50/merchant/mo).

*Speaker note:* Don't fabricate TAM — flag it as founder-to-source. Lead with the bottom-up unit model and phased M4/M12 targets. The 1,000-merchant scale math doubles as the charity-impact headline.

---

## Slide 10 — Go-to-Market

**Founding merchants → testimonials → word-of-mouth referral.**

- **Invite-gated launch:** sign-up blocked without a **founding-access code** (admin-issued; `founding_access_codes` table live).
- **Founding offer:** first **20–25 merchants** get **0% commission + 12 months free** (signed agreement). ~$300/mo foregone per merchant — bought back as testimonials, referrals, case studies, investor proof.
- **High-fit wedge segments:** reservation-led fine dining, B2B caterers/event companies, members' clubs / invitation-only dining, small-town relationship-driven restaurants.
- **The hook that sells itself:** "stop paying four tools — get one that runs the kitchen *and* tells you how to make more money, cheaper than any one of them, and it gives back."
- **Restaurant-only at launch** (retail `business_type` exists in code but hidden) to keep the wedge sharp.

*Speaker note:* The founding cohort is deliberate, not desperation pricing — it buys social proof and word-of-mouth. Hospitality is a tight referral network; the smart-inventory + giving story is the talkable hook that compounds CAC down.

---

## Slide 11 — Competition

**One system vs a stack of point tools — and the only one that thinks about margin and gives.** (Feature-by-feature, same axes as the website comparison; aggregators excluded — different category.)

| Capability | **Woahh** | Toast | Square | Bopple | me&u | MarketMan / MarginEdge |
|---|---|---|---|---|---|---|
| Full back-of-house (orders · menu · KDS) | **Yes** | Yes | Yes | No | No | No |
| Own-brand online ordering + storefront | **Yes** | Add-on | Add-on | Yes | QR only | No |
| Reservations + table management | **Yes** | Add-on | Add-on | No | No | No |
| CRM + loyalty + marketing | **Yes** | Add-ons | Add-ons | Partial | No | No |
| Ingredient inventory + auto-deplete | **Yes** | Add-on | Basic | No | No | Yes |
| **AI margin intelligence — when to run a sale** | **Yes · recommends** | Reports only | Reports only | No | No | Reports only |
| AI menu import & copywriting | **Yes · live** | Racing | Racing | No | No | No |
| Donates from every sale | **Yes** | No | No | No | No | No |
| No locked-in hardware (any browser) | **Yes** | No | Partial | Yes | Yes | Yes |
| Flat all-in price (no per-feature add-ons) | **Yes** | No | No | Per-order | Per-order | SaaS |

- **Credibility check (honest):** Toast/Square *are* full POS — but each capability is a **separate paid add-on** (Toast owns xtraCHEF for inventory; both have online ordering/KDS/marketing in higher tiers). Bopple/me&u are **ordering layers only**, not back-of-house. MarketMan/MarginEdge are **inventory-cost tools** that *report* — they don't run the restaurant. None recommend menu actions; none give.
- **The two cells nobody else fills:** *AI margin intelligence that recommends the action* (everyone else "reports only" or blank) and *donates from every sale* (everyone else "No").

*Speaker note:* Walk the **margin-intelligence** row — everyone else is "Reports only" or "No"; only Woahh *recommends* (when to run a sale). Then the **donates** row — everyone else "No". Frame the add-on cells honestly: competitors *have* the pieces, but as four separate bills that don't talk; Woahh is one bill that does it all and turns the data into decisions. Aggregators (Uber/DoorDash) are deliberately excluded — different category.

---

## Slide 12 — Traction / Status (honest)

**Built and code-verified — final go-to-market plumbing in progress.**

**Live / verified:**
- Merchant dashboard + 27 feature pages, KDS, orders, menu, reservations, storefront, customer portal, demo mode — **~90–95% code-to-docs fidelity**.
- **Per-merchant SMS (send + STOP/opt-out) verified end-to-end on the live backend (2026-05-31)** with a dedicated ClickSend number.
- Hardened multi-tenant RLS, PII masking, compliance (ABN checksum, Spam Act consent/unsubscribe), per-merchant email identity.

**Live (merged + deployed 2026-06-02):**
- AI features (`ai-menu-copilot`, `ai-campaign`, `ai-decline-reasons`) — real edge functions on Claude Sonnet 4.6; browser-verified, merged + deployed.

**Built, next-phase launch:**
- **Smart inventory** (AI recipe builder, auto-deplete on completion, auto-86 to storefront, conversational stock AI) — built + demo-verified on branch `feat/restaurant-inventory`.

**Honest gaps (NOT overclaimed):**
- No production subscription-billing UI · no POS/terminal payments · retail vertical hidden · delivery courier code built but flagged off · self-learning + margin-radar are roadmap (designed, not built) · receipts/PWA/GDPR flows not built.
- Paying merchants to date: **[TBD: founder to fill]**.

*Speaker note:* Credibility comes from honesty. Lead with what's verified, separate "built / next-phase," and name the gaps before an investor finds them. The SMS end-to-end verification and the demo-verified inventory engine are real, dated proof points.

---

## Slide 13 — Roadmap / Vision

**From restaurant OS to the smart, multi-vertical local-commerce + giving platform.**

**Near-term (unblocks first paying merchant):**
- Stripe billing & subscription-management UI (Connect Express wired; webhook sync, billing portal, grace periods needed).
- Ship smart inventory to founding merchants; dedicated per-merchant SMS numbers.

**Intelligence (the differentiator deepens):**
- **Self-learning recipes** — predict stock, cut stock-takes ~75%.
- **Plate Economics / Margin Radar** — live plate cost, menu-engineering quadrant, *when-to-run-a-sale* recommendations, price forecasting from supplier-invoice OCR + commodity feeds.

**Expansion verticals:**
- **Retail/shop** (un-hide `business_type='retail'`: storefront + SKU/barcode + shipping — reuses the inventory engine).
- **Appointments/services** (booking + staff schedules + deposits — reuses reservations).
- **POS:** Stripe Terminal → Tap to Pay (needs Apple entitlement + Stripe AU AFSL).
- **Delivery** as a single feature flag (courier code already built, dormant).

*Speaker note:* The vision arc: restaurants → retail → services → POS → multi-vertical local-commerce-with-giving. The intelligence layer (inventory → margin radar) is the throughline that makes every vertical smarter, and reuses one data spine + one giving ledger.

---

## Slide 14 — Team

**Built by a lean founding team.**

- **Pawit Singh — Founder & CEO** — product, engineering & GTM. **[TBD: background]**
- **Sid Sethia — Co-founder** — **[TBD: role + background]**
- **Aditya [surname — TBD]** — Co-founder — **[TBD: role + background]**
- Advisors / charity partners — **[TBD]**

*Speaker note:* Investors back the team as much as the product. Emphasize the depth shipped lean (27 feature pages, AI copilots, smart inventory engine, hardened multi-tenancy) as evidence of execution velocity. Fill backgrounds + roles + Aditya's surname + any hospitality credibility. **[Aditya's surname not found in any doc — founder to confirm spelling.]**

---

## Slide 15 — The Ask

**Raising [TBD: amount] to [TBD: stage — pre-seed / seed].**

**Use of funds [TBD: founder to confirm allocation]:**
- Ship production subscription billing → first paying merchants.
- Sign and onboard the founding 20–25 merchant cohort (Brisbane).
- Ship + productionise smart inventory; build the self-learning + margin-radar layers.
- GTM / sales for metro expansion (Sydney / Melbourne / Gold Coast).
- POS / Tap-to-Pay + AFSL pathway; delivery flag-on.

**Milestones this funds:**
- **M4:** 50+ merchants · ~$0.75M GMV/mo · ~$17k revenue/mo
- **M12:** 300+ merchants · ~$4.5M GMV/mo · ~$1.24M ARR

*Speaker note:* Tie the ask to the M4/M12 milestones. The single biggest near-term unlock is the billing UI (blocks the first paying merchant); the biggest differentiation unlock is the margin-radar layer. Amount + allocation are founder-to-fill.

---

## Slide 16 — Expansion: the platform play (Eat → Shop → Book)

**You think this is restaurant software. It's the smart operating system for every main-street business.**

| Stage | Vertical | Status | What it reuses |
|---|---|---|---|
| **Now** | 🍽️ **Eat** — restaurants (orders, kitchen, menu, smart inventory, loyalty) | **Live** on `woahh.app` | the wedge we win first |
| **Next** | 🛍️ **Shop** — retail (SKU/barcode, inventory, shipping) | `business_type='retail'` code exists, hidden | same storefront + **inventory engine** + giving rails |
| **Then** | 💈 **Book** — services: barbers, salons, fitness (appointments, staff schedules, deposits) | reuses the live reservations engine | ~80% of what's already shipped |

- **One smart OS · one giving ledger — across every local vertical.** `/eat → /shop → /book`.
- Each new vertical is a re-skin + a few modules on rails that already exist (multi-tenant, branding, CRM, loyalty, marketing, **inventory intelligence**, payments, giving). Marginal cost is low; the TAM multiplies.
- **The inventory spine is the connective tissue** — Eat tracks ingredients, Shop tracks SKUs, both ride the same engine and the same margin intelligence.

*Speaker note:* This is the "edge" — investors came for a restaurant SaaS and leave seeing a multi-vertical, *intelligent* local-commerce + giving platform. Land the wedge first (win restaurants decisively), then reveal the platform. Same rails, same ledger, same brain — pointed at the next category.

---

## Slide 17 — Closing / Mission

**Giving is not a cost centre. It's the growth engine — and the product is finally smart enough to win on its own.**

- woahh gives independent restaurants the **whole stack in one bill, and a brain on top** — it runs the kitchen, learns the inventory, and tells the owner how to make more money. For under $10/day.
- And it routes giving through the rails: a **0.1% GMV floor**, a **publicly auditable ledger**, a **/impact leaderboard**, and the **50/50 split** model.
- **The scale math:** 1,000 merchants at ~$15k GMV/mo → **~$4.13M/year to charity** (5,000 → **~$20.7M/year**) — at ~94% contribution margin (pre-payroll).
- Every merchant we win is more revenue, a smarter platform, and **more given away** — at once.

**woahh — the smart operating system for independent restaurants, with giving built in.**

*Speaker note:* Close on the reframe: this is venture-scale *because* it's both smarter than the point tools and gives back. The intelligence wins the merchant; the giving keeps them talking. End on the impact headline and the contact CTA.

---

### Pre-flight checklist before this deck ships
- **[2026-06-03] Repositioned:** consumer `/eat` marketplace removed as a pillar; competition refocused on **Toast/Square/Bopple/me&u/MarketMan** (not Uber/DoorDash); **Smart Inventory & Plate Economics** added as Slide 6 and woven through moat/competition/roadmap/expansion. **The HTML deck (`woahh-vc-deck.html`) still needs regenerating to match.**
- **Charity headline** — locked: **~2% of every online order + 50% of every subscription** (50/50 split). The 0.1% GMV floor is the *separate* voluntary-rate default.
- **Growth tier price** — **$150** ($199 references removed everywhere).
- **Founding offer** — **0% commission + 12 months free** (matches the live landing; reconcile the open 1-year-vs-lifetime note in WOAHH_FIXES_TODO 6.2).
- Fill all **[TBD]**: founder team (14), ask amount + use of funds (15), TAM/SAM (9), paying-merchant count (12).
- Do not overclaim: AI copilots = **live**; smart inventory = **built, next-phase**; self-learning + margin radar = **roadmap (designed, not built)**; commission = "policy/future, app fee currently 0"; no POS/billing-UI/retail/delivery yet.

---

*Internal note: repositioned 2026-06-03 (dropped marketplace pillar, refocused competition on POS/ordering/inventory players, added Smart Inventory & Plate Economics). All [TBD] markers need founder input before presenting.*
