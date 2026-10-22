#!/usr/bin/env bash
# Tests for .claude-plugin/hooks/block-writes.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/block-writes.sh"
. "$SCRIPT_DIR/helpers.sh"
. "$SCRIPT_DIR/../hooks/json.sh"

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

# --- Test 9: Bash tool not blocked by THIS hook (Bash has its own guard,
#     hooks/block-bash-writes.sh; this hook is scoped to Edit/Write only) ---
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
{"tool_name":"Write","tool_input":{"file_path":"$cwd/.no-vibe/data/sessions/lesson-x.json","content":"{}"},"cwd":"$cwd"}
EOF
)
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + Write to .no-vibe/data/*.json → allow"
}

test_marker_allows_write_data

# --- Test 11: ApplyPatch also blocked ---
test_marker_blocks_apply_patch() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"ApplyPatch","tool_input":{"file_path":"$cwd/foo.py"},"cwd":"$cwd"}
EOF
)
    local exit_code
    echo "$input" | "$HOOK" >/dev/null 2>&1
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + ApplyPatch outside → deny" \
        || fail "marker + ApplyPatch outside → deny" "got exit $exit_code"
}

test_marker_blocks_apply_patch

# --- Test 12: missing target path fails closed ---
test_marker_blocks_missing_target() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input
    input=$(cat <<EOF
{"tool_name":"Write","tool_input":{"content":"x"},"cwd":"$cwd"}
EOF
)
    local output exit_code
    output=$(echo "$input" | "$HOOK" 2>&1)
    exit_code=$?
    rm -rf "$cwd"
    [ "$exit_code" -ne 0 ] && pass "marker + missing target → deny (fail closed)" \
        || fail "marker + missing target → deny (fail closed)" "got exit $exit_code"
    assert_contains "$output" "no target path was provided" "missing-target deny message present"
}

test_marker_blocks_missing_target

# --- Test 13: Write into $HOME/.no-vibe/ (global learner state) → allow ---
test_marker_allows_write_home_scratch() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local fake_home
    fake_home=$(mktemp -d)
    mkdir -p "$fake_home/.no-vibe"
    local input
    input=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$fake_home/.no-vibe/PROFILE.md","content":"x"},"cwd":"$cwd"}
EOF
)
    local exit_code
    HOME="$fake_home" bash -c "echo '$input' | '$HOOK' >/dev/null 2>&1"
    exit_code=$?
    rm -rf "$cwd" "$fake_home"
    assert_eq "0" "$exit_code" "marker + Write to \$HOME/.no-vibe/PROFILE.md → allow"
}

test_marker_allows_write_home_scratch

# --- Test 14: Write to fake-HOME path outside .no-vibe → still deny ---
test_marker_blocks_other_home_path() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local fake_home
    fake_home=$(mktemp -d)
    local input
    input=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$fake_home/notes.md","content":"x"},"cwd":"$cwd"}
EOF
)
    local exit_code
    HOME="$fake_home" bash -c "echo '$input' | '$HOOK' >/dev/null 2>&1"
    exit_code=$?
    rm -rf "$cwd" "$fake_home"
    [ "$exit_code" -ne 0 ] && pass "marker + Write to other \$HOME path → deny" \
        || fail "marker + Write to other \$HOME path → deny" "got exit $exit_code"
}

test_marker_blocks_other_home_path
# --- apply_patch: the patch text is the only source of target paths ---
run_patch() {
    local cwd="$1" patch="$2"
    printf '{"tool_name":"apply_patch","tool_input":{"command":%s},"cwd":%s}' \
        "$(json_string "$patch")" "$(json_string "$cwd")" | "$HOOK" >/dev/null 2>&1
}

test_patch_inside_scratch_allows() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    run_patch "$cwd" $'*** Begin Patch\n*** Add File: .no-vibe/notes.md\n+hi\n*** End Patch'
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "0" "$exit_code" "marker + apply_patch adding .no-vibe file → allow"
}
test_patch_inside_scratch_allows

test_patch_outside_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    run_patch "$cwd" $'*** Begin Patch\n*** Update File: src/main.rs\n@@\n-a\n+b\n*** End Patch'
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "2" "$exit_code" "marker + apply_patch updating project file → deny"
}
test_patch_outside_blocks

test_patch_mixed_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    run_patch "$cwd" $'*** Begin Patch\n*** Add File: .no-vibe/a.md\n+a\n*** Add File: b.txt\n+b\n*** End Patch'
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "2" "$exit_code" "marker + apply_patch touching .no-vibe and project → deny"
}
test_patch_mixed_blocks

test_patch_move_out_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    run_patch "$cwd" $'*** Begin Patch\n*** Update File: .no-vibe/a.md\n*** Move to: src/a.md\n*** End Patch'
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "2" "$exit_code" "marker + apply_patch moving a file into the project → deny"
}
test_patch_move_out_blocks

test_patch_without_paths_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    run_patch "$cwd" 'not a patch'
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "2" "$exit_code" "marker + apply_patch with no parseable path → deny"
}
test_patch_without_paths_blocks
# --- On Linux and macOS a backslash is part of a name, not a separator ---
test_backslash_name_escape_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    case "${OSTYPE:-}" in
        msys*|cygwin*|win32*)
            rm -rf "$cwd"
            pass "backslash name escape → deny (skipped on Windows)"
            return
            ;;
    esac
    printf '{"tool_name":"Write","tool_input":{"file_path":%s},"cwd":%s}' \
        "$(json_string '.no-vibe/a\b/../../src/c')" "$(json_string "$cwd")" | "$HOOK" >/dev/null 2>&1
    local exit_code=$?
    rm -rf "$cwd"
    assert_eq "2" "$exit_code" "marker + Write .no-vibe/a\\b/../../src/c → deny"
}
test_backslash_name_escape_blocks

# --- The guard needs no realpath, and follows symlinks before allowing ---
fake_realpath_bin=$(mktemp -d)
printf '#!/bin/sh\necho "realpath: unsupported" >&2\nexit 1\n' > "$fake_realpath_bin/realpath"
chmod +x "$fake_realpath_bin/realpath"

write_rc() {
    # $1 = cwd, $2 = file_path; runs with a realpath that always fails.
    printf '{"tool_name":"Write","tool_input":{"file_path":%s},"cwd":%s}' \
        "$(json_string "$2")" "$(json_string "$1")" | PATH="$fake_realpath_bin:$PATH" "$HOOK" >/dev/null 2>&1
    echo $?
}

test_no_realpath_needed() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" && touch "$cwd/.no-vibe/active"
    assert_eq "2" "$(write_rc "$cwd" "$cwd/src/main.rs")" "broken realpath: project write → deny"
    assert_eq "0" "$(write_rc "$cwd" "$cwd/.no-vibe/notes.md")" "broken realpath: .no-vibe write → allow"
    assert_eq "0" "$(write_rc "$cwd" "$cwd/.no-vibe/new/../notes.md")" "broken realpath: .. inside .no-vibe → allow"
    rm -rf "$cwd"
}
test_no_realpath_needed

test_symlink_escape_blocks() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" "$cwd/src" && touch "$cwd/.no-vibe/active"
    ln -s ../src "$cwd/.no-vibe/out"
    ln -s ../src/main.rs "$cwd/.no-vibe/f"
    assert_eq "2" "$(write_rc "$cwd" "$cwd/.no-vibe/out/x.rs")" "write through a symlinked dir out of .no-vibe → deny"
    assert_eq "2" "$(write_rc "$cwd" "$cwd/.no-vibe/f")" "write to a symlink out of .no-vibe → deny"
    rm -rf "$cwd"
}
test_symlink_escape_blocks
rm -rf "$fake_realpath_bin"
# --- Paths the resolver cannot pin down are refused ---
test_unresolvable_targets_block() {
    local cwd
    cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe" "$cwd/src" && touch "$cwd/.no-vibe/active"
    ln -s ../src "$cwd/.no-vibe/link"
    ln -s ../src/new "$cwd/.no-vibe/dang"
    local long; long=".no-vibe/$(printf './%.0s' $(seq 600))link/main.rs"
    local rc
    for target in "$cwd/.no-vibe/dang/x" "$cwd/.no-vibe/missing/../link/x" "$cwd/$long"; do
        rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":%s},"cwd":%s}' \
            "$(json_string "$target")" "$(json_string "$cwd")" | "$HOOK" >/dev/null 2>&1; echo $?)
        assert_eq "2" "$rc" "unresolvable target → deny: ${target#$cwd/}"
    done
    rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":%s},"cwd":%s}' \
        "$(json_string "//${cwd#/}/.no-vibe/notes.md")" "$(json_string "$cwd")" | "$HOOK" >/dev/null 2>&1; echo $?)
    assert_eq "0" "$rc" "leading // inside .no-vibe → allow"
    rm -rf "$cwd"
}
test_unresolvable_targets_block
# --- A long project path still allows its .no-vibe state file ---
test_long_project_path_allows() {
    local cwd
    cwd=$(make_sandbox)
    local seg; seg=$(printf 'p%.0s' $(seq 200))
    local deep="$cwd/$seg/$seg/$seg/$seg/$seg"
    mkdir -p "$deep/.no-vibe" && touch "$deep/.no-vibe/active"
    local rc
    rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":".no-vibe/syllabus.md"},"cwd":%s}' \
        "$(json_string "$deep")" | "$HOOK" >/dev/null 2>&1; echo $?)
    assert_eq "0" "$rc" "1000+ byte project path: .no-vibe/syllabus.md → allow"
    rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":"src/main.rs"},"cwd":%s}' \
        "$(json_string "$deep")" | "$HOOK" >/dev/null 2>&1; echo $?)
    assert_eq "2" "$rc" "1000+ byte project path: src/main.rs → deny"
    rm -rf "$cwd"
}
test_long_project_path_allows

summary
