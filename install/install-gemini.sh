#!/usr/bin/env bash
# Install no-vibe for Gemini CLI.
#
# Default destination: ~/.gemini/extensions/no-vibe
# Override with: NO_VIBE_DEST=/path ./install/install-gemini.sh

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST="${NO_VIBE_DEST:-$HOME/.gemini/extensions/no-vibe}"

echo "Installing no-vibe (Gemini CLI) to: $DEST"

# Ensure generated GEMINI.md and .toml commands are current.
bash "$REPO_ROOT/scripts/sync.sh"

mkdir -p "$DEST/.gemini/commands" "$DEST/skills/no-vibe"

cp "$REPO_ROOT/runtimes/gemini/gemini-extension.json" "$DEST/"
cp "$REPO_ROOT/runtimes/gemini/GEMINI.md" "$DEST/"
cp "$REPO_ROOT/runtimes/gemini/.gemini/tool-mapping.md" "$DEST/.gemini/"
cp "$REPO_ROOT/runtimes/gemini/.gemini/commands"/*.toml "$DEST/.gemini/commands/" 2>/dev/null || true

cp "$REPO_ROOT/shared/skill"/*.md "$DEST/skills/no-vibe/"

mkdir -p "$HOME/.no-vibe/memory"
if [ ! -f "$HOME/.no-vibe/NO-VIBE.md" ]; then
    cp "$REPO_ROOT/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
    cp "$REPO_ROOT/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
fi

echo "done. Restart Gemini CLI for the extension to load."
