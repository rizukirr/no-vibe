# Gemini CLI Tool Mapping (for no-vibe skill)

The no-vibe skill is written against Claude Code tool names. Use these
Gemini CLI equivalents when executing skill steps:

| Skill references    | Gemini CLI equivalent |
|---------------------|-----------------------|
| `Read`              | `read_file`           |
| `Write`             | `write_file`          |
| `Edit`              | `replace`             |
| `Bash`              | `run_shell_command`   |
| `Grep`              | `grep_search`         |
| `Glob`              | `glob`                |
| `TodoWrite`         | `write_todos`         |
| `Skill` (invoke)    | `activate_skill`      |
| `WebSearch`         | `google_web_search`   |
| `WebFetch`          | `web_fetch`           |
| `Task` (subagent)   | No equivalent — run inline |

## Write-guard reminder

When `.no-vibe/active` exists, `write_file` and `replace` are refused on
paths outside `.no-vibe/`. The same rule applies to `run_shell_command`:
self-enforce rejection of `>`, `>>`, `&>`, `&>>`, `tee`, `sed -i` /
`--in-place`, `cp`, `mv`, `install`, `dd of=…`, and `cat <<EOF >`
heredoc-redirects when the destination falls outside `.no-vibe/**`,
`/tmp/**`, `/var/tmp/**`, or `/dev/{null,stdout,stderr,tty,fd/*}`. Variable or command-substituted destinations
(`$VAR`, `$(…)`, backticks) — fail closed.

`2>&1` and other fd-merge forms (no file target) are fine. Read-only
shells (`ls`, `git status`, `grep`, `cat`, build/test invocations that
don't redirect to project paths) are allowed.

Show code in chat; user types it.

## Data persistence

Use `save_memory` sparingly — no-vibe's learner state lives in
`.no-vibe/data/` (project) and `~/.no-vibe/` (global), both governed by
`skills/no-vibe/DATA-SCHEMA.md`. Do not duplicate that state into Gemini
memory.
