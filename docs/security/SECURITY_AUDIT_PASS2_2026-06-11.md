# Security Audit — PASS 2 (adversarial, read-only)

**Date:** 2026-06-11
**Scope:** Fresh adversarial pass going BEYOND pass-1 (`docs/security/SECURITY_AUDIT_2026-06-11.md`).
Focus areas: business-logic abuse (promo/loyalty/discount), race conditions (capture/refund/decline/restock/double-submit), IDOR + mass-assignment on RPCs/edge fns, JWT/session/anon lifecycle, Storage bucket policies, Realtime authz, demo-mode + view-as-customer, reservation/cancellation tokens, email/SMS header/template injection, AI functions (prompt-injection + cost abuse), supply-chain, **and an audit of the code shipped tonight** (the pass-1 remediation: branch `security/overnight-hardening-2026-06-11`, HEAD `68f8c13`).
**Method:** read-only. Findings are VERIFIED in code; no code was changed.
**Baseline:** `vite build` exits 0 on the audited tree (confirmed).

---

## 0. How PASS 2 relates to PASS 1

Pass-1 found 43 issues (F1–F43) and **remediated the CRITICAL/HIGH set** in commits `c28098b`…`68f8c13`. I re-verified the remediations and they are **substantially correct and well-engineered** (see §4 "Audit of tonight's new code"). PASS 2's job is the *next layer*: classes pass-1 under-covered (Storage, Realtime, business-logic abuse, double-submit races, AI cost), the few pass-1 findings that were documented-but-NOT-fixed, and any bug introduced by tonight's code.

**New PASS-2 findings are numbered `P1`…`P21`.** Where a pass-1 finding is still open (documented, not fixed), it is re-flagged as `CARRY-Fnn` so the founder has one current list.

---

## 1. Findings Table (CRITICAL → LOW)

| # | Severity | Title | Location |
|---|---|---|---|
| **P1** | **HIGH** | Loyalty points are awarded at order PLACEMENT and never reversed on decline/abandon/void → free-reward farming | `RestaurantStorefront.tsx:681-687`; `customerAccount.ts:129`; (drift RPC `award_order_loyalty_points`) |
| **P2** | **HIGH** | Server-side order rate-limit is defeated by transaction rollback — a throttle hit on a *failed* order (out-of-stock probe, floor reject) is rolled back, so it never counts | `migrations/20260611040000:263-277,367-370` |
| **P3** | **MEDIUM** | Promo code has only a GLOBAL `usage_limit`, no per-customer cap → one guest redeems the same promo on unlimited fresh anon sessions | `migrations/20260611040000:463-482`; `usePromoCode.ts` |
| **P4** | **MEDIUM** | Promo `usage_count` is consumed at placement and **not** released on decline/abandon/void → griefing exhausts a merchant's limited promo by abandoning orders | `migrations/20260611040000:478-480`; `claim_order_for_response` (no decrement) |
| **P5** | **MEDIUM** | Anon caller can authorize a real Square/Stripe charge against ANY order UUID (no ownership check for `callerId === null`) → cross-customer "pay for a stranger's order" + writes a payment id onto a victim order | `square-payment/index.ts:227-233`; `stripe-payment-intent` (parity) |
| **P6** | **MEDIUM** | AI edge functions have NO per-org cost cap / rate-limit and accept ANY active staff (incl. kitchen via 6-digit PIN) → unbounded Anthropic spend on a compromised low-trust account | `_shared/auth.ts:48-67`; `ai-menu-copilot`, `ai-inventory-assistant`, `ai-campaign`, `ai-menu-import`, `ai-decline-reasons` |
| **P7** | **MEDIUM** | `abuse_throttle` is unbounded-growth + never pruned; `rate_limit_hit` fail-OPENs on null subject and the open-order cap query is u/index-unfriendly | `migrations/20260611040000:223-281,375-385` |
| **P8** | **MEDIUM** | `set_refund_status` can resurrect a fully-refunded order back to `payment_status='paid'` (and clear `refunded_at`) when its only money-moving refund row is flipped to `failed`/`canceled` by a webhook → a refunded order silently re-counts in GMV | `migrations/20260610050000:357-366` |
| **P9** | **MEDIUM** | `award_order_loyalty_points` + `adjust_loyalty_points` are SCHEMA-DRIFT (live-only, in NO migration) → unaudited money-adjacent code; the loyalty-guard trigger (P-fix) depends on them behaving a specific way | repo-wide (absent from `supabase/migrations/`) |
| **P10** | **LOW** | `guard_order_payment_columns` does NOT pin `payment_status` against a same-org member moving an order to a non-money status that *removes* a pending state, and leaves `order_number`/`customer_id` writable by staff (re-attribution) | `migrations/20260611020000:148-181` |
| **P11** | **LOW** | F11 restock helper restocks on `decline`/`auto_decline`/`void` but NOT on order **DELETE** (the delete path in `api.ts:493`) → a deleted stock-tracked order still leaks inventory | `migrations/20260611040000:54-104`; `api.ts:493` |
| **P12** | **LOW** | Self-XSS / template-injection latent in `order-respond` confirm email: guest `table_number` and `notes`-adjacent fields flow to HTML; escaped today but `fulfillment_type`/`order_number` interpolated via `escapeHtml` only partially | `order-respond/index.ts:531-575` (low — all current sinks ARE escaped) |
| **P13** | **LOW** | `rate_limit_hit('1 minute' window) keyed on `auth.uid()` only — a bot rotating anon sessions (each a fresh uid) bypasses the per-uid throttle entirely; no IP key | `migrations/20260611040000:367,619` |
| **P14** | **LOW** | `void_my_unpaid_order` lets a customer void their own `awaiting_confirmation` order even while the owner is mid-confirm in `order-respond` → a benign race (claim CAS wins) but can restock an order the kitchen is about to cook | `migrations/20260611040000:171-204` vs `order-respond` claim |
| **P15** | **LOW** | `customers` self-update guard (P-fix F6) pins points but the customer can still freely flip `marketing_opt_in` / `*_opted_out` / `saved_addresses` on their own row (consent-state tamper) | `migrations/20260611020000:64-67` (deliberately not pinned) |
| — | — | **CARRIED FROM PASS 1 (documented, NOT fixed)** | — |
| **CARRY-F19** | MEDIUM | Guest consent RPC still auto-CLAIMS unclaimed CRM rows by email/phone → within-tenant identity takeover | `migrations/20260608010000:130-183` |
| **CARRY-F20** | MEDIUM | `lookup_email_for_username` (anon) still leaks email per username; `customer-signup` 409 existence oracle | `migrations/20260420022440`; `customer-signup/index.ts` |
| **CARRY-F21** | MEDIUM | `validate_loyalty_code` still brute-forceable, no attempt limit, returns customer email | `migrations/20260602100500:64-91` |
| **CARRY-F22** | MEDIUM | `account-recover` still 200-owner cap + unsalted SHA-256 answers + spoofable XFF | `account-recover/index.ts` |
| **CARRY-F24/F25** | MEDIUM | Demo-mode global localStorage flag still routes REAL apex orders to in-memory DemoStore; `?demo=` arms on any host | `src/services/api.ts`; `src/lib/demoBootstrap.ts` |
| **CARRY-F14** | MEDIUM | Owners can still self-insert `donation_ledger` rows / set `total_donations_cents` (charity fabrication) | `migrations/20260423085555:88,97-109` |
| **CARRY-F2/F1** | CRITICAL | Leaked `sbp_`/`ghp_` credentials + plaintext Square tokens — ROTATION is the only fix (operational) | `.git/config`; chat history; `square_connections` |

---

## 2. Detailed NEW findings (PASS 2)

### P1 — HIGH — Loyalty points awarded at placement, never reversed on decline/abandon
**Location:** `src/pages/storefront/RestaurantStorefront.tsx:681-687` (and `RetailStorefront`/`PublishedStorefront` parity) calls `customerAccountApi.awardOrderPoints(order.id)` → `customerAccount.ts:129` → drift RPC `award_order_loyalty_points`. The award fires **immediately after `create_order_with_inventory` returns**, i.e. while a card order is still `awaiting_confirmation` and unpaid.
**Risk:** Loyalty points are credited the instant the order row exists, BEFORE the owner confirms and BEFORE the card is captured. `order-respond` (confirm/decline/auto_decline) and `void_my_unpaid_order` do NOT touch loyalty — there is no reversal anywhere in the repo. So a declined order, a customer-abandoned card order, and an auto-declined stale order all leave the awarded points in place. `total_points` is redeemed for real rewards.
**Exploit:** A guest (free anon session) places an order on a loyalty-enabled merchant, lets the points award, then abandons the card dialog (or the owner declines). Points stay. Loop to accrue an arbitrary balance, then redeem free rewards. Bounded to one org's loyalty program, but it directly defeats the loyalty economy and is trivially scriptable behind the captcha-less guest faucet (CARRY-F12).
**Fix:** Award loyalty points ONLY on a terminal SUCCESS — move `awardOrderPoints` server-side into the `order-respond` *confirm-with-paid* path (or a DB trigger on `payment_status → paid`), keyed idempotently per order. Never award at placement for a card/confirmation order. For pay-at-venue/auto-confirm, award on order completion, not creation. Reverse on refund proportionally.

### P2 — HIGH — Order rate-limit defeated by transaction rollback
**Location:** `migrations/20260611040000_abuse_dos_inventory_ratelimit.sql:263-277` (`rate_limit_hit` does an `INSERT … ON CONFLICT DO UPDATE`), called at `:367-370` INSIDE `create_order_with_inventory` (a single SECURITY DEFINER transaction).
**Risk:** The throttle counter is incremented **inside the same transaction** as the order. If the order subsequently RAISEs (out-of-stock, item unavailable, below-floor total, customer-mismatch — all very common attacker inputs), the whole transaction rolls back, INCLUDING the `abuse_throttle` increment. So an attacker who deliberately submits orders that fail late (e.g. always request `qty > stock`, or a sub-floor `p_total`) is **never throttled** — the rate-limit only "sticks" for orders that fully succeed. The concurrent-open-order cap (`:375-385`) has the same property (its SELECT count is meaningless if the throttle never persists). This guts the F12 server-side defense for the most abusive call patterns.
**Exploit:** Loop `create_order_with_inventory` with `qty = 9999` (always fails the stock check) or `p_total = 0` (always fails the floor) — each call rolls back the throttle row, so the per-minute cap never trips, while still doing the expensive product-lock + price recompute work (a DB-load DoS). Captcha (CARRY-F12) is the only real backstop, and it is FOUNDER-INPUT/not-yet-enabled.
**Fix:** Record the throttle hit so it survives a failed order. Options: (a) check/increment the limit via `pg_background`/`dblink` autonomous transaction; (b) move the throttle to an edge-function wrapper (Cloudflare/Supabase) that runs BEFORE the RPC and is not inside its transaction; (c) increment the counter in a `BEFORE`-everything step and explicitly `COMMIT`-isolate it. The clean fix is an edge/Cloudflare rate-limit (already recommended by pass-1) — the DB throttle as written is not a reliable boundary.

### P3 — MEDIUM — Promo code has no per-customer redemption limit
**Location:** `migrations/20260611040000:463-482` (promo validated by `is_active`/`expires_at`/global `usage_count < usage_limit` only). `promo_codes` has no `per_customer_limit` column and there is no `promo_redemptions(customer_id, promo_id)` ledger anywhere.
**Risk:** A "first order 20% off" or "$10 off" promo with `usage_limit = 500` is meant to be one-per-customer, but the only gate is the GLOBAL counter. Every fresh guest anon session is a new `customer` row, so the same human redeems the same promo repeatedly until the global cap is hit, and there is no defense at all for an unlimited (`usage_limit IS NULL`) promo.
**Exploit:** Guest places order with `PROMO20`, abandons or completes; mints a fresh anon session; repeats. Each is a "new customer," so a single attacker drains the entire promo allowance (or, for an uncapped promo, gets the discount on every order forever).
**Fix:** Add a `promo_redemptions(promo_id, customer_id, order_id, created_at)` table with `UNIQUE(promo_id, customer_id)` (or a `per_customer_limit` column) and enforce it inside `create_order_with_inventory` against `v_customer_id`. Combine with captcha so fresh-customer minting is itself gated.

### P4 — MEDIUM — Promo usage consumed at placement, never released on decline/abandon
**Location:** `migrations/20260611040000:478-480` (`UPDATE promo_codes SET usage_count = usage_count + 1` happens inside order creation); `claim_order_for_response` (decline/auto_decline) and `void_my_unpaid_order` do NOT decrement it. (Mirror of the F11 inventory problem, which WAS fixed; promo usage was not.)
**Risk:** A limited promo's `usage_count` is incremented when the order is *created*, even for a card order that is later declined/abandoned. There is no release. So abandoned orders permanently burn the promo allowance.
**Exploit:** Griefing — a competitor or bot places `usage_limit` orders with a merchant's limited promo and abandons them all (captcha-less), exhausting the promo so real customers see "promo no longer available." Also lets a single attacker consume the cap faster than legitimate use.
**Fix:** When the F11 restock fires (decline/auto_decline/void), also decrement the promo `usage_count` (idempotently, gated by the same `stock_released`/a new `promo_released` flag), OR — cleaner — only increment `usage_count` on the terminal success (confirm-with-paid), matching the loyalty fix (P1).

### P5 — MEDIUM — Anon caller can authorize a charge against any order UUID
**Location:** `supabase/functions/square-payment/index.ts:227-233` — `if (!isServiceRole && callerId) { …ownership check… }`. For an anonymous caller `callerId` is `null`, so the ownership block is skipped entirely; the comment says "anon guests pass." Same shape in `stripe-payment-intent`.
**Risk:** Guest checkout legitimately needs anon callers to pay, so a blanket anon block is impossible — but the current code lets ANY anon caller (who knows an order UUID — discoverable via `/order/:id` links/receipts) create or resume a payment authorization on that order with their OWN card token. The amount is server-read (`order.total_amount`), so there is no undercharge; the harm is: (a) a third party can PAY a victim's order (mark it paid / authorized with funds the victim didn't intend), and (b) a `square_payment_id`/`stripe_payment_intent_id` gets written onto an order the caller doesn't own, which then drives `order-respond`'s capture path.
**Exploit:** Attacker harvests an `/order/:id` UUID, calls `square-payment {order_id, source_id:<attacker card>}`. A real authorization lands on the victim's order against the attacker's card. Confusing at best; at worst a "pay then dispute/chargeback" or order-state-manipulation vector. Bounded by: amount is fixed, order must be non-terminal, and it charges the *attacker's* card.
**Fix:** Require the anon caller's session to OWN the order — bind the order's `customer_id` to the caller's anon `auth.uid()` (via `customer_id_for_user(org)`) even for anon, exactly as `create_order_with_inventory` does. An order placed by anon session A should only be payable by session A. Reject when the order's customer's `user_id` ≠ the caller uid (and the caller is not org staff/service-role).

### P6 — MEDIUM — AI functions: no cost cap, any-staff access
**Location:** `_shared/auth.ts:48-67` (`resolveCaller` resolves owner OR ANY `is_active` staff — no role filter), used by `ai-menu-copilot`, `ai-inventory-assistant`, `ai-campaign`, `ai-menu-import`, `ai-decline-reasons`. No per-org/day token budget, no call-rate limit, in any of them.
**Risk:** Every AI function calls Anthropic on each request with no per-org spend ceiling and accepts any active staff member — including kitchen/service roles whose only credential is a 6-digit PIN (brute-forceable per CARRY-F21/F30). A compromised or malicious low-trust staff account can loop the vision-enabled `ai-menu-copilot`/`ai-menu-import` (image+PDF ingestion = the most expensive calls) to run up unbounded Anthropic cost on the platform's key.
**Exploit:** Phish/guess a kitchen PIN → loop `ai-menu-import` with large images → platform Anthropic bill balloons; no per-org cap stops it.
**Fix:** (1) Add a per-org daily/monthly AI-call (or token) budget enforced in a shared helper before the Anthropic call, tracked in a small `ai_usage` table (mirror `increment_email_usage`). (2) Restrict the money-adjacent AI fns (`ai-menu-copilot`, `ai-inventory-assistant`, `ai-menu-import`) to `owner`/`manager` roles — add a role filter to `resolveCaller` or a per-fn check. (3) Cap `max_tokens` and input size per call.

### P7 — MEDIUM — `abuse_throttle` unbounded growth + fail-open + costly cap query
**Location:** `migrations/20260611040000:223-281` (`abuse_throttle` table + `rate_limit_hit`), `:375-385` (open-order cap query).
**Risk:** Three issues in the new throttle primitive: (a) `abuse_throttle` rows are **never pruned** — every distinct `(subject, action)` persists forever; the F12 anon faucet creates a new uid per session, so the table grows one row per anon order attempt = unbounded growth (a slow storage DoS that *amplifies* the very abuse it guards). (b) `rate_limit_hit` returns `false` (allow) on a null/empty subject — combined with any path where `auth.uid()` could be null, it fails OPEN. (c) The open-order cap (`:375-385`) joins `orders`→`customers` and filters `created_at > now() - 1 hour` with no supporting composite index on `customers(user_id)` + `orders(customer_id,status,payment_status)` → a heavy scan on every guest order.
**Exploit:** Loop fresh anon sessions placing orders → `abuse_throttle` grows without bound and the cap query slows every checkout. The fail-open on null subject means any future caller path that reaches the RPC without a uid is unthrottled.
**Fix:** (a) Prune `abuse_throttle` (a `DELETE WHERE window_start < now() - interval '1 day'` in the existing per-minute cron, or `ON CONFLICT` that also evicts old keys). (b) Decide fail-CLOSED for null subject on the anon path (the order RPC already rejects null `auth.uid()`, so this is defense-in-depth). (c) Add the supporting index. (And see P2 — the rollback issue makes the whole counter unreliable regardless.)

### P8 — MEDIUM — `set_refund_status` can resurrect a refunded order to `paid`
**Location:** `migrations/20260610050000_order_refunds.sql:352-366`. After recomputing `v_new_total` from money-moving refunds, it sets `payment_status = CASE WHEN v_new_total <= 0 THEN 'paid' …`.
**Risk:** If a refund that was counted as `pending`/`succeeded` is later flipped to `failed`/`canceled` by a provider webhook AND it was the order's ONLY money-moving refund, `v_new_total` becomes 0 and the order's `payment_status` is set back to `'paid'` with `refunded_at` cleared. For a genuinely-failed refund (the money never left), reverting to `paid` is correct. But the function does NOT verify the underlying CHARGE is still captured — if the order was fully refunded and the webhook is a spurious/duplicate `failed` for a refund that actually succeeded (provider eventual-consistency, or a forged-but-signed event under CARRY-F31's single-key model), the order silently re-enters GMV as `paid` despite the customer having the money back.
**Exploit:** Mostly a data-integrity / reconciliation risk under webhook races rather than a direct theft: a fully-refunded order can be nudged back to `paid` (re-inflating GMV + charity math) if a stale/failed refund webhook lands after the success. Low likelihood, real money-reporting impact.
**Fix:** Only revert to `paid` when the order's authoritative provider charge is still confirmed captured (re-read the provider, or never auto-revert a `refunded` order to `paid` from a webhook — leave it `refunded` and require an explicit re-charge). At minimum, gate the `<=0 → paid` branch on `v_order.payment_status NOT IN ('refunded')` unless a positive capture is re-verified.

### P9 — MEDIUM — Money-adjacent loyalty RPCs are schema-drift (not in any migration)
**Location:** `award_order_loyalty_points` (called by `customerAccount.ts:130`) and `adjust_loyalty_points` (referenced by `Loyalty.tsx`, and by the comments in `20260611020000:32,221`) exist ONLY on the live DB — neither appears in `supabase/migrations/`.
**Risk:** Two functions that mutate the redeemable `total_points` balance are **unversioned and unauditable from the repo**. The pass-1/-tonight loyalty self-edit guard (F6 fix) is explicitly designed around their behaviour ("owner/staff write where `auth.uid() <> customer.user_id` passes through"), but their actual bodies — including whether they validate org scope, bound the award, or are idempotent — cannot be reviewed here. P1's award-at-placement abuse depends on `award_order_loyalty_points`'s idempotency, which is unverifiable.
**Exploit:** None directly; this is a governance/assurance gap. If either RPC has a SECURITY DEFINER + missing org-scope bug, it would be invisible to every repo-based review (and the search_path sweep in `20260611020000:227-247` is the ONLY thing currently hardening them).
**Fix:** Dump the live definitions (`pg_get_functiondef`) and commit them as a migration so they are versioned + reviewable; then audit them for org-scope + idempotency + award bounds.

### P10 — LOW — `guard_order_payment_columns` leaves attribution/identity columns writable
**Location:** `migrations/20260611020000:148-181` pins `payment_status`, `payment_method`, `total_amount`, provider ids, refund cols — but NOT `customer_id`, `order_number`, `organization_id`, `line_items`, `shipping_address`, `notes`, `dine_in`, `table_number`.
**Risk:** A same-org staff/owner JWT can still rewrite `customer_id` (re-attribute an order to a different customer → loyalty/GMV-by-customer skew), `line_items` (rewrite what was ordered after the fact), or `notes`/`shipping_address` on an existing order via REST. Org-scoped (no cross-tenant), and most are legitimately editable in some flows, so this is low — but `customer_id` and `order_number` re-writes are integrity risks the guard doesn't cover.
**Fix:** If `order_number` and `customer_id` are meant immutable post-creation, pin them too in the same guard (set `NEW.order_number := OLD.order_number; NEW.customer_id := COALESCE(NEW.customer_id, OLD.customer_id)` or pin outright). Leave `line_items` editable only via a dedicated audited path if at all.

### P11 — LOW — F11 restock not wired into order DELETE
**Location:** restock helper `migrations/20260611040000:54-104` is invoked from `claim_order_for_response` + `void_my_unpaid_order` only; the order DELETE path is `src/services/api.ts:493` (`supabase.from("orders").delete()`), with no restock.
**Risk:** F11 (inventory-DoS) was fixed for decline/auto_decline/abandon, but a merchant (or a flow) deleting a stock-tracked `awaiting_confirmation`/`pending` order does NOT restock — the decrement leaks. Lower impact than the abandon loop (DELETE needs org-member auth), but it's the same inventory-leak class the migration set out to close.
**Fix:** Add a `BEFORE DELETE` trigger on `orders` that calls `restock_order_inventory(OLD.id)` for non-terminal orders that haven't released stock (respecting the `stock_released` flag), OR restock in the `removeOrder` API path.

### P12 — LOW — `order-respond` confirm email — interpolation review (currently safe)
**Location:** `order-respond/index.ts:485-581` (`buildConfirmHtml`). All dynamic values (`customerName`, `title`, `tableNumber`, `dateStr`, `orgName`, `orgAbn`, item titles/extras, `ref`) ARE passed through `escapeHtml` (which encodes `& < > " '`). The fulfillment/payment labels are looked up from fixed maps.
**Risk:** No injection today — verified every sink is escaped. Flagged only as a latent note: `fulfillmentType` and `paymentStatus` fall through to the raw value when not in the label map (`fulLabel[...] ?? p.fulfillmentType`), and those raw values reach `escapeHtml`, so still safe. Kept as a watch-item if a future free-text field (e.g. a planned `order_source`) is interpolated unescaped (this is pass-1 F33's docket sibling).
**Fix:** None required now. Keep the invariant "every interpolated value goes through `escapeHtml`" and add a test.

### P13 — LOW — Throttle keyed on uid only — anon-session rotation bypass
**Location:** `migrations/20260611040000:367` (`rate_limit_hit(v_auth_uid::text, 'place_order', …)`) + `:619` (reservations).
**Risk:** The fixed-window throttle keys solely on `auth.uid()`. Each fresh `signInAnonymously` returns a NEW uid, so a bot that mints a new anon session per order resets its bucket every time — the per-uid throttle does nothing against the exact attack (CARRY-F12) it's meant to slow. There is no IP/device key (the DB can't see the real client IP reliably).
**Fix:** This is why pass-1 made captcha the front line; the DB throttle is only a backstop against a single session looping. Add an edge/Cloudflare per-IP rate-limit (the real fix) and gate anon sign-in behind Turnstile so fresh-uid minting is itself rate-limited.

### P14 — LOW — `void_my_unpaid_order` vs `order-respond` confirm race (benign, restock side-effect)
**Location:** `migrations/20260611040000:171-204` (customer void) and `order-respond` claim (`claim_order_for_response`). Both compare-and-swap on `status='awaiting_confirmation'`, so exactly one wins — correct. The note: if the owner clicks Confirm at the same instant the customer's card-dialog-close fires `void_my_unpaid_order`, whichever CAS commits first wins; the loser no-ops.
**Risk:** Correct exclusivity (no double-charge, no double-restock). The only oddity: a customer can void an order the owner is about to confirm, and the void RESTOCKS — if the kitchen had already started, the inventory count is restored while food is being made. Bounded and unlikely; included for completeness.
**Fix:** None strictly needed (CAS is correct). Optionally, only allow `void_my_unpaid_order` within a short window after placement, or block it once `confirmed_at` work is in flight.

### P15 — LOW — Customer can still tamper own consent/opt-out state
**Location:** `migrations/20260611020000:64-67` — the F6 loyalty guard pins `total_points`/`milestone_spend_cents` only; it deliberately does NOT pin `marketing_opt_in`, `email_opted_out`, `sms_opted_out`, `saved_addresses`, `email_consent_at`, `sms_consent_at`.
**Risk:** A logged-in customer can `PATCH /rest/v1/customers?user_id=eq.<self>` to set `email_opted_out=false` / fabricate a `*_consent_at` timestamp / change `saved_addresses` on their own row. Self-only (no cross-customer), but it lets a customer forge their own consent record (a Spam-Act compliance integrity issue — the merchant relies on `*_consent_at` as proof of consent) and re-subscribe themselves after opting out.
**Fix:** Pin the consent/opt-out columns in the same self-edit guard EXCEPT when the write comes through `upsert_my_consent` (which is SECURITY DEFINER but runs with the caller's `auth.uid()` non-null). Distinguish via a session GUC the RPC sets, or move all consent writes exclusively through `upsert_my_consent` and pin the columns for direct REST writes. (This is the consent half of pass-1 F19.)

---

## 3. Carried-over PASS-1 findings still OPEN (documented, not fixed)

These were in pass-1; I re-verified they are NOT addressed by tonight's commits. Listed so the founder has a single current list — see pass-1 doc for full detail/exploits/fixes.

- **CARRY-F1/F2 (CRITICAL, operational):** leaked `ghp_` PAT in `.git/config`, pasted `sbp_` admin token, plaintext Square OAuth tokens in `square_connections`. **Rotation is the only fix and is still pending.** Highest priority.
- **CARRY-F19 (MEDIUM):** `upsert_my_consent` still auto-claims unclaimed CRM rows by email/phone (`20260608010000:146-183`) → within-tenant identity takeover. The loyalty guard explicitly deferred this.
- **CARRY-F20 (MEDIUM):** `lookup_email_for_username` anon email leak + `customer-signup` 409 oracle — unchanged.
- **CARRY-F21/F30 (MEDIUM/LOW):** `validate_loyalty_code` brute-force + returns email; `staff-pin-login verify_user` enumeration oracle — unchanged. (`get_member_org` staff-branch over-exposure WAS fixed tonight in `20260611030000`.)
- **CARRY-F22 (MEDIUM):** `account-recover` 200-owner cap + unsalted answers + spoofable XFF — unchanged.
- **CARRY-F14 (MEDIUM):** owner can fabricate `donation_ledger` / `total_donations_cents` — the org-payment guard pins payment cols but NOT donation cols; unchanged.
- **CARRY-F24/F25 (MEDIUM):** demo-mode lost-order bug + `?demo=` arming on any host — `api.ts`/`demoBootstrap.ts` show NO `getTenantSlug`/`disableDemo` guard added; unchanged.
- **CARRY-F23 (MEDIUM):** AI prompt-injection — pass-1 added data-fencing in `c5fb166`; the residual is the cost/role gap re-raised here as **P6** (different angle).
- **CARRY-F28 (LOW):** Stripe idempotency key omits amount (Square folds it in) — unchanged. Latent.

---

## 4. Audit of tonight's NEW code (pass-1 remediation) — introduced-bug review

I reviewed every file changed in `c28098b`…`68f8c13` for regressions to the working charge/capture/refund/storefront/guest-checkout flow. **No HIGH/CRITICAL regression found.** The remediations are correct. Notes:

**SOUND (verified, no regression):**
- `20260611010000` F4 server-authoritative `initial_status` — correctly forces `awaiting_confirmation` for untrusted card orders, honours only `pending`/`awaiting_confirmation` for non-card, and leaves trusted POS (`v_is_org_member`) full control. Pricing/floor/promo/inventory blocks are byte-identical to C1. The "pay-at-venue on a card-enabled merchant" case is handled MORE conservatively (forced `awaiting_confirmation`), matching the client. ✓
- `20260611020000` guard triggers — the trust model (`auth.uid() IS NULL` = trusted service path) is correct. `record_order_refund`/`set_refund_status`/`claim_order_for_response`/webhooks all run service-role (uid NULL) → pass through; REST writes (uid non-null) → pinned. Verified the frontend's only order UPDATE (`api.ts:433 updateStatus`) writes `status` (NOT pinned), so kanban moves are unaffected. The `Managers view customers` policy swap correctly preserves owner+manager read while dropping kitchen/service. ✓
- `20260611030000` re-mask — `get_public_storefront` now merges the publish-gate JOIN with the full denylist (security_questions, contact_email, square_*, counters all nulled); `get_member_org` staff branch closed; `get_order_by_id` nulls `notes`. Verified column set matches the drift-validated set. ✓ (Closes F3 — the most dangerous pass-1 finding.)
- `20260611040000` F11 restock — the compare-and-swap on `orders.stock_released` (single-statement CAS) is a correct idempotency anchor; restock is correctly tied to the decline/auto_decline branch inside `claim_order_for_response` (same txn as the status flip) and to the actually-voided branch of `void_my_unpaid_order`. No double-restock. ✓
- `order-respond` — claim-before-capture (BLK-1), provider-from-order-row (H-1), amount-match capture guards (H-3) for both Stripe and Square are correct and preserved. ✓
- `square-payment` — F15 server-side `online_card_enabled` gate added; per-org OAuth (BLK-2); terminal-state + amount-drift guards correct. ✓
- Storage buckets (`product-images`, `branding-assets`) — INSERT/UPDATE/DELETE all scoped to `(storage.foldername(name))[1] = current_org_id()` (migrations `20260528115310`/`131845`/`20260512112737`). Anon (`current_org_id()` NULL) cannot write. **Not a finding** — pass-1 didn't cover Storage; confirmed sound here.
- Realtime — anon `OrderStatus` correctly POLLS (no anon realtime on `orders` after lockdown); KDS realtime runs in org-scoped auth. Sound.

**BUGS INTRODUCED / WEAKNESSES IN THE NEW CODE (raised above):**
- **P2** — the new DB rate-limit is defeated by transaction rollback (the F12 server backstop is unreliable).
- **P7** — the new `abuse_throttle` table is unbounded-growth + fail-open on null subject.
- **P13** — the new throttle keys on uid only (anon-rotation bypass) — captcha remains the real boundary.
- **P4** — F11 restock was added for inventory but the *parallel* promo `usage_count` consume was NOT released (asymmetry introduced by fixing only inventory).
- **P11** — F11 restock not wired into order DELETE.

None of these break the working flows; they are gaps/weaknesses in the new defensive code rather than regressions to charge/capture/refund.

---

## 5. Supply-chain / process (quick)

- **No lockfile-pinned CI / no `postinstall` audit.** Repo still has no `.github/`, no `.husky/`, no gitleaks (pass-1 F26) — re-confirmed. `package-lock.json`/`bun.lockb` present but unverified against advisories here. No `postinstall` script was found in `package.json` scanning (good — none to abuse), but there is no `npm audit`/`osv-scanner` gate. **FOUNDER-INPUT:** add the gitleaks pre-commit + a CI `npm audit --production` / `osv-scanner` gate (pass-1 roadmap item 23).
- Edge functions pin esm.sh versions (`@supabase/supabase-js@2.45.0`, `stripe@17.3.0`) — good; no floating `@latest`.

---

## 6. Prioritized actions (PASS 2 delta only)

**Do first (money/abuse integrity):**
1. **P1** — stop awarding loyalty points at placement; award on confirm-with-paid only, reverse on refund. (HIGH, loyalty economy.)
2. **P5** — bind anon payment authorization to the order's owning anon session. (MEDIUM, cross-customer charge.)
3. **P2 + P13** — recognise the DB rate-limit is not a reliable boundary; ship the Cloudflare/edge per-IP limit + enable Turnstile (CARRY-F12 FOUNDER-INPUT). The DB throttle stays as defense-in-depth after P7's prune/fail-closed fix.
4. **P3 + P4** — add per-customer promo limit + release promo usage on non-success (or consume on success only — pairs with P1).

**This week:**
5. **P6** — per-org AI cost cap + restrict money-adjacent AI fns to owner/manager.
6. **P8** — don't auto-resurrect a `refunded` order to `paid` from a webhook without re-verifying capture.
7. **P7** — prune `abuse_throttle` + fail-closed null subject + add the supporting index.
8. **P9** — commit the drift loyalty RPCs as migrations and audit them.

**Backlog (LOW + carried):**
9. **P10/P11/P12/P14/P15** — guard attribution columns, restock on DELETE, keep the email-escape invariant, consent-column pinning.
10. **CARRY set** — rotate credentials (CRITICAL, still pending), F19 consent claim, F20/F21/F22 enumeration/recovery, F24/F25 demo mode, F14 donation fabrication.

---

## 7. Bottom line

Tonight's pass-1 remediation is **genuinely good** — the three CRITICALs (leaked-mask F3, sandbox-token F9, online-card gate F15) and the HIGH set (F4 status, F5 webhook org-bind, F6/F7/F16 write-guards, F11 restock) are correctly implemented with sound trust models and idempotency, and they do not regress the charge/capture/refund/guest-checkout flow.

PASS 2's net-new risk is concentrated in **business-logic abuse the money-path hardening didn't touch**: loyalty points and promo usage are both granted at *placement* and never reversed (P1/P4), promos have no per-customer cap (P3), and the new server-side rate-limit is undermined by transaction rollback + uid-only keying + unbounded growth (P2/P7/P13) — so **captcha (the FOUNDER-INPUT front line) is doing more of the load-bearing work than the DB throttle implies.** None are cross-tenant data theft; the dominant theme remains within-tenant integrity + the captcha-less anon faucet amplifying everything. Plus the still-pending **credential rotation** (CARRY-F1/F2) remains the single highest-priority operational item.
