#!/usr/bin/env bash
# Re-point Claude's ephemeral memory dir at a persistent workspace store, so
# memory survives container rebuilds. The live dir lives under ~/.claude (wiped
# on every container reset); only /workspaces/GrowthHub is a persistent mount.
# Idempotent + safe to run on every SessionStart.
set -euo pipefail

PERSIST="/workspaces/GrowthHub/.claude/memory"
LIVE="/home/vscode/.claude/projects/-workspaces-GrowthHub/memory"

mkdir -p "$PERSIST"
mkdir -p "$(dirname "$LIVE")"

# Already correctly linked → nothing to do.
if [ -L "$LIVE" ] && [ "$(readlink -f "$LIVE")" = "$(readlink -f "$PERSIST")" ]; then
  exit 0
fi

# Fresh container rebuilt a real dir here: migrate anything already written
# (keeping the persistent copy as source of truth), then replace with a symlink.
if [ -e "$LIVE" ] && [ ! -L "$LIVE" ]; then
  if [ -d "$LIVE" ]; then
    cp -an "$LIVE"/. "$PERSIST"/ 2>/dev/null || true
    rm -rf "$LIVE"
  else
    rm -f "$LIVE"
  fi
fi

# Stale / wrong-target symlink → drop it.
[ -L "$LIVE" ] && rm -f "$LIVE"

ln -s "$PERSIST" "$LIVE"
echo "link-memory: $LIVE -> $PERSIST"
