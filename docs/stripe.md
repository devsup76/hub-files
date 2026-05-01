# Stripe Setup Guide — Woahh

> Do this once. Refer back as needed.
> Last updated: 2026-04-30

---

## Account Creation

Go to **stripe.com/au** and sign up.

**During signup:**
- Email — business email (or founders@ once set up; can change later)
- What are you building — **"Platform or marketplace"**
- Country — **Australia**
- Business name — Woahh Pty Ltd (once registered; use your legal name until then)
- Industry — **Software / SaaS**
- Website — woahhapp.com (placeholder fine)
- ABN — enter once you have it; Stripe AU requires it for payouts

---

## Immediately After Account Is Created

1. **Stay in test mode** — do not activate live mode. All dev work happens in test mode.

2. **Dashboard → Connect → Get started** — enable Connect, set platform name to "Woahh", upload logo.

3. **Apply for Connect Custom** — in the Connect tier selector, choose Custom and describe the platform as:
   > *"Woahh is a SaaS platform for Australian restaurants and retail merchants. We process orders on behalf of merchants via connected accounts, collect a platform fee, and disburse payments on a short delay for dispute handling."*

4. **Email Stripe Australia support** (`au-support@stripe.com` or via Dashboard Help → Contact support) requesting written confirmation that Woahh's platform operations under Connect fall within Stripe Payments Australia Pty Ltd's AFSL. This is a standard request. You need it on file before the first live transaction under Connect Custom.

5. **Save your API keys:**

   | Key | Where it goes |
   |---|---|
   | Publishable key | `VITE_STRIPE_PUBLISHABLE_KEY` (repo env) |
   | Secret key | `STRIPE_SECRET_KEY` (Supabase edge function secret) |
   | Webhook signing secret | `STRIPE_WEBHOOK_SECRET` (after configuring webhooks in Week 2) |

---

## Phased Connect Model

| Phase | Model | Config |
|---|---|---|
| Founding merchants | Connect Express | `application_fee_amount: 0` — zero commission forever |
| All paying merchants (Phase 1 paid launch+) | Connect Custom | `application_fee_amount` = 6% online / 4% in-person; T+1 payout delay |

**Do not configure webhooks or go live until Week 2 of the launch sprint.**

Test card for development: `4242 4242 4242 4242`

---

## How Woahh's Cut Works

On every transaction, `application_fee_amount` is deducted at the point of charge and lands directly in Woahh's platform Stripe balance — before the merchant ever sees the money.

- Online order: 6% gross → 50% to charity (weekly cron transfer), 50% stays as Woahh revenue
- In-person order: 4% gross → 50% to charity, 50% Woahh revenue
- Founding merchants: 0% — `application_fee_amount: 0`, always

Charity transfers are made from Woahh's Stripe platform balance via the `stripe-charity-transfer` edge function (weekly pg_cron job, Phase 1 paid launch).

---

## Connect Custom Approval Timeline

Stripe typically reviews Connect Custom applications within 2–4 weeks. Apply on the same day you create the account so approval arrives before Week 2 integration work begins.

If approval is delayed, the launch sprint proceeds with Connect Express only (founding merchants). Paying merchant onboarding waits until Custom is approved.
