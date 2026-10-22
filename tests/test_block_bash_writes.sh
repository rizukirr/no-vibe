#!/usr/bin/env bash
# Tests for hooks/block-bash-writes.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/block-bash-writes.sh"
. "$SCRIPT_DIR/helpers.sh"
. "$SCRIPT_DIR/../hooks/json.sh"

# bash_call CWD CMD: the hook JSON for a Bash tool call.
bash_call() {
    printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
        "$(json_string "$2")" "$(json_string "$1")"
}

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
    bash_call "$cwd" "$cmd" \
        | "$HOOK" 2>&1
}

run_hook_with_home() {
    # $1 = cwd, $2 = HOME override, $3 = bash command
    local cwd="$1" home="$2" cmd="$3"
    bash_call "$cwd" "$cmd" \
        | HOME="$home" "$HOOK" 2>&1
}

# --- Test 1: no marker → allow any command ---
test_no_marker_allows() {
    local cwd; cwd=$(mktemp -d)
    bash_call "$cwd" "echo hi > /etc/passwd" \
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
    printf '{"tool_name":"Read","tool_input":{"file_path":"x"},"cwd":%s}' "$(json_string "$cwd")" \
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

# --- Test 20: redirect into $HOME/.no-vibe/ (global teaching prefs) → allow ---
test_redirect_into_home_scratch_allowed() {
    local cwd; cwd=$(make_sandbox)
    local fake_home; fake_home=$(mktemp -d -p "$SANDBOX_ROOT")
    mkdir -p "$fake_home/.no-vibe"
    run_hook_with_home "$cwd" "$fake_home" "echo hi > $fake_home/.no-vibe/PROFILE.md" >/dev/null
    local rc=$?
    rm -rf "$cwd" "$fake_home"
    assert_eq "0" "$rc" "redirect into \$HOME/.no-vibe/ → allow"
}

# --- Test 21: redirect into fake $HOME path outside .no-vibe → deny ---
test_redirect_into_home_other_denied() {
    local cwd; cwd=$(make_sandbox)
    local fake_home; fake_home=$(mktemp -d -p "$SANDBOX_ROOT")
    local out; out=$(run_hook_with_home "$cwd" "$fake_home" "echo bad > $fake_home/notes.md")
    local rc=$?
    rm -rf "$cwd" "$fake_home"
    [ "$rc" -ne 0 ] && pass "redirect into other \$HOME path → deny" \
        || fail "redirect into other \$HOME path → deny" "got exit $rc"
}

test_redirect_into_home_scratch_allowed
test_redirect_into_home_other_denied

# --- Test 22: mixed Windows-form cwd vs MSYS-form target → allow ---
# Regression for the path-form mismatch on Git Bash, where MSYS converts
# command-line --arg paths but leaves embedded path strings untouched,
# producing a `C:/...` cwd alongside a `/c/...` target inside the same
# tool call. Pure Linux runs are unaffected (no drive letters → the
# substitution below is a no-op).
test_mixed_path_form_allowed() {
    local cwd; cwd=$(make_sandbox)
    case "$cwd" in
        /[A-Za-z]/*)
            local drive="${cwd:1:1}"
            local rest="${cwd:2}"
            local win_cwd="${drive}:${rest}"
            local msys_target="$cwd/.no-vibe/notes.md"
            local out; out=$(bash_call "$win_cwd" "echo hi > $msys_target" | "$HOOK" 2>&1)
            local rc=$?
            rm -rf "$cwd"
            [ "$rc" = "0" ] && pass "mixed-form cwd vs target → allow" \
                || fail "mixed-form cwd vs target → allow" "got exit $rc | out: $out"
            ;;
        *)
            rm -rf "$cwd"
            pass "mixed-form cwd vs target → allow (skipped on non-MSYS)"
            ;;
    esac
}
test_mixed_path_form_allowed

# --- A command that is not a string cannot be checked ---
test_non_string_command_denied() {
    local cwd; cwd=$(make_sandbox)
    printf '{"tool_name":"Bash","tool_input":{"command":["echo hi > src/a"]},"cwd":%s}' "$(json_string "$cwd")" \
        | "$HOOK" >/dev/null 2>&1
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "array command → deny"
}
test_non_string_command_denied

# --- /tmp only counts after .. is resolved ---
test_tmp_dotdot_escape_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo hi > /tmp/..$cwd/src/a" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "/tmp/.. into the project → deny"
}
test_tmp_dotdot_escape_denied

test_tmp_inner_dotdot_allowed() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" "echo hi > /tmp/no-vibe-a/../no-vibe-b" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "/tmp/a/../b stays in /tmp → allow"
}
test_tmp_inner_dotdot_allowed

# --- On Linux and macOS a backslash is part of a name, not a separator ---
test_backslash_name_escape_denied() {
    local cwd; cwd=$(make_sandbox)
    case "${OSTYPE:-}" in
        msys*|cygwin*|win32*)
            rm -rf "$cwd"
            pass "backslash name escape → deny (skipped on Windows)"
            return
            ;;
    esac
    run_hook "$cwd" "echo hi > '.no-vibe/a\\b/../../src/c'" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "redirect to '.no-vibe/a\\b/../../src/c' → deny"
}
test_backslash_name_escape_denied

# --- The guard needs no realpath ---
test_no_realpath_needed() {
    local cwd; cwd=$(make_sandbox)
    local bin; bin=$(mktemp -d)
    printf '#!/bin/sh\necho "realpath: unsupported" >&2\nexit 1\n' > "$bin/realpath"
    chmod +x "$bin/realpath"
    bash_call "$cwd" "echo hi > src/x" | PATH="$bin:$PATH" "$HOOK" >/dev/null 2>&1
    local deny_rc=$?
    bash_call "$cwd" "echo hi > .no-vibe/x" | PATH="$bin:$PATH" "$HOOK" >/dev/null 2>&1
    local allow_rc=$?
    rm -rf "$cwd" "$bin"
    assert_eq "2" "$deny_rc" "broken realpath: redirect into project → deny"
    assert_eq "0" "$allow_rc" "broken realpath: redirect into .no-vibe → allow"
}
test_no_realpath_needed

# --- /private/tmp is allowed only where /tmp resolves there ---
test_private_tmp_off_macos_denied() {
    local cwd; cwd=$(make_sandbox)
    if [ "$(cd -P /tmp && pwd -P)" = /private/tmp ]; then
        rm -rf "$cwd"
        pass "/private/tmp off macOS → deny (skipped: /tmp is /private/tmp here)"
        return
    fi
    run_hook "$cwd" "echo hi > /private/tmp/x" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "/private/tmp where /tmp is not /private/tmp → deny"
}
test_private_tmp_off_macos_denied

# --- A backslash in a target is refused: bash may drop it ---
test_backslash_target_denied() {
    local cwd; cwd=$(make_sandbox)
    run_hook "$cwd" 'echo hi > .no-vibe\notes.md' >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "redirect to .no-vibe\\notes.md → deny"
}
test_backslash_target_denied

# --- Symlinks are followed before a target is allowed ---
test_symlink_escape_denied() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/src"
    ln -s ../src "$cwd/.no-vibe/out"
    run_hook "$cwd" "echo hi > .no-vibe/out/x" >/dev/null
    local rc=$?
    rm -rf "$cwd"
    assert_eq "2" "$rc" "redirect through a symlinked dir out of .no-vibe → deny"
}
test_symlink_escape_denied
# --- Paths the resolver cannot pin down are refused ---
test_unresolvable_targets_denied() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/src"
    ln -s ../src "$cwd/.no-vibe/link"
    ln -s ../src/new "$cwd/.no-vibe/dang"
    local long; long=".no-vibe/$(printf './%.0s' $(seq 600))link/main.rs"
    run_hook "$cwd" "echo pwn > .no-vibe/dang/x" >/dev/null; assert_eq "2" "$?" "dangling symlink mid-path → deny"
    run_hook "$cwd" "echo pwn > .no-vibe/missing/../link/x" >/dev/null; assert_eq "2" "$?" "symlink after a missing dir and .. → deny"
    run_hook "$cwd" "echo pwn > $long" >/dev/null; assert_eq "2" "$?" "overlong target → deny"
    local deep; deep=".no-vibe/$(printf 'd/%.0s' $(seq 2000))x"
    local start end
    start=$(date +%s)
    run_hook "$cwd" "echo pwn > $deep" >/dev/null; assert_eq "2" "$?" "2000-component target → deny"
    end=$(date +%s)
    [ $((end - start)) -lt 3 ] && pass "2000-component target decided in under 3 s" \
        || fail "2000-component target decided in under 3 s" "took $((end - start)) s"
    rm -rf "$cwd"
}
test_unresolvable_targets_denied

test_double_slash_root_denied() {
    local cwd; cwd=$(make_sandbox)
    local fake_home; fake_home=$(mktemp -d -p "$SANDBOX_ROOT")
    ln -s / "$fake_home/.no-vibe"
    run_hook_with_home "$cwd" "$fake_home" "echo pwn > //${cwd#/}/src/x" >/dev/null
    local rc=$?
    rm -rf "$cwd" "$fake_home"
    assert_eq "2" "$rc" "// target with a root resolving to / → deny"
}
test_double_slash_root_denied
summary
