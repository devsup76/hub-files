---
name: woahh-online-order-flow
description: "The online ordering flow (QR→order→pay→confirm→receipt→KDS/docket) — status, the receipt-email root-cause fix, and what's verified live"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4a5c9742-6065-4dcb-b9ed-037257b18a15
---

The end-to-end ONLINE ordering flow on `feat/storefront-platform` (worktree repo-audit), verified live on
test-bistro (Square sandbox) on 2026-06-10. **11/11 E2E PASS:** QR→storefront(`get_public_storefront`)→
menu(`get_public_menu`)→guest checkout(anon+`upsert_my_consent`+T&C)→order(C1)→C1 rejects tamper→Square
authorize→kitchen confirm(`order-respond` capture)→**confirmation+receipt email delivered**→tracker(masked)
→refund→refund shows on tracker.

**RECEIPT EMAIL — the big fix (was NEVER working, 0 sent ever).** Root cause was NON-OBVIOUS: `order-respond`
inserted `email_log.email_type='order_respond'`, but the table has `CHECK (email_type IN
('campaign','order_confirmation','trial_reminder','system'))`. supabase-js `.insert()` returns `{error}`
WITHOUT throwing, so every receipt insert failed silently → no row, no 500 → looked like success. Campaigns
worked (valid 'campaign'). Fix: `email_type='order_confirmation'`. Also: ONE combined confirmation+receipt
email (no separate receipt send), robust recipient resolution (explicit fetch by `customer_id` — the embedded
`customer:customers(email)` join was unreliable), proper AU receipt (business name+ABN, date, itemised+line
prices, total, GST 10% line when ABN present = valid Tax Invoice, payment status, fulfilment), prominent
COLLECTION # (pickup) / TABLE # (dine-in). ONLINE-ONLY: gated on having a customer email (walk-in counter
orders have none → skip → printed receipt at venue, "later"). **No 'ready' email** from order-respond — live
order updates stay OPTIONAL via `order-notify`, toggled in NotificationSettings (`notify_on_preparing/ready/
declined`). Commit afd0070. order-respond is DEPLOYED to live (pmnyhbhtkcfoozkinieo).

**Founder flow spec (2026-06-10):** scan QR→menu→order→pay→kitchen notified→confirm→customer gets confirmation
+receipt email (pickup=number, dine-in=table number)→kitchen prints a ticket DOCKET marked "ONLINE ORDER"
(differentiate from in-person) + KDS→prepare→deliver/call out. No "ready" email required; live updates optional/
toggleable. In-person ordering = "sort out later".

**Docket:** `src/lib/printDocket.ts` `printKitchenDocket(order, org)` — thermal-print window, big "ONLINE ORDER"
banner (reads `order.order_source ?? 'online'`), collection ref/table, items + kitchen modifiers (+extras, NO
removed-ingredients, notes), no prices. Print button wired into Orders.tsx cards. Commit e39b6a2.
FOLLOW-UPS (not done): (1) add the print button to the KDS card too (needs `org` threaded into the OrderCard
sub-component); (2) add `orders.order_source` column (default 'online') + set 'walk_in' in WalkInOrderDialog so
the docket marker is accurate once in-person orders exist (today the field is absent → defaults to ONLINE ORDER,
correct for all current storefront orders). Refund-on-tracker also shipped (OrderStatus.tsx, commit 9aa4166).

**Branch PUSHED 2026-06-10** (`feat/storefront-platform` @ e39b6a2, 13 commits) → Cloudflare PREVIEW building
(founder lifted the push-hold to preview Taco Joint/Wingz Hut + onboard the first merchant). Build = `vite build`
(no tsc gate; ~8 pre-existing type errors don't block). .env is tracked but holds ONLY public VITE_ keys (no
server secret). For a real merchant on `name.woahh.app` (prod), still need: merge→main + wildcard DNS + env vars
(see docs/FIRST_MERCHANT_READINESS.md + SCHEMA_DRIFT_RECONCILIATION + SQUARE_PRODUCTION_CHECKLIST). See
[[woahh-storefront-platform]], [[woahh-payments-stripe]]. ROTATE the pasted `sbp_` Supabase token.
