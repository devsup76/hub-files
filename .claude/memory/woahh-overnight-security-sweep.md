---
name: woahh-overnight-security-sweep
description: Results of the autonomous overnight security audit + hardening of woahh (2026-06-02 night)
metadata: 
  node_type: memory
  type: project
  originSessionId: 5cc244e8-c455-42e8-b8b8-d97c5fa82054
---

User authorized an autonomous overnight security sweep of woahh (2026-06-02 night, asleep, "make it secure, merge to main, I'll review in the morning"). DONE. Isolated worktree `/workspaces/GrowthHub/repo-audit`, branch `security/overnight-sweep` off `main @ e8ba573`.

**Audit:** Workflow `wr5obyucx` — 15 dimensions → **42 findings** (1 critical, 4 high, 8 med, 12 low, 5 info). The verify+report phase hit transient Anthropic rate-limiting, so per-finding verification mostly didn't run (findings are audit-pass; I hand-verified the critical + secdef + headers). 3 audit dims (secdef/idor/bizlogic) returned no structured output; secdef hand-checked clean.

**🔴 CRITICAL #1 (C1, verified twice):** `create_order_with_inventory` trusts client `p_total` and stores it as `orders.total_amount` without recomputing from `products.price` (INTEGER cents); `stripe-payment-intent` charges it → customer can pay 1¢ for any order. Also `p_payload.initial_status` is client-set → can skip the manual-capture hold. **Blocks safe real-card go-live.** Not live-exploitable tonight only because `pk_live` isn't in the prod bundle. Fix staged (`staged-fixes/01`, draft) — needs server-side total recompute (RPC + checkout change). DO NOT enable real card payments until fixed.

**🔴 CRITICAL #2 (C2, found by the verification pass, LIVE-EXPLOITABLE NOW):** `"Owners update their org"` policy on `organizations` has no `WITH CHECK`/column guard → any merchant can `update({tier:'enterprise', founding_merchant:true, sms_monthly_cap:1e6, marketplace_featured:true}).eq('id', myOrgId)` from the browser = free enterprise + permanent 0% commission + unlimited SMS/email + top marketplace placement. No payments/pk_live needed — exploitable today. **MOST URGENT.** Fix: `staged-fixes/06` (REVOKE UPDATE on privileged columns of organizations FROM authenticated — safe high-value part). Also **H5 (HIGH):** customers self-grant loyalty points (`customers.total_points` client-writable) → `staged-fixes/06` (needs companion award RPC). **M9:** fabricate donation totals (donation_ledger self-insert) inflates public Impact leaderboard. **M10:** promo codes enforced client-side only. **jspdf (was H4) = FALSE POSITIVE** (ReDoS regex only on unused addImage/html path) — skip the bump.

**2nd verification workflow `w68ezslq5`** (idor/bizlogic gaps + adversarial re-check) succeeded: confirmed C1+H1, downgraded H2/H3→medium + jspdf→FP, found C2/H5/M9/M10/L15. Branch now at `9171e82` (report + staged-fixes/06 added). Total ~47 findings.

**MERGED to main (live, build-verified):** commit `2f91a65` — low-risk frontend hardening: CSP `*.js.stripe.com` (✅ confirmed live in prod headers), Feedback.tsx `javascript:` URL guard, Tables.tsx HTML-escape, useStorefrontSettings HSL validation, api.ts LIKE escaping. main is now `e8ba573 → 2f91a65` (ONLY this; backend stays on branch).

**STAGED on branch (NOT applied — no DB/deploy creds):** commit `3a4ba61` — `SECURITY_AUDIT_REPORT.md` (full triage) + `staged-fixes/`: 02 delete seeded test acct (SAFE, ready — `WoahhTest2026!` is a live committed credential!), 03 storage bucket limits (SAFE), 01 payment-total CRITICAL (draft, 2 options), 04 RLS public-read/customer-PII drops (verify storefront uses RPCs first), 05 rate-limit scaffold.

**Morning actions for user:** (1) fix payment total before enabling cards; (2) run `staged-fixes/02` + rotate that password; (3) rate-limit reservation/email; (4) `staged-fixes/03`; (5) dep upgrades (jspdf, react-router-dom); (6) **add `VITE_STRIPE_PUBLISHABLE_KEY` to woahh-app PRODUCTION scope** (it's not there — proven: fresh build still lacks pk_live; likely Preview-scoped).

**pk_live status (DEFINITIVE):** woahh.app = `woahh-app` Cloudflare Pages project. After 3 rebuilds + var confirmed Plaintext/correct-name, prod bundle STILL has no pk_live AND prod Shop chunk hash == my local keyless build → the var is NOT in woahh-app's **Production** env scope. Connect Express is live-activated + merchant onboarding verified (see [[woahh-payments-stripe]]); only the Production env var + the C1 payment fix remain before real card payments work safely.

**2026-06-06 SESSION — fixes worked through with the user (live DB changes are user-run in the Supabase SQL editor):**
- ✅ **C2 applied** by user (REVOKE on privileged `organizations` columns; migration `20260603000000`). Live-exploitable hole closed.
- ✅ **H5** (loyalty self-grant): migration `20260603002000` (RPCs `award_order_loyalty_points` + `adjust_loyalty_points` + `orders.loyalty_awarded`) — **Part A run by user; frontend deployed to main (`cc78895`, bundle index-BbiGXGvm)**; **Part B REVOKE `total_points`/`milestone_spend_cents` given to user** (status: told to run — confirm it's done).
- ✅ **M9** (fake donations): migration `20260603003000` DROP donation_ledger insert policy — **DROP given to user**; one-time donate UI replaced w/ "coming soon" (rate slider kept), deployed to main (`17eaa9a`).
- ✅ **M5** (storage limits): migration `20260603004000` UPDATE storage.buckets (10MiB + raster MIME, no svg) — **given to user to run**.
- ⏸️ **C1 + M2 ON HOLD** for the user's restaurant-inventory rebuild (`feat/restaurant-inventory`). C1 fix (server-side order-total validation migration `20260603001000` + promo_code passthrough) is BUILT + frontend deployed (`baceb77`), migration staged for after the rebuild. M2 (stripe-payment-intent anon PI) deferred (payment-gated, not live till pk_live).
- ⏸️ **L4** (staff customer PII) DEFERRED — entangled: KDS/Orders read `customers(name)` join for kitchen/service; needs `customer_name` denormalized onto orders (do with the order rebuild) not a blanket RLS lock.
- 🔲 Remaining "rest": M1 (account-recover spoofable-IP throttle, edge fn), react-router-dom→6.30.2, L1/L2 cross-tenant menu/table reads, M6/M7 rate limits.
- ⚠️ H1 (seeded test pw `WoahhTest2026!`): do NOT delete (it's the user's test login) — rotate password + scrub from CLAUDE.md instead.
- All fix migrations live on branch `security/overnight-sweep`; frontend halves merged to main.

**MARKETING/COMPETITIVE (2026-06-06, main = `25df918`):** removed Uber Eats/DoorDash column from landing comparison table (`25fa037`). Bopple research (verified): Bopple is a NEAR-PEER (lower fee ~1.8%+card, HAS discovery marketplace bopple.app, owns-customer, full back-of-house, CRM/loyalty, browser-based; live delivery via Uber Direct/DoorDash) — only clearly loses on reservations + giving. **Adding an honest Bopple column would undercut the "why Woahh wins" table → user deciding (lean: reframe or keep internal).** **Retail shop-model competitor landscape SAVED to `docs/COMPETITORS_SHOP.md` on main** (49 competitors): closest rivals Shopify(+Shop app), Square, Shopline, Lightspeed X-Series, Hike POS, Epos Now; Woahh wedges = marketplace + giving + bundled price + Uber-Direct courier; honest vuln = retail POS not shipped yet.

Re-running a focused verification pass (idor/bizlogic gaps + adversarial re-check of top findings). Related: [[woahh-payments-stripe]], [[woahh-sms-architecture]], [[woahh-restaurant-inventory]].
