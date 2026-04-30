# no-vibe — Pi Installation

Pi is the [pi-mono](https://github.com/badlogic/pi-mono) coding agent (`@mariozechner/pi-coding-agent`). no-vibe ships as a pi package: the bundled extension provides a **hard** write-guard (mirrors the OpenCode in-process guard), the bundled prompts expose `/no-vibe`, `/no-vibe-btw`, `/no-vibe-challenge`, and the canonical `skills/` directory is shared with the other runtimes.

## Install

### Option A — global, from git

```bash
pi install git:github.com/rizukirr/no-vibe
```

This installs to `~/.pi/agent/git/no-vibe/` and pi auto-discovers:
- skills from `./skills` (declared in `package.json` → `pi.skills`)
- prompts from `./.pi-plugin/prompts` (declared in `package.json` → `pi.prompts`)
- the write-guard extension from `./.pi-plugin/extensions` (declared in `package.json` → `pi.extensions`)

### Option B — project-local

```bash
cd /path/to/your/project
pi install -l git:github.com/rizukirr/no-vibe
```

Installs under `.pi/` for the current project only.

### Option C — manual symlink

If you cloned the repo elsewhere:

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/Projects/no-vibe

mkdir -p ~/.pi/agent/skills ~/.pi/agent/prompts ~/.pi/agent/extensions
ln -s ~/Projects/no-vibe/skills/no-vibe                          ~/.pi/agent/skills/no-vibe
ln -s ~/Projects/no-vibe/.pi-plugin/prompts/no-vibe.md           ~/.pi/agent/prompts/no-vibe.md
ln -s ~/Projects/no-vibe/.pi-plugin/prompts/no-vibe-btw.md       ~/.pi/agent/prompts/no-vibe-btw.md
ln -s ~/Projects/no-vibe/.pi-plugin/prompts/no-vibe-challenge.md ~/.pi/agent/prompts/no-vibe-challenge.md
ln -s ~/Projects/no-vibe/.pi-plugin/extensions/no-vibe           ~/.pi/agent/extensions/no-vibe
```

## Verify Installation

1. Start `pi` in any project.
2. Run `/no-vibe on` — should create `.no-vibe/active` and switch the status injection to `no-vibe: ON`.
3. Ask the assistant to write a project file (e.g. `src/foo.py`) — it should be **blocked at the tool level** by the extension with `no-vibe mode is active. Refusing write to '...'`.
4. Ask the assistant to `echo bad > someproj.py` or `sed -i …` on a project file — it should also be blocked with the corresponding `Refusing Bash command — …` message.
5. Confirm `.no-vibe/notes.md` writes still succeed (allowlist).
6. Confirm `/tmp/scratch.txt` writes still succeed (allowlist).
7. Run `/no-vibe off` — should remove the marker.

## Notes

- This is a **hard block** (extension uses `pi.on("tool_call", ...)` returning `{ block: true, reason }`). It is at parity with the Claude Code and OpenCode surfaces, not the soft-block-only Codex/Gemini surfaces.
- Path-handling, Bash-parsing rules, and the safe-target allowlist (`.no-vibe/**`, `/tmp/**`, `/var/tmp/**`, `/dev/{null,stdout,stderr,tty,fd/*}`) are kept in lockstep with `.opencode/plugins/no-vibe.js` and the Claude `hooks/`. Variable / command-substitution destinations (`$VAR`, `$(…)`, backticks) fail closed.
- Skills are loaded from the canonical `skills/` directory — there is no per-runtime copy, so a SKILL.md edit propagates to pi automatically.
