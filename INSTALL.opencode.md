# no-vibe — OpenCode Installation

## Install

1) Add the plugin to your OpenCode config (`~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git",
    "no-vibe@git+https://github.com/rizukirr/no-vibe.git"
  ]
}
```

2) Install global commands:

```bash
mkdir -p ~/.config/opencode/commands
curl -fsSL https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/.opencode/commands/no-vibe.md -o ~/.config/opencode/commands/no-vibe.md
curl -fsSL https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/.opencode/commands/no-vibe-challenge.md -o ~/.config/opencode/commands/no-vibe-challenge.md
curl -fsSL https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/.opencode/commands/no-vibe-btw.md -o ~/.config/opencode/commands/no-vibe-btw.md
```

3) Refresh plugin cache (recommended on install/update):

```bash
rm -rf ~/.cache/opencode/packages/no-vibe@git+https:/github.com/rizukirr/no-vibe.git
opencode run --print-logs "check no-vibe plugin"
```

4) Restart OpenCode.

## Verify

1. Run `/no-vibe on`. This creates `.no-vibe/active`; PROFILE.md is not created yet (it is created by the AI on its first reply).
2. Start a lesson topic (for example `/no-vibe build a linear layer`)
3. On the AI's first reply, confirm `~/.no-vibe/PROFILE.md` exists with the schema headings (`## Identity & expertise`, `## Learning style`, `## Disclosure mode`, `## Observed strengths`, `## Known gaps`) and empty bullets under each. `.no-vibe/SUMMARY.md` should NOT exist yet — it appears at the first layer close worth recording, with sections `## Current Focus`, `## Accomplishments`, `## Open Questions`.
4. Confirm the assistant teaches in chat and does not write project files directly.

CLI note: when using `opencode run`, invoke commands with `--command` (for example `opencode run --command no-vibe on`). Do not pass `/no-vibe on` as a plain message if you expect command execution.

## Customizing teaching style

no-vibe uses a four-layer adaptation stack, split by *write cadence* and *scope*:

- **Default teaching style** — the floor. Defined in `skills/no-vibe/SKILL.md`. Ships with the plugin; you never edit this directly.
- **`~/.no-vibe/PROFILE.md` — global, stable identity (AI-managed):** identity, expertise, learning style, disclosure mode (guided vs. showcase default), observed strengths, known gaps. AI-created on your first `/no-vibe` activation, rewritten only when something cross-project durable shifts.
- **`.no-vibe/SUMMARY.md` — project, running journey (AI-managed):** current focus, accomplishments, open questions in *this* project. AI-created at the first layer close worth recording, updated frequently, pruned aggressively.
- **`user/*.md` — your override files (user-managed, AI never touches):**
  - `~/.no-vibe/user/*.md` — global overrides
  - `.no-vibe/user/*.md` — project overrides

The OpenCode bootstrap hook is gated on `.no-vibe/active`, so projects without no-vibe never get a stray `.no-vibe/` directory. The hook injects `~/.no-vibe/PROFILE.md`, `.no-vibe/SUMMARY.md` (when present), and every `user/*.md` into the system prompt under a `## Background Memory` block prefaced with *"Use this memory sparingly — only when directly relevant"*. It does NOT create PROFILE.md, SUMMARY.md, or `user/` — AI creates the first two when needed; you create files under `user/` if you want explicit overrides.

Example explicit override:

```bash
mkdir -p ~/.no-vibe/user
cat > ~/.no-vibe/user/style.md <<'EOF'
- Skip the 12-year-old framing — I have a CS background; technical vocab is fine.
- Prefer direct mechanism over kitchen/sports analogies.
EOF
```

The filename is yours to choose; the AI loads every `.md` file in `user/` sorted by filename. Anything in `user/` is read-only for the AI.

## Troubleshooting

- Check logs: `opencode run --print-logs "hello" 2>&1 | rg -i "no-vibe|plugin|error"`
- Requires `rg` (ripgrep) for the troubleshooting command above
- If install fails, look for `ENOENT ... package.json` on `no-vibe@git+...`
- If `/no-vibe` is unknown, command files were not installed in `~/.config/opencode/commands/`
- If installed version looks stale, clear only the no-vibe cache path above, run `opencode run --print-logs "check no-vibe plugin"`, then restart OpenCode
