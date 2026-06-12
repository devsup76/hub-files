---
name: woahh-push-merge-policy
description: "Founder directive 2026-06-12 (scoped) — hub-files ONLY: always pull first and commit+push immediately after every change so teammates see progress; app repo keeps branch-then-founder-merge workflow"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8247c908-37ec-4f1c-bcb5-8c2df7a2fb0a
---

**Founder (2026-06-12): "always push and merge after we make a change" + "and pull as well" — then scoped: "that policy is only for hub files, not the app, so teammates can see progress on files."**

**Why:** the founder + a teammate both work off the `hub-files` planning repo (TODO list, docs, research) and need every change visible to each other immediately. The app repo is different — merges to `main` deploy straight to prod (Cloudflare), so app merges stay deliberate.

**How to apply:**
- **`hub-files` (/workspaces/GrowthHub):** ALWAYS `git pull` at the start of work and before editing shared files (teammate pushes too); commit + push to `master` IMMEDIATELY after every change (TODO edits, docs, memory). Never leave hub-files work unpushed at end of turn.
- **App repo (`business-growth-hub`, repo/ + worktrees):** NOT covered. Keep the existing convention: feature branches pushed for Cloudflare previews; merge to `main` only when the founder asks or explicitly approves (a branch push = preview; `main` = prod). Pulling first is still good hygiene everywhere.
- Historical note: on 2026-06-12, before this scoping, the barber-preview branch + a teammate's `feat/wallets` fix were merged to app `main` under the broad reading — founder did not ask to revert.
