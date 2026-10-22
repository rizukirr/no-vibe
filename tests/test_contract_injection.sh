#!/usr/bin/env bash
# Asserts the per-reply header contract lives in the no-vibe skill, both in
# its body and in the frontmatter description hosts show before loading it.

set -u
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/helpers.sh"

skill="$REPO_ROOT/skills/no-vibe/SKILL.md"
HEADER='[no-vibe] Step:'

if grep -qF "$HEADER" "$skill"; then
    pass "SKILL.md body contains '$HEADER'"
else
    fail "SKILL.md body contains '$HEADER'"
fi

desc_line=$(awk '/^description:/{print; exit}' "$skill")
case "$desc_line" in
    *"$HEADER"*) pass "SKILL.md description contains '$HEADER'" ;;
    *) fail "SKILL.md description contains '$HEADER'" "$desc_line" ;;
esac

for gone in phases.md curriculum.md reference-grounding.md; do
    if [ -e "$REPO_ROOT/skills/no-vibe/$gone" ]; then
        fail "skills/no-vibe/$gone removed"
    else
        pass "skills/no-vibe/$gone removed"
    fi
done

lines=$(wc -l < "$skill")
if [ "$lines" -le 200 ]; then
    pass "SKILL.md is at most 200 lines"
else
    fail "SKILL.md is at most 200 lines" "$lines lines"
fi

summary
