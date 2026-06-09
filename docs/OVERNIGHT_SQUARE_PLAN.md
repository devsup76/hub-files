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

## Status log
- [~] 1. Square online build (wzi6jmhua) → verify → commit local
- [ ] 1b. Deploy + sandbox E2E (authorize/capture/refund) — DEFERRED (needs Supabase token); one-command-ready for morning
- [ ] 2. Multi-location + one-and-done OAuth connect + GMV + refunds (build + adversarial review)
- [ ] 3. RIGOROUS exhaustive testing (matrix above) → find + FIX issues (loop-until-dry)
- [ ] 4. Templates-functional + scalability + data-integrity audit + fixes
- [ ] 5. Repo cleanup + CLAUDE.md + memory + docs
- [ ] 6. Morning report: what's functional/verified, issues found+fixed, improvements, what needs you
