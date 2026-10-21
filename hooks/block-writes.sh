#!/usr/bin/env bash
# no-vibe PreToolUse hook: blocks Edit/Write/NotebookEdit/MultiEdit/apply_patch
# on paths outside .no-vibe/ when .no-vibe/active exists in cwd.
#
# Reads tool call as JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

# Normalize Windows-style drive paths (`C:/foo`, `c:\foo`) to MSYS form
# (`/c/foo`) so prefix comparisons stay consistent on Git Bash. See
# block-bash-writes.sh for the full rationale. Same fix, same reason.
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

. "$(dirname "$0")/json.sh"

input=$(cat)

cwd=$(json_get .cwd)
# JSON this reader cannot parse is refused while no-vibe is active, never
# waved through. The marker is then looked up from the hook's own cwd.
if [ $? -eq 2 ]; then
    if [ -f "$PWD/.no-vibe/active" ]; then
        echo "no-vibe mode is active. Refusing a tool call whose JSON could not be parsed." >&2
        exit 2
    fi
    exit 0
fi
cwd=$(normalize_path "$cwd")

# If marker doesn't exist, allow everything.
if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

tool_name=$(json_get .tool_name)
case "$tool_name" in
    Edit|Write|NotebookEdit|MultiEdit|ApplyPatch|apply_patch) ;;
    *) exit 0 ;;
esac

# apply_patch carries the patch text in tool_input.command instead of a path,
# so every file the patch adds, updates, deletes or moves to is checked.
case "$tool_name" in
    ApplyPatch|apply_patch)
        targets=$(json_get .tool_input.command |
            sed -n -E -e 's/^\*\*\* (Add|Update|Delete) File: (.*)$/\2/p' -e 's/^\*\*\* Move to: (.*)$/\1/p')
        ;;
    *)
        targets=$(json_get .tool_input.file_path || json_get .tool_input.notebook_path)
        ;;
esac

# No target means nothing to check against the allowlist: fail closed.
if [ -z "$targets" ]; then
    cat >&2 <<EOF
no-vibe mode is active. Refusing '$tool_name' because no target path was provided.
Show the code in chat and let the user type it into their project instead.
To exit no-vibe mode, the user can run \`/no-vibe off\`.
EOF
    exit 2
fi

home_dir=$(normalize_path "${HOME:-/root}")
if command -v realpath >/dev/null 2>&1; then
    scratch_root=$(normalize_path "$(realpath -m "$cwd/.no-vibe")")
    home_scratch_root=$(normalize_path "$(realpath -m "$home_dir/.no-vibe")")
else
    scratch_root="$cwd/.no-vibe"
    home_scratch_root="$home_dir/.no-vibe"
fi

deny() {
    cat >&2 <<EOF
no-vibe mode is active. You cannot write to '$1' while learning.
Show the code in chat instead, and let the user type it into their project
themselves. If you need to save lesson state, write it under \`.no-vibe/\`.

To exit no-vibe mode, the user can run \`/no-vibe off\`.
EOF
    exit 2
}

# Writes are allowed inside the project's .no-vibe/ and the global ~/.no-vibe/.
while IFS= read -r target; do
    [ -z "$target" ] && continue
    target=$(normalize_path "$target")
    case "$target" in
        /*) abs_target="$target" ;;
        *)  abs_target="$cwd/$target" ;;
    esac
    if command -v realpath >/dev/null 2>&1; then
        # -m so it doesn't fail if the file doesn't exist yet
        abs_target=$(normalize_path "$(realpath -m "$abs_target")")
    else
        abs_target=$(cd "$(dirname "$abs_target")" 2>/dev/null && pwd)/$(basename "$abs_target")
    fi
    case "$abs_target" in
        "$scratch_root"/*|"$scratch_root") ;;
        "$home_scratch_root"/*|"$home_scratch_root") ;;
        *) deny "$abs_target" ;;
    esac
done <<EOF
$targets
EOF

exit 0
