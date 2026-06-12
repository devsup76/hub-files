# Unified Customer Auth — locked spec (2026-06-12)

> Founder decisions locked 2026-06-12 (with senior-advisor review). Resolves TODO #20
> (account model → **(a) unified Woahh account**), #32 (faster sign-in), and the
> customer-facing half of #15. CRM + customer logins were wiped same day (test data)
> so this ships onto a clean slate.

## The flow (customer-visible)

**Sign-up — fully in-dialog, zero redirects:**
1. From checkout (or a members-only deal), dialog opens led by the **merchant's logo**:
   *"Create your account to unlock deals & loyalty at **{Merchant}**"* — Woahh as the
   trust layer underneath: *"One account for every Woahh restaurant · Powered by Woahh"*.
   (NOT "we manage these restaurants" — platform, not operator; liability optics.)
2. Name + email + password (+ optional mobile) in a real `<form>` with
   `autocomplete="new-password"` etc. so phones offer to save the password.
3. **One consent tick, explicit wording (LOCKED):** "I agree to the Terms and to
   receiving deals & loyalty offers from {Merchant} and Woahh restaurants — unsubscribe
   anytime, every email shows how." Defensible single-tick because marketing is named
   and the account IS a deals program. Guest checkout keeps its separate opt-in.
4. **Email verification = 6-digit code entered in the same dialog** (no magic-link
   redirect). On verify → dialog closes → checkout resumes, cart intact.
5. On verification: **loyalty back-claim** — link existing `customers` rows by
   email/phone (set `user_id`) so past guest orders count instantly.

**Sign-in — three methods at launch (LOCKED, founder overrode SMS-later advice):**
password · email code · SMS code. SMS protected by per-identifier + per-IP rate
limits, attempt lockout, and Turnstile-ready hooks (SMS pumping fraud is real).

**Cross-merchant guest detection (LOCKED — generic, privacy-safe):** when a guest
email already has a Woahh account, show *"Good news — this email already has a Woahh
account. Sign in and your details + loyalty come with you."* **Never name the other
restaurant before sign-in** (account enumeration + dining-history leak). After
sign-in, the unified account hub shows all connected restaurants.

**Guest nudge (LOCKED):** "create an account" lives as a **PS inside the order
receipt** (transactional = always legal, 100% reach). A separate follow-up email goes
**only to guests who ticked marketing** at checkout, once, ~24h later.

**Members-only offers:** new `members_only` flag on `promo_codes` — storefront shows
them locked with "Sign in to unlock" → opens the auth dialog. (Did not exist before.)

## Build plan (branch `feat/unified-customer-auth`, worktree `repo-auth`)

1. Migration: `members_only` on promo_codes; `customer_otp_codes` table (identifier,
   purpose, code_hash, expires_at, attempts, ip) — service-role only; `email_has_account(text)`
   SECURITY DEFINER RPC (boolean, rate-limit guarded) for the cross-shop notice;
   `customers.account_nudge_sent_at` for the one-time follow-up.
2. Edge fn `customer-auth-otp`: send_email_code (Resend), send_sms_code (ClickSend via
   shared WOAHH_SMS_NUMBER), verify → `auth.admin.generateLink` token_hash → client
   `verifyOtp` (no email actually sent for the session hop). Rate limits: 3 sends /
   identifier / 10 min, 8 / IP / hour, 5 verify attempts per code; codes 6 digits,
   10-min expiry, hashed at rest.
3. Frontend: rebuild the auth dialog as the unified multi-step component (merchant
   logo header, sign-up wizard incl. code step, three sign-in methods, cross-shop
   notice, consent wording). Password-manager-friendly forms.
4. Receipt PS nudge (order-respond template) + follow-up cron (opt-ins only).
5. Verify: tsc/build, 390px Playwright run of the full flow, push branch for preview.

## Status (2026-06-12, end of day)
**BUILT + PUSHED on `feat/unified-customer-auth` — NOT merged.** Go-live order:
1. Run migration `supabase/migrations/20260612200000_unified_customer_auth.sql` (SQL editor).
2. `npx supabase functions deploy customer-auth-otp order-respond` (needs CLICKSEND_* +
   WOAHH_SMS_NUMBER + RESEND_API_KEY secrets — all already set for other fns).
3. Merge the branch → Cloudflare ships the new dialog.
4. Staged next (small): guest follow-up email cron (opt-ins only), members-only promo
   storefront UI ("sign in to unlock"), Turnstile on the OTP endpoint pre-scale.

## Risks accepted / deferred
- SMS OTP at launch = per-send cost + fraud surface (mitigations above; revisit if abused).
- Single-tick consent relies on explicit wording — do not weaken the copy without re-review.
- Passkeys = v2; SMS marketing consent (vs email) inherits the same tick wording which
  names offers generically — acceptable, revisit when SMS campaigns scale.
