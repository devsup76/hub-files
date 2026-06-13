---
name: woahh-brand-preview-template-recipe
description: How to add a new single-brand storefront preview (like Taco Joint / Wingz Hut) on feat/storefront-platform
metadata: 
  node_type: memory
  type: project
  originSessionId: 213112d3-cbd5-4cb0-9221-3a0ba2396e4e
---

Recipe for "create a new template like tacojoint/wingzhut" — a self-contained, single-brand storefront PREVIEW with NO backend/DB/Stripe (passes no `onPlaceOrder` → checkout inert, `demo` flag). Work in worktree **`repo-audit`**, branch **`feat/storefront-platform`** (LOCAL/preview only, not merged). See [[woahh-storefront-platform]] and [[woahh-online-order-flow]].

**Files per brand (mirror Wingz Hut / Taco Joint):**
1. Logo asset → `public/<brand>/logo.png` (served as `/<brand>/logo.png` via `SmartImage`, same-origin). User drops source in repo-root `/<brand>/` dir; copy into `repo-audit/public/<brand>/`.
2. `src/pages/preview/<brand>World.ts` — the hand-built `StorefrontWorld` data: `SectionOrg` (name/logo_url/cover_url/tagline/description/address), `SectionProduct[]` (each size = its own product, **prices in INTEGER CENTS**, `extras: SectionProductExtra[]` for flavour/meal picks with `price_delta` cents), `SectionCategory[]` (name MUST equal each product's `category`), `SectionReview[]`, a `*_THEME` (strict `"H S% L%"` HSL allow-list tokens), `*_SECTIONS`, `*_HERO`, and a `buildConfig(template)` → `parseStorefrontConfig(...)`. Export a `*ConfigFor(layout)` picking the config whose `template` enum === chosen blueprint's `layoutTemplate`.
3. `src/pages/preview/<Brand>Preview.tsx` — page: `?t=` template switcher, optional `?mode=`/`?accent=` toggles (Taco does this), `?screen=menu|checkout` deep-link, `seedCart()`, a `Stage` that renders `<ThemeShell world variants demo><Home world/></ThemeShell>`. Remount `Stage` via `key` on any param change (cart/nav hooks live inside).
4. Route in `src/App.tsx`: lazy import + `<Route path="/<brand>-preview" element={<ApexOnly><Brand Preview/></ApexOnly>} />`.

**Two levels of distinctiveness:**
- **Reuse existing blueprints (Wingz Hut):** pick 2 of the registered blueprints (e.g. `bold-appetite`/Counter + `kerb`). Zero new home/CSS — just `world` + preview page + route.
- **Brand-new bespoke layout (Taco Joint added `cantina`):** also requires (a) new `StorefrontTemplate` enum value in `src/lib/storefrontConfig.ts` (`TEMPLATES` array), (b) new preset in `src/lib/storefrontTemplates.ts` + entry in its blueprint list, (c) new blueprint in `src/components/storefront/chrome/registry.ts`, (d) new bespoke Home in `src/components/storefront/homes/<id>/` + register in `homes/registry.ts` `BESPOKE_HOMES`, (e) typography block in `src/index.css` under `.storefront-renderer[data-template="<id>"]`.

**Existing registered blueprints/layouts** (id → layoutTemplate): modern-minimal→minimal, bold-appetite→bold, editorial-boutique→editorial, fresh-organic→hero, luxe-noir→grid, vibrant-market→boutique, kerb→kerb, daily→daily, maison→maison, rush→rush, cantina→cantina.

Invariant: `blueprint.layoutTemplate === config.template`. Verify with `vite build` + `tsc`.

**Brands built so far:** Wingz Hut (`/wingzhut-preview`, Counter+Kerb), Taco Joint (`/tacojoint-preview`, Rush+Harvest+bespoke Cantina), **Raising Tenders (`/raisingtenders-preview`, Rush+Counter+Kerb; light/dark + red/orange accent; 30/32 Kingston Rd Underwood QLD; 16 items from Menu.png) — built + committed `490635c` + PUSHED to `feat/storefront-platform` for Cloudflare preview (2026-06-10)**.

**Verification gotcha (learned 2026-06-10):** Playwright `fullPage` screenshots BALLOON `min-h-screen`/`100vh` storefront sections → the landing looks "80-90% empty voids" in a fullPage capture but is fully populated at a normal viewport. ALWAYS judge with fixed-viewport shots (`fullPage:0`) scrolled in steps, not one fullPage capture. A visual-critique agent panel was fooled by this and raised a false "broken landing" blocker. It ALSO misread Menu.png prices ($19.99→$15.99, $8.99→$9.99) and the punny "Not Fried Chicken" dessert (→"Hot") — re-read the source image / crop it (via chromium clip; no PIL in this env) before "fixing" customer-facing data. Screenshot helper: `/tmp/rt-shot.mjs` (chromium-1223 in ms-playwright cache, `playwright-core` default-import).


**2026-06-13 — merchant-previews v2 (branch `feat/merchant-previews-v2`, off main, PUSHED not merged):** combined the teammate's navigable single-brand preview (yieldarche's `feat/wingzhut-preview`: real ThemeShell, menu→cart→checkout) with in-page toggles. NEW shared infra: `src/pages/preview/PreviewToolbar.tsx` (template + light/dark + curated accent swatches, pinned bottom so it never covers nav, writes to URL). `StickyTabsNav` now renders real tabs (Menu·Deals·About·Reviews + Order CTA) desktop + mobile strip — previously logo+cart only, so bold/kerb/rush had no nav. `SectionCategory.isDeals` → a 'Deals' tab (category page; restaurants have no 'pricing' page). **4 merchant links:** `/wingzhut-preview?t=counter|kerb` (red/amber/lime), `/redhotchicken-preview?t=rush|kerb` (red/blue/gold). **Red Hot Chicken** = Raising Tenders rebrand (same Underwood addr), new world `redHotChickenWorld.ts` from merchant logo+menu.png (Nash Box $28.99 — verify prices by CROPPING the menu, a glance misreads), 6 Unsplash stock food shots (merchant replaces). **Cross-brand differentiation even on shared Kerb:** Wingz Hut radius lg + font bold (rounded/poppy) vs RHC radius sm + font classic (sharp/gritty) + different palettes/logos. Per push-merge policy: app-repo previews stay branch-only (founder-gated merge). Fixed: wingzhut logo was 404 (copied to public/wingzhut/logo.png).