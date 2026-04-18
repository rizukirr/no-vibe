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
paths outside `.no-vibe/`. Do not work around via `run_shell_command`
redirections. Show code in chat; user types it.

## Data persistence

Use `save_memory` sparingly — no-vibe's learner state lives in
`.no-vibe/data/` (project) and `~/.no-vibe/` (global), both governed by
`skills/no-vibe/DATA-SCHEMA.md`. Do not duplicate that state into Gemini
memory.
