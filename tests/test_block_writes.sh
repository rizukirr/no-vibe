#!/usr/bin/env bash
# Tests for .claude-plugin/hooks/block-writes.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../.claude-plugin/hooks/block-writes.sh"
. "$SCRIPT_DIR/helpers.sh"

# Each test runs in a fresh temp dir to isolate the .no-vibe/ marker.
make_sandbox() {
    local dir
    dir=$(mktemp -d)
    echo "$dir"
}

# --- Test 1: no marker → allow ---
test_no_marker_allows_edit() {
    local cwd
    cwd=$(make_sandbox)
    local input
    input=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$cwd/foo.py"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "no marker → exit 0 (allow)"
}

test_no_marker_allows_edit
summary
