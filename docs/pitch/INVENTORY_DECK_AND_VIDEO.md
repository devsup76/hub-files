# Smart Inventory & Plate Economics — Pitch Deck + Video Copy

> Drop-in copy for the VC deck and the short founder video. Covers the restaurant
> **smart inventory** (built, next-phase launch) and the **Plate Economics / Margin
> Radar** flagship (roadmap). Keep claims honest: inventory v1 is built & verified;
> self-learning + margin radar are the roadmap vision. Full detail: `docs/RESTAURANT_INVENTORY.md`.
> Created 2026-06-03.

---

## A. Short video — summary to read out

**One-liner (for a chyron / caption):**
> "Woahh doesn't just track your stock — it learns your kitchen and tells you what to put on special."

**~30-second script (spoken):**
> "Every restaurant wastes hours on paper stock-takes — and still has no idea which dish actually makes money when prices swing. Woahh fixes both. You snap a photo of your menu, and AI estimates how much of each ingredient every dish uses — this pizza, about 150 grams of mozzarella and 100 mls of sauce — you just confirm it. From then on your stock depletes automatically every time you sell a plate, and if you run out of an ingredient it pulls the dish from your storefront on its own. Then it goes further: it learns how much each dish *really* uses from your actual stock-takes, so it can predict your stock and you stop counting by hand. And the big one — it knows the live cost of every plate as ingredient prices move, so when potatoes are cheap it tells you to run the fries, and when tomatoes spike it tells you to pull the caprese. Most tools tell you a price went up. Woahh tells you what to cook, what to push, and what to put on special — and gives half of what it earns to charity."

**~15-second cut (if you need it tighter):**
> "Snap your menu and AI sets up your recipes — this pizza, about 150g of mozzarella — you just confirm. Stock then depletes automatically as you sell, and it tells you exactly when to run a sale, like pushing the fries when potatoes are cheap. A profit copilot for your kitchen, not just an inventory list. And half of what we earn goes to charity."

**On-screen beats (b-roll suggestions):**
1. Snap menu photo → AI fills in "Margherita: 150g mozzarella · 100ml sauce · 5g basil" → owner taps Confirm
2. Order completes → ingredient bars tick down
3. Ingredient hits zero → dish flips to "temporarily sold out" on the storefront
4. Alert card: *"Potatoes at a 6-month low — push Loaded Fries this weekend."*
5. Charity line / impact badge

---

## B. Pitch deck — slide section

### Slide: "Inventory that runs — and thinks — for you"

**Subtitle:** From paper stock-takes to a profit copilot.

**Body (3 tiers, shown as an escalating stack):**

1. **It runs itself (built).**
   - AI reads your menu and estimates how much of each ingredient a dish uses — *"this pizza ≈ 150g mozzarella, 100ml sauce"* — which you confirm in one click. The hand-entry that makes competitors quit, done for you.
   - Stock auto-depletes as orders complete; sell-outs auto-pull the dish from your storefront. No clipboards.

2. **It learns your kitchen (roadmap).**
   - A few stock-takes teach it how much each dish really uses, so it **predicts** your stock and you count by hand ~75% less.
   - *No incumbent closes this loop.*

3. **It prices every plate (roadmap flagship).**
   - Knows the live cost & margin of every dish as ingredient prices swing.
   - Tells you **when to run a sale and when not to** — "push the fries, potatoes are cheap; pull the caprese, tomatoes spiked."

**The line that lands:**
> Tools like MarketMan and MarginEdge tell you *a price went up.* **Woahh tells you what to cook, what to push, and what to put on special to make the most money** — and donates half of what it earns.

**Speaker notes:**
> "Inventory is where most restaurant software dies — setup is brutal and nobody keeps it current. We solved the setup with AI, and we keep it current automatically because it's wired into the same order flow that already runs the kitchen. That's table stakes for us. The real prize is the third layer: because we hold the recipe *and* the sales data, we can connect a price spike to the exact dishes it hurts and tell the owner what to do about it — in plain English, before it eats their margin. That's a category nobody owns yet, and it runs on the same data spine we've already built."

---

### Optional one-liner for an existing "Why we win" / moat slide

> **A data spine no competitor has:** the same recipe + sales data that auto-depletes stock also self-calibrates recipes and prices every plate — three escalating layers of AI on one foundation. Aggregators take 30% and own your customer; POS tools report costs. We do the back-of-house *and* the profit decisions *and* the demand channel — and give half away.

---

## C. Status footnote (for internal honesty / Q&A prep)

- **Built & verified (demo, next-phase launch):** AI recipe builder, auto-deplete on order completion, auto-86 to storefront, conversational stock AI. On branch `feat/restaurant-inventory`.
- **Roadmap (designed, not built):** self-learning recipe calibration (§7) and Plate Economics / Margin Radar (§8) in `docs/RESTAURANT_INVENTORY.md`. Both ride additive schema on the v1 foundation — no rewrite.
- If asked "is the margin radar live?" → "The inventory engine and AI recipes are built; the predictive margin layer is our next build, and the data foundation for it already ships in v1." Keep it honest.
