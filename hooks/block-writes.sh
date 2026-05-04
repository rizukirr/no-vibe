#!/usr/bin/env bash
# no-vibe PreToolUse hook: blocks Edit/Write/NotebookEdit/MultiEdit/ApplyPatch
# on paths outside .no-vibe/ when .no-vibe/active exists in cwd.
#
# Reads tool call as JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

# Normalize Windows-style drive paths (`C:/foo`, `c:\foo`) to MSYS form
# (`/c/foo`) so prefix comparisons stay consistent on Git Bash. See
# block-bash-writes.sh for the full rationale — same fix, same reason.
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

# Read all of stdin
input=$(cat)

# Parse cwd from input (jq required)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd=$(normalize_path "$cwd")

# If marker doesn't exist, allow everything.
if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

# Parse tool name. Only the four write-style tools matter.
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
case "$tool_name" in
    Edit|Write|NotebookEdit|MultiEdit|ApplyPatch|apply_patch) ;;
    *) exit 0 ;;
esac

# Extract the target path. Field name varies slightly by tool but
# all four currently use file_path or notebook_path at the top level.
target=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

# If we somehow can't find a target, fail closed (block).
if [ -z "$target" ]; then
    cat >&2 <<EOF
no-vibe mode is active. Refusing '$tool_name' because no target path was provided.
Show the code in chat and let the user type it into their project instead.
To exit no-vibe mode, the user can run \`/no-vibe off\`.
EOF
    exit 2
fi

# Normalize the target before path joining so a Windows-form target
# combined with an MSYS-form cwd produces a coherent absolute path.
target=$(normalize_path "$target")

# Resolve target to absolute path. If it's relative, anchor to cwd.
case "$target" in
    /*) abs_target="$target" ;;
    *)  abs_target="$cwd/$target" ;;
esac

# Resolve symlinks and .. — use realpath if available, else manual cleanup.
home_dir=$(normalize_path "${HOME:-/root}")
if command -v realpath >/dev/null 2>&1; then
    # -m so it doesn't fail if the file doesn't exist yet
    abs_target=$(normalize_path "$(realpath -m "$abs_target")")
    scratch_root=$(normalize_path "$(realpath -m "$cwd/.no-vibe")")
    home_scratch_root=$(normalize_path "$(realpath -m "$home_dir/.no-vibe")")
else
    abs_target=$(cd "$(dirname "$abs_target")" 2>/dev/null && pwd)/$(basename "$abs_target")
    scratch_root="$cwd/.no-vibe"
    home_scratch_root="$home_dir/.no-vibe"
fi

# Allow writes inside project-local .no-vibe/ (scratch escape hatch) and
# global ~/.no-vibe/ (cross-project learner state: profile.md, synth-state).
case "$abs_target" in
    "$scratch_root"/*|"$scratch_root") exit 0 ;;
    "$home_scratch_root"/*|"$home_scratch_root") exit 0 ;;
esac

# Otherwise — deny.
cat >&2 <<EOF
no-vibe mode is active. You cannot write to '$abs_target' while learning.
Show the code in chat instead, and let the user type it into their project
themselves. If you need to save a lesson note or summary, write it under
\`.no-vibe/\`.

To exit no-vibe mode, the user can run \`/no-vibe off\`.
EOF
exit 2
