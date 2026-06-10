# AI Features — Architecture & Progress

> Server-side Claude (Anthropic) features for woahh. **`ANTHROPIC_API_KEY` lives only in
> Supabase edge-function secrets — never the frontend.** All calls route through edge functions.
> Branch: `feature/ai-features` (worktree at `/workspaces/GrowthHub/repo-ai`, off `origin/main`).
> Last updated: 2026-05-31

---

## Decisions (locked 2026-05-31)

| Decision | Choice |
|---|---|
| **Scope** | Three core onboarding wins: **menu import**, **campaign copy generator**, **decline-reason suggestions**. (Assistant chat, analytics narrator, marketplace AI search deferred.) |
| **Models** | **Sonnet 4.6 (`claude-sonnet-4-6`) everywhere** (switched off Haiku 2026-06-01 per request). Overridable via `ANTHROPIC_MODEL_SONNET`. Note: the model swap did not change the ~5s round-trip — that latency is edge cold-start + network, not Haiku-vs-Sonnet. |
| **Search / embeddings** | Not building marketplace AI search this round (avoids pgvector + a 2nd embeddings key). |
| **Delivery** | Feature branch `feature/ai-features`, pushed to remote. |
| **Provider** | Anthropic only — one key (`ANTHROPIC_API_KEY`). |
| **Menu upload transport** | Base64 sent directly to the edge function (no Storage bucket in v1). Images downscaled client-side. |
| **Tier gating** | None — these are onboarding/retention accelerators; available to all tiers. |
| **JWT** | AI functions use Supabase default `verify_jwt = true` (NOT listed in `config.toml`). Each also re-validates via `resolveCaller`. |

---

## Shared foundation (hand-built, coherent base)

| File | Purpose |
|---|---|
| `supabase/functions/_shared/anthropic.ts` | Claude Messages API client: `MODELS`, `complete()`, `completeJSON()` (tolerant JSON extractor — fences/prose; **no assistant-prefill**, since `claude-sonnet-4-6` rejects it), `imageBlock()`, `pdfBlock()`, `AnthropicError` (carries HTTP status), shared `corsHeaders` + `json()`. Structured `[anthropic]` logging w/ token usage. |
| `supabase/functions/_shared/auth.ts` | `resolveCaller(authHeader)` → validates JWT (anon `getUser`) + resolves org (owner-first, then active staff) → `{ uid, orgId, admin }`. Mirrors `customer-invite-send`. |

Every AI edge function is therefore tiny: `resolveCaller` → call Claude → return JSON. Errors funnel through `AnthropicError` so rate-limit (429) / overloaded (503) pass through with sane codes.

---

## Features

### 1. Menu **copilot** (multi-file, conversational) — `ai-menu-copilot` (Sonnet 4.6 vision)  ⭐ v2
> Upgraded 2026-05-31 from the one-shot `ai-menu-import` into a conversational copilot (commit `ac113cd`).
- **Edge fn `ai-menu-copilot`:** accepts `{ files?: [{file,mediaType}], draft?, chat?, instruction? }` → returns `{ reply, questions, draft, done }`. Reads **multiple photos/PDFs as one menu**; revises the COMPLETE draft each turn from the merchant's current (hand-edited) draft. Rich `draft` schema: `categories`, `items` (`price_cents|null` + `needs_attention`, **size options**, **add-ons**, **dietary** tags), `combos`. `maxTokens: 16000`, temp 0.2, defensive cents/array coercion. **Prompt caching** (`cache_control` on the uploaded media) so each turn re-reads photos cheaply.
- **Frontend (`MenuImportDialog.tsx`, rewritten in place — same export/props, `Menu.tsx` untouched):** two-pane dialog — LEFT chat with **clarifying-question quick-reply chips** + multi-file "Add photos"; RIGHT **live editable review table** (items grouped by category, options/add-on badges, dietary chips, **combos** section). Hand-edits flow back into the next AI turn. **Import** maps options+addons → `extras_list`, dietary → `tags`, links combos to created products by name via `comboApi.create`. **Never auto-publishes.**
- **Guardrails / fixes:** multi-file size caps; **include/exclude keyed by stable string (name+category), not array index** (so a copilot turn that reorders rows can't import deselected items — the key adversarial fix); negative prices clamped ≥0 + import guard; blank/`needs_attention` rows block save.
- **Old one-shot `ai-menu-import`** remains deployed but is **superseded** (UI no longer calls it). Safe to delete later.
- **Status:** ✅ built + adversarially reviewed + **live-verified** (2-turn convo: extract → rename category / add GF / add an extra). UI end-to-end (browser import) still wants a human pass.

### 2. Campaign copy generator — `ai-campaign` (Haiku 4.5)
- **Edge fn:** accepts `{ channel: "sms"|"email", goal, tone, extra?, maxChars? }` → returns SMS `{ body }` (trimmed to the caller's `maxChars`, incl. opt-out reminder) or Email `{ subject, headline, body, ctaText }`.
- **Frontend:** "Generate with AI" button (Sparkles) in **SMSCampaigns.tsx** (fills `setBody`, clamped to `MESSAGE_MAX`=130) and **EmailCampaigns.tsx** (fills `setSubject`/`setHeadline`/`setBodyText`/`setCtaText`). Goal + tone pickers. Surgical, self-contained edits to keep merge surface with the SMS branch minimal.
- **Hardening:** SMS generator honours the composer's real 130-char cap (badge + trim + `canSend` now gates `charsLeft>=0`); email returns a goal-matched `headline` so the hero heading isn't the stale promo default.
- **Status:** ✅ built + verified · `ai-campaign/index.ts`, `AiCampaignDialog.tsx`, `SMSCampaigns.tsx`, `EmailCampaigns.tsx`

### 3. Decline-reason suggestions — `ai-decline-reasons` (Haiku 4.5)
- **Edge fn:** accepts `{ items, fulfillment, total, localTime }` → returns `{ reasons: string[] }` (3 short, customer-friendly decline reasons).
- **Frontend:** replaces the **hardcoded** quick-reason chips in the Orders decline dialog (`ApprovalCard`, Orders.tsx) with AI-suggested chips (lazy-fetched when the dialog opens; re-fetches each open for fresh time-of-day context; falls back to the static list on error/demo/empty). Merchant taps one or types their own.
- **Status:** ✅ built + verified · `ai-decline-reasons/index.ts`, `Orders.tsx`

---

## Secrets to set before go-live (Supabase edge-function secrets)

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...   # provided by owner; server-side only
# optional pins:
# supabase secrets set ANTHROPIC_MODEL_HAIKU=claude-haiku-4-5
# supabase secrets set ANTHROPIC_MODEL_SONNET=claude-sonnet-4-6
```
No `VITE_` var is added — the key never touches the bundle.

---

## Build verification (done 2026-05-31)

Each feature was built by a dedicated agent then reviewed by an independent adversarial verifier. Findings applied:
- **menu-import** (verdict pass): vision `maxTokens` 4096→**8192** (truncation on big menus); **blank price now blocks save**; removed dead `Label` import.
- **campaign-copy** (verdict needs-fix → **fixed**): **HIGH** — AI SMS could exceed the composer's 130 cap and still send → dialog now takes `maxChars`, edge fn targets+trims to it, `onApply` clamps, `canSend` gates `charsLeft>=0`; **MEDIUM** — email now returns a goal-matched `headline` (was leaving the generic promo default).
- **decline-reasons** (verdict pass): guard re-set on dialog close (re-fetch per open); empty-after-filter no longer renders zero chips.

Checklist:
- [x] `npx tsc --noEmit` — zero errors in any AI-feature file (pre-existing errors in untouched `Auth.tsx`/`AdminCodes.tsx`/`Customers.tsx` only)
- [x] `npm run build` succeeds (exit 0)
- [x] No key leakage — `grep -riE "anthropic|sk-ant|x-api-key" src/ dist/` returns nothing
- [x] **`ANTHROPIC_API_KEY` secret set** on Supabase project `pmnyhbhtkcfoozkinieo` (2026-05-31)
- [x] **Deployed** `ai-menu-import` + `ai-campaign` + `ai-decline-reasons` (all ACTIVE v1, 2026-05-31)
- [x] **Live-verified all 3** via test-merchant JWT: `ai-menu-import` (PDF → 3 categories / 8 items, correct cents + a "Large +$3.00" size-option), `ai-campaign` (SMS + email, goal-matched headline), `ai-decline-reasons` (3 contextual reasons). OPTIONS=200, anon POST=401 (auth gate works).
- [x] **Bug found + fixed during live test:** `claude-sonnet-4-6` rejects assistant-prefill ("must end with a user message") → menu-import was 400'ing. Removed the default prefill in `completeJSON` (commit `097fa54`) and redeployed all 3. Haiku tolerated prefill so campaign/decline were unaffected.
- [x] **Menu COPILOT (v2) built + live-verified** — `ai-menu-copilot` deployed (ACTIVE), 2-turn conversation passes (multi-file vision, size options/add-ons/dietary/combos, prompt caching). Adversarial review fixed the index-keyed include bug (now stable-key) + negative-price clamp. Commits `ac113cd` (copilot) on top of the campaign/decline/import work.
- [ ] Optional final pass through the **preview UI** (buttons render + flows feel right), then merge `feature/ai-features` → `main`.
- [ ] Rotate the shared Anthropic key + the Supabase access token after testing (both passed through chat).

---

## 🌅 MORNING STATE (handoff — 2026-05-31 night)

**Everything is built, deployed, and live-verified. Branch `feature/ai-features` is pushed; nothing is merged to `main` yet (waiting on your UI sign-off).**

**4 AI features live on Supabase `pmnyhbhtkcfoozkinieo`** (all ACTIVE, `ANTHROPIC_API_KEY` set):
| Feature | Edge fn | Live-tested via curl |
|---|---|---|
| Menu **copilot** (multi-file, chat, options/add-ons/dietary/combos) | `ai-menu-copilot` | ✅ 2-turn convo |
| Campaign copy (SMS + email) | `ai-campaign` | ✅ |
| Decline reasons | `ai-decline-reasons` | ✅ |
| (old one-shot import, superseded) | `ai-menu-import` | ✅ (unused by UI now) |

**What's left for you (in order):**
1. **Test in the browser.** Open the latest Cloudflare Pages preview for the `feature/ai-features` branch (a fresh build was triggered by commit `ac113cd`). Log in: `pawitsingh23+merchant@gmail.com` / `WoahhTest2026!` at `/business/auth`.
   - **Menu → "Import menu with AI"** → upload 1+ menu photos/PDFs → chat to refine ("merge X into Y", "add GF to all pasta") → edit the table → **Import** → confirm items + a combo land. *(This is the only flow not yet exercised end-to-end — the edge brain is proven, but the browser import path needs a human click-through.)*
   - **SMS/Email composer → "Generate with AI"**, **Orders → Decline → AI chips** (already proven).
2. **If happy → merge `feature/ai-features` → `main`.** (Cloudflare Pages prod still served by Lovable per `MIGRATION_OFF_LOVABLE.md`; merging just lands the code.)
3. **Rotate secrets** — the Anthropic key + the Supabase access token both passed through chat. New Anthropic key = one `supabase secrets set ANTHROPIC_API_KEY=…`.

**Worktree:** `/workspaces/GrowthHub/repo-ai` on `feature/ai-features` (isolated from the SMS chat's `repo/`). Reusable copilot test: `node /tmp/copilot_test.js`.

**Known follow-ups (not blockers):** browser end-to-end of the import-save (products/combos write path); could delete the superseded `ai-menu-import`; demo-mode chat turns are canned (don't call the model).
