---
name: woahh-ai-features
description: "woahh AI features (menu copilot, campaign copy, decline reasons) — MERGED to main + deployed 2026-06-02 (origin/main f9a881d); browser-signed-off; edge fns on Sonnet 4.6; full state in docs/AI_ARCHITECTURE.md"
metadata: 
  node_type: memory
  type: project
  originSessionId: 34853477-267b-47da-a992-b8c3f693c13b
---

Four server-side Claude (Anthropic) features for woahh, built 2026-05-31 on branch **`feature/ai-features`** in an isolated git worktree at **`/workspaces/GrowthHub/repo-ai`**.

**✅ MERGED TO MAIN + DEPLOYED 2026-06-02** (origin/main @ `f9a881d`). Integrated origin/main into the branch first (clean, no conflicts), then fast-forwarded main. Cloudflare rebuilds prod woahh.app from main. **Browser sign-off DONE** via the recovered Playwright/chromium harness (/tmp/pwtest), against dev server on :8081 + injected merchant session: (a) **menu copilot import** — uploaded a menu image → real vision extraction ("5 items, 2 categories, 1 combo, Banana Bread GF") → draft rendered; (b) **edit-menu-with-AI** — loaded live menu → "add Bestseller to Plain Naan" → AI proposed the change in the draft (Apply NOT clicked, so live menu untouched; Apply data-loss fix was code-verified earlier). **3 edge fns redeployed** (`npx supabase functions deploy ai-campaign ai-decline-reasons ai-menu-copilot --project-ref pmnyhbhtkcfoozkinieo`, token from /tmp/sb-token now wiped) to sync the Sonnet swap + latest copilot/_shared. Post-deploy smoke test: ai-campaign → HTTP 200, valid SMS copy, 3.3s. **ROTATE the Supabase token `sbp_f400…` (pasted in chat 2026-06-02 for this deploy).**

**Deployed + live-verified** on Supabase project `pmnyhbhtkcfoozkinieo` (the `ANTHROPIC_API_KEY` edge-function secret is set):
- `ai-menu-copilot` — conversational multi-file menu builder (Sonnet 4.6 vision): chat + clarifying questions + a live editable draft (categories, size **options**, **add-ons**, **dietary** tags, **combos**); prompt caching on the uploaded media. Supersedes the one-shot `ai-menu-import` (still deployed, now unused).
- `ai-campaign` (now **Sonnet 4.6**) — SMS / email campaign copy. `ai-decline-reasons` (now **Sonnet 4.6**) — order decline-reason chips. (Both swapped Haiku→Sonnet in 461225f, deployed 2026-06-02.)

Shared edge modules: `_shared/anthropic.ts` (Claude client — note `completeJSON` must **not** prefill the assistant turn; `claude-sonnet-4-6` rejects prefill) + `_shared/auth.ts` (`resolveCaller`). Key is server-side only; never in the frontend bundle.

**Full architecture + the morning handoff checklist live in `/workspaces/GrowthHub/docs/AI_ARCHITECTURE.md` — read that first.**

Action items: (1) browser-test the menu-copilot **import save path** (the only flow not exercised end-to-end; edge brain is proven via `node /tmp/copilot_test.js`); (2) merge `feature/ai-features` → `main` when happy; (3) **ROTATE** the Anthropic key + the Supabase access token — both were pasted into chat. Test merchant: `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` at `/business/auth`. Supabase CLI ran via `npx supabase@latest … --project-ref pmnyhbhtkcfoozkinieo` (no local Docker — deploys through the API bundler). Related: [[woahh-sms-architecture]].
