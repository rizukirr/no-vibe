# Installing no-vibe for OpenCode

## 1) Add plugin entry

Add this to `opencode.json` (project or global):

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

## 2) Restart OpenCode

Restart OpenCode so plugins and commands reload.

## 3) Verify

- Run `/no-vibe on`
- Ask for a coding lesson topic
- Confirm the agent teaches in chat instead of writing project files

## Troubleshooting

Check logs:

```bash
opencode run --print-logs "hello" 2>&1 | rg -i "no-vibe|plugin"
```

If the plugin does not load:

1. Confirm the plugin line exists in `opencode.json`
2. In OpenCode, run `/no-vibe on` and confirm the command is recognized (not "unknown command"); then run `skill` and confirm `no-vibe` appears in the available skills list
3. Restart OpenCode after config changes

## Local verification

Run both local test suites before opening a PR:

```bash
bash tests/test_block_writes.sh
node tests/test_opencode_plugin.mjs
```

Known baseline issue: `tests/test_block_writes.sh` currently points to `.claude-plugin/hooks/block-writes.sh`, but this branch stores the hook at `hooks/block-writes.sh`.

Recommended fix:

```bash
# tests/test_block_writes.sh
HOOK="$SCRIPT_DIR/../hooks/block-writes.sh"
```
