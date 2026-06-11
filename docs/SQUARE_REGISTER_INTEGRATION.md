# Square Register Integration — How Woahh Links to the Merchant's Big Square Screen

> **Audience:** Woahh founder. **Context:** first merchant (restaurant, Daisy Hill QLD) owns the big Square countertop device. Woahh already has the Square connector sandbox-built (per-org OAuth `square_connections`, Web Payments SDK → `CreatePayment(autocomplete:false)` → capture-on-confirm, RefundPayment, multi-location, GMV views). This doc answers: **what can we do with their hardware?**
> All claims AU-verified as of June 2026 unless marked ⚠️ UNVERIFIED. Sources in §6.

---

## 1. TL;DR

- **We can never put Woahh software ON a Square Register, and we can never drive it as a payment device.** No app store, no sideloading, no SDK, and Square staff explicitly confirm Terminal API works only with Square Terminal/Handheld — never Register. This is global policy, unchanged 2020→2026. ([forum 14086](https://developer.squareup.com/forums/t/does-square-allow-3rd-party-apps-to-run-on-square-register-yet/14086), [forum 25966](https://developer.squareup.com/forums/t/square-terminal-api-vs-square-register/25966))
- **The flagship integration absolutely exists and is GA in Australia: Orders API push.** A Woahh order with a PICKUP fulfillment that is paid (via our existing Square `CreatePayment`) **appears natively on the merchant's Register screen** in the Orders tab / Order Manager — staff mark In Progress → Ready → Picked up, kitchen tickets auto-print, Square KDS picks it up. **Zero fee when paid through Square** (which we already do). ([orders-api/what-it-does](https://developer.squareup.com/docs/orders-api/what-it-does))
- **The build delta is tiny:** wrap our existing `CreatePayment` in a `CreateOrder` (line items + PICKUP fulfillment + `source.name: "Woahh"`), pass `order_id` to `CreatePayment`, add `ORDERS_WRITE`/`ORDERS_READ` scopes. The docs even *require* `delay_capture` for fulfillment orders — matching our capture-on-confirm flow. Effort: **S (days)**.
- **Everything staff do on the Register flows back to us:** `order.fulfillment.updated`, `payment.*`, `refund.*` webhooks fire for Register-originated activity, with `SearchOrders`/`ListPayments` polling sweeps and the Payouts API for bank-level GMV reconciliation — all AU-available. Walk-in Register sales are cleanly separable from Woahh orders via `source`/`application_details.square_product = SQUARE_POS`, so our GMV views can show the merchant *everything*.
- **If the founder wants Woahh-initiated in-person checkout, the merchant buys a Square Terminal (or A$349 Handheld) to sit beside the Register** — Terminal API is GA in AU at 1.6% card-present, supports `app_fee_money` (our commission carries over, same PAAF PDS/FSG compliance gate we already have), and can show an itemised cart from a Square Order. The Register itself can never be that screen.

---

## 2. The Device Landscape — what the merchant actually owns

The "big iPad-lookalike with the big merchant screen" in AU in 2026 is one of two very different products:

### Square Register (most likely)
- Fully integrated dual-screen appliance: big seller display + **detachable customer EFTPOS display** (1 m cable). Built-in Square POS software. Accessory hub: 5× USB + Ethernet; Bluetooth for select printers; offline payments (24 h reconnect window). **1.6%** per tap/insert AU card-present.
- **1st gen:** sold in AU since March 2021. **2nd gen:** announced for AU 5 Feb 2026, **A$1,099** (or A$92/mo ×12), at Officeworks/JB Hi-Fi/Harvey Norman/The Good Guys/Costco from March 2026. Same dual-screen design; faster chipset, IP54, better Wi-Fi. ([AU press release](https://squareup.com/au/en/press/square-register-second-generation), [specs](https://squareup.com/au/en/hardware/register/specs))
- A Daisy Hill restaurant that bought before ~Feb 2026 almost certainly has the **1st-gen Register**. Integration surface is identical for both gens.
- **Closed appliance.** No third-party apps, no app store, no documented OS, no on-device SDK. All integration is server-side via Square's APIs; the Register is purely a display/fulfillment surface for data Square syncs down.

### iPad on Square Stand 2nd gen (the lookalike alternative)
- **A$149** dock with a **built-in contactless + chip&PIN reader** and USB hub; fits 10.9"/11" iPads; runs the free Square POS / Square for Restaurants app. ([squareup.com/au/en/hardware/stand](https://squareup.com/au/en/hardware/stand))
- Same server-side integration surface (it runs the same Square POS software, so Orders push etc. work identically), **but** because it's a real iPad it *can* run other apps — opening two extra doors that are shut on Register: **Mobile Payments SDK** (AU-available; a native Woahh iPad app driving the Stand's built-in reader) and **Point of Sale API** app-switch. Both require Woahh to ship a native app we don't have yet.

### How to tell them apart in 5 seconds
- **Register:** two permanently attached Square-branded screens, **no Apple logo anywhere**.
- **Stand:** a visible **iPad** swivelling in a white/black dock.

### Not it, but relevant
- **Square Terminal** (handheld-ish countertop card device with printer) and **Square Handheld** (A$349, AU launch July 2025) — these are the only devices the **Terminal API** can drive. Sold in AU. If we ever want Woahh to *initiate* an in-person charge on Square hardware, one of these gets added next to the Register.

> ⚠️ Note: the old **Reader SDK** is dead (retired 31 Dec 2025) — ignore any older material referencing it. Its successor, **Mobile Payments SDK**, is AU-available but native-app-only and never runs on Register.

---

## 3. Integration Options — RANKED

### Option 1 — Orders API push: Woahh orders appear on the Register ⭐ THE PLAY

**What the merchant experiences:** A customer orders on the Woahh storefront. Seconds later the order **pops up on their Register's Orders tab** (with a new-order notification chime, configurable), labelled **"Woahh"** as the source channel — exactly like a Square Online or Deliverect order. Staff tap In Progress → Ready → Picked up on the big screen; the kitchen ticket **auto-prints** on their existing kitchen printer; if they run Square KDS, it lands there too. They never touch a second tablet, never re-key an order. When they tap "Ready", **Woahh's own order tracker updates and the customer gets notified** (via the fulfillment webhook).

**What Woahh builds (on top of the existing connector):**
1. `CreateOrder` (Orders API): line items + a **PICKUP** fulfillment (`recipient.display_name`, `schedule_type: ASAP` + `prep_time_duration`, or `pickup_at`) + `source.name: "Woahh"` , at the merchant's `location_id`.
2. Pass the returned `order_id` into our **existing** `CreatePayment(autocomplete:false)` call. That's the whole payment-side delta — docs state fulfillment orders **must** have `delay_capture` set, which is literally our flow. ([how-it-works](https://developer.squareup.com/docs/orders-api/how-it-works))
3. Capture on owner-confirm exactly as today (or see §4 for the sequencing decision).
4. Subscribe to `order.fulfillment.updated` webhooks → mirror Register-side bumps (Ready/Completed) into Woahh's tracker + customer notifications.

**APIs + scopes:** Orders API (`ORDERS_WRITE`, `ORDERS_READ` — **new scopes, requires a re-consent pass** for the already-connected org), Payments API (`PAYMENTS_WRITE`/`PAYMENTS_READ` — already held), `MERCHANT_PROFILE_READ` (already held). Webhooks: `order.fulfillment.updated`, `order.updated`.

**AU availability:** ✅ GA. Square states the push rule verbatim ("Orders with fulfillment that have been fully paid are pushed to the Square Point of Sale and Square Dashboard Order Manager"); Orders API explicitly available in Australia; the Order Manager / Orders tab ships in the **free** Square POS app family (no paid plan needed) and is documented in the **AU help centre**; the Register 2nd-gen AU press release markets "fire kitchen tickets, organise online orders" on the device. AU production precedent at scale: **Deliverect, Mr Yum/me&u (direct Square integration, AU), DoorDash native (AU), Uber Eats native (AU rollout announced Apr 2026)** all use exactly this loop.

**No marketplace approval needed:** Square staff confirm an **unlisted/private production OAuth app can connect unlimited merchants with all production scopes** — no certification gate before pushing orders to a merchant's POS. (App Marketplace listing is optional marketing, and ironically requires 5+ active sellers *first*.) ([forum 25389](https://developer.squareup.com/forums/t/clarification-on-oauth-limits-for-unlisted-private-production-applications/25389))

**Fees impact on the locked 3%+1% model:** **None — if we keep charging through Square.** "There is no transaction fee for orders paid using Square payments." Our `app_fee_money` commission rides as today. **BUT:** pushing a **Stripe-paid** order costs a **1% Square Orders API fee per transaction** — that would eat half of Woahh's 2% take. Rule: **for this merchant, Woahh orders pay via the Square connector, full stop.** (Square AU online rate 2.2% CNP vs Stripe+1% is roughly a wash on raw cost, but the 1% comes out of the ecosystem we monetise — avoid.)

**Effort: S** (days — `CreateOrder` wrapper + scope addition + one webhook handler; we already have OAuth, payment flow, and webhook infrastructure).

**Risks / gotchas:**
- ⚠️ UNVERIFIED — **push timing vs our capture-on-confirm:** docs say the order surfaces "after it is charged" *and* that fulfillment orders must use delayed capture; whether the Register shows the order at **authorization** or only at **capture** is the #1 sandbox test (see §4 — both outcomes are workable, they just decide which surface "accepts" the order).
- **Use PICKUP fulfillments only for v1.** A reported Aug 2025 bug had DELIVERY-type API orders not showing in the POS list, and DELIVERY fulfillments are invisible to the seller **without a formal Square partnership agreement**. PICKUP is the battle-tested type (and fits pickup + dine-in collection).
- **No unpaid-order push.** We cannot inject an open tab for the cashier to settle on the Register. Payment (or at minimum a delayed-capture auth) must exist first. DRAFT orders never show.
- If our 7-minute auto-decline cron voids an authorized order *after* it has surfaced on the Register, we must cancel the Square fulfillment/order too, or a dead ticket sits on their screen.

---

### Option 2 — Sync-back: webhooks + polling + payouts (the data plane)

**What the merchant experiences:** Nothing new to learn — but Woahh's dashboard now shows their **whole business**: walk-in Register sales alongside Woahh online orders, refunds staff issued on the device, and bank-deposit-accurate net GMV. This is the "one dashboard" value prop made real on top of their existing hardware.

**What Woahh builds:**
- Webhook handlers: `payment.created/updated`, `refund.created/updated`, `order.created/updated`, `order.fulfillment.updated`. These fire for **Register-originated** activity, not just API objects. Verify HMAC (`x-square-hmacsha256-signature`), dedupe on `event_id`, guard ordering with `Order.version`.
- **Critical gotcha:** `order.updated` payloads are **sparse** (id/state/version only) — always follow with `RetrieveOrder` for line items/totals. Payment & Refund webhooks carry full objects.
- Polling backstop: `SearchOrders` (filters by `updated_at`, up to 10 locations/request, includes **all** sales "regardless of how… they entered the Square ecosystem (such as Point of Sale)") + `ListPayments` (`updated_at` window) on a per-org high-water mark. Required because webhooks are at-least-once, unordered, and **discarded permanently after 24 h of failed retries**.
- GMV attribution: Register walk-ins carry `Payment.application_details.square_product = SQUARE_POS` (use this, not `Order.source.name`, as the robust discriminator); Woahh orders carry our app/source — clean channel split, no heuristics, no double-counting (match on stored `order_id`).
- Money truth: nightly **Payouts API** (`ListPayoutEntries`: gross/fee/net per payment+refund) join — explicitly AU-supported (AU payout cutoff 12AM local documented).
- Register-side refunds: `PaymentRefund` carries `payment_id` → match to our order row, mark refunded idempotently (inverse of our existing RefundPayment path — handle both origins or we'll double-process). ⚠️ UNVERIFIED (minor): docs don't *explicitly* enumerate POS-initiated refunds firing `refund.created`; expected behaviour, confirm with one live Register refund.

**APIs + scopes:** `ORDERS_READ`, `PAYMENTS_READ` (held), Payouts API. Webhooks subscribed per-application in the Developer Console — events arrive for every OAuth'd merchant with `merchant_id` in the envelope, mapping 1:1 onto `square_connections`.

**AU availability:** ✅ All global platform infrastructure, no AU gating.
**Fees impact:** none (read-only).
**Effort: M** (1–2 weeks — handlers + sweep + reconciliation tables; reuses our payment-state machine discipline).
**Risks:** webhook-ops hygiene (24 h discard window means the sweep is not optional); rate limits unpublished (429 + backoff — keep sweeps coarse).

---

### Option 3 — Catalog sync (one-way push, Woahh → Square)

**What the merchant experiences:** Their Square item library matches their Woahh menu, so walk-ins rung up on the Register hit the **same items** Woahh sells online — per-item reporting unifies, Square inventory decrements, and kitchen-ticket/KDS **station routing works properly** (Square routes by item category — doc-backed, AU help centre).

**What Woahh builds:** `BatchUpsertCatalogObjects` push (idempotency key per write), store returned `catalog_object_id` per product/variation/location, reference them in pushed order line items (ad-hoc line items *do* render fine on pushed orders, but lose category/modifier fidelity for routing + reporting). Subscribe to `catalog.version.updated` (`ITEMS_READ`) as a **drift alarm** (payload is timestamp-only → pull deltas via `SearchCatalogObjects`). **Posture: one-way, Woahh = source of truth. Do not build bidirectional merge** — dual-source-of-truth conflict resolution is the classic failure mode here.

**APIs + scopes:** Catalog API (`ITEMS_READ`, `ITEMS_WRITE` — new scopes, same re-consent pass as Option 1).
**AU availability:** ✅ core AU POS feature.
**Fees impact:** none.
**Effort: M** (mapping table + sync job + drift handling; we already sync some catalog for the Square payments build).
**Risks:** merchant edits items on the Register → drift (alarm + re-push, accept eventual consistency); modifier-mapping fidelity worth a sandbox check.

---

### Option 4 — Add a Square Terminal/Handheld beside the Register (Terminal API)

**What the merchant experiences:** For in-person orders **initiated in Woahh** (e.g. phone orders typed into the Woahh dashboard, or a future Woahh counter mode), staff tap "Charge" in Woahh and the **Square Terminal next to the Register wakes up showing the itemised cart**; customer taps card; done. The Register keeps doing its normal job. One Square account, one settlement, one set of reports.

**What Woahh builds:** Devices API pairing (`CreateDeviceCode` → seller enters code on device → `device.code.paired` webhook → store `device_id` per location — maps directly onto `square_connections` + our per-location routing). Then `CreateTerminalCheckout` (`device_id`, `amount_money`, `deadline_duration` default PT5M, optional `order_id` + `show_itemized_cart: true` for the itemised screen — **GA in AU** per Square's dev blog, Terminal software ≥6.62) with `terminal.checkout.updated` webhooks + polling fallback. Persist `payment_ids` (checkout objects are deleted after 30 days; Payment is the permanent record). Our existing Terminal API stub is the right design.

**APIs + scopes:** Terminal API, Devices API — add `DEVICE_CREDENTIAL_MANAGEMENT` (+ `DEVICES_READ`) to the OAuth scope list; `PAYMENTS_WRITE_ADDITIONAL_RECIPIENTS` for `app_fee_money`.

**AU availability:** ✅ Terminal API GA in AU (region list now US/CA/UK/FR/IE/ES/AU/JP). Devices: Square Terminal (docs-listed) and Square Handheld (A$349 AU, staff-confirmed for Terminal API though not yet in the docs matrix). **The Register is excluded — everywhere, permanently as of today.**

**Fees impact:** Square AU card-present = **1.6% flat** (vs 2.2% online — cheaper). `app_fee_money` **is supported on Terminal checkouts for AU sellers** (Terminal API overview features table lists Application fees for AU; cap 90% of payment, 60% below a threshold; needs both platform + seller accounts approved for processing). This is how the locked in-person model (lower merchant fee, no customer service fee) gets collected. **Same PAAF PDS/FSG compliance gate** we already carry for online Square app fees — no new compliance category. ⚠️ UNVERIFIED (minor): run one AU-sandbox `CreateTerminalCheckout` with `app_fee_money` before relying on it.

**Effort: M** (pairing UI + checkout lifecycle + webhooks; stub exists). **Plus hardware cost to the merchant** (~A$329-class Terminal / A$349 Handheld — exact current AU Terminal price ⚠️ UNVERIFIED, check Square Shop AU).
**Risks:** merchant must buy a device (pitch: "your Register stays; this little one lets Woahh ring up sales too"); PAAF paperwork before live.

---

### Option 5 — Doshii / Deliverect hub (middleware, AU-native)

**What the merchant experiences:** Same end result as Option 1 (orders land on the Register), but via a paid AU middleman.

**What it is:** Doshii (AU, Westpac-incubated, Square AU co-markets it) and Deliverect both push third-party orders into Square POS; me&u/Mr Yum and HungryHungry reach Square this way. Woahh would integrate once with Doshii's Partner API (JWT location auth, WebSocket/webhook events, sandbox) and reach **every major AU POS** (Square, Lightspeed/Kounta, Impos, H&L, OrderMate…), not just Square.

**AU availability:** ✅ AU-native (Doshii) / AU-operating (Deliverect).
**Fees impact:** venue pays **from A$89/month** per app connection — clashes with our zero-commission founding pitch unless Woahh absorbs it.
**Effort: M** (one partner API integration).
**Verdict:** **Not for merchant #1** (we'd pay A$89/mo to avoid days of work we can do directly, and we lose the direct Square data plane that powers Options 2–3). **Keep on the shelf for merchant #2+ on a non-Square POS** — that's the real reason Doshii exists.

---

### Option 6 — Mobile Payments SDK (ONLY if the device turns out to be an iPad-on-Stand)

If the "Register" is actually an iPad in a Square Stand: the iPad can run other apps, and the **Mobile Payments SDK is AU-available** (US/CA/UK/AU) — a native Woahh iPad app could take card-present payments through the **Stand's built-in reader** (or a Square Reader), with `app_fee_money` (staff-confirmed for AU in-person). This is the only path that puts a **Woahh UI on the countertop device itself**.
**Effort: L** — requires the native app we haven't built (Capacitor pipeline is "later" in our roadmap). **Phase 4+ at best.** Irrelevant if it's a true Register.

### Option 7 — Point of Sale API app-switch (NOT recommended)

Same-device app-switch (`square-commerce-v1`) from a hypothetical Woahh iPad app into Square POS. **AU is officially supported** (docs list US/CA/UK/AU/IE/ES/FR/JP — earlier uncertainty resolved), but: **amount-only (no itemized sales), no sandbox, no invoices**, iPad-on-Stand only (never Register), needs a native app, and Square itself steers developers to Mobile Payments SDK instead. Weak fit for restaurant orders. Skip.

### ❌ Confirmed NOT possible (don't burn time here)
1. **Woahh software/UI on the Square Register** — no app store, no sideloading, ever (global, reconfirmed through 2026).
2. **Driving the Register via Terminal API** — staff-confirmed twice, no pairing path, no roadmap announcement exists.
3. **Pushing an unpaid open tab/cart** for the cashier to settle on the Register — paid + fulfillment are hard preconditions.
4. **Putting Woahh's cart on the Register's customer-facing display** — no API touches that screen (the itemised-cart display in Option 4 is on the *Terminal's* screen).

---

## 4. Recommended Path + Phased Rollout

**Strategy in one line:** the Register is not a platform, it's a *destination* — so feed it (Orders push), listen to it (webhooks/sync-back), and only add API-drivable hardware (Terminal) beside it when the merchant wants Woahh-initiated in-person checkout.

### Phase 0 — this week (½ day + one merchant visit)
1. Run the **30-second merchant checklist** (§5) — confirm Register vs Stand, plan, printers/KDS.
2. **AU sandbox spike (the load-bearing test):** `CreateOrder`(PICKUP, `source.name:"Woahh"`) → `CreatePayment(autocomplete:false, order_id)` → observe in the sandbox Dashboard/POS: **does the order surface at authorization, or only after capture?** This single answer picks sequencing A or B below. While there: test an `EXTERNAL`-tender payment push, and confirm a fulfillment-cancel removes the ticket.

### Phase 1 — this month: Orders push live (Option 1) — **Effort S**
- Add `ORDERS_WRITE`/`ORDERS_READ` (+ `ITEMS_*` now, to avoid a second re-consent later) to the OAuth scope list; re-consent flow for the connected org.
- `CreateOrder` wrapper around the existing payment call; PICKUP-only; `source.name: "Woahh"`.
- `order.fulfillment.updated` handler → Woahh tracker + customer notify.
- Auto-decline cron: on void, also cancel the Square fulfillment/order.

**How it composes with capture-on-confirm — two clean shapes (sandbox test decides):**
- **Shape A — order surfaces at authorization (the docs' delay-capture pattern):** order appears on the Register immediately at place-order; merchant can treat **either** the Register **or** Woahh as the accept surface; our capture-on-confirm fires as today; on decline/auto-decline we void + cancel the fulfillment so the ticket disappears. Most natural; Register staff see orders instantly.
- **Shape B — order surfaces only at capture:** Woahh remains the sole accept/decline surface (today's flow, unchanged); the moment the owner confirms (capture), the **already-accepted** ticket lands on the Register/kitchen printer as a pure fulfillment ticket. Slightly later kitchen visibility (≤ our 7-min confirm window), zero stale-ticket risk. Also perfectly fine.
- Either way: **Square-paid only** for this merchant (the 1% non-Square fee makes Stripe-paid push a non-starter), which also means flipping this org's `payment_provider` to `square` is a prerequisite — sequence it with the existing Square go-live gates (AU Square account, AU bank, PAAF PDS/FSG).

### Phase 2 — next: sync-back + GMV (Option 2) — **Effort M**
Payment/refund/order webhooks + the `SearchOrders`/`ListPayments` sweep + `SQUARE_POS` attribution → Woahh dashboard shows walk-in Register sales next to Woahh orders. This is the retention hook ("Woahh sees my whole shop"). Nightly Payouts reconciliation feeds fee-accurate net GMV (and our donation math).

### Phase 3 — soon after: catalog one-way push (Option 3) — **Effort M**
Unifies per-item reporting + fixes kitchen-station routing fidelity. Do after Phase 2 proves the data plane.

### Phase 4 — decision point: in-person (Option 4) — **Effort M + hardware + PAAF**
Only when the merchant asks for Woahh-initiated counter/phone-order charging: Square Terminal next to the Register, Devices pairing, `CreateTerminalCheckout` with `order_id` + itemised cart + `app_fee_money`. Gate: PAAF PDS/FSG review (already on our Square go-live list). Mobile Payments SDK / native app remains a later play and only matters for Stand-class hardware.

**Explicit non-goals:** Doshii/Deliverect for this merchant; POS API; anything that assumes code on the Register.

---

## 5. Open Questions to Confirm

### 30-second "ask the merchant" checklist
1. **"Is there an Apple logo on it, or does the screen swivel out of a dock?"** → iPad+Stand. **Two permanently attached Square screens, no Apple logo** → Register. (Bonus: photo of the front + the underside sticker/serial; Dashboard → Account & Settings → Hardware also lists it.)
2. **"Does the customer have their own little screen to tap their card on?"** → detachable customer display = Register.
3. **"Which Square app/plan?"** — free Square POS, or Square for Restaurants (Free/Plus)? (Order push works on all; Plus matters only for unlimited KDS.)
4. **"Kitchen printer and/or kitchen screen (KDS)?"** — tells us where pushed tickets will physically land, and whether the KDS "view online orders" toggle needs enabling.
5. **"Bought when?"** — pre-Feb-2026 = 1st-gen Register (no integration difference; just inventory).
6. **"Any other channels already feeding it?"** (Square Online, DoorDash, Deliverect/Doshii) — Woahh becomes another labelled source alongside them; good for the pitch.

### To verify in sandbox / with Square (⚠️ all currently UNVERIFIED)
- **Push timing:** does an `autocomplete:false` authorized order surface on POS at auth or at capture? (Decides Shape A vs B — the only design-affecting unknown.)
- **EXTERNAL-tender push:** does a `source_id=EXTERNAL` payment satisfy the push condition? (Only matters if we ever push Stripe-paid orders — currently ruled out.)
- **Register-initiated refunds → `refund.created` webhook:** expected, 5-minute live test on the merchant's device.
- **1% Orders-API fee invoicing mechanics for AU sellers** (only relevant to the Stripe-paid path): ask Square AU partner support.
- **`app_fee_money` on an AU `CreateTerminalCheckout`** (one sandbox call, Phase 4).
- **Current AU Square Terminal price** (Square Shop AU) before pitching Phase 4 hardware.
- **Modifier/category fidelity** of catalog-linked vs ad-hoc line items on printed kitchen tickets (Phase 3 sandbox check).

---

## 6. Sources

**Hardware / device landscape**
- https://squareup.com/au/en/hardware/register · https://squareup.com/au/en/hardware/register/specs
- https://squareup.com/au/en/press/square-register-second-generation
- https://squareup.com/au/en/townsquare/introducing-square-register-australia
- https://squareup.com/au/en/hardware/stand
- https://squareup.com/help/au/en/article/6257-compare-square-register-stand-and-terminal
- https://squareup.com/help/au/en/article/8597-set-up-square-register-2nd-generation
- https://www.officeworks.com.au/shop/officeworks/p/square-register-with-detachable-customer-display-pisqu012
- https://squareup.com/au/en/press/square-handheld-australia

**No-third-party-apps / no Terminal-API-on-Register**
- https://developer.squareup.com/forums/t/does-square-allow-3rd-party-apps-to-run-on-square-register-yet/14086
- https://developer.squareup.com/forums/t/can-a-custom-app-that-accesses-third-party-vendor-services-run-on-a-square-register/5895
- https://developer.squareup.com/forums/t/square-terminal-api-vs-square-register/25966
- https://developer.squareup.com/forums/t/terminal-api-to-square-register/8319
- https://squareup.com/help/ca/en/article/6259-square-register-supported-integrations
- https://developer.squareup.com/docs/in-person-payment-options
- https://developer.squareup.com/forums/t/action-required-reader-sdk-deprecation-and-retirement/20750
- https://developer.squareup.com/docs/mobile-payments-sdk

**Orders API push**
- https://developer.squareup.com/docs/orders-api/what-it-does · /create-orders · /how-it-works · /manage-orders · /fulfillments
- https://developer.squareup.com/forums/t/creation-of-order-for-pos-via-api/20857
- https://developer.squareup.com/reference/square/objects/OrderSource · /FulfillmentPickupDetails
- https://developer.squareup.com/blog/orders-push-public-beta/
- https://squareup.com/help/au/en/article/8454-manage-orders-with-square
- https://squareup.com/help/au/en/article/8322-set-up-order-manager-on-your-point-of-sale (also /us/ edition)
- https://squareup.com/help/au/en/article/6923-pickup-orders-on-square-point-of-sale
- https://squareup.com/help/au/en/article/6679-orders-in-square-pos-setup-guide
- https://squareup.com/help/au/en/article/6704-create-orders-with-square-apis
- https://squareup.com/us/en/press/orders-api
- https://community.squareup.com/t5/Your-Square-Account-Information/Order-Created-via-API-not-reflecting-on-Square-POS-Orders-List/td-p/806073

**Fees / external payments**
- https://developer.squareup.com/docs/payments-pricing
- https://squareup.com/au/en/payments/our-fees
- https://developer.squareup.com/docs/payments-api/take-payments/external-payments
- https://developer.squareup.com/docs/payments-api/take-payments-and-collect-fees

**KDS / routing**
- https://squareup.com/au/en/point-of-sale/restaurants/kitchen-display-system
- https://squareup.com/help/au/en/article/7959-route-orders-with-your-kds
- https://squareup.com/help/us/en/article/8170-filter-orders-by-category-with-square-kds
- https://squareup.com/help/gb/en/article/8282-configure-printer-profile-for-kitchen-routing
- https://squareup.com/help/us/en/article/8148-create-and-assign-item-categories-with-square-for-restaurants

**Terminal API / Devices / app fees**
- https://developer.squareup.com/docs/terminal-api/overview · /quickstart · /take-payments-for-orders
- https://developer.squareup.com/reference/square/devices-api · /devices-api/create-device-code
- https://developer.squareup.com/reference/square/terminal-api/create-terminal-checkout
- https://developer.squareup.com/reference/square/objects/TerminalCheckout
- https://developer.squareup.com/blog/build-with-square-terminal-api-now-generally-available/
- https://developer.squareup.com/blog/announcing-mobile-payments-sdk-ga-and-new-terminal-api-features/
- https://developer.squareup.com/forums/t/app-fee-money-in-au/24749
- https://developer.squareup.com/forums/t/issues-with-new-handheld-device-and-terminal-api/23733
- https://squareup.com/help/au/en/article/6849-square-terminal-api
- https://developer.squareup.com/forums/t/taking-an-itemized-order-with-a-terminal-in-uk/17961

**Webhooks / sync-back / reconciliation**
- https://developer.squareup.com/docs/webhooks/overview · /step3validate · /v2webhook-events-tech-ref
- https://developer.squareup.com/reference/square/orders-api/webhooks/order.updated
- https://developer.squareup.com/reference/square/orders-api/search-orders
- https://developer.squareup.com/reference/square/payments-api/list-payments
- https://developer.squareup.com/reference/square/objects/Order · /PaymentRefund
- https://developer.squareup.com/docs/payouts/overview
- https://developer.squareup.com/docs/build-basics/general-considerations/handling-errors
- https://developer.squareup.com/forums/t/the-source-field-of-an-pos-order-has-been-changed/7962

**Catalog**
- https://developer.squareup.com/docs/catalog-api/what-it-does · /webhooks

**Ecosystem precedent / partners (AU)**
- https://squareup.com/au/en/the-bottom-line/inside-square/mr-yum-integration-au
- https://squareup.com/help/au/en/article/7644-mr-yum-and-square
- https://doshii.com/en-au/square-pos-integration · /partner-with-doshii · /apps/meandu-integration · /apps/hungryhungry-integration
- https://squareup.com/help/au/en/article/7479-doshii-and-square
- https://support.doshii.com/developer-support/hc/en-us/articles/360018190353-getting-started-with-the-doshii-partner-api
- https://www.deliverect.com/en-au/integrations/square · https://help.deliverect.com/en/articles/9734245-square-settings
- https://squareup.com/help/au/en/article/7094-deliverect-and-square
- https://squareup.com/help/au/en/article/7148-manage-doordash-orders-with-square
- https://merchants.ubereats.com/au/en/resources/articles/product-highlights/square-integration-relaunch-may-2025/
- https://investor.uber.com/news-events/news/press-release-details/2026/Uber-and-Block-Expand-Global-Partnership-to-Transform-Restaurant-Operations-and-Launch-Cash-App-Pay-2026-m4qJ1JkXP3/default.aspx
- https://squareup.com/au/en/point-of-sale/restaurants/food-delivery-software

**Platform / OAuth / marketplace**
- https://developer.squareup.com/forums/t/clarification-on-oauth-limits-for-unlisted-private-production-applications/25389
- https://developer.squareup.com/docs/oauth-api/square-permissions
- https://developer.squareup.com/docs/app-marketplace/requirements · /faq · /requirements/orders-api (⚠️ some pages 404 mid-restructure)
- https://developer.squareup.com/docs/international-development
- https://developer.squareup.com/docs/pos-api/what-it-does · /how-it-works · /build-on-ios