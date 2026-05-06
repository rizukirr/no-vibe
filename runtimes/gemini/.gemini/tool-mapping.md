# Gemini CLI Tool Mapping (for no-vibe)

The no-vibe skill is written against Claude tool names. Use these Gemini equivalents:

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

## Memory model

Two NO-VIBE.md files (project + global). Use `read_file` / `write_file` directly on:

- `.no-vibe/NO-VIBE.md` (project canvas)
- `~/.no-vibe/NO-VIBE.md` (style — global)

Do not mirror these into Gemini's `save_memory`. The files are the canonical store.
