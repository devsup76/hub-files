---
name: woahh-wallets-apple-google-pay
description: "Apple Pay + Google Pay (Stripe ECE + Square Web SDK) — MERGED to main + LIVE; Apple Pay device-verified on Square; Google Pay shipped-unverified; adversarial double-check + open items"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a5c9742-6065-4dcb-b9ed-037257b18a15
---

Apple Pay + Google Pay on the customer web checkout, 2026-06-12. **MERGED to `main` + LIVE on woahh.app** (founder explicitly authorized wallets→main; the app repo otherwise stays branch→founder-review). Design + 23-risk register in `docs/architecture/APPLE_GOOGLE_PAY_RISK_AND_DESIGN.md` (now carries a 2026-06-12 "DOUBLE-CHECK — verified status" section). Founder's research doc `docs/architecture/APPLE_GOOGLE_PAY_PLAN.md` is fallible (its "zero server changes" claim was wrong).

**Status — adversarially double-checked 2026-06-12 (5-dim Workflow `wf_7a706c49`, 26 agents, every MEDIUM+ finding verified vs code):**
- **Apple Pay (Square): WORKS — LIVE-VERIFIED on a real iPhone on Test Pizza (PRODUCTION Square account).** Sync `tokenize()` is the first await (Safari gesture rule, verified NOT-A-BUG); double-charge prevented (R15/R16 atomic `try_claim_square_auth` claim-before-CreatePayment + resume-by-payment-id); `paymentRequest.total` in DOLLARS `(amountCents/100).toFixed(2)`.
- **Google Pay (Square): SHIPPED, NOT device-verified.** Render hardened — attaches into a VISIBLE `w-full` container, hides only if unavailable (commit `f718065`; the earlier `hidden`/`h-0` could fail to render Google's button — GPAY-001, verified real, now fixed). Open: **GPAY-002** — the Square-button→container click-bubble needs a real Chrome/Android tap test (fallback if tap doesn't fire = a direct click listener). Google Pay needs NO domain registration/file. **Founder uses iPhone → can't see GP on Safari; test in desktop Chrome (Google-account card) or Android.**
- **Square server (`square-payment` v16, verify_jwt=false): WORKS / SECURE** — atomic claim release-on-throw + linkErr-void, R19 decline allow-list (never raw `errors[].detail`), per-org OAuth token (no global, BLK-2), charge amount from SERVER total (C1), SHA-256 idempotency.
- **Capture path (`order-respond`) SECURITY verified SOLID** — claim-before-capture, provider routing by the order's auth id, H-3 amount-mismatch guard, decline/auto-decline VOIDS pending holds, auto-decline gated to a service_role-claim JWT.
- **Stripe wallets (ECE, `stripe-payment-intent` v30): WORKS in code** (deferred-intent, double-charge prevented, amount parity wallet==Elements==PI, `event.paymentFailed()` on every error path, idempotency bound to amount, separate Elements groups) — NOT device-tested.

**REAL OPEN ITEMS (verified real — do NOT call the surface "fully secure" until addressed):**
1. **R3 PENDING-capture gap [HIGH, prod]** — `order-respond` SILENTLY SKIPS a PENDING (3DS/async) authorization at owner-confirm → order stays unpaid, money never captured. Lower-probability for WALLETS specifically (Apple/Google tokens are pre-authenticated, rarely 3DS-challenged) but a real capture gap. FIX before broad production card reliance — order-respond is incident-prone, do it WITH founder review.
2. **Stripe Apple Pay domain reg [MEDIUM]** — add woahh.app to Stripe's **payment_method_domains** before Stripe merchants' Apple Pay renders (Square's woahh.app domain is already verified + `.well-known/apple-developer-merchantid-domain-association` hosted at `5caf888` and confirmed SERVING HTTP 200 raw token, not SPA-shadowed).
3. **Square SDK env [config, prod]** — woahh.app's `VITE_SQUARE_APPLICATION_ID` must be the PROD app id (`sq0idp-`) so the prod Web Payments SDK loads; `window.Square` is cached per session, so ONE build can't mix sandbox + prod Square merchants. Revert test-bistro's Square-sandbox flip (`docs/sql/SQUARE_SANDBOX_GOLIVE.sql`) before relying on it on prod.
4. **CORS `*.pages.dev` [MEDIUM]** — payment fns accept ANY `*.pages.dev` origin (preview convenience, `_shared/cors.ts`); tighten to the project's own preview hosts. Mitigated by per-order capability checks.
5. **Square OAuth stale-flag [MEDIUM]** — `square_payment_ready` can be stale if a token expires without a flag update; the refresh cron mitigates; add monitoring.

**Verified NOT bugs (don't re-chase):** Apple Pay gesture timing; Square + Stripe double-charge protections; idempotency keys; charges_enabled handling; wallet-init failure never blocks the card fallback.

**Apple Pay domain model at SCALE** (founder asked): registration is per-EXACT-host, NO wildcard (Apple/Stripe/Square all reject `*.woahh.app`). Path-based `woahh.app/shop/slug` = ONE registration covers ALL merchants (done). Subdomains `slug.woahh.app` + custom domains `name.com.au` = one registration PER host, automatable via a **register-on-publish hook** (designed, NOT built); the `.well-known` file is one-and-done (the shared Cloudflare bundle serves every host that points at the Pages project). Custom domains also need per-merchant DNS-onboarding + a `custom_domain→org` map. Apple's ~99-domains/merchant-identifier → Stripe shards, Square unlimited (confirm w/ Stripe support past ~50).

Founder wants a CRITICAL ADVISOR ([[user-wants-critical-advisor]]). Related: [[woahh-order-respond-autodecline-auth]], [[woahh-payments-stripe]], [[woahh-online-order-flow]].
