# Woahh — docs index

> Planning / strategy / architecture docs for the **woahh** app. This is the `hub-files`
> planning repo (`devsup76/hub-files`) — **not** the app build (that is `devsup76/business-growth-hub`,
> mounted here as the `repo/` worktree + feature worktrees `repo-audit`, `repo-pay`, `repo-ai`, etc.).
> Single source of truth for the app itself: [`../CLAUDE.md`](../CLAUDE.md).
> Last updated: 2026-06-10 (docs cleanup: completed one-off SQL bundles, done handoffs/run logs,
> Lovable-era plans, and deferred-retail research deleted — all recoverable from git history).

## Planning / TODO
- [WOAHH_FIXES_TODO.md](WOAHH_FIXES_TODO.md) — **the open punch list** (single source of truth for fixes/polish; rewritten 2026-06-10).

## Launch & onboarding
- [FIRST_MERCHANT_READINESS.md](FIRST_MERCHANT_READINESS.md) — GO/NO-GO readiness verdict + hard gates for the first real merchant.
- [MERCHANT_ONBOARDING_RUNBOOK.md](MERCHANT_ONBOARDING_RUNBOOK.md) — zero-to-live, dependency-ordered runbook for onboarding the first 1–5 merchants.
- [MERCHANT_DEMOS_TASKS.md](MERCHANT_DEMOS_TASKS.md) — demo-merchant storefront polish tasks (Taco Joint richer/dark-mode, etc.).

## Payments & Square
- [SQUARE_POS_INTEGRATION.md](SQUARE_POS_INTEGRATION.md) — Square as a second payment connector (online + Terminal in-person), API-verified plan.
- [SQUARE_PRODUCTION_CHECKLIST.md](SQUARE_PRODUCTION_CHECKLIST.md) — sandbox→production go-live checklist (AU account, OAuth app, compliance, deploy steps).
- [SQUARE_SANDBOX_GOLIVE.sql](SQUARE_SANDBOX_GOLIVE.sql) — test-bistro Square-sandbox seed/flip **+ the not-yet-run REVERT block** (needed before the Stripe test order in READINESS gate B.10).
- [REFUND_POLICY.md](../repo-audit/docs/REFUND_POLICY.md) — refund mechanics (full/partial, who/when, per-provider routing, GMV/donation reconciliation). *Lives in the app repo: `repo-audit/docs/`.*
- [AUDIT_FINDINGS_2026-06-09.md](AUDIT_FINDINGS_2026-06-09.md) — storefront-platform + payments deep audit; money/correctness/payment-race findings (fixed) + staged decisions.
- [GUEST_CHECKOUT_DESIGN.md](GUEST_CHECKOUT_DESIGN.md) — anonymous-session guest checkout design (shipped + live-verified).
- [POS_TERMINAL_PLAN.md](POS_TERMINAL_PLAN.md) — in-person Stripe Terminal + Tap-to-Pay plan.

## DB / schema
- [SCHEMA_DRIFT_RECONCILIATION.md](SCHEMA_DRIFT_RECONCILIATION.md) — live-vs-repo schema drift findings + standing follow-up (migration smoke gate).
- [LIVE_SCHEMA_2026-06-10.txt](LIVE_SCHEMA_2026-06-10.txt) / [LIVE_FUNCTIONS_2026-06-10.txt](LIVE_FUNCTIONS_2026-06-10.txt) — live DB snapshots used for the drift reconciliation.
- [RUN_ORDER_NUMBER.sql](RUN_ORDER_NUMBER.sql) — **NOT yet run / not integrated**: daily-resetting human-friendly order numbers (pending feature).

## Storefront & domains
- [DOMAINS_ROADMAP.md](DOMAINS_ROADMAP.md) — three domain tiers on one host→org resolver (`name.woahh.app` → custom domains).
- [NATIVE_APP_PLATFORM.md](NATIVE_APP_PLATFORM.md) — Capacitor native-app plan (wrap the PWA, don't rewrite).
- [NATIVE_SCAFFOLD.md](NATIVE_SCAFFOLD.md) — how to run the committed Capacitor scaffold (the "execute" half of the plan above).

## Architecture & roadmap
- [SCALING.md](SCALING.md) — traffic flow, load handling, cost, and the dials we turn as we scale.
- [FRANCHISE_ARCHITECTURE.md](FRANCHISE_ARCHITECTURE.md) — additive franchise / multi-location layer (planned, not built).
- [SMS_ARCHITECTURE.md](SMS_ARCHITECTURE.md) — two-number SMS model + hardening (shipped); reservations now email-only; **key-rotation list lives here**.
- [RESTAURANT_INVENTORY.md](RESTAURANT_INVENTORY.md) — ingredient inventory / BOM / auto-86 (built, not yet live; next phase).

## Pitch / business / legal / hardware
- [pitch/](pitch/) — investor deck (VC_PITCH_DECK, woahh-vc-deck), merchant pitch (RESTAURANT_PITCH), positioning brief, deck/video asset inventory.
- [business/](business/) — business strategy (locked financial model), master plan, shop architecture (deferred retail vertical).
- [legal/](legal/) — ABN registration guide, legalities (Spam Act / compliance checklists), expansion process.
- [hardware/](hardware/) — restaurant hardware recommendations.
