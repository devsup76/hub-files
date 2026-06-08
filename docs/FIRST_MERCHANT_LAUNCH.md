# First-Merchant Launch — readiness + FOUNDER HANDOFF

> **Living doc — updated continuously during the 2026-06-08 autonomous run.**
> Goal: a first restaurant merchant fully onboardable on **`name.woahh.app`** with
> **CRM + cloud POS + online ordering (incl. online card payments)** — everything we
> say is functional *actually* functional. Branches + preview only; **merge to main
> only after the restaurant approves.** Crash-recovery: read this + memory
> `woahh-overnight-3goals` + `docs/OVERNIGHT_PLAN_2026-06-07.md`.

## Mission (6h autonomous, founder away)
1. Finish **guest checkout** (anon-auth + email/T&C/marketing consent + account nudge).
2. **C1 — server-side order-total validation** so **online card payments are safe + functional** (no more client-trusted total).
3. Verify **CRM + cloud POS + online ordering + payments** are genuinely functional (hard E2E).
4. **Website redesign preview** running (6 directions) on its branch — not merged.
5. This **FOUNDER HANDOFF** ready: every migration (in order) + Supabase/Stripe/Cloudflare action you must do, + the merchant-onboarding steps.
6. Keep committing + pushing; docs current.

---

## ⚡ FOUNDER ACTIONS WHEN YOU'RE BACK (the to-do list)

> Run in this order. Each item links to where the SQL/steps live. ✅ = ready, ⏳ = being prepared.

### A. Database migrations (Supabase SQL editor, in order)
1. ✅ **Storefront config** (DONE — you ran these): `20260603010000` → `20260603020000` → `20260607010000`.
2. ⏳ **Guest-checkout consent** (`20260608010000_guest_checkout_consent.sql`) — T&C columns + `upsert_my_consent` RPC. *(SQL will be pasted here when the build lands.)*
3. ⏳ **C1 — server-side order-total validation** — hardens `create_order_with_inventory` to recompute the authoritative total server-side before any card capture. **Required before taking real cards.** *(SQL will be pasted here after the C1 work + review.)*
4. ⏳ After all migrations: **regenerate types** — `npx supabase gen types typescript --project-id pmnyhbhtkcfoozkinieo > src/integrations/supabase/types.ts` (or Dashboard → API → generate). Clears the `as any` casts + the 8 pre-existing tsc errors.

### B. Supabase Auth settings (Dashboard → Authentication)
- ⏳ **Enable Anonymous sign-ins** (Providers) — required for guest checkout.
- ⏳ **Enable bot protection** (Turnstile/hCaptcha) on the same screen — guards anon-sign-in abuse.
- For `name.woahh.app` later: add `https://*.woahh.app/**` to the redirect allow-list.

### C. Stripe (online payments)
- ⏳ Confirm Connect Express is live + the merchant is onboarded (Connect onboarding link). *(Details after the payments pass.)*
- Local/preview testing of cards needs `VITE_STRIPE_PUBLISHABLE_KEY` in the env (prod already has `pk_live`).

### D. name.woahh.app (when ready to go live for the merchant)
- See `docs/MERCHANT_ONBOARDING_RUNBOOK.md` — Cloudflare DNS + Pages custom domain + TLS + the guarded `subdomain_slug` SQL.

### E. Create the first merchant account (you said you'll do this with me)
- We'll create the org, import the menu (AI import), set branding, pick a template, publish, set the slug, and verify end-to-end together.

---

## STATUS (functional vs pending)
| Capability | State |
|---|---|
| Storefront templates (8) | ✅ render live (migrations applied); preview at `/storefront-preview` |
| Bespoke template publish → live render | ✅ verified (maison/kerb on test-bistro) |
| Cloud POS (walk-in) + KDS | ✅ verified functional |
| Online ordering (menu→cart) | ✅ verified (default + bespoke) |
| Guest checkout | ⏳ building (needs migration #2 + anon-auth toggle) |
| Online card payments | ⏳ pending C1 (#3) + Stripe config |
| CRM | ⏳ to verify this run |
| Website redesign (6 directions) | ✅ built/pushed; preview on `feat/marketing-home-redesign` |

## Fixes already shipped this run (branch `feat/storefront-platform`)
- `da3140b` storefront fail-safe (Stripe guard + getPublic 404) · live-wiring `7a573e4` · (more below as they land).

## LIVE LOG (append per milestone)
- [2026-06-08] 6h mission started; guest-checkout build running (`weex56az3`).
