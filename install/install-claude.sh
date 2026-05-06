#!/usr/bin/env bash
# Install no-vibe for Claude Code (manual install — fallback).
#
# The recommended install path is the marketplace:
#   /plugin marketplace add rizukirr/no-vibe
#   /plugin install no-vibe@no-vibe
#
# This script is for users who want to install offline / from a local
# clone. It copies runtimes/claude/ (which is self-contained post-sync)
# into the user's Claude plugins directory.
#
# Default destination: ~/.claude/plugins/no-vibe
# Override with: NO_VIBE_DEST=/path ./install/install-claude.sh

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST="${NO_VIBE_DEST:-$HOME/.claude/plugins/no-vibe}"

echo "Installing no-vibe (Claude Code) to: $DEST"

# Make sure the runtimes/claude/ tree is fresh from /shared/.
bash "$REPO_ROOT/scripts/sync.sh" >/dev/null

mkdir -p "$DEST"
# Copy the self-contained Claude plugin tree.
cp -R "$REPO_ROOT/runtimes/claude"/. "$DEST/"
chmod +x "$DEST/hooks"/*.sh

# Seed global ~/.no-vibe/NO-VIBE.md from template if missing.
mkdir -p "$HOME/.no-vibe/memory"
if [ ! -f "$HOME/.no-vibe/NO-VIBE.md" ]; then
    cp "$REPO_ROOT/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
    cp "$REPO_ROOT/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
    echo "seeded: $HOME/.no-vibe/NO-VIBE.md"
fi

echo "done. Restart Claude Code for the plugin to load."
