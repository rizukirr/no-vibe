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
    assert_eq "no-vibe: ON" "$out" "completed session → no resume hint"
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

test_silent_when_no_dir
test_off_when_dir_no_marker
test_on_when_marker_present
test_no_stdin_fallback
test_resume_hint_surfaced
test_completed_session_ignored
test_most_recent_session_wins
summary
