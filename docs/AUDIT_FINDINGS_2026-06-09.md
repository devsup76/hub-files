# Woahh Storefront-Platform Audit — Consolidated Findings Register

**Date:** 2026-06-09
**Branch:** `feat/storefront-platform` @ `a9aef21` (worktree `repo-audit`)
**Lenses merged:** (1) Storefront + Ordering, (2) Order/Payment State Machine, (3) Multi-Tenant Isolation/Scale, (4) Square Integration, (5) Templates/Preview Robustness.
**Status:** read-only audit; nothing deployed. Square is sandbox-first, not live. Stripe Connect IS live-activated (per CLAUDE.md), so the payment-state-machine BLOCKERs gate real cards **today**.

This register is **deduped** — several lenses independently found the same root defects (notably: bespoke storefront drops the ingredient-availability safety layer; bespoke checkout invents fees/fulfillment; org-RPC denylist anti-pattern; order-respond confirm/decline/cron race; Square single-token + idempotency). Each merged finding lists every lens that saw it and every implicated file.

Verification note: I read the actual files for the highest-severity items (order-respond final write has no status guard — `order-respond/index.ts:262-263`; Square idempotency key is order-id-only — `square-payment/index.ts:233`; `SectionProduct` type carries no availability fields; `AddToCartButton` at `ProductView.tsx:137` prices base-only while the cart bills extras; `cantina` is in client `TEMPLATES` but absent from the DB CHECK and from `RESTAURANT_TEMPLATE_ORDER`; org RPC `RETURNS public.organizations` with a hardcoded denylist that omits the Square columns). Those are HIGH-confidence. Items I did not independently re-run (e.g. the exact Overlay focus race, the deadlock-ordering, multi-location Square behavior) are marked MEDIUM/LOW confidence inline.

---

## FIX PLAN (what to do tonight vs. what needs founder/deploy/decision)

### Fix tonight — low-risk, local, no infra/no decision
These are self-contained client/server edits that reduce real customer-facing harm and can't make things worse:

- **B1-STORE** (sold-out blindness in bespoke storefront) — extend `SectionProduct`, map availability, fetch `ingredient_shortages`, re-check at the bridge. Mirrors shipped default-storefront logic. Local, additive.
- **B1-TMPL** (add-to-cart button under-quotes priced extras) — make the button price include selected extras (extract `unitPriceWithExtras` to `pricing.ts`). Pure UI math fix. **Do this first — it's a money/trust defect with a one-function fix.**
- **H1-STORE** (bespoke checkout offers disabled fulfillment methods + invented $4.99 delivery) — thread `enabledFulfillments` from merchant settings; filter `FULFILLMENTS`. Local.
- **H1-TMPL** (3 divergent `effectivePrice` defs) — delete the per-home helpers, import canonical `pricing.ts`. Mechanical refactor.
- **H2-STORE / M5-STORE** (empty-cart submit + post-nav re-validation) — add `canPlaceOrder(world, form)` guard in `usePlaceOrder`. Local.
- **H3-STORE / H4-STORE** (name/phone sanitisation + real phone-shape validation before SMS consent) — local validation. Spam-Act-adjacent; cheap.
- **H2-TMPL** (cantina orphaned in picker) — add `"cantina"` to `RESTAURANT_TEMPLATE_ORDER` *only if* M1-SCALE (DB CHECK) is fixed in the same change; otherwise leave a code comment + parity test, because making it pickable without the migration causes a save error (see decision item).
- **M1/M2/M3/M4-STORE** (qty cap, slot disambiguation, cancel-vs-paid copy) — local UI guards.
- **M3-SCALE** (tenant `SLUG_RE` length 63 → 40 to match DB) — one regex edit + extend `tenant.test.ts`.
- **L-tier** items across lenses — low-risk polish, batch opportunistically.

### Needs deploy coordination (server/edge/migration) — low decision risk but must be run by owner
- **B1/B2-PAY** (order-respond confirm/decline/cron race → double-charge / uncaptured-cook) — requires a new SECURITY DEFINER RPC + edge-fn rewrite (claim-before-capture) **and** the cron migration changed to claim-in-SQL. This is the **single most important fix before taking real Stripe cards.** Code is local but it touches an edge function + a migration the owner must apply.
- **H2-PAY** (provider chosen from org flag not order row) — 1-line server fix in `order-respond` (`derive provider from order.square_payment_id ?? stripe_payment_intent_id`). Low risk; deploy with B1/B2-PAY.
- **H4-PAY** (auto-decline cron has no idempotency + no lower-bound) — fold into the B1/B2-PAY claim-in-SQL cron rewrite.
- **H1-SCALE / H2-SCALE / M2-SCALE** (org/order RPC denylist omits Square columns → leaks `square_merchant_id`/`square_location_id` + financial counters to anon/staff) — migration adding `:= NULL` masks now; allowlist refactor later. Run the masking migration tonight if owner is available; it's additive and safe.
- **M1-SCALE** (cantina not in DB template CHECK → save throws) — additive migration extending the CHECK. Pairs with H2-TMPL.

### Needs founder DECISION or is GATED (do NOT just fix)
- **B2-PAY/B1-SCALE/B2-SQ** (single global `SQUARE_ACCESS_TOKEN` routes all Square merchants' money to ONE account) — architectural: requires the `square_connections` per-org OAuth model OR a hard single-tenant guard. **Decision:** Square must stay one-sandbox-merchant until this is built. The mitigation tonight is a guard that refuses a 2nd `square_payment_ready` org — that's a code fix but it encodes a product decision, so flag it.
- **H3-SQ** (Square OAuth 30-day token expiry, no refresh) — hard go-live blocker; documentation/decision, not a tonight fix.
- **M4-SQ** (`appFeeAmount = 0` for ALL Square merchants → breaks the 2%/2% charity model) — must be reconciled with the locked financial model before any non-founding Square merchant; ties to the OAuth model. Decision + later code.
- **H3-SCALE** (owner can self-set `square_payment_ready`/`payment_provider` — no WITH CHECK) — needs a trigger or a `payment_connections` table; security boundary decision. Stage for review.
- **H1-PAY** (inventory decremented at order-create, money captured later, no stock-release on payment failure → inventory-DoS) — needs a stock-release path + anon rate-limit; design decision on where to release. Stage.
- **M5-PAY** (no refund path anywhere; decline email promises refunds) — needs a new `refund-order` edge function; product/ops decision. Stage.
- **B1-SQ / H3-SQ-amount / H3-PAY** (Square idempotency keyed on order-id only → re-charges old amount; amount can drift between authorize and capture) — Square fix is local-ish (key on order+amount) but **must be tested on deploy** with a real amount-change flow; treat as deploy-gated.

### Honest confidence summary
- HIGH confidence (code-verified this session): B1-STORE, B1-TMPL, H1-STORE, H1-TMPL, H2-TMPL, M1-SCALE, M3-SCALE, B1/B2-PAY race, H2-PAY, H1/H2/M2-SCALE denylist, B1-SQ idempotency, B2-PAY/SQ single token, M4-SQ appfee.
- MEDIUM confidence (logic-derived from lens reports, not re-executed): H3-STORE/H4-STORE validation gaps, M-tier storefront guards, H3-STORE Overlay focus race, H1-PAY inventory-DoS, L1-SCALE deadlock, Square multi-location/webhook-URL behaviors.
- The payment-state-machine BLOCKERs assume Stripe Connect is genuinely live (per CLAUDE.md). If real cards are NOT yet flowing, B1/B2-PAY drop to HIGH-but-not-emergency.

---

## BLOCKER

### BLK-1 — order-respond confirm / decline / auto-decline-cron are NOT mutually exclusive → double-charge a declined order, or cook-but-never-capture
- **Lenses:** Payments (B1, B2)
- **Area:** Order/payment state machine
- **File:** `supabase/functions/order-respond/index.ts:113` (status read) vs `:262-263` (final `update(...).eq("id", order.id)` — **no `.eq("status","awaiting_confirmation")` guard**, verified); cron `supabase/migrations/20260422122034_98783421-...sql:26-41`
- **Scenario (bad):** Order at minute 7. Per-minute cron fires `auto_decline` while owner clicks Confirm. Both pass the line-113 read; both run provider capture/cancel; both write unconditionally. Outcomes: customer charged for a kitchen-rejected order (`payment_status='paid'` + `status='declined'`, decline email already sent), or `status='pending'` + PI canceled at Stripe (kitchen cooks, merchant never paid). Same on Square (`CompletePayment` vs `CancelPayment`).
- **Impact:** Double-charge / silent uncaptured authorizations. Only remediation today is a manual refund (the decline email literally promises one). This is the top blocker before real cards.
- **Fix:** Claim-before-capture. Conditional write FIRST: `UPDATE orders SET status=<new> WHERE id=$1 AND status='awaiting_confirmation' RETURNING *`; if 0 rows, return 200 idempotently and do NOT call capture/cancel — only the claim winner touches the provider. Best: a SECURITY DEFINER `respond_to_order(order_id, action)` RPC doing the flip in one statement (also fixes the `email_used_this_month` read-modify-write lost-update at `:300`).
- **Confidence:** HIGH (final write has no status guard — verified).

### BLK-2 — Single global `SQUARE_ACCESS_TOKEN` routes EVERY Square merchant's funds to ONE account
- **Lenses:** Scale (B1), Square (B2), Payments (referenced)
- **Area:** Multi-tenant payments
- **File:** `supabase/functions/square-payment/index.ts:103` (single env token) + `:74-97` (`resolveLocationId` caches that one account's location onto each org), `supabase/functions/order-respond/index.ts:179`, migration `20260609020000_square_payments.sql:18-23` (documents single-sandbox, OAuth out of scope)
- **Scenario (bad):** Operator flips a 2nd org to `square_payment_ready=true`. `ListLocations` runs with the single global token → returns merchant #1's locations → caches #1's `location_id` onto #2's org row → #2's customers' cards charge into #1's Square account. No org↔token binding; the cached location makes it permanent and silent.
- **Impact:** Cross-tenant fund-routing leak; AFSL/PCI problem; impossible reconciliation. Money to the wrong merchant.
- **Fix:** Build the planned per-org `square_connections` (access/refresh token + merchant_id + location_id) and look up by `order.organization_id`, fail-closed if absent. Until then, hard-guard: refuse if >1 org has `square_payment_ready=true`, or pin to a single allow-listed `organization_id` env. **Gated — encodes the "Square stays one sandbox merchant" product decision.**
- **Confidence:** HIGH (single env token verified).

### BLK-3 — Bespoke storefront has NO sold-out / required-ingredient hard-block → un-makeable dishes are orderable (and payable)
- **Lenses:** Storefront (B1)
- **Area:** Bespoke ThemeShell ordering path
- **File:** `src/components/storefront/sections/types.ts` (`SectionProduct` omits `is_available`/`stock_quantity`/`ingredients`/`required_ingredients` — verified absent), `src/components/storefront/liveStorefrontData.ts:83-109` (`productToSectionProduct` never maps them), `src/components/storefront/PublishedStorefront.tsx:220-344` (bridge has no `blockedLine` guard), `src/components/storefront/screens/ProductView.tsx:181` (every `add()` ungated)
- **Scenario (bad):** Merchant 86's a required ingredient (writes `ingredient_shortages`). The default `RestaurantStorefront` marks the dish "Temporarily sold out", disables Add, re-checks at checkout (`RestaurantStorefront.tsx:533-540`). The bespoke storefront lets the customer add it, check out, and pay by card; the kitchen gets a ticket it physically cannot make and the card is authorized.
- **Impact:** Customer charged for a dish that can't be made; the entire shipped `feat/ingredient-availability` safety layer is bypassed on the new storefront. Also never emits `removed_ingredients`, so soft-shortage "made without X" never reaches the kitchen.
- **Fix:** Extend `SectionProduct` with `ingredients?`/`requiredIngredients?`; map in `productToSectionProduct`; fetch `ingredientShortageApi.listPublic(org.id)` in `LiveStorefrontStage` (poll + focus-refetch like the default); compute `isBlocked`/`ingredientsOutFor`; disable Add + mark "Temporarily sold out"; re-check `blockedLine` in the bridge before `orderApi.createTest`; emit `removed_ingredients`. Mirror `RestaurantStorefront.tsx:179-209,533-549`.
- **Confidence:** HIGH (type lacks the fields — verified).

### BLK-4 — Add-to-cart button price EXCLUDES priced extras, but the cart BILLS them → customer sees one price, is charged another
- **Lenses:** Templates (B1)
- **Area:** Bespoke product view / cart
- **File:** `src/components/storefront/screens/ProductView.tsx:137,150` (`AddToCartButton` uses `priceState(product).current` base-only — verified) vs `src/components/storefront/chrome/useLiveCart.ts:70-78,114-122` (`unitPriceWithExtras` folds extras into the cart line)
- **Scenario (bad):** Product has "+ Extra cheese $2.00". Customer toggles it; button reads "Add to cart · $14"; cart, checkout, and order all charge $16. Button under-quotes by the extras delta on every product with priced extras.
- **Impact:** Direct money/trust defect; chargeback bait ("the button said $14").
- **Fix:** Make the button price include selected extras. Best: extract `unitPriceWithExtras` from `useLiveCart` into `screens/pricing.ts` and have both the button and the cart call it (single source of truth). **Fix this first — one function, high harm.**
- **Confidence:** HIGH (both code paths verified).

---

## HIGH

### H-1 — order-respond picks the capture adapter from the org's CURRENT `payment_provider`, not the provider that authorized the order
- **Lenses:** Payments (H2)
- **File:** `supabase/functions/order-respond/index.ts:173` (`const provider = org.payment_provider ?? "stripe"`)
- **Scenario (bad):** Merchant on Stripe takes 3 card orders at `awaiting_confirmation`, then flips to Square to test. Confirming the 3 Stripe orders runs the Square branch; `sqPaymentId` is null; capture silently no-ops; the Stripe holds expire uncaptured (~7 days). Merchant cooks, never paid; customer's pending charge vanishes.
- **Impact:** Uncaptured authorizations on any provider switch with in-flight orders.
- **Fix:** Derive provider from the order row: `order.square_payment_id ? "square" : order.stripe_payment_intent_id ? "stripe" : org.payment_provider`. The authorization id is the source of truth.
- **Confidence:** HIGH (provider read from org flag verified). Deploy with BLK-1.

### H-2 — Auto-accept (`status='pending'`) card orders capture money before inventory re-validation; payment failure never releases stock → inventory-DoS
- **Lenses:** Payments (H1)
- **File:** `supabase/functions/stripe-payment-intent/index.ts:116`, `supabase/functions/square-payment/index.ts:221-227`, migration `20260608020000_c1_server_side_order_total.sql` (decrements stock in the RPC; no compensating release), `src/services/guestCheckout.ts` (anon sessions)
- **Scenario (bad):** Last unit. Guest A's order creates the row (stock→0), card declines at confirm; stock stays 0, order `unpaid`. Guest B can't order though nobody paid. A bot mints anon sessions and places max-qty unpaid orders, zeroing every stocked item.
- **Impact:** Free inventory-DoS; legitimate customers blocked; stock/money desync.
- **Fix:** Prefer manual capture always (even auto-accept) and decrement committed stock at capture; OR add a stock-release path on `payment_intent.payment_failed`/Square `FAILED`/`CANCELED` (idempotent) + a short-TTL cron releasing stock for `unpaid` card orders. At minimum rate-limit anon order creation per IP/device. **Stage — needs design decision on where to release.**
- **Confidence:** MEDIUM-HIGH.

### H-3 — Square `idempotency_key` is order-id-only → an amount change re-charges the OLD amount; amount can drift between authorize and capture
- **Lenses:** Square (B1), Payments (H3), Scale (H4-adjacent)
- **File:** `supabase/functions/square-payment/index.ts:233` (`idempotency_key: sq-pay-${order.id}` — verified) + resume guard `:195-210`; parallel Stripe gap `stripe-payment-intent/index.ts:104-110`
- **Scenario (bad):** Customer authorizes, then a promo drops the total. Retry sends the same idempotency key → Square replays the original (higher) payment, ignoring the new `amount_money` → customer charged the old amount. At capture, `order-respond` captures the full authorized hold (defaults), so authorize/capture amounts can diverge from `orders.total_amount`.
- **Impact:** Silent mischarge (Square's idempotency semantics differ from Stripe's per-PI model).
- **Fix:** Key on `order.id`+`amountCents`; before reusing, compare the live authorization's amount to the current total — if different, cancel the stale auth and create fresh. At capture, pass explicit `amount_to_capture`/`amount_money` = `orders.total_amount`. **Local-ish but MUST be tested on deploy with an amount-change flow.**
- **Confidence:** HIGH (key verified).

### H-4 — Bespoke checkout offers fulfillment methods the merchant DISABLED + charges a fabricated $4.99 delivery
- **Lenses:** Storefront (H1), Templates (M7)
- **File:** `src/components/storefront/screens/Checkout.tsx:636,719` (`FULFILLMENTS`/`TIME_SLOTS` hardcoded — verified), `src/components/storefront/PublishedStorefront.tsx:248-250` (`serviceFeeCents` 1% + `deliveryFeeCents = 499` stored on the order — verified)
- **Scenario (bad):** Pickup-only merchant. Customer still sees Delivery + Dine-in, picks Delivery, is charged $4.99 for a service the merchant can't dispatch; or Dine-in at a no-dine-in venue produces an `in_store_pickup` order with `dine_in:true`. The default storefront only lists `enabledFulfillments`.
- **Impact:** Orders the merchant can't fulfill; mis-billed fees diverging from merchant config and the locked financial model (the C1 server-recompute only protects the card charge, not the stored total or pay-at-venue amount).
- **Fix:** Thread `enabledFulfillments` from `mergeSettings(org.settings).fulfillment` onto `world`; filter `FULFILLMENTS`; default to the first enabled method (not the literal `"pickup"`). Source service-fee + delivery from merchant settings (or 0) instead of constants.
- **Confidence:** HIGH (hardcoded fulfillment + 499 verified).

### H-5 — `get_public_storefront` (and `get_member_org`, `get_order_by_id`) use a denylist over the full row → new Square columns + financial counters leak
- **Lenses:** Scale (H1, H2, M2)
- **File:** `supabase/migrations/20260602100000_storefront_rpc_null_recovery_secrets.sql:19` (`RETURNS public.organizations` + hardcoded `:= NULL` list that does NOT include Square cols — verified), `supabase/migrations/20260529080000_org_pii_isolation_for_staff.sql:48-57` (`get_member_org` same gap), `supabase/migrations/20260601093000_harden_order_customer_and_receipts.sql` (`get_order_by_id`); consumed at `src/services/api.ts:215`
- **Scenario (bad):** Any anon caller hits `get_public_storefront` for a public slug and reads `square_merchant_id`, `square_location_id`, `payment_provider`, plus `email_used_this_month`, `*_topup_credits`, `charges_enabled`, `phone_otp_attempts`, `founding_merchant`, `tos_accepted_at`, etc. Staff `get_member_org` leaks the merchant's Square identity. Public order tracker leaks `stripe_payment_intent_id`/`square_payment_id`.
- **Impact:** Discloses payment-processor identity + business internals to the public internet; structurally, every future `organizations` column is exposed-by-default.
- **Fix:** Immediate: null `square_merchant_id`, `square_location_id` (+ financial counters) in all three denylists. Proper: convert to an **allowlist** `RETURNS TABLE(...)` projecting only storefront-needed columns (like `get_public_menu`/`marketplace_organizations` already do). See IMP-1.
- **Confidence:** HIGH (denylist omits Square cols — verified). **Run masking migration tonight (additive/safe); allowlist later.**

### H-6 — Owner can self-activate `square_payment_ready` / flip `payment_provider` (org UPDATE has no WITH CHECK)
- **Lenses:** Scale (H3)
- **File:** RLS `"Owners update their org"` — `supabase/migrations/20260418045819_...sql:31-32` (`USING (owner_id = auth.uid())`, no WITH CHECK); migration `20260609020000` says the flag is operator-set
- **Scenario (bad):** Merchant runs `UPDATE organizations SET square_payment_ready=true, payment_provider='square'` via REST. Edge fn then treats them as payment-ready and (per BLK-2) charges through the shared account; or flips `payment_provider` with no readiness, breaking their own checkout.
- **Impact:** Owner-driven misconfig of a money path; amplifies BLK-2.
- **Fix:** Make these columns operator/server-owned: BEFORE UPDATE trigger rejecting owner changes to `payment_provider`/`square_payment_ready`/`square_merchant_id`/`square_location_id`/`charges_enabled`/`stripe_account_id` (allow service-role / onboarding fn only), or a separate `payment_connections` table written only by SECURITY DEFINER. **Stage — security boundary decision.**
- **Confidence:** HIGH (no WITH CHECK on the policy — per lens; pattern matches the known subdomain_slug gap).

### H-7 — Square card-retry is permanently blocked after a decline (fixed idempotency key + no payment_id persisted on failure)
- **Lenses:** Scale (H4)
- **File:** `supabase/functions/square-payment/index.ts:233` (fixed key) + failure branch `:252-264` (stores nothing)
- **Scenario (bad, common):** First card declines (typo/insufficient funds). Customer fixes it and retries with a new `source_id`; CreatePayment reuses the same idempotency key → Square replays the original declined response for ~24h → the order can never be paid. Customer abandons; looks like a Woahh bug.
- **Impact:** Lost conversions on every recoverable decline.
- **Fix:** Include a retry nonce in the key for declines (e.g. `sq-pay-${order.id}-${sourceId.slice(0,12)}` or an attempt counter); keep `resume_existing_payment` only for the successful APPROVED/COMPLETED case. (Overlaps H-3's amount-key fix — design the key once.)
- **Confidence:** HIGH.

### H-8 — Empty-cart "Place order" + post-navigation re-validation gaps in bespoke checkout
- **Lenses:** Storefront (H2, M5)
- **File:** `src/components/storefront/screens/Checkout.tsx:217` (`usePlaceOrder` doesn't guard empty cart), `:1159-1160` (`canContinue` true on Payment step regardless of cart), `:293-296` (`fulfillmentValid` only gates step-0→1 Continue), `:457-460` (StepIndicator jumps bypass validation)
- **Scenario (bad):** (a) User empties the cart from the persistent rail while on the Payment step, clicks Place order → zero-line order. (b) User selects Pickup, fills contact, jumps back via the indicator, switches to Delivery (address now blank), jumps to Payment, places order → delivery order with `address: ""` → courier has nowhere to go.
- **Impact:** Zero-line and invalid-delivery orders reach the kitchen/courier.
- **Fix:** A single `canPlaceOrder(world, form)` predicate, re-checked inside `usePlaceOrder` (empty cart + `fulfillmentValid` + `contactValid`) AND used to disable `PrimaryAction`, regardless of navigation path. (See IMP-2.)
- **Confidence:** MEDIUM-HIGH.

### H-9 — Bespoke checkout accepts junk name/phone unsanitised into order notes + SMS consent
- **Lenses:** Storefront (H3, H4)
- **File:** `src/components/storefront/screens/Checkout.tsx:283-291` (`contactValid`: `name.trim().length>1`, `phone.trim().length>=6` — accepts 6 spaces / 6 letters), `:785` (`phoneGiven`), `src/components/storefront/PublishedStorefront.tsx:297,322-324` (raw `name` into `notes` + `recordConsentAndGetCustomerId`)
- **Scenario (bad):** Name of 10k emoji/newlines passes validation, concatenated raw into the kitchen ticket + persisted to `customers.name`. Phone `"abcdef"` passes → SMS opt-in checkbox shows → consent recorded for a non-numeric phone → later campaign silently fails but the consent record claims opt-in.
- **Impact:** Ticket-layout blowout, persisted junk PII, Spam-Act-adjacent bad consent data.
- **Fix:** Trim/strip-control-chars/length-cap name/email/address (e.g. 80/200) before notes + consent RPC; validate phone shape (`/[0-9]/` count ≥ 6 after stripping spaces/`+`/`-`); only show the SMS consent box for a real-looking number.
- **Confidence:** MEDIUM-HIGH (validation thresholds per lens).

### H-10 — Three divergent `effectivePrice` definitions disagree across home vs menu/cart
- **Lenses:** Templates (H1)
- **File:** `src/components/storefront/homes/cantina/Parts.tsx:30-34` & `homes/rush/Parts.tsx:134-136` (`sale_price > 0 ? sale_price : price` — verified) vs `homes/daily/Parts.tsx:25`, `homes/maison/MaisonHome.tsx:110`, `homes/kerb/Parts.tsx:237` vs canonical `screens/pricing.ts:21-37` (`onSale = sale_price < price`)
- **Scenario (bad):** A `sale_price` ≥ base (fixture/sale-window/future path) shows the higher "sale" price on the cantina/rush hero while the menu+cart bill the lower base; `sale_price=0` shows "$0" in the menu (priceState treats it as 100%-off) but full price on cantina. Same product, two prices on one screen.
- **Impact:** Inconsistent pricing across surfaces; the "onSale" badge logic also diverges per home.
- **Fix:** Delete every local `effectivePrice` helper; import `effectiveUnitPriceCents` + `priceState` from `screens/pricing.ts`. One sale definition storewide.
- **Confidence:** HIGH (divergent helpers verified).

### H-11 — `cantina` template is orphaned: in client `TEMPLATES` + registered as a blueprint, but absent from the picker AND from the DB CHECK (so it can't be picked and would fail to save)
- **Lenses:** Templates (H2), Scale (M1)
- **File:** `src/lib/storefrontConfig.ts:46,59` (`cantina` valid — verified), `src/components/storefront/chrome/registry.ts:241-256` (registered), `src/pages/StorefrontPreview.tsx:62-71` (`RESTAURANT_TEMPLATE_ORDER` omits cantina — verified), `supabase/migrations/20260607010000_storefront_template_variants.sql:20-23` (CHECK = classic/hero/grid/minimal/editorial/boutique/bold/kerb/daily/maison/rush — **no cantina**, verified)
- **Scenario (bad):** A fully built blueprint is unreachable in any picker; and the moment any path persists `template='cantina'`, the `storefront_config` INSERT/UPDATE throws `check_violation`. Today it only surfaces in the hardcoded `/tacojoint-preview` route (no persist), which is why it hasn't bitten.
- **Impact:** Orphaned work + a latent save-crash.
- **Fix:** Add a migration extending the CHECK to include `'cantina'` AND add `"cantina"` to `RESTAURANT_TEMPLATE_ORDER` — **together**. Add a parity test: `TEMPLATES` ⊆ migration CHECK array (see IMP-3).
- **Confidence:** HIGH (both gaps verified).

### H-12 — `square-webhook` reconstructs the signed URL from `req.url` when `SQUARE_WEBHOOK_URL` is unset → all Square webhooks silently rejected (or host-spoof surface)
- **Lenses:** Payments (M6 — escalated by Square lens L3)
- **File:** `supabase/functions/square-webhook/index.ts:80-82`
- **Scenario (bad):** Operator forgets `SQUARE_WEBHOOK_URL`. Behind the Supabase/Cloudflare proxy `req.url` ≠ the Square-dashboard notification URL → HMAC always fails → every payment status update dropped → orders never reach `paid` from the webhook (masked by order-respond's inline capture), and Square retry-storms then disables the subscription.
- **Impact:** Silent webhook breakage; weakened anti-spoof posture.
- **Fix:** Make `SQUARE_WEBHOOK_URL` **required** — fail-closed 503 if unset (like the signing key); never fall back to `req.url`.
- **Confidence:** HIGH (fallback present per lens).

---

## MEDIUM

### M-1 — Cart line `+` button has no upper bound (only `QuantityStepper` clamps to 99)
- **Lenses:** Storefront (M1)
- **File:** `src/components/storefront/screens/Cart.tsx:74,83` (`onSetQty(line.id, line.qty±1)`), reducer `src/components/storefront/chrome/useLiveCart.ts:126-132` (floors at 0, no cap)
- **Impact:** Hold/auto-repeat `+` → qty 500+, giant total, large card auth.
- **Fix:** Clamp `qty = Math.min(99, ...)` in the reducer or the Cart handlers; disable `+` at cap.
- **Confidence:** MEDIUM-HIGH.

### M-2 — Both `onCancel` and `onPaid` on the card dialog flip to "confirmed" → a customer who cancels payment sees order-confirmed
- **Lenses:** Storefront (M4)
- **File:** `src/components/storefront/screens/Checkout.tsx:1857-1868`
- **Scenario (bad):** Customer reaches the card dialog, hits Cancel. Order already exists at `awaiting_confirmation` (unpaid). UI shows the same "Order confirmed / updates by text" as a paid order; customer believes they paid; stale-order cron may auto-decline.
- **Impact:** Customer expects food that won't come; payment-state confusion.
- **Fix:** On cancel, show "Order received — payment pending" (distinct copy), or keep them on the Payment step with a "Complete payment" retry + explicit "pay at venue" choice.
- **Confidence:** MEDIUM-HIGH.

### M-3 — Customer-facing fees invented client-side and not re-validated for non-card orders
- **Lenses:** Storefront (M2)
- **File:** `src/components/storefront/PublishedStorefront.tsx:248-250`, `Checkout.tsx:72-82` (`computeTotals`)
- **Scenario (bad):** Pay-at-venue/dine-in order's `totalCents` is purely client-computed; C1 only protects the card charge. A tampered client submits any total for a pay-later order; venue ticket shows a wrong total. (Same root as H-4's $4.99/1%.)
- **Fix:** Server-side compute/validate the displayed total for all orders, or derive fees from merchant config. Document pay-at-venue totals as advisory until then.
- **Confidence:** MEDIUM.

### M-4 — `auto_decline_stale_orders` cron has no idempotency and no lower-bound window
- **Lenses:** Payments (H4 — placed MEDIUM here as it folds into BLK-1's fix)
- **File:** cron `supabase/migrations/20260422122034_98783421-...sql:26-41`
- **Scenario (bad):** If `order-respond` takes >60s (Stripe slow + Resend backoff), the next minute's cron fires a 2nd `auto_decline` for the same still-`awaiting_confirmation` row → double decline emails + the BLK-1 race against itself. No lower bound prevents a 1-second confirmation window from clock alignment.
- **Fix:** Claim atomically in SQL (`UPDATE ... WHERE status='awaiting_confirmation' AND created_at < cutoff RETURNING id`), fire side-effects only for claimed rows; or add a `decline_dispatched_at` marker. Fold into BLK-1.
- **Confidence:** HIGH (fold into BLK-1 rewrite).

### M-5 — Webhooks have no event-id dedup; replayed `canceled`/`failed` can downgrade an order mid-confirm
- **Lenses:** Payments (M1)
- **File:** `supabase/functions/stripe-webhook/index.ts:79-87`, `supabase/functions/square-webhook/index.ts:122-142` (only guard is `.neq('payment_status','paid')`)
- **Scenario (bad):** A replayed/out-of-order `payment_intent.canceled` (Stripe at-least-once redelivery; Square `payment.updated` fires on every change) sets `payment_status='canceled'` on an order being captured concurrently → row reads `canceled` while money is captured.
- **Fix:** Persist processed `event.id`/`event_id` in a `webhook_events` table (unique constraint), ignore duplicates; enforce a monotonic status lattice (`unpaid→authorized→paid`; never write `authorized`/`canceled`/`failed` over `paid` or over `canceled`). See IMP-4.
- **Confidence:** MEDIUM-HIGH.

### M-6 — No refund path anywhere; `refunded` status is valid but never produced
- **Lenses:** Payments (M5), Square (L4)
- **File:** `supabase/migrations/20260602130000_online_payments_express.sql:23` (enum allows `refunded`) — no producer; decline email promises refunds (`order-respond/index.ts:376`)
- **Impact:** Every refund is manual in the Stripe/Square dashboard; the order row never reflects `refunded`; no automated remediation for the BLK-1/H-2/M-2 mischarge scenarios. A Square-dashboard refund never updates the order.
- **Fix:** Add a `refund-order` action/edge fn (owner-auth) refunding via the order's provider id, setting `payment_status='refunded'`; wire the decline path to auto-refund a captured (`paid`) order; add `refund.created`/`refund.updated` handling in `square-webhook`. **Stage — ops/product decision.**
- **Confidence:** HIGH (no producer — verified by grep across migrations per lens).

### M-7 — `order-respond` / `stripe-payment-intent` / `square-payment` capture failures are swallowed; order still confirms + emails "confirmed"
- **Lenses:** Payments (M4), Square (H4, H5)
- **File:** `supabase/functions/order-respond/index.ts:197,211,214-216,233,250,253-255`
- **Scenario (bad):** `capture`/`complete` throws (transient 5xx/network). Catch logs, falls through; order → `pending`, customer emailed "confirmed", `payment_status` left at `authorized`; the hold expires uncaptured. Square "already COMPLETED/CANCELED" errors are treated as non-ok and silently ignored even though the payment actually captured.
- **Fix:** Don't email "confirmed" unless capture succeeded or the PI/payment is already in the target state; on failure leave `awaiting_confirmation` (owner/cron retries) + surface to the dashboard; treat Square "already in target state" errors as success (re-GET to confirm). Add a reconcile cron for `pending`+`authorized` orders. See IMP / I4.
- **Confidence:** MEDIUM-HIGH.

### M-8 — `stripe-payment-intent` / `square-payment` resume path doesn't check the order isn't already declined/terminal
- **Lenses:** Payments (M7), Square (L8)
- **File:** `supabase/functions/stripe-payment-intent/index.ts:92,104-123`, `square-payment/index.ts:195-210`
- **Scenario (bad):** Order auto-declined (status `declined`, PI canceled). Canceled PI isn't `RESUMABLE` → falls through to create a fresh PI on a `declined` order. Customer pays for an order the kitchen rejected. Square: `PENDING` (3DS/risk-hold) is treated as `authorized`, letting the UI proceed as paid.
- **Fix:** Early-return 400 if `order.status` is terminal (`declined`/`completed`) before creating/resuming, in both fns; map Square `PENDING` separately (don't claim `authorized`).
- **Confidence:** MEDIUM-HIGH.

### M-9 — `app_fee` is hardcoded 0 for ALL Square merchants → non-founding merchants pay no commission, breaking the 2%/2% charity split
- **Lenses:** Square (M4), Scale (M3)
- **File:** `supabase/functions/square-payment/index.ts:230` (`const appFeeAmount = 0;` unconditional — verified; reads `founding_merchant` at `:147` but never uses it)
- **Scenario (bad):** A non-founding Square merchant goes live → Woahh + charity get 0% (the Stripe path correctly computes `application_fee_amount`).
- **Impact:** Lost revenue + charity allocation on every Square order; financial-model divergence.
- **Fix:** Compute `appFeeAmount` from total + founding flag (founding → 0, else locked %). Note Square `app_fee_money` requires the platform to be the processing merchant via Connect/OAuth — ties to BLK-2. **Decision: gate Square go-live; restrict `square_payment_ready` to founding (fee-0) merchants until OAuth+app-fee exists.**
- **Confidence:** HIGH (unconditional 0 verified).

### M-10 — `upsert_my_consent` email path forks duplicate customers; phone path has a TOCTOU INSERT race
- **Lenses:** Scale (M4)
- **File:** `supabase/migrations/20260608010000_guest_checkout_consent.sql:139-144` (email match, non-unique LIMIT 1), `:188-202` (INSERT)
- **Scenario (bad):** (a) Two guest checkouts, same email, no/different phone → both INSERT → two CRM rows (campaign dup, miscounted "new customers"). (b) Two anon sessions, same phone, both pass the "no row" check → second hits `customers_org_phone_uidx` → order placement fails.
- **Fix:** Get-or-create via `INSERT ... ON CONFLICT (organization_id, phone_number) DO UPDATE` (and `(org, user_id)`), or catch `unique_violation` + re-select-claim; consider a partial unique index on `(org, lower(email)) WHERE user_id IS NULL` to curb guest dup.
- **Confidence:** MEDIUM.

### M-11 — Concurrent same-name signups race on slug generation → "Database error creating new user"
- **Lenses:** Scale (M5)
- **File:** `supabase/migrations/20260609010000_guard_anon_user_triggers.sql:59-66` (`WHILE EXISTS` check then INSERT)
- **Scenario (bad):** Two concurrent "Joe's Pizza" signups both compute `joes-pizza` (free at check time), both INSERT → second violates the `subdomain_slug` UNIQUE → the auth.users trigger raises → signup fails. Real at launch-burst scale.
- **Fix:** Make the insert collision-tolerant — loop the INSERT catching `unique_violation` and re-suffix (rely on the atomic INSERT + retry, not a pre-check).
- **Confidence:** MEDIUM-HIGH.

### M-12 — `square-payment` location resolution is non-deterministic for multi-location merchants and caches the wrong one permanently
- **Lenses:** Square (M6)
- **File:** `supabase/functions/square-payment/index.ts:86-95` (`find(ACTIVE) ?? locations[0]`), short-circuits forever once cached (`:76`)
- **Scenario (bad):** A multi-location merchant returns several ACTIVE locations; the unstable `find` caches whichever Square lists first onto `square_location_id`; payments land at the wrong store; uncorrectable without a manual DB edit.
- **Fix:** Refuse auto-pick when `locations.length > 1`; require an explicit `square_location_id` (a location picker in onboarding); auto-pick only for exactly one location.
- **Confidence:** MEDIUM.

### M-13 — Square decline `code` is returned but the UI shows a flat generic message
- **Lenses:** Square (M2, M3)
- **File:** `supabase/functions/square-payment/index.ts:252-263` (returns `code`), `src/components/checkout/CardPayment.tsx:224-228` (ignores `code`)
- **Impact:** No actionable "try another card / check CVV / insufficient funds" guidance; weaker conversion + support load.
- **Fix:** Map known `code`s (`CARD_DECLINED`/`INSUFFICIENT_FUNDS`/`CVV_FAILURE`/`CARD_EXPIRED`/`GENERIC_DECLINE`) to distinct, retryable copy. **MUST test each Square sandbox magic card on deploy.**
- **Confidence:** MEDIUM-HIGH.

### M-14 — Currency hardcoded AUD with no per-org currency or settlement-currency check
- **Lenses:** Payments (M2), Square (M5)
- **File:** `supabase/functions/stripe-payment-intent/index.ts:126`, `square-payment/index.ts:235,243`
- **Scenario (bad):** A connected account whose settlement currency isn't AUD gets FX-converted or `CURRENCY_MISMATCH` (Square sandbox often defaults US); the `$` label silently assumes AUD.
- **Fix:** Read currency from the org (add `organizations.currency` default `aud`), validate against the account's capabilities at onboarding, surface `CURRENCY_MISMATCH` distinctly, thread through the client label.
- **Confidence:** MEDIUM.

### M-15 — `square_payment_ready` / `payment_provider='square'` are never settable by any UI/RPC
- **Lenses:** Square (B3 — placed MEDIUM; it's a gating/decision gap, not active harm yet)
- **File:** migration `20260609020000:41`; grep confirms zero code writes these
- **Scenario:** Only onboarding path is hand-written SQL with no validation that a valid token/merchant binding exists (BLK-2), no Operations UI (Stripe has `charges_enabled` UI; Square has none).
- **Fix:** Add an Operations panel + an authenticated `square-connect` edge fn that verifies `ListLocations` then flips the flags together. Until then document the manual SQL + gate BLK-2. Ties to H-6.
- **Confidence:** HIGH (no writer — verified by grep per lens).

### M-16 — Switching/jumping fulfillment and various ThemeShell nav edge cases (Overlay focus race, duplicate cart trees, deep-link anchor race)
- **Lenses:** Templates (H3, M3, M5, M6), Storefront (M6, M7)
- **File:** `src/components/storefront/chrome/Overlay.tsx:114-130,165-188` (focus-restore + body-scroll-lock cross-instance race when two overlays swap in one commit), `screens/Cart.tsx:240-275` (PersistentRail renders the line list twice — desktop aside + mobile sheet, both tabbable), `chrome/useStorefrontNav.ts:80-93` (`openCart` keeps stale `productId`; mount-only single-rAF anchor scroll races layout)
- **Impact:** Focus flash / wrong AT focus, possible stuck `overflow:hidden`, duplicate "Remove X" controls for screen readers, deep-link lands mid-page.
- **Fix:** Track scroll lock with a `Set` of overlay ids; only restore focus if the closing panel still contains `document.activeElement`; render only the active screen's overlay; `aria-hidden`+`inert` the off-breakpoint cart; `openCart` returns a clean `{screen:"cart"}`; double-rAF / observer-settle the anchor scroll.
- **Confidence:** MEDIUM (logic-derived; not re-executed in a browser).

### M-17 — `tabs-dense-grid` / `lookbook-pages` category navigation inconsistencies
- **Lenses:** Templates (M1, M2)
- **File:** `src/components/storefront/screens/MenuBrowse.tsx:118-144` (TabsDenseGrid — dead `#cat-x` anchor; nav highlights by anchor, grid filters by id → can disagree), `:245-256` (LookbookPages ignores categoryId from the primary Menu/footer link → always lands on category #1)
- **Impact:** Deep links scroll nowhere; "active category" mismatch; boutique "Menu" entry dumps you on one collection.
- **Fix:** Render per-category anchored bands (or drop the dead anchor); unify "active category" to `nav.current.categoryId`; give LookbookPages an all/overview page when no categoryId.
- **Confidence:** MEDIUM.

### M-18 — 100-product / no-category catalogues render one ungrouped grid with no pagination/windowing; `groupByCategory` recomputed on every cart mutation
- **Lenses:** Templates (M8, M9)
- **File:** `src/components/storefront/screens/MenuBrowse.tsx` (maps full `world.products`), `catalogue.ts:67-80`, homes `groupByCategory` in `useMemo` keyed on `world` (which includes `cart`)
- **Impact:** 100 IntersectionObservers + 100 lazy images on one screen; adding one cart item re-groups the whole catalogue 2–3× (cart is in the `world` memo deps).
- **Fix:** Cap the grid with "Load more"/windowing past ~60 items; disable per-card `Reveal` past N; compute `groups` once at the stage level memoized on `[products, categories]` only and pass via context so cart changes don't re-group.
- **Confidence:** MEDIUM.

### M-19 — `SmartImage ratio="auto"` with no `src` → zero-height container; NoImageFallback invisible
- **Lenses:** Templates (M4)
- **File:** `src/components/storefront/templates/primitives.tsx:368-375,499-541` (`ASPECT_CLASS.auto=""`), used at `ProductView.tsx:343`
- **Impact:** Any future `ratio="auto"` without an explicit height silently renders an invisible image with no placeholder, defeating the layout-stable contract.
- **Fix:** When `!showImg && ratio==="auto"`, add a `min-h` floor to the wrapper (e.g. `min-h-[12rem]`), or require callers to pass a height.
- **Confidence:** MEDIUM.

### M-20 — `location_only` Square branch is an unauthenticated read of any order's `location_id`
- **Lenses:** Square (M1)
- **File:** `supabase/functions/square-payment/index.ts:165,174-183` (ownership check only runs when `callerId` non-null; anon skips it)
- **Impact:** Low (location ids aren't secret on Square) but it's an unauthenticated read keyed on a capability that doesn't need the order at all.
- **Fix:** Resolve `location_only` from `organization_id`/slug, drop the order coupling; or accept + document the minor leak.
- **Confidence:** MEDIUM.

---

## LOW

- **L-1** — Multi-item order lock ordering can deadlock under concurrency. *Payments-adjacent / Scale L1.* `supabase/migrations/20260608020000_c1_server_side_order_total.sql:141-161` locks products `FOR UPDATE` in client-supplied order; orders [A,B] vs [B,A] can deadlock (Postgres aborts one). Fix: lock in deterministic id order. Confidence MEDIUM.
- **L-2** — `order-respond` increments `email_used_this_month` via read-modify-write (`order-respond/index.ts:300`) → lost update under concurrent invocations; cap overshoot. Use the atomic `increment_email_usage` RPC. (Fixed by BLK-1's RPC.) Confidence HIGH.
- **L-3** — Bespoke flow never collects a per-item kitchen note though `CartLine.note` exists. `contracts.ts:53`, `useLiveCart.ts`; no UI sets it. Dead plumbing; customers can't say "no pickles". Fix: add a note textarea to `ProductDetailBody`. Confidence HIGH.
- **L-4** — `email` regex `/.+@.+\..+/` too loose (accepts internal spaces). `Checkout.tsx:287,781`. Use the shared `isValidEmail` (`RestaurantStorefront.tsx:523`). Confidence MEDIUM.
- **L-5** — Cart footer "Taxes & delivery calculated at checkout" but checkout shows a service fee (not tax) and conditional delivery. `Cart.tsx:184-186` vs `Checkout.tsx:603-620`. Align copy. Confidence HIGH.
- **L-6** — `orderNumberFor` FNV-1a 4-digit suffix can collide (9000 values); demo "W-1234" can repeat in galleries. `Checkout.tsx:88-99`. Widen to 6 digits. Confidence LOW.
- **L-7** — `ConsentCheckbox` T&C link inside the `<label htmlFor=tos>` toggles the checkbox on touch. `Checkout.tsx:350-404,867-876`. Move the link out or `stopPropagation`. Confidence MEDIUM.
- **L-8** — Stripe webhook doesn't also match on `stripe_payment_intent_id = pi.id` (defence-in-depth; metadata-only). `stripe-webhook/index.ts:79-87`. Confidence MEDIUM.
- **L-9** — `org.name` flows unescaped into the email subject (escaped only in body + From). `order-respond/index.ts:137,156`. Tighten the subject too (Resend sanitizes — LOW). Confidence MEDIUM.
- **L-10** — `square-payment:188` `Math.round(Number(order.total_amount))` assumes integer cents; fine today, masks a future schema change. Confidence LOW.
- **L-11** — `CardPayment.tsx:35` `SQUARE_SDK_SRC` hardcoded to `sandbox.web.squarecdn.com`; no env switch → guaranteed go-live break (prod build loads sandbox SDK). Flip + test on go-live. Confidence HIGH.
- **L-12** — `CardPayment.tsx:179` "No Square location" friendly message, but `onPaid()` then continues as if done though nothing was paid; confirm order stays `unpaid`/`awaiting_confirmation` (it does). Confidence MEDIUM.
- **L-13** — `formatPrice` returns `""` for null/NaN → blank price slot. `primitives.tsx:564-568`. Prefer `$0.00`/dash + clamp upstream. Confidence HIGH.
- **L-14** — Double-sticky tab bars on Counter (NavBar tabs + MenuBrowse tab strip). `NavBar.tsx:316` + `MenuBrowse.tsx:151`. Redundant; eats mobile space. Confidence MEDIUM.
- **L-15** — `CloseButton` uses `useId()` as a React `key` on a single element (no-op dead code). `Overlay.tsx:331,337`. Drop it. Confidence HIGH.
- **L-16** — `Reveal` mounts one IntersectionObserver per element (self-disconnects, but 100 at once on a dense grid). `primitives.tsx:296-320`. Tie into M-18 windowing or share one observer. Confidence MEDIUM.
- **L-17** — `square-webhook` ignores `oauth.authorization.revoked` (future); dead token keeps being used. `square-webhook/index.ts:109`. Ties to H-3-SQ token model. Confidence MEDIUM.
- **L-18** — `docs/SQUARE_POS_INTEGRATION.md` does not exist in this worktree (referenced by the Square work). Document the integration + the go-live checklist. Confidence HIGH.
- **L-19** — Double-click race on page-variant "Place order" only half-guarded (`submitting` is async state, not a synchronous latch). `Checkout.tsx:231-233,1181`. Add a `useRef` in-flight latch set synchronously. (Default `RestaurantStorefront` has the same theoretical gap.) Confidence MEDIUM.
- **L-20** — `findProduct` undefined (realtime-removed/86'd) → ProductView `return null` leaves the shell in a "product open, nothing visible" limbo. `ProductView.tsx` + `useStorefrontNav`. Render a "no longer available" state with a Back/close. Confidence MEDIUM.
- **L-21** — Page-variant checkout Esc handler is `onKeyDown` on `<main>` (only fires when focus is inside); Overlay uses a document listener. `Checkout.tsx:1635-1640`. Use a `useEffect` document listener or focus the takeover on open. Confidence MEDIUM.
- **L-22** — Square `ListLocations` failure caches nothing, returns null → customer silently dropped to pay-at-venue with no "merchant never set up" vs "Square down" distinction and no owner alert. `square-payment/index.ts:81-85,216-219`. Log the discriminating case; pre-resolve at onboarding. Confidence MEDIUM.

---

## IMPROVEMENTS (structural — not bugs, but they close whole classes)

- **IMP-1** — Make `get_public_storefront`, `get_member_org`, `get_order_by_id` share ONE allowlist projection (a "public org projection" view/function), reused by all three. Structurally eliminates the "new column leaks by default" class (root of H-5). Matches the sound `get_public_menu`/`marketplace_organizations` pattern. *(Scale I1.)*
- **IMP-2** — One `canPlaceOrder(world, form)` predicate reused by the CTA-disable + the submit handler — removes the class of "navigated around the guard" bugs (H-8, M-16). Centralise the fee/total math (`orderTotals(cart, fulfillment, merchantFees)`) used by both the UI summary and the order bridge (H-4/M-3). *(Storefront I1/I2.)*
- **IMP-3** — CI parity test for the three documented "keep in sync" cross-language pairs: (a) `tenant.ts RESERVED_HOSTS` ↔ `guard_subdomain_slug` reserved array; (b) `tenant.ts SLUG_RE` length ↔ DB CHECK (M3-SCALE); (c) `storefrontConfig.ts TEMPLATES` ↔ `storefront_config_template_check` (H-11). Each has already drifted. *(Scale I2 / Templates H2.)*
- **IMP-4** — Define `payment_status` transitions as a DB-level state machine (trigger/CHECK on a transition fn) so no edge fn or webhook can write an illegal/backward transition — closes M-5/BLK-1/H-1 at the data layer regardless of caller bugs. *(Payments IMP4.)*
- **IMP-5** — Add an `order_status_history` / `payment_events` audit table written on every transition with the provider event id — essential for reconciling mischarges + dispute evidence. *(Payments IMP1.)*
- **IMP-6** — Reconcile cron: re-attempt `capture`/`complete` on confirmed `authorized` orders before holds expire (covers H-2/M-7); refund/cancel `declined`+captured. *(Payments/Square I4.)*
- **IMP-7** — Square code dedup: `_shared/square.ts` for `squareFetch` + base/version constants (prod cutover currently edits 3 places); shared `mapSquareStatus` used by both webhook and order-respond (they already drift — webhook maps `FAILED→failed`, order-respond never sets `failed`). *(Square I1/I2.)*
- **IMP-8** — Add an SSR smoke test over EVERY blueprint in `STOREFRONT_BLUEPRINTS` (ThemeShell + each home + each screen variant) at 0/1/100 products, restaurant+retail, dark+light — asserting non-throw + a present `#menu` region; plus one jsdom add→cart→checkout (inert) per shell family (overlay/page/persistent-rail). The only existing test (`StorefrontRenderer.smoke.test.tsx`) covers just the SectionsHome path (H-4-TMPL). *(Templates H4.)*
- **IMP-9** — `order-respond` should fail-LOUD on Square token absence (currently silently skips capture/cancel → uncaptured holds), matching `square-payment`'s 500. *(Scale I3.)*

---

## VERIFIED SOUND (no finding — recorded so it isn't re-audited)

- `marketplace_organizations` view + `get_public_menu` are correct **allowlists** — payment columns don't leak through them.
- C1 floor model (`20260608020000`): server-recomputes subtotal + DB-priced extras + server-validated promo, rejects below-floor for untrusted callers only, skips org members, single `FOR UPDATE` read avoids price/stock TOCTOU. Floor-not-exact-total tradeoff justified.
- `square-webhook` is fail-closed on missing signing key, constant-time HMAC, `.neq('payment_status','paid')` guard, reference_id fallback — matches the hardened Stripe webhook.
- Square payment-status mapping reuses the existing `payment_status` CHECK (no new states).
- Migration `20260609020000` is additive + idempotent (`ADD COLUMN IF NOT EXISTS`, partial index, `payment_provider DEFAULT 'stripe'` leaves existing merchants unchanged).
- Anon-trigger guard (`20260609010000`) short-circuits both auth.users triggers on `is_anonymous` (no phantom orgs/profiles for guests).
- Orders dashboard 5s polling fallback; `useProductsRealtime` pairs realtime + 30s polling + re-subscribes on `user.id` (CLAUDE.md gotchas #3/#4 honored).
- Staff have no direct UPDATE on `organizations` (owner-only) — payment-connection write is org-owner-level, not per-staff (H-5 staff exposure is read-only).
- Genuinely config-driven: one `ThemeShell` + variant switches, zero per-merchant code; unknown template falls back to blueprint[0] without throwing.
- Preview↔live parity: identical `ThemeShell`+`world` tree; inert demo Checkout can't place a real order without the injected bridge.
- a11y baseline strong: one `Overlay` does focus-trap/Esc/restore/scroll-lock; reduced-motion honoured; correct ARIA roles (the H-3/M-16 issues are the exceptions).
- Dark mode + accent swap ride entirely on AA-derived scoped CSS vars; deterministic render (no clock/RNG; FNV-1a order number).

## Integration review (2026-06-10)

**VERDICT: NOT integration-sound — 1 BLOCKER + 3 HIGH must be fixed before deploy.** The combined payment surface + migration stack share two root-cause integration defects: (1) the `payment_status != 'paid'` no-downgrade guard predates the refund pass and is blind to `refunded`/`partially_refunded`, so Square re-fires/resumes silently revert refunded orders to `paid`; (2) the H-5/H-6 column-masking RPC (`get_order_by_id`) was re-created at an earlier timestamp than the migration that adds `orders.square_location_id`, so the new column is anon-readable. Both are emergent — invisible to per-pass review. The state machine token/provider/claim wiring and migration run-order/dependency chain are otherwise verified sound.

This section consolidates two integration-review lenses (A = payment state machine; B = migration stack). Findings are deduped and severity-ranked. Two HIGH-class findings across the lenses (Lens A "resume-path clobber" and Lens A BLOCKER) share one root cause and are listed under the BLOCKER's fix.

### BLOCKER

**INT-B1 — Square `payment.updated` webhook + resume path clobber refund states back to `paid`** (Lens A BLOCKER + Lens A HIGH "resume re-mark", same root cause)
- **Files:** `supabase/functions/square-webhook/index.ts` (`setOrderPayment`, ~125-178); `supabase/functions/square-payment/index.ts` (~223-261, 371-380); interacts with `supabase/migrations/20260610050000_order_refunds.sql` (`record_order_refund`).
- **Scenario:** After a refund, `payment_status` is `refunded`/`partially_refunded` but the Square payment object stays `COMPLETED` (only `refunded_money` changes). Square fires `payment.updated`; `setOrderPayment` maps COMPLETED→`paid` and its only guard is `.neq('payment_status','paid')` — which does NOT block a `refunded`/`partially_refunded` row → order silently flips back to `paid`. Same clobber is reachable client-side via the `square-payment` resume branch (only short-circuits on `payment_status === 'paid'`, then re-writes `paid` for a still-COMPLETED refunded payment). Result: GMV re-inflates (settlement keys on `payment_status`), order is internally inconsistent (`payment_status='paid'` with `refund_amount_cents>0`). Stripe not currently affected (no `payment_intent.succeeded` re-fire post-refund).
- **Fix:** Widen the no-downgrade guard to protect terminal/refund states in BOTH writers: `.not('payment_status','in','(paid,refunded,partially_refunded)')` on `square-webhook setOrderPayment` (both `square_payment_id` and `reference_id` fallback updates) and on the `square-payment` order-row write; add a top-of-handler terminal check in `square-payment`: reject when `payment_status` ∈ `paid,refunded,partially_refunded,canceled` (`code:"order_terminal"`, 400). Apply the widened guard defensively in `stripe-webhook setOrderPayment` too. Optionally route `payment.updated` carrying non-zero `refunded_money` through `set_refund_status` instead of mapping COMPLETED→paid.

### HIGH

**INT-H1 — Anon order-tracker leaks `orders.square_location_id` (H-5 mask not re-amended after column add)** (Lens B HIGH-1)
- **Files:** `supabase/migrations/20260610030000_orders_square_location.sql` (adds `orders.square_location_id`); `supabase/migrations/20260609060000_rpc_mask_square_and_counters.sql` (`get_order_by_id`, earlier timestamp, denylist masks only `stripe_payment_intent_id`/`square_payment_id`/`square_order_id`).
- **Scenario:** `get_order_by_id` is the only anon-GRANTed `RETURNS SETOF orders` RPC and returns the full row by denylist. 030000 runs AFTER 060000 and adds `square_location_id`, which the denylist never nulls → any anon caller with a `receipt_token` (customer order-status URLs) reads the merchant's Square location id. Exactly the denylist-leak failure mode 060000 warns about.
- **Fix:** Re-create `get_order_by_id` AFTER the last column-adding migration with `r.square_location_id := NULL;` added to the denylist (place this re-create last in the run order). Preferably land the deferred allowlist-projection (mask-by-default). Scope is `get_order_by_id` only — `get_member_org`/`get_public_storefront` don't return the new orders column (Lens B MEDIUM-1).

**INT-H2 — Concurrent partial-refund + webhook back-out: opposite lock order → deadlock / lost-update on refund total** (Lens A HIGH "partial+full double-fire / back-out")
- **File:** `supabase/migrations/20260610050000_order_refunds.sql` (`set_refund_status` ~307-335 vs `record_order_refund`).
- **Scenario:** `set_refund_status` locks the refund row then the order row (`FOR UPDATE`); `record_order_refund` locks the order row first then inserts the refund row — opposite acquisition order. A webhook back-out (e.g. refund A → FAILED) racing a new partial refund B can deadlock, or compute `v_new_total` from a stale `refund_amount_cents` snapshot → `refund_amount_cents`/`payment_status` drift from the sum of `succeeded` refund rows; GMV reads a wrong net.
- **Fix:** Make lock order consistent — in `set_refund_status` lock the order row FIRST (`SELECT ... FROM orders WHERE id = (SELECT order_id FROM payment_refunds WHERE ...) FOR UPDATE`), then the refund row. Better: derive `refund_amount_cents` as a recomputed `SUM(amount_cents) WHERE status IN ('pending','succeeded')` inside the locked section rather than incremental add/subtract (eliminates the lost-update).

### MEDIUM

**INT-M1 — `notifyRefund` fires per partial with single-amount framing + no dedupe vs idempotent record** (Lens A MEDIUM)
- **File:** `supabase/functions/refund-order/index.ts` (~294, 373, 490-534).
- **Scenario:** Email is sent unconditionally after `recordRefund` with this-call's amount only; partial-then-completing refund sends "$30" then "$70" (never the $100 total), and a retry where `record_order_refund` was an idempotent no-op still emails. Reads as duplicate/confusing refunds → support/dispute risk.
- **Fix:** Have `record_order_refund` return an `is_new` flag; gate `notifyRefund` on it. Phrase email with this refund amount + running refunded total / remaining balance.

**INT-M2 — `order-respond` capture path not guarded against already-refunded `payment_status`** (Lens A MEDIUM)
- **File:** `supabase/functions/order-respond/index.ts` (~115-119, 215-283).
- **Scenario:** Early-return only checks `order.status`, not `payment_status`. Combined with INT-B1's clobber, a refunded-then-confirmed order can be marked `paid` with `refund_amount_cents>0`. Largely neutralized by fixing INT-B1; belt-and-braces.
- **Fix:** After the claim, skip the capture write if `payStatus` ∈ `('refunded','partially_refunded','canceled')`; optionally have `record_order_refund` refuse orders in `awaiting_confirmation`.

**INT-M3 — Concurrent Square token refresh (inline charge × daily cron) → no CAS, stale-token charge failures** (Lens A MEDIUM)
- **File:** `supabase/functions/_shared/square.ts` (`getFreshAccessToken` ~153-188); callers `square-payment`/`order-respond`/`refund-order` + cron `square-token-refresh`.
- **Scenario:** Inline refresh and cron can both see `needsRefresh` and call `obtainToken`; the losing caller proceeds with its stale in-memory `conn.access_token` → sporadic `UNAUTHORIZED`. With `withinDays=7` the window is wide (routine, not edge). An `order-respond` capture that fails silently leaves "cooked but not captured" until the webhook reconciles.
- **Fix:** Serialize refresh with a conditional update (`UPDATE ... WHERE org_id=$ AND expires_at=$old`) so one writer wins; on lost CAS re-`loadConnection` before charging. Or short advisory lock per org.

**INT-M4 — `set_square_default_location` leaves `organizations.square_location_id` stale (H-6 guard makes it a one-way door)** (Lens B MEDIUM-3)
- **File:** `supabase/migrations/20260610010000_square_connections.sql` (~205-217).
- **Scenario:** RPC updates `square_connections.default_location_id` only (the H-6 guard would pin the org column under the owner's JWT). Correct today because `square-payment` reads the connection first, but `organizations.square_location_id` is set once at connect (service role) and never re-synced; any future reader of the org column charges to a stale location, and no JWT path can keep it in sync.
- **Fix:** Either mirror the value into `organizations.square_location_id` via a service-role helper/edge fn, or drop the org column and make `square_connections.default_location_id` the single source of truth. Until then, audit that no reader uses `organizations.square_location_id`.

**INT-M5 — `partially_refunded` inflates `by_status.paid` count / `order_count` in final GMV RPC** (Lens B MEDIUM-2)
- **File:** `supabase/migrations/20260610050000_order_refunds.sql` (~398).
- **Scenario:** Partial-refund orders bucket as `paid`: `cents` are netted (line 396) but the order is counted as a full `paid` order, so AOV (`gmv_cents/order_count`) under-states for merchants with many partials. Internal BI only, org-scoped, no leak. Comment (412-416) only documents the full-refund exclusion half.
- **Fix:** Document the semantic in the RPC comment, or compute AOV over only non-zero-net orders if fidelity matters.

### LOW

**INT-L1 — `square-payment` resume reports a `PENDING` Square payment as `authorized`, contradicting its own comment** (Lens A LOW)
- **File:** `supabase/functions/square-payment/index.ts` (~60, 244-261).
- **Scenario:** `RESUMABLE_SQUARE = ["APPROVED","PENDING","COMPLETED"]` includes `PENDING` despite the comment (~241-243) saying PENDING is NOT treated as authorized; resume returns `status:"authorized"` for a matching-amount PENDING. No money moves (order-respond won't capture a non-APPROVED), but the storefront tells the customer they're authorized while a 3DS/risk hold is unresolved.
- **Fix:** Remove `PENDING` from `RESUMABLE_SQUARE` (or special-case to "still processing").

**INT-L2 — Out-of-band dashboard refunds not reflected in `refund_amount_cents` → `remaining` over-states** (Lens A LOW)
- **File:** `supabase/functions/refund-order/index.ts` (~157-159, 257-275).
- **Scenario:** `remaining = total_amount - refund_amount_cents`; a refund issued directly in the Stripe/Square dashboard isn't recorded (we only `set_refund_status` for refunds we created), so `remaining` stays too high and `refund-order` can attempt to over-refund. Provider rejects (`refund_failed`) — safe but opaque.
- **Fix:** Have `square-webhook`/`stripe-webhook` `refund.created` for an unrecorded refund call `record_order_refund` (not just `set_refund_status`) so external refunds decrement the summary. Document that dashboard refunds must be mirrored.

**INT-L3 — Overloaded `square_location_id` column name across `organizations` and `orders`** (Lens B LOW-1)
- **File:** `20260609020000` (`organizations.square_location_id`) vs `20260610030000` (`orders.square_location_id`).
- **Scenario:** Not a composition defect (different tables, both `IF NOT EXISTS`), but the identical name underlies INT-H1 (mask author missed the order column) and INT-M4 (two stores of "location"). Authoritative source is `square_connections.default_location_id`.
- **Fix:** Naming/documentation only (e.g. `organizations.square_default_location_id`); not worth a data migration.

### IMPROVEMENT

- **INT-I1 — Idempotency-key amount-coupling differs between authorize and refund** (Lens A IMPROVEMENT): `square-payment` keys on `order:amount:source_id`; `refund-order` keys on `order:alreadyRefunded:amount`. Two identical-amount partials issued back-to-back before the first records share a key → Square returns the first refund object, `record_order_refund` dedupes on `provider_refund_id`, second partial no-ops. Safe (prevents double-refund) but blocks a legitimate "refund $30 twice" until the first records. Add a code comment so a future maintainer doesn't "fix" it into a double-refund bug.
- **INT-I2 — The 10 migrations are not bundled into `docs/FOUNDER_RUN_NEXT.sql`** (Lens B IMPROVEMENT-1): the file is absent in `repo-audit`. Inter-file ordering is load-bearing exactly at INT-H1 (mask re-create vs `orders.square_location_id` add). Generate the bundle in strict timestamp order, append the INT-H1 `get_order_by_id` re-mask as the final statement, run as one transaction.
- **INT-I3 — Migration→edge-fn deploy-order coupling documented only in 050000** (Lens B IMPROVEMENT-2): `claim_order_for_response` (040000) has no missing-RPC guard — if `order-respond` deploys before 040000 runs, every confirm/decline 500s. State the apply-then-deploy order once at the top of the bundle: run all 10 migrations → deploy `order-respond`/`refund-order`/`square-*` → verify the two crons.

### Verified sound (no action)
Per-org OAuth path consistent across `square-payment`/`order-respond`/`refund-order` (all via `loadConnection`→`getFreshAccessToken`, no stale global `SQUARE_ACCESS_TOKEN`); H-1 provider detection identical across callers; claim-CAS correctly gates only capture/cancel and is absent from the (post-capture) refund path. Migration run-order/column dependencies satisfied in order; `payment_status` CHECK widening complete (final = `unpaid,authorized,paid,pay_in_person,refunded,partially_refunded,failed,canceled`); `get_gmv_analytics` double-create (040000→050000) later-wins, identical `(integer)` signature; H-6 guard passes service-role webhook/connect writes; `claim_order_for_response` enum/columns pre-exist; `square_connections` deny-by-default RLS correct; C1 prerequisite migration present.
