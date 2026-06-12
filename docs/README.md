# Woahh — docs index

> Planning / strategy / architecture docs for the **woahh** app. This is the `hub-files`
> planning repo (`devsup76/hub-files`) — **not** the app build (that is `devsup76/business-growth-hub`,
> mounted here as the `repo/` worktree + feature worktrees `repo-audit`, `repo-pay`, `repo-ai`, etc.).
> Single source of truth for the app itself: [`../CLAUDE.md`](../CLAUDE.md).
> Last updated: 2026-06-12 (reorganised into folders; spent SQL bundles + done handoff reports + dated
> schema-proof screenshots removed — all recoverable from git history).

## At the root
- [WOAHH_FIXES_TODO.md](WOAHH_FIXES_TODO.md) — **the open punch list** (single source of truth for fixes/polish).

## `launch/` — go-live & onboarding
- [FIRST_MERCHANT_READINESS.md](launch/FIRST_MERCHANT_READINESS.md) — GO/NO-GO readiness verdict + hard gates for the first real merchant.
- [MERCHANT_ONBOARDING_RUNBOOK.md](launch/MERCHANT_ONBOARDING_RUNBOOK.md) — zero-to-live, dependency-ordered runbook for onboarding the first 1–5 merchants.
- [SQUARE_PRODUCTION_CHECKLIST.md](launch/SQUARE_PRODUCTION_CHECKLIST.md) — sandbox→production go-live checklist (AU account, OAuth app, compliance, deploy steps).

## `architecture/` — designs, plans, feature specs
- [SQUARE_POS_INTEGRATION.md](architecture/SQUARE_POS_INTEGRATION.md) — Square as a second payment connector (online + Terminal in-person).
- [SQUARE_REGISTER_INTEGRATION.md](architecture/SQUARE_REGISTER_INTEGRATION.md) — Square Register / in-person POS integration design.
- [APPLE_GOOGLE_PAY_RISK_AND_DESIGN.md](architecture/APPLE_GOOGLE_PAY_RISK_AND_DESIGN.md) — Apple/Google Pay risk register + design + **verified post-merge status** (wallets merged + live).
- [APPLE_GOOGLE_PAY_PLAN.md](architecture/APPLE_GOOGLE_PAY_PLAN.md) — founder research doc on wallet domain registration (treat as fallible).
- [GUEST_CHECKOUT_DESIGN.md](architecture/GUEST_CHECKOUT_DESIGN.md) — anonymous-session guest checkout design (shipped + live-verified).
- [POS_TERMINAL_PLAN.md](architecture/POS_TERMINAL_PLAN.md) — in-person Stripe Terminal + Tap-to-Pay plan.
- [UNIFIED_CUSTOMER_AUTH.md](architecture/UNIFIED_CUSTOMER_AUTH.md) — fast customer sign-in (password / email code / SMS code) — built + live.
- [DOMAINS_ROADMAP.md](architecture/DOMAINS_ROADMAP.md) — three domain tiers on one host→org resolver (`name.woahh.app` → custom domains).
- [NATIVE_APP_PLATFORM.md](architecture/NATIVE_APP_PLATFORM.md) — Capacitor native-app plan (wrap the PWA, don't rewrite).
- [NATIVE_SCAFFOLD.md](architecture/NATIVE_SCAFFOLD.md) — how to run the committed Capacitor scaffold.
- [SCALING.md](architecture/SCALING.md) — traffic flow, load handling, cost, and the dials we turn as we scale.
- [FRANCHISE_ARCHITECTURE.md](architecture/FRANCHISE_ARCHITECTURE.md) — additive franchise / multi-location layer (planned, not built).
- [SMS_ARCHITECTURE.md](architecture/SMS_ARCHITECTURE.md) — two-number SMS model + hardening (shipped); reservations email-only; **key-rotation list lives here**.
- [RESTAURANT_INVENTORY.md](architecture/RESTAURANT_INVENTORY.md) — ingredient inventory / BOM / auto-86 (built, not yet live; next phase).

## `security/` — audits & hardening
- [AUDIT_FINDINGS_2026-06-09.md](security/AUDIT_FINDINGS_2026-06-09.md) — storefront-platform + payments deep audit; money/correctness/payment-race findings (fixed) + staged decisions.
- [SECURITY_AUDIT_2026-06-11.md](security/SECURITY_AUDIT_2026-06-11.md) — 2026-06-11 security audit (CRITICAL/HIGH → SQL in `sql/SECURITY_FIXES_RUN_THESE.sql`).
- [SECURITY_AUDIT_PASS2_2026-06-11.md](security/SECURITY_AUDIT_PASS2_2026-06-11.md) — second-pass security audit.
- [SUPABASE_HARDENING.md](security/SUPABASE_HARDENING.md) — Supabase project hardening reference.

## `schema/` — live DB schema reference
- [SCHEMA_DRIFT_RECONCILIATION.md](schema/SCHEMA_DRIFT_RECONCILIATION.md) — live-vs-repo schema drift findings + standing follow-up (migration smoke gate).
- [LIVE_SCHEMA_2026-06-10.txt](schema/LIVE_SCHEMA_2026-06-10.txt) / [LIVE_FUNCTIONS_2026-06-10.txt](schema/LIVE_FUNCTIONS_2026-06-10.txt) — live DB snapshots used for the drift reconciliation.

## `sql/` — one-off bundles to run in the Supabase SQL editor
> Each mirrors numbered migrations in the app repo (`repo/supabase/migrations/`); these are the consolidated copies for one-shot manual application. **Run-status is the founder's call — confirm before deleting.**
- [FOUNDER_RUN_THESE.sql](sql/FOUNDER_RUN_THESE.sql) — overnight-fixes 2026-06-11 migrations (**founder side-quest: pending run**).
- [SECURITY_FIXES_RUN_THESE.sql](sql/SECURITY_FIXES_RUN_THESE.sql) — CRITICAL/HIGH from the 2026-06-11 audit (**founder side-quest: pending run**) — run FIRST.
- [SECURITY_OVERNIGHT_RUN_THESE.sql](sql/SECURITY_OVERNIGHT_RUN_THESE.sql) — medium/low overnight fixes (run after the above).
- [SECURITY_DEFECT_FIXES_RUN_THESE.sql](sql/SECURITY_DEFECT_FIXES_RUN_THESE.sql) — corrects 5 bugs introduced by an earlier security bundle.
- [RUN_ORDER_NUMBER.sql](sql/RUN_ORDER_NUMBER.sql) — daily-resetting human-friendly order numbers (pending feature).
- [SQUARE_SANDBOX_GOLIVE.sql](sql/SQUARE_SANDBOX_GOLIVE.sql) — test-bistro Square-sandbox seed/flip **+ the not-yet-run REVERT block** (needed before a real Stripe test order — READINESS gate B.10).

## `pitch/` · `business/` · `legal/` · `hardware/`
- [pitch/](pitch/) — investor deck (VC_PITCH_DECK, woahh-vc-deck), merchant pitch (RESTAURANT_PITCH), positioning brief, deck/video asset inventory.
- [business/](business/) — business strategy (locked financial model), master plan, shop architecture (deferred retail vertical).
- [legal/](legal/) — ABN registration guide, legalities (Spam Act / compliance checklists), expansion process.
- [hardware/](hardware/) — restaurant hardware recommendations.

## Elsewhere
- [REFUND_POLICY.md](../repo-audit/docs/REFUND_POLICY.md) — refund mechanics; lives in the **app repo** (`repo-audit/docs/`), not here.
