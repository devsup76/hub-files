# Woahh — Fixes & Polish TODO

> Single source of truth for the open punch list.
> Closed items at the bottom for context.
> Last updated: 2026-05-29

---

## Architecture state (2026-05-28)

- **Live at `https://woahh.app`** — single origin, path-based split
- Merchant portal at `/business/*`; customer at apex
- Legacy `business.woahh.app` 301s pre-mount in `src/main.tsx`
- Email infrastructure verified at Resend (`mail.woahh.app`, `campaigns.woahh.app`)
- Test merchant: `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` (slug `test-bistro`)

See `CLAUDE.md` for full architecture details.

---

## 🔴 Open

### Security warnings flagged by Lovable scanner (2026-05-29)

Surface during a code review on Lovable. None block menu/order functionality. Prioritized by severity.

- 🔴 **Org Stripe IDs + owner PII readable by staff.** "Staff view their org" SELECT returns the full row including `owner_phone`, `abn`, `stripe_account_id`. Fix: stale staff SELECT down to a safe-column view. *Medium effort.*
- 🔴 **SMS webhook accepts opt-outs without signature verification.** Attacker can POST fake delivery receipts and force-opt-out arbitrary phones. Add Clicksend HMAC verification (mirror the email-webhook Svix pattern). *Small.*
- 🔴 **Stripe payment intent creation has no auth.** Add JWT verify to the create-payment-intent edge function. *Small.*
- 🟡 **Realtime subscribe-to-any-org events.** Lovable flagged orders + products. Likely false positive — `postgres_changes` uses table-level RLS, and staff/owner SELECT policies are org-scoped. Verify before "fixing".
- 🟡 **Product cost prices readable by all staff via products SELECT.** If `cost_price` column exists, service staff can see margins. Fix: column-level RLS or separate `product_costs` table. *Medium.*
- 🟡 **Courier webhook skips signature verification when no secret configured.** Should fail-closed. *Small.*
- 🟢 **Account recovery log / order notification log have no SELECT policy.** Effectively locked (no policy = deny by default with RLS on). Cosmetic only — add explicit DENY for defense-in-depth.
- 🟢 **Waitlist entries: customer can't read their own.** Doesn't break anything. Add tokened SELECT if desired.

### -1.2 Founding-merchant sign-up code gating

- **Status:** ⬜ Open — highest priority for controlling who can create accounts
- **Decisions locked:** unique single-use codes; hidden admin page at `/business/dashboard/admin/codes` visible only to `pawitsingh23@gmail.com`
- **Tech:**
  - New table `founding_access_codes` (code text PK, created_at, used_at, used_by_user uuid FK, used_by_email text, revoked_at). RLS: admin only.
  - RPC `redeem_founding_code(p_code text)` SECURITY DEFINER → checks unused + not revoked, marks consumed atomically, granted to `anon`.
  - Auth.tsx sign-up: required `signup_code` field. Redeem RPC first; only call `supabase.auth.signUp` if redemption succeeded.
  - Admin page: list + generate + revoke codes.

### 1.2 Replace email-confirmation popup with dedicated page

- **Where:** After sign-up submit on `/business/auth`
- **Status:** ⬜ Open
- **Current:** Toast pops "check your email"
- **Wanted:** Route to `/business/auth/check-email` with "We sent a confirmation link to {email}. Click it to finish signing up." + Resend button.

### 2.1 Replace manual "Add Customer" with invite-to-consent flow

- **Status:** ⬜ Open — Spam-Act compliance requirement before scale
- **Current:** Customers.tsx form lets merchants type customer details directly. Band-aid for consent timestamps already applied (commit `ffb9f1b`).
- **Wanted:** Rename "Add Customer" → "Invite Customer". Merchant enters name + email → invite email sent → customer clicks `/i/:token` → consents → customer row created with `email_consent_at = now()`, `email_consent_method = 'invite_link'`.
- **Scope (~3 Lovable prompts):**
  - DB: `customer_invites` table (org_id, email, name?, token, expires_at, accepted_at, customer_id FK)
  - Dashboard: rename button, pending invites tab with resend / cancel
  - Public: `/i/:token` accept page + `customer-invite-send` and `customer-invite-accept` edge functions + transactional email template

### 2.3 Notify customer when their record is removed

- **Status:** ⬜ Open
- **Wanted:** When merchant deletes a customer, send email: "Your account at {Org Name} has been removed. Your loyalty points and order history with this merchant are no longer accessible. If you believe this was a mistake, reply to this email."
- **Open question:** Soft-delete (30-day grace + scheduled hard purge) vs hard-delete. Recommend soft-delete.

### 3.1 Hard separation of merchant vs customer auth identities

- **Status:** 🟡 Partially solved by routing — `/signin` is customer-only on apex; `/business/auth` is merchant-only. But same email can still be both a merchant `auth.users` row AND a customer `growthhub_profiles` row, and the routing doesn't force a chooser.
- **Wanted:** Hard separation in DB and in flow. Merchant doesn't auto-become a customer at their own shop.

### 3.2 Add "View as customer" button in merchant sidebar

- **Where:** `src/components/dashboard/AppSidebar.tsx`
- **Status:** ⬜ Open
- **Wanted:** Button at the bottom that opens `/account` in a new tab. Same-origin now that single-origin migration is done — much simpler than the prior cross-host plan.

### Reviews edge cases

- **Latent:** Reviews `INSERT` requires matching order via `customer_id_for_user(org)`. Reviews `SELECT` / `UPDATE` policies should be audited for consistency (e.g., can a customer edit their own review post-submission? can a merchant flag spam?). Not blocking; flag for future audit.

---

## ✅ Closed (recent — 2026-05-29)

| # | Item | How resolved |
|---|---|---|
| Phantom-org bug | Staff users were owners of empty phantom orgs (trigger fired on staff-manage's createUser call), breaking `.maybeSingle()` in `orgApi.getMine` | Pushed `b51b045`. Trigger now skips `kind=staff`; existing phantoms cleaned up; new `my_org_id()` RPC + client uses it for deterministic resolution. |
| Products INSERT RLS failure | `current_org_id()` returning NULL in RLS contexts because of a fragile `auth.users` JOIN | Pushed `90e5f2f`. Reverted `current_org_id()` to simple priority-ordered version; rewrote products policy to use direct EXISTS subqueries instead of `current_org_id()`. |
| Realtime menu sync — service + manager weren't seeing owner's adds | (a) ShiftAvailabilityPanel was UPDATE-only filter; (b) hook subscribed under anon JWT pre-PIN-login; (c) missing queryKey invalidation for shift-availability-products | Pushed `e66aa2c`. Auth-aware re-subscription, all 3 queryKeys invalidated, ShiftAvailabilityPanel expanded to `event:"*"`, 30s polling fallback added. |
| **Staff saw empty menu (VERIFIED FIXED 2026-05-29)** | Staff logins get a junk phantom org from `handle_new_user_org`; `orgApi.getMine` was picking that empty phantom over the real staff org → staff queried an org with no products | Pushed `9b175da`. `getMine` branches on `user_metadata.kind`: staff resolve via their `staff_accounts` row (never a phantom owned org); owners use the owned-org path. **User confirmed working end-to-end** — owner adds → service sees it live. |
| Owner add showed success popup but no item | `getMine` depended on `my_org_id()` RPC that wasn't deployed → undefined orgId; fallback RPC inserted server-side (success toast) but list queried undefined org | Pushed `903da2a`. `getMine` resolves org with no RPC dependency. |
| Diagnostic logging | Hard to debug staff session without DB access | Pushed `ea759c7` + `5df23a7`. Console logs at `[session]`, `[org-query]`, `[products-query]`, `[products-create]` with explicit demo-mode warning. |
| Defensive staff view policies | Belt-and-suspenders re-assertion in case any policy got dropped | Pushed `bd50ba9`. Idempotent re-creation of staff SELECT policies on products, menu_categories, combos, organizations. |

---

## ✅ Closed (earlier — 2026-05-28)

| # | Item | How resolved |
|---|---|---|
| -1.1 | Publish Lovable app to `woahh.app` | ✅ Done. Migrated to single origin after subdomain split caused cross-origin session issues. |
| 0.1 | Campaign send error | ✅ Pushed `0573c29` + `e17483f`. Lovable shipped stale-claim self-heal; we added try/catch revert + structured logging. |
| 0.2 | Customers form null consent timestamps | ✅ Pushed `0573c29`. `*_consent_at` now derived from `marketing_opt_in` toggle at insert time. Real fix (2.1) still pending. |
| 1.1 | Hide retail at sign-up | ✅ Pushed `0573c29`. Picker hidden, default to restaurant. |
| 1.3 | Don't re-prompt business type after email verification | ✅ Pushed `0573c29`. Org metadata fields flow through `auth.users.user_metadata`; `BusinessTypeGate` auto-hydrates the org row from metadata when the legacy gate would fire. |
| 2.2 | Double-confirm customer delete | ✅ Pushed `0573c29`. AlertDialog with destructive action. |
| Routing pivot | Subdomain split → single origin with `/business/*` | ✅ Lovable migration commit `d903a87`. Pre-mount redirect in `src/main.tsx` handles legacy subdomain visitors. |
| Multi-tenant lockdown | Orders, reservations, organizations, promotions, courier_credentials, reviews, signup_codes, growthhub_profiles, product-images storage | ✅ Migrations `20260528115310`, `131845`, `131923`, `134549`. Replaced public-SELECT policies with SECURITY DEFINER RPCs and safe views (`marketplace_organizations`, `active_promotions`). |
| `current_org_id()` determinism | Stable resolution for users in multiple orgs | ✅ Migration `134549`. `ORDER BY priority, tiebreak`. |
| Customer reset password flow | Customers can reset on apex, session sticks | ✅ Pushed `1b21b4a`. `/reset-password` moved to customer paths. |
| Storefront sign-in CTAs | Header + footer "Sign in" point at merchant `/business/auth` | ✅ Pushed `1b21b4a`. Internal consistency with "Start free" merchant signup. |
| Email infrastructure | mail.woahh.app + campaigns.woahh.app DKIM/SPF/DMARC | ✅ Resend domains verified, all 6 hardening prompts (A–F) shipped earlier in session. |
| Customer sign-in split | `/signin` on apex + Customer persona hidden from `/business/auth` | ✅ Pushed via Lovable in `c90f5d7` and downstream. Reuses `CustomerForm` (named export from Auth.tsx). |
| Staff PIN 3-step verify | UX win, no security regression | ✅ Lovable commit `66f7e95`. |
| Products realtime | Owner changes propagate to KDS + storefront without refresh | ✅ Migration `152014` + `useProductsRealtime` hook + Lovable commit `e1c85a1`. |
| Side-effects-during-render in redirects | useEffect wrapping | ✅ Pushed `e17483f` (later superseded by single-origin pivot which removed the redirect components). |
| Hash fragment preservation | Deep-link `#anchor` survives host redirect | ✅ Pushed `e17483f`. |
| Path-injection (`//`) normalization | Defensive `normalizePath` in `apexUrl`/`businessUrl` | ✅ Pushed `e17483f`. |
| `/join` mis-categorization | Customer sign-up correctly on apex | ✅ Pushed `e17483f`. |

---

## Test-merchant cleanup reminder

When you're done with the seeded test merchant:

```sql
DELETE FROM auth.users WHERE id = '11111111-1111-1111-1111-111111111111';
```

The org and related rows cascade via `owner_id` FK.
