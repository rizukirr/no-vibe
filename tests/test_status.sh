#!/usr/bin/env bash
# Tests for hooks/status.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/status.sh"
. "$SCRIPT_DIR/helpers.sh"

run_status() {
    printf '{"cwd":"%s"}' "$1" | HOME="$2" "$HOOK" 2>/dev/null
}

syllabus() {
    local cwd="$1" status="$2"
    cat > "$cwd/.no-vibe/syllabus.md" <<EOT
---
status: $status
topic: Rust backend
level: knows Python
start: ownership
teaching: code first
goal: build a CRUD API in axum
---

current: section 2, exercise 1

- [x] 1. Write small Rust programs
- [ ] 2. Handle errors with Result
- [ ] 3. Serve JSON with axum
EOT
}

fake_home=$(mktemp -d)

cwd=$(mktemp -d)
assert_eq "" "$(run_status "$cwd" "$fake_home")" "no .no-vibe/ → silent"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"
assert_eq "no-vibe: OFF" "$(run_status "$cwd" "$fake_home")" "dir without marker → OFF"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "marker, no syllabus → ON"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; syllabus "$cwd" approved
assert_eq 'no-vibe: ON, resuming "Rust backend" (section 2/3)' "$(run_status "$cwd" "$fake_home")" "approved syllabus → resume hint"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; syllabus "$cwd" draft
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "draft syllabus → no resume hint"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; syllabus "$cwd" done
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "done syllabus → no resume hint"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe" "$fake_home/.no-vibe"; touch "$cwd/.no-vibe/active"
printf '## Identity & expertise\n- secret\n' > "$fake_home/.no-vibe/PROFILE.md"
out=$(run_status "$cwd" "$fake_home")
assert_eq "no-vibe: ON" "$out" "PROFILE.md present → not injected"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"
out=$(cd / && printf '{"cwd":"%s"}' "$cwd" | HOME="$fake_home" "$HOOK")
assert_eq "no-vibe: OFF" "$out" "cwd comes from stdin, not PWD"
rm -rf "$cwd"

rm -rf "$fake_home"
summary
