# Square POS Integration — Decision-Ready Plan

> Status: **research-complete, not started.** Last updated: 2026-06-09.
> Scope: integrating **Square** (online + in-person) into Woahh as a payment connector, alongside the existing Stripe Connect Express flow.
> All API names below are verified against official Square developer docs (cited inline). No invented endpoints.

---

## TL;DR Recommendation

**Can we do it? — Yes.** Square has a production-grade, multi-tenant platform model that maps almost 1:1 onto Woahh's existing Stripe Connect Express design:

- **Online:** Web Payments SDK (`card.tokenize()`) → `CreatePayment(autocomplete:false)` → `CompletePayment`/`CancelPayment` — the direct analog of our Stripe PaymentIntent manual-capture-on-confirm flow.
- **In-person:** Terminal API (`CreateTerminalCheckout`) drives the merchant's **own** Square Terminal over the cloud — **no native app required**, fits our web/cloud-POS today.
- **Commission:** `app_fee_money` on the payment is the direct analog of Stripe's `application_fee_amount`. Founding-merchant "0 fee" = `app_fee_money: 0`.
- **Australia:** first-class supported region (AUD, eftpos). ✅

**Add-alongside-Stripe, NOT replace.** Add Square as a **second, merchant-selectable connector** (`organizations.payment_provider ∈ {stripe, square}`); keep Stripe Connect Express as the default. Square's value is for AU merchants who **already own Square hardware + a Square account** — they keep their gear and bank settlement and just OAuth-authorize Woahh. The order/KDS/storefront/marketplace layer is payment-agnostic and fully reused; only the payments adapter differs.

**Is the platform-fee/commission model viable on Square? — Yes, and arguably with a *cleaner* regulatory posture than our Stripe path.** With `app_fee_money`, **Square is merchant-of-record**, the seller is paid directly into *their* Square balance, and only our cut lands in *our* Square account. That sidesteps the "platform custodies merchant GMV" exposure that drives the Stripe-Connect-Custom AFSL concern. ([app fees](https://developer.squareup.com/docs/payments-api/take-payments-and-collect-fees), [Square AU MoR / AFSL 513929](https://squareup.com/au/en/legal/general/au-fsg))

**Three load-bearing caveats:**
1. Woahh needs an **AU Square developer account + AU bank account** to collect `app_fee_money` from AU sellers (currency must match). ([app fees — additional considerations](https://developer.squareup.com/docs/payments-api/collect-fees/additional-considerations))
2. Square uses a **Standard-style OAuth-into-the-seller's-own-account** model — **not** managed Express sub-accounts. New operational obligation: a **scheduled token-refresh job** (access tokens expire at 30 days). ([OAuth tokens](https://developer.squareup.com/docs/oauth-api/receive-and-manage-tokens))
3. Our **open C1 (server-side order-total validation) applies to Square too** — `CreatePayment` trusts the amount we send, exactly like Stripe. Do not take real Square cards until C1 lands.

---

## 1. How merchants connect (Square OAuth, multi-merchant, multi-location)

One Square developer **application** (`client_id` / `client_secret`) connects to unlimited independent seller accounts via **OAuth 2 (authorization-code flow)** — the multi-tenant equivalent of our one-platform-app Stripe setup. ([OAuth overview](https://developer.squareup.com/docs/oauth-api/overview))

**Flow:**
1. Redirect merchant to `https://connect.squareup.com/oauth2/authorize?client_id={APP_ID}&scope={SCOPES}&state={STATE}`. ([create auth URLs](https://developer.squareup.com/docs/oauth-api/create-urls-for-square-authorization))
2. Merchant signs into *their* Square account, approves scopes → Square redirects to our callback with a single-use **authorization code** (5-min expiry).
3. Our server calls **`ObtainToken`** (`POST /oauth2/token`, `grant_type: authorization_code`) → returns `access_token`, `refresh_token`, `expires_at`, and **`merchant_id`**. ([ObtainToken](https://developer.squareup.com/reference/square/o-auth-api/obtain-token))

**Token lifecycle (the new operational bit vs Stripe Express):**
- Store `{merchant_id → access_token, refresh_token, expires_at}` per org.
- **Access tokens expire after 30 days.** Code-flow **refresh tokens do not expire** (unless the seller revokes). Run a scheduled job that proactively refreshes every token ≤7 days old. ([receive & manage tokens](https://developer.squareup.com/docs/oauth-api/receive-and-manage-tokens))
- Subscribe to **`oauth.authorization.revoked`** to detect disconnects.

**Scopes (least-privilege for our use case):** ([permissions ref](https://developer.squareup.com/docs/oauth-api/square-permissions))

| Scope | Why we need it |
|---|---|
| `PAYMENTS_WRITE` | Create/complete/cancel payments + **all Terminal payment ops** |
| `PAYMENTS_READ` | Retrieve payment/refund info |
| **`PAYMENTS_WRITE_ADDITIONAL_RECIPIENTS`** | **Required** to set `app_fee_money` (our cut). Without it, no platform fee. |
| `ORDERS_WRITE` / `ORDERS_READ` | Create/pay/retrieve Orders-API orders |
| `MERCHANT_PROFILE_READ` | Read merchant + locations (Locations API) |
| `DEVICE_CREDENTIAL_MANAGEMENT` | Create device codes to pair Square Terminal hardware |

**Multi-location (e.g. "Taco Joint" × 5 stores):**
- One OAuth token covers **all** of a merchant's locations (one `merchant_id`, many `location_id`s) — **no re-OAuth per location**.
- After connect, call **`ListLocations`** (`GET /v2/locations`) once, store the `location_id`s. ([Locations API](https://developer.squareup.com/docs/locations-api), [ListLocations](https://developer.squareup.com/reference/square/locations-api/list-locations))
- **`location_id` is required on every payment + order** — route each order/checkout to the correct store.

---

## 2. IN-PERSON on Square hardware

Square offers two officially-supported in-person paths; **both are available in Australia.** The choice hinges on one fact: **is the trigger web/server-side (Woahh today) or from a native app (future)?** ([in-person options](https://developer.squareup.com/docs/in-person-payment-options))

### Decision: use **Terminal API** now (no native app); add Mobile Payments SDK later

| | **Path A — Terminal API** (recommended now) | **Path B — Mobile Payments SDK** (later) |
|---|---|---|
| Trigger from | **Web/server POS** — our cloud POS drives it, **no native app** | Native iOS/Android app **only** |
| Hardware | **Square Terminal** (handheld, printer + buyer display, tap/chip + **eftpos**) | Square **Reader / Stand / Kiosk / Tap to Pay** on iPhone/Android |
| Pairing | Cloud **device-code** (one-time per Terminal) | OAuth access token + `location_id` |
| Offline | ❌ none (cloud round-trip) | ✅ supports offline payments |
| AU support | ✅ (US, CA, AU, GB, JP) | ✅ (US, CA, UK, AU) |
| `app_fee_money` | ✅ supported on Terminal checkouts | ✅ |

Sources: [Terminal API overview](https://developer.squareup.com/docs/terminal-api/overview), [Mobile Payments SDK](https://developer.squareup.com/docs/mobile-payments-sdk), [AU hardware](https://squareup.com/au/en/hardware), [intl. regions](https://developer.squareup.com/docs/international-development).

> ⚠️ **Reader SDK is dead** — deprecated and **retired 31 Dec 2025** (built on the dead Transactions API). Do not use it; Mobile Payments SDK is its successor. ([migrate](https://developer.squareup.com/docs/mobile-payments-sdk/migrate))
> Note: the Mobile Payments SDK does **not** drive a Square **Terminal** (it covers Reader/Stand/Kiosk/Tap to Pay). For Terminal hardware, Path A is the only option.

### What Woahh would build (Terminal API)

1. **Pair a Terminal (one-time):** backend calls **Devices API `CreateDeviceCode`** (`product_type: TERMINAL_API` + `location_id`) → short code (e.g. `AFZEFB`). Merchant enters it on the Terminal's "Device Code" screen → `device.code.paired` webhook → persistent `device_id`. ([pair a Terminal](https://developer.squareup.com/docs/terminal-api/integrate-square-terminal))
2. **Take a payment:** `POST /v2/terminals/checkouts` (**`TerminalCheckout`**) with `amount_money`, `reference_id` (our order id), `app_fee_money`, and `device_options.device_id` to route to that specific Terminal. Buyer taps/dips; we get the result by webhook. ([CreateTerminalCheckout](https://developer.squareup.com/reference/square/terminal-api/create-terminal-checkout))
3. **Manage:** `GET /v2/terminals/checkouts/{id}`, `.../cancel`, `.../search`; refunds via `TerminalRefund`.

### How it ties to our cloud POS / KDS

- The in-person trigger comes from **Orders.tsx / KDS** (our existing in-person/dine-in/counter flow). We add a "**Charge on Square Terminal**" action that calls a new `square-terminal-checkout` edge function with the order id → routes to the paired `device_id`.
- The `terminal.checkout.updated` webhook flips `orders.payment_status` (`unpaid → paid`) and the order continues through our normal kanban/KDS exactly as today. Hardware is the merchant's own; we never custody it.
- Preserves the **in-person charity split** via `app_fee_money` on the Terminal checkout (no customer-facing service fee, per our locked in-person model).

---

## 3. ONLINE (Web Payments SDK + Payments/Orders API)

The online stack maps almost 1:1 onto our Stripe PaymentIntent manual-capture-on-confirm flow.

| Our Stripe step | Square equivalent | Where |
|---|---|---|
| Stripe.js card Element | **Web Payments SDK** `payments.card()` → `card.attach()` | Browser |
| `elements.submit()` / confirm | `card.tokenize()` → one-time **payment token** (handles 3-DS/SCA) | Browser |
| Create PaymentIntent (manual) | **`CreatePayment`** with `source_id` (token) + `idempotency_key` + `amount_money` + `order_id` + `app_fee_money` + **`autocomplete: false`** | Server (edge fn) |
| Capture on owner-confirm | **`CompletePayment`** → `COMPLETED` | Server |
| Cancel/void on decline | **`CancelPayment`** → `CANCELED` | Server |
| `application_fee_amount` | **`app_fee_money`** | Server |
| Webhook `payment_intent.*` | **`payment.updated`** (HMAC-signed) | Server |

Sources: [Web Payments overview](https://developer.squareup.com/docs/web-payments/overview), [take a card payment](https://developer.squareup.com/docs/web-payments/take-card-payment), [Card.tokenize](https://developer.squareup.com/reference/sdks/web/payments/card-payments), [take payments](https://developer.squareup.com/docs/payments-api/take-payments), [CreatePayment](https://developer.squareup.com/reference/square/payments-api/create-payment).

### Manual-capture parity with our Stripe flow — ✅ supported

- **Authorize only:** `CreatePayment` with `autocomplete: false` (card validated, funds held, not captured).
- **Capture on owner-confirm:** `CompletePayment`. **Void on decline:** `CancelPayment`. ([delayed capture](https://developer.squareup.com/docs/payments-api/take-payments/card-payments/delayed-capture))
- **Auth-hold window:** **7 days online / card-not-present** (default; overridable via `delay_duration`). Our **7-minute auto-decline cron sits comfortably inside** the 7-day window. ([delayed-capture deep dive](https://developer.squareup.com/blog/a-deep-dive-into-authorization-and-delayed-capture/))
- ⚠️ **Watch-item:** `delay_action: COMPLETE` (auto-capture on expiry) is **disallowed when an `order_id` is attached** to the payment. Since we attach an Orders-API order, we must **always call `CompletePayment` explicitly on owner-confirm** — which our confirm flow already does. (Use `delay_action: CANCEL`, the default, as the safety net.)

### Orders API (model line items)

- **`CreateOrder`** (`POST /v2/orders`) builds an `Order` from line items / taxes / discounts / service charges / fulfillments. Line items can be **ad-hoc** (name/price/qty at order time) — the right fit because **our menu lives in our own DB, not Square Catalog**. ([Orders API](https://developer.squareup.com/docs/orders-api/what-it-does), [create orders](https://developer.squareup.com/docs/orders-api/create-orders), [Order object](https://developer.squareup.com/reference/square/objects/Order))
- **Single payment:** `CreatePayment` with `order_id` (amount must match order total) — the path that pairs with delayed capture. **Split payments** (gift card + card): `PayOrder` (`POST /v2/orders/{id}/pay`). ([pay for orders](https://developer.squareup.com/docs/orders-api/pay-for-orders))

### Webhooks (HMAC-signed — same pattern as our Stripe/Resend/Svix verification)

- Payments: **`payment.created`**, **`payment.updated`** (authorize/complete/cancel). Orders: **`order.created`**, **`order.updated`**, **`order.fulfillment.updated`**. Refunds: **`refund.created`**, **`refund.updated`**. ([webhook events ref](https://developer.squareup.com/docs/webhooks/v2webhook-events-tech-ref), [payment.updated](https://developer.squareup.com/reference/square/payments-api/webhooks/payment.updated))
- Subscribe via the **Webhook Subscriptions API**; enumerate events via `ListWebhookEventTypes`. Square signs with an HMAC header → reuse our existing webhook-verification pattern. ([webhook subscriptions API](https://developer.squareup.com/docs/webhooks/webhook-subscriptions-api))

### Lower-effort fallback (optional)

**`CreatePaymentLink`** (Checkout API) returns a Square-hosted payment page (inline `order` or `quick_pay`) — no card form to host, but **less control over auth/capture timing**. For our confirm-on-accept requirement, Web Payments SDK + `CreatePayment(autocomplete:false)` is the right path; hosted checkout is a quick fallback only. ([square order checkout](https://developer.squareup.com/docs/checkout-api/square-order-checkout))

---

## 4. Commercials

### Can the platform take its commission on Square? — Yes (`app_fee_money`)

- Set **`app_fee_money`** (`{amount, currency}`) on `CreatePayment` / `CreateTerminalCheckout` / `CreatePaymentLink` / `UpdatePayment`. Square takes its processing fee first, credits **our** `app_fee_money` to **our** Square account, and settles the remainder to the **seller's** Square balance. Worked example: $20.00 payment, $2.00 app fee → Square fee ~$0.88 → **we get $2.00, seller gets ~$17.12**. ([app fees](https://developer.squareup.com/docs/payments-api/take-payments-and-collect-fees))
- **Founding-merchant 0% commission** = `app_fee_money: 0` (or omit). Splitting our cut across recipients: `app_fee_allocations`.
- **Fee cap:** app fee ≤ **90%** of `total_money` above the per-currency threshold (**AUD $8.00**), ≤ 60% below it — far above our 4% gross, so no constraint. ([additional considerations](https://developer.squareup.com/docs/payments-api/collect-fees/additional-considerations))

### Payout / settlement

- **Square is merchant-of-record; the seller is paid directly** into their own Square balance → their bank (AU: next-business-day automatic; instant transfer = **1.5%**). We never custody the seller's GMV — only our `app_fee_money` lands in our Square account (daily auto-transfer / Instant Transfer 1.5%). ([Square AU MoR](https://squareup.com/au/en/the-bottom-line/operating-your-business/merchant-of-record))

### Processing fees (AU, seller pays; our app fee is on top)

| | Square (AU) | Stripe (AU, our current) |
|---|---|---|
| In-person card-present | **1.6%** | Higher (Terminal AU pricing) |
| Online / card-not-present | **2.2%** | ~2.9% + A$0.30-class |

Source: [Square payments pricing](https://developer.squareup.com/docs/payments-pricing).

### AFSL / MoR

- **Square AU Pty Ltd holds AFSL 513929 and is merchant-of-record.** Because we **never hold the seller's funds** (only our fee lands in our own Square account), the "platform custodying merchant money" exposure that drives our **Stripe-Connect-Custom AFSL** concern is **Square's** problem, not ours. ([AU FSG](https://squareup.com/au/en/legal/general/au-fsg))
- **AU go-live legal docs** for the Payments API Application Fee (PAAF) service — read/comply before launch: **PAAF Product Disclosure Statement** (`https://squareup.com/au/en/legal/general/pds-paaf`) + **AU Financial Services Guide** (`https://squareup.com/au/en/legal/general/au-fsg`). Confirm AFSL coverage **for the Payments-API-with-app-fee flow specifically** with Square AU before go-live (Square's AFSL applies to some products, not all).
- **Separate from our per-txn fee:** Square takes a share of *app-subscription* revenue under the Partner Integrated Marketplace Agreement (PIMA) if we ever list on the App Marketplace — distinct from `app_fee_money` (which is ours). ([rev share](https://developer.squareup.com/docs/app-marketplace/rev-share))

---

## 5. Square vs Stripe Connect — our use case

| Dimension | **Square** (Payments API + OAuth) | **Stripe Connect** (our current Express) |
|---|---|---|
| Platform per-txn fee | ✅ `app_fee_money` (founding = 0) | ✅ `application_fee_amount` (founding = 0) |
| Fee cap | ≤ 90% above AUD $8.00 threshold / ≤ 60% below | No fixed % cap |
| Who holds funds / MoR | **Seller** paid directly; **Square is MoR**; only our fee transits our account | **Platform is MoR** (destination charge); full GMV hits our balance first |
| AFSL posture (charity split) | **Lower** — Square AU is MoR (AFSL 513929); we don't custody GMV | **Higher** for Custom (needs Stripe AFSL written confirmation); Express avoids it |
| In-person AU rate | **1.6%** card-present | Higher (Terminal AU) |
| Online AU rate | **2.2%** | ~2.9% + A$0.30-class |
| Connect/onboarding model | **OAuth into seller's *own* Square account** (Standard-like); they need/create a Square account | **Express** managed sub-accounts we provision (`stripe-connect-onboard`) |
| Token / credential mgmt | 30-day access tokens; **scheduled refresh job required** | Connect account id + our secret key; no refresh job |
| In-person hardware | **Merchant's own** Square Terminal via Terminal API (cloud pairing, no LAN/BT) | We provision Stripe Terminal, or Tap to Pay via RN app (Phase 2, Apple entitlement) |
| Online card entry | Web Payments SDK `card.tokenize()` | Stripe.js + PaymentIntent |
| Manual capture | `CreatePayment(autocomplete:false)` → `CompletePayment`/`CancelPayment` (7-day online hold) | PaymentIntent manual capture |
| Webhooks | `payment.updated` etc., HMAC-signed | `payment_intent.*`, HMAC-signed |
| Cross-border | Seller must be same country/currency as our Square account (AU-only ✅) | `on_behalf_of`; N/A for AU-only |
| Monthly platform cost | None | None |

Independent comparisons: [Zapier](https://zapier.com/blog/stripe-vs-square/), [Airwallex](https://www.airwallex.com/au/blog/comparison-stripe-vs-square). Stripe destination-charge / MoR refs: [destination charges](https://docs.stripe.com/connect/destination-charges), [merchant of record](https://docs.stripe.com/connect/merchant-of-record).

---

## 6. Proposed Woahh architecture

**Merchant picks Stripe OR Square at onboarding.** Add `organizations.payment_provider ∈ {stripe, square}` (default `stripe`). The entire order/KDS/storefront/marketplace/confirmation/courier/notification stack is **payment-agnostic and unchanged** — only the payments adapter branches.

### Payment abstraction (mirror the existing Stripe seam)

We already isolate payments in three edge functions + the capture-on-confirm hook. Mirror them 1:1:

| Existing (Stripe) | New (Square) | Role |
|---|---|---|
| `stripe-connect-onboard` | **`square-oauth-connect`** | OAuth authorize URL + `ObtainToken` callback; store tokens; `ListLocations` |
| `stripe-payment-intent` | **`square-payment`** | `CreateOrder` (ad-hoc line items) + `CreatePayment(autocomplete:false, app_fee_money, order_id, location_id)` |
| `order-respond` (capture/cancel branch) | extend with a **Square branch** | `CompletePayment` on confirm / `CancelPayment` on decline |
| `stripe-webhook` | **`square-webhook`** | verify HMAC; `payment.updated` → flip `orders.payment_status` |
| — | **`square-terminal-checkout`** (+ `square-devices` pairing) | in-person: `CreateDeviceCode` pairing + `CreateTerminalCheckout` |

Call sites in `CardPayment.tsx` / checkout / `Orders.tsx` branch on `org.payment_provider`. The storefront's existing `charges_enabled`/payment-ready gate becomes a provider-aware "is this merchant payment-ready?" check.

### What's reusable (almost everything)

- ✅ `orders` table + line-items JSONB, order-confirmation flow, KDS, kanban, courier dispatch, customer notifications, storefront, marketplace — **unchanged**.
- ✅ `orders.payment_status` state machine (`unpaid → authorized → paid / canceled / refunded`) — **reused as-is** (Square statuses map onto it).
- ✅ Manual-capture-on-confirm pattern, the 7-minute auto-decline cron, the webhook-HMAC-verification pattern, the "founding = 0 fee" concept — **all reused**.
- ✅ `order-respond` already branches on `payment_status` — add a provider check.

### What changes (DB)

- `organizations`: add `payment_provider`, `square_merchant_id`, `square_payment_ready` (mirror of `charges_enabled`).
- **New `square_connections`** table: `org_id, merchant_id, access_token, refresh_token, expires_at, scopes` (RLS owner-only; tokens are secrets — consider Vault/encrypted column, never client-readable).
- **New `square_locations`** (or JSONB on org): `org_id, location_id, name, status` from `ListLocations`.
- `orders`: add `square_payment_id`, `square_order_id`, `square_terminal_checkout_id` (parallel to `stripe_payment_intent_id`).

### What's net-new operationally

- A **scheduled token-refresh job** (pg_cron) refreshing Square access tokens ≤7 days old (30-day hard expiry). No Stripe equivalent.
- A **new in-person pairing UX** (enter device code on the Terminal) in the dashboard.
- An **AU Square developer account + AU bank account** + PAAF PDS/FSG review (human/compliance).

### Phased plan + effort estimate

| Phase | Deliverable | Effort | Blockers |
|---|---|---|---|
| **0. Prereqs (human)** | AU Square dev account + AU bank; create Square application; read PAAF PDS/FSG; confirm AFSL coverage for app-fee flow with Square AU | ~1 wk (mostly waiting) | Compliance sign-off |
| **1. Connect** | `square-oauth-connect` (authorize + `ObtainToken` + `square_connections` + `ListLocations`); token-refresh cron; `payment_provider` flag + onboarding picker | ~3–4 days | Phase 0 |
| **2. Online** | `square-payment` (`CreateOrder` ad-hoc + `CreatePayment(autocomplete:false, app_fee_money)`); Web Payments SDK in `CardPayment.tsx` (provider branch); `square-webhook` (`payment.updated`); extend `order-respond` capture/cancel; **gate behind C1 fix** | ~5–7 days | **C1 (order-total validation)**, Phase 1 |
| **3. In-person** | `square-devices` pairing UX + `square-terminal-checkout` (`CreateTerminalCheckout`) wired into Orders/KDS; `terminal.checkout.updated` webhook | ~4–5 days | Phase 1; merchant owns a Square Terminal |
| **4. Hardening + go-live** | Refund paths (`RefundPayment`/`TerminalRefund`), `oauth.authorization.revoked` handling, reconciliation, adversarial review, end-to-end test | ~3–4 days | Phases 1–3 |
| **5. (Later) Mobile Payments SDK** | Reader/Stand/**Tap to Pay** + offline — only when the native RN merchant app ships | deferred | Native app (separate track) |

**Rough total (Phases 0–4): ~3 weeks of build** + compliance lead time. Reuse is high because the order/KDS/confirmation layer is untouched and the Stripe seam is the template.

---

## 7. Risks / unknowns / confirm with Square

- [ ] **C1 (server-side order-total validation)** — `CreatePayment` trusts the amount we send, same as Stripe. **Do not take real Square cards until C1 lands.** (Internal blocker, not Square.)
- [ ] **AU Square account + bank** required to collect `app_fee_money` from AU sellers (currency must match). Confirm setup. ([additional considerations](https://developer.squareup.com/docs/payments-api/collect-fees/additional-considerations))
- [ ] **AFSL coverage for the Payments-API-with-app-fee flow** — Square AU's AFSL applies to *some* products. Get **written confirmation** it covers our skim-a-platform-fee model (analogous to confirming Stripe AFSL for Connect Custom).
- [ ] **`delay_action: COMPLETE` is disallowed with an attached `order_id`** — we must always call `CompletePayment` explicitly on confirm (we already do). Verify behavior in sandbox. ([delayed capture](https://developer.squareup.com/docs/payments-api/take-payments/card-payments/delayed-capture))
- [ ] **Terminal API has no offline mode** (cloud round-trip) — confirm acceptable for in-person; Mobile Payments SDK (offline) is the later answer. ([Terminal overview](https://developer.squareup.com/docs/terminal-api/overview))
- [ ] **Token-refresh job** is a new operational dependency (30-day access-token expiry) — must be reliable or merchants silently disconnect. ([manage tokens](https://developer.squareup.com/docs/oauth-api/receive-and-manage-tokens))
- [ ] **Exact OAuth scopes per in-person endpoint** — confirm `DEVICE_CREDENTIAL_MANAGEMENT` + `PAYMENTS_WRITE` are sufficient for the full pairing→checkout→refund Terminal path in the API reference before build.
- [ ] **Merchant must already have / create a Square account** (Standard-like model) — higher friction than Stripe Express for merchants *without* Square; that's why Square is the *alternative*, not the default.
- [ ] **Square Catalog not used** — we send ad-hoc line items; confirm reporting/receipts are acceptable without catalog linkage (optional future sync).

---

### Appendix — primary sources

OAuth/multi-merchant: [overview](https://developer.squareup.com/docs/oauth-api/overview) · [manage tokens](https://developer.squareup.com/docs/oauth-api/receive-and-manage-tokens) · [permissions](https://developer.squareup.com/docs/oauth-api/square-permissions) · [ObtainToken](https://developer.squareup.com/reference/square/o-auth-api/obtain-token) · [Locations](https://developer.squareup.com/docs/locations-api).
In-person: [in-person options](https://developer.squareup.com/docs/in-person-payment-options) · [Terminal API](https://developer.squareup.com/docs/terminal-api/overview) · [pair a Terminal](https://developer.squareup.com/docs/terminal-api/integrate-square-terminal) · [CreateTerminalCheckout](https://developer.squareup.com/reference/square/terminal-api/create-terminal-checkout) · [Mobile Payments SDK](https://developer.squareup.com/docs/mobile-payments-sdk) · [Reader SDK retired](https://developer.squareup.com/docs/mobile-payments-sdk/migrate) · [AU hardware](https://squareup.com/au/en/hardware).
Online: [Web Payments](https://developer.squareup.com/docs/web-payments/overview) · [take card payment](https://developer.squareup.com/docs/web-payments/take-card-payment) · [Payments API](https://developer.squareup.com/docs/payments-api/take-payments) · [delayed capture](https://developer.squareup.com/docs/payments-api/take-payments/card-payments/delayed-capture) · [Orders API](https://developer.squareup.com/docs/orders-api/what-it-does) · [webhooks](https://developer.squareup.com/docs/webhooks/v2webhook-events-tech-ref).
Commercials: [app fees](https://developer.squareup.com/docs/payments-api/take-payments-and-collect-fees) · [pricing](https://developer.squareup.com/docs/payments-pricing) · [AU FSG / AFSL 513929](https://squareup.com/au/en/legal/general/au-fsg) · [PAAF PDS](https://squareup.com/au/en/legal/general/pds-paaf) · [intl. development](https://developer.squareup.com/docs/international-development).
