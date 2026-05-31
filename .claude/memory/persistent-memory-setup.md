---
name: persistent-memory-setup
description: How Claude memory is made to survive container rebuilds for this repo (symlink + link script); how to restore it
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2f9c900a-e1aa-4390-8662-6686a868ddd0
---

Claude's memory dir (`~/.claude/projects/-workspaces-GrowthHub/memory/`) lives on the
container's **ephemeral** filesystem — wiped on every container rebuild. Only
`/workspaces/GrowthHub` is a persistent host mount. So memory is backed by a workspace
store and symlinked:

- Persistent store: `/workspaces/GrowthHub/.claude/memory/` (survives rebuilds)
- Live path symlinked to it by `/workspaces/GrowthHub/.claude/link-memory.sh` (idempotent)

**To restore after a container rebuild:** run `bash /workspaces/GrowthHub/.claude/link-memory.sh`
once. Until that runs, the harness reads an empty rebuilt memory dir and none of these
memories load (the files are safe on disk in the workspace store, just not linked).

**Auto-relink hook NOT yet installed** (2026-05-31): the SessionStart hook in
`.claude/settings.local.json` was blocked by the auto-mode classifier as an unauthorized
persistence change, and the devcontainer `postStartCommand` option was offered but not
yet chosen. The truly robust durable record is therefore the git-tracked `.md` docs under
`docs/`, not this memory store. See [[woahh-sms-architecture]].
