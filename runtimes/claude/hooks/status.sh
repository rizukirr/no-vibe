#!/usr/bin/env bash
# no-vibe SessionStart hook: prints current mode + resume hint when a
# curriculum is in progress.
#
# v2 model: resume hint is sourced from .no-vibe/session.md (curriculum
# file) by counting unchecked items, not from JSON session files. Silent
# if .no-vibe/ does not exist (so unrelated projects stay quiet).

set -u

input=$(cat 2>/dev/null || true)
cwd=""
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
    cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -z "$cwd" ] && cwd="$PWD"

if [ ! -d "$cwd/.no-vibe" ]; then
    exit 0
fi

if [ ! -f "$cwd/.no-vibe/active" ]; then
    echo "no-vibe: OFF"
    exit 0
fi

line="no-vibe: ON"

session_md="$cwd/.no-vibe/session.md"
if [ -f "$session_md" ]; then
    topic=$(grep -m1 -E '^# Lesson:' "$session_md" 2>/dev/null | sed -E 's/^# Lesson:[[:space:]]*//')
    [ -z "$topic" ] && topic="untitled"
    total=$(grep -cE '^- \[[ x]\]' "$session_md" 2>/dev/null || true)
    done_count=$(grep -cE '^- \[x\]' "$session_md" 2>/dev/null || true)
    [ -z "$total" ] && total=0
    [ -z "$done_count" ] && done_count=0
    if [ "$total" -gt 0 ] && [ "$done_count" -lt "$total" ]; then
        line="$line — resuming \"$topic\" ($done_count/$total layers complete)"
    fi
fi

echo "$line"
exit 0
