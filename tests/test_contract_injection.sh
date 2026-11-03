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

# The book model, the context step, project.md and the do-no-harm rule.
BOOK_HEADER='<context|level|goal|roadmap|learn|exercise|check> · Chapter: <n/total|-> · Section: <k|-> · Exercise: <k|->'
case "$desc_line" in
    *"$BOOK_HEADER"*) pass "SKILL.md description carries the book header" ;;
    *) fail "SKILL.md description carries the book header" "$desc_line" ;;
esac
for needle in "$BOOK_HEADER" '### 0. context' 'Relevance check' '## Do no harm' '## Explaining' 'Use visuals often' '## Stack' '## Structure' '## Conventions' '## Works' '## Open' 'Every multiple-choice question ends with an open option' '## The book' 'Every step has a reason' 'Plan backward from the goal' 'Before an optional chapter or section' 'Read more:' 'When a chapter begins, plan its sections' 'Core:' 'Always ask it as its own question' 'Do not stop there' 'Keep every search scoped to the goal' '### 4. chapter' '### 5. build' '### 6. check' '## Notes' '## ROADMAP.md' 'Build:' 'practice:' '.no-vibe/practice/'; do
    if grep -qF -- "$needle" "$skill"; then
        pass "SKILL.md contains '$needle'"
    else
        fail "SKILL.md contains '$needle'"
    fi
done

lines=$(wc -l < "$skill")
if [ "$lines" -le 320 ]; then
    pass "SKILL.md is at most 320 lines"
else
    fail "SKILL.md is at most 320 lines" "$lines lines"
fi

summary
