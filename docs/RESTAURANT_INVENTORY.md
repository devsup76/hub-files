# Restaurant Ingredient Inventory — Architecture & Handoff

> **Status: BUILT, VERIFIED, NOT YET LIVE.**
> Code is complete on branch **`feat/restaurant-inventory`** (`devsup76/business-growth-hub`, commit `e14d0aa`), pushed (Cloudflare preview builds from the branch). It is **not merged to `main` and not deployed**.
> **This launches in the NEXT PHASE, once founding vendors (merchants) are secured.** Going live = merge to main + run one migration + deploy two edge functions (steps at the bottom).
> Last updated: 2026-06-03.

---

## 1. Why we built this

Retail merchants already had real inventory (the `ShopInventory` page, `stock_movements`, the `ai-inventory-assistant` edge function). **Restaurants had nothing** — a dish (`products`) could only carry a free-text list of ingredient *names* (`products.ingredients_list`), with no quantities and no stock counts. Restaurant owners were still doing **paper stock-takes** and had no idea what an order actually consumed.

This feature gives restaurants ingredient-level inventory that:
- Tracks raw ingredients online (no more clipboard stock-takes).
- **Auto-depletes** as food sells — stock drops automatically when an order is completed.
- **Auto-86s** dishes when an ingredient runs out, using the storefront machinery we already shipped.
- Uses **AI to remove the setup pain** — the #1 reason restaurants abandon inventory tools (MarketMan, xtraCHEF, WISK, Apicbase) is that building recipes by hand is brutal. We auto-draft them.

It also lays the foundation for a genuinely category-defining phase 2: **self-learning recipes that predict your stock and cut stock-taking ~75%** (see §7).

---

## 2. The mental model

| | Restaurant | Retail (already live) |
|---|---|---|
| Dashboard page | **Inventory** (`/business/dashboard/inventory`) | "Inventory" (`/menu` → `ShopInventory`) |
| What you track | **Raw ingredients** (flour, mozzarella, chicken) | Finished SKUs |
| Unit | g / kg, ml / L, or each | count |
| Link to sales | **Recipes** (dish → ingredient quantities) | direct (1 product = 1 stock unit) |
| Depletes when | order **completed** (recipe × qty) | order placed |
| Runs out → | auto-86 via `ingredient_shortages` | low-stock flag |

A dish does **not** have to have a recipe. Inventory only tracks dishes you've built recipes for, so adoption is incremental.

---

## 3. Data model (migration `20260603100000_restaurant_ingredient_inventory.sql`)

### Tables
- **`ingredients`** — per-org master list.
  `id, organization_id, name, name_normalized (lower(btrim) — the join key), base_unit ('each'|'g'|'ml'), stock_quantity numeric, par_level numeric, cost_per_unit_cents, supplier, is_tracked bool`.
  `UNIQUE(organization_id, name_normalized)`. RLS: `organization_id = current_org_id()`. Realtime enabled.
  Stock is stored in a **base unit** (g / ml / each). The UI lets merchants enter/read kg & L and converts (×1000) — base storage keeps the math exact.
- **`recipe_components`** — bill-of-materials (dish → ingredient quantity).
  `id, organization_id, product_id, ingredient_id, quantity numeric (in ingredient base_unit), source ('manual'|'ai'|'learned'), confidence numeric, last_learned_at`.
  `UNIQUE(product_id, ingredient_id)`. The `source/confidence/last_learned_at` columns exist **now** so phase-2 self-learning needs no schema rewrite.
- **`ingredient_movements`** — audit ledger (mirrors `stock_movements`).
  `movement_type ('restock'|'sale'|'waste'|'count'|'correction'|'other'), quantity_delta, quantity_before, quantity_after, reason, source ('manual'|'ai'|'order'|'import'|'count'), order_id`. This is also the **training data** for phase-2 learning.
- **Altered `ingredient_shortages`**: added `source ('manual'|'auto')` so an auto-restock never clears an ingredient a human deliberately 86'd.
- **Altered `orders`**: added `ingredients_depleted_at timestamptz` (idempotency guard).

### `adjust_ingredient_stock(...)` RPC
Manual / AI stock changes. `SECURITY DEFINER`, authorises owner + active manager, `FOR UPDATE` row lock, writes a movement, updates stock. **Clamps at ≥ 0** (manual paths can't go negative). On a restock that crosses back above 0 it deletes the **auto** shortage row (auto-un-86); a manual 86 survives.

### Auto-depletion on completion (the core)
A **`BEFORE UPDATE OF status`** trigger on `orders`, guarded `WHEN NEW.status='completed' AND OLD.status <> 'completed' AND OLD.ingredients_depleted_at IS NULL`:
1. Sets `NEW.ingredients_depleted_at` **directly on the row** — no inner `UPDATE`, so no trigger recursion.
2. Parses `line_items`, and for each line loads that dish's `recipe_components`, **skips** any component the customer removed (`removed_ingredients`, matched on normalized name), and aggregates `quantity × line_qty` per ingredient.
3. Applies decrements **`ORDER BY ingredient_id` with `FOR UPDATE`** → deterministic lock order → no deadlocks when two orders complete at once.
4. **Allows negative stock** on sale (this is deliberate — negative = theoretical-vs-actual *variance*, the signal that drives phase-2 learning and surfaces over-portioning/theft). It never raises, so a kitchen can always close a ticket.
5. If an ingredient lands `<= 0` (and `is_tracked`), upserts an **auto** row into `ingredient_shortages`.

A companion **`AFTER INSERT … WHEN NEW.status='completed'`** covers any future "insert an already-completed order" path.

**Design decisions came from an adversarial design review** — recursion safety, deadlock-safe locking, negative-stock policy, the name-matching trap, and the insert-at-completed gap were all caught and handled before coding.

---

## 4. Auto-86: zero storefront changes

This is the elegant part. The storefront already reads `ingredient_shortages` (the "temporarily unavailable ingredient" feature shipped 2026-06-02) and already does the required-vs-optional split:
- ingredient **required** on a dish → dish shows **"Temporarily sold out"**, Add disabled, checkout blocked.
- ingredient **optional** → dish shows **"X temporarily unavailable"** but stays orderable.

Because our new `ingredients.name_normalized` uses the *same* normalization as `ingredient_shortages` and `products.ingredients_list`, depleting an ingredient to zero just writes the shortage row the storefront is already watching. **No storefront code was touched.** (Keeping recipe ingredient names identical to the dish's `ingredients_list` names is therefore important — the AI builder enforces this; see §5.)

---

## 5. AI features (both restaurant-gated, reuse `_shared/auth.ts` + `_shared/anthropic.ts`)

### `ai-recipe-builder` (edge fn, Sonnet)
"Build recipes with AI" on the inventory page. Reads the org's dishes (`title`, `description`, `ingredients_list`) and **estimates, per dish, how much of each ingredient one serving uses** — e.g. *"Margherita ≈ 150g mozzarella, 100ml tomato sauce, 5g basil."* It's an estimate the owner **confirms/edits** (not a claim to know their exact recipe); the self-learning loop (§7) then calibrates it to real usage. **Constraint:** it only assigns quantities to ingredient names *already on the dish* — it cannot invent names — so storefront auto-86 matching stays aligned. Returns a proposal `{ recipes[], ingredients[] (deduped master), skipped }`. The merchant reviews/edits quantities, then confirm bulk-creates `ingredients` + `recipe_components` (`source='ai'`).

### `ai-ingredient-assistant` (edge fn, Haiku)
"AI stock" conversational dialog. "received 20kg flour", "wasted 3kg tomatoes", "set basil to 500g" → one safe proposal → confirm → `adjust_ingredient_stock`. **Unit conversion (kg/L → base) is done server-side**, not by the model, so arithmetic is never trusted to the LLM.

Both share the project's standard AI helpers and require the `ANTHROPIC_API_KEY` secret (already set on the project; the retail `ai-inventory-assistant` uses the same one).

---

## 6. Frontend & demo

- **`src/pages/dashboard/RestaurantInventory.tsx`** (new) — ingredient table (on-hand in friendly units, par, OK/Low/Out badge, supplier), add/edit sheet, the AI-stock dialog, and the recipe-builder review dialog. Modeled on `ShopInventory.tsx`.
- **Route** `/business/dashboard/inventory` in `App.tsx`; **sidebar** "Inventory" entry for restaurants in `AppSidebar.tsx` (retail keeps inventory at `/menu`).
- **`src/services/api.ts`** — `ingredientApi` (list/create/update/remove/adjustStock/aiAssist) + `recipeApi` (listForProduct/upsert/remove/build/applyProposal), all demo-aware.
- **`src/lib/demo.ts`** — full demo support: Bella's Bistro seeded with 4 ingredients + recipes on Margherita & Pepperoni, depletion hooked into order completion, AI stubs. Works in `?demo=owner`.

---

## 7. Phase 2 — self-learning recipes ("woahh does your stock-take for you")

The founder's vision, designed and ready to build on this foundation. **No incumbent does this.**

1. **Learn** — 4–5 stock-takes over a few days each give one equation, e.g. `20×Butter Chicken + 6×Chicken Masala ≈ 20kg chicken`. Non-negative least squares (NNLS) solves the per-dish usage coefficients.
2. **Predict** — once coefficients are confident, the running theoretical balance (`ingredients.stock_quantity`, auto-depleted by sales) **is** the predicted on-hand. Show it as "Predicted: ~4.2kg chicken left" with a confidence band.
3. **Confirm, don't count** — the merchant glances and taps "looks right" instead of weighing everything; that confirmation is itself a (soft) training signal.
4. **~75% less stock-taking** — once an ingredient's model is confident, drop its required physical-count cadence; the app tells them *which few* ingredients still need a real count (low confidence / high variance / drifting).
5. **Verify + keep learning** — periodic counts and any mismatch feed back; drift (a recipe change, a new cook over-portioning) shows up as rising variance → the app asks for a count sooner.

**Why the v1 schema already supports it:** `ingredient_movements` is the training set (`source='order'` = theoretical depletion, `count`/`correction` = physical counts, all timestamped with before/after); `recipe_components.{source,confidence,last_learned_at}` already exist. Phase 2 adds an NNLS `recipe-learn` edge fn + a couple of additive columns (`last_verified_at`, a `stock_confirmations` log) — **no rewrite of v1**.

Other phase-2 items: AI invoice/delivery OCR receiving (reuse the `ai-menu-import` vision pipeline), reorder/par alerts + suggested purchase orders, theoretical-vs-actual variance dashboard, food-cost %, extras/combos depletion.

---

## 8. Plate Economics & Margin Radar — the flagship (phase 3)

> **Founder idea, 2026-06-03 — "this could be the biggest thing."** A system that knows the true cost of every plate *as ingredient prices move*, and tells the merchant **what to do about it**: when to run a sale, when *not* to, what to push, what to quietly pull. Potatoes are $15/case today and $5 next week — that swing should change what's on special. **This is the part no competitor does.**

### 8.1 The gap we exploit

Today's cost tools — **Jelly, MarginEdge ("Price Movers & Alerts"), MarketMan, xtraCHEF/Toast, Apicbase, Supy, meez, cogs-well** — all do the same thing: scan a supplier invoice → structured line items (SKU, qty, price) → update each recipe's cost card → recompute gross-profit % → **send a "this price changed" alert**. Volatility tracking = "here's what happened over the last 90 days." ([MarginEdge](https://www.marginedge.com/food-cost), [Jelly](https://blog.getjelly.co.uk/ingredient-price-alert-tools-restaurants/))

They **report**. They don't **decide**. None of them close the loop to a *menu action*: "your potato dishes just fell below target margin — here's the sale to run instead, and here's the one to pull." That decision layer — cost movement → margin impact → **recommended action**, forecast-ahead and in plain English — is the wedge, exactly like the self-learning recipe loop (§7). We already hold the two assets that make it possible: the **recipe BOM** (`recipe_components`, which links every ingredient price move to the exact dishes it hits) and the **sales mix** (`orders.line_items`).

### 8.2 The concepts (grounded)

- **Plate cost** — the food cost of one serving = Σ(recipe component qty × that ingredient's current unit cost). We can compute this per dish *the moment a cost changes* because we have the BOM. ([touchBistro](https://www.touchbistro.com/blog/menu-pricing-how-to-calculate-food-cost-percentage/))
- **Food cost %** = plate cost ÷ menu price. Healthy is ~25–35%. ([meez](https://www.getmeez.com/blog/food-cost-percentage-vs-contribution-margin))
- **Contribution margin (CM)** = menu price − plate cost — the dollars that actually land in the till per dish. The real lever is **high CM**, not just low food-cost %. ([Tenzo](https://www.gotenzo.com/resources/insight/the-secret-to-menu-engineering-contribution-margins/))
- **Menu-engineering matrix** — classify each dish by CM × popularity: **Stars** (high CM, popular), **Plowhorses** (popular, low CM), **Puzzles** (high CM, unpopular), **Dogs** (low CM, unpopular). We can plot this automatically: CM from our cost data, popularity from sales mix. ([meez menu engineering](https://www.getmeez.com/blog/the-ultimate-guide-to-menu-engineering), [Lightspeed](https://www.lightspeedhq.com/blog/menu-engineering/))
- **Price elasticity** — how much demand moves when price moves. Discount *elastic* items (more units + traffic); hold/raise *inelastic* ones. We learn each dish's elasticity from our own price/promo → sales history. ([Revionics](https://revionics.com/blog/profitable-pricing-decisions-using-price-elasticity-of-demand), [NetSuite dynamic pricing](https://www.netsuite.com/portal/resource/articles/business-strategy/dynamic-pricing.shtml))

### 8.3 What the system does

1. **Live plate cost & margin per dish.** Recompute every dish's plate cost, food-cost % and CM whenever an ingredient cost changes. The inventory page already knows the recipe; this just adds the money layer.
2. **Cost-spike → margin-impact alerts, mapped to dishes.** Because of the BOM we go from "potatoes +180% this week" straight to *"your Loaded Fries CM dropped $9.20 → $4.10 (food cost 31% → 58%); 3 other dishes affected."* No competitor connects the price to the *plate* automatically across the menu.
3. **Auto menu-engineering quadrant.** Stars / Plowhorses / Puzzles / Dogs, recomputed continuously from CM (cost data) × popularity (sales mix). Tells the owner what to feature, fix, reprice, or cut.
4. **When-to-run-a-sale (and when NOT) — the headline.** Combine *current + forecast ingredient cost* × *dish CM* × *learned elasticity*:
   - **Cheap input + elastic, popular dish → promote it.** "Potatoes are at a 6-month low — push Loaded Fries this weekend; even at 20% off you make more per plate *and* drive traffic."
   - **Spiking input → pull or reprice, don't feature.** "Tomatoes +160% — quietly drop the Caprese from specials or nudge it +$2; promoting it now would sell your worst-margin plate."
   - **Inelastic + healthy margin → leave alone.** Discounting it just gives away margin.
5. **Forecast, so decisions are proactive.** Seasonality + supplier-order reading + external feeds predict next week's costs (ARIMA for seasonality, LSTM-class models for ag prices — both well-established for commodities). "Avocado climbs into summer — lock supply now or rotate the guac off the hero spot." ([USDA ERS season-average forecasts](https://www.ers.usda.gov/data-products/season-average-price-forecasts), [ag price deep-learning](https://www.nature.com/articles/s41598-025-05103-z))
6. **Demand-side trends (the far edge).** Align the *cheap-input* window with a *high-demand* window — seasonal/search/social signals — so promos land when an item is both cheap to make and trending.

### 8.4 Data inputs

**Internal (we already own — free):**
- `recipe_components` — the BOM; the link from any ingredient price move to the exact dishes. **The asset competitors charge for, we already have.**
- `ingredients.cost_per_unit_cents` — current unit cost (already in the v1 schema).
- `ingredient_movements` (`source='order'`/`import`) — every restock can carry the **purchase unit cost**, building a per-ingredient **price history** automatically (add a `unit_cost_cents` column to movements in phase 3).
- `orders.line_items` + `completed_at` + `promo_codes` — sales mix and price/promo → sales response = the **elasticity** training set.

**AI-captured:**
- **Invoice / supplier-order OCR** (reuse the `ai-menu-import` vision pipeline): photograph or forward a supplier invoice → line-item prices flow straight into the ingredient price history. *This is how prices get into the system with zero manual entry* — and it doubles as the receiving/restock flow from §7's phase-2 list. Reading **supplier order confirmation emails** is the same pipeline.
- **LLM as the translator**: turn the numbers into one plain-English recommendation a busy owner acts on in 5 seconds ("Run a fries promo this weekend; pull the caprese").

**External price feeds (layer in later; mostly subscription, few open APIs):**
- **AU (woahh is Brisbane-based):** [Brisbane Markets Price Report / Brismark](https://brisbanemarketspricereport.com.au/), [Freshlogic WPTI](https://freshlogic.com.au/services/weekly-pricing/), [DAFF/ABARES weekly horticulture prices](https://www.agriculture.gov.au/abares/data/weekly-commodity-price-update/australian-horticulture-prices), Ausmarket national report.
- **Global:** [FAO Food Price Index](https://www.fao.org/worldfoodsituation/foodpricesindex/en), [USDA ERS](https://www.ers.usda.gov/data-products), commodity APIs ([commoditypriceapi](https://commoditypriceapi.com/), [APIFarmer](https://apifarmer.com/agriculture-commodity-prices-api/)).
- **Cold-start without any feed:** the invoice-derived internal price history alone (what *this* merchant actually paid over time) already powers alerts + recommendations. External feeds add forecasting and benchmarking; start internal, layer external.

### 8.5 Why the v1 + phase-2 foundation already supports it

- The **BOM** (`recipe_components`) and **per-ingredient cost** (`ingredients.cost_per_unit_cents`) ship in v1 — plate cost is computable today.
- The **self-learning recipe loop (§7)** makes plate costs *accurate* even when recipes were rough estimates — cost intelligence is only as good as the quantities, and §7 keeps them honest.
- **Additive phase-3 schema only** (no rewrite): `ingredient_movements.unit_cost_cents` (purchase price history), `products.target_food_cost_pct`, an `ingredient ↔ commodity-symbol` map for forecasts, and a `dish_margin_snapshots` (or computed view) for the quadrant/alerts.

### 8.6 Phasing

- **3a — Plate economics:** per-dish plate cost, food-cost %, CM from current ingredient costs; the auto menu-engineering quadrant (CM × sales mix). Pure read/compute over existing data.
- **3b — Cost movement intelligence:** invoice OCR → ingredient price history → cost-spike → margin-impact alerts mapped to dishes.
- **3c — Recommendations (the flagship):** forecast (seasonality + supplier orders + AU feeds) + learned elasticity → "run / don't run this sale," "reprice," "86 for now," surfaced in plain English by the LLM.
- **3d — Demand-side:** trend signals so promos hit the cheap-input × high-demand sweet spot; optional automated dynamic pricing / scheduled promos.

### 8.7 Positioning

> Incumbents tell you *the price went up.* Woahh tells you *what to cook, what to push, and what to put on special this week to make the most money* — and gives half of what it earns to charity. It's the difference between a **cost report** and a **profit copilot**.

This compounds with everything else: the same BOM that auto-depletes stock (v1) and self-calibrates recipes (§7) also prices every plate and times every promotion (§8). One data spine, three escalating layers of intelligence — none of which the incumbents have.

---

## 9. What is intentionally NOT in v1

- **Extras (`added_extras`) and combos do not deplete.** Documented to avoid a confusing asymmetric ledger (a removed ingredient subtracts but an added extra wouldn't). Phase 2 maps extras → ingredients.
- **Per-dish recipe editor inside the Menu screen** — skipped for now to avoid risk in that large file; recipes are managed via the AI builder + inventory page.
- **par_level never drives storefront 86** — it's an internal "low stock" signal only. Auto-86 is strictly `<= 0`, which is why no storefront change was needed.
- **The migration has not been run against live Postgres** — authored + design-reviewed; it applies in the next phase.

---

## 10. Verification done (demo, Playwright)

All green in `?demo=owner` (restaurant Bella's Bistro):
- Inventory page renders the seeded ingredients.
- AI restock "received 5kg mozzarella" → 2kg → **7kg** (kg→g conversion correct).
- "Build recipes with AI" → drafted **3 dishes / 7 ingredients**.
- Completed the Pepperoni Supreme order → **Mozzarella −150g, Pepperoni −80g, Tomato −100ml** (exact recipe, net of removals).
- "wasted 2kg mozzarella" → Mozzarella 0 / **Out** → `/shop` shows **Margherita "Temporarily sold out — out of Mozzarella"** (required) and **Pepperoni "Mozzarella temporarily unavailable"** (optional). Confirms auto-86 with zero storefront changes.

Build is green (`npm run build`). (`@stripe/stripe-js` had to be `npm install`ed in the container — it was in `package.json` but not in `node_modules`; unrelated to this feature.)

---

## 11. How to go live (next phase)

1. **Merge** `feat/restaurant-inventory` → `main` (Cloudflare rebuilds prod frontend from `main`).
2. **Run the migration** `supabase/migrations/20260603100000_restaurant_ingredient_inventory.sql` against the live project (`pmnyhbhtkcfoozkinieo`) — paste in the Supabase SQL editor, or `supabase db push` with an access token.
3. **Deploy the two edge functions:**
   ```
   supabase functions deploy ai-recipe-builder       --project-ref pmnyhbhtkcfoozkinieo
   supabase functions deploy ai-ingredient-assistant --project-ref pmnyhbhtkcfoozkinieo
   ```
   They need the existing `ANTHROPIC_API_KEY` secret (already set).
4. **Smoke test** as a restaurant merchant (e.g. the test merchant `pawitsingh23+merchant@gmail.com`): Inventory page → Build recipes with AI → complete an order → confirm stock dropped; drive an ingredient to 0 → confirm the storefront flags the dish.

---

## 12. Key files

| File | Purpose |
|---|---|
| `supabase/migrations/20260603100000_restaurant_ingredient_inventory.sql` | tables, RLS, RPC, depletion triggers, auto-86 |
| `supabase/functions/ai-recipe-builder/index.ts` | AI recipe drafting (Sonnet) |
| `supabase/functions/ai-ingredient-assistant/index.ts` | conversational stock (Haiku) |
| `src/pages/dashboard/RestaurantInventory.tsx` | the inventory page + AI dialogs |
| `src/services/api.ts` | `ingredientApi`, `recipeApi` |
| `src/lib/demo.ts` | demo seed + depletion + AI stubs |
| `src/App.tsx`, `src/components/dashboard/AppSidebar.tsx` | route + nav |
