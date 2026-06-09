# ☀️ Morning report — overnight Square + audit + hardening run (2026-06-09 → 10)

> Read this first. Everything below is **committed LOCAL on `feat/storefront-platform` (6 commits ahead, NOT pushed)** + docs pushed to hub-files. No Cloudflare builds triggered, nothing deployed/merged. Sandbox-only.

## TL;DR
You asked to fully build **Square online payments** + run **rigorous testing** to find issues + reach state-of-the-art, then clean up. Done:
- **Square online payments** built as a 2nd provider (Stripe untouched), **+ the scale features you asked for**: one-and-done org-level OAuth connect, multi-location, GMV view, refunds (+ policy).
- A **deep adversarial audit found real issues we'd missed** — a money/trust defect, an order-confirm/cron double-charge race, a multi-merchant-token hole, Square-ID leaks, and ~12 more — **all fixed + verified** (or staged with a clear reason).
- **Rigorous runtime testing** (Playwright): 48 storefront combos, every good/bad flow — no product bugs; validation gates correct.
- Repo cleaned (superseded docs archived, index added), **CLAUDE.md updated** to current reality.

**The one thing left to make Square actually take a sandbox payment is a deploy** (migrations + edge fns + Square OAuth app), which needs you. Steps below.

## ✅ Built + verified (tsc clean, builds green, 76/76 + 48/48 tests; adversarially reviewed)
| Area | State |
|---|---|
| Square ONLINE payments | authorize → capture-on-confirm, C1 server-total, provider flag (default stripe) |
| One-and-done org Square connect | per-org OAuth tokens (`square_connections`, deny-by-default RLS, HMAC state) — **org-level, staff/tablet-independent** |
| Multi-location | `orders.square_location_id` → connection default → first-active; NULL = single-loc unchanged |
| GMV view | `get_gmv_analytics()` + dashboard widget (paid/authorized/unsettled, per-provider, per-location, nets refunds) |
| Refunds | full/partial, provider-routed, amount-capped, idempotent, owner/manager-only + `docs` policy (in repo-audit) `REFUND_POLICY.md` |
| Audit fixes | BLK-1/2/3/4 + H-1/4/5/6/7/8/9/10/11/12 — see `AUDIT_FINDINGS_2026-06-09.md` |
| Storefront templates | 11 incl. Cantina; previews verified functional; bespoke online-card path |

## 🔎 Issues found + fixed (the headline value)
- **BLK-4 (money):** bespoke add-to-cart button under-quoted paid extras vs the cart → **fixed** (shared price fn; button == cart).
- **BLK-3:** bespoke storefront let un-makeable (sold-out/required-ingredient-out) dishes be ordered → **fixed** (hard-block + bridge re-check).
- **BLK-1 (double-charge race):** owner-confirm vs the auto-decline cron weren't mutually exclusive → **fixed** (atomic claim-before-capture CAS).
- **BLK-2:** a single global Square token would route every merchant's funds to one account → **fixed** (per-org OAuth tokens + fail-closed guard).
- **H-5:** anon/staff RPCs leaked `square_merchant_id`/`location_id` + financial counters → **fixed** (masked).
- **H-6:** an owner could self-flip payment flags → **fixed** (owner-immutable trigger).
- Plus H-1/3/4/7/8/9/10/11/12 (capture-by-order-provider, idempotency, fulfillment-from-settings, sanitisation, empty-cart guard, single price source, Cantina CHECK, webhook fail-closed).
- **Final integration review** (the payment code was assembled across 3 passes; reviewed the combined state) caught **3 more deploy blockers** the per-pass reviews couldn't see — all **fixed**: INT-B1 (a refund-state clobber that re-marked refunded orders `paid` / re-inflated GMV), INT-H1 (anon order-tracker leaked `square_location_id` via migration ordering), INT-H2 (a refund lock-order deadlock). See `AUDIT_FINDINGS_2026-06-09.md` → "Integration review".
- **Staged (need your decision), not silently shipped:** H-2 (release inventory on payment failure), Square AU/AFSL go-live, in-person Terminal.

## ⚡ FOUNDER ACTIONS — to take a Square sandbox payment (in order)
1. **Run `docs/FOUNDER_RUN_NEXT.sql`** in the Supabase SQL editor — it bundles the **11** new migrations in order (the last, `20260610060000_remask_get_order_by_id`, MUST stay last). (Review `20260609050000` payment-col guard + `20260610010000` square_connections — they're security-boundary tables — before applying.) Then **regenerate `types.ts`**.
2. **Square OAuth app** (Square Developer Dashboard): set the OAuth Redirect URL to the `square-oauth-connect` function URL; enable scopes `PAYMENTS_WRITE PAYMENTS_READ ORDERS_WRITE MERCHANT_PROFILE_READ PAYMENTS_WRITE_IN_PERSON`; subscribe the webhook to `payment.*` + `refund.*`.
3. **Edge secrets:** `SQUARE_OAUTH_CLIENT_ID`, `SQUARE_OAUTH_CLIENT_SECRET`, `SQUARE_OAUTH_REDIRECT`, `SQUARE_WEBHOOK_SIGNATURE_KEY`, `SQUARE_WEBHOOK_URL` (+ `SQUARE_ACCESS_TOKEN` already set; optional `SQUARE_SINGLE_ORG_ID`; prod: `SQUARE_API_BASE=https://connect.squareup.com`).
4. **Deploy edge fns:** `square-payment square-webhook order-respond square-oauth-connect square-token-refresh refund-order stripe-webhook`.
5. **Ping me** — I'll flip test-bistro to Square + run the sandbox test card (`4111 1111 1111 1111`) end-to-end (connect → authorize → confirm-capture → refund), with you.
6. **Then decide the final push** (one Cloudflare build) once you've reviewed the storefront visuals + this.

## Notes
- I **did not get a Supabase access token**, so I couldn't deploy/sandbox-test autonomously — everything is build-verified + review-verified; the live sandbox test is step 5 above (~5 min together).
- Local commits ahead of origin (unpushed): demos, Cantina, Square online, fix-1, fix-2, scale (6). One final app push when you approve = one Cloudflare build.
- Detail: `OVERNIGHT_SQUARE_PLAN.md`, `SQUARE_POS_INTEGRATION.md`, `AUDIT_FINDINGS_2026-06-09.md`, `FIRST_MERCHANT_LAUNCH.md`, `repo-audit/docs/REFUND_POLICY.md`.
