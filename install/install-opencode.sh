#!/usr/bin/env bash
# Install no-vibe for OpenCode.
#
# Default destination: ~/.config/opencode/plugins/no-vibe
# Override with: NO_VIBE_DEST=/path ./install/install-opencode.sh

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST="${NO_VIBE_DEST:-$HOME/.config/opencode/plugins/no-vibe}"

echo "Installing no-vibe (OpenCode) to: $DEST"

mkdir -p "$DEST/plugins" "$DEST/commands" "$DEST/skills/no-vibe" "$DEST/shared/guard" "$DEST/shared/skill" "$DEST/shared/templates"

cp "$REPO_ROOT/runtimes/opencode/plugins/no-vibe.js" "$DEST/plugins/"
cp "$REPO_ROOT/runtimes/opencode/index.js" "$DEST/"

# Skill files go to two places: $DEST/skills/no-vibe/ for OpenCode's native
# skill loader, and $DEST/shared/skill/ for the plugin's buildBootstrap()
# which resolves SHARED_DIR to $DEST/shared/ at runtime.
cp "$REPO_ROOT/shared/skill"/*.md "$DEST/skills/no-vibe/"
cp "$REPO_ROOT/shared/skill"/*.md "$DEST/shared/skill/"
cp "$REPO_ROOT/shared/commands"/*.md "$DEST/commands/"
cp "$REPO_ROOT/shared/guard"/*.json "$DEST/shared/guard/"
cp "$REPO_ROOT/shared/templates"/*.md "$DEST/shared/templates/"

mkdir -p "$HOME/.no-vibe/memory"
if [ ! -f "$HOME/.no-vibe/NO-VIBE.md" ]; then
    cp "$REPO_ROOT/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
    cp "$REPO_ROOT/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
    echo "seeded: $HOME/.no-vibe/NO-VIBE.md"
fi

echo "done. Restart OpenCode for the plugin to load."
