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

## Status
- [ ] Square research (workflow) → `docs/SQUARE_POS_INTEGRATION.md`
- [ ] No-image placeholders (shared)
- [ ] Full menu + checkout demo nav + deep-links (both)
- [ ] Taco Joint richer + dark mode
- [ ] Render-verify all + commit/push

## Notes / decisions
- Wingz Hut = Counter (dark, default) / Kerb. Taco Joint = Rush (default) / Harvest; now + dark mode.
- Taco Joint drink prices are placeholders (Jarritos/Mexican Coke/Horchata/Water) — confirm later.
- Crash-recovery: this file + memory `woahh-overnight-3goals` + `docs/MERCHANT_ONBOARDING_RUNBOOK.md`.
