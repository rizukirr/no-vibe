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
3. On the AI's first reply, confirm `~/.no-vibe/PROFILE.md` and `.no-vibe/PROFILE.md` exist with the schema headings (`## Identity & expertise`, `## Observed strengths`, `## Known gaps`, `## Style notes`, `## Recent layer outcomes`) and empty bullets under each.
4. Confirm the assistant teaches in chat and does not write project files directly.

CLI note: when using `opencode run`, invoke commands with `--command` (for example `opencode run --command no-vibe on`). Do not pass `/no-vibe on` as a plain message if you expect command execution.

## Customizing teaching style

no-vibe uses a three-layer adaptation stack:

- **Default teaching style** — the floor. Defined in `skills/no-vibe/SKILL.md`. Ships with the plugin; you never edit this directly.
- **`PROFILE.md` — the AI's progression files (AI-managed):**
  - `~/.no-vibe/PROFILE.md` — global progression. AI-created on your first `/no-vibe` activation, AI-updated per layer when it learns something durable about how *you* learn.
  - `.no-vibe/PROFILE.md` — same shape, project-scoped.
- **`user/*.md` — your override files (user-managed, AI never touches):**
  - `~/.no-vibe/user/*.md` — global overrides
  - `.no-vibe/user/*.md` — project overrides

The OpenCode bootstrap hook is gated on `.no-vibe/active`, so projects without no-vibe never get a stray `.no-vibe/` directory. The hook injects PROFILE.md (both scopes, when present) and every `user/*.md` into the system prompt; it does NOT create PROFILE.md or `user/` — AI creates PROFILE.md on first activation, you create files under `user/` if you want explicit overrides.

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
