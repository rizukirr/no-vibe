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

# --- Test 2: marker exists, Read tool → allow ---
test_marker_allows_read() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Read","tool_input":{"file_path":"$cwd/foo.py"},"cwd":"$cwd"}
EOF
)
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + Read → allow"
}

# --- Test 3: marker exists, Edit outside .no-vibe/ → deny ---
test_marker_blocks_edit_outside() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$cwd/foo.py"},"cwd":"$cwd"}
EOF
)
    local output
    output=$(echo "$input" | "$HOOK" 2>&1)
    local exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + Edit outside → deny (exit non-zero)" \
        || fail "marker + Edit outside → deny (exit non-zero)" "got exit $exit_code"
    assert_contains "$output" "no-vibe mode is active" "deny message present"
}

# --- Test 4: marker exists, Edit inside .no-vibe/ → allow ---
test_marker_allows_edit_inside() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/notes"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$cwd/.no-vibe/notes/lesson.md"},"cwd":"$cwd"}
EOF
)
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + Edit inside .no-vibe/ → allow"
}

test_marker_allows_read
test_marker_blocks_edit_outside
test_marker_allows_edit_inside
summary
