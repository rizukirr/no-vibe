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

# Syllabus variations the skill or an editor can produce.
resume() {
    local cwd; cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"
    printf '%b' "$1" > "$cwd/.no-vibe/syllabus.md"
    run_status "$cwd" "$fake_home"
    rm -rf "$cwd"
}
assert_eq 'no-vibe: ON, resuming "Rust: backend" (section 1/1)' \
    "$(resume '---\nstatus: approved\ntopic: "Rust: backend"\n---\n- [ ] 1. a\n')" "double-quoted topic"
assert_eq 'no-vibe: ON, resuming "Rust" (section 1/1)' \
    "$(resume "---\nstatus: approved\ntopic: 'Rust'\n---\n- [ ] 1. a\n")" "single-quoted topic"
assert_eq 'no-vibe: ON, resuming "T" (section 2/2)' \
    "$(resume '---\r\nstatus: approved\r\ntopic: T\r\n---\r\n- [x] 1. a\r\n- [ ] 2. b\r\n')" "CRLF syllabus"
assert_eq 'no-vibe: ON, resuming "T" (section 1/1)' \
    "$(resume '---\nstatus: approved  \ntopic: T\n---\n- [ ] 1. a\n')" "trailing spaces after approved"
assert_eq 'no-vibe: ON, resuming "T" (section 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [X] 1. a\n- [ ] 2. b\n')" "capital X counts as ticked"
assert_eq 'no-vibe: ON, resuming "T" (section 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n- [ ] 2. b\n\nnotes:\n- [ ] remember x\n')" "unnumbered box is not a section"
assert_eq 'no-vibe: ON' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n')" "no sections → no resume hint"
assert_eq 'no-vibe: ON' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n- [x] 2. b\n')" "all sections ticked → no resume hint"
cwd=$(mktemp -d -p "$fake_home"); mkdir -p "$cwd/a\"b/.no-vibe"
assert_eq "no-vibe: OFF" "$(printf '{"cwd":"%s/a\\"b"}' "$cwd" | HOME="$fake_home" "$HOOK")" "escaped quote in cwd is decoded"
rm -rf "$cwd"
rm -rf "$fake_home"
summary
