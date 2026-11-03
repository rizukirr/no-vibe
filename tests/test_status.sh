#!/usr/bin/env bash
# Tests for hooks/status.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/status.sh"
. "$SCRIPT_DIR/helpers.sh"

run_status() {
    printf '{"cwd":"%s"}' "$1" | HOME="$2" "$HOOK" 2>/dev/null
}

roadmap() {
    local cwd="$1" status="$2"
    cat > "$cwd/.no-vibe/ROADMAP.md" <<EOT
---
status: $status
topic: Rust backend
level: knows Python
start: ownership
teaching: code first
goal: build a CRUD API in axum
---

current: chapter 2, section 1, exercise 1

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
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "marker, no roadmap → ON"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; roadmap "$cwd" approved
assert_eq 'no-vibe: ON, resuming "Rust backend" (chapter 2/3)' "$(run_status "$cwd" "$fake_home")" "approved roadmap → resume hint"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; roadmap "$cwd" draft
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "draft roadmap → no resume hint"
rm -rf "$cwd"

cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"; roadmap "$cwd" done
assert_eq "no-vibe: ON" "$(run_status "$cwd" "$fake_home")" "done roadmap → no resume hint"
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

# Roadmap variations the skill or an editor can produce.
resume() {
    local cwd; cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"
    printf '%b' "$1" > "$cwd/.no-vibe/ROADMAP.md"
    run_status "$cwd" "$fake_home"
    rm -rf "$cwd"
}
assert_eq 'no-vibe: ON, resuming "Rust: backend" (chapter 1/1)' \
    "$(resume '---\nstatus: approved\ntopic: "Rust: backend"\n---\n- [ ] 1. a\n')" "double-quoted topic"
assert_eq 'no-vibe: ON, resuming "Rust" (chapter 1/1)' \
    "$(resume "---\nstatus: approved\ntopic: 'Rust'\n---\n- [ ] 1. a\n")" "single-quoted topic"
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/2)' \
    "$(resume '---\r\nstatus: approved\r\ntopic: T\r\n---\r\n- [x] 1. a\r\n- [ ] 2. b\r\n')" "CRLF roadmap"
assert_eq 'no-vibe: ON, resuming "T" (chapter 1/1)' \
    "$(resume '---\nstatus: approved  \ntopic: T\n---\n- [ ] 1. a\n')" "trailing spaces after approved"
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [X] 1. a\n- [ ] 2. b\n')" "capital X counts as ticked"
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n- [ ] 2. b\n\nnotes:\n- [ ] remember x\n')" "unnumbered box is not a section"
assert_eq 'no-vibe: ON' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n')" "no sections → no resume hint"
assert_eq 'no-vibe: ON' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n- [x] 2. b\n')" "all sections ticked → no resume hint"
cwd=$(mktemp -d -p "$fake_home"); mkdir -p "$cwd/a\"b/.no-vibe"
assert_eq "no-vibe: OFF" "$(printf '{"cwd":"%s/a\\"b"}' "$cwd" | HOME="$fake_home" "$HOOK")" "escaped quote in cwd is decoded"
rm -rf "$cwd"
assert_eq "no-vibe: ON, resuming \"it's\" (chapter 1/1)" \
    "$(resume "---\nstatus: approved\ntopic: 'it''s'\n---\n- [ ] 1. a\n")" "single-quoted topic unescapes ''"
assert_eq 'no-vibe: ON, resuming "say "hi"" (chapter 1/1)' \
    "$(resume '---\nstatus: approved\ntopic: "say \\"hi\\""\n---\n- [ ] 1. a\n')" "double-quoted topic unescapes \\\""
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/3)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x]  1. a\n- [ ] 2. b\n- [ ]\t3. c\n')" "extra spacing after the box still counts"
assert_eq 'no-vibe: ON, resuming ""x"" (chapter 1/1)' \
    "$(resume "---\nstatus: approved\ntopic: '\"x\"'\n---\n- [ ] 1. a\n")" "single-quoted value keeps inner double quotes"
assert_eq "no-vibe: ON, resuming \"'x'\" (chapter 1/1)" \
    "$(resume '---\nstatus: approved\ntopic: "'"'"'x'"'"'"\n---\n- [ ] 1. a\n')" "double-quoted value keeps inner single quotes"
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n  - [x] 1.1 b\n- [ ] 2. c\n  - [ ] 2.1 d\n')" "indented prerequisite chapters are not counted"
assert_eq 'no-vibe: ON, resuming "T" (chapter 2/2)' \
    "$(resume '---\nstatus: approved\ntopic: T\n---\n- [x] 1. a\n  - [x] Section 1 b\n    Core: c\n    Saw: d\n  - Check: e\n- [ ] 2. f\n  - [ ] Section 1 g\n')" "section lines are not counted"
cwd=$(mktemp -d); mkdir -p "$cwd/.no-vibe"; touch "$cwd/.no-vibe/active"
printf -- '---\nstatus: approved\ntopic: T\n---\n- [ ] 1. a\n' > "$cwd/.no-vibe/syllabus.md"
assert_eq 'no-vibe: ON' "$(run_status "$cwd" "$fake_home")" "an old syllabus.md alone is not read"
rm -rf "$cwd"
rm -rf "$fake_home"
summary
