#!/usr/bin/env bash
# Tests for .claude-plugin/hooks/block-writes.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/block-writes.sh"
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

# --- Test 5: path traversal (.. escape) → deny ---
test_marker_blocks_traversal() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$cwd/.no-vibe/../foo.py"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + path traversal → deny" \
        || fail "marker + path traversal → deny" "got exit $exit_code"
}

# --- Test 6: Write tool also blocked ---
test_marker_blocks_write() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$cwd/foo.py","content":"x"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + Write outside → deny" \
        || fail "marker + Write outside → deny" "got exit $exit_code"
}

# --- Test 7: NotebookEdit also blocked ---
test_marker_blocks_notebook_edit() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"$cwd/n.ipynb"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + NotebookEdit outside → deny" \
        || fail "marker + NotebookEdit outside → deny" "got exit $exit_code"
}

# --- Test 8: MultiEdit also blocked ---
test_marker_blocks_multi_edit() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"MultiEdit","tool_input":{"file_path":"$cwd/foo.py"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + MultiEdit outside → deny" \
        || fail "marker + MultiEdit outside → deny" "got exit $exit_code"
}

# --- Test 9: Bash tool not blocked (loophole — handled by skill instruction) ---
test_marker_allows_bash() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + Bash → allow (loophole, see SKILL.md)"
}

test_marker_blocks_traversal
test_marker_blocks_write
test_marker_blocks_notebook_edit
test_marker_blocks_multi_edit
test_marker_allows_bash

# --- Test 10: marker exists, Write inside .no-vibe/data/ → allow ---
test_marker_allows_write_data() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/data"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$cwd/.no-vibe/data/profile.json","content":"{}"},"cwd":"$cwd"}
EOF
)
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + Write inside .no-vibe/data/ → allow"
}

test_marker_allows_write_data
summary
