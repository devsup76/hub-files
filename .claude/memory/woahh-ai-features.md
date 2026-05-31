---
name: woahh-ai-features
description: "woahh AI features (menu copilot, campaign copy, decline reasons) — built on branch feature/ai-features in worktree repo-ai; 4 edge functions deployed; full state in docs/AI_ARCHITECTURE.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 34853477-267b-47da-a992-b8c3f693c13b
---

Four server-side Claude (Anthropic) features for woahh, built 2026-05-31 on branch **`feature/ai-features`** in an isolated git worktree at **`/workspaces/GrowthHub/repo-ai`** (created off `origin/main`, kept separate from the *other chat's* per-merchant SMS work in `repo/`). Pushed to origin; **NOT merged to `main` yet** (awaiting the user's browser UI sign-off).

**Deployed + live-verified** on Supabase project `pmnyhbhtkcfoozkinieo` (the `ANTHROPIC_API_KEY` edge-function secret is set):
- `ai-menu-copilot` — conversational multi-file menu builder (Sonnet 4.6 vision): chat + clarifying questions + a live editable draft (categories, size **options**, **add-ons**, **dietary** tags, **combos**); prompt caching on the uploaded media. Supersedes the one-shot `ai-menu-import` (still deployed, now unused).
- `ai-campaign` (Haiku 4.5) — SMS / email campaign copy. `ai-decline-reasons` (Haiku) — order decline-reason chips.

Shared edge modules: `_shared/anthropic.ts` (Claude client — note `completeJSON` must **not** prefill the assistant turn; `claude-sonnet-4-6` rejects prefill) + `_shared/auth.ts` (`resolveCaller`). Key is server-side only; never in the frontend bundle.

**Full architecture + the morning handoff checklist live in `/workspaces/GrowthHub/docs/AI_ARCHITECTURE.md` — read that first.**

Action items: (1) browser-test the menu-copilot **import save path** (the only flow not exercised end-to-end; edge brain is proven via `node /tmp/copilot_test.js`); (2) merge `feature/ai-features` → `main` when happy; (3) **ROTATE** the Anthropic key + the Supabase access token — both were pasted into chat. Test merchant: `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` at `/business/auth`. Supabase CLI ran via `npx supabase@latest … --project-ref pmnyhbhtkcfoozkinieo` (no local Docker — deploys through the API bundler). Related: [[woahh-sms-architecture]].
