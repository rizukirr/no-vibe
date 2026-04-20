#!/usr/bin/env bash
# Tests for /no-vibe-btw marker snapshot/restore cycle.
# Simulates the shell snippets embedded in commands/no-vibe-btw.md,
# .opencode/commands/no-vibe-btw.md, and .gemini/commands/no-vibe-btw.toml.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/helpers.sh"

make_sandbox() {
    local dir
    dir=$(mktemp -d)
    echo "$dir"
}

# Shared snippet mirroring the documented flow.
# Returns 0 if marker ends up matching `was_active` snapshot, 1 otherwise.
run_btw_cycle() {
    local cwd="$1"
    local task_rc="$2"
    (
        cd "$cwd" || exit 99
        was_active=0
        [ -f .no-vibe/active ] && was_active=1

        rm -f .no-vibe/active
        [ -f .no-vibe/active ] && { echo "FATAL: marker still present after rm"; exit 1; }

        # Simulate task — pass or fail according to arg.
        ( exit "$task_rc" ) || true

        if [ "$was_active" = "1" ]; then
            mkdir -p .no-vibe && touch .no-vibe/active
            [ -f .no-vibe/active ] || { echo "FATAL: marker not restored"; exit 1; }
        fi
    )
}

# --- Test 1: marker active → task succeeds → marker restored ---
test_restore_on_success() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    run_btw_cycle "$cwd" 0 >/dev/null 2>&1
    local rc=$?
    local present=0
    [ -f "$cwd/.no-vibe/active" ] && present=1
    rm -rf "$cwd"
    assert_eq "0" "$rc"       "btw cycle exits 0 on task success"
    assert_eq "1" "$present"  "marker restored after successful task"
}

# --- Test 2: marker active → task fails → marker still restored ---
test_restore_on_failure() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    run_btw_cycle "$cwd" 1 >/dev/null 2>&1
    local rc=$?
    local present=0
    [ -f "$cwd/.no-vibe/active" ] && present=1
    rm -rf "$cwd"
    assert_eq "0" "$rc"       "btw cycle still exits 0 when task fails (restore runs)"
    assert_eq "1" "$present"  "marker restored even after task failure"
}

# --- Test 3: marker absent → no spurious restoration ---
test_no_spurious_restore() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    run_btw_cycle "$cwd" 0 >/dev/null 2>&1
    local present=0
    [ -f "$cwd/.no-vibe/active" ] && present=1
    rm -rf "$cwd"
    assert_eq "0" "$present" "marker not created when it was not active beforehand"
}

# --- Test 4: during task body, marker is absent (guard actually disabled) ---
test_marker_absent_during_task() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local during
    during=$(
        cd "$cwd" || exit 99
        was_active=0
        [ -f .no-vibe/active ] && was_active=1
        rm -f .no-vibe/active
        if [ -f .no-vibe/active ]; then echo "PRESENT"; else echo "ABSENT"; fi
        if [ "$was_active" = "1" ]; then
            mkdir -p .no-vibe && touch .no-vibe/active
        fi
    )
    rm -rf "$cwd"
    assert_eq "ABSENT" "$during" "marker is absent during the task body"
}

test_restore_on_success
test_restore_on_failure
test_no_spurious_restore
test_marker_absent_during_task

# --- Test 5: TOML/command verification snippet fails loud when rm is sabotaged ---
test_verification_catches_rm_failure() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local output rc
    output=$(
        cd "$cwd" || exit 99
        # Simulate a filesystem where rm "succeeds" but marker persists
        # by re-creating it immediately. Exercises the exact post-rm guard
        # from no-vibe-btw command specs.
        rm -f .no-vibe/active
        touch .no-vibe/active  # sabotage
        test ! -f .no-vibe/active || { echo "FATAL: marker still present"; exit 1; }
    )
    rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "post-rm verification fails loud when marker persists" \
        || fail "post-rm verification fails loud when marker persists" "got exit $rc"
    assert_contains "$output" "FATAL: marker still present" "post-rm FATAL message emitted"
}

# --- Test 6: verification snippet fails loud when restore is sabotaged ---
test_verification_catches_restore_failure() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local output rc
    output=$(
        cd "$cwd" || exit 99
        was_active=1
        rm -f .no-vibe/active
        # Sabotage restore: make .no-vibe a non-writable file instead of dir,
        # so touch cannot recreate the marker at expected path.
        rm -rf .no-vibe
        : > .no-vibe  # file now occupies .no-vibe path; mkdir -p will fail
        if [ "$was_active" = "1" ]; then
            mkdir -p .no-vibe 2>/dev/null && touch .no-vibe/active 2>/dev/null
            test -f .no-vibe/active || { echo "FATAL: marker not restored"; exit 1; }
        fi
    )
    rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "post-restore verification fails loud when marker missing" \
        || fail "post-restore verification fails loud when marker missing" "got exit $rc"
    assert_contains "$output" "FATAL: marker not restored" "post-restore FATAL message emitted"
}

test_verification_catches_rm_failure
test_verification_catches_restore_failure

summary
