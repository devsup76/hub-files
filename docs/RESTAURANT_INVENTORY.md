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
"Build recipes with AI" on the inventory page. Reads the org's dishes (`title`, `description`, `ingredients_list`) and drafts, per dish, how much of each ingredient one serving uses. **Constraint:** it only assigns quantities to ingredient names *already on the dish* — it cannot invent names — so storefront auto-86 matching stays aligned. Returns a proposal `{ recipes[], ingredients[] (deduped master), skipped }`. The merchant reviews/edits quantities, then confirm bulk-creates `ingredients` + `recipe_components` (`source='ai'`).

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

## 8. What is intentionally NOT in v1

- **Extras (`added_extras`) and combos do not deplete.** Documented to avoid a confusing asymmetric ledger (a removed ingredient subtracts but an added extra wouldn't). Phase 2 maps extras → ingredients.
- **Per-dish recipe editor inside the Menu screen** — skipped for now to avoid risk in that large file; recipes are managed via the AI builder + inventory page.
- **par_level never drives storefront 86** — it's an internal "low stock" signal only. Auto-86 is strictly `<= 0`, which is why no storefront change was needed.
- **The migration has not been run against live Postgres** — authored + design-reviewed; it applies in the next phase.

---

## 9. Verification done (demo, Playwright)

All green in `?demo=owner` (restaurant Bella's Bistro):
- Inventory page renders the seeded ingredients.
- AI restock "received 5kg mozzarella" → 2kg → **7kg** (kg→g conversion correct).
- "Build recipes with AI" → drafted **3 dishes / 7 ingredients**.
- Completed the Pepperoni Supreme order → **Mozzarella −150g, Pepperoni −80g, Tomato −100ml** (exact recipe, net of removals).
- "wasted 2kg mozzarella" → Mozzarella 0 / **Out** → `/shop` shows **Margherita "Temporarily sold out — out of Mozzarella"** (required) and **Pepperoni "Mozzarella temporarily unavailable"** (optional). Confirms auto-86 with zero storefront changes.

Build is green (`npm run build`). (`@stripe/stripe-js` had to be `npm install`ed in the container — it was in `package.json` but not in `node_modules`; unrelated to this feature.)

---

## 10. How to go live (next phase)

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

## 11. Key files

| File | Purpose |
|---|---|
| `supabase/migrations/20260603100000_restaurant_ingredient_inventory.sql` | tables, RLS, RPC, depletion triggers, auto-86 |
| `supabase/functions/ai-recipe-builder/index.ts` | AI recipe drafting (Sonnet) |
| `supabase/functions/ai-ingredient-assistant/index.ts` | conversational stock (Haiku) |
| `src/pages/dashboard/RestaurantInventory.tsx` | the inventory page + AI dialogs |
| `src/services/api.ts` | `ingredientApi`, `recipeApi` |
| `src/lib/demo.ts` | demo seed + depletion + AI stubs |
| `src/App.tsx`, `src/components/dashboard/AppSidebar.tsx` | route + nav |
