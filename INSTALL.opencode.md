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
```

3) Restart OpenCode.

## Verify

1. Run `/no-vibe on`
2. Start a lesson topic (for example `/no-vibe build a linear layer`)
3. Confirm the assistant teaches in chat and does not write project files directly

CLI note: when using `opencode run`, invoke commands with `--command` (for example `opencode run --command no-vibe on`). Do not pass `/no-vibe on` as a plain message if you expect command execution.

## Troubleshooting

- Check logs: `opencode run --print-logs "hello" 2>&1 | rg -i "no-vibe|plugin|error"`
- Requires `rg` (ripgrep) for the troubleshooting command above
- If install fails, look for `ENOENT ... package.json` on `no-vibe@git+...`
- If `/no-vibe` is unknown, command files were not installed in `~/.config/opencode/commands/`
