#!/usr/bin/env bash
# no-vibe SessionStart hook: prints the mode status, plus a resume hint when
# .no-vibe/ROADMAP.md holds an approved roadmap. Reads JSON on stdin for
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
roadmap="$cwd/.no-vibe/ROADMAP.md"

# The frontmatter value of $1, without CR, trailing spaces or YAML quotes.
# Inside quotes, '' becomes ' and \" or \\ lose their backslash, as in YAML.
# Only the outer quote style is undone, once.
field() {
    local v
    v=$(tr -d '\r' < "$roadmap" | sed -n "s/^$1:[[:space:]]*//p" | head -n 1 | sed 's/[[:space:]]*$//')
    case "$v" in
        \'*\') v=${v#\'}; v=${v%\'}; v=$(printf '%s' "$v" | sed "s/''/'/g") ;;
        \"*\") v=${v#\"}; v=${v%\"}; v=$(printf '%s' "$v" | sed 's/\\\(["\\]\)/\1/g') ;;
    esac
    printf '%s\n' "$v"
}

# Chapters are the numbered checkbox lines the skill writes, `- [ ] 1. ...`.
sections() { tr -d '\r' < "$roadmap" | grep -cE "^- \[$1\][[:space:]]+[0-9]+\. "; }

if [ -f "$roadmap" ] && [ "$(field status)" = "approved" ]; then
    total=$(sections '[ xX]')
    finished=$(sections '[xX]')
    if [ "$total" -gt 0 ] && [ "$finished" -lt "$total" ]; then
        line="$line, resuming \"$(field topic)\" (chapter $((finished + 1))/$total)"
    fi
fi

echo "$line"
exit 0
