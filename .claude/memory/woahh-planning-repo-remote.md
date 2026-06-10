---
name: woahh-planning-repo-remote
description: "The woahh planning/docs repo (hub-files) now lives under the devsup76 GitHub account, not Pawit12-spec"
metadata: 
  node_type: memory
  type: project
  originSessionId: f10c18b2-0a3b-4f7d-8fc2-09914b89bde1
---

The planning/docs repo at `/workspaces/GrowthHub` (branch `master`, contains `docs/WOAHH_FIXES_TODO.md`, `CLAUDE.md`, etc.) is the GitHub repo **`devsup76/hub-files`**.

It used to point at `Pawit12-spec/hub-files`, but that account's PAT (`ghp_AtJg…`) was revoked (API returns 401) — on 2026-06-02 the remote was switched to `https://github.com/devsup76/hub-files.git` and the push succeeded under a **devsup76** account PAT.

**Why:** pushing failed with "could not read Password / Repository not found" until both the account (Pawit12-spec → devsup76) and a fresh token were corrected.

**How to apply:** to push planning docs, the remote must be `devsup76/hub-files` and you need a current **devsup76** GitHub PAT. Never commit the token to memory — ask the user for a fresh one if the embedded one 401s. This is the docs repo only; the app code lives in `repo/` (separate Lovable-managed repo). See [[persistent-memory-setup]].
