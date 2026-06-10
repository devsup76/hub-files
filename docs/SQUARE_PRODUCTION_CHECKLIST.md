# Square — Sandbox → Production Go-Live Checklist & Readiness Report

> **Status as of 2026-06-10:** Square online payments are **SANDBOX-VERIFIED-LIVE** (full
> authorize → capture → refund lifecycle + edge cases proven end-to-end on the
> `sandbox-direct` shortcut). This document is the dependency-ordered checklist to go from
> that proven state to a **real AU merchant taking real customer money**, plus the residual
> debt to clear before scale.
>
> Tags used below:
> - **FOUNDER** — human action by the founder (accounts, secrets, dashboard config, decisions)
> - **CLAUDE** — code/migration work
> - **EXTERNAL** — Square / compliance / regulator action with outside lead time
> - **HARD-GATE** — must be true before taking real money (or before the named milestone)
> - **nice-to-have** — improves robustness/scale but does not block first real money
>
> Source of truth: this checklist is synthesised from four adversarial assessments
> (webhooks, OAuth, compliance/money-model, residuals/observability/schema-drift). Key code
> citations are inline so each claim is verifiable.

---

## (1) VERIFIED LIVE — what is proven

The sandbox E2E exercised the **payment state machine** on the `sandbox-direct` connection
(test-bistro, founding-equivalent, fee-0, single merchant). The following are proven correct:

| Lifecycle stage | Proven behaviour | Source (synchronous, self-reported) |
|---|---|---|
| Authorize | `CreatePayment(autocomplete:false)` → `payment_status='authorized'` written inline | `square-payment/index.ts:388-397` |
| Capture (owner-confirm) | `CompletePayment` → `payment_status='paid'` written inline | `order-respond/index.ts:254-258` |
| Decline / void | `CancelPayment` → `payment_status='canceled'` written inline | `order-respond/index.ts:273-282` |
| Refund (synchronous) | `POST /v2/refunds` → `record_order_refund` → `refunded`/`partially_refunded` | `refund-order/index.ts:363-371`; migration `20260610050000:205-269` |
| Edge cases | Tampered/under-quoted totals rejected (C1 floor); required-ingredient hard-block; claim-before-capture race fix (BLK-1); idempotency keys | `20260608020000`, audit BLK-1/3/4 |

**Why it worked with no webhook subscribed:** unlike a webhook-driven Stripe integration,
this stack writes `payment_status` **synchronously from the API call result**, not from the
webhook. `square-webhook` is purely a reconciliation/back-out layer (see §3). That is the
architectural reason the happy path is self-contained — and also why async-refund and
out-of-band reconciliation are the gaps that appear only at scale.

**Stripe is untouched.** The Square path is an additive second provider behind
`organizations.payment_provider ∈ {stripe, square}` (default `stripe`). The Stripe code path
is byte-for-byte unchanged; commission is hardcoded `0` identically on both
(`square-payment/index.ts:316` mirrors `stripe-payment-intent/index.ts:121`).

> **VERIFIED ≠ PRODUCTION-READY.** The proven path is the *one* founding-equivalent, fee-0,
> single-merchant, sandbox-direct happy path. Everything that separates it from a real AU
> merchant at scale is the checklist below.

---

## (2) PRODUCTION GO-LIVE CHECKLIST (dependency order)

### Stage 0 — TOP STRUCTURAL DEBT (do first; blocks confidence in everything else)

- [ ] **SCHEMA-DRIFT RECONCILIATION** — **CLAUDE + FOUNDER · HARD-GATE**
  **This is the single biggest structural risk and the root of an incident that already
  broke 3 customer-facing RPCs in production** (`get_public_storefront`, `get_member_org`,
  `get_order_by_id` threw `42703 undefined column` because the repo migration history is
  *ahead of* live: `orders.receipt_token` from `20260601093000` and
  `organizations.phone_otp_attempts` from `20260602101000` were never applied to live, yet
  later masking RPCs referenced them). Hotfixed by `20260610070000` / `docs/FIX_DRIFTED_RPCS.sql`,
  but repo and live are now **forked on table shape AND RPC behaviour**, and the blast radius
  is **unbounded** because `CREATE OR REPLACE FUNCTION` defers column-resolution to *runtime*
  (a drifted RPC applies cleanly, then fails the first time a customer hits it). There is no
  `db diff`, no recorded live snapshot, no CI gate anywhere in the repo.
  Reconciliation (the fix):
  1. `pg_dump --schema-only` / `supabase db dump` of live `pmnyhbhtkcfoozkinieo`; diff vs the
     schema a clean repo apply would produce → authoritative drift list.
  2. Per drift decide **backfill-live vs re-baseline-repo** (product decision for
     `receipt_token`: gain the separate-bearer-token security property, or accept
     "order UUID = tracker token" and amend/squash `20260601093000`/`20260602101000`).
  3. Single squashed baseline migration = live-as-of-now; CI `db diff` fails the build on
     un-applied drift; lint rejecting RPC bodies that reference non-baseline columns.
  4. **Post-apply RPC smoke test that *invokes* every re-created public RPC** (the
     verification that caught the drift must become permanent, not ad hoc).
  > Until this is done, every Square migration the founder runs carries the same silent
  > runtime-failure risk. Tracked in `docs/SCHEMA_DRIFT_RECONCILIATION.md` (the overnight run log was deleted 2026-06-10; in git history).

### Stage 1 — Square production account & app (external lead time)

- [ ] **AU production Square developer account + AU bank account (AUD)** — **FOUNDER + EXTERNAL · HARD-GATE**
  Can't take real AU cards without a real prod Square app. App-fee account currency must
  match the AU seller (AUD). ~1 wk, mostly waiting. Square reviews/activates apps that take
  payments. (`SQUARE_POS_INTEGRATION.md:228`.)
- [ ] **Create the Production Square application** (separate from sandbox); obtain prod
  `client_id` (`sq0idp-…`) + secret — **FOUNDER · HARD-GATE**
- [ ] **Register the OAuth Redirect URL** = exact `SQUARE_OAUTH_REDIRECT` =
  `https://pmnyhbhtkcfoozkinieo.supabase.co/functions/v1/square-oauth-connect` (must byte-match) — **FOUNDER · HARD-GATE**
- [ ] **Confirm the 5 OAuth scopes** the app requests match `_shared/square.ts:27-33`
  (`PAYMENTS_WRITE/READ`, `ORDERS_WRITE`, `MERCHANT_PROFILE_READ`, `PAYMENTS_WRITE_IN_PERSON`).
  Note `PAYMENTS_WRITE_IN_PERSON` is reserved for the later Terminal phase — confirm it
  doesn't add consent friction / AU review for an online-only merchant. — **FOUNDER · nice-to-have**

### Stage 2 — Backend secrets & base-URL flip (config; mechanical)

- [ ] **`SQUARE_API_BASE=https://connect.squareup.com`** — **FOUNDER · HARD-GATE**
  Single var that switches OAuth endpoints + all REST calls. Default is sandbox
  (`_shared/square.ts:18`, `square-payment/index.ts:40-41`, `order-respond`, `refund-order`).
  Set prod `SQUARE_VERSION` too.
- [ ] **`SQUARE_OAUTH_CLIENT_ID` / `SQUARE_OAUTH_CLIENT_SECRET` / `SQUARE_OAUTH_REDIRECT`** (prod) — **FOUNDER · HARD-GATE**
  Read at `square-oauth-connect/index.ts:124-129` + `_shared/square.ts:173-174`.
- [ ] **REMOVE/UNSET `SQUARE_ACCESS_TOKEN` in prod + delete test-bistro's `sandbox-direct` row** — **FOUNDER (+ CLAUDE for row delete) · HARD-GATE**
  `_shared/square.ts:163-166`: any connection with `merchant_id='sandbox-direct'` or a token
  starting `<` **bypasses per-org OAuth and uses the global `SQUARE_ACCESS_TOKEN`**. This is
  the live form of **BLK-2** — a residual sandbox-direct row + a set `SQUARE_ACCESS_TOKEN`
  would route real charges to that shared account. Neutralise before any real merchant.
- [ ] **Token-refresh cron prerequisites** — **FOUNDER + CLAUDE · HARD-GATE**
  Deploy `square-token-refresh`; run migration `20260610020000_square_token_refresh_cron.sql`
  (daily `0 3 * * *`, refreshes connections expiring within 7 days). Confirm
  `vault.decrypted_secrets` rows `project_url` + `service_role_key` exist — without them the
  cron is a **silent no-op** and tokens silently expire after ~30 days
  (`cron migration:35-37`).

### Stage 3 — Webhook subscription & secrets (closes reconciliation gaps #1/#2)

> Handler is already deployed and **fail-closed** (returns `503` and processes nothing if
> either secret is unset — `square-webhook/index.ts:84-100`). Today, unsubscribed, those vars
> are simply absent. **Subscribing the webhook + setting the two secrets is a mandatory
> pre-real-money config step**, not optional: without it async refunds freeze at `pending`
> forever, rejected refunds are never backed out (silent GMV understatement + a customer told
> money is coming that may not be), and dashboard-issued refunds/voids never reconcile.

- [ ] **Square Dashboard → Webhooks → Add subscription** (prod app) — **FOUNDER · HARD-GATE**
  Notification URL = `https://pmnyhbhtkcfoozkinieo.supabase.co/functions/v1/square-webhook`
  (verify_jwt **false** — Square can't send a Supabase JWT; `square-webhook/index.ts:7-8`).
  Subscribe to: `payment.created`, `payment.updated`, `refund.created`, `refund.updated`
  (matches branches at `:125,139`). Add `oauth.authorization.revoked` once that branch is
  built (§3 residuals); add `dispute.*` once a dispute pipeline exists.
- [ ] **`SQUARE_WEBHOOK_SIGNATURE_KEY`** = the signature key Square shows for the subscription — **FOUNDER · HARD-GATE**
  Used for the HMAC at `:60-78`.
- [ ] **`SQUARE_WEBHOOK_URL`** = the **exact** notification URL string — **FOUNDER · HARD-GATE**
  Mandatory: Square's HMAC is computed over `notificationUrl + rawBody` (`:74`); behind the
  Supabase/Cloudflare proxy `req.url` is rewritten, so the code **deliberately refuses to
  fall back to `req.url`** (`:90-100`). A mismatch → HMAC fails silently → every status
  update dropped → Square disables the subscription. (This is residual **H-12**.)
- [ ] **Verify** with Square "Send test event" + a real sandbox async refund: confirm a
  `pending` row in `payment_refunds` promotes to `succeeded` via `set_refund_status`. — **CLAUDE/FOUNDER · HARD-GATE**

### Stage 4 — Frontend production cutover (Cloudflare build) — **contains 1 non-env code change**

- [ ] **`CardPayment.tsx:35` SDK src → production** — **CLAUDE · HARD-GATE**
  Currently HARDCODED to `https://sandbox.web.squarecdn.com/v1/square.js` (residual **L-11**).
  A prod build would load the **sandbox SDK** = guaranteed go-live break (a prod app id
  tokenised against the sandbox SDK fails). Change to `https://web.squarecdn.com/v1/square.js`
  (ideally env-driven). **This is the one cutover item that is NOT an env flip and will be
  missed if you only flip env vars** — frontend and backend silently disagree otherwise.
- [ ] **`VITE_SQUARE_APPLICATION_ID`** = prod app id — **FOUNDER · HARD-GATE** (`CardPayment.tsx:32`)
- [ ] **`VITE_SQUARE_LOCATION_ID`** optional (server `location_only` resolver covers it) — **FOUNDER · nice-to-have** (`CardPayment.tsx:277`)

### Stage 5 — Provider onboarding UX (real merchant can't reach Square today)

- [ ] **Provider-picker / toggle in Operations** — **CLAUDE · HARD-GATE (before 2nd merchant; chicken-and-egg today)**
  Operations renders the Square card **only when `payment_provider === 'square'`**, but the
  *only* writer of that value is the OAuth callback itself (`square-oauth-connect:224`). A
  real merchant starts on the `'stripe'` default (`20260609020000:27`) and has **no UI to
  switch** — test-bistro was flipped by manual SQL. Add a toggle that sets
  `payment_provider` before connecting (or show the Square card to stripe-default merchants).
- [ ] **Run the REAL OAuth round-trip at least once** (sandbox-seller account first, then
  prod) — **FOUNDER · HARD-GATE**
  `authorize_url → Square consent → ObtainToken callback → store tokens` has **never run** —
  everything to date used the OAuth-bypassing `sandbox-direct` shortcut. This is the single
  most important untested seam. (Multi-location note: one OAuth covers all of a merchant's
  locations; owner picks the default online-order location via `set_square_default_location`.
  **Only one default location routes all online orders** — a true 5-location merchant likely
  needs 5 orgs today, since per-storefront→per-location routing is plumbed but not wired.)

### Stage 6 — Commission / AFSL posture (decision + gate)

- [ ] **Decision: keep `app_fee_money = 0` (founding pass-through) OR turn on the locked model** — **FOUNDER · HARD-GATE (for the decision)**
  Today `appFeeAmount = 0` hardcoded (`square-payment:316`); `app_fee_money` is **omitted**
  when 0 (Square rejects `amount:0`). This is correct for **founding merchants** (0% commission,
  still pay subscriptions). The locked 3%+1%→2%/2% charity model **does NOT flow through
  Square yet** (`REFUND_POLICY.md:211` — no per-order charity booking today).
- [ ] **AFSL / merchant-of-record posture** — **EXTERNAL · gate depends on fee**
  Square AU Pty Ltd holds **AFSL 513929** and is merchant-of-record; the seller is paid into
  *their own* Square balance and Woahh never custodies GMV — this **sidesteps** the Stripe
  Connect Custom AFSL exposure. **While `app_fee = 0` (founding phase): NO hard AFSL gate**
  (pure pass-through). **The moment you set a non-zero `app_fee_money` it becomes a HARD
  GATE**, requiring:
  - AU Square dev account + AU bank (AUD) — already in Stage 1;
  - written confirmation from Square AU that AFSL 513929 covers the **app-fee** flow
    specifically ("applies to *some* products, not all" — `SQUARE_POS_INTEGRATION.md:158`);
  - PAAF (Payments API Application Fee) **PDS** + AU **FSG** review before launch;
  - **add the `PAYMENTS_WRITE_ADDITIONAL_RECIPIENTS` OAuth scope** (currently **absent** from
    `_shared/square.ts:27-33` — the app physically cannot set `app_fee_money` without it);
  - un-hardcode `appFeeAmount` (founding→0, else locked %);
  - add the contra-`donation_ledger` entry on refund (`REFUND_POLICY.md:218-224`), or refunds
    over-state charity.
- [ ] **Restrict `square_payment_ready` to founding/fee-0 merchants** until the
  OAuth + app-fee + AFSL chain is complete — the audit's explicit go-live gate
  (`AUDIT_FINDINGS:257`). — **FOUNDER + CLAUDE · HARD-GATE (before paying Square merchant)**
- [ ] **Verify `20260609050000_guard_org_payment_columns.sql` (H-6) is actually applied to live** — **FOUNDER · HARD-GATE**
  Blocks an owner self-setting `payment_provider`/`square_payment_ready`/`square_merchant_id`
  over REST. Marked done, but **given the drift incident, do not assume**. If absent, an owner
  can self-activate Square and (with any shared-token leftover) misroute funds.

### Stage 7 — Deploy

- [ ] **Deploy the 7 Square edge functions** with prod env secrets + rebuild Cloudflare
  frontend with prod `VITE_SQUARE_*` + the SDK-src code fix — **FOUNDER + CLAUDE · HARD-GATE**

---

## (3) DEFERRED / RESIDUAL ITEMS (ranked for scale)

> None of these block the *first* founding-equivalent real charge on the happy path, but they
> rank in order of how soon they bite as real volume / a second merchant arrives.

| # | Item | Tag | Severity | Why it matters | Refs |
|---|---|---|---|---|---|
| 1 | **Disputes / chargebacks — NOT HANDLED AT ALL** | CLAUDE | **HARD-GATE (scale)** | No handler anywhere (Square *or* Stripe), no event subscribed, no `mapSquareStatus` mapping, no merchant alert, no commission claw-back. A **code** blocker, not config. At AU scale chargebacks are a certainty; platform has zero visibility. | grep finds nothing; `SQUARE_POS_INTEGRATION.md:125` |
| 2 | **INT-B1 — refund→paid clobber** | CLAUDE | **HARD-GATE (scale)** | Replayed Square `payment.updated` can re-flip `refunded`→`paid` and re-inflate GMV; settlement keys on `payment_status`. Needs a `webhook_events` dedup table. | audit 403-406; `square-webhook` ~125-178 |
| 3 | **H-2 — payment failure does NOT release committed stock** | CLAUDE | **HARD-GATE (public launch)** | `create_order_with_inventory` decrements stock at order-create; `stripe-webhook:48-49` on `payment_intent.payment_failed` only sets `failed` — no restock; no Square `FAILED`/`CANCELED` release. With guest checkout live, a bot mints anon sessions → free inventory-DoS; legit declines strand last-unit stock. Fix: decrement-at-capture OR idempotent release-on-failure + short-TTL cron + anon rate-limit. | audit 103-109; `stripe-webhook:48-49` |
| 4 | **C1 v2 — full server-authoritative total** | CLAUDE | **HARD-GATE (public launch)** | C1 (`20260608020000`) validates only `item subtotal − promo` as a **floor**; delivery/service fees + **pay-at-venue/dine-in totals are client-trusted**. Bespoke checkout invents a $4.99 delivery + 1% fee client-side and offers disabled fulfillment methods. Make the entire total server-derived from merchant settings. | `20260608020000:22-44`; H-4 119-126; M-3 210-215 |
| 5 | **Observability / alerting on the money path** | CLAUDE | **HARD-GATE (scale)** | Near-zero today: `stripe-payment-intent` 0 logs/0 errors; `square-payment` & `refund-order` 0 `console.error`; **no sentry/datadog/pagerduty anywhere**. Capture-failure-but-order-confirms (M-7) is logged to nothing. Need: error alerting on the 6 money fns; a `payment_events`/`order_status_history` audit table (dispute evidence); a reconcile cron re-attempting `authorized` captures before holds expire; health checks on the 2 crons. | IMP-5/6 372-373; M-7 238-243 |
| 6 | **Captcha widget — wire + enable** | CLAUDE + FOUNDER | nice-to-have (amplifier) | `guestCheckout.ts:33-43` accepts an optional `captchaToken` but **nothing in the UI generates one** — no Turnstile/hCaptcha widget exists. Guest checkout is live with anon sign-ins. Unbounded anon minting amplifies H-2 + CRM-row spam. Add the widget + enable Supabase Auth bot-protection + thread the token. | `guestCheckout.ts:33-43`; CLAUDE.md "+ Turnstile/captcha before scale" |
| 7 | **Anon-user cleanup cron — absent** | CLAUDE | nice-to-have | No cron reaps stale anonymous `auth.users`; every guest checkout mints a permanent row. `20260609010000` only *guards triggers*, doesn't reap. Unbounded `auth.users` growth. Need a periodic delete of old anon users (preserve FK'd order/consent rows). | no cron found; `20260609010000` |
| 8 | **`oauth.authorization.revoked` not handled** | CLAUDE | nice-to-have (reliability) | Only a `// Future:` comment (`square-webhook/index.ts:145`). A merchant disconnecting Woahh from their Square dashboard leaves a dead token; next checkout fails at `CreatePayment` with no merchant warning. Subscribe the event, clear the connection, flip `square_payment_ready=false`, surface "reconnect Square". | `square-webhook:145`; `SQUARE_POS_INTEGRATION.md:41` |
| 9 | **Token-refresh failure is invisible to the merchant** | CLAUDE | nice-to-have (reliability) | Both refresh paths swallow failures and return the stale token (`square.ts:175,183`; `square-token-refresh:67-69`) — good for transient blips, bad for permanent revocation. No failure counter, no alert, no `square_payment_ready` flip on sustained failure; after ~30 days the merchant is silently dead. | `square.ts:183`; `SQUARE_POS_INTEGRATION.md:246` |
| 10 | **`expires_at` 25-day default fudge** | CLAUDE | nice-to-have (low) | OAuth callback defaults to 25 days when Square omits `expires_at` (`square-oauth-connect:199`); normally dead code (Square always returns ~30d), but a 25-day default vs a 7-day refresh window is tight if it ever fires. | `square-oauth-connect:199` |
| 11 | **M-9 — Square `app_fee` hardcoded 0 for all** | CLAUDE | HARD-GATE (2nd paying merchant) | Same as Stage 6; restated here as a residual. Any non-founding Square merchant routes 0% to Woahh+charity. | `square-payment:316` |

---

## (4) DO THIS BEFORE THE FIRST REAL MERCHANT — short list

> The minimal set to responsibly take **one** real founding-equivalent (fee-0) merchant's
> money on the happy path. Ordered.

1. **Reconcile the schema drift** (Stage 0) — diff live↔repo, decide backfill-vs-rebaseline,
   add the post-apply RPC smoke test. *The root cause that already broke prod once; silent.*
2. **AU prod Square app + AU bank** (Stage 1) — the only item with external lead time.
3. **Flip backend to prod** (Stage 2): `SQUARE_API_BASE=connect.squareup.com`, prod OAuth
   client id/secret/redirect, prod `SQUARE_VERSION`.
4. **Tear down the sandbox-direct seam** (Stage 2): unset `SQUARE_ACCESS_TOKEN`, delete the
   `sandbox-direct` connection row. *Live BLK-2.*
5. **Subscribe the Square webhook + set `SQUARE_WEBHOOK_SIGNATURE_KEY` + `SQUARE_WEBHOOK_URL`**
   (Stage 3) — closes async-refund / dashboard-refund reconciliation; verify async-refund
   promotes `pending → succeeded`.
6. **Fix the hardcoded sandbox SDK** (`CardPayment.tsx:35`) + set prod
   `VITE_SQUARE_APPLICATION_ID` (Stage 4). *The non-env code change that gets missed.*
7. **Run the real OAuth round-trip once** (Stage 5) — the most important untested seam.
8. **Verify `square_payment_ready` is restricted to founding/fee-0** + **H-6 guard is on live**
   (Stage 6). Keep `app_fee_money = 0` until OAuth+app-fee+AFSL exist.
9. **Token-refresh cron deployed + vault secrets present** (Stage 2) — else silent token
   expiry in ~30 days.

**Cannot wait until scale but cheap, batch into the above:** H-12 (webhook URL fail-closed —
covered by Stage 3) and L-11 (sandbox SDK — covered by Stage 4).

**Build before a *public* (non-founding-equivalent) launch, not just the first merchant:**
the dispute/chargeback handler (#1), INT-B1 dedup (#2), H-2 stock release (#3), C1 v2 (#4),
and payment-path observability/alerting (#5).
