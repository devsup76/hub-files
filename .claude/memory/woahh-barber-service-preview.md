---
name: woahh-barber-service-preview
description: "Triple A Barbershop (Daisy Hill QLD) \"Woahh for services\" booking preview — 3 customer skins + merchant dashboard, branch feat/barber-service-preview (worktree repo-barber), PUSHED for Cloudflare preview 2026-06-10/11 overnight"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8247c908-37ec-4f1c-bcb5-8c2df7a2fb0a
---

**Triple A Barbershop service-booking preview** — built overnight 2026-06-10→11 (founder asleep, autonomous). First "Woahh for services" vertical, exclusive to this one merchant.

- **Where:** worktree `/workspaces/GrowthHub/repo-barber`, branch `feat/barber-service-preview` (off `feat/storefront-platform`), PUSHED → Cloudflare preview builds per push. Routes: `/tripleabarbers-preview` (skin chooser), `?ui=heritage|olive|fade` (3 fully distinct customer skins), `?ui=admin` or `/tripleabarbers-admin` (merchant dashboard). All client-only (localStorage world store, cross-tab sync via BroadcastChannel) — NO backend/DB.
- **Merchant facts:** Triple A Barbershop, 4-14 Allamanda Dr Daisy Hill QLD 4127, (07) 3416 2643, IG @triple_a_barbershop, barbers Hakeem + Jai. NOT on Booksy/Fresha; real prices NOT findable online (tripleabarber.com is a DIFFERENT shop in Indiana, USA — do not use). **Prices in the preview are placeholders** calibrated to Logan-market Booksy scan (cuts $30-60, skin fades $50-75, beards $20-35) — founder to supply real list; admin Services section has a placeholder banner + full price editor.
- **Booking rules (founder-specified 2026-06-10):** 15-min slot grid; each booking blocks ONE chair for 60 min; capacity = barbers/day (default 2, per-day editable in admin Hours & capacity); free gaps of 30–45 min render as "call us to squeeze in" pills (shop phone), NOT bookable slots; NO per-barber booking (book the shop). Engine: `src/pages/preview/barber/engine.ts` (pure functions, injectable now).
- **Home visits:** callout $35 + $1.50/km from shop, 25km cap, +30min travel chair-block — industry-calibrated (Perth $50 callout, Melbourne $1/km examples), all merchant-editable; suburb→km table (SUBURB_KM) + slider calculator.
- **Skins:** Heritage (old-money editorial, Cormorant Garamond, black-gold-olive, booking in right drawer), Olive Club (majority-olive members-club bento, Fraunces, persistent booking rail — the founder's palette brief), Fade District (street poster, Archivo 900, marquees, polaroids, full-screen takeover). Shared themable `BookingFlow` via `--ab-*` CSS vars in `shared.tsx`. Admin: chair timeline (the wow), bookings, services/prices, promos, hours+capacity, home-visit pricing, loyalty, customers, notification log (mock email/SMS), settings+reset.
- **Verified:** tsc + vite build green; Playwright E2E booked on all 3 skins (refs issued, email/SMS mocks + ICS render, zero console errors); cross-tab → admin slot consumption confirmed. Screenshot gotcha: use fixed-viewport shots, helper /tmp/rt-shot.mjs + flow probe /tmp/ab-flow.mjs (dev server localhost:8087 in-container).
- **Infra lesson:** subagent API sockets dropped repeatedly overnight (4 long-running agents died with "socket connection was closed"; ~6h lost). Keep overnight subagent tasks SHORT; long agents that survive: fine; >1h without completing: assume dead and rebuild inline.
- **Next:** founder uploads real prices (paste into admin or update `data.ts` SERVICES); optional deeper design-critique pass; if approved → productionise as the Woahh services vertical (real DB schema, payments, SMS/email via existing infra).
