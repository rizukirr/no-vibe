#!/usr/bin/env bash
# no-vibe SessionStart hook: prints the mode status, plus a resume hint when
# .no-vibe/syllabus.md holds an approved syllabus. Reads JSON on stdin for
# cwd and falls back to PWD.

set -u
. "$(dirname "$0")/json.sh"

input=$(cat 2>/dev/null || true)
cwd=$(json_get .cwd)
[ -z "$cwd" ] && cwd="$PWD"

# Silent in projects that never opted in.
[ -d "$cwd/.no-vibe" ] || exit 0

if [ ! -f "$cwd/.no-vibe/active" ]; then
    echo "no-vibe: OFF"
    exit 0
fi

line="no-vibe: ON"
syllabus="$cwd/.no-vibe/syllabus.md"

# The frontmatter value of $1, without CR, trailing spaces or YAML quotes.
field() {
    tr -d '\r' < "$syllabus" | sed -n "s/^$1:[[:space:]]*//p" | head -n 1 |
        sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
}

# Sections are the numbered checkbox lines the skill writes, `- [ ] 1. ...`.
sections() { tr -d '\r' < "$syllabus" | grep -cE "^- \[$1\] [0-9]+\. "; }

if [ -f "$syllabus" ] && [ "$(field status)" = "approved" ]; then
    total=$(sections '[ xX]')
    finished=$(sections '[xX]')
    if [ "$total" -gt 0 ] && [ "$finished" -lt "$total" ]; then
        line="$line, resuming \"$(field topic)\" (section $((finished + 1))/$total)"
    fi
fi

echo "$line"
exit 0
