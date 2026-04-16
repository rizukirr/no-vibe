# Installing no-vibe for OpenCode

## 1) Add plugin entry

Add this to `opencode.json` (project or global):

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

This enables plugin hooks (bootstrap injection, skill path registration, write guard in active mode).

## 2) Install commands

Plugins and commands are loaded separately in OpenCode. To use `/no-vibe` and `/no-vibe:challenge` globally, copy command files into your global commands directory:

```bash
mkdir -p ~/.config/opencode/commands
cp .opencode/commands/no-vibe.md ~/.config/opencode/commands/no-vibe.md
cp .opencode/commands/no-vibe-challenge.md ~/.config/opencode/commands/no-vibe-challenge.md
cp .opencode/commands/no-vibe-btw.md ~/.config/opencode/commands/no-vibe-btw.md
```

If you prefer project-local commands instead, copy these files into `<project>/.opencode/commands/`.

## 3) Restart OpenCode

Restart OpenCode so plugins and commands reload.

## 4) Verify

- Run `/no-vibe on`
- Ask for a coding lesson topic
- Confirm the agent teaches in chat instead of writing project files
- CLI note: with `opencode run`, use `--command no-vibe on` rather than passing `/no-vibe on` as plain message text.

## Troubleshooting

Check logs:

```bash
opencode run --print-logs "hello" 2>&1 | rg -i "no-vibe|plugin"
```

Requires `rg` (ripgrep).

If the plugin does not load:

1. Confirm the plugin line exists in `opencode.json`
2. Confirm package install succeeds (no `ENOENT ... package.json` for `no-vibe@git+...` in logs)
3. In OpenCode, run `/no-vibe on` and confirm the command is recognized (not "unknown command"); then run `skill` and confirm `no-vibe` appears in the available skills list
4. Restart OpenCode after config changes

## Local verification

Run both local test suites before opening a PR:

```bash
bash tests/test_block_writes.sh
node tests/test_opencode_plugin.mjs
```
