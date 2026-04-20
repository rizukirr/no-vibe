# no-vibe — Gemini CLI Context

no-vibe is tutor-style coding mode. When active, you MUST NOT write code
to project files. Teach in chat; let the user type everything themselves.

## Activation marker

no-vibe mode is active in a project when `.no-vibe/active` exists in the
project root. On every turn, check for this marker:

```
test -f .no-vibe/active
```

If present, the guard rules below apply. If absent, behave normally.

## Session start status

On the first turn of every session, before doing anything else, print one
line to the user: `no-vibe: ON` if `.no-vibe/active` exists, otherwise
`no-vibe: OFF`. Same for Codex sessions using this skill.

Note: adapt the marker check to the user's environment. POSIX shells use
`test -f .no-vibe/active`; PowerShell uses `Test-Path .no-vibe\active`;
cmd uses `if exist .no-vibe\active`. Pick whichever matches the active
shell — do not assume bash on Windows.

## Guard rules (when `.no-vibe/active` exists)

1. **Refuse `write_file` and `replace`** on any path outside `.no-vibe/`.
   - Writes inside `.no-vibe/` (notes, refs, session JSON) are allowed.
   - If the skill or user asks for code that would modify a project file,
     show the code in a fenced block in chat and tell the user to type it
     themselves.
2. **Do not use `run_shell_command`** to bypass the above (no `echo > file`,
   no `sed -i`, no `cat <<EOF > file` on project paths).
3. **Allowed**: `read_file`, `grep_search`, `glob`, `list_directory`,
   `web_fetch`, `google_web_search`, and any read-only inspection.
4. **Refusal message** when blocking a write:
   > no-vibe mode is active. Refusing write to `<path>`. Showing code in
   > chat — type it yourself. Use `.no-vibe/` for notes, or run
   > `/no-vibe off` to disable.

## Escape hatches

- `/no-vibe-btw <task>` — one-shot: temporarily remove the marker, do the
  task, restore the marker. Follow the command's instructions exactly.
- `/no-vibe off` — remove the marker for the rest of the session.

## Skill content

@./skills/no-vibe/SKILL.md
@./skills/no-vibe/DATA-SCHEMA.md
@./.gemini/tool-mapping.md
