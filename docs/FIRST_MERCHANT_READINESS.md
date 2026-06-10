# First Merchant Readiness — GO / NO-GO

> Synthesized 2026-06-10 from four independent audits: (1) Merchant Onboarding Journey, (2) Customer Journey + Payments, (3) Deployment Mechanics + DB/Frontend Version Match, (4) Residual Risks / Day-1 Showstoppers.
> Scope: deploying the `feat/storefront-platform` work to prod and onboarding the FIRST founding merchant as a **Stripe-only** pilot. Square is sandbox-only and out of day-1 scope.

---

## 1. VERDICT

**GO-WITH-CONDITIONS** — every onboarding and payment *step* is built, wired, and (for the money path) live-verified; the only thing between "built" and "a real merchant is live" is **shipping plumbing** — push + merge the 31-commit branch to the default branch, redeploy a handful of edge functions in lockstep, and confirm the drift hotfix — not any unfixed correctness or money bug.

---

## 2. WHAT IS VERIFIED READY

- **All DB migrations are applied to live** (`pmnyhbhtkcfoozkinieo`): guest-consent (`20260608010000`), C1 server-side total (`20260608020000`), anon-trigger guard (`20260609010000`), Square additive (`20260609020000`), payment-column write-guard (`20260609050000`), RPC masking (`20260609060000`), and the drift hotfixes (`20260610070000`, `20260610080000`).
- **RPC drift smoke gate is 8-clean / 0 failures** against the live DB (`scripts/rpc-drift-smoke.mjs`) — the single best go/no-go check; it proves the live anon RPCs are self-consistent with the live schema and that the public storefront + order tracker no longer 42703.
- **The two latent schema landmines are backfilled on live**: `organizations.phone_otp_attempts` and `account_recovery_log.ip` both resolve (rows-0, not 42703).
- **C1 server-side order-total validation is the live, authoritative definition** — a tampered $0.01 order was rejected live ("below the authoritative minimum"). Item revenue cannot be underpaid. Safe to take real cards.
- **Full guest checkout + order → KDS chain verified live this session** (anon session → consent → C1 order → `awaiting_confirmation` → confirm → capture → KDS).
- **Stripe is the correct default and the path is intact** end-to-end: `payment_provider` defaults to `'stripe'` NOT NULL; `stripe-payment-intent` recomputes the amount from `orders.total_amount` (never the client), destination charge to the merchant, manual capture on owner-confirm, idempotency `pi-${order.id}`; founding-merchant `application_fee_amount = 0`.
- **`order-respond` has the BLK-1 atomic claim-before-capture guard** (via `claim_order_for_response`, RPC already on live) — closes the confirm/decline/auto-decline-cron double-charge race.
- **Square is inert for a Stripe merchant**: default flag `stripe`, `square_payment_ready` default `false`, write-guard trigger reverts unauthorized flips, SDK lazy-loaded only on the Square branch, sandbox-hardcoded. Missing `VITE_SQUARE_*` degrades gracefully to pay-at-venue and never crashes.
- **The merge is a clean fast-forward** — `origin/main` is an ancestor of the branch HEAD (zero conflicting commits); apex root route is the only change and resolves to the unchanged `<Storefront/>` on `woahh.app` and on every `*.pages.dev` preview; new routes are purely additive; subdomain behavior stays dormant until wildcard DNS is added (not needed for merchant #1).
- **Build is green**: `vite build` exits 0. The 8 pre-existing tsc errors are cosmetic (stale generated `types.ts`) and do NOT reach the bundle (Vite/esbuild does not type-check).

---

## 3. THE EXACT REMAINING STEPS (in order)

> Tags: **[FOUNDER]** = human action; **[CLAUDE]** = agent/CLI action. **HARD-GATE** = must clear before a real merchant; **nice-to-have** = ship around it.

### A. Pre-flight gates
1. **[CLAUDE] HARD-GATE — Run the drift smoke gate.** `node scripts/rpc-drift-smoke.mjs` → expect `8 ran clean, 0 drift failures`. This validates the masking-RPC-vs-live-schema match the whole deploy depends on. Re-run after any further migration.
2. **[CLAUDE] HARD-GATE — Confirm the RPC-drift hotfix (`20260610070000`) is the LAST-applied definition of `get_public_storefront` / `get_member_org` / `get_order_by_id` on live.** A 42703 in these already broke prod once; the smoke gate passing is strong evidence, but verify the hotfix sorts last and is the live-active body before treating it as done.
3. **[CLAUDE] nice-to-have — Regenerate `types.ts`** (`npx supabase gen types … > src/integrations/supabase/types.ts`). Clears the 8 stale tsc errors and the `as any` casts (`storefront_config`, `square_connections`, `founding_access_codes`, `get_gmv_analytics`). Not runtime-blocking, but ship it with the merge so the next real type error isn't masked.

### B. Ship the code
4. **[CLAUDE] HARD-GATE — Sync local default branch to its remote** before merging (local `main` is behind `origin/main`), so the merge is a clean fast-forward. Confirm `.env` (the only modified working-tree file) is NOT committed — it holds local secrets.
5. **[CLAUDE] HARD-GATE — Redeploy the Stripe-critical edge functions in lockstep with the merge**: `npx supabase functions deploy order-respond stripe-webhook`. `order-respond` depends on the `claim_order_for_response` RPC (already live). Also redeploy `stripe-payment-intent` and `stripe-connect-onboard` so the live functions match the shipped frontend. The Square/refund functions deploy-but-dormant; harmless.
6. **[CLAUDE] HARD-GATE — Redeploy + smoke `owner-verify` and `account-recover`** so the live functions run the repo versions that read the now-backfilled `phone_otp_attempts` / `recovery_log.ip` columns. `owner-verify` selects `phone_otp_attempts` before any branch — onboarding phone-OTP 42703s if the deployed version is stale. Smoke a `send_otp` + a `lookup` and confirm no 42703.
7. **[FOUNDER/CLAUDE] HARD-GATE — Push `feat/storefront-platform` and merge → the default branch** (fast-forward). Cloudflare rebuilds prod from the default branch. The live frontend has none of guest checkout / template picker / bespoke card path / sold-out hard-block until this lands.
8. **[FOUNDER] HARD-GATE — Confirm prod env vars in the Cloudflare Pages build**: `VITE_STRIPE_PUBLISHABLE_KEY=pk_live_...` (THE most likely silent failure — if missing, every card payment silently degrades to "pay at venue"); `VITE_SUPABASE_*`. Leave `VITE_SQUARE_*` UNSET (keeps Square dormant).
9. **[FOUNDER] HARD-GATE — Set edge-function secrets for the steps you'll use**: `STRIPE_SECRET_KEY` (sk_live) + `STRIPE_WEBHOOK_SECRET` + register the `stripe-webhook` endpoint for `account.updated` and `payment_intent.*`; `WOAHH_SMS_NUMBER` + ClickSend creds (owner phone OTP / onboarding); `RESEND_API_KEY` + `APP_URL` (order emails); `ANTHROPIC_API_KEY` (only if using AI menu import — manual menu is the fallback).
10. **[CLAUDE] HARD-GATE — Smoke prod after rebuild**: apex `woahh.app` marketing + `/eat` + `/business/auth` visually unchanged; then place a real Stripe test order on `test-bistro` to confirm the capture path against the redeployed functions.

### C. Onboard the first merchant (per `MERCHANT_ONBOARDING_RUNBOOK.md`)
11. **[FOUNDER/CLAUDE] HARD-GATE — Mint a founding code** at `/business/dashboard/admin/codes` (URL-only, admin-gated to `pawitsingh23@gmail.com`) and hand it to the merchant out-of-band.
12. **[FOUNDER (merchant)] — Sign up** at `/business/auth` with the founding code (gating is fail-closed: code redeemed before `signUp`). Org auto-creates (`free_trial`, 60-day trial, derived `subdomain_slug`).
13. **[FOUNDER (merchant)] — Complete the onboarding checklist**: owner phone OTP (needs step 6 + step 9 SMS secrets), ABN (checksum-validated), business address. Business-type auto-ticks from signup (checklist copy is cosmetically stale; non-blocking).
14. **[FOUNDER (merchant)] — Build the menu** (manual add-item, or AI import if `ANTHROPIC_API_KEY` set). Dish photos are URL-paste only (no upload widget) — friction, not a blocker.
15. **[FOUNDER (merchant)] — Set branding** (logo upload, HSL colors, font pair). Applies with or without a template.
16. **[FOUNDER (merchant)] — Pick + publish a storefront template** (`/business/dashboard/storefront`, solo-tier-gated). Optional — unpublished merchants render the default storefront with zero action.
17. **[FOUNDER (merchant)] — Connect Stripe** (Operations → Connect card → `stripe-connect-onboard`, Express AU, `application_fee:0`). Must finish hosted onboarding so `charges_enabled` flips true (synced by the `account.updated` webhook). Until then, card capture 400s and degrades to pay-at-venue.
18. **[FOUNDER (merchant)] — Place real test order(s)** with `online_card_enabled` still OFF (pay-at-venue) and confirm cent-exact totals + order → KDS.
19. **[FOUNDER/CLAUDE] HARD-GATE for real cards — Flip `settings.payments.online_card_enabled = true`** (SQL-only, no UI; default false) for this merchant ONLY after step 18 confirms totals match. This is the boundary between pilot pay-at-venue and live card capture.
20. **[FOUNDER (merchant)] — `name.woahh.app` subdomain storefront: NOT day-1.** Requires human wildcard `*.woahh.app` CNAME + Pages custom domain + TLS. The merchant launches on the apex `/eat/:slug` + storefront path; add the subdomain later. The code ships dormant and safe.
21. **[FOUNDER (merchant)] — Final go-live test**: a real end-to-end order (card capture on, if step 19 done) → owner-confirm → capture → KDS → customer tracker.

---

## 4. PILOT-ACCEPTABLE RISKS (explicitly accepted)

These are KNOWN and ACCEPTED for a single controlled founding-merchant pilot. They become real concerns at scale / public launch, not at one-merchant pilot volume.

- **Captcha OFF on anon signup/guest checkout.** The `captchaToken` plumbing exists but no UI generates one, and Supabase bot-protection was toggled off for auto-testing. Supabase's built-in anon rate-limiting covers one-merchant volume. Wire Turnstile/hCaptcha + re-enable before scale.
- **Square is sandbox-only and entirely out of day-1 scope.** As long as the merchant stays on `payment_provider='stripe'` (the default), the whole Square go-live chain (AU account/bank, OAuth round-trip, sandbox-SDK teardown, app-fee/AFSL, webhook subscribe) is not applicable. The write-guard trigger (`20260609050000`) prevents an accidental self-flip to Square.
- **H-2 deferred — payment failure does NOT release committed stock** (inventory-DoS). Stock is decremented at order-create; a `payment_intent.payment_failed` only marks the order failed, no restock. With `online_card_enabled` OFF there is no decline-at-capture path at all. Low risk for one pilot merchant; fix before public/scaled launch. Interim mitigation: anon order rate-limit.
- **C1 v2 deferred — only the item subtotal − promo floor is server-validated.** Delivery/service fees and pay-at-venue/dine-in totals remain client-trusted. A tampered client can only drop its OWN fees, never underpay for food. Documented as fine-for-pilot.
- **No automated refund→order reconciliation / money-path alerting yet.** For one pilot merchant the Stripe dashboard is eyeball-able. Add observability before scale.
- **Anon-user cleanup cron not yet wired** — every guest checkout mints a permanent `auth.users` row. Unbounded but harmless at one-merchant volume.
- **8 stale tsc errors** — runtime-safe; `vite build` is green. Regenerating `types.ts` clears them (nice-to-have).
- **Cosmetic onboarding copy gaps** — checklist "Set business type … in account settings" (no such UI; auto-ticks); a Notify tooltip says "Upgrade to Growth" but the gate is marketplace. Non-blocking.

---

## 5. DO-NOT-SHIP / MUST-CLEAN ITEMS

- **Do NOT commit `.env`** in the push — it is the only modified working-tree file and holds local secrets. Confirm it stays out of the merge.
- **Clean / unpublish `test-bistro` before launch** so it does not appear in the `/eat` marketplace alongside the real merchant. It is currently published on the `kerb` bespoke template and carries test artifacts (test order `b7cd95ec`, `+c1verify` customer, a few anon auth users). It is the TEST org, not the merchant's org, so it does not ship into the merchant's storefront — but it should not be publicly listed.
- **Do NOT flip `online_card_enabled` to true** for the merchant until a real test order (step 18) confirms cent-exact totals. Default-false is correct; the flip is the live-money boundary.
- **Do NOT leave the merchant on Square** — keep `payment_provider='stripe'`. Square is sandbox-only; flipping it would route real funds through an unverified sandbox path.
- **Do NOT add wildcard `*.woahh.app` DNS/TLS as a day-1 dependency** — it is not needed for merchant #1 and the subdomain path ships safely dormant without it.

---

### Bottom line
The correctness/money work for one founding Stripe merchant is genuinely in good shape (C1 floor live-verified, BLK-1 claim-before-capture live, guest checkout live-verified, drift smoke 8-clean). What stands between "today" and "merchant live" is delivery plumbing: push + merge the branch, redeploy `order-respond` / `stripe-webhook` / `owner-verify` / `account-recover` in lockstep, set the Cloudflare + edge secrets (especially `VITE_STRIPE_PUBLISHABLE_KEY=pk_live`), and confirm the drift hotfix. Run the merchant card-capture-OFF (pay-at-venue) first, confirm a real order end-to-end, then flip `online_card_enabled`.
