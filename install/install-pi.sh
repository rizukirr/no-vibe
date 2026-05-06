#!/usr/bin/env bash
# Install no-vibe for Pi.
#
# Default destination: ~/.pi/plugins/no-vibe
# Override with: NO_VIBE_DEST=/path ./install/install-pi.sh

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST="${NO_VIBE_DEST:-$HOME/.pi/plugins/no-vibe}"

# Pi-specific: skip when already installed at any known Pi location.
# Other runtimes overwrite freely; Pi does not because users may have it
# wired through .agents/skills/ or a different .pi/ layout we shouldn't
# clobber.
existing=()
[ -d "$HOME/.agents/skills/no-vibe" ] && existing+=("$HOME/.agents/skills/no-vibe")
[ -d "$HOME/.pi/plugins/no-vibe" ] && existing+=("$HOME/.pi/plugins/no-vibe")
[ -d "$HOME/.pi/extensions/no-vibe" ] && existing+=("$HOME/.pi/extensions/no-vibe")

if [ "${#existing[@]}" -gt 0 ]; then
    echo "no-vibe is already installed for Pi at:"
    for p in "${existing[@]}"; do echo "  $p"; done
    echo "Skipping — remove the existing install first if you want to reinstall."
    exit 0
fi

echo "Installing no-vibe (Pi) to: $DEST"

mkdir -p "$DEST/extensions/no-vibe" "$DEST/prompts" "$DEST/skills/no-vibe" "$DEST/shared/guard" "$DEST/shared/templates"

cp "$REPO_ROOT/runtimes/pi/.pi-plugin/plugin.json" "$DEST/"
cp "$REPO_ROOT/runtimes/pi/.pi-plugin/extensions/no-vibe/index.ts" "$DEST/extensions/no-vibe/"

cp "$REPO_ROOT/shared/skill"/*.md "$DEST/skills/no-vibe/"
cp "$REPO_ROOT/shared/commands"/*.md "$DEST/prompts/"
cp "$REPO_ROOT/shared/guard"/*.json "$DEST/shared/guard/"
cp "$REPO_ROOT/shared/templates"/*.md "$DEST/shared/templates/"

mkdir -p "$HOME/.no-vibe/memory"
if [ ! -f "$HOME/.no-vibe/NO-VIBE.md" ]; then
    cp "$REPO_ROOT/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
    cp "$REPO_ROOT/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
    echo "seeded: $HOME/.no-vibe/NO-VIBE.md"
fi

echo "done. Restart Pi for the plugin to load."
