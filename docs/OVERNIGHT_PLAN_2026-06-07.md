# Overnight Build Plan — 2026-06-07 (3 goals, autonomous)

> **Purpose:** single crash-recovery anchor for the overnight autonomous session. If the
> container crashes, the next session reads THIS file + the memory note
> `woahh-overnight-3goals` to know the full plan, decisions, branch names, and live status.
> **Update the "LIVE STATUS" section + commit after every milestone.**

Founder went to sleep ~2026-06-07 (after the storefront context-recovery). ~10 hours.
Wants **3 goals, one at a time, industry-level, by morning.** 3 separate branches.

## Standing decisions (from the founder, before sleep)
- **Authority: branches + previews ONLY.** Nothing merged to `main`/`master`, no Cloudflare
  deploys, no live DB migrations. Everything reviewable in the morning. (Matches the
  "PAUSED for review" posture.)
- **Save progress continuously** (commit + push branches; update this doc + memory) — crash-safe.
- **Self-critique hard** at every goal (adversarial review agents + my own Playwright verification).
- **Match orchestration to the task** (don't force one mega-workflow): dependent build → pipeline
  workflow; divergent design → parallel independent agents + judge panel; research → fan-out readers
  + synthesis + a single-writer execution agent.

## Repos / worktrees
- App code: `devsup76/business-growth-hub`. Main worktree `/workspaces/GrowthHub/repo` (master).
  Feature worktrees: `repo-audit` (feat/storefront-platform), `repo-ai`, `repo-pay`, `repo-promo`, `repo-sms`.
- Planning/docs: `devsup76/hub-files` = `/workspaces/GrowthHub` (this file). Push needs a current
  devsup76 PAT (may 401 — commit locally regardless; /workspaces persists across crashes).

---

## GOAL 1 — Restaurant storefront templates (branch `feat/storefront-platform`, worktree `repo-audit`)

**Objective:** high-fidelity, working, **structurally-distinct** restaurant templates so each merchant
gets their own vibe. Each template must show **home + menu + checkout** (the 3 judge-screens).

**Founder reframe (post-questions):** the existing 6 blueprints have *similar layouts with only
minor differences*. So:
1. **Consolidate 6 → 4 keepers** (the most distinct); the others' uniqueness is covered by
   per-merchant **font / vibe / color** customization (the picker already does logo + 3 colors + copy).
2. **Design 3–4 NEW archetypes with COMPLETELY DIFFERENT LAYOUTS** — think big & niche:
   **food-truck / street-food**, **local cafe / bakery**, **prestige fine-dining**, **fast-casual/QSR**
   (pick the best 3–4). These need genuinely different page architectures + likely NEW sections
   (e.g. "find us today" for trucks, "reservations/chef story" for fine-dining, "daily specials board"
   for cafe) — NOT just new variant combos.
   Final target: **~7–8 templates**, 4 refined + 3–4 radically different.

**Foundation (the Theme-Shell framework) — what existed at session start:**
- Branch `feat/storefront-platform` @ `d7f7af9` (pushed). WIP checkpoint committed `b1c66e3` (pushed).
- Complete + clean: `chrome/{contracts,Overlay,useCart,useStorefrontNav,Footer,NavBar}`,
  `screens/{pricing,catalogue,QuantityStepper,ProductCard,MenuBrowse(6),ProductView(6),Cart(5)}`.
- Was MISSING (the crash boundary): `chrome/CartTrigger.tsx`, `chrome/ThemeShell.tsx` (composer),
  `screens/Checkout.tsx`, `registry.ts` blueprint DATA, and preview wiring. + NavBar `l.name`→`l.label` bug.

**Phase 1A (workflow `ww43hqahv`, RUNNING):** build CartTrigger + Checkout + registry (parallel) →
ThemeShell composer → wire navigable preview (`/storefront-preview`) → typecheck (`tsc -p tsconfig.app.json`)
+ vite build green. Result = the 6-blueprint system FUNCTIONAL end-to-end (home→menu→product→cart→checkout).

**Phase 1B (next):** critique the 6 → pick the 4 keepers; document why; ensure font/vibe customization
covers the dropped variations.

**Phase 1C:** design the 3–4 NEW different-layout archetypes — parallel independent creative agents
(one per archetype, each may add its own sections + shell layout), then a judge panel scoring
distinctiveness/fidelity/"beats Bopple", then I integrate into registry + preview.

**Phase 1D:** adversarial self-critique (a11y, responsive, checkout UX, visual distinctiveness) → fix →
Playwright browser-verify all templates across the 3 judge-screens. Commit + push. Leave for review.

**Review surface:** `/storefront-preview` (template switcher + restaurant/retail toggle + per-template
home/menu/cart/checkout). Cloudflare preview: `feat-storefront-platform.woahh-app.pages.dev/storefront-preview`.

---

## GOAL 2 — Our website UI upgrade (NEW branch `feat/marketing-home-redesign`)

**Objective:** woahh.app marketing site has *too much on the home page*. Split into sections/top-nav;
the home page itself must *capture the audience* fast. Draft **3 state-of-the-art directions**.
Each direction must show **3 judge-screens: marketing home + /eat marketplace + merchant dashboard**.

**Delivery: NON-DESTRUCTIVE preview gallery** (like `/storefront-preview`) — live site untouched until
the founder picks. Build a `/home-preview` (or similar, ApexOnly + noindex) that flips the 3 directions ×
the 3 screens. High-fidelity presentational mockups (judge a design language; not fully wired apps).

**Orchestration:** generate (3 independent agents, one full direction each — divergent) → judge panel
(independent scorers) → I assemble the gallery + self-critique + Playwright-verify. Branch off `master`.

**STATUS: not started** (Goal 1 first).

---

## GOAL 3 — Standalone native merchant app (NEW branch `feat/native-app-platform`)

**Objective:** merchants who want their own app on the **App Store + Google Play**, alongside
everything else. Plan how it works now + future; **execute a Capacitor scaffold** (founder chose
"Capacitor scaffold + plan").

**Scope:** (a) decision-ready architecture/strategy doc (Capacitor vs Expo/RN vs PWA/TWA; per-merchant
white-label build pipeline; store submission, signing, entitlements, push, deep links, OTA updates;
cost/maintenance; phased now→future tied to tiers Growth/Enterprise); (b) a WORKING Capacitor wrapper
committed around the existing Vite/React PWA (iOS + Android shells; per-merchant forced-slug seam already
hinted by `resolveTenant` returning `apex` for `capacitor://`), building locally (Android at least; iOS
needs a Mac/Xcode — document).

**Orchestration:** parallel research readers (Capacitor docs/our-codebase fit/store requirements) →
synthesized plan → ONE focused execution agent for the scaffold (single-writer) → verify build.
Branch off `master`.

**STATUS: not started** (after Goals 1 & 2).

---

## GOAL 1 — FINAL ARCHETYPE MAP (decision 2026-06-07)

**Architecture for "completely different layouts":** the 6 existing blueprints share ONE section-based
home (StorefrontRenderer sections) and differ only in chrome + theme — that's why they read similar.
The NEW archetypes get **bespoke home components** (not the generic section stack). Seam: a
`homes/` registry (id → home component); `ThemeShell` renders `children` so the preview passes the
bespoke home as children for new archetypes, and the section-based home for keepers. Ordering chrome
(nav/cart/menu/product/checkout via ThemeShell) is reused by all.

**KEEP 4 (section-based, customizable via font/vibe/color — identities clarified):**
- `modern-minimal` **Aurora** — Modern Minimalist (design-forward bistro / specialty)
- `editorial-boutique` **Atelier** — Editorial Boutique (artisan / wine bar / plant-based)
- `luxe-noir` **Noir** — Luxe Noir, dark & moody (cocktail bar / steakhouse / izakaya)
- `fresh-organic` **Harvest** — Warm Farm-to-Table (brunch / health)
**Drop from the restaurant picker:** `bold-appetite` (Counter) + `vibrant-market` (Pantry) — their
vibes are recreated stronger by the new Rush/Kerb archetypes (kept in code, not shown for restaurants).

**ADD 4 NEW (bespoke completely-different home layouts):**
1. **Kerb** — Food truck / street food. "We're parked at" location+hours hero, today's menu strip,
   weekly schedule, social photo row, sticky Order. Energetic. Type: Archivo. Ordering: dense-grid +
   sticky-bottom-bar + bottom-sheet checkout.
2. **Daily** — Local cafe / bakery. Cozy welcome, "today's specials" board, opening-hours card,
   loyalty join, warm gallery, story. Type: Fraunces soft. Ordering: photo-card-grid + friendly checkout.
3. **Maison** — Prestige fine dining. Cinematic full-bleed, reservation-first CTA, degustation/prix-fixe
   menu, chef story + portrait, press/awards, muted luxe. Type: Cormorant Garamond. Ordering:
   longform-by-course + dedicated-page checkout.
4. **Rush** — Fast-casual / QSR. Deal/combo hero ("2 for $20"), big category tiles, value combos,
   "order in 3 taps" + app band, fast reorder. Type: Bricolage chunky. Ordering: dense-grid +
   sticky-bottom-bar + bottom-sheet checkout.

Fonts reuse the 6 already-loaded families (CSP-clean) in NEW pairings; each new archetype gets its own
`data-template` typography block in index.css. New template enum values added in storefrontConfig.ts
(code only — DB CHECK not needed for the code-driven preview). Final restaurant set = **8 templates**.

## GOAL 1 — ✅ DONE (pending founder review), branch `feat/storefront-platform`

8 distinct restaurant templates, each functional across **home + menu + checkout** (desktop + mobile,
verified via headless-chromium screenshots). All committed + pushed.

**REVIEW IN THE MORNING:** `/storefront-preview` — Cloudflare branch preview
`https://feat-storefront-platform.woahh-app.pages.dev/storefront-preview`. Use the top switcher to flip
the 8 templates + restaurant/retail; use the bottom-left **Home/Menu/Cart/Checkout** jumper to see each
of the 3 judge-screens per template.
- 4 KEEPERS (section-based, customizable by font/vibe/color): Aurora (modern-minimal), Atelier
  (editorial-boutique), Noir (luxe-noir, dark), Harvest (fresh-organic).
- 4 NEW bespoke (completely different layouts): **Kerb** (food truck — parked-at card, route table),
  **Daily** (cafe — chalkboard specials, punch card), **Maison** (fine dining — reservation-first,
  degustation), **Rush** (QSR — deal hero, combos, app band).

**Key commits:** `4f36ed8` foundation (CartTrigger/Checkout/ThemeShell/registry/preview) · `68529ba`
seams (theming fix + homes registry + 4 enums/typographies/presets/blueprints) · `28afb96` 4 bespoke
homes · `44edaa6` fixes (page-checkout full-screen takeover, preview-nav clearance, Kerb/Rush food hero).

**Self-critique fixes applied:** ThemeShell wasn't theming the chrome → fixed; page-based checkouts
rendered off-screen → now full-screen takeover; preview-nav was hidden behind Kerb's sticky bar → moved;
food-truck/QSR showed a dining-room photo → food-forward hero.

**Deferred (note for review, NOT blockers):**
- These 8 are **preview-only** — the LIVE published storefront (`Shop.tsx`/`PublishedStorefront`) + the
  dashboard template-picker still use the OLD section renderer. Wiring ThemeShell + the 8 into the live
  path + picker is the next integration step AFTER the founder picks favorites (keeps "previews only").
- Keepers Aurora/Harvest share a centered-hero layout (accepted — customizable). Noir vs Maison are the
  closest pair (both dark-elegant); could push Noir toward a nightlife/bar identity later.
- Per-archetype product imagery uses shared fixtures (merchants supply real photos); only Kerb/Rush
  covers were swapped to food shots.

## LIVE STATUS (update + commit after every milestone)
- [2026-06-07] Context recovered; WIP checkpoint `b1c66e3`.
- [2026-06-07] Goal 1 foundation `4f36ed8` → seams `68529ba` → 4 bespoke homes `28afb96` → fixes
  `44edaa6`. 8 templates, screenshot-verified desktop+mobile. **GOAL 1 DONE (pending review).**
- [2026-06-07] NEXT: Goal 2 — website UI upgrade (3 home-page directions preview), new branch
  `feat/marketing-home-redesign`.
- Goal 3: NOT STARTED.
