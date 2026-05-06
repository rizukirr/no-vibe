# Install no-vibe — OpenCode

OpenCode has no marketplace. Install copies the plugin tree into OpenCode's plugins directory.

## Steps

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-opencode.sh
```

Default destination: `~/.config/opencode/plugins/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-opencode.sh`

Restart OpenCode after install.

## Verify

- `~/.config/opencode/plugins/no-vibe/plugins/no-vibe.js` exists.
- `~/.config/opencode/plugins/no-vibe/skills/no-vibe/SKILL.md` exists.
- `~/.config/opencode/plugins/no-vibe/commands/` contains five command files.
- `~/.no-vibe/NO-VIBE.md` exists (seeded if missing).
- After OpenCode restart, the slash commands `/no-vibe`, `/no-vibe-btw`, `/no-vibe-challenge`, `/no-vibe-forget`, `/no-vibe-clear` are available.

## What gets installed

- JS plugin (`plugins/no-vibe.js`) — provides the write guard.
- Skill prose, command prose, guard data (`shared/guard/*.json`), templates.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Hard.** The JS plugin reads `shared/guard/write-tools.json` and blocks writes to project paths. Same allowlist as Claude: `.no-vibe/`, `~/.no-vibe/`, `/tmp`, `/dev/null` family.
