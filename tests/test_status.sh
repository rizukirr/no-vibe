#!/usr/bin/env bash
# Tests for hooks/status.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/status.sh"
. "$SCRIPT_DIR/helpers.sh"

make_sandbox() { mktemp -d; }

# --- Test 1: .no-vibe/ missing → silent, exit 0 ---
test_silent_when_no_dir() {
    local cwd; cwd=$(make_sandbox)
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "no .no-vibe dir → exit 0"
    assert_eq "" "$out" "no .no-vibe dir → silent stdout"
}

# --- Test 2: .no-vibe/ exists, no marker → "no-vibe: OFF" ---
test_off_when_dir_no_marker() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: OFF" "$out" "dir + no marker → OFF"
}

# --- Test 3: marker present → "no-vibe: ON" ---
test_on_when_marker_present() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: ON" "$out" "marker present → ON"
}

# --- Test 4: no stdin → falls back to PWD, still safe ---
test_no_stdin_fallback() {
    local cwd; cwd=$(make_sandbox)
    ( cd "$cwd" && "$HOOK" </dev/null >/dev/null )
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "no stdin → exit 0"
}

test_silent_when_no_dir
test_off_when_dir_no_marker
test_on_when_marker_present
test_no_stdin_fallback
summary
