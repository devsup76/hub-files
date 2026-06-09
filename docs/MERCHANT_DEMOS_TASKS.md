# Merchant demos + Square research — task block (2026-06-09, founder away ~2h)

Branch `feat/storefront-platform`. All visual/preview + research; no backend, no merge.

## Tasks
1. **Taco Joint — richer + more colour + DARK MODE.** The Rush/Harvest render read a bit basic/sparse.
   Use the green/red/cream/navy/masa palette MORE (festive sections, richer backgrounds, accent pops,
   tasteful pattern touches), and add a **dark-mode variant** (dark bg + vibrant pops) selectable via
   `?mode=dark` + a toggle in the preview header.
2. **Full menu + checkout demo pages — BOTH merchants.** Make `/wingzhut-preview` + `/tacojoint-preview`
   a complete navigable demo: home → **menu page** (full browse) → add to cart → **checkout page**
   (full flow; final "place order" stays an inert "Demo" no-op). Deep-linkable via `?screen=menu` /
   `?screen=checkout` so menu + checkout can be opened directly. Keep no real backend/order/Stripe.
   - Sub-fix (benefits both + real merchants): tasteful **no-image placeholders** (branded gradient +
     glyph + item name) so menu cards without dish photos look polished, not empty.
3. **Square POS integration research.** How Woahh could integrate **Square** — the in-person hardware
   (Square Terminal / Reader / Mobile Payments SDK) AND online (Web Payments SDK + Payments/Orders API),
   multi-merchant via Square OAuth, multi-location, vs the current Stripe Connect model. Write a
   decision-ready plan → `docs/SQUARE_POS_INTEGRATION.md`.

## Status — ALL DONE (app code committed LOCAL ONLY `a9092f4`, NOT pushed; view via localhost)
- [x] Square research → `docs/SQUARE_POS_INTEGRATION.md` (pushed — docs repo, no Cloudflare)
- [x] No-image placeholders (shared, theme-derived, dark-adaptive)
- [x] Full menu + checkout demo nav + deep-links (both merchants)
- [x] Taco Joint richer (festive green/red/masa bands) + dark mode + Light/Dark toggle
- [x] Render-verified all (browser screenshots, light+dark, menu+checkout, both) — committed LOCAL only

### View on localhost (`cd repo-audit && npm run dev` → :5173)
- Taco light/dark: `/tacojoint-preview` · `/tacojoint-preview?mode=dark`  (+ `?t=harvest`)
- Taco menu/checkout: `/tacojoint-preview?screen=menu` · `?screen=checkout` (add `&mode=dark`)
- Wingz menu/checkout: `/wingzhut-preview?screen=menu` · `?screen=checkout`  (+ `?t=kerb`)
- Templates: Wingz `?t=counter|kerb` · Taco `?t=rush|harvest`

### Pending founder decisions (no rush)
- Per merchant: pick template + (Taco) light vs dark default; confirm Taco drink prices; any copy/colour tweaks.
- **One final push when approved = one Cloudflare build.** Square plan awaits greenlight.

## Notes / decisions
- Wingz Hut = Counter (dark, default) / Kerb. Taco Joint = Rush (default) / Harvest; now + dark mode.
- Taco Joint drink prices are placeholders (Jarritos/Mexican Coke/Horchata/Water) — confirm later.
- Crash-recovery: this file + memory `woahh-overnight-3goals` + `docs/MERCHANT_ONBOARDING_RUNBOOK.md`.
