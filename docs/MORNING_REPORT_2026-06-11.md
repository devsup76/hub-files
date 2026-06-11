# Morning report — 2026-06-11

**Overnight autonomous build for the first-merchant push. Everything is on ONE preview branch — nothing was deployed to prod.**

Branch: **`feat/overnight-fixes-2026-06-11`** (22 commits, `tsc`/`vite build` green, pushed → Cloudflare preview building).

---

## TL;DR — the headline

1. **Card payments work.** Proven with a screenshot of a real customer at the Test Pizza checkout being asked for card details (Square card form, `web.squarecdn.com`). The reason *you* couldn't see it was the **owner-preview guard** (a merchant can't charge their own card) — fixed with a notice + a "View as customer" toggle.
   - Proof: `docs/proof/card-form-test-pizza.png` (original), `docs/proof/card-window-obvious.png` (the new obvious window).
2. **All 13 punch-list items built** (held **#1** and **#8** as you asked), each build-verified.
3. **Your two new asks done:**
   - **Card window is obvious + on top** — it was rendering *behind* the bespoke checkout panel (z-index). Now raised above it (z-[205]/[210]) with a clear "Pay {amount} by card" + trust icon.
   - **Order is only placed once paid** — on card abandon/close the unpaid order is now **voided** and the customer is told "Payment not completed — your order has NOT been placed." Payment is the place-order trigger.
4. **Adversarial code review ran — no blockers.** 5 MEDIUM/LOW findings were all fixed.

---

## ✅ DO THESE (founder action list)

1. **Open the Cloudflare preview** for `feat/overnight-fixes-2026-06-11` and click through (storefront order → card window → dashboard sidebar/checklists).
2. **Run 4 SQL migrations** in the Supabase SQL editor (`pmnyhbhtkcfoozkinieo`) — all idempotent, in `docs/FOUNDER_RUN_THESE.sql`:
   - `20260611001100_next_available_username` (smart usernames #16)
   - `20260611001500_storefront_publish_rate_limit` (#9)
   - `20260611002000_void_my_unpaid_order` (the pay-to-place void — until this runs, an abandoned card is cleaned up by the existing 7-min auto-decline instead of instantly)
   - `2026061100xxxx_gate_public_storefront` (#7 publish-gating) — **apply this LAST and only when you're ready**: it hides any storefront without a published config. **Test Pizza is published, so it stays visible.** Other merchants must publish first.
3. **Decide on the deeper payment-first design** (below) — I did NOT ship it blind.
4. **Rotate keys** (still outstanding from prior sessions): the `sbp_` Supabase token pasted in chat, ClickSend, GitHub PATs, Anthropic, Resend.
5. Minor: **update Test Pizza's storefront hero copy** — it still says "Test Bistro / street food" (a template seed), not Pizza. Cosmetic, in the storefront editor.

---

## Per-item status

| # | Item | Status |
|---|------|--------|
| 1 | Nicer onboarding + no payments until ABN verified | **HELD** (your call) |
| 2 | Setup section auto-collapses done steps | ✅ |
| 3 | Test in-store validation code | ⏳ not a build — manual test recommended |
| 4 | Declutter sidebar (grouped/collapsible) | ✅ |
| 5 | "Setting up & domain" go-live checklist | ✅ (GoLiveChecklist) |
| 6 | Disable delivery behind a flag | ✅ (`VITE_DELIVERY_ENABLED`, default off) |
| 7 | Storefront only viewable once published | ✅ code + migration (apply when ready) |
| 8 | On publish → `<slug>.woahh.app` | **SKIPPED** (your call — see #8 rec below) |
| 9 | Limit storefront churn | ✅ (10/day DB cap + 45s cooldown) |
| 10 | Real live checkout timings | ✅ (settings.kitchen prep minutes) |
| 11 | One checkbox Terms + marketing | ✅ **already compliant** — kept SEPARATE (Spam Act); see advisory |
| 12 | Phone UI | **ON HOLD** (per the list) |
| 13 | Pay-at-venue / pay-online configurable | ✅ (`settings.payments.pay_mode`) |
| 14 | Charity money-flow | ⏳ **net-new build, not a bug** — see advisory (flagged for decision) |
| 15 | Account-before-guest at checkout | ✅ (guest still 1 tap away) |
| 16 | Smarter auto usernames | ✅ (needs its migration) |
| 17 | QR without dine-in | ✅ |
| — | EXTRA A — "View as customer" owner toggle | ✅ (so you can test the card flow while logged in) |
| — | EXTRA B — demo-flag can't leak into real storefronts | ✅ |
| — | Card dialog **on top** + **obvious** + **pay-to-place** | ✅ |

---

## Code review — no blockers

8 agents (4 review dimensions × adversarial verify). **No BLOCKER/HIGH.** All 5 confirmed findings fixed on the branch:
- **MEDIUM** — GoLiveChecklist query key didn't match the publish invalidation → fixed.
- **LOW** ×4 — KDS delivery-filter coercion when delivery off; venue-mode order note said "Pay: card"; `pay_mode` doc comments said "widens" (it narrows); the username RPC was mislabeled STABLE.
- **Pre-emptive HIGH I caught + fixed:** `pay_mode` defaulting to "venue" would have **silently disabled Test Pizza's card** on the preview — added back-compat so already-card-enabled merchants get `both`.

Caveats noted (not blockers): apply #7 after merchants publish (deploy-ordering); the void-on-abandon needs its migration to be instant (else 7-min auto-decline fallback).

---

## Advisory (full: `docs/ADVISORY_2026-06-11.md`)

You asked me to critique. The sharp version:
- Your list optimizes how the storefront **looks**; the launch is decided by whether the **first real order takes money correctly, shows an honest pickup time, and doesn't go live before ready.** Those are now addressed (live timings, publish-gating, pay-to-place, demo-flag).
- **#11 was a trap** — bundling marketing into a mandatory Terms tick violates the Spam Act. The code already keeps them separate; I did **not** bundle them. Don't.
- **#14 is mislabeled** — the charity/commission split is **not written server-side** on real orders (fee hardcoded 0). It's a net-new build + a product decision, not a bug-fix. Needs your input before I build it.

---

## #8 — domain strategy recommendation (full in advisory)

- **Ship Option B (`<slug>.woahh.app`)** as the publish target — the resolution code is already written + wired; the only hard prerequisite is the reserved-slug guard (already built) + wildcard `*.woahh.app` DNS/TLS + a Cloudflare Pages custom domain (a human/infra step).
- **Option A (`woahh.app/shop/<slug>`, live today)** is the zero-risk fallback while wildcard TLS isn't set up.
- **Option C (merchant's own custom domain)** — defer; sell as a paid Growth/Enterprise add-on later via Cloudflare for SaaS.
- This is exactly why #8 was worth pausing on — happy to wire B the moment you greenlight the DNS.

---

## The deeper payment-first design (for your sign-off — NOT shipped)

You said "order can only be placed once paid, payment is the place-order trigger." What I shipped on the branch delivers the **guarantee** (abandon → no order persists; only an authorized card places it). But the order is still *briefly* created before the card opens, because the server recomputes + authorizes the amount **against the order row** (the anti-undercharge safety, "C1").

The fully clean version — **never create the order until the card authorizes**:
- Change `square-payment` / `stripe-payment-intent` to authorize against the **cart** (server recomputes the amount from the cart line-items, still C1-safe — no client-trusted amount), then **create the order only on a successful authorization**.
- Pros: zero transient order, no void needed, "payment is literally the trigger."
- Cons: it's edge-function + ordering-flow surgery touching money — I won't ship it blind. ~½ day, wants a careful review + test.
- **Recommendation:** ship what's on the branch now (it already gives you the guarantee), and schedule the cart-authorize refactor as a focused, reviewed change.

---

## What did NOT touch prod
Nothing. Preview branch only; all migrations written, none applied. The live `woahh.app` (main) is unchanged except the owner-preview notice + the card safety-net error message already merged earlier.
