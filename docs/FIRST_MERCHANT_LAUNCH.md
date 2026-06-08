# First-Merchant Launch — readiness + FOUNDER HANDOFF

> **Living doc — updated continuously during the 2026-06-08 autonomous run.**
> Goal: a first restaurant merchant fully onboardable on **`name.woahh.app`** with
> **CRM + cloud POS + online ordering (incl. online card payments)** — everything we
> say is functional *actually* functional. Branches + preview only; **merge to main
> only after the restaurant approves.** Crash-recovery: read this + memory
> `woahh-overnight-3goals` + `docs/OVERNIGHT_PLAN_2026-06-07.md`.

## Mission (6h autonomous, founder away)
1. Finish **guest checkout** (anon-auth + email/T&C/marketing consent + account nudge).
2. **C1 — server-side order-total validation** so **online card payments are safe + functional** (no more client-trusted total).
3. Verify **CRM + cloud POS + online ordering + payments** are genuinely functional (hard E2E).
4. **Website redesign preview** running (6 directions) on its branch — not merged.
5. This **FOUNDER HANDOFF** ready: every migration (in order) + Supabase/Stripe/Cloudflare action you must do, + the merchant-onboarding steps.
6. Keep committing + pushing; docs current.

---

## ⚡ FOUNDER ACTIONS WHEN YOU'RE BACK (the to-do list)

> Run in this order. Each item links to where the SQL/steps live. ✅ = ready, ⏳ = being prepared.

> 🟢 **CONVENIENCE: `docs/FOUNDER_RUN_THESE.sql`** bundles migrations #2 + #3 (the two NEW ones) in order — paste that ONE file into the Supabase SQL editor, then regenerate types. (The 3 storefront migrations are already applied.)

### A. Database migrations (Supabase SQL editor, in order)
1. ✅ **Storefront config** (DONE — you ran these): `20260603010000` → `20260603020000` → `20260607010000`.
2. ✅ **Guest-checkout consent** — READY to run: `repo-audit/supabase/migrations/20260608010000_guest_checkout_consent.sql` (adds `customers.tos_accepted_at`/`tos_accept_method` + the `upsert_my_consent` SECURITY DEFINER RPC). Verified its `ON CONFLICT` index (`customers_org_user_uidx`) exists. Build done + pushed (`581bbad`). Needs **B (anon sign-ins)** enabled to function.
3. ✅ **C1 — server-side order-total validation** — READY to run: `repo-audit/supabase/migrations/20260608020000_c1_server_side_order_total.sql`. Recomputes the authoritative item subtotal+promo server-side and REJECTS a client total below that floor (untrusted guest/customer callers only; trusted POS skipped so comps work). **Required before taking real cards.** Adversarial-reviewed (correctness/bypass/regression) → **safe to apply; blocks the catastrophic undercharge (1¢-for-$80); byte-for-byte identical otherwise; idempotent.** Pushed `a981b89`.
   - **After applying: TEST before enabling real cards** — place a few real orders (guest + signed-in, pickup + delivery, with/without a promo) and confirm the charged total matches what the customer saw. Then enable card acceptance.
   - **Known residuals (bounded, documented in the migration; v2 hardening, not blockers):** (a) *fee-skip* — a deliberately-tampered client could drop the 1% service / delivery fee from its own charge (item revenue is always protected); (b) *promo-race / sale-window-expiry* false-reject if a code/sale lapses while the item sits in the cart. **v2 = full server-authoritative total incl. server-computed fees** (closes both) — recommended before broad scale; fine for the first pilot.
4. ⏳ After all migrations: **regenerate types** — `npx supabase gen types typescript --project-id pmnyhbhtkcfoozkinieo > src/integrations/supabase/types.ts` (or Dashboard → API → generate). Clears the `as any` casts + the 8 pre-existing tsc errors.

### B. Supabase Auth settings (Dashboard → Authentication)
- ⏳ **Enable Anonymous sign-ins** (Providers) — required for guest checkout.
- ⏳ **Enable bot protection** (Turnstile/hCaptcha) on the same screen — guards anon-sign-in abuse.
- For `name.woahh.app` later: add `https://*.woahh.app/**` to the redirect allow-list.

### C. Stripe (online payments)
- ⏳ Confirm Connect Express is live + the merchant is onboarded (Connect onboarding link). *(Details after the payments pass.)*
- Local/preview testing of cards needs `VITE_STRIPE_PUBLISHABLE_KEY` in the env (prod already has `pk_live`).

### D. name.woahh.app (when ready to go live for the merchant)
- See `docs/MERCHANT_ONBOARDING_RUNBOOK.md` — Cloudflare DNS + Pages custom domain + TLS + the guarded `subdomain_slug` SQL.

### E. Create the first merchant account (you said you'll do this with me)
- We'll create the org, import the menu (AI import), set branding, pick a template, publish, set the slug, and verify end-to-end together.

---

## STATUS (functional vs pending)
| Capability | State |
|---|---|
| Storefront templates (8) | ✅ render live (migrations applied); preview at `/storefront-preview` |
| Bespoke template publish → live render | ✅ verified (maison/kerb on test-bistro) |
| Cloud POS (walk-in) + KDS | ✅ verified functional |
| Online ordering (menu→cart) | ✅ verified (default + bespoke) |
| Guest checkout | 🔧 built + UI-verified, but an adversarial review found real bugs (phone-collision crash, returning-anon misclassified → T&C dropped, magic-link orphaned the order, email-dup, card-capture gate). **Being fixed + re-verified now** (`wi1ap0hqw`) before it's "functional". |
| Online card payments | ✅ safe to enable after migration #3 applied + tested (C1 done; charge path reads server order total); needs Stripe Connect live + the test pass |
| CRM | ⏳ to verify this run |
| Website redesign (6 directions) | ✅ built/pushed; preview on `feat/marketing-home-redesign` |

## ✅ VERIFIED THIS RUN (headless-chromium E2E vs LIVE test-bistro)
- **CRM** — Customers page lists customers (name/email/phone/marketing opt-in), Bulk SMS + Email broadcast, Invite-customer; order→customer linkage works (a test order created the "pawit · GH" customer).
- **Cloud POS** — "New walk-in order" dialog (menu + Counter/Dine-in/Takeaway + discount/tax/tip + Charge) + KDS kanban + a completed walk-in order.
- **Online ordering (menu→cart)** — default + bespoke; add-to-cart + cart sheet work.
- **Bespoke storefront render** — published maison/kerb → `/shop/test-bistro` renders the bespoke template with the live menu.
- **Guest checkout UI** — Contact step shows Name/Phone/**Email (for receipt)** + **required Terms checkbox** + **optional "Email me deals… unsubscribe anytime"** + "Sign in for deals" (optional). **No forced sign-in.** (Order *placement* is gated on B-anon-auth + #2 below.)

## ⏳ NEEDS YOUR ACTION, THEN VERIFY (post-apply checklist)
After you run `FOUNDER_RUN_THESE.sql` + enable anonymous sign-ins (+ Turnstile) + regen types:
1. **Guest order places** — on `/shop/<slug>`: add item → checkout → email + tick T&C → Place order → expect an order at `awaiting_confirmation` + a "create an account" nudge; confirm it appears in Kitchen Orders. (Ping me — I'll E2E it.)
2. **C1 totals correct** — place a few orders (guest + signed-in, pickup + delivery, ±promo) and confirm the charged total == what the customer saw, and that a tampered low total is rejected. **Only after this passes, enable real card acceptance.**
3. **Consent captured** — the guest's email + marketing opt-in shows in the merchant CRM.

## Website redesign preview (Goal 2)
- Branch `feat/marketing-home-redesign` (pushed). Review the **6 directions × home/marketplace/dashboard** at `/home-preview` on its Cloudflare branch preview. **Not merged** — pick a direction; I'll build the winner for real.

## Note: test-bistro state
- The test merchant is currently **published on the `kerb` template** (from this run's testing). To revert it to the default storefront: dashboard → Storefront → unpublish (or `UPDATE storefront_config SET is_published=false WHERE organization_id=(test-bistro)`). Harmless; it's the test merchant.

## Fixes already shipped this run (branch `feat/storefront-platform`)
- `da3140b` storefront fail-safe (Stripe guard + getPublic 404) · live-wiring `7a573e4` · (more below as they land).

## LIVE LOG (append per milestone)
- [2026-06-08] 6h mission started; guest-checkout build running (`weex56az3`).
- [2026-06-08] ✅ Guest checkout DONE + pushed (`581bbad`): both storefronts, email+T&C+marketing, anon-auth, account nudge, preview inert, C1 honored. Migration #2 ready.
- [2026-06-08] ✅ C1 server-side total validation DONE + pushed (`a981b89`); adversarial-reviewed safe; migration #3 ready (test before real cards). NEXT: verify CRM + guest-checkout UI; confirm website preview; finalize handoff.
