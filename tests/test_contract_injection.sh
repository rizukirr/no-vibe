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

# The context step, project.md and the do-no-harm rule.
case "$desc_line" in
    *"<context|level|goal|syllabus|learn|exercise>"*) pass "SKILL.md description lists the context step" ;;
    *) fail "SKILL.md description lists the context step" "$desc_line" ;;
esac
for needle in '<context|level|goal|syllabus|learn|exercise>' '### 0. context' 'Relevance check' '## Do no harm' '## Stack' '## Structure' '## Conventions' '## Works' '## Open' 'Always end with an open option' 'End with an open option here too'; do
    if grep -qF -- "$needle" "$skill"; then
        pass "SKILL.md contains '$needle'"
    else
        fail "SKILL.md contains '$needle'"
    fi
done

lines=$(wc -l < "$skill")
if [ "$lines" -le 200 ]; then
    pass "SKILL.md is at most 200 lines"
else
    fail "SKILL.md is at most 200 lines" "$lines lines"
fi

summary
