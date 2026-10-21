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
field() { sed -n "s/^$1:[[:space:]]*//p" "$syllabus" | head -n 1; }
if [ -f "$syllabus" ] && [ "$(field status)" = "approved" ]; then
    total=$(grep -cE '^- \[[ x]\] ' "$syllabus")
    finished=$(grep -cE '^- \[x\] ' "$syllabus")
    current=$((finished + 1))
    [ "$current" -gt "$total" ] && current=$total
    line="$line, resuming \"$(field topic)\" (section $current/$total)"
fi

echo "$line"
exit 0
