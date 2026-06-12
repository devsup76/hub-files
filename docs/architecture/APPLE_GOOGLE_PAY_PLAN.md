# Apple Pay + Google Pay on Woahh Web Checkout — Implementation Plan

> Status: research complete (June 2026), all load-bearing claims fact-checked against official Stripe / Square / Apple / Google docs. Corrections from fact-check OVERRIDE earlier drafts. AU availability verified. Decision-ready.
> Audience: founder. Scope: web checkout on woahh.app + future `<slug>.woahh.app` subdomains, both payment providers.

---

## 1. TL;DR

- **Yes, and our capture-on-confirm flow survives 100% intact.** Apple Pay and Google Pay tokens process as **card payments** on both Stripe and Square. Stripe: manual capture explicitly supported for both wallets ("Manual capture support: Yes" on both wallet pages; Express Checkout Element has a first-class `captureMethod: 'manual'` option). Square: same `CreatePayment(autocomplete:false, app_fee_money)` call, just a different front-end token source — Square staff confirm delayed capture works with wallet tokens. Our authorize-at-checkout → owner-confirms → capture / 7-min-auto-decline → void logic needs **zero server-side changes**. ([stripe.com/apple-pay](https://docs.stripe.com/apple-pay?platform=web), [stripe.com/google-pay](https://docs.stripe.com/google-pay?platform=web))
- **Fully available in Australia, at zero extra cost.** Both wallets via Stripe: "worldwide except India," AUD settlement, priced identically to cards (1.7% + A$0.30 domestic). Neither Apple nor Google charges the merchant anything. Square AU: both wallets ✅ in the country matrix, 2.2% online rate (wallet parity implied, not explicitly stated). ([stripe.com/au/pricing](https://stripe.com/au/pricing), [Square country matrix](https://developer.squareup.com/docs/payment-card-support-by-country#digital-wallet-payments))
- **The customer experience:** tap the Apple Pay / Google Pay button → native wallet sheet shows the order total → Face ID / fingerprint → done. No card typing, no account needed — perfect fit with our guest checkout. Stripe's 2025 holdback experiment: offering Apple Pay = **+22.3% conversion, +22.5% revenue**. RBA says device wallets are now **~40% of ALL Australian card payments** (majority of under-50s). me&u and Bopple already ship Apple Pay — this is table stakes for AU restaurant ordering.
- **The one real engineering problem is domain registration for `<slug>.woahh.app`.** Every exact hostname that shows a wallet button must be individually registered with Stripe (and separately with Square, for Square orgs). **No wildcards exist anywhere in this space** — Stripe, Square, Apple, and Google all reject them. The fix is one API call per merchant, automated into slug provisioning. Stripe handles all Apple certificates for us; no Apple Developer account ever.
- **Recommended path:** Stripe **Express Checkout Element** on the apex first (S/M effort, ~3–5 days), then the register-on-publish subdomain hook, then Square parity when Square goes live. The existing card form stays as the always-present fallback.

---

## 2. How it actually works

### Apple Pay (via Stripe — our live provider)

1. **Page load:** the Express Checkout Element (ECE) silently checks: is this Safari (or iOS 16+ browser / supported Chromium config)? Does the device have a card in Apple Wallet? Is this exact hostname registered with Stripe? If any check fails, **the button simply doesn't render** — the customer sees only our existing card form. ([docs.stripe.com/elements/express-checkout-element](https://docs.stripe.com/elements/express-checkout-element))
2. **Customer taps the button:** the native Apple Pay sheet slides up showing the **total amount** (from the Elements `amount`) plus optional line items (items, service fee — we control these via `lineItems`), and a "Pay ▸ <name>" label. For destination charges the name derives from the **platform** Stripe account (i.e. Woahh) unless we set the ECE `business: { name: merchantName }` option per-merchant — **test the label on test-bistro before launch**.
3. **Customer authorizes with Face ID / Touch ID:** Apple's Secure Element returns a **network token (DPAN) + one-time cryptogram** — the merchant's real card number never touches our code or Stripe's servers as raw PAN. Stripe wraps it as a `payment_method` of `type: card` with a `wallet.apple_pay` sub-object.
4. **Certificates: nobody at Woahh touches any.** Stripe holds the Apple Merchant ID, the CSR, and the signing certificates: *"Stripe handles Apple merchant validation for you, including creating an Apple Merchant ID and Certificate Signing Request. Don't follow the merchant validation process in the Apple Pay documentation."* ([docs.stripe.com/apple-pay](https://docs.stripe.com/apple-pay?platform=web)) No Apple Developer Program membership for us or for any merchant.
5. **Authorization (our manual-capture flow):** we create the PaymentIntent server-side exactly as today — `capture_method: 'manual'`, `transfer_data[destination]`, `application_fee_amount` — and confirm it with the wallet payment method. The customer's bank places a normal pending hold at the authorized amount; it appears in the Wallet app / bank app as a **pending transaction** (issuer-dependent display).
6. **Capture (owner confirms the order):** our `order-respond` edge function captures as today. Customer sees the pending charge settle — no interaction, no notification difference vs a typed card. Visa/Mastercard/Amex CNP auth windows are ~7 days (Visa customer-initiated; the doc notes some flows are "4 days and 18 hours") — our 7-minute confirm window sits laughably far inside it. ([docs.stripe.com/payments/place-a-hold-on-a-payment-method](https://docs.stripe.com/payments/place-a-hold-on-a-payment-method))
7. **Void (decline / 7-min timeout):** we cancel the PaymentIntent; "the funds are released and the payment status changes to canceled." The pending entry lingers on the customer's statement until their bank drops it — typically hours to ~3 business days, occasionally up to 5+ (industry convention; Stripe officially only says some banks "take a bit longer"). **Action: add one line to the decline email/order-status page: "the pending hold will disappear from your statement within a few days."** Identical to our existing card manual-capture behaviour — no new support burden.

### Google Pay (via Stripe)

Same skeleton, different rails:

- Sheet comes from the customer's **Google account** — works in Chrome/Edge/Opera on any platform, plus Android browsers; the customer just needs a saved card, no app. Zero account friction for guest checkout.
- **Technical split:** Android devices return **DPAN (CRYPTOGRAM_3DS)** tokens — device-tokenized, liability-shifted by default. Desktop and iOS return **PAN_ONLY** tokens that need 3DS — **Stripe runs 3DS automatically**, invisible to us, but explains why some desktop Google Pay payments show a 3DS challenge. ([developers.google.com/pay/api/web/support/faq](https://developers.google.com/pay/api/web/support/faq))
- No certificates, no verification file, no Google-side registration when using Stripe.js/Elements — Stripe is the registered gateway and carries the Google relationship. Manual capture: "Yes". Refunds: "the same process as card payments" — our refund-on-tracker path is unchanged. ([docs.stripe.com/google-pay](https://docs.stripe.com/google-pay?platform=web))
- Capture/void customer experience: a normal pending card auth in their bank app; no separate Google Pay transaction feed dependency.

### Browser/device coverage (what % of customers see a button)

| Surface | Apple Pay | Google Pay |
|---|---|---|
| iPhone Safari (the AU restaurant-customer default) | ✅ | with `'always'` |
| iPhone Chrome/Firefox/Edge (iOS 16+) | ✅ (Stripe ECE) | ✅ iOS 16+ |
| Android Chrome | ❌ | ✅ (best case: DPAN) |
| Desktop Safari (macOS) | ✅ (Touch ID or paired iPhone/Watch) | with `'always'` |
| Desktop Chrome/Edge | macOS only, `applePay:'always'` (Stripe); Apple-level QR-handoff to iPhone exists since Feb 2025 but don't count on it per-PSP | ✅ |
| Firefox | ❌ Apple Pay | with `'always'` |

Square's documented matrix is narrower: **Apple Pay = Safari only** for the Web Payments SDK (don't assume Apple's newer third-party-browser support applies to Square until Square docs say so). Google Pay on Square: Chrome, Firefox, Safari, Edge, Opera. ([developer.squareup.com/docs/web-payments/apple-pay](https://developer.squareup.com/docs/web-payments/apple-pay))

Offering **both** wallets is mandatory to cover the iPhone-Safari + Android-Chrome split — one wallet alone covers roughly half of mobile devices.

---

## 3. Stripe implementation plan (primary path)

### Use the Express Checkout Element — not the Payment Request Button

The Payment Request Button is **officially legacy** ("Stripe no longer recommends using the Payment Request Button") with a published migration guide. ECE is one component that renders Apple Pay + Google Pay (+ Link etc.) buttons with automatic per-browser/per-wallet availability detection. ([docs.stripe.com/elements/express-checkout-element](https://docs.stripe.com/elements/express-checkout-element), [migration guide](https://docs.stripe.com/elements/express-checkout-element/migration))

### Code-level steps (deferred-intent pattern)

```js
// 1. Elements group carries amount/currency/capture mode
const elements = stripe.elements({
  mode: 'payment',
  amount: authoritativeTotalCents,   // MUST equal the server-side C1-recomputed total
  currency: 'aud',
  captureMethod: 'manual',           // ← our flow, first-class option
});

// 2. Mount the express buttons above the existing card form
const ece = elements.create('expressCheckout', {
  lineItems: [...],                         // items + service fee shown in the wallet sheet
  business: { name: merchantName },         // per-merchant "Pay ▸" label
  emailRequired: true,                      // wallet sheet collects receipt email (guest checkout)
  paymentMethods: { applePay: 'auto', googlePay: 'auto' },
});
ece.mount('#express-checkout');

// 3. On 'confirm' event: submit → create PI server-side → confirmPayment
ece.on('confirm', async (event) => {
  await elements.submit();
  const { clientSecret } = await createPaymentIntentEdgeFn(orderDraft); // existing stripe-payment-intent fn:
  // capture_method:'manual', transfer_data[destination], application_fee_amount — UNCHANGED
  await stripe.confirmPayment({ elements, clientSecret, confirmParams: { return_url } });
});

// 4. Hide the express section entirely when no wallet is available
ece.on('availablepaymentmethodschange', ({ availablePaymentMethods }) => { ... });
```

([docs.stripe.com/elements/express-checkout-element/accept-a-payment](https://docs.stripe.com/elements/express-checkout-element/accept-a-payment), [JS reference](https://docs.stripe.com/js/elements_object/create_express_checkout_element))

### Connect / destination-charge specifics — nothing changes

- Both wallet property tables: **"Connect support: Yes."** `application_fee_amount` / `transfer_data` live on the server-created PI which the wallet never sees.
- The Elements `captureMethod` must match the PI's `capture_method` (both `'manual'`), and the **Elements `amount` must equal the PI amount** — a mismatch hard-declines some methods and would show the customer one number while charging another.
- **C1 interlock (load-bearing):** the server-recomputed authoritative total (migration `20260608020000`) must be written into BOTH the Elements `amount` (via `elements.update({amount})` before confirm) and the PI. Our C1 floor check already rejects tampered totals — keep it; the ECE just needs the same number client-side so the wallet sheet is truthful.
- Guest checkout: Stripe's own ECE example creates the PI with only amount + currency — **no Customer object required**. The wallet supplies verified billing details; `emailRequired: true` gets us the receipt email from the sheet. The Supabase anonymous session is orthogonal — nothing changes.

### Dashboard/API setup

1. Enable Apple Pay + Google Pay in Dashboard → Payment methods (likely already on by default for cards).
2. Register `woahh.app` at Dashboard → Settings → [Payment method domains](https://dashboard.stripe.com/settings/payment_method_domains), or `POST /v1/payment_method_domains -d domain_name=woahh.app` with the **live platform secret key, no Stripe-Account header** (destination charges → platform registers, connected accounts never touch this). One registration covers Apple Pay, Google Pay, Link, PayPal, Klarna, Amazon Pay. **Live-mode registration auto-propagates to sandboxes** — no separate sandbox registration. ([docs.stripe.com/payments/payment-methods/pmd-registration](https://docs.stripe.com/payments/payment-methods/pmd-registration))
3. Assert `apple_pay.status == 'active'` in the response; if inactive, fix and `POST /v1/payment_method_domains/:id/validate`.
4. **No `.well-known` file is required for Stripe** (current docs contain zero mention of it; Stripe handles Apple merchant validation server-side). Hosting Stripe's universal file is optional belt-and-braces — but see §5 for the Square conflict at the same path.

### Effort: **M** (3–5 days)

- ECE wiring in both checkout surfaces (default `RestaurantStorefront` + bespoke `StorefrontRenderer` path): ~2 days.
- Edge-function touch (the existing `stripe-payment-intent` fn already does manual capture + destination + app fee; just ensure the deferred-intent handshake + amount parity): ~0.5 day.
- Apex domain registration + label/lineItems polish + fallback collapse: ~0.5 day.
- Live testing on test-bistro (real card in a real Wallet — see §7): ~1 day.
- `order-respond` capture/void: **zero changes**.

---

## 4. Square implementation plan (parity for Square merchants)

Square is sandbox-built, not yet live — wallets ride along when it ships.

### SDK methods

```js
const req = payments.paymentRequest({ countryCode: 'AU', currencyCode: 'AUD', total: {...} });
const googlePay = await payments.googlePay(req);  await googlePay.attach('#gpay-button');
const applePay  = await payments.applePay(req);   // render our own button (Apple HIG assets)
// Click handler: tokenize() MUST be called synchronously in the click — Safari user-gesture rule,
// no intervening awaits before tokenize() for Apple Pay.
const tokenResult = await applePay.tokenize();
// tokenResult.token → existing CreatePayment(source_id, autocomplete:false, app_fee_money) — UNCHANGED
```

Square: all Web Payments SDK tokens "share a common format" and the server-side Payments API code "works seamlessly for all the other methods" — our adapter's CreatePayment / CompletePayment / CancelPayment path is untouched. Square recommends adding `verifyBuyer()` SCA on wallet transactions to reduce declines. ([developer.squareup.com/docs/web-payments/digital-wallets](https://developer.squareup.com/docs/web-payments/digital-wallets))

### AU caveats + confirmations

- **AU availability: confirmed.** Country matrix: Australia row shows Apple Pay ✅ and Google Pay ✅ for digital wallet payments. ([payment-card-support-by-country](https://developer.squareup.com/docs/payment-card-support-by-country#digital-wallet-payments))
- **Delayed capture with wallet tokens: confirmed by Square staff** on the developer forum ("Apple Pay payments do allow for delay capture"), default 7-day CNP window, `delay_action` defaults to CANCEL (auto-void on expiry — our 7-min cron sits well inside). The formal delayed-capture doc is card-worded, so **re-verify in sandbox** (we've already sandbox-built the card path; this is a one-hour check). ([forum confirmation](https://developer.squareup.com/forums/t/apple-pay-web-sdk-with-auth-deferred-capture-with-different-amount/8560))
- **`app_fee_money` works in AU (PAAF)** — subject to the PAAF PDS/FSG review already on our Square go-live list; same `PAYMENTS_WRITE_ADDITIONAL_RECIPIENTS` scope we already use; fee caps 60%/90% around the A$8 threshold. Wallets aren't named separately because they process as card payments. ([take-payments-and-collect-fees](https://developer.squareup.com/docs/payments-api/take-payments-and-collect-fees))
- **Apple Pay domain registration (heavier than Stripe):** Square **requires** hosting its verification file at `/.well-known/apple-developer-merchantid-domain-association` on each domain (downloaded from Square; "subject to change… check for updates regularly"; "works only with Square as the domain"), then `POST /v2/apple-pay/domains` (RegisterDomain) per exact hostname → response `status: VERIFIED`. No wildcards ("Apple requires every domain to be validated"), but Square staff confirm **no limit** on registrations and the **same file works for all subdomains**. ([RegisterDomain](https://developer.squareup.com/reference/square/apple-pay-api/register-domain), [wildcard thread](https://developer.squareup.com/forums/t/can-we-add-the-wildcard-domain-for-apple-pay/10587))
- **Google Pay: near-zero ops** — no domain registration, no Google console, no file. HTTPS + brand-compliant button only. ([web-payments/google-pay](https://developer.squareup.com/docs/web-payments/google-pay))
- ⚠️ UNVERIFIED: whether RegisterDomain is called with each seller's per-org OAuth token (like our other Square calls) or once platform-wide — verify in sandbox before building the hook.

### Effort: **M** (≈1 week, but gated on Square AU go-live anyway)

Buttons + tokenize wiring (~2 days), `.well-known` serving decision (§5) (~1 day), RegisterDomain automation + sandbox dance (~1–2 days), testing (Apple Pay sandbox needs a deployed HTTPS host — see §7).

---

## 5. THE SUBDOMAIN PROBLEM: `<slug>.woahh.app` × wallet domain verification

This is the one place our architecture creates real work. The facts:

### Exact mechanics

- **Registration is per EXACT hostname. No wildcards. Anywhere.** `woahh.app` does NOT cover `cantina.woahh.app`. Stripe: "register all of your web domains that show an Apple Pay button… top-level domains… and subdomains…" (even `www` is called out). An Apple DTS engineer confirms wildcard/dynamic subdomains are rejected "due to domain ownership requirements" ([Apple forums thread 774591](https://developer.apple.com/forums/thread/774591)). Same rule at Square and in Google's own console. ([pmd-registration](https://docs.stripe.com/payments/payment-methods/pmd-registration), [Stripe support FAQ](https://support.stripe.com/questions/register-domains-for-payment-methods))
- **For our destination charges, all registrations live on the WOAHH platform account** — platform live secret key, omit the `Stripe-Account` header. Connected restaurants never touch domain registration. One registration per hostname covers all six express methods. Live-mode registration auto-covers sandboxes.
- **What breaks if we skip it:** the wallet buttons **silently don't render** on that subdomain (or Apple Pay fails at merchant validation). No error to the customer, no log — just a missing button and a merchant asking why their storefront has no Apple Pay. This is the documented #1 failure mode across the whole ecosystem (Shopify/Woo/SureCart threads all trace to "the exact host wasn't registered"). Card checkout keeps working, so it degrades gracefully — but the conversion lift evaporates exactly where we promised it.

### Automation plan: register-on-publish hook

This is precisely how Shopify/Wix/Squarespace do it — wallet enablement is a **platform** responsibility executed via PSP APIs at provisioning time; the merchant sees at most a toggle. ([Shopify: "automatically manages the domain verification process"](https://help.shopify.com/en/manual/payments/accelerated-checkouts/apple-pay))

1. **Hook point:** the same code path that sets/changes `subdomain_slug` (the planned `set_subdomain_slug` RPC / storefront-publish edge function). On publish:
   - `GET /v1/payment_method_domains` (list-before-create — "Don't register your domain more than once per account") → if absent, `POST /v1/payment_method_domains -d domain_name=<slug>.woahh.app` with the platform live key → assert `apple_pay.status == 'active'`, else `POST …/validate` and alert.
   - If the org's `payment_provider = 'square'`: also `POST /v2/apple-pay/domains {domain_name}` → assert `VERIFIED`.
2. **Slug change:** register the new hostname, `enabled=false` the old one (Stripe supports disable via update).
3. **Backfill script** for existing slugs before flipping wallets on. Throttle: Stripe live mode = 100 req/s global, ~25 req/s per endpoint — irrelevant at our merchant count, relevant if we ever bulk-migrate.
4. **Store the registration status on the org row** (e.g. `settings.payments.wallet_domain_status`) so the dashboard can show "Apple Pay active on your storefront ✓" and we can re-validate in a nightly job.

### `.well-known` serving on Cloudflare Pages

- One Pages project serves the **same static bundle on apex + every subdomain**, so a single file at `public/.well-known/apple-developer-merchantid-domain-association` is automatically live on every `<slug>.woahh.app` forever — zero per-merchant work.
- Empirically verified (2026-06-12): real static assets (robots.txt, manifest.json, llms.txt) win over our `/* /index.html 200` SPA rule on woahh.app **in practice**, despite Cloudflare docs claiming redirects always apply — but **today the `.well-known` path returns the SPA's index.html** because no file exists there. After adding any file: `curl` it and confirm 200 + raw bytes, no redirect, no HTML; also confirm Vite copies the dot-directory into `dist/` (check build output once).
- **The provider conflict:** Stripe no longer needs a hosted file (registration works file-less; Stripe's universal file is just belt-and-braces). Square **requires** Square's file, and Square's file "works only with Square." Resolution, in order of preference:
  1. **Now (Stripe-only):** ship nothing, register via API, confirm `apple_pay.status: active`. If Stripe validation ever complains, ship Stripe's universal file ([stripe.com/files/apple-pay/…](https://stripe.com/files/apple-pay/apple-developer-merchantid-domain-association), verified live: HTTP 200, 9,094 bytes, identical for all Stripe domains).
  2. **At Square go-live:** a tiny host-aware **Cloudflare Pages Function** at that one path: look up the host's org → return Square's file for Square orgs, Stripe's file otherwise. ~30 lines; also solves Square's "file may change" warning if it fetches/caches from Square periodically.

### Caps / limits

- Stripe documents **no cap** on registered domains. Apple's underlying PSP API has a **99-domains-per-merchant-identifier** limit; whether Stripe maps one Apple identifier per platform account (→ ~99-domain ceiling) or shards is ⚠️ UNVERIFIED — large Stripe platforms demonstrably exceed 99, suggesting sharding, but **ask Stripe support before merchant #50**. Square staff: "no limit." ([Apple RegisterMerchant](https://developer.apple.com/documentation/applepaywebmerchantregistrationapi/register-merchant))

---

## 6. Fees + business case

### Extra cost: none (verified)

| | Stripe AU | Square AU |
|---|---|---|
| Wallet surcharge | **A$0.00** — "no additional fees… pricing is the same as for other card transactions" (Apple Pay); "you pay only Stripe's processing fees" (Google Pay) | None listed anywhere — single 2.2% online rate, no wallet line item (parity implied, not explicit) |
| Underlying rate | 1.7% + A$0.30 domestic / 3.5% + A$0.30 international / +2% conversion — "Cards and wallets" is ONE pricing category | 2.2% online, no fixed cents; 1.6% in person |
| Apple's cut | $0 from merchants (Apple monetises card issuers) | $0 |
| Google's cut | $0 ("no fees for the Google Pay API") | $0 |

([stripe.com/au/pricing](https://stripe.com/au/pricing), [squareup.com/au/en/pricing](https://squareup.com/au/en/pricing)). One margin nuance: a tourist's foreign card inside Apple Pay still bills at the international rate — same as if typed. Our locked 3%+1% commission model is untouched: `application_fee_amount` / `app_fee_money` are provider-fee-independent.

### Conversion lift (the reason to do this)

- **Stripe holdback experiment (2025), 50+ payment methods:** businesses offering Apple Pay saw **+22.3% conversion and +22.5% revenue** on eligible checkouts. ([stripe.com/blog](https://stripe.com/blog/testing-the-conversion-impact-of-50-plus-global-payment-methods))
- Stripe-cited cases: Wish A/B — defaulting eligible users to Apple Pay = **2× conversion lift**; Indiegogo +250% after express checkout. ([best-practices](https://docs.stripe.com/apple-pay/best-practices)) (The circulating "58% faster checkout" figure is ⚠️ UNVERIFIED marketing shorthand — don't quote it.)
- Our context maximises the lift: **guest checkout, mobile, no saved card** — exactly the highest-friction segment wallets fix.

### AU adoption (RBA — the load-bearing local numbers)

- Device-based wallets = **~40% of all Australian card payments in 2025** (up from 31% in 2022); 43% of consumers tapped with a phone in the diary week; **majority of under-50s** use mobile wallets. ([RBA Bulletin May 2026](https://www.rba.gov.au/publications/bulletin/2026/may/consumer-payment-behaviour-in-australia.html))
- Industry submissions: ~**50% of card-present transactions** via mobile wallets by June 2025; ~520M wallet transactions / A$24.3B in a single month (Feb 2025).
- Competitors already ship it: **me&u is an official Apple Pay partner; Bopple's AU App Store listing advertises "integrated Apple Pay."** Our 16-row landing comparison table currently has a visible gap here.

For a young, mobile-ordering restaurant audience, the card-number form is now the *minority, higher-friction* path. This is plausibly the single highest-leverage conversion feature we can ship.

---

## 7. Phased rollout recommendation

**Where it sits in priorities:** after the current `feat/storefront-platform` stack ships and the first merchant is live — wallets multiply the value of online ordering but don't block it. Phase 1 is small enough to slot in immediately after.

### Phase 1 — Stripe wallets on the apex (M: ~3–5 days)
1. Register `woahh.app` (live key) → assert `apple_pay.status: active`. (5 minutes.)
2. ECE above the card form in both checkout paths; `captureMethod:'manual'`; C1 authoritative total wired into Elements `amount` + `lineItems`; `business.name` per merchant; `emailRequired:true`; collapse on `availablepaymentmethodschange`.
3. No `.well-known` file yet (Stripe doesn't need one).
4. Gate behind the existing per-merchant `settings.payments.online_card_enabled` flag — wallets are just another way to create the same PI.

### Phase 2 — subdomain automation (S: ~1–2 days)
5. Register-on-publish hook in the slug-provisioning path (+ disable-on-rename, + backfill script, + status on org row).
6. Per-subdomain smoke check using Stripe's wallet-rendering test page pattern ([docs.stripe.com/testing/wallets](https://docs.stripe.com/testing/wallets)).

### Phase 3 — Square parity (M, gated on Square AU go-live)
7. Host-aware Pages Function for `.well-known` (Square file for Square orgs); RegisterDomain in the same publish hook; ApplePay/GooglePay SDK buttons in the Square checkout branch; verify delayed-capture + `app_fee_money` with a wallet token in sandbox.

### Phase 4 — polish
8. Stripe support ticket: confirm ECE counts as "Stripe-hosted/Stripe.js" for automatic Google Pay Visa liability shift (likely yes — doc says "Stripe-hosted products and using Stripe.js" — but the carve-out wording is ambiguous; if not, one toggle in the Google Pay & Wallet Console).
9. Stripe support ticket: confirm no ~99-domain Apple ceiling per platform account.
10. Analytics on `availablepaymentmethodschange` (what % of checkouts see a wallet button) + wallet share of payments.
11. Apple AUG compliance check: once live, Apple Pay must have **equal or greater prominence** than other express options (fine — it'll be the top button), and never put a stored-balance/top-up layer in front of it (prohibited "staged wallet"; our PSP destination-charge model is a standard, compliant arrangement). ([Apple AUG](https://developer.apple.com/apple-pay/acceptable-use-guidelines-for-websites/))

### Testing realities (don't get surprised)

- **Apple Pay cannot be tested with Stripe test cards.** You must use a **real card in a real Apple Wallet** against **test API keys** — Stripe detects test mode and returns a successful test token; the card is never charged. ([docs.stripe.com/apple-pay](https://docs.stripe.com/apple-pay?platform=web))
- HTTPS mandatory even in dev; localhost won't show Apple Pay. Random `*.pages.dev` branch previews are impractical to register one-by-one — **test on a stable registered staging hostname** (e.g. `staging.woahh.app`, registered once) or ngrok-in-sandbox.
- Google Pay is easy: own personal card, even on localhost (Square) / any registered HTTPS host (Stripe).
- Square Apple Pay sandbox: separate "Add Sandbox Domain" in the Developer Console (dashboard, not API), real HTTPS host, Safari, real card in Wallet (not charged); Apple skips file verification in sandbox, so **production registration is the real test**.
- Founder live test on test-bistro: place a wallet order → owner confirm → check capture; place one → let the 7-min cron decline → confirm the hold drops off the bank app in the following days; verify the sheet's "Pay ▸" label and line items.

---

## 8. Open questions / ⚠️ UNVERIFIED items

1. ⚠️ **Apple's 99-domains-per-merchant-identifier limit vs a Stripe platform account** — undocumented mapping; likely sharded by Stripe (big platforms exceed it) but confirm with Stripe support before scaling past tens of merchant subdomains.
2. ⚠️ **Google Pay Visa liability shift classification for ECE** — current doc wording ("Stripe-hosted products and using Stripe.js") suggests automatic, but the "outside of a Stripe-hosted product" carve-out is ambiguous. One support ticket; zero build impact either way (payments work regardless; we'd only forgo some Visa DPAN fraud protection). Note: e-commerce tokens get neither liability shift nor 3DS.
3. ⚠️ **Square RegisterDomain auth model** — per-seller OAuth token vs platform-level call: not documented; verify in sandbox before building the Square hook.
4. ⚠️ **Square wallet pricing parity** — 2.2% AU online with no wallet line anywhere strongly implies parity, but no sentence says "wallets cost the same online." Low risk; confirm on first sandbox→live statement.
5. ⚠️ **Square delayed capture + `app_fee_money` on a wallet token** — staff-forum-confirmed + processes-as-card logic, but formally card-worded docs; one sandbox transaction closes it.
6. ⚠️ **Cloudflare Pages static-asset vs `_redirects` precedence** — observed behaviour (assets win) contradicts the docs' letter; after adding any `.well-known` file, curl-verify 200/raw-bytes/no-HTML on apex + one subdomain, and re-verify after deploy-pipeline changes. Also confirm Vite copies `public/.well-known/` into `dist/`.
7. **Wallet sheet "Pay ▸" label on destination charges** — derives from the platform account unless `business.name` is set; verify the per-merchant override renders correctly on test-bistro.
8. **"58% faster checkout with Apple Pay"** — circulating attribution to Stripe not found on any fetched official page; do not use in marketing.
9. **Decision:** when Square ships, build the host-aware `.well-known` Pages Function (recommended) vs static-Square-file-plus-hope (only viable if Stripe registration stays file-less, which it currently is).

---

## 9. Sources

**Stripe (official docs):**
- https://docs.stripe.com/apple-pay?platform=web — availability (worldwide except India), Connect: Yes, Manual capture: Yes, no extra fees, Stripe handles Apple merchant validation, domain rules, real-card testing
- https://docs.stripe.com/google-pay?platform=web — same property table for Google Pay, liability-shift section, no Google-side registration
- https://docs.stripe.com/elements/express-checkout-element + /accept-a-payment + /migration — ECE component, `captureMethod:'manual'`, browser matrix, PRB legacy status
- https://docs.stripe.com/js/elements_object/create_express_checkout_element — `paymentMethods`, `business.name`, `lineItems`, `emailRequired`
- https://docs.stripe.com/payments/payment-methods/pmd-registration — domain registration incl. Connect destination-vs-direct rules, live→sandbox propagation
- https://docs.stripe.com/api/payment_method_domains (+ /object, /validate) — API endpoints + per-wallet status
- https://docs.stripe.com/payments/place-a-hold-on-a-payment-method — auth windows, cancel/release behaviour, partial capture
- https://stripe.com/au/pricing + https://stripe.com/pricing/local-payment-methods — AU rates, cards-and-wallets one category
- https://docs.stripe.com/testing/wallets — wallet-rendering test page
- https://docs.stripe.com/apple-pay/best-practices + https://stripe.com/blog/testing-the-conversion-impact-of-50-plus-global-payment-methods — conversion data
- https://support.stripe.com/questions/using-authorization-and-capture-with-apple-pay ; https://support.stripe.com/questions/register-domains-for-payment-methods ; https://support.stripe.com/questions/liability-shift-for-google-pay-charges
- https://stripe.com/files/apple-pay/apple-developer-merchantid-domain-association — universal association file (live-verified 2026-06-12, HTTP 200, 9,094 bytes)

**Square (official docs + staff forum):**
- https://developer.squareup.com/docs/web-payments/apple-pay ; /google-pay ; /digital-wallets ; /overview — SDK methods, browser matrices, sandbox rules, common token format
- https://developer.squareup.com/docs/payment-card-support-by-country#digital-wallet-payments — AU row: Apple Pay ✅ Google Pay ✅
- https://developer.squareup.com/reference/square/apple-pay-api/register-domain — RegisterDomain
- https://developer.squareup.com/docs/payments-api/take-payments/card-payments/delayed-capture ; /take-payments-and-collect-fees — 7-day CNP window, PAAF/app-fee rules
- https://developer.squareup.com/forums/t/apple-pay-web-sdk-with-auth-deferred-capture-with-different-amount/8560 ; https://developer.squareup.com/forums/t/can-we-add-the-wildcard-domain-for-apple-pay/10587 — staff confirmations (delayed capture; no wildcards / no limit / shared file)
- https://squareup.com/au/en/pricing ; https://developer.squareup.com/docs/payments-pricing — AU 2.2% online

**Apple / Google (official):**
- https://developer.apple.com/documentation/applepaywebmerchantregistrationapi (+ /register-merchant, /preparing-merchant-domains-for-verification) — PSP-level machinery, 99-domain limit, per-pspId file
- https://developer.apple.com/forums/thread/774591 — Apple DTS: no wildcard domains
- https://developer.apple.com/apple-pay/acceptable-use-guidelines-for-websites/ — prominence rule, staged-wallet prohibition
- https://support.apple.com/guide/safari/apple-pay-in-third-party-browsers-ibrw9b779bd3/mac ; https://support.apple.com/en-us/118269 ; https://support.apple.com/en-us/104954 — third-party browsers, AU dual-network debit, pending-transaction behaviour
- https://developers.google.com/pay/api/web/support/faq — DPAN vs PAN_ONLY split; https://developers.google.com/pay/api/web/guides/resources/shift-liability-to-issuer ; https://support.google.com/console/answer/10914884 — direct-integration console rules (not needed via Stripe); https://support.google.com/wallet/answer/12059326?co=GENIE.CountryCode%3DAU — AU card support

**AU adoption + market:**
- https://www.rba.gov.au/publications/bulletin/2026/may/consumer-payment-behaviour-in-australia.html — ~40% of card payments device-based (2025)
- https://www.ausbanking.org.au/wp-content/uploads/2025/09/ABA-submission-RBA-Proposals-Paper-submitted.pdf — ~50% of card-present via wallets
- https://www.meandu.com/us/partners/apple-pay ; https://apps.apple.com/au/app/bopple-order-local-takeaway/id641698016 — AU competitor precedent

**Platform precedent:**
- https://help.shopify.com/en/manual/payments/accelerated-checkouts/apple-pay ; https://support.squarespace.com/hc/en-us/articles/37109872867341 ; https://support.wix.com/en/article/wix-stores-customer-checkout-with-apple-pay

**Cloudflare:**
- https://developers.cloudflare.com/pages/configuration/redirects/ ; https://developers.cloudflare.com/pages/configuration/serving-pages/ — plus live curl checks of woahh.app static-asset serving (2026-06-12)