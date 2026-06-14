---
name: woahh-approval-flow-pr10
description: 2026-06-14 session — order-approval card redesign + payment-gated approval + PR
metadata: 
  node_type: memory
  type: project
  originSessionId: baf7b18a-76fb-44e6-904b-8dee333c81eb
---

Session 2026-06-14 on branch `feat/founder-fixes-2026-06-12` (worktree `repo-ff`). Built on top of the founder-fixes set. **PR #10** opened (feat/founder-fixes-2026-06-12 → main): https://github.com/devsup76/business-growth-hub/pull/10 — **all 6 required CI checks GREEN** (build-test, typecheck-ratchet, lint-ratchet, migration-guard, no-test-deletion, secret-scan), `mergeable_state=blocked` = **only the required 1 review is missing**. I deliberately did NOT admin-bypass (main got the CI safety spine + branch protection merged today; PR touches a payments migration → [[woahh-agentic-dev-workflow]] "payments/RLS/migrations human-led"). Founder merges.

**Shipped in this session (committed on the branch):**
- **#19 approval-card redesign** (`fc63855` + review fixes `a52cbf5`): red↔white FLASH once an order waits **30s** unactioned (was: final-minute pulse), enlarged scale, reduced-motion safe (`.wh-approval-flash` in index.css); food-first hierarchy (big qty+title, small #/name); line-item **modifiers** (variant / − removed / + added) now shown at the approval step; "Action needed" a11y token (role=status). Verified headless (iPad viewport).
- **Payment-gated approval** (`e02a4a0` + constraint fix in `a52cbf5`): card order (online_card_enabled, non-venue, non-dine-in) created `payment_status='pending'` → HIDDEN from approval queue until the Stripe/Square webhook flips `pending→authorized/paid`. Venue/cash/POS stay `unpaid` and show immediately. Migration `20260614120000_payment_gated_approval_queue.sql` (re-states `create_order_with_inventory` byte-identical to `20260612140200` + the INSERT payment_status + the CHECK widen).

**🔴 CRITICAL — founder MUST run on live before enabling online cards** (the function half of the migration was already run 2026-06-14; the CHECK was NOT widened — verified `pending_allowed=false` on live via Management API; caught by the 20-agent adversarial review):
```sql
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check
  CHECK (payment_status IN ('unpaid','pending','authorized','paid','pay_in_person','refunded','partially_refunded','failed','canceled'));
```
Without it, every online-card order fails at creation (CHECK rejects 'pending'). Additive/zero-risk. The committed migration file now includes this ALTER (for fresh applies); the live DB still needs it run.

**Also done:** `order-receipt-email` edge fn **DEPLOYED** (v1, ACTIVE, verify_jwt=true) — fixes the dead receipt Email button. Used the founder's `sbp_` PAT (pasted in chat → **ROTATE**).

**⚠️ Deferred money-path hardening (only bites once online cards are ON — founder review):** Stripe webhook-latency window (a `pending` order hidden until the hold lands; if webhook delayed past auto-decline timeout the order is swept — hold voided, no charge, but order lost); `void_my_unpaid_order` doesn't release a live Stripe hold for `pending`; `auto_decline` clock starts at created_at not authorization. See PR #10 body + [[woahh-online-order-flow]].

Tooling notes for this env: `gh` NOT installed (use the embedded token in `git config remote.origin.url` + GitHub REST API via node); `python3` json/difflib are flaky (use node / `--jq`). CI gate scripts live in `ci/scripts/*.mjs`; tsc-ratchet runs `tsc -b` (stricter than `tsc --noEmit`).
