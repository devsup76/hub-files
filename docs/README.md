# Woahh — docs index

> Planning / strategy / architecture docs for the **woahh** app. This is the `hub-files`
> planning repo (`devsup76/hub-files`) — **not** the app build (that is `devsup76/business-growth-hub`,
> mounted here as the `repo/` worktree + feature worktrees `repo-audit`, `repo-pay`, `repo-ai`, etc.).
> Single source of truth for the app itself: [`../CLAUDE.md`](../CLAUDE.md).
> Last updated: 2026-06-09.

## Launch & onboarding
- [FIRST_MERCHANT_LAUNCH.md](FIRST_MERCHANT_LAUNCH.md) — first-restaurant readiness + founder handoff (guest checkout + C1 live-verified; founder action list).
- [MERCHANT_ONBOARDING_RUNBOOK.md](MERCHANT_ONBOARDING_RUNBOOK.md) — zero-to-live, dependency-ordered runbook for onboarding the first 1–5 merchants.
- [FOUNDER_RUN_THESE.sql](FOUNDER_RUN_THESE.sql) — the exact migrations the founder runs in the Supabase SQL editor, in order (idempotent).

## Payments & Square
- [SQUARE_POS_INTEGRATION.md](SQUARE_POS_INTEGRATION.md) — Square as a second payment connector (online + Terminal in-person), API-verified plan.
- [REFUND_POLICY.md](../repo-audit/docs/REFUND_POLICY.md) — refund mechanics (full/partial, who/when, per-provider routing, GMV/donation reconciliation). *Lives in the app repo: `repo-audit/docs/`.*
- [AUDIT_FINDINGS_2026-06-09.md](AUDIT_FINDINGS_2026-06-09.md) — storefront-platform + payments deep audit; money/correctness/payment-race findings (fixed) + staged decisions.
- [stripe.md](stripe.md) — one-time Stripe account setup guide.

## Storefront & templates / domains
- [DOMAINS_ROADMAP.md](DOMAINS_ROADMAP.md) — three domain tiers on one host→org resolver (`name.woahh.app` → custom domains).
- [MERCHANT_DEMOS_TASKS.md](MERCHANT_DEMOS_TASKS.md) — demo-merchant storefront polish tasks (Taco Joint richer/dark-mode, etc.).

## Architecture & roadmap
- [NATIVE_APP_PLATFORM.md](NATIVE_APP_PLATFORM.md) — Capacitor native-app plan (wrap the PWA, don't rewrite).
- [NATIVE_SCAFFOLD.md](NATIVE_SCAFFOLD.md) — how to run the committed Capacitor scaffold (the "execute" half of the plan above).
- [SCALING.md](SCALING.md) — traffic flow, load handling, cost, and the dials we turn as we scale.
- [FRANCHISE_ARCHITECTURE.md](FRANCHISE_ARCHITECTURE.md) — additive franchise / multi-location layer (planned, not built).
- [SMS_ARCHITECTURE.md](SMS_ARCHITECTURE.md) — two-number SMS model + hardening (shipped); reservations now email-only.
- [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md) — server-side Claude features (menu copilot, campaign copy, decline reasons).
- [RESTAURANT_INVENTORY.md](RESTAURANT_INVENTORY.md) — ingredient inventory / BOM / auto-86 (built, not yet live; next phase).
- [POS_TERMINAL_PLAN.md](POS_TERMINAL_PLAN.md) — in-person Stripe Terminal + Tap-to-Pay plan.

## Planning / TODO
- [WOAHH_FIXES_TODO.md](WOAHH_FIXES_TODO.md) — the open punch list (single source of truth for fixes/polish).
- [OVERNIGHT_SQUARE_PLAN.md](OVERNIGHT_SQUARE_PLAN.md) — the 2026-06-09 Square build/audit/cleanup run plan + progress log.

## Pitch / business / legal / hardware
- [pitch/](pitch/) — investor deck (VC_PITCH_DECK, woahh-vc-deck), merchant pitch (RESTAURANT_PITCH), positioning brief, speaker script.
- [business/](business/) — business strategy, master plan, shop architecture/research.
- [legal/](legal/) — founders term sheet, ABN registration guide, legalities, expansion verticals.
- [hardware/](hardware/) — restaurant + shop hardware recommendations.

## Archive
- [archive/](archive/) — superseded / historical handoffs + early plans (off-Lovable migration, morning/overnight handoffs, original email-domain / features-to-add / non-dev-implementations notes). Kept for history; not current.
