# no-vibe for Pi

Pi is the [pi-mono](https://github.com/badlogic/pi-mono) coding agent (`@mariozechner/pi-coding-agent`). no-vibe ships as a pi package. The bundled extension runs the shared write guard as a hard block and injects the status line, the bundled prompts expose `/no-vibe`, `/no-vibe-btw` and `/no-vibe-challenge`, and the `skills/` directory is shared with the other runtimes.

Requires `bash` on PATH.

## Avoiding skill collisions

Pi also reads skills from `~/.agents/skills/`. If `~/.agents/skills/no-vibe/` exists from a manual install, pi discovers the skill twice and warns about the collision on every startup. Remove that directory or symlink before installing the package.

```bash
ls ~/.agents/skills/no-vibe/ 2>/dev/null
```

## Install

### Option A: global, from git

```bash
pi install git:github.com/rizukirr/no-vibe
```

This installs to `~/.pi/agent/git/no-vibe/`, and pi discovers these from `package.json`:

- skills from `./skills` (`pi.skills`)
- prompts from `./.pi-plugin/prompts` (`pi.prompts`)
- the extension from `./.pi-plugin/extensions` (`pi.extensions`)

### Option B: project-local

```bash
cd /path/to/your/project
pi install -l git:github.com/rizukirr/no-vibe
```

Installs under `.pi/` for the current project only.

### Option C: manual symlink

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

## Verify installation

1. Start `pi` in any project.
2. Run `/no-vibe on`. It should create `.no-vibe/active` and switch the status line to `no-vibe: ON`.
3. Send a topic. The agent should start with multiple-choice questions about your level, and every reply should start with the `[no-vibe] Step: ...` header.
4. Ask the assistant to write a project file such as `src/foo.py`. The extension should block it at the tool level with `no-vibe mode is active. You cannot write to '...' while learning.`
5. Ask the assistant to run `echo bad > someproj.py` or `sed -i` on a project file. It should be blocked with `no-vibe mode is active. Refusing Bash command that writes outside the safe-target allowlist`.
6. Confirm writes to `.no-vibe/notes.md` and `/tmp/scratch.txt` still succeed.
7. Run `/no-vibe off`. It should remove the marker.

## Notes

- The extension hooks `pi.on("tool_call", ...)` and returns `{ block: true, reason }`. It runs `hooks/block-writes.sh` and `hooks/block-bash-writes.sh`, the same guard scripts every other runtime uses, so the allowlist and the Bash rules cannot drift between runtimes.
- If the guard script cannot run, the extension blocks the write. A missing guard is worse than a blocked write.
- Skills load from the shared `skills/` directory, so a SKILL.md edit reaches pi with no per-runtime copy.
