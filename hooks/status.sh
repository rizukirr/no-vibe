#!/usr/bin/env bash
# no-vibe SessionStart hook: prints current mode status.
# Reads JSON on stdin to get cwd; falls back to PWD.

set -u

input=$(cat 2>/dev/null || true)
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
    cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

# Only announce status for projects that have opted in (a .no-vibe/ dir
# exists). Silent in unrelated projects to avoid context noise.
if [ ! -d "$cwd/.no-vibe" ]; then
    exit 0
fi

if [ -f "$cwd/.no-vibe/active" ]; then
    echo "no-vibe: ON"
else
    echo "no-vibe: OFF"
fi
exit 0
