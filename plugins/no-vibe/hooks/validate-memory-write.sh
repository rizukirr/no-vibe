#!/usr/bin/env bash
# no-vibe PreToolUse hook: validates that AI-issued Write calls targeting
# ~/.no-vibe/PROFILE.md or .no-vibe/SUMMARY.md contain at least one
# canonical section heading. This catches the failure mode where AI
# accidentally writes a chat reply into the progression file instead of
# a schema-preserving rewrite (DeepTutor's _is_valid_memory_rewrite).
#
# Only validates the `Write` tool (full file replacement). Edit /
# MultiEdit / NotebookEdit / ApplyPatch are not validated — they are for
# incremental updates and the existing file should already carry
# canonical headings.
#
# Reads tool call as JSON on stdin. Exit 0 = allow, exit 2 = block with
# stderr surfaced to the AI.

set -u

normalize_path() {
    local p="$1"
    p=$(printf '%s' "$p" | tr '\\' '/')
    case "$p" in
        [A-Za-z]:/*)
            local drive
            drive=$(printf '%s' "${p%%:*}" | tr '[:upper:]' '[:lower:]')
            p="/$drive${p#?:}"
            ;;
        [A-Za-z]:)
            local drive
            drive=$(printf '%s' "${p%%:*}" | tr '[:upper:]' '[:lower:]')
            p="/$drive"
            ;;
    esac
    printf '%s' "$p"
}

input=$(cat 2>/dev/null || true)
[ -z "$input" ] && exit 0

cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
cwd=$(normalize_path "$cwd")
[ -z "$cwd" ] && exit 0

# Only validate when no-vibe is active in this project. Consistent with
# the rest of the hook surface — we don't police writes in projects
# that haven't opted in.
[ -f "$cwd/.no-vibe/active" ] || exit 0

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool_name" = "Write" ] || exit 0

target=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$target" ] && exit 0
target=$(normalize_path "$target")

case "$target" in
    /*) abs_target="$target" ;;
    *)  abs_target="$cwd/$target" ;;
esac

home_dir=$(normalize_path "${HOME:-/root}")
if command -v realpath >/dev/null 2>&1; then
    abs_target=$(normalize_path "$(realpath -m "$abs_target")")
    global_profile=$(normalize_path "$(realpath -m "$home_dir/.no-vibe/PROFILE.md")")
    project_summary=$(normalize_path "$(realpath -m "$cwd/.no-vibe/SUMMARY.md")")
else
    global_profile="$home_dir/.no-vibe/PROFILE.md"
    project_summary="$cwd/.no-vibe/SUMMARY.md"
fi

target_kind=""
case "$abs_target" in
    "$global_profile") target_kind="profile" ;;
    "$project_summary") target_kind="summary" ;;
    *) exit 0 ;;
esac

content=$(echo "$input" | jq -r '.tool_input.content // empty' 2>/dev/null)

# An empty / missing content field on a Write call is malformed — let
# the existing tool plumbing handle the error rather than second-guess.
[ -z "$content" ] && exit 0

if [ "$target_kind" = "profile" ]; then
    canonical_re='^(## Identity & expertise|## Learning style|## Disclosure mode|## Observed strengths|## Known gaps)[[:space:]]*$'
    canonical_human='one of: "## Identity & expertise", "## Learning style", "## Disclosure mode", "## Observed strengths", "## Known gaps"'
    label="PROFILE.md"
else
    canonical_re='^(## Current Focus|## Accomplishments|## Open Questions)[[:space:]]*$'
    canonical_human='one of: "## Current Focus", "## Accomplishments", "## Open Questions"'
    label="SUMMARY.md"
fi

if printf '%s\n' "$content" | grep -Eq "$canonical_re"; then
    exit 0
fi

cat >&2 <<EOF
no-vibe heading-validation: refusing Write to $label ($abs_target).

The proposed content does not contain any canonical section heading. Expected $canonical_human.

This usually means a chat reply was about to be written into the file by mistake instead of a schema-preserving rewrite. Re-issue the Write with the correct schema, or use Edit for incremental updates that preserve the existing headings. See SKILL.md "PROFILE.md and SUMMARY.md — the progression files".
EOF
exit 2
