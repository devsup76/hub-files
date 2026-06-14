---
name: woahh-agentic-dev-workflow
description: Decision/architecture for running autonomous coding agents on the live woahh app — Linear + Slack + GitHub + Claude Code
metadata: 
  node_type: memory
  type: project
  originSessionId: 213112d3-cbd5-4cb0-9221-3a0ba2396e4e
---

Founder wants to move from ad-hoc "Claude works a branch → review → repeat" to a fleet of **autonomous coding agents** in a collab env, tracked in **Slack + Linear** (asked 2026-06-14: "is that the best approach?"). Researched + decided.

**Verdict:** Slack + Linear are a GOOD front-of-house but only 2 of 3 pillars. The **missing safety spine = GitHub PRs + mandatory CI + required human review + branch protection on `main`** — lives in GitHub (devsup76/business-growth-hub), NOT Linear/Slack. Linear = orchestration+audit plane that POINTS AT GitHub PRs (via Agent Session `externalUrls`), never a merge path. **No first-party Anthropic↔Linear agent yet** (claude-code#12925 open) — build the assign→run loop yourself via **Cyrus** (open-source runner that makes Claude Code an assignable Linear agent, git-worktree-per-issue, streams Agent Activities back) or a small **Agent SDK dispatcher** on the AgentSessionEvent webhook. Linear **MCP** (`claude mcp add --transport http linear https://mcp.linear.app/mcp`) alone = read/write tool access, NOT the delegation loop.

**The stack (pillars):** Work/control = **Linear** (Agent Sessions + Cyrus/Agent-SDK runner); Runtime = **Claude Code on the $200 Max sub** (`claude -p`, one git worktree per issue, NO live-DB access); Code/CI/review = **GitHub** (PRs + branch protection + a NEW Actions CI + a reviewer agent DISTINCT from the builder — Claude Code GitHub Action @v1 / /code-review / CodeRabbit); Comms/human-gate = **Slack**; Secrets = **the vault container** (task-scoped short-lived tokens); Observability = **Sentry → auto-files Linear issues**.

**Loop:** Linear issue (spec + bounded file set + risk label) → delegate to agent (human stays primary assignee = accountable) → dispatcher spins worktree off main → Claude Code builds, tests, pushes `claude/issue-NNN` → Cloudflare preview + GitHub PR (link in session externalUrls) → CI (tsc+vitest+build+RLS test+CI-gaming check) + reviewer agent (blocking) → Slack human-gate msg → **human merges** (branch protection blocks agent merge) → prod. **Migrations NEVER auto** — agent proposes SQL in PR, human applies in Supabase editor.

**⚠️ URGENT before scaling agents (the "crawl" phase):** (1) **Rotate the live `ghp_` PAT embedded in BOTH git remote URLs** (confirmed observed) + all pasted-unrotated tokens (sbp_f400…, sbp_c40f…, ClickSend) → vault them. (2) **Add `.github/workflows` CI** — none exists in business-growth-hub today. (3) Add a **blocking cross-tenant RLS isolation test** (pgTAP / org1-vs-org2). (4) **Turn on branch protection** on `main` (founder-merge is convention-only today). (5) Add Linear MCP to work issues manually first.

**Guardrails (permanent):** no agent merges to main; payments(square-payment/refund-order/order-respond)/order-state-machine/RLS/tier-commission = HUMAN-LED forever; migrations serialized + human-applied (already hit timestamp collisions); agents get ZERO prod-DB access + ZERO standing secrets (work the RPC layer); reviewer ≠ builder; scope issues to disjoint file sets + serialize hot files (Menu.tsx/Orders.tsx/App.tsx/types.ts) + migration authoring; treat merchant/PR/issue text as untrusted (prompt-injection); mind the **June-15-2026 Agent SDK credit billing** change (parallel `claude -p` draws a separate pool then API rates).

**Rollout:** Crawl (fix spine: rotate+CI+RLS test+branch protection+Linear MCP) → Walk (ONE delegated agent via Cyrus/Agent-SDK + Slack gate + blocking reviewer agent; climb autonomy ladder add-tests→small-fixes→low-risk-refactors→doc/dep only) → Run (3–10 parallel agents, planner→builder→reviewer→shepherd, Sentry→Linear loop, dependency metadata to serialize hot files). Humans merge + payments/RLS human-led PERMANENTLY.

**Next offered:** I can do the crawl-phase CODE now (write `.github/workflows/ci.yml`, the cross-tenant RLS test, branch-protection settings doc, Linear MCP setup) — secret rotation is the founder's (interactive).
