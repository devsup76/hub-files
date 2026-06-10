# Post-Square TODO — founder-noticed flow gaps (2026-06-10)

> Queued by founder AFTER finishing the Square verification. Both are first-merchant-readiness
> items (a real merchant's customers need these), not future-scale.

## 1. Refunded state not shown on the public order tracker
- **Symptom:** when an order is refunded, the `/order/:id` tracker (OrderStatus.tsx) doesn't reflect it.
- **Likely cause:** the DATA is already there — `get_order_by_id` returns `payment_status`
  (`refunded` / `partially_refunded`) + `refund_amount_cents`/`refunded_at` (verified live). The
  tracker UI just doesn't RENDER a refund indicator (it renders the order *status* steps
  pending→preparing→ready→completed, not the payment/refund status).
- **Fix scope (frontend only):** in `src/pages/OrderStatus.tsx`, surface a "Refunded $X on <date>"
  / "Partially refunded" banner when `payment_status` ∈ {refunded, partially_refunded}. No DB/edge change.

## 2. Receipt/confirmation not delivered when the owner confirms an order
- **Symptom:** confirming an order doesn't send the customer a receipt/confirmation email.
- **Likely causes to check (in order):**
  1. `order-respond` confirm path — does it actually call the email send (Resend) on `action:'confirm'`,
     and to the right recipient (guest email is on the consent/customers row / order notes)?
  2. `RESEND_API_KEY` edge secret set + the sender domain (`mail.woahh.app`) verified for this project.
  3. The notification settings gate (`notify_on_*` / marketplace tier) — is the confirm-receipt gated off?
  4. Guest orders: is the email captured + passed so the receipt has a recipient?
- **Fix scope:** diagnose via the order-respond logs + the email path; likely a config (Resend secret)
  or a missing/guarded send on confirm. Edge fn + possibly NotificationSettings.

## Status
- [x] 1. Refund on tracker (frontend) — DONE (OrderStatus banner)
- [x] 2. Receipt on confirm — FIXED (email_type CHECK was rejecting 'order_respond'; now 'order_confirmation'). Combined confirmation+receipt, AU receipt content, pickup#/table#, online-only. Verified live (delivered).
- Tackle AFTER the Square verification + readiness sign-off is complete.
