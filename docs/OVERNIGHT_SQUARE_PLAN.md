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

## Status log
- [ ] 1. Square online build (wzi6jmhua) → verify → commit local
- [ ] 1b. Deploy + sandbox E2E (authorize/capture/refund) — needs Supabase token
- [ ] 2. Multi-location + one-and-done OAuth connect + GMV + refunds
- [ ] 3. Templates-functional + scalability audit + fixes
- [ ] 4. Repo cleanup + CLAUDE.md + memory + docs
