---
name: woahh-payments-stripe
description: "Woahh Stripe payments — online card on Connect Express (founding-merchant interim); built + reviewed, NOT deployed; Custom deferred to AFSL"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5cc244e8-c455-42e8-b8b8-d97c5fa82054
---

Woahh online payments. **Model (interim, locked with owner):** founding merchant takes ONLINE card
through Woahh on **Stripe Connect Express, `application_fee_amount: 0`** (pass-through; Stripe pays the
merchant directly, Woahh holds NO funds → **no AFSL/written agreement needed**). IN-PERSON = the
merchant's OWN external EFTPOS (recorded in Woahh, not charged via us — no Stripe Terminal build). The
normal "we process the payment / hold funds + charity split via application_fee" is **Connect Custom**,
which legally needs **Stripe's written AFSL confirmation** before the first live charge → DEFERRED.
Charity for founding merchants comes from subscription/voluntary, not card commission, until Custom.

**Progress finding:** CLAUDE.md said Stripe "not started" — STALE. Connect Express onboarding already
worked (`stripe-connect-onboard` → Express AU acct → `organizations.stripe_account_id`; Operations
StripeConnectCard). The gap was actually CHARGING (no card UI, payment-intent never called, no webhook).

**BUILT 2026-06-02 — branch `feat/online-payments-express`, worktree `/workspaces/GrowthHub/repo-pay`,
commit `4b89ff0` (off origin/main `a88a089`). Build GREEN. NOT pushed / merged / deployed.** Plan file:
`/home/vscode/.claude/plans/gentle-watching-llama.md`.
- migration `20260602130000_online_payments_express.sql`: orders.payment_status(+CHECK
  unpaid|authorized|paid|pay_in_person|refunded|failed|canceled) / stripe_payment_intent_id /
  payment_method; organizations.charges_enabled / payouts_enabled.
- `stripe-payment-intent` (rewritten): anon guest checkout (verify_jwt=false, order_id = capability,
  amount recomputed from order row), charges_enabled gate, manual capture when order
  status=awaiting_confirmation else automatic, idempotencyKey pi-<order_id> + resume-existing-PI, stores PI on order.
- `order-respond`: capture on confirm / cancel on decline — decided from the **LIVE PI status** (retrieve),
  not the cached column (review fix — else a confirm beating the webhook leaves the hold uncaptured).
- `stripe-webhook` (NEW): Stripe-signature-verified (constructEventAsync, fail-closed); PI events →
  payment_status (with no-downgrade guard `.neq('payment_status','paid')`); account.updated → charges_enabled/payouts_enabled.
- `stripe-connect-onboard`: also refreshes charges_enabled from Stripe on each connect/finish-setup
  (so readiness doesn't depend solely on the Connect webhook).
- config.toml: verify_jwt=false for stripe-webhook + stripe-payment-intent.
- Frontend: `src/components/checkout/CardPayment.tsx` (Payment Element dialog, VITE_STRIPE_PUBLISHABLE_KEY,
  not-payment-ready→pay-at-venue fallback); RestaurantStorefront wired (delivery/pickup → card dialog after
  order creation, FORCED through confirmation so unpaid never hits the kitchen; checkout closed+cart cleared
  first to prevent duplicate-on-abandon; dine-in pays at venue; demo/owner-preview never charge); Operations
  StripeConnectCard 3 states (connect / finish-setup / payment-ready). deps @stripe/stripe-js + react-stripe-js.

Adversarial review `wf_d4f56e00-c4c` (3 agents): money model sound; fixed 2 HIGH (stale-status capture;
duplicate order/PI on abandoned dialog) + unpaid-in-kitchen (force awaiting_confirmation) + webhook-config
(onboard refresh) + demo-mode network call. **DEFERRED (noted, non-blocking for the restaurant founding
merchant):** RetailStorefront + Shop card wiring; Orders "Unpaid" badge + in-person "mark collected"
(payment_status visibility); `pay_in_person` value defined but never written; loyalty awarded at order
creation (pre-payment). Refund/dispute = documented deferral.

**TO GO LIVE (owner/ops, on `pmnyhbhtkcfoozkinieo`):** set `STRIPE_SECRET_KEY` (sk_live) +
`STRIPE_WEBHOOK_SECRET`; Stripe dashboard webhook → `/functions/v1/stripe-webhook` with events
payment_intent.succeeded|amount_capturable_updated|payment_failed|canceled + account.updated — **MUST
include connected-account (Connect) events or charges_enabled never flips → no merchant can charge**;
merchant finishes Express onboarding (ABN/bank/KYC); test-mode dry-run → small live charge + refund.
Then push branch + deploy 4 edge fns + frontend rebuild (merge→main). See [[woahh-sms-architecture]] for the
deploy pattern (npx supabase functions deploy). Rotate any keys pasted in chat.

**END-TO-END TEST PASSED (TEST MODE) 2026-06-02.** Deployed 4 fns + set Stripe TEST secrets on
`pmnyhbhtkcfoozkinieo`; created Stripe test webhook `we_1Tdqit…`. Drove the Cloudflare preview (branch alias
`feat-online-payments-express.woahh-app.pages.dev`) via Playwright: seeded customer
`pawitsingh23+stripetest@gmail.com`/`WoahhTest2026!` → /shop/test-bistro → pickup → cart → checkout → **Stripe
Payment Element** → 4242… → order `eb00790a` (awaiting_confirmation), PI `pi_3TdruM…` $7.00 manual-capture
**requires_capture** → owner-confirm (order-respond) → **PI succeeded, amount_received 700**. WHOLE MONEY PATH PROVEN.
Two real blockers found+fixed en route (needed in ALL envs): (1) Cloudflare env var must be in **Preview** scope
(user fixed); (2) **`public/_headers` CSP was missing Stripe** → Payment Element blocked → added
js.stripe.com/hooks.stripe.com/api.stripe.com, committed **`b12bd60`** on the branch (fixes prod too).
Test artifacts: created charges_enabled test Custom acct `acct_1TdrUn1L8arUigVy` via Stripe API + PATCHed Test
Bistro org (stripe_account_id + charges_enabled=true) to skip hosted onboarding; seeded the customer via Auth admin.
**GO-LIVE DELTAS:** STRIPE_SECRET_KEY=sk_live + a LIVE webhook → STRIPE_WEBHOOK_SECRET; Cloudflare **Production**
VITE_STRIPE_PUBLISHABLE_KEY=pk_live; **merge branch→main** (ships frontend + CSP fix to prod); REAL merchant does
live Express KYC; $1 live charge+refund. (Test Bistro's stripe_account_id is a TEST acct — clear before any live
use of that org.) Branch state: `b12bd60` on `feat/online-payments-express`, pushed, NOT merged to main.
**ROTATE:** sbp_f400… token + Stripe TEST keys (pasted in chat).
