#!/usr/bin/env bash
# Install no-vibe for Codex.
#
# Codex uses instruction-based enforcement via AGENTS.md at the project root.
# This script:
#   1. Runs scripts/sync.sh to ensure AGENTS.md is up to date with /shared/.
#   2. Copies AGENTS.md to the current project's root.
#   3. Copies skill prose + commands to .no-vibe/codex/ for reference.
#   4. Installs Codex-visible skills under ~/.codex/no-vibe/skills/.
#
# Run this script from inside a project directory you want to enable.

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT="${1:-$PWD}"

echo "Installing no-vibe (Codex) into project: $PROJECT_ROOT"

# Ensure generated AGENTS.md is current.
bash "$REPO_ROOT/scripts/sync.sh"

if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
    echo "WARNING: $PROJECT_ROOT/AGENTS.md already exists." >&2
    echo "Refusing to overwrite. Merge manually from: $REPO_ROOT/runtimes/codex/AGENTS.md" >&2
    exit 1
fi

cp "$REPO_ROOT/runtimes/codex/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
echo "wrote: $PROJECT_ROOT/AGENTS.md"

mkdir -p "$PROJECT_ROOT/.no-vibe/codex/skill" "$PROJECT_ROOT/.no-vibe/codex/commands"
cp "$REPO_ROOT/shared/skill"/*.md "$PROJECT_ROOT/.no-vibe/codex/skill/"
cp "$REPO_ROOT/shared/commands"/*.md "$PROJECT_ROOT/.no-vibe/codex/commands/"

mkdir -p "$HOME/.codex/no-vibe/skills/no-vibe-forget" "$HOME/.codex/no-vibe/skills/no-vibe-clear"
cp "$REPO_ROOT/runtimes/codex/skills/no-vibe-forget/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-forget/SKILL.md"
cp "$REPO_ROOT/runtimes/codex/skills/no-vibe-clear/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-clear/SKILL.md"

mkdir -p "$HOME/.no-vibe/memory"
if [ ! -f "$HOME/.no-vibe/NO-VIBE.md" ]; then
    cp "$REPO_ROOT/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
    cp "$REPO_ROOT/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
fi

echo "done. Codex will read AGENTS.md on session start."
