# Apple Pay + Google Pay on Woahh Web Checkout — Risk Register + Implementation Design

> For founder sign-off before implementation. Targets the LIVE Stripe path (woahh.app prod, built from `origin/main`) and the sandbox-built Square second provider, on both checkout surfaces (default `RestaurantStorefront` + bespoke `PublishedStorefront`/`Checkout`). All severities below are the **adjudicated** severities from the confirmed-risk verdicts, not the raw finding claims.

---

## DOUBLE-CHECK — verified status (2026-06-12, post-merge)

> Wallets are now **MERGED to `main` and LIVE on woahh.app** (founder explicitly authorized wallets→main). This section records an **adversarial functional + security re-check** (5-dimension Workflow, 26 agents, every MEDIUM+ finding verified against the live code) layered on top of the pre-build register below. **Do not represent the surface as "fully secure" — three real items remain open (1, 4, 5).**

**✅ Verified working / secure (provable from code; Apple Pay also device-tested):**
- **Apple Pay (Square)** — **LIVE-VERIFIED on a real iPhone on Test Pizza (PRODUCTION Square account).** `tokenize()` is the first await (Safari gesture rule — verified NOT-A-BUG); double-charge prevented (R15/R16 atomic `try_claim_square_auth` + resume-by-payment-id); wallet sheet total in DOLLARS.
- **Square server `square-payment` (v16)** — atomic claim **released on throw** + linkErr-void; R19 decline allow-list (never raw `errors[].detail`); per-org OAuth token, **no global fallback** (BLK-2); charge amount from the **server** total (C1); SHA-256 idempotency. Verdict: WORKS / SECURE.
- **Capture-path security (`order-respond`)** — claim-before-capture, provider routing by the **order's** auth id (not the org's current flag), H-3 amount-mismatch guard, **decline/auto-decline VOID pending holds**, auto-decline gated to a service_role-claim JWT. All verified SECURE.
- **Stripe wallets (ECE, `stripe-payment-intent` v30)** — deferred-intent (no pre-created clientSecret), double-charge prevented, amount parity wallet==Elements==PI, `event.paymentFailed()` on every error path, idempotency bound to amount, separate Elements groups. WORKS in code (not device-tested).

**Register items now CLOSED:** R10/R11 (fake wallet buttons removed, live), R7 (guest-PII snapshot — migration `20260612160000`), R15/R16 (atomic claim — migration `20260612170000`, applied live), R13/R17 (ECE deferred-intent rebuilt), R2 (1% service fee dropped), R1 (built on `feat/wallets` off main, merged).

**🔶 REAL OPEN ITEMS (do not call "fully secure" until done):**
1. **R3 — PENDING-capture gap [HIGH, production-only].** `order-respond` SILENTLY SKIPS a Square `PENDING` (3DS/async) / Stripe `processing` authorization at owner-confirm → order confirmed but **never captured** (cook-but-unpaid). Sandbox approves instantly so it never surfaces there; **production can return PENDING.** Lower-probability for WALLETS (Apple/Google tokens are pre-authenticated, rarely 3DS-challenged) but a real gap. **Fix before broad production card reliance — with founder review (order-respond is incident-prone).**
2. **GPAY-002 — Google Pay tap unverified [MEDIUM].** GPAY-001 (button rendered into a collapsed container) **fixed** (`f718065`: attach into a visible container). Remaining: confirm the Square-rendered button's click bubbles to the container `onClick` on a real **Chrome/Android** device; fallback if not = a direct click listener. Google Pay needs **no** domain registration/file.
3. **Stripe Apple Pay domain registration [MEDIUM].** Add `woahh.app` to Stripe's **payment_method_domains** before Stripe merchants' Apple Pay renders. (Square's `woahh.app` is already verified + `.well-known/apple-developer-merchantid-domain-association` hosted at `5caf888`, confirmed serving HTTP 200 raw token — not SPA-shadowed.)
4. **Square SDK env [config, production].** woahh.app's `VITE_SQUARE_APPLICATION_ID` must be the PROD app id (`sq0idp-`) so the production Web Payments SDK loads; `window.Square` is cached per session, so ONE build cannot mix sandbox + prod Square merchants. **Revert test-bistro's Square-sandbox flip** (`docs/sql/SQUARE_SANDBOX_GOLIVE.sql`) before relying on it on prod.
5. **CORS `*.pages.dev` [MEDIUM] + Square OAuth stale-flag [MEDIUM].** Payment fns accept ANY `*.pages.dev` origin (`_shared/cors.ts`, preview convenience) — tighten to the project's own preview hosts (mitigated by per-order capability checks). `square_payment_ready` can be stale if a token expires without a flag update — the refresh cron mitigates; add monitoring.

**Verified NOT bugs (don't re-chase):** Apple Pay gesture timing; Square + Stripe double-charge protections; idempotency keys; `charges_enabled` handling; wallet-init failure never blocks the card fallback.

---

## 1. Risk register

Sorted CRITICAL → LOW. No CRITICAL items survived adjudication. The most load-bearing items for go/no-go are **R1 (branch direction)**, **R10 (live fake-wallet buttons)**, and **R7 (cross-guest receipt redirection)** — fix those before any wallet code.

| ID | Dimension | Risk (specific to our code) | Severity | Fix / mitigation |
|---|---|---|---|---|
| **R1** | compliance-ops-deploy | Wallet work must NOT branch off `feat/storefront-platform`. Git reality is inverted vs CLAUDE.md: `origin/main` is **65 commits AHEAD** (`rev-list --left-right origin/main...origin/feat/storefront-platform = 65/1`) and already holds the whole storefront platform + the F15 server-side online-card gate + F28 amount-bound idempotency. The stale branch LACKS both money-safety fixes; building wallets there = building on pre-F15/F28 code and risking a 65-commit regression on merge. Its Cloudflare preview is OLDER than prod, so "verified on preview" wouldn't reflect prod. | HIGH | Branch `feat/wallets` off `origin/main` (HEAD `35f9588`). Wire ECE into the `main` versions of `CardPayment.tsx`, `screens/Checkout.tsx`, `RestaurantStorefront.tsx`, `stripe-payment-intent`. Cherry-pick the single Raising-Tenders preview commit (`490635c`) onto main if still wanted. Update CLAUDE.md + this plan's §3/§7 to record the inverted direction. Verify against a **main-built** staging/preview, never the stale-branch preview. |
| **R10** | compliance-ops-deploy | Fake "Apple Pay"/"Google Pay" affordances already ship live and violate Apple's AUG (lucide Apple glyph + black "Pay" button + Google-styled button that do NOT invoke a wallet — they open the ordinary card dialog and only stamp `Pay: apple` into order notes). The **RetailStorefront** Apple/Google radio (`RetailStorefront.tsx:693-707`) is **completely ungated** and ships the deceptive labels live now; the restaurant buttons (`RestaurantStorefront.tsx:1566-1597`) are gated behind `showOnlinePay` (default off) but use look-alike marks. | HIGH | **Prerequisite, not polish.** (1) Delete the `apple`/`googlepay` radio options from `RetailStorefront.tsx` now (ungated, live). (2) Replace the two fake restaurant buttons with a single generic "Pay by card" button using neither the Apple glyph/black style nor the Google-blue style; drop `"apple"`/`"googlepay"` from the `payment` union and the `Pay: ${selectedPayment}` notes string. (3) Only render a real Apple Pay button after `availablepaymentmethodschange` confirms availability, using Apple's official asset/HIG. |
| **R7** | guest-anon | Persistent anon session reuses ONE `customers` row across different guest emails on a shared device. `customerSupabase` has `persistSession:true` + fixed `storageKey`; `ensureGuestSession()` is a no-op when a session exists, so a returning guest keeps the same `auth.uid()`. `upsert_my_consent` Branch 1 does `email = COALESCE(v_email, email)` → overwrites the stored email. Orders have NO email snapshot; `order-respond` resolves the receipt recipient LIVE from `customers.email`. Net: on a family iPad/kiosk/two-tab session, Guest A's still-pending order receipt (full items + total + AU tax-invoice PII) is emailed to Guest B. Wallets amplify this (more shared-device, faster reorders). | HIGH | **Layer A (now, ~3 lines):** in `ensureGuestSession`, if the existing session is anonymous, `signOut()` + mint a FRESH anon session so each guest order gets its own uid → its own `customers` row. **Layer B (durable):** add `orders.customer_email` (+`customer_name`) written by `create_order_with_inventory`; have `order-respond` prefer `order.customer_email` over the live `customers.email`. Do both. |
| **R15** | idempotency-webhooks | Square wallet single-use tokens defeat idempotency dedup. The key folds in `source_id` (`SHA-256(order.id:amount:source_id)`, H-7) so a typed-card retry deliberately gets a fresh key — but a wallet **double-tap** mints a new `source_id` → new key → Square does NOT dedup → **two authorizations**. The resume-by-`square_payment_id` guard is a non-atomic read; two concurrent submits both read NULL and both `CreatePayment`. Impact is a duplicate self-voiding hold, not double settlement. | MEDIUM | Add a server-side **atomic claim** before `CreatePayment`: conditional `UPDATE ... WHERE square_payment_id IS NULL` (or `FOR UPDATE`), only the winner proceeds; loser short-circuits to resume. (This also fixes the existing typed-card race.) Do NOT rely on a client `wallet:true` flag. Key the wallet idempotency on `order.id+amount` alone. |
| **R16** | idempotency-webhooks | Square second-authorize ORPHANS the first. The post-create `UPDATE square_payment_id = payment.id` is unconditional (no-downgrade guard only excludes terminal states), so the row points at the 2nd auth; `order-respond` + the cron capture/cancel only the current id → the FIRST hold is never captured or voided, lingers ~7 days, and the webhook can't reconcile it (keys on the current id). | MEDIUM | Primary: the atomic claim from R15 prevents two auths. Defense-in-depth: before overwriting `square_payment_id`, if a different live APPROVED/PENDING auth exists for the order, `CancelPayment` it first; OR store auth ids in an append-only child table and have `order-respond` cancel ALL non-captured auths on confirm/decline. |
| **R2** | amount-integrity | The two storefronts store DIFFERENT `total_amount` for the same cart: the bespoke path ADDS a 1% service fee (`serviceFeeCents`, `PublishedStorefront.tsx`), the default path omits it (`RestaurantStorefront.tsx:397`). C1 is a floor only — it stores `p_total` verbatim, so the 1%-higher bespoke total passes and is charged. A wallet sheet (which must equal `total_amount`) inherits a per-surface discrepancy; there is no single authoritative total to anchor to. Also: `application_fee_amount` is hardcoded 0, so the 1% the customer pays is NOT split out per the locked 3%+1% model. | HIGH | Lock ONE total formula before enabling online cards/wallets. Extract `computeTotals` (`Checkout.tsx`) into a shared helper; have `RestaurantStorefront` consume it so both surfaces store identical `total_amount`. Per the locked model, ADD the 1% service fee to the default path. Reconcile the hardcoded `application_fee_amount: 0` with 3%+1%→2%/2%. Add a test: both paths → same `total_amount` for a fixed cart; captured == stored == wallet-sheet amount. |
| **R12** | guest-anon | `upsert_my_consent` Branch 2 lets an anonymous guest CLAIM an unclaimed CRM row (`user_id IS NULL`) by phone/email match and overwrite its name/email with guest values (guest values win via COALESCE). A visitor who knows a regular's on-file number can re-point that CRM contact's identity + receipts/loyalty + flip `marketing_opt_in`. This is the tracked-but-deferred F19 consent half. | MEDIUM | In Branch 2, do NOT overwrite identity on an unclaimed match: `name/email = COALESCE(existing, guest)` (fill nulls only), never adopt guest `marketing_opt_in` onto a merchant-entered row. Best: gate phone/email→existing linking behind verified (magic-link) sign-in; add `customers.is_guest` and only let the guest flow claim rows it created. |
| **R3** | capture-state-machine | Confirm-time capture silently no-ops a non-terminal auth. Square `PENDING` (3DS/risk hold) at confirm falls into a comment-only branch — order is already flipped to confirmed by the claim RPC, no capture, `payment_status` unchanged → cook-but-unpaid, no later auto-capture (webhook only mirrors status). Same gap on Stripe `processing`. Wallets raise the PENDING rate (3DS/SCA more common). Decline correctly cancels PENDING; confirm is the asymmetry. | MEDIUM | On confirm with Square `PENDING` (and Stripe `processing`), set a distinct `payment_status='authorizing'` + `console.warn`, so the row is not indistinguishable from captured. Then either have `square-webhook` CompletePayment when it later resolves to APPROVED on a confirmed order, or add a low-frequency reconcile cron. At minimum surface "payment still authorizing — do not start" to the owner. |
| **R13** | wallet-gotchas (Stripe) | ECE requires the deferred-intent pattern but our dialog is PaymentIntent-FIRST (`CardPayment.tsx` pre-creates the PI in a `useEffect`, then mounts `<Elements options={{clientSecret}}>`). ECE needs `elements({mode:'payment', amount, currency, captureMethod})` with NO `clientSecret`, PI created inside `ece.on('confirm')`. Two values the client never sees today must be surfaced: the authoritative cents (`orders.total_amount`) and the manual-vs-automatic capture flag (`order.status`). The plan's "~0.5 day handshake" understates a real restructure. | MEDIUM (plan-quality) | Restructure `CardPaymentDialog` to deferred-intent for the Stripe branch. Have `stripe-payment-intent` (or a tiny read) return `total_amount` cents + a `manual_capture` flag. Build `elements({amount, captureMethod})` matching the PI. Keep the existing `<PaymentElement/>` card form as the always-present fallback. Re-budget §3 line 113 as a component rewrite. |
| **R17** | wallet-gotchas (Stripe) | Same restructure framed for capture/amount parity: if `captureMethod` mismatches the PI's `capture_method`, some wallet methods hard-decline; the plan's "both 'manual'" is wrong (auto-accept orders are `automatic` capture). Amount parity: the wallet sheet must equal `orders.total_amount`, but the client only holds the `amountLabel` display string. | MEDIUM (plan-quality) | Drive `captureMethod` from the returned status, never hardcode `'manual'`. Pass authoritative cents into `elements({amount})`. Add an integration test asserting `elements.amount === PI.amount` and `elements.captureMethod === PI.capture_method` for both an `awaiting_confirmation` and an auto-accept order. (Same edge-fn change as R13.) |
| **R18** | compliance-ops-deploy | Per-host wallet-domain registration has no code seam. Apple Pay needs each exact host (`woahh.app` + every `<slug>.woahh.app`) registered — no wildcards. The plan hooks "register-on-publish" onto a `set_subdomain_slug` RPC / publish edge fn that **does not exist** (grep empty); slugs are auto-set only at signup. No `payment_method_domains`/`apple-pay/domains` code anywhere. The natural hook (`storefrontConfigApi.upsert` flipping `is_published`) exists but nothing attaches registration. If skipped, wallet buttons silently don't render on subdomains. | MEDIUM | Build the slug-provisioning path (validated `set_subdomain_slug` RPC / publish edge fn) first, then attach a server-side `wallet-domain-register` edge fn: list-before-create `GET /v1/payment_method_domains`, `POST` `<slug>.woahh.app` on the platform live key, assert `apple_pay.status=='active'`; Square `RegisterDomain` for Square orgs; store status in `settings.payments.wallet_domain_status`; disable old host on rename; backfill before flipping wallets on. Gate the wallet UI on `wallet_domain_status`. |
| **R20** | idempotency-webhooks | The decline/void email + OrderStatus DECLINED state have no "pending hold will disappear" copy. Wallet users see the pending charge instantly (issuer push), so a void produces a visible "charged then cancelled" moment with no reassurance. The current decline copy ("reply to arrange a refund") is mildly counterproductive for an auth-hold decline (nothing to refund). | LOW | Add provider-agnostic copy to `buildDenyHtml` (`order-respond`) and the `OrderStatus` DECLINED block: "Your card was authorised but not charged; any pending hold drops off within a few business days." Only render when the order had a card auth. Ship with/before wallets; benefits the existing card flow. |
| **R8** | tenant-isolation | `order-respond` + `refund-order` skip the fail-closed `SQUARE_API_BASE` host validation `square-payment` enforces (local untrimmed `const`, no regex). A typo'd/whitespaced base during AU cutover could misdirect per-org Square bearer tokens. Operator-set secret (NOT attacker-controllable); Square not in prod. | MEDIUM | Hoist `assertSquareBaseValid()` into `_shared/square.ts`; delete the local `SQUARE_API_BASE`/`squareFetch` in both fns and import the shared trimmed+validated ones; call the guard before any bearer-carrying `squareFetch`. Also add it to `square-oauth-connect`. Pre-AU-go-live hardening. |
| **R11** | guest-anon | RetailStorefront advertises Apple/Google Pay/Card as a payment selector that takes NO money — order always lands at `awaiting_confirmation`, selection only goes into notes. Customer believes they paid. AU consumer-representation problem. (Overlaps R10's retail fix.) | MEDIUM | Remove the wallet radio entries (R10) and relabel "Pay on collection". Defer real retail card plumbing; retail signup is currently paused. Also drop the misleading "Complete your purchase securely" copy. |
| **R14** | guest-anon | Default-storefront wallet buttons render ABOVE the email/Terms fields and are the first controls — a forward-looking consent-bypass trap. Today safe (disabled until `canPlaceOrder`; `submitOrder` re-validates Terms + runs `recordConsentAndGetCustomerId`). But a real ECE/Square wallet iframe fires on tap and can't be `disabled`, so a tap could authorize before consent/Terms. | LOW | Do not MOUNT the wallet element until `canPlaceOrder` (Terms + email + name); move it below the Terms checkbox. In `ece.on('confirm')`/the wallet click handler, guard on `!canPlaceOrder` and run `ensureGuestSession` + `recordConsentAndGetCustomerId` BEFORE any PI-create/tokenize. Test that the wallet path can't reach `createPaymentIntent` with `tosAccepted=false`. |
| **R6a** | tenant-isolation | `SQUARE_SINGLE_ORG_ID` pin in `square-payment` silently 400s the 2nd+ merchant's online card/wallet if the env is left set. Dead-by-default (env set nowhere today); per-org OAuth is the real isolation boundary. | LOW | Delete the pin (lines 214-225). If a kill-switch is wanted, make it a comma-split allowlist + loud log + a distinct frontend "card temporarily unavailable" state (vs silent pay-at-venue). Add "confirm UNSET in prod" to the Square checklist. |
| **R6b** | tenant-isolation | `resolveLocationId` trusts `order.square_location_id` first with no membership check. Safe today (no writer; RLS pins the column), but a future multi-location order writer could intra-merchant mis-bucket GMV. Per-org token already prevents cross-tenant fund misrouting. | LOW | Add the membership check now (mirror `set_square_default_location`): only return `orderLocationId` if it's in `conn.locations`, else fall through to default. |
| **R5** | tenant-isolation | Apple Pay on subdomains is greenfield per-host registration (covered by R18) — fund-routing is SAFE (`on_behalf_of`+`transfer_data.destination` per-org); risk is per-host correctness + missing `.well-known`. | LOW | See R18 + §2 `.well-known` design. Pre-ship design requirement, no live defect. |
| **R4** | domain-registration | Square `RegisterDomain` auth model (per-seller OAuth vs platform) is unprovisioned in our scopes (`SQUARE_OAUTH_SCOPES` has no apple-pay-domains scope). One sandbox connection affected today. | LOW | Sandbox-verify before building the Square hook. If a scope is needed, add it to `SQUARE_OAUTH_SCOPES` now (new connects carry it, mirroring `PAYMENTS_WRITE_IN_PERSON`) + plan one re-consent for the single sandbox merchant. Gate behind Square AU go-live. |
| **R9** | tenant-isolation | `square_payment_ready` can drift from a deleted `square_connections` if the revoke webhook is misconfigured → broken card field instead of pay-at-venue fallback. Fail-closed, no fund misrouting. | LOW | On a Square 401/`ACCESS_TOKEN_REVOKED` at authorize, best-effort clear `square_payment_ready=false` (service-role) so the storefront self-heals to pay-at-venue without waiting on the webhook. Only on token/auth errors, never on card declines. |
| **R19** | idempotency-webhooks | Square wallet decline path leaks Square's raw `errors[].detail` to the client (bypasses the F43 `failSafe` helper). Mostly benign decline text; long-tail config/permission errors could expose internals. Sandbox-only. | LOW | Map Square decline `code`s to an allow-list of customer-safe messages; return `{error: friendly, code}`, never the raw `detail`. Full `errors[]` is already logged server-side. Benefits the typed-card path too. |

---

## 2. Implementation design (file-by-file)

### 2.0 Branch reconciliation (do FIRST — R1)

```bash
git fetch origin
git checkout -b feat/wallets origin/main      # HEAD 35f9588 — has F15 + F28 + the platform
# (optional) cherry-pick the Raising Tenders preview if still wanted:
# git cherry-pick 490635c
```

All edits below target the **`origin/main`** versions of the files. `feat/storefront-platform` is stale (behind+65) — do not build on it. Update CLAUDE.md to record the inverted direction so no one re-uses the stale branch.

### 2.1 Surface the authoritative amount + capture mode to the client (C1 parity — R13/R17)

**`supabase/functions/stripe-payment-intent/index.ts`** — the only server change for Stripe wallets. Today the success response is `{ client_secret }`. Extend it (it already computes both values):

```ts
// amountCents already at ~line 120; capture mode already at ~line 152
return json({
  client_secret: pi.client_secret,
  amount: amountCents,                                   // orders.total_amount, C1-validated cents
  capture_method: order.status === 'awaiting_confirmation' ? 'manual' : 'automatic',
});
```

No change to `paymentIntents.create` params — `capture_method`, `transfer_data[destination]`, `on_behalf_of`, `application_fee_amount:0`, and the amount-bound idempotency key (`pi-${order.id}-${amountCents}`) all work identically for wallet tokens (they process as `type:card` PIs). The F15 gate (`online_card_enabled` + `pay_mode!=='venue'`, lines 90-106) and the destination-charge model are inherited unchanged — **wallets are just another way to create the same PI**.

### 2.2 Stripe Express Checkout Element in the shared dialog (R13/R17/R14)

**`src/components/checkout/CardPayment.tsx`** — the single shared charge surface for both storefronts. Restructure the Stripe branch from PI-first to **deferred-intent**:

1. Fetch `amount` + `capture_method` first (from the extended `stripe-payment-intent` response, or a tiny read RPC).
2. `const elements = stripe.elements({ mode:'payment', amount: totalCents, currency:'aud', captureMethod })` — **`captureMethod` driven by the returned status, never hardcoded** (R17).
3. Mount `<ExpressCheckoutElement>` ABOVE the existing `<PaymentElement>` — but **only render it once `canPlaceOrder` is true** (Terms + email + name), per R14. The existing `<PaymentElement>` card form stays as the always-present fallback.
4. In `ece.on('confirm')`: guard `if (!canPlaceOrder) { event.paymentFailed?.(); return; }`; for guests run `ensureGuestSession()` + `recordConsentAndGetCustomerId({...tosAccepted})` BEFORE creating the PI; then `createPaymentIntent` → `stripe.confirmPayment({ elements, clientSecret, confirmParams:{ return_url }})`. Success handling is unchanged — the existing branch already accepts `succeeded | requires_capture | processing` (line 101).
5. `business: { name: merchantName }` for the per-merchant "Pay ▸" label; `emailRequired: true` for the guest receipt email; collapse the express section on `availablepaymentmethodschange`.
6. SDK is ready — `@stripe/stripe-js 5.10.0` + `@stripe/react-stripe-js 3.10.0` both export `ExpressCheckoutElement`, no bump.

Because `CardPaymentDialog` is shared, both checkout paths inherit Stripe wallets from this one change.

### 2.3 Mount points on BOTH checkout paths

- **Default restaurant** (`src/pages/storefront/RestaurantStorefront.tsx`): the wallet trigger lives inside the shared dialog (§2.2). The fake buttons at `:1566-1597` are **deleted** per R10 and replaced with a single generic "Pay by card" entry; the dialog (gated by `showOnlinePay` at `:732-740`) surfaces the ECE itself. Keep void-on-cancel (`voidUnpaidOrder`, `:1847-1861`).
- **Bespoke** (`src/components/storefront/screens/Checkout.tsx`): add the wallet affordance in the live `PayByCardPanel` (~`:1103-1130`); the real charge already routes through the shared `CardPaymentDialog` mounted at ~`:1999-2018`, so the ECE is inherited automatically. **Fix the abandon divergence**: the bespoke path does NOT void on cancel — wire it to `voidUnpaidOrder` like the default path so an abandoned wallet tap doesn't leave a phantom unpaid ticket (the 7-min cron is the fallback either way).
- **Retail** (`RetailStorefront.tsx`): no wallets — remove the fake radio (R10/R11), relabel "Pay on collection". No payment plumbing here; out of scope.

The `provider` prop is already threaded to both call sites (`RestaurantStorefront.tsx:1841`, `Checkout.tsx:2005`) and into `CardPaymentDialog`. The wallet code branches on `provider` exactly like the existing card path.

### 2.4 Square Web Payments SDK applePay/googlePay branch (R15/R16/R19)

**Client — `CardPayment.tsx` `SquarePayForm` (~`:156-291`):** today only `payments.card()`. Add, reusing the `locationId` already resolved at `:305-306`:

```js
const req = payments.paymentRequest({ countryCode:'AU', currencyCode:'AUD',
  total:{ amount: String(totalCents), label:'Total' }});  // totalCents = orders.total_amount, NOT a client recompute
const googlePay = await payments.googlePay(req); await googlePay.attach('#gpay-button');
const applePay  = await payments.applePay(req);  // own button, Apple HIG asset
// Apple Pay user-gesture rule: tokenize() MUST be the first await in the click handler — no intervening awaits.
async function onApplePayClick() {
  if (!canPlaceOrder) return;                       // R14
  const { token } = await applePay.tokenize();      // synchronous-in-gesture
  await ensureGuestSession(); await recordConsentAndGetCustomerId({...}); // R14 — after token, before invoke
  await supabase.functions.invoke('square-payment', { body:{ order_id, source_id: token, wallet:true }});
}
```

The wallet token substitutes for the card token at the existing invoke — `square-payment` needs **zero amount/capture changes** (amount re-derived from `orders.total_amount`, `autocomplete:false`, per-org token, no-downgrade guard all unchanged). Add Square's recommended `verifyBuyer()` SCA on the wallet path to cut declines.

**Server — `square-payment/index.ts` (R15/R16 — the real server work):** add an **atomic claim before `CreatePayment`** so single-use wallet tokens can't double-authorize:

```sql
UPDATE orders SET square_auth_claim = gen_random_uuid()
 WHERE id = $order AND square_payment_id IS NULL AND square_auth_claim IS NULL
 RETURNING id;     -- only the winner proceeds to CreatePayment; loser → resume branch
```

For wallet-originated calls, key the idempotency on `order.id + amountCents` ALONE (don't fold in `source_id`). Defense-in-depth (R16): before the post-create `UPDATE square_payment_id`, if a different live APPROVED/PENDING auth exists, `CancelPayment` it first. **R19:** in the `CreatePayment` failure branch (`:388-399`), map `errors[].code` to an allow-list of safe messages, return `{error: friendly, code}` — never the raw `detail`.

### 2.5 Register-on-publish domain hook (R18/R4/R5)

No code seam exists. Build in order:

1. **Slug provisioning** — ship the validated `set_subdomain_slug` SECURITY DEFINER RPC (the `guard_subdomain_slug` trigger from `20260603020000` validates but provides no publish seam). This is a prerequisite the storefront platform needs anyway.
2. **`wallet-domain-register` edge fn** (NEW, server-side, NOT client-callable), invoked from BOTH the slug-set RPC and the `is_published` flip in `src/services/storefrontConfig.ts` `upsert()` (and/or an `AFTER UPDATE OF is_published` trigger sibling to `validate_storefront_config`):
   - **Stripe:** `GET /v1/payment_method_domains` (list-before-create) → if absent `POST domain_name=<slug>.woahh.app` with the **platform live key, NO `Stripe-Account` header** (destination charges → platform registers) → assert `apple_pay.status=='active'`, else `POST …/validate` + alert. One registration covers Apple Pay + Google Pay + Link.
   - **Square** (only if `org.payment_provider==='square'`): `POST /v2/apple-pay/domains {domain_name}` → assert `VERIFIED`. **R4:** sandbox-verify the auth model first (per-seller OAuth vs platform); if a scope is needed add it to `SQUARE_OAUTH_SCOPES` now.
3. On slug rename: register the new host, `enabled=false` the old. Backfill existing published slugs before flipping wallets on.
4. **Store status** in `settings.payments.wallet_domain_status` so the dashboard shows "Apple Pay active ✓" and a wallet button never silently no-ops on an unregistered host — **gate the wallet UI on this status** + log when a wallet is requested on an unregistered host (makes the silent #1 failure mode observable).

### 2.6 `.well-known` Stripe-vs-Square resolution

- **Cloudflare Pages** serves one static bundle on apex + every subdomain; `public/_redirects` is a single `/* /index.html 200` SPA fallback that would shadow a missing `.well-known` path (returns HTML to Apple's verifier). There are NO Pages Functions today.
- **Phase 1 (Stripe-only):** ship NO file — Stripe registration is file-less. `public/_headers:22` already delegates `payment=(self "https://js.stripe.com")`, so the Stripe wallet iframe is permitted; CSP already allows `js.stripe.com` + Square hosts.
- **Phase 3 (Square go-live):** add a **host-aware Cloudflare Pages Function** at `/.well-known/apple-developer-merchantid-domain-association`: look up the host's org → return Square's file for Square orgs, Stripe's universal file otherwise (~30 lines). Add an explicit `/.well-known/*` passthrough above the SPA catch-all and `curl`-verify 200 + raw bytes + no-HTML on apex + one subdomain (and confirm Vite copies the dot-dir into `dist/`). For Square wallets, add the Square wallet origin to the `payment=` Permissions-Policy allow-list.

### 2.7 The settings gate (inherited, no new flag)

Wallets are an online-card capture, so they ride the SAME server-enforced gate the card path uses — `settings.payments.online_card_enabled === true` (default false, enforced in `stripe-payment-intent:90-106` / `square-payment:168-191`) AND `pay_mode !== 'venue'` AND not dine-in/owner-preview/demo. Mount the ECE/Square wallet behind exactly `showOnlinePay` (`RestaurantStorefront.tsx:732-740`) and the bespoke `world.onlineCardEnabled && paysByCardOnline`. No separate wallet flag — enabling online card enables wallets (subject to Stripe Dashboard wallet config + domain registration + Square wallet eligibility).

### 2.8 Amount-formula lock (R2 — do before enabling cards)

Extract `computeTotals` (`screens/Checkout.tsx`) into a shared helper; have `RestaurantStorefront` consume it so both surfaces store identical `orders.total_amount` (add the 1% service fee to the default path per the locked model). The wallet `paymentRequest`/`elements({amount})` MUST source from that same stored `total_amount`, never a client recompute. Separately reconcile `application_fee_amount: 0` with the 3%+1%→2%/2% model.

---

## 3. Founder / credential actions (only the founder can do these)

1. **Stripe Dashboard — enable wallets:** Settings → Payment methods → confirm Apple Pay + Google Pay are on (usually default-on for cards). No Apple Developer account needed — Stripe holds all Apple certificates.
2. **Register `woahh.app`** (Phase 1) with the **LIVE platform secret/restricted key, NO `Stripe-Account` header**: `POST /v1/payment_method_domains -d domain_name=woahh.app`; assert `apple_pay.status=='active'` (else `POST …/:id/validate`). Live-mode registration auto-propagates to sandboxes. A **restricted key** scoped to `payment_method_domains:write` is preferred for the automation env over the full live secret.
3. **Real-device Apple Pay live test** (cannot be done with Stripe test cards): a real card in a real Apple Wallet, in Safari, against **test API keys** — Stripe returns a successful test token, the card is never charged. Must be on a stable registered HTTPS host (`staging.woahh.app`, registered once), not a random `*.pages.dev` preview, not localhost.
4. **Verify the "Pay ▸" label** on test-bistro renders the merchant name (set via ECE `business.name`) vs the platform name — destination charges default to the platform name.
5. **Square (Phase 3 only, gated on AU go-live):** AU Square dev account + AU bank + PAAF PDS/FSG review (already on the Square go-live list); "Add Sandbox Domain" in the Square Developer Console for the Apple Pay sandbox test; confirm wallet pricing parity on the first sandbox→live statement.
6. **Two Stripe support tickets** (zero build impact, before scaling): (a) the ~99-domains-per-Apple-merchant-identifier ceiling vs a platform account (before merchant ~#50); (b) Google Pay Visa liability-shift classification for ECE.
7. **Rotate the leaked PAT** embedded in the `origin` remote URL (`ghp_…` visible via `git remote -v`) and re-set the remote without an inline credential — surfaced during this review.

---

## 4. Test plan

**Unit / integration (CI):**
- `computeTotals` parity: both storefront paths produce identical `total_amount` for a fixed cart (R2).
- Stripe parity: `elements.amount === PI.amount` and `elements.captureMethod === PI.capture_method` for an `awaiting_confirmation` order (manual) AND an auto-accept order (automatic) (R13/R17).
- Consent-before-authorize: the wallet path cannot reach `createPaymentIntent`/`tokenize` when `tosAccepted=false`; `recordConsentAndGetCustomerId` runs before any authorize (R14).
- Guest isolation: two sequential guest checkouts with different emails on one persisted session produce two `customers` rows; Guest A's receipt resolves to Guest A's snapshot email (R7).
- Square atomic claim: two concurrent `square-payment` invokes for one order → exactly one `CreatePayment` (R15/R16).
- C1 floor still rejects a tampered sub-floor total via the wallet path.

**Live sequence on test-bistro (real card in a real Wallet):**
1. Register the staging host; flip `online_card_enabled=true`, `pay_mode='online'` on test-bistro.
2. **Apple Pay (Safari, real card, TEST keys):** place a guest order → wallet sheet shows correct total + "Pay ▸ <merchant>" + line items → Face ID → order at `awaiting_confirmation`, PI `requires_capture`.
3. **Owner confirm** → `order-respond` captures → `payment_status=paid`; verify ONE combined confirmation+receipt email to the wallet-collected address.
4. **Decline/auto-decline:** place another → let the 7-min cron void → PI `canceled`; confirm the bank/Wallet app pending hold drops off in the following days; verify the decline email/OrderStatus shows the "pending hold disappears" copy (R20).
5. **Google Pay (Chrome, personal card):** repeat the place→confirm and place→decline cycles.
6. **Amount parity probe:** confirm the wallet-sheet amount equals `orders.total_amount` cents on a cart with a percentage promo (the x.xx5 boundary that previously diverged).
7. **Abandon:** open the wallet, dismiss without authorizing → confirm the unpaid order is voided on BOTH default (`voidUnpaidOrder`) and bespoke paths.
8. **Square (sandbox, Phase 3):** Apple Pay in Safari on the registered sandbox host (real card, not charged) → authorize→confirm→capture and authorize→cancel; verify `app_fee_money`/delayed-capture with a wallet token; double-tap to confirm no second authorization (R15).

---

## 5. Phased build order (smallest shippable increments)

- **Phase 0 — prerequisites (block wallets):** (a) branch off `origin/main` + fix CLAUDE.md (R1); (b) remove the live fake Apple/Google affordances — RetailStorefront radio first, then restaurant buttons (R10/R11); (c) Layer-A fresh-anon-session for guests + Layer-B `orders.customer_email` snapshot (R7); (d) lock the shared `computeTotals` so both surfaces store identical `total_amount` (R2).
- **Phase 1 — Stripe wallets on the apex (M, ~3–5 days):** extend `stripe-payment-intent` to return `amount`+`capture_method`; restructure `CardPaymentDialog` to deferred-intent ECE (gated by `canPlaceOrder` + `online_card_enabled`/`pay_mode`); register `woahh.app`; the existing card form stays as fallback. Lands on both checkout paths via the shared dialog. Add the decline "pending hold" copy (R20).
- **Phase 2 — subdomain automation (S, ~1–2 days):** ship `set_subdomain_slug` RPC; the `wallet-domain-register` edge fn (register-on-publish + disable-on-rename + backfill + `wallet_domain_status`), gating the wallet UI on registration status (R18/R5).
- **Phase 3 — Square parity (M, gated on Square AU go-live):** sandbox-verify `RegisterDomain` auth model + scopes (R4); add the atomic claim + idempotency-key fix + error-message allow-list to `square-payment` (R15/R16/R19); add `applePay`/`googlePay` in `SquarePayForm` (synchronous-tokenize + `verifyBuyer`); host-aware `.well-known` Pages Function; hoist `assertSquareBaseValid` into the shared module + `order-respond`/`refund-order` (R8); PENDING-at-confirm `authorizing` state + reconcile (R3).
- **Phase 4 — hardening/polish:** consent-claim COALESCE fix (R12); `resolveLocationId` membership check (R6b); delete `SQUARE_SINGLE_ORG_ID` pin (R6a); self-heal `square_payment_ready` on 401 (R9); analytics on `availablepaymentmethodschange`; Apple AUG prominence check; the two Stripe support tickets.

**Founder sign-off gate:** Phase 0 is mandatory before any wallet code (it removes a live compliance/PII exposure and locks the amount the wallet sheet must show). Phase 1 is the smallest real-value increment and is Stripe-only (the one live-capable wallet path). Square (Phase 3) stays blocked behind AU Square account + bank + PAAF regardless.