#!/usr/bin/env bash
# no-vibe PreToolUse hook: blocks Edit/Write/NotebookEdit/MultiEdit/ApplyPatch
# on paths outside .no-vibe/ and ~/.no-vibe/ when .no-vibe/active exists.
#
# Tool list comes from shared/guard/write-tools.json (single source of truth
# across all five runtimes).
#
# Reads tool call as JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    SHARED_DIR="$CLAUDE_PLUGIN_ROOT/shared"
else
    SHARED_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)
fi
TOOLS_JSON="$SHARED_DIR/guard/write-tools.json"

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

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd=$(normalize_path "$cwd")

if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty')

is_write_tool=0
while IFS= read -r t; do
    t=$(printf '%s' "$t" | tr -d '\r')
    [ "$tool_name" = "$t" ] && is_write_tool=1 && break
done < <(jq -r '.tools[]' "$TOOLS_JSON" 2>/dev/null)
[ "$is_write_tool" = "1" ] || exit 0

# Extract target via any path-field name listed in the JSON.
target=""
for field in $(jq -r '.path_fields[]' "$TOOLS_JSON" 2>/dev/null | tr -d '\r'); do
    candidate=$(echo "$input" | jq -r ".tool_input.$field // empty")
    if [ -n "$candidate" ]; then
        target="$candidate"
        break
    fi
done

if [ -z "$target" ]; then
    cat >&2 <<EOF
no-vibe mode is active. Refusing '$tool_name' because no target path was provided.
Show the code in chat and let the user type it themselves.
Run \`/no-vibe off\` to exit.
EOF
    exit 2
fi

target=$(normalize_path "$target")
case "$target" in
    /*) abs_target="$target" ;;
    *)  abs_target="$cwd/$target" ;;
esac

home_dir=$(normalize_path "${HOME:-/root}")
if command -v realpath >/dev/null 2>&1; then
    abs_target=$(normalize_path "$(realpath -m "$abs_target")")
    scratch_root=$(normalize_path "$(realpath -m "$cwd/.no-vibe")")
    home_scratch_root=$(normalize_path "$(realpath -m "$home_dir/.no-vibe")")
else
    abs_target=$(cd "$(dirname "$abs_target")" 2>/dev/null && pwd)/$(basename "$abs_target")
    scratch_root="$cwd/.no-vibe"
    home_scratch_root="$home_dir/.no-vibe"
fi

case "$abs_target" in
    "$scratch_root"/*|"$scratch_root") exit 0 ;;
    "$home_scratch_root"/*|"$home_scratch_root") exit 0 ;;
esac

cat >&2 <<EOF
no-vibe mode is active. Cannot write to '$abs_target' while learning.
Show code in chat; user types it. Save lesson notes under \`.no-vibe/\`.
Run \`/no-vibe off\` to exit.
EOF
exit 2
