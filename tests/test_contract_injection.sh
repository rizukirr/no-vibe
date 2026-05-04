#!/usr/bin/env bash
# Asserts the Turn Response Contract block is present on every surface where
# the model reads instructions. Five-surface parity per CLAUDE.md.
#
# If any surface drops the contract this test fails — the contract must mirror
# across all five surfaces (Claude/Codex command, OpenCode command, Pi prompt,
# Gemini TOML command + GEMINI.md), plus appear in SKILL.md proper.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=helpers.sh
. "$SCRIPT_DIR/helpers.sh"

echo "== Turn Response Contract injection =="

# Stable substrings the contract must contain on every surface.
HEADER_FORMAT='[no-vibe] Phase:'
CONTRACT_TITLE='Turn Response Contract'

# (path, friendly-name) pairs. Codex inherits via commands/no-vibe.md per
# INSTALL.codex.md routing — no separate Codex file to check.
SURFACES=(
    "skills/no-vibe/SKILL.md|SKILL.md (canonical)"
    "commands/no-vibe.md|Claude command"
    ".opencode/commands/no-vibe.md|OpenCode command"
    ".pi-plugin/prompts/no-vibe.md|Pi prompt"
    ".gemini/commands/no-vibe.toml|Gemini TOML command"
    "GEMINI.md|GEMINI.md context"
)

for entry in "${SURFACES[@]}"; do
    rel_path="${entry%%|*}"
    name="${entry##*|}"
    abs_path="$REPO_ROOT/$rel_path"

    if [ ! -f "$abs_path" ]; then
        fail "$name exists" "$abs_path not found"
        continue
    fi

    if grep -qF "$CONTRACT_TITLE" "$abs_path"; then
        pass "$name contains '$CONTRACT_TITLE'"
    else
        fail "$name contains '$CONTRACT_TITLE'" "missing in $rel_path"
    fi

    if grep -qF "$HEADER_FORMAT" "$abs_path"; then
        pass "$name contains header format '$HEADER_FORMAT'"
    else
        fail "$name contains header format '$HEADER_FORMAT'" "missing in $rel_path"
    fi
done

# SKILL.md frontmatter description must include the contract summary so it
# reaches the model on skill-tool launch (the original drift root cause).
desc_line=$(awk '/^description:/{print; exit}' "$REPO_ROOT/skills/no-vibe/SKILL.md")
if echo "$desc_line" | grep -qF "$HEADER_FORMAT"; then
    pass "SKILL.md description includes header format"
else
    fail "SKILL.md description includes header format" "frontmatter description: line missing '$HEADER_FORMAT'"
fi

# Phase-format reminder section must appear before "## The Iron Law" so a
# reader hits it before the contract.
skill_md="$REPO_ROOT/skills/no-vibe/SKILL.md"
fmt_line=$(grep -n '^## Format conventions' "$skill_md" | head -1 | cut -d: -f1)
iron_line=$(grep -n '^## The Iron Law' "$skill_md" | head -1 | cut -d: -f1)
if [ -n "$fmt_line" ] && [ -n "$iron_line" ] && [ "$fmt_line" -lt "$iron_line" ]; then
    pass "SKILL.md Format conventions section precedes Iron Law"
else
    fail "SKILL.md Format conventions section precedes Iron Law" \
        "fmt_line=$fmt_line iron_line=$iron_line"
fi

# Drift-recovery subsection must exist.
if grep -qF 'When AI catches its own drift mid-session' "$skill_md"; then
    pass "SKILL.md contains drift-recovery subsection"
else
    fail "SKILL.md contains drift-recovery subsection" "missing heading"
fi

summary
