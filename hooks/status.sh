#!/usr/bin/env bash
# no-vibe SessionStart hook: prints current mode status, plus a one-line
# resume hint for the most recently modified in-progress session (so
# /compact, /clear, and fresh sessions re-anchor on the curriculum).
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

if [ ! -f "$cwd/.no-vibe/active" ]; then
    echo "no-vibe: OFF"
    exit 0
fi

line="no-vibe: ON"

# Try to surface the most recently modified in-progress session, so the
# AI re-enters Phase 0 with the topic and layer pointer in context. If
# jq is missing or no sessions exist, we keep the bare "ON" line.
sessions_dir="$cwd/.no-vibe/data/sessions"
if [ -d "$sessions_dir" ] && command -v jq >/dev/null 2>&1; then
    latest=""
    latest_mtime=0
    for f in "$sessions_dir"/*.json; do
        [ -f "$f" ] || continue
        status=$(jq -r '.status // empty' "$f" 2>/dev/null)
        [ "$status" = "in_progress" ] || continue
        mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$latest_mtime" ]; then
            latest_mtime="$mtime"
            latest="$f"
        fi
    done
    if [ -n "$latest" ]; then
        topic=$(jq -r '.topic // "untitled"' "$latest" 2>/dev/null)
        cur=$(jq -r '.current_layer // 0' "$latest" 2>/dev/null)
        tot=$(jq -r '.layers_total // 0' "$latest" 2>/dev/null)
        phase=$(jq -r '.current_phase // "?"' "$latest" 2>/dev/null)
        line="$line — resuming \"$topic\" (layer $cur/$tot, $phase)"
    fi
fi

echo "$line"

# --- Adaptation Iron Law: inject the AI's progression files
# (~/.no-vibe/PROFILE.md = global stable identity, .no-vibe/SUMMARY.md =
# project running journey) and the user's override files (every *.md
# under user/, both scopes) into the system prompt. The runtime never
# creates or writes any of these — AI creates PROFILE.md on first
# activation and SUMMARY.md at the first layer close worth recording per
# the schemas in skills/no-vibe/SKILL.md; user owns user/. Read order in
# SKILL.md "The Adaptation Iron Law". The whole block is wrapped in a
# `## Background Memory` preamble (DeepTutor pattern) telling the AI to
# use it sparingly. ---

emit_file() {
    local label="$1" path="$2" placeholder="$3"
    echo
    if [ -f "$path" ]; then
        echo "=== $label ($path) ==="
        cat "$path"
        echo "=== END $label ==="
    else
        echo "=== $label (not present — $path) ==="
        echo "$placeholder"
        echo "=== END $label ==="
    fi
}

emit_user_dir() {
    local label="$1" dir="$2" placeholder="$3"
    echo
    echo "=== $label ($dir/) ==="
    if [ -d "$dir" ]; then
        local found=0
        # POSIX-portable sorted glob; suppress nullglob warnings via [ -e ] guard.
        for f in "$dir"/*.md; do
            [ -e "$f" ] || continue
            found=1
            echo "--- $f ---"
            cat "$f"
        done
        if [ "$found" -eq 0 ]; then
            echo "$placeholder"
        fi
    else
        echo "$placeholder"
    fi
    echo "=== END $label ==="
}

echo
echo "## Background Memory"
echo "Use this memory sparingly — only when directly relevant to the current turn."
echo "Read order: PROFILE (global stable) → SUMMARY (project running) → user/ (user overrides). user/ wins on conflict."

emit_file "GLOBAL PROFILE" "$HOME/.no-vibe/PROFILE.md" \
    "PROFILE.md missing — AI creates it on first activation per the schema in SKILL.md \"PROFILE.md and SUMMARY.md — the progression files\"."
emit_file "PROJECT SUMMARY" "$cwd/.no-vibe/SUMMARY.md" \
    "SUMMARY.md not yet created — appears at the first layer close worth recording. Schema in SKILL.md \"PROFILE.md and SUMMARY.md — the progression files\"."
emit_user_dir "GLOBAL USER OVERRIDES" "$HOME/.no-vibe/user" \
    "No user-authored override files — defaults, PROFILE.md, and SUMMARY.md apply unmodified."
emit_user_dir "PROJECT USER OVERRIDES" "$cwd/.no-vibe/user" \
    "No user-authored override files — defaults, PROFILE.md, and SUMMARY.md apply unmodified."

exit 0
