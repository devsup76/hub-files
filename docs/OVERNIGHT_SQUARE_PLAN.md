# Overnight autonomous run — Square integration + scale audit + cleanup (2026-06-09 → 10, founder asleep)

Authority: build + commit **LOCAL ONLY** on `feat/storefront-platform` (NO app-branch pushes — Cloudflare).
Docs push to `hub-files` (no Cloudflare). Deploy edge fns to Supabase only (separate from Cloudflare).
Sandbox-only Square testing (founder's live account NOT needed). Crash-recovery: this file + memory
`woahh-overnight-3goals` + `docs/SQUARE_POS_INTEGRATION.md`.

## Founder inputs
- ✅ Square Sandbox App ID `sandbox-sq0idb-MNrX3w-C63OrW82EZjLr3Q` (in frontend env via build)
- ✅ `SQUARE_ACCESS_TOKEN` sandbox secret set in Supabase edge secrets
- ⏳ **Supabase access token (sbp_)** — needed to DEPLOY + sandbox-test autonomously; else build+verify only, deploy-ready for morning. ROTATE after use.
- Test merchant = test-bistro (flip to Square via settings flag; reversible, no migration).

## Priorities (in order)
1. **Square ONLINE payments — fully functional** (workflow `wzi6jmhua` running): square-payment + square-webhook + order-respond capture branch + provider flag + Web Payments SDK + CSP, gated by C1. Verify → (deploy + sandbox E2E if token) → commit local.
2. **Scale/merchant factors (design + build):**
   - Multi-location (Square `location_id` per merchant location; order→location; one connection covers all).
   - One-and-done **org-level** Square connect (OAuth) — staff/tablet-independent; easy setup; works online + (later) every reader.
   - **GMV visibility** (gross value moved through Square + overall) in dashboard/analytics.
   - **Refunds** — `RefundPayment` flow + Orders refund action + step-by-step policy doc (full/partial, who, timing).
   - In-person designed/stubbed (Terminal API per location/reader) — after online.
3. **Templates-functional + scalability audit:** every storefront button/flow works; multi-tenant isolation holds; no per-merchant code; no data-loss-on-scale; additive-only schema. Fix criticals.
4. **Repo cleanup:** clean folders, archive superseded docs + scratch files; fix CLAUDE.md; update memory + docs.

## Design invariants (industry-level, scalable)
- Payment is an **adapter** (`payment_provider` per org, default stripe). Stripe path byte-for-byte unchanged.
- All schema changes **additive + idempotent**; no destructive migrations; no data-loss risk.
- Square connection + tokens stored at **org level** (not per-staff/device); refresh-token cron for OAuth.
- C1 server-validated total is the ONLY charge amount (Square + Stripe). No client-trusted amounts.

## ⚡ FOUNDER DIRECTIVE (2026-06-09 night): RIGOROUS TESTING — every scenario, good AND bad.
"State-of-the-art level, find issues we missed, slight improvements, keep being better." No Supabase
token provided → Square = BUILD + heavy adversarial review + a one-command deploy/test ready for morning;
pour runtime-testing rigor into everything testable LOCALLY. Use loop-until-dry bug hunting + adversarial
multi-lens review. Fix what's found; log every fix + every slight improvement.

### Exhaustive test matrix (local, Playwright + code review)
- **Storefront × all 11 templates**: render; every button/flow — browse, category filter, search, add-to-cart,
  customize (extras/required ingredients/removed), quantity, remove, cart, checkout steps (fulfillment ×4,
  contact, payment), guest checkout (email/T&C/marketing/SMS), sign-in path, deep-links (?screen=, ?t=, ?mode=, ?accent=).
- **Good + BAD inputs**: empty cart, invalid/empty email, T&C unchecked, 0/huge/negative qty, special chars/emoji/very
  long names, sold-out/required-ingredient-out items, promo edge cases, dine-in vs delivery vs pickup vs shipping,
  no-image fallbacks, demo/preview inertness, missing Stripe/Square key fallback.
- **Multi-tenant + scale**: isolation (no cross-merchant leak), no per-merchant code, additive schema, data-loss
  risks, order/payment state machine, concurrency (multi-tablet), realtime + polling fallback.
- **Square (code-review, can't runtime w/o deploy)**: good payment, declined, partial/full refund, double-submit,
  network-fail mid-pay, location mismatch, token expiry, webhook replay/spoof, amount tampering (C1), currency, multi-location.
- **Accessibility/responsive/perf** spot checks; **slight improvements** logged + applied where low-risk.

## PROGRESS (2026-06-09 night)
- ✅ Square online build done + committed LOCAL (`a9aef21`). Sandbox deploy/test = one command (deferred, needs Supabase token).
- ✅ Runtime tests (Playwright, inert previews): 48 render combos no errors; Cantina functional; bad-input gates correct; live /shop path works. No runtime product bugs.
- ✅ Deep adversarial audit (`wqmedoy16`) → `docs/AUDIT_FINDINGS_2026-06-09.md`. **Found real issues:** BLK-4 (money: bespoke button price ≠ cart), BLK-3 (bespoke no sold-out block), BLK-1 (order-respond confirm/cron race → double-charge), BLK-2 (single Square token = all funds to 1 acct → OAuth needed), H-1..H-12 (fulfillment/sanitise/price-divergence/cantina-CHECK/webhook-URL/RPC-leaks-square-ids/idempotency/owner-self-set-payment-cols/inventory-DoS).
- ▶ Fix pass 1 (`wa9fq5z96`, RUNNING): tonight-local correctness/money — BLK-4, BLK-3, H-4, H-8, H-9, H-10, H-11(+migration), H-12 → review → verify.
- NEXT: fix pass 2 (payment hardening — BLK-1 claim-before-capture, H-1 provider-from-order, BLK-2 guard, H-3/H-7 idempotency, H-6 payment-col trigger, H-5 masking migration). Then scale build (Square OAuth one-and-done + multi-location + GMV + refunds = fixes BLK-2 properly + founder asks). Then cleanup + CLAUDE.md + report. Stage for founder decision: H-2 (inventory release).

## Status log
- [x] 1. Square online build (wzi6jmhua) → verified → committed local `a9aef21`
- [ ] 1b. Deploy + sandbox E2E (authorize/capture/refund) — DEFERRED (needs Supabase token); one-command-ready for morning
- [ ] 2. Multi-location + one-and-done OAuth connect + GMV + refunds (build + adversarial review)
- [ ] 3. RIGOROUS exhaustive testing (matrix above) → find + FIX issues (loop-until-dry)
- [ ] 4. Templates-functional + scalability + data-integrity audit + fixes
- [ ] 5. Repo cleanup + CLAUDE.md + memory + docs
- [ ] 6. Morning report: what's functional/verified, issues found+fixed, improvements, what needs you

## PROGRESS (cont.)
- ✅ Fix pass 1 (correctness/money) committed LOCAL `46df6cc`: BLK-3, BLK-4, H-4/8/9/10/11/12 + cantina CHECK migration + parity test. 76/76 tests.
- ✅ Fix pass 2 (payment hardening) committed LOCAL `c01bcf6`: BLK-1 (claim CAS), H-1, BLK-2 guard, H-3/H-7, H-6, H-5 + 3 additive migrations (20260609040000/050000/060000). tsc/build green.
- ▶ Scale features (`wmzasllnk`, RUNNING): org-level one-and-done Square OAuth connect (per-org tokens, fixes BLK-2) + multi-location + GMV view + refunds (+ REFUND_POLICY.md).
- NEXT: repo cleanup + fix CLAUDE.md + update memory + MORNING REPORT (consolidated: built/verified, issues found+fixed, migrations to run in order, deploy steps, decisions for founder).
- Local commits ahead of origin (unpushed): demos+cantina+square+fix1+fix2 (5). ONE final app push when founder approves.
