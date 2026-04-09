#!/usr/bin/env bash
# no-vibe PreToolUse hook: blocks Edit/Write/NotebookEdit/MultiEdit
# on paths outside .no-vibe/ when .no-vibe/active exists in cwd.
#
# Reads tool call as JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

# Read all of stdin
input=$(cat)

# Parse cwd from input (jq required)
cwd=$(echo "$input" | jq -r '.cwd // empty')

# If marker doesn't exist, allow everything.
if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

# Marker exists — but for now, still allow. (Subsequent tasks tighten this.)
exit 0
