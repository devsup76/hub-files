---
name: woahh-ingredient-availability
description: "woahh 'temporarily unavailable ingredient' feature — org-wide shortage registry; built on branch feat/ingredient-availability in repo/; migration applied to live DB; verified end-to-end via Playwright; committed not pushed"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5488fec5-c083-48fd-a411-06e380d8cc03
---

Org-wide "temporarily unavailable ingredient" registry for woahh restaurants. When a kitchen runs out
of an ingredient (e.g. Coriander), staff toggle it OFF in the **Shift Availability panel** (the "Menu"
SheetTrigger button on Orders.tsx + KitchenDisplay.tsx — a slide-out "Menu availability" sheet). Every
restaurant dish whose `ingredients_list` contains that name then shows "<ingredient> temporarily
unavailable" on the storefront card + struck-through in the customize dialog, **but the item stays
orderable** (deliberate design; manual restore, no auto-expiry).

**Branch `feat/ingredient-availability`** in the Lovable app repo at **`/workspaces/GrowthHub/repo`**
(NOT the AI worktree repo-ai). Files:
- `supabase/migrations/20260602100000_ingredient_shortages.sql` — table `ingredient_shortages`
  (org-scoped, UNIQUE(org, name_normalized)), RLS (`current_org_id()` for authenticated writes),
  realtime publication, SECURITY DEFINER `get_public_ingredient_shortages(p_org_id)` granted to anon
  (mirrors the `get_public_menu` pattern; returns only ingredient names, no `created_by`).
- `src/services/api.ts` — `ingredientShortageApi` (list/listPublic/mark/clear) + `normalizeIngredient`.
- `src/components/dashboard/ShiftAvailabilityPanel.tsx` — new "Ingredients" section (distinct
  ingredients across products, In stock/Out toggle, "N out" badge, realtime + 30s poll).
- `src/pages/storefront/RestaurantStorefront.tsx` — public 30s poll of shortages; warning banner on
  cards; struck-through in customize dialog.

**Adversarial review (Workflow, 17 agents) → 12 findings confirmed, security clean. Fixes applied:**
the core one — **out-of-stock ingredients are now stamped into `removed_ingredients` at add-to-cart**
(in `addToCart`), so the order line shows "− No Coriander" on the kitchen ticket / KDS / Orders /
receipt (previously the kitchen got ZERO signal). Also: 30s `refetchInterval` on the panel queries
(CLAUDE.md gotcha #4), success toast on the ingredient toggle, intro copy mentions ingredients.
**Deferred (documented, not bugs):** essential-ingredient hard-block (intentionally "stays orderable"),
demo-mode seeding, minor nits.

**Follow-up fix `0351633` (commit #2 on branch):** out-of-stock ingredients are now computed LIVE via a
single `lineRemoved(line)` helper (union of customer removals + currently-out ingredients) used for
both the cart display and the submitted order line — NOT snapshotted at add-time. Closes the hole where
a shortage landing after an item was already in the cart never reached the kitchen ticket (and the
reverse over-flagging). Playwright-verified both directions (add in-stock → mark out after → "No X"
appears within the 30s poll; restock → clears).

**Essential-vs-garnish BUILT (#2, commit `cd758a3`, migration `20260602120000` APPLIED to live DB).**
Per-product `products.required_ingredients text[]` (default `{}`, backward compatible) + `get_public_menu`
returns it (DROP+CREATE — RETURNS shape changed, can't CREATE OR REPLACE). Menu editor: ★ toggle per
standard ingredient marks it required. Storefront: if a REQUIRED ingredient is out → item hard-blocked
("Temporarily sold out — out of X", Add disabled, excluded from upsells, handleAdd guarded); OPTIONAL
out ingredients unchanged (soft "temporarily unavailable", stays orderable). Checkout guard blocks submit
if a required ingredient went out while in cart. Playwright-verified: required-out→blocked (force-click
adds nothing), same ingredient optional-out→orderable. Commits on branch (all PUSHED to origin/feat/ingredient-availability): `c5a9062` (feature),
`0351633` (live-recompute fix #1), `cd758a3` (required hard-block #2), `7475571` (demo-mode support).

**Demo mode DONE (`7475571`):** the whole feature works in the in-memory DemoStore now — `ingredientShortages`
state + list/mark/clear methods + seed (Basil out = optional soft banner; Mozzarella marked required on
the Margherita = toggle-out hard-block); ingredientShortageApi routes to DemoStore in demo;
ShiftAvailabilityPanel enabled in demo (queries + toggles demo-branched, realtime guarded off, removed
the "disabled in demo" placeholder). Playwright-verified in `?demo=owner`: storefront soft banner
(orderable) → staff toggle Mozzarella out → storefront hard-block. Non-demo path re-verified (no
regression). Demo storefront = `/shop/bellas-bistro`.

**woahh.app is OFF LOVABLE** (since 2026-05-31, per docs/MIGRATION_OFF_LOVABLE.md): Cloudflare Pages
(`woahh-app`) → Supabase `pmnyhbhtkcfoozkinieo`. Pushing a branch = Cloudflare **preview** build (not
prod, not Lovable); prod rebuilds only from `main`. (Earlier "Lovable CI" wording was stale.)

**AI features in demo = intentionally CANNED, zero Anthropic cost** (user decision 2026-06-02): all 3
(ai-campaign, ai-menu-copilot, ai-decline-reasons) already short-circuit in demo with clear messaging
and make NO model calls — no change made. Real-AI-in-demo would need a server-side demo path + rate
limit (deferred; revisit after the AI branch merges). See [[woahh-ai-features]].

**✅ MERGED TO MAIN 2026-06-02 (origin/main @ `a88a089`).** Integrated origin/main (which by then had the AI features + SMS hardening) into the branch: Menu.tsx auto-merged (kept BOTH the ingredient ★-required toggle AND the AI import/edit buttons); 3 SMS edge-fn conflicts (owner-verify/reservation-remind/sms-webhook) resolved by taking MAIN's version (the branch carried the superseded `397a289` hardening); dropped the stale `20260602000000_owner_verify_otp_lockout.sql` (superseded by main's `20260602101000_owner_otp_attempts`; its `phone_otp_locked_until` column is unreferenced). **Renamed both ingredient migrations to `20260602122000_ingredient_shortages` + `20260602123000_required_ingredients`** to avoid timestamp-prefix clashes with main's `100000`/`120000` SMS migrations. Build green (tsc+vite). FF-pushed main. **No DB deploy needed** — both ingredient migrations were already applied to the live DB by hand (renamed files carry identical SQL); feature has no edge functions; frontend goes live when Cloudflare rebuilds from main. Nothing left deferred on the ingredient feature.

**Status: ✅ migration APPLIED to live DB `pmnyhbhtkcfoozkinieo` (user ran the SQL in Supabase SQL
Editor, 2026-06-02); build green; verified end-to-end via Playwright** against test-bistro (added
Coriander to two naans → marked Out → storefront banner showed → cart line "− No Coriander" → staff
panel showed "Coriander OUT / 1 out"). **Test data fully cleaned up afterwards.** Committed locally on
the branch, **NOT pushed** (pushing triggers Lovable CI). Test merchant:
`pawitsingh23+merchant@gmail.com` / `WoahhTest2026!`, org `35cf67fb-bd48-45ec-8032-32debbca84b1`.

**Local test harness set up this session:** Playwright drives chromium directly (MCP `playwright`
reconfigured to `--browser chromium --headless --no-sandbox`, but mid-session MCP reconfig needs a
session restart to bind; until then use direct scripts). chromium-1223 + host libs installed via apt;
playwright-core scratch project at `/tmp/pwtest` (auth via Supabase password-grant → session injected
into `localStorage['woahh-business-auth']`; storefront browse/cart is fully public, no login). Dev
server: `cd repo && npm run dev` → http://localhost:8080 (points at the live backend via repo/.env).
Related: [[woahh-ai-features]], [[woahh-sms-architecture]].
