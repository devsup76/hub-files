# Apple/Google Pay — go-test prep (Square first)

> **⚠️ SUPERSEDED 2026-06-12 — these prep steps are DONE.** Wallets are merged to `main`
> and live on woahh.app; the migrations are applied; `square-payment` (v16) +
> `stripe-payment-intent` (v30) are deployed; **Apple Pay is device-verified on Test
> Pizza (production Square)**; the Apple Pay `.well-known` file is hosted + serving.
> For the current verified status + the real open items (R3 PENDING-capture gap, Stripe
> Apple Pay domain reg, Square SDK env, Google Pay device test), see the **"DOUBLE-CHECK
> — verified status"** section of `docs/APPLE_GOOGLE_PAY_RISK_AND_DESIGN.md` and the
> `woahh-wallets-apple-google-pay` memory. The historical prep checklist follows.

> Everything is built, self-reviewed, and committed on branch **`feat/wallets`** (pushed,
> build green). Nothing wallet-related is on prod except the Phase-0 fake-button removal
> (already live). Below is the exact ordered list to run together when you're back.

## What's ready
- **Stripe** Apple/Google Pay — DONE + the edge fn is already deployed (`stripe-payment-intent` v30).
- **Square** Apple/Google Pay — DONE in code; needs the steps below to go testable.
- Both passed an adversarial self-review; every real finding was fixed. One follow-up
  is flagged at the bottom (a production-only 3DS edge case — **not** a sandbox-test blocker).

## Step 1 — Run the migrations (Supabase SQL editor)
Paste **`docs/WALLETS_RUN_THESE.sql`** (2 additive, idempotent migrations) and run it:
- `20260612160000` — R7 guest-PII: freezes the receipt recipient onto the order.
- `20260612170000` — R15/R16: `square_auth_claim_at` column + `try_claim_square_auth()` RPC.

⚠️ **Run these BEFORE Step 2.** `square-payment` calls `try_claim_square_auth()`; deploying
it before the RPC exists would break the live Square card flow. Likewise `order-respond`
reads `orders.customer_email`.

## Step 2 — Deploy the edge functions (I'll do this with you, with your OK)
After Step 1's migrations are applied:
- **`square-payment`** — Square wallet path + R15/R16 atomic claim + R19 decline allow-list.
- **`order-respond`** — R7: prefers the frozen `orders.customer_email` snapshot.
- (`stripe-payment-intent` is already deployed.)
I'll smoke-test each after deploy (dummy order → clean 404, not 500) so the live card path is verified intact.

## Step 3 — Square Developer Console (you)
- Add your test host as a **sandbox domain** for Apple Pay. Square's sandbox **skips** the
  `.well-known` file check, so this is the only Apple-Pay registration needed for the test.

## Step 4 — Enable online card (you)
- Set **`online_card_enabled` = true** for the Square merchant (test-bistro).

## Step 5 — Test on a real phone (you)
- **Apple Pay:** Safari + a card in Apple Wallet, on the registered host.
- **Google Pay:** Chrome + a card in your Google account.
- Place an order → the wallet button shows above the card field → tap → authorize. The
  order lands `awaiting_confirmation`; you confirm it → it captures. (Sandbox doesn't charge.)

## Where to test
- **Preview (keeps it off prod):** register the `feat/wallets` Cloudflare preview host in Step 3.
- **Prod:** review the branch, merge to `main`, register `woahh.app`, test there.

## Known follow-up (NOT a test blocker)
- A **PENDING (3DS) wallet authorization** at owner-confirm time isn't captured yet
  (pre-existing `order-respond` gap, R3). Square's **sandbox won't hit it** (sandbox cards
  approve). I'll fix it carefully — with your review — **before Square wallets go to
  production**, since `order-respond` is the function we've had incidents in.
