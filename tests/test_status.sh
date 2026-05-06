#!/usr/bin/env bash
# Tests for runtimes/claude/hooks/status.sh
# v2: resume hint sourced from .no-vibe/session.md (curriculum file with
# checkbox items), not JSON session files.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../runtimes/claude/hooks/status.sh"
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

# --- Test 3: marker present, no session.md → "no-vibe: ON" ---
test_on_when_marker_present() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: ON" "$out" "marker present → ON"
}

# --- Test 4: no stdin → falls back to PWD ---
test_no_stdin_fallback() {
    local cwd; cwd=$(make_sandbox)
    ( cd "$cwd" && "$HOOK" </dev/null >/dev/null )
    local rc=$?
    rm -rf "$cwd"
    assert_eq "0" "$rc" "no stdin → exit 0"
}

# --- Test 5: in-progress curriculum (unchecked items) surfaces resume hint ---
test_resume_hint_surfaced() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/session.md" <<EOF
# Lesson: Build a Linear Layer
Mode: concept

## Curriculum
- [x] 1. Skeleton
- [x] 2. Forward pass
- [x] 3. Bias term
- [ ] 4. Activation
- [ ] 5. Backward stub
- [ ] 6. Compare to pytorch
- [ ] 7. Synthesize
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_contains "$out" "no-vibe: ON" "ON prefix kept"
    assert_contains "$out" "Build a Linear Layer" "topic surfaced"
    assert_contains "$out" "3/7 layers complete" "checkbox count surfaced"
}

# --- Test 6: fully-checked curriculum → no resume hint ---
test_completed_curriculum_ignored() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/session.md" <<EOF
# Lesson: Old
Mode: skill

## Curriculum
- [x] 1. step
- [x] 2. step
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: ON" "$out" "fully-complete curriculum → no resume hint"
}

# --- Test 7: empty curriculum (no checkboxes) → no resume hint ---
test_empty_curriculum_ignored() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    cat > "$cwd/.no-vibe/session.md" <<EOF
# Lesson: Stub
Mode: concept

## Curriculum
(none yet)
EOF
    local out; out=$(echo "{\"cwd\":\"$cwd\"}" | "$HOOK")
    rm -rf "$cwd"
    assert_eq "no-vibe: ON" "$out" "no checkbox items → no resume hint"
}

test_silent_when_no_dir
test_off_when_dir_no_marker
test_on_when_marker_present
test_no_stdin_fallback
test_resume_hint_surfaced
test_completed_curriculum_ignored
test_empty_curriculum_ignored
summary
