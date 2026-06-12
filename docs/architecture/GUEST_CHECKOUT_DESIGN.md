# Guest Checkout — Decision-Ready Design

> **Status:** Proposed (decision-ready). 2026-06-08.
> **Scope:** Add a true *guest* checkout (email receipt + T&C accept + marketing opt-in + account nudge) that works on BOTH the default `RestaurantStorefront` AND the bespoke `ThemeShell`/`screens/Checkout.tsx`. Returning customers can still sign in.
> **Hard constraints:** Do NOT weaken the order RPC's security hardening. Do NOT enable real card capture (the **C1 hold** — server-side order-total recompute — stands). Apex/default behaviour stays unchanged for users who don't checkout.
> **Source of truth:** Built on the three verified maps (order-rpc, customer-consent, anon-auth). File:line refs in this doc were re-verified against `/workspaces/GrowthHub/repo-audit` on 2026-06-08.

---

## 0. The problem in one paragraph

Today BOTH storefronts **force sign-in before placing an order**:
- Default: `RestaurantStorefront.tsx:449-457` `openCheckout()` → `if (!customerUser) setCheckoutStep("auth")`.
- Bespoke: `screens/Checkout.tsx:182-224` `usePlaceOrder()` → `if (!customerSignedIn) requestAuth()` (a forced sign-in gate added in a prior pass; the file comments even assert "there is NO guest checkout").

Both do this because `create_order_with_inventory` (the SECURITY DEFINER order RPC) raises `"Sign in is required to place an order"` when `auth.uid() IS NULL` (final RPC `supabase/migrations/20260601093000_harden_order_customer_and_receipts.sql:105-113`). A truly unauthenticated `anon`-key REST call has a NULL `auth.uid()` and is rejected. So "guest checkout" needs the guest to carry a **non-null** `auth.uid()` without making them create a real account.

---

## 1. Recommended mechanism — **Supabase Anonymous Auth** (not RPC-relax)

**Decision: mint a Supabase anonymous session (`signInAnonymously`) before the guest hits the order RPC. Do NOT relax the RPC.**

### Why anon-auth wins
| | Anonymous Auth (CHOSEN) | RPC-relax (`anon` role + email in payload) |
|---|---|---|
| Order RPC change | **None.** Anon user has a real `auth.uid()` + the `authenticated` Postgres role; the existing `auth.uid() IS NOT NULL` gate passes untouched. | Must `GRANT EXECUTE … TO anon` + move ALL trust (tenant resolution, total recompute, rate-limit, dedup) into the function body. New anonymous write path into multi-tenant `orders`. |
| Auth invariant | **Preserved** — one rule ("a real uid writes orders") for every caller. | **Broken/forked** — "real users" vs "trusted-payload guests". |
| Account nudge / upgrade | First-class: `updateUser({email})` → verify → `updateUser({password})`, or `linkIdentity()`. **User id is stable**, so the guest's `customers` row + `orders` carry over with zero migration. | No identity → orphaned order; later email-match merge by hand. |
| Abuse protection | Supabase's built-in IP rate-limit (30/hr/IP default) + CAPTCHA on the sign-in endpoint. | Re-implement by hand on the RPC. |
| Cost | `auth.users` accumulation (solved by a cleanup cron — §6). | Avoids accumulation, but at the cost of all the above. |

The maps confirm anon-auth is *unworkable-free*: an anon user is "just an `authenticated`-role user flagged `is_anonymous = true`", `customer_id_for_user(p_org_id)` returns NULL for it → the order is inserted with `customer_id = NULL` (already a valid state, RPC lines 110/165/176), and the order is trackable via `receipt_token` (anon-safe, RPC `get_order_by_id` lines 23-65). **No RPC change, no new RLS surface, no new `anon` grant.**

### THE SINGLE FOUNDER/INFRA ACTION REQUIRED
> **Enable Anonymous sign-ins in Supabase Auth settings** for project `pmnyhbhtkcfoozkinieo`:
> Dashboard → Authentication → Providers → toggle **Anonymous sign-ins** ON.
>
> Strongly recommended at the same time (same screen / Bot-and-Abuse-Protection): turn on **Cloudflare Turnstile (or hCaptcha)** so anon sign-ins require a `captchaToken`. We already use Cloudflare, so Turnstile is the natural pick. *(Local dev: add `enable_anonymous_sign_ins = true` under `[auth]` in `supabase/config.toml` — there is currently NO such key.)*

Everything else in this design is repo code/migration — no other human/infra step except the optional wildcard-unrelated cleanup cron (§6) and (later) `linkIdentity` requires "Manual linking" enabled in Auth settings.

---

## 2. Data / consent model

### What columns already exist on `customers` (verified — no schema gap for email/marketing)
From `types.ts:219-258` + the consent migrations:
- `email` (nullable) — the receipt email.
- `marketing_opt_in boolean NOT NULL DEFAULT false` — the marketing flag.
- `email_consent_at timestamptz` / `email_consent_method text` / `email_opted_out boolean` / `email_opted_out_at timestamptz` / `email_unsubscribe_token uuid` — **email** consent audit (migration `20260420042943`).
- `sms_consent_at` / `sms_consent_method` / `sms_opted_out` / `sms_opted_out_at` — **SMS** consent audit (migration `20260420035346`).
- `user_id uuid` (nullable) — links to the (anon or permanent) auth user via the partial unique index `(organization_id, user_id) WHERE user_id IS NOT NULL`.

### The ONE gap: Terms & Conditions acceptance
There is **no `tos_accepted_at` / `terms_accepted` column on `customers`** — those fields exist only on `organizations` (the merchant). The founder spec requires the guest to **accept T&C**. Two acceptable options:

- **Option A (recommended — explicit + auditable):** add a small migration with two columns.
- **Option B (zero-migration):** treat "placed an order" as implicit T&C acceptance and only show the checkbox in the UI (legally weaker; the checkbox state isn't persisted). **Not recommended** — the whole point is an auditable consent trail like the SMS/email columns already give us.

#### Migration (Option A) — `supabase/migrations/20260608000000_customer_tos_acceptance.sql`
```sql
-- Guest/customer T&C acceptance audit trail (mirrors the email/sms consent columns).
-- Presentation-neutral; written by the same SECURITY DEFINER consent RPC used at
-- checkout. No RLS change: customers table policies are unchanged.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS tos_accepted_at  timestamptz,
  ADD COLUMN IF NOT EXISTS tos_accept_method text;   -- e.g. 'checkout_checkbox'
COMMENT ON COLUMN public.customers.tos_accepted_at IS
  'When this customer accepted the merchant/Woahh terms (guest checkout or account create).';
```
After applying: regenerate `src/integrations/supabase/types.ts`.

### Consent values written at guest checkout
| Field | Value at guest checkout | Source/method string |
|---|---|---|
| `email` | the email the guest typed (receipt) | — |
| `name` | guest name (fallback `email.split('@')[0]`) | — |
| `user_id` | the anon `auth.uid()` | — |
| `tos_accepted_at` | `now()` (T&C box ticked — **required to place order**) | `tos_accept_method = 'checkout_checkbox'` |
| `marketing_opt_in` | `true` **only if** the marketing box is ticked, else `false` | — |
| `email_consent_at` | `now()` if marketing ticked, else NULL | `email_consent_method = 'checkout_checkbox'` |
| `email_opted_out` | `false` | — |
| `sms_consent_at` / `sms_consent_method` | `now()` / `'checkout_checkbox'` if the (existing) SMS box is ticked + phone given | — |

> **Stop hardcoding `marketing_opt_in: true`.** Today `ensureExists` (`customerAccount.ts:62-80`) hardcodes `marketing_opt_in: true` with **no timestamp** — a Spam-Act gap. The new consent path must (a) derive `marketing_opt_in` from the actual checkbox and (b) stamp `email_consent_at`/`email_consent_method` whenever it sets the flag true.

### The RLS hazard this design fixes (load-bearing)
The current guest SMS-consent write is a **direct `customers` upsert through the customer client** (`RestaurantStorefront.tsx:603-612`). Every `customers` RLS policy requires org membership OR `user_id = auth.uid()`; **there is no anon/public INSERT or UPDATE policy on `customers`**. So for a real guest (anon or no session) that upsert is **silently RLS-rejected** and the consent is dropped (the failure is swallowed by the surrounding `try/catch`).

Because we are now minting an anon session, the guest's `auth.uid()` is non-null — but it still won't match an *existing* row's `user_id` for an upsert-by-phone, and the self-policy is `WITH CHECK (user_id = auth.uid())`, so a plain client upsert remains fragile. **The robust fix is to mirror the `accept_customer_invite` pattern: a single SECURITY DEFINER RPC that performs the consent upsert** (so the write is keyed to the caller's `auth.uid()` server-side and never depends on a public table policy).

#### Consent RPC — `supabase/migrations/20260608000100_upsert_guest_consent.sql`
```sql
-- One SECURITY DEFINER entry point for guest/customer consent at checkout.
-- Mirrors accept_customer_invite (20260530090000): the function — not a public
-- RLS policy — owns the write, keyed to the CALLER's auth.uid(). Idempotent on
-- (organization_id, user_id). Never elevates beyond the caller's own row.
CREATE OR REPLACE FUNCTION public.upsert_my_consent(
  p_org_id        uuid,
  p_name          text,
  p_email         text,
  p_phone         text DEFAULT NULL,
  p_tos           boolean DEFAULT false,
  p_email_opt_in  boolean DEFAULT false,
  p_sms_opt_in    boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id  uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sign in is required';      -- anon session still has a uid; truly-null is rejected
  END IF;
  IF p_tos IS NOT TRUE THEN
    RAISE EXCEPTION 'Terms must be accepted';   -- T&C is mandatory to create a consent row
  END IF;

  INSERT INTO public.customers (
    organization_id, user_id, name, email, phone_number,
    tos_accepted_at, tos_accept_method,
    marketing_opt_in,
    email_consent_at, email_consent_method, email_opted_out,
    sms_consent_at,   sms_consent_method,   sms_opted_out
  ) VALUES (
    p_org_id, v_uid,
    COALESCE(NULLIF(trim(p_name), ''), split_part(p_email, '@', 1)),
    NULLIF(trim(p_email), ''), NULLIF(trim(p_phone), ''),
    now(), 'checkout_checkbox',
    p_email_opt_in,
    CASE WHEN p_email_opt_in THEN now() END,
    CASE WHEN p_email_opt_in THEN 'checkout_checkbox' END,
    false,
    CASE WHEN p_sms_opt_in AND p_phone IS NOT NULL THEN now() END,
    CASE WHEN p_sms_opt_in AND p_phone IS NOT NULL THEN 'checkout_checkbox' END,
    false
  )
  ON CONFLICT (organization_id, user_id) WHERE user_id IS NOT NULL
  DO UPDATE SET
    name             = COALESCE(NULLIF(trim(EXCLUDED.name), ''), customers.name),
    email            = COALESCE(EXCLUDED.email, customers.email),
    phone_number     = COALESCE(EXCLUDED.phone_number, customers.phone_number),
    tos_accepted_at  = COALESCE(customers.tos_accepted_at, EXCLUDED.tos_accepted_at),
    tos_accept_method= COALESCE(customers.tos_accept_method, EXCLUDED.tos_accept_method),
    marketing_opt_in = customers.marketing_opt_in OR EXCLUDED.marketing_opt_in,
    email_consent_at = COALESCE(customers.email_consent_at, EXCLUDED.email_consent_at),
    email_consent_method = COALESCE(customers.email_consent_method, EXCLUDED.email_consent_method),
    sms_consent_at   = COALESCE(customers.sms_consent_at, EXCLUDED.sms_consent_at),
    sms_consent_method = COALESCE(customers.sms_consent_method, EXCLUDED.sms_consent_method),
    updated_at       = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_my_consent(uuid,text,text,text,boolean,boolean,boolean)
  TO anon, authenticated;
```
> This RPC is **additive** — it does not touch the `customers` RLS policies, the order RPC, or any existing function. It only ever writes the caller's own (org, uid) row. A guest who opts OUT of marketing still gets a row (so the order can be linked + receipt-emailed), with `marketing_opt_in = false` and no consent timestamp.

---

## 3. Checkout UX (identical intent on default + bespoke)

### Guest flow (no account required)
1. Build cart (fully public — unchanged).
2. Tap **Place order** → checkout panel opens (NO forced sign-in gate).
3. Contact fields: **Name**, **Email** (required — "for your receipt"), Phone (optional), delivery address / table # as today.
4. **Two checkboxes:**
   - ☑ **T&C (required)** — "I agree to the [Terms](…) and [Privacy Policy](…)." Place-order button disabled until ticked.
   - ☐ **Marketing (optional, pre-unchecked)** — "Email me deals & updates from {org.name}. Unsubscribe anytime." (The existing SMS opt-in checkbox stays as-is, gated on a phone being entered.)
5. **Place order** → order is created (see §4). No card capture (C1 hold).
6. **Post-order nudge (push, not force):** `PostPurchaseModal` opens for guests — "Create an account for deals / track your order / 1-click reorder." Skippable ("Skip — I'll just check out"). On skip → redirect to `/order/:receipt_token`.

### Returning customer
A small, low-emphasis **"Sign in"** link at the top of the checkout panel (and the cart) opens `CustomerAuthDialog` (default: the existing `"auth"` step; bespoke: the existing `requestAuth()` dialog). Signing in pre-fills email + links the order to their existing `customers` row + earns loyalty — exactly today's behaviour. The difference is sign-in becomes **optional**, not a gate.

### Why the UX is "the same" across both surfaces
The *intent* (email + T&C + marketing + nudge + optional sign-in) is identical; the *presentation* differs because the surfaces differ:
- Default = the `shadcn` Dialog at `RestaurantStorefront.tsx:1438-1613`.
- Bespoke = the themed `screens/Checkout.tsx` Contact step (`ContactStep`, lines 616-687) styled on theme tokens.
Both reuse the **same** `PostPurchaseModal` (default already mounts it at lines 1616-1628; bespoke gets the same component mounted in the `OrderConfirmed` success state) and the **same** `CustomerAuthDialog` for the optional sign-in.

---

## 4. Order placement (how a guest order satisfies the RPC)

### The exact sequence (both surfaces, in `submitOrder` / the `placeOrder` bridge)
```text
1. ensure anon session:
     const { data } = await customerSupabase.auth.getSession();
     if (!data.session) await customerSupabase.auth.signInAnonymously({ options: { captchaToken } });
     // now customerSupabase has a non-null auth.uid() (authenticated role, is_anonymous=true)

2. record consent + get/create the customers row (SECURITY DEFINER, keyed to that uid):
     const customerId = await supabase.rpc("upsert_my_consent", {
       p_org_id: org.id, p_name, p_email, p_phone,
       p_tos: true, p_email_opt_in: marketingOptIn, p_sms_opt_in: smsOptIn,
     });   // throws if T&C not accepted

3. place the order (UNCHANGED call — already passes client: customerSupabase):
     const order = await orderApi.createTest(org.id, customerId, totalCents, { …, client: customerSupabase });
     // RPC: auth.uid() != NULL  → passes the gate.
     // Branch 2 (non-org-member): customer_id_for_user(org) now RETURNS the row we just
     //   created (user_id = this uid), so p_customer_id == that id → no mismatch raise.
     // Order is created linked to the guest's anon-backed customer row.

4. redirect to /order/{order.receipt_token ?? order.id}   (already the code today)
```

> **Note:** Step 2 makes `customer_id_for_user(org)` return a non-null id for the guest, so we can pass `p_customer_id = customerId` and the order is **linked** (enables loyalty + later carry-over on account upgrade). If we ever choose a fully-anonymous order with no CRM row, pass `p_customer_id = NULL` — the RPC accepts that too (lines 110/165). The linked path is preferred because it makes the account-upgrade carry-over automatic.

### Email-already-registered edge case
The guest types an email that already belongs to a **permanent** account:
- **At checkout:** harmless — `upsert_my_consent` keys on `(org, anon-uid)`, NOT on email (there is no `(organization_id, email)` unique index), so it creates a *separate* guest row tied to the anon uid. The order still completes. No conflict, no error.
- **At account upgrade (the nudge):** this is where it matters. The Supabase in-place upgrade (`updateUser({email})` / `linkIdentity`) will **conflict** if that email already has a permanent account. Handle it with an explicit branch in the nudge: "This email already has an account — **sign in to merge**." On sign-in, the returning account's `customers` row is the canonical one; the anon-session guest row (and its order) can be reconciled later (§6 future) or simply left (the order is still trackable by receipt token and visible to the merchant). **Do not auto-merge in v1.**

### Receipt access via `receipt_token`
Unchanged and already correct: every post-order redirect uses `order.receipt_token ?? order.id` (default `RestaurantStorefront.tsx:584`; bespoke bridge `PublishedStorefront.tsx:264-265,279-280`). `OrderStatus.tsx` polls `get_order_by_id({ p_id: token })`, which is anon-safe and looks up by `receipt_token` (RPC lines 23-65). The guest's order — `customer_id` linked or NULL — is fully trackable by the unguessable token with no auth. The transactional **receipt email** (Resend, `send-transactional-email` / `order-notify`) uses the email we stored on the order notes / customer row.

### Dine-in / pickup specifics
- **Dine-in** (`fulfillment = in_store_pickup`, `dine_in = true`): pays at the venue — no online card, so guest checkout works today with zero payment concern. Table number flow unchanged.
- **Pickup / delivery:** would normally pay online by card — but **card capture stays on hold (C1)**. Both surfaces already create the order at `awaiting_confirmation` and the owner confirms manually; guest checkout does not change this. **Do NOT take real cards until C1 (server-side total recompute in `create_order_with_inventory`) is fixed** — see §7.

---

## 5. Implementation plan (file-by-file)

### 5.1 New shared helper — `src/services/guestCheckout.ts` (NEW)
A tiny, surface-agnostic module so both storefronts behave identically:
```ts
// ensureGuestSession(): get-or-mint anon session on customerSupabase (idempotent;
//   no-op if already signed in, anon or permanent). Optional captchaToken passthrough.
// recordConsentAndGetCustomerId(orgId, {name,email,phone,tos,emailOptIn,smsOptIn}):
//   calls customerSupabase.rpc("upsert_my_consent", …) → returns customerId (string).
```
Both `submitOrder` (default) and the `placeOrder` bridge (bespoke) call these two before `orderApi.createTest`.

### 5.2 `src/pages/storefront/RestaurantStorefront.tsx` (default — remove forced gate)
- **`openCheckout()` (449-457) + `continueFromUpsell()` (460-466):** delete the `if (!customerUser) setCheckoutStep("auth")` branches → always go to upsell/checkout. Keep a manual "Sign in" affordance (a button that sets `checkoutStep = "auth"`) for returning customers.
- **Checkout dialog (1438-1613):** add the **T&C checkbox** (required; disable the Pay/Place buttons until ticked) and a **marketing email checkbox** (optional) next to the email field. New state: `const [tosAccepted, setTosAccepted] = useState(false)` and `const [emailOptIn, setEmailOptIn] = useState(false)`. Add a small "Already have an account? **Sign in**" link.
- **`submitOrder()` (483-): before `orderApi.createTest`,** insert: `await ensureGuestSession()` then `const customerId = await recordConsentAndGetCustomerId(...)` for the guest path (replace the signed-in-only `ensureExists` branch at 547-559 with: signed-in → `ensureExists` as today; guest → the new helper). **Remove** the fragile direct guest consent upsert (603-612) — the RPC now owns it.
- **`finishOrder()` (470-481):** open `PostPurchaseModal` for ALL guests (drop the `loyalty.enabled` condition so the account nudge shows even when loyalty is off). Modal already mounted (1616-1628) with `defaultEmail={guest.email}`.

### 5.3 `src/components/storefront/screens/Checkout.tsx` (bespoke — convert forced gate → optional)
- **`usePlaceOrder()` (182-224):** delete the `if (!customerSignedIn) { requestAuth?.(); return; }` gate (195-200). The bridge now always submits (the bridge itself mints the anon session — §5.4). Drop the `customerSignedIn` / `requestAuth` *gating* params (keep `requestAuth` only to power the optional "Sign in" link).
- **`ContactStep` (616-687):** add the **T&C checkbox** (required) + **marketing email checkbox** (optional), themed with `FIELD_BASE` tokens. Extend `CheckoutForm` (99-116) + `contactValid` (230-236) so `Continue`/`Place order` requires `tos === true` and a valid email (email is already required here).
- **`PrimaryAction` (770-842):** remove the `needsAuth` "Sign in to place order" label path; CTA is always "Place order". Add a small "Sign in" text link in the panel/page header that calls `requestAuth`.
- **`Checkout` entry (1311-1466):** keep `useCustomerAuth` + `CustomerAuthDialog` (1360-1366) for the **optional** sign-in only; remove the comment/logic asserting "there is NO guest checkout" and the auto-gate wiring (`customerSignedIn` threading at 1383-1449 becomes prefill-only).

### 5.4 `src/components/storefront/PublishedStorefront.tsx` (bridge)
- **`placeOrder` bridge (LiveStorefrontStage, ~196-284):** before `orderApi.createTest` (244), add: `await ensureGuestSession()`; then for a guest, `customerId = await recordConsentAndGetCustomerId(org.id, { name: input.name, email: input.email, phone: input.phone, tos: input.tos, emailOptIn: input.emailOptIn, smsOptIn: input.smsOptIn })`. (`CheckoutBridge` input gains `tos`/`emailOptIn`/`smsOptIn` — thread them from the `Checkout` form.) Keep the signed-in `ensureExists` branch (220-231) as the "already has account" path.
- **Account nudge:** mount `PostPurchaseModal` in the bespoke success state (reuse the component) seeded with `defaultEmail = input.email` and `orderId = receiptToken`, so the bespoke flow gets the same "create an account for deals" push.

### 5.5 `src/services/customerAccount.ts` (consent hygiene)
- `ensureExists` (62-80): stop hardcoding `marketing_opt_in: true`. Accept an explicit opt-in arg and stamp `email_consent_at`/`email_consent_method` when true (so the *signed-in* path is also Spam-Act-clean). This aligns the legacy path with the new guest path.

### 5.6 Migrations + types
- Apply `20260608000000_customer_tos_acceptance.sql` (§2) and `20260608000100_upsert_guest_consent.sql` (§2) in the Supabase SQL editor → regenerate `src/integrations/supabase/types.ts`.

### 5.7 Account-upgrade (the nudge actually creating an account)
- `PostPurchaseModal` already sends a magic link (`sendMagicLink`, `useCustomerAuth.ts:138-146`) → on click lands `/account?from_order=<receipt_token>`. Because the guest is in an **anon** session, the cleanest upgrade is `customerSupabase.auth.updateUser({ email })` (link email to the SAME uid) → verify → optional password; the `customers` row + order (keyed on the stable uid) carry over automatically. The magic-link path also works but mints/uses the email identity; prefer `updateUser` from the live anon session for true carry-over. (Add a thin "create account" handler in the modal that calls `updateUser` when an anon session is present, falling back to `sendMagicLink` otherwise.) `linkIdentity()` (OAuth) requires **Manual linking** enabled in Auth settings — defer to a later pass.

---

## 6. Abuse / cleanup + future

- **Anon-user accumulation:** every guest checkout creates a permanent `auth.users` row (Supabase has **no auto-cleanup**). Mitigate:
  - **CAPTCHA** (Turnstile/hCaptcha) on `signInAnonymously` — pass `options.captchaToken`. Strongly recommended (it's a public write endpoint).
  - Built-in **IP rate-limit** on anon sign-ins (default 30/hr/IP; configurable in dashboard) — no code needed.
  - **Periodic cleanup cron** (pg_cron), gated so it never deletes a guest whose order we still need (we copy email/total into our own `orders`/`customers`, so deleting the stale auth row is harmless):
    ```sql
    DELETE FROM auth.users
    WHERE is_anonymous IS TRUE
      AND created_at < now() - interval '30 days'
      AND id NOT IN (SELECT user_id FROM public.customers WHERE user_id IS NOT NULL);
    ```
    (Tune the predicate; at founding-merchant scale a weekly run is plenty.)
- **Mint lazily:** call `signInAnonymously` **at place-order time**, not on page load, so a browsing visitor never creates an auth row.
- **Future — guest→account conversion:** when a guest later signs in/creates an account with the same email, reconcile the anon guest row(s) + their orders into the permanent customer (manual email-match merge, since we don't auto-merge in v1). The stable-uid upgrade path (`updateUser`) makes the in-session case free; the cross-session case (different device) is the only one needing a merge job.

---

## 7. Risks / what stays unchanged

- ✅ **Order RPC unchanged.** No edit to `create_order_with_inventory`, no new `anon` grant, no new RLS policy on `orders` or `customers`. The `auth.uid() IS NOT NULL` gate, the cross-org `p_customer_id` validation, and the `receipt_token`-only public tracking are all preserved exactly. Guest writes ride the existing `authenticated`-role path.
- ✅ **C1 hold stands.** This design does **not** enable card capture; pickup/delivery still create at `awaiting_confirmation` with manual owner confirm. ⚠️ Guest checkout *broadens who can submit a client-trusted total* (friction-free, anonymous) — so **C1 (server-side recompute of `p_total` from product prices + server-side promo consumption inside the order RPC) MUST be fixed before any real card capture ships alongside guest checkout.** The RPC already loads each product `FOR UPDATE` (lines ~131-159), so the authoritative subtotal can be summed there.
- ✅ **Apex / default browsing unchanged.** No change for visitors who don't check out (anon session is minted lazily at place-order). Marketing landing, `/eat`, `/business/*` untouched.
- ⚠️ **New consent RPC is additive** but is a SECURITY DEFINER function granted to `anon, authenticated` — it must (and does) write ONLY the caller's own `(org, auth.uid())` row and hard-`SET search_path = public`. Review it as carefully as `accept_customer_invite` (the pattern it mirrors).
- ⚠️ **One small migration + types regen** required (the `tos_accepted_at` columns + the consent RPC). Without the T&C columns, fall back to UI-only T&C (Option B, legally weaker).
- ⚠️ **Stop hardcoding `marketing_opt_in: true`** in `ensureExists` — fixing this is part of the change, not optional, for Spam-Act compliance.

---

### Key file:line index (verified 2026-06-08)
- Order RPC (final): `supabase/migrations/20260601093000_harden_order_customer_and_receipts.sql:67-198` (auth gate 105-113; non-member branch 110; verbatim total insert 178; anon-safe `get_order_by_id` 23-65).
- `customer_id_for_user`: `supabase/migrations/20260419061246_*.sql:29-39` (maps `customers.user_id = auth.uid()`).
- Consent-RPC pattern to mirror: `supabase/migrations/20260530090000_customer_invites.sql:53-96` (`accept_customer_invite`, SECURITY DEFINER, granted anon+authenticated).
- Default forced gate: `src/pages/storefront/RestaurantStorefront.tsx:449-457`, `460-466`; checkout dialog `1438-1613`; SMS-consent + fragile guest upsert `590-617`; signed-in `ensureExists` `547-559`; `finishOrder` nudge gate `470-481`; PostPurchaseModal mount `1616-1628`; token redirect `584`.
- Bespoke forced gate: `src/components/storefront/screens/Checkout.tsx:182-224` (`usePlaceOrder`), `ContactStep` `616-687`, `contactValid` `230-236`, `PrimaryAction` needsAuth `770-842`, entry gate wiring `1311-1466`.
- Bespoke bridge: `src/components/storefront/PublishedStorefront.tsx:196-284` (guest order, `ensureExists` 220-231, `createTest` 244, token 264-265/279-280).
- Order create client API: `src/services/api.ts:439-489` (`createTest`; inaccurate recompute comment 476-478).
- Consent client API: `src/services/customerAccount.ts:62-80` (`ensureExists`, hardcoded `marketing_opt_in: true`).
- Public tracker: `src/pages/OrderStatus.tsx:157-180`.
- Customer auth (no anon today): `src/hooks/useCustomerAuth.ts:138-146` (`sendMagicLink`); dual clients `src/integrations/supabase/client.ts:22-40`.
- PostPurchaseModal: `src/components/storefront/PostPurchaseModal.tsx` (whole file).
- Customers consent columns: `src/integrations/supabase/types.ts:219-258`; SMS consent migration `20260420035346`; email consent migration `20260420042943`. **No `tos_accepted_at` on customers; no `(organization_id, email)` unique index.**
