#!/usr/bin/env bash
# Tests for hooks/block-bash-writes.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/block-bash-writes.sh"
. "$SCRIPT_DIR/helpers.sh"

# Sandbox must live OUTSIDE /tmp because /tmp is on the allowlist —
# otherwise every redirect would be classified safe.
SANDBOX_ROOT="${HOME:-/root}/.no-vibe-test-sandbox"
mkdir -p "$SANDBOX_ROOT"
make_sandbox() {
    local dir
    dir=$(mktemp -d -p "$SANDBOX_ROOT")
    mkdir -p "$dir/.no-vibe"
    touch "$dir/.no-vibe/active"
    echo "$dir"
}

run_hook() {
    # $1 = cwd, $2 = bash command
    local cwd="$1" cmd="$2"
    jq -n --arg cwd "$cwd" --arg cmd "$cmd" \
        '{tool_name:"Bash",tool_input:{command:$cmd},cwd:$cwd}' \
        | "$HOOK" 2>&1
}

# --- Test 1: no marker → allow any command ---
test_no_marker_allows() {
    local cwd; cwd=$(mktemp -d)
    jq -n --arg cwd "$cwd" '{tool_name:"Bash",tool_input:{command:"echo hi > /etc/passwd"},cwd:$cwd}' \
        | "$HOOK" >/dev/null 2>&1
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "no marker → allow"
}

# --- Test 2: read-only command → allow ---
test_readonly_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "ls -la && grep foo bar.txt | head" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "read-only command → allow"
}

# --- Test 3: redirect into project file → deny ---
test_redirect_project_denied() {
    local cwd; cwd=$(make_sandbox)
    local out; out=$(run_hook "$cwd" "echo bad > $cwd/foo.py")
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "redirect into project → deny" || fail "redirect into project → deny" "got exit $rc"
    assert_contains "$out" "no-vibe mode is active" "deny message present"
}

# --- Test 4: redirect into .no-vibe/ → allow ---
test_redirect_into_scratch_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo hi > $cwd/.no-vibe/notes.md" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "redirect into .no-vibe/ → allow"
}

# --- Test 5: redirect into /tmp → allow ---
test_redirect_tmp_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo hi > /tmp/scratch.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "redirect into /tmp → allow"
}

# --- Test 6: redirect to /dev/null → allow ---
test_devnull_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "make 2>/dev/null > /dev/null" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "redirect to /dev/null → allow"
}

# --- Test 7: 2>&1 fd-merge alone → allow ---
test_fd_merge_alone() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "make 2>&1 | tee /tmp/log.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "2>&1 + tee /tmp → allow"
}

# --- Test 8: tee into project → deny ---
test_tee_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo x | tee $cwd/out.log" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "tee into project → deny" || fail "tee into project → deny" "got exit $rc"
}

# --- Test 9: append redirect (>>) into project → deny ---
test_append_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo x >> $cwd/log.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass ">> into project → deny" || fail ">> into project → deny" "got exit $rc"
}

# --- Test 10: sed -i on project → deny ---
test_sed_i_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "sed -i 's/foo/bar/' $cwd/code.py" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "sed -i project → deny" || fail "sed -i project → deny" "got exit $rc"
}

# --- Test 11: sed without -i → allow ---
test_sed_no_inplace_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "sed 's/foo/bar/' $cwd/code.py" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "sed without -i → allow"
}

# --- Test 12: cp into project → deny ---
test_cp_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "cp /tmp/src.txt $cwd/dst.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "cp into project → deny" || fail "cp into project → deny" "got exit $rc"
}

# --- Test 13: cp into .no-vibe/ → allow ---
test_cp_scratch_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "cp /tmp/src.txt $cwd/.no-vibe/dst.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "cp into .no-vibe/ → allow"
}

# --- Test 14: mv into project → deny ---
test_mv_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "mv /tmp/src.txt $cwd/dst.txt" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "mv into project → deny" || fail "mv into project → deny" "got exit $rc"
}

# --- Test 15: dd of=project → deny ---
test_dd_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "dd if=/tmp/src of=$cwd/out.bin bs=1M" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "dd of=project → deny" || fail "dd of=project → deny" "got exit $rc"
}

# --- Test 16: command substitution destination → deny (fail closed) ---
test_substitution_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" 'echo x > $TARGET' >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "var-substitution destination → deny (fail closed)" \
        || fail "var-substitution destination → deny" "got exit $rc"
}

# --- Test 17: relative path into project → deny ---
test_relative_project_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo bad > foo.py" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "relative redirect → deny" || fail "relative redirect → deny" "got exit $rc"
}

# --- Test 18: non-Bash tool → allow (out of scope) ---
test_non_bash_allowed() {
    local cwd; cwd=$(make_sandbox)
    jq -n --arg cwd "$cwd" '{tool_name:"Read",tool_input:{file_path:"x"},cwd:$cwd}' \
        | "$HOOK" >/dev/null 2>&1
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "non-Bash tool → allow"
}

# --- Test 19: &> compound redirect into project → deny ---
test_amp_redirect_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "make &> $cwd/out.log" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    [ "$rc" -ne 0 ] && pass "&> into project → deny" || fail "&> into project → deny" "got exit $rc"
}

test_no_marker_allows
test_readonly_allowed
test_redirect_project_denied
test_redirect_into_scratch_allowed
test_redirect_tmp_allowed
test_devnull_allowed
test_fd_merge_alone
test_tee_project_denied
test_append_project_denied
test_sed_i_project_denied
test_sed_no_inplace_allowed
test_cp_project_denied
test_cp_scratch_allowed
test_mv_project_denied
test_dd_project_denied
test_substitution_denied
test_relative_project_denied
test_non_bash_allowed
test_amp_redirect_denied
summary
