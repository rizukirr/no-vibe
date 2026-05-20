#!/usr/bin/env bash
# Tests for hooks/validate-memory-write.sh — heading validation on Write
# calls targeting ~/.no-vibe/PROFILE.md or .no-vibe/SUMMARY.md.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/validate-memory-write.sh"
. "$SCRIPT_DIR/helpers.sh"

make_sandbox() {
    local dir
    dir=$(mktemp -d)
    echo "$dir"
}

# Isolate $HOME so the dev machine's real ~/.no-vibe/PROFILE.md doesn't
# bleed into path resolution during tests.
FAKE_HOME=$(mktemp -d)
export HOME="$FAKE_HOME"

cleanup_home() {
    rm -rf "$FAKE_HOME"
}
trap cleanup_home EXIT

# --- Test 1: no marker → allow (validator is gated on .no-vibe/active) ---
test_no_marker_allows() {
    local cwd; cwd=$(make_sandbox)
    local input='{"tool_name":"Write","tool_input":{"file_path":"'$HOME'/.no-vibe/PROFILE.md","content":"chat reply, no headings"},"cwd":"'$cwd'"}'
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "no marker → exit 0"
}

# --- Test 2: marker exists, non-Write tool → allow ---
test_non_write_tool_allows() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input='{"tool_name":"Edit","tool_input":{"file_path":"'$HOME'/.no-vibe/PROFILE.md","new_string":"anything"},"cwd":"'$cwd'"}'
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "Edit tool → allow (validator is Write-only)"
}

# --- Test 3: Write to unrelated path → allow ---
test_unrelated_write_allows() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local input='{"tool_name":"Write","tool_input":{"file_path":"'$cwd'/.no-vibe/notes.md","content":"freeform note"},"cwd":"'$cwd'"}'
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "Write to unrelated .no-vibe/ path → allow"
}

# --- Test 4: Write to PROFILE.md with canonical heading → allow ---
test_profile_with_canonical_heading_allows() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local content='# PROFILE\n## Identity & expertise\n- CS background\n## Learning style\n- prefers mechanism over analogy\n'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.no-vibe/PROFILE.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "PROFILE.md with canonical heading → allow"
}

# --- Test 5: Write to PROFILE.md missing all canonical headings → block ---
test_profile_without_canonical_heading_blocks() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    # Looks like a chat reply, not a schema-preserving rewrite
    local content='Sure! Here is what I think about your code: it looks great, just keep going.'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.no-vibe/PROFILE.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    local stderr; stderr=$(echo "$input" | "$HOOK" 2>&1 >/dev/null)
    local code=$?
    rm -rf "$cwd"
    assert_eq "2" "$code" "PROFILE.md without canonical heading → exit 2 (block)"
    assert_contains "$stderr" "heading-validation" "stderr mentions heading-validation"
    assert_contains "$stderr" "Identity & expertise" "stderr names a canonical PROFILE heading"
}

# --- Test 6: Write to SUMMARY.md with canonical heading → allow ---
test_summary_with_canonical_heading_allows() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local content='# SUMMARY\n## Current Focus\n- async-rust layer 3/5\n## Open Questions\n- when does spawn need Send?\n'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$cwd/.no-vibe/SUMMARY.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "SUMMARY.md with canonical heading → allow"
}

# --- Test 7: Write to SUMMARY.md missing all canonical headings → block ---
test_summary_without_canonical_heading_blocks() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local content='Some freeform text that is not a schema rewrite.'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$cwd/.no-vibe/SUMMARY.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    local stderr; stderr=$(echo "$input" | "$HOOK" 2>&1 >/dev/null)
    local code=$?
    rm -rf "$cwd"
    assert_eq "2" "$code" "SUMMARY.md without canonical heading → exit 2 (block)"
    assert_contains "$stderr" "Current Focus" "stderr names a canonical SUMMARY heading"
}

# --- Test 8: PROFILE heading set must NOT validate a SUMMARY write ---
test_summary_with_profile_heading_blocks() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    # PROFILE-style heading inside SUMMARY.md content — must still block
    local content='# SUMMARY\n## Identity & expertise\n- this is wrong file for this heading\n'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$cwd/.no-vibe/SUMMARY.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "2" "$code" "SUMMARY.md with PROFILE heading → block"
}

# --- Test 9: PROFILE.md with only `## Disclosure mode` heading → allow ---
test_profile_with_disclosure_heading_allows() {
    local cwd; cwd=$(make_sandbox)
    mkdir -p "$cwd/.no-vibe"
    touch "$cwd/.no-vibe/active"
    local content='# PROFILE\n## Disclosure mode\n- mode: guided\n- prediction_gate: on\n'
    local input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$HOME/.no-vibe/PROFILE.md\",\"content\":\"$content\"},\"cwd\":\"$cwd\"}"
    echo "$input" | "$HOOK" >/dev/null 2>&1
    local code=$?
    rm -rf "$cwd"
    assert_eq "0" "$code" "PROFILE.md with Disclosure mode heading → allow"
}

test_no_marker_allows
test_non_write_tool_allows
test_unrelated_write_allows
test_profile_with_canonical_heading_allows
test_profile_without_canonical_heading_blocks
test_summary_with_canonical_heading_allows
test_summary_without_canonical_heading_blocks
test_summary_with_profile_heading_blocks
test_profile_with_disclosure_heading_allows
summary
