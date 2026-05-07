#!/usr/bin/env bash
# Tests for hooks/status.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/status.sh"
. "$SCRIPT_DIR/helpers.sh"

# Isolate $HOME so the dev machine's real ~/.no-vibe/PROFILE.md and
# ~/.no-vibe/user/*.md do not get injected by the hook during these
# exact-match assertions. Each test that explicitly cares about
# adaptation injection sets up its own files inside this fake home.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
export HOME="$FAKE_HOME"

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

# --- Test 3: marker present → "no-vibe: ON" line first ---
test_on_when_marker_present() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    # Hook also injects PROFILE.md / user overrides after the status line,
    # so we check the status line is emitted as the first line rather than exact-match.
    local first_line; first_line=$(printf '%s\n' "$out" | head -n 1)
    assert_eq "no-vibe: ON" "$first_line" "marker present → ON line first"
}

# --- Test 4: no stdin → falls back to PWD, still safe ---
test_no_stdin_fallback() {
    local cwd; cwd=$(make_sandbox)
    ( cd "$cwd" && "$HOOK" </dev/null >/dev/null )
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "no stdin → exit 0"
}

# --- Test 5: in-progress session surfaces resume hint ---
test_resume_hint_surfaced() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/data/sessions"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/data/sessions/build-a-linear-layer.json" <<EOF
{"topic":"Build a Linear Layer","status":"in_progress","current_layer":3,"layers_total":7,"current_phase":"phase3"}
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_contains "$out" "no-vibe: ON" "ON prefix kept"
    assert_contains "$out" "Build a Linear Layer" "topic surfaced"
    assert_contains "$out" "layer 3/7" "layer pointer surfaced"
    assert_contains "$out" "phase3" "phase surfaced"
}

# --- Test 6: completed sessions don't trigger resume hint ---
test_completed_session_ignored() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/data/sessions"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/data/sessions/old.json" <<EOF
{"topic":"Old","status":"completed","current_layer":7,"layers_total":7,"current_phase":"phase6"}
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    local first_line; first_line=$(printf '%s\n' "$out" | head -n 1)
    assert_eq "no-vibe: ON" "$first_line" "completed session → no resume hint"
}

# --- Test 7: most recent in-progress session wins ---
test_most_recent_session_wins() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/data/sessions"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/data/sessions/older.json" <<EOF
{"topic":"Older Topic","status":"in_progress","current_layer":1,"layers_total":5,"current_phase":"phase2"}
EOF
    # Backdate older.json
    touch -t 202001010000 "$cwd/.no-vibe/data/sessions/older.json"
    cat > "$cwd/.no-vibe/data/sessions/newer.json" <<EOF
{"topic":"Newer Topic","status":"in_progress","current_layer":2,"layers_total":4,"current_phase":"phase3"}
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_contains "$out" "Newer Topic" "newer session wins"
}

# --- Test 8: PROFILE.md (project + global) is injected when present ---
test_profile_md_injected_when_present() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    mkdir -p "$FAKE_HOME/.no-vibe"
    printf '%s\n' "# PROFILE — global" "## Identity & expertise" "- CS background, Rust solid" > "$FAKE_HOME/.no-vibe/PROFILE.md"
    printf '%s\n' "# PROFILE — project" "## Recent layer outcomes" "- async-rust layer 3/5 Clear" > "$cwd/.no-vibe/PROFILE.md"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd" "$FAKE_HOME/.no-vibe"
    assert_contains "$out" "no-vibe: ON" "ON line still emitted"
    assert_contains "$out" "GLOBAL PROFILE" "global PROFILE.md labeled"
    assert_contains "$out" "CS background, Rust solid" "global PROFILE.md content present"
    assert_contains "$out" "PROJECT PROFILE" "project PROFILE.md labeled"
    assert_contains "$out" "async-rust layer 3/5" "project PROFILE.md content present"
}

# --- Test 9: PROFILE.md absent → placeholder, no auto-creation ---
test_profile_md_absent_uses_placeholder_no_create() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    local globalProfile="missing"
    local projectProfile="missing"
    [ -e "$FAKE_HOME/.no-vibe/PROFILE.md" ] && globalProfile="present"
    [ -e "$cwd/.no-vibe/PROFILE.md" ] && projectProfile="present"
    rm -rf "$cwd"
    assert_contains "$out" "GLOBAL PROFILE" "global PROFILE section emitted even when absent"
    assert_contains "$out" "PROJECT PROFILE" "project PROFILE section emitted even when absent"
    assert_contains "$out" "PROFILE.md missing" "placeholder text used when PROFILE.md absent"
    assert_eq "missing" "$globalProfile" "hook must not create global PROFILE.md"
    assert_eq "missing" "$projectProfile" "hook must not create project PROFILE.md"
}

# --- Test 10: PROFILE.md absence does NOT change the OFF or no-dir cases ---
test_no_injection_when_off() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    # marker absent → status hook prints OFF only and exits
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: OFF" "$out" "OFF state has no adaptation injection"
}

# --- Test 11: user/*.md files (project + global) loaded sorted ---
test_user_dir_globs_sorted() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe/user"
    touch "$cwd/.no-vibe/active"
    mkdir -p "$FAKE_HOME/.no-vibe/user"
    # Filenames intentionally chosen so sort order matters: a- comes before b-
    printf '%s\n' "- skip 12-year-old framing" > "$FAKE_HOME/.no-vibe/user/a-style.md"
    printf '%s\n' "- prefer mechanism over analogy" > "$FAKE_HOME/.no-vibe/user/b-extra.md"
    printf '%s\n' "- this project uses tabs" > "$cwd/.no-vibe/user/conventions.md"
    # A non-.md file must NOT be loaded
    printf '%s\n' "should not appear" > "$FAKE_HOME/.no-vibe/user/notes.txt"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd" "$FAKE_HOME/.no-vibe"
    assert_contains "$out" "GLOBAL USER OVERRIDES" "global user overrides labeled"
    assert_contains "$out" "skip 12-year-old framing" "first global user file content present"
    assert_contains "$out" "prefer mechanism over analogy" "second global user file content present"
    # Sort order: a-style.md must appear before b-extra.md in the output
    local pos_a pos_b
    pos_a=$(printf '%s' "$out" | awk '/skip 12-year-old framing/{print NR; exit}')
    pos_b=$(printf '%s' "$out" | awk '/prefer mechanism over analogy/{print NR; exit}')
    if [ -n "$pos_a" ] && [ -n "$pos_b" ] && [ "$pos_a" -lt "$pos_b" ]; then
        assert_eq "ok" "ok" "user/ files loaded in sorted filename order"
    else
        assert_eq "a<b" "a>=b" "user/ files must be loaded in sorted filename order (a-style before b-extra)"
    fi
    assert_contains "$out" "PROJECT USER OVERRIDES" "project user overrides labeled"
    assert_contains "$out" "this project uses tabs" "project user file content present"
    case "$out" in
        *"should not appear"*) assert_eq "filtered" "leaked" "non-.md files in user/ must be ignored" ;;
        *) assert_eq "filtered" "filtered" "non-.md files in user/ are ignored" ;;
    esac
}

# --- Test 12: empty/missing user/ uses placeholder ---
test_user_dir_empty_uses_placeholder() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_contains "$out" "GLOBAL USER OVERRIDES" "global user overrides section emitted when dir absent"
    assert_contains "$out" "PROJECT USER OVERRIDES" "project user overrides section emitted when dir absent"
    assert_contains "$out" "No user-authored override files" "placeholder used when user/ dir absent or empty"
}

# --- Test 13: hook does not create user/ directory or any file in it ---
test_hook_does_not_create_user_dir() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    echo "{\"cwd\":\"$cwd\"}" | "$HOOK" >/dev/null
    local globalUserDir="missing"
    local projectUserDir="missing"
    [ -e "$FAKE_HOME/.no-vibe/user" ] && globalUserDir="present"
    [ -e "$cwd/.no-vibe/user" ] && projectUserDir="present"
    rm -rf "$cwd"
    assert_eq "missing" "$globalUserDir" "hook must not create global user/ dir"
    assert_eq "missing" "$projectUserDir" "hook must not create project user/ dir"
}

test_silent_when_no_dir
test_off_when_dir_no_marker
test_on_when_marker_present
test_no_stdin_fallback
test_resume_hint_surfaced
test_completed_session_ignored
test_most_recent_session_wins
test_profile_md_injected_when_present
test_profile_md_absent_uses_placeholder_no_create
test_no_injection_when_off
test_user_dir_globs_sorted
test_user_dir_empty_uses_placeholder
test_hook_does_not_create_user_dir
summary
