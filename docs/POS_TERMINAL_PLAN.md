# POS & In-Person Payments Plan — Stripe Terminal + Tap to Pay

> **Status:** Planning. Not started.
> **Owner:** Woahh
> **Last updated:** 2026-05-31
> **Related:** `CLAUDE.md` → Pricing & Giving Model, Stripe Connect model (phased); existing walk-in dialog + KDS + `useProductsRealtime`.

---

## 1. Goal

Add a true **point-of-sale / service side** to Woahh so merchants can take **walk-in (counter / dine-in) orders** and accept **card-present payments** on a physical terminal — while preserving the in-person commission + charity split.

Two payment hardware paths, one shared backend:

1. **Smart reader** (Stripe Reader S700 / BBPOS WisePOS E) — driven from the existing web app. **Phase 1.**
2. **Tap to Pay on iPhone / Android** — no hardware, requires a native merchant app. **Phase 2.**

---

## 2. The core constraint (why Stripe, not the merchant's own reader)

The in-person fee (**4% merchant → 2% charity / 2% Woahh**, no customer-facing service fee) is collected via `application_fee_amount` on the charge. That fee can **only** be skimmed when the payment runs through **our** Stripe platform / Connect account.

| Path | Commission + charity | Order/payment data | Reconciliation | Verdict |
|---|---|---|---|---|
| **Stripe Terminal** (smart reader or Tap to Pay) | ✅ via `application_fee_amount` | ✅ full | ✅ automatic | **Primary** |
| **Merchant's own reader** (Tyro / Square / bank EFTPOS) | ❌ money bypasses us | ❌ none | ❌ manual | Fallback only |

**Decision:** Stripe Terminal is the primary path. A **"Paid externally / Cash"** button exists as a fallback for merchants who insist on their own hardware — but those orders generate **zero charity/commission** and must not become the default.

---

## 3. Stripe Connect alignment

This plugs into the already-documented phased Connect model:

- **Founding merchants** → Connect **Express**, `application_fee_amount: 0`. Pass-through, lower risk. Use this to prove the flow end-to-end at launch.
- **All paying merchants** → Connect **Custom**, Woahh holds funds, charity split via `application_fee_amount`.

### ⚠️ AFSL / money-handling gate
Connect **Custom** = Woahh holds funds = operates under Stripe's AU AFSL. **Written confirmation from Stripe is required before the first live in-person charge on Custom.** Card-present money flowing through our platform sits squarely inside this obligation. Founding-merchant Express flow (`application_fee_amount: 0`) is lower-risk and can go first.

---

## 4. Shared backend (built once, serves both phases)

Both the smart reader and Tap to Pay use the **same** edge functions and PaymentIntent flow. Only the client-side reader-discovery method differs.

### Edge functions
| Function | Purpose |
|---|---|
| `terminal-connection-token` | Issues a `terminal/connection_token` scoped to the **connected account**. |
| `terminal-register-reader` | Registers a **Location** + **Reader** per venue (smart reader only; Tap to Pay uses the device itself). |
| `terminal-create-payment` | Creates a **PaymentIntent on the connected account** with `application_fee_amount` (in-person 4%) + `transfer_data` / `on_behalf_of`. Returns `client_secret`. |

### Payment flow (identical for both hardware paths)
1. Staff signs in (reuse Supabase session + staff PIN login).
2. Client → `terminal-connection-token` → connection token for the connected account.
3. Discover + connect reader:
   - **Smart reader:** `discoverReaders({ discoveryMethod: 'internet', locationId })`
   - **Tap to Pay:** `discoverReaders({ discoveryMethod: 'tapToPay', locationId })` — the phone *is* the reader.
4. Build walk-in order → `terminal-create-payment` → PaymentIntent on connected account with `application_fee_amount`.
5. `collectPaymentMethod(clientSecret)` → customer taps/inserts card → `confirmPaymentIntent` → capture.
6. Order flows into KDS via Supabase Realtime — same lifecycle as an online order.

### Fee plumbing
- In-person: `application_fee_amount` = **4%** only (no 2% customer-facing service fee). Split downstream: 2% charity, 2% Woahh. Record to `donation_ledger` (source: `gmv_mandatory`) on capture, same as online.

---

## 5. Phase 1 — Smart reader from the web app

**Hardware:** Stripe Reader **S700** or **BBPOS WisePOS E** (smart countertop readers).
**Why first:** these are **server-driven over the internet via the Stripe Terminal JS SDK** — they work from the existing React/Vite web app with **no native app required**. Proves the entire Connect / `application_fee` / charity flow before taking on native overhead.

### Work items
- [ ] Build the 3 shared edge functions (§4).
- [ ] **Service / walk-in order builder** in the web dashboard — extend the existing walk-in dialog into a full counter-order screen (product grid, modifiers, qty, running total, fulfillment = `in_store_pickup` / `dine_in`).
- [ ] Integrate `@stripe/terminal-js` — connection token, reader pairing UI (settings under KitchenSettings or a new POS settings page), collect-payment flow.
- [ ] Reader registration UI (Location + Reader per venue).
- [ ] "Paid externally / Cash" fallback button (marks order settled; no charity/commission).
- [ ] Receipt: email (reuse `send-transactional-email`) + on-screen.
- [ ] Order writes into existing orders table → KDS via Realtime.

### Constraints
- Both S700 and WisePOS E are available in **Australia**.
- Web-app driven; no App Store dependency. Ships on the normal Lovable/web pipeline.

---

## 6. Phase 2 — Tap to Pay (native merchant app)

Tap to Pay on iPhone/Android **cannot** run from the web app or a PWA — it requires Stripe's **native mobile SDK**. Build a focused **"Service / POS" companion app**, not a port of the whole dashboard.

### Build approach: React Native (Expo dev client)
Use **`@stripe/stripe-terminal-react-native`** (official; supports Tap to Pay on iPhone *and* Android).

| Option | Verdict |
|---|---|
| **React Native (Expo dev client / EAS build)** | ✅ **Chosen.** Reuse `services/api.ts`, Supabase auth (`supabase-js` runs natively), staff PIN login, TS types. Official RN Terminal SDK with Tap to Pay. |
| **Capacitor wrap of the Vite app** | ⚠️ Least new code, but Tap to Pay relies on shaky community plugins. Don't bet the headline feature on it. |
| **Native Swift + Kotlin** | ❌ Two codebases, no reuse. Only if we outgrow RN. |

> Expo note: use a **dev client / EAS build**, not Expo Go — the Terminal SDK needs custom native config (config plugin).

### ⚠️ The long pole: Apple Tap to Pay entitlement
- Requires the **`com.apple.developer.proximity-reader.payment.acceptance`** entitlement, **requested from and approved by Apple** — not automatic. Can take days to weeks.
- **Apply on day one, in parallel with all other work.**
- Device floor: **iPhone XS or newer**, recent iOS. No taps in the iOS simulator — Stripe provides a *simulated* reader for dev.
- **Android Tap to Pay:** Android 11+, NFC, Google hardware attestation; published via Google Play.
- Both modes are **live in Australia**.

### App scope (deliberately narrow)
- Staff sign-in (reuse Supabase + PIN login).
- Walk-in order builder (mirror the Phase 1 web screen).
- KDS-lite view.
- Tap to Pay flow (swap `discoveryMethod: 'tapToPay'` into the shared backend).
- "Paid externally / Cash" fallback.

### Operational reality
- Lovable builds web, **not native binaries**. The RN app is a **separate repo with its own toolchain** (Xcode, Android Studio, EAS build, App Store + Google Play submission under our developer accounts).
- Edge functions + Supabase remain **shared** with the web app.
- Different release pipeline than the "push → Lovable CI picks it up" web flow — plan for app-store review cycles.

---

## 7. Sequencing

1. **Now:** apply for the **Apple Tap to Pay entitlement** (longest lead time).
2. **Now:** get **Stripe AFSL written confirmation** for Connect Custom in-person (before any live Custom charge).
3. **Phase 1:** ship the **smart reader** path from the web app — proves Connect / `application_fee` / charity end to end with zero native work.
4. **Phase 2:** spin up the RN Service/POS app against the **same** edge functions; swap in the `tapToPay` discovery method. Tap to Pay becomes a near-free addition once the backend exists.

**Rationale:** in-person commission + charity is live and earning (Phase 1) before we take on native-app overhead. "$0-hardware Tap to Pay" then layers on as a sales lever me&u / Bopple can't match cheaply.

---

## 8. Open questions / to confirm
- [ ] Connected account capability flags required for Terminal + Tap to Pay (enable in Connect onboarding).
- [ ] Per-venue Location modelling — one Stripe Location per `organizations` row, or per physical site for multi-location tiers?
- [ ] Receipt requirements for AU card-present (surcharge disclosure, GST line).
- [ ] Refund / void flow from the Service app (partial + full).
- [ ] Tipping on in-person — supported by Terminal; decide whether to expose and whether tips are charity-exempt.
- [ ] Offline behaviour — Terminal supports offline card-present; decide if in scope.
