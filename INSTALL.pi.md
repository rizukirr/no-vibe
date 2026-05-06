# Install no-vibe — Pi

Pi has no marketplace. Install copies the plugin tree into Pi's plugins directory.

**Important:** the installer **skips** if no-vibe is already installed at any of these paths. Remove the existing install first if you want to reinstall.

- `~/.agents/skills/no-vibe`
- `~/.pi/plugins/no-vibe`
- `~/.pi/extensions/no-vibe`

## Steps

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-pi.sh
```

Default destination: `~/.pi/plugins/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-pi.sh`

Restart Pi after install.

## Verify

- `~/.pi/plugins/no-vibe/plugin.json` exists.
- `~/.pi/plugins/no-vibe/extensions/no-vibe/index.ts` exists.
- `~/.pi/plugins/no-vibe/skills/no-vibe/SKILL.md` exists.
- `~/.pi/plugins/no-vibe/prompts/` contains five command files.
- `~/.no-vibe/NO-VIBE.md` exists (seeded if missing).
- After Pi restart, the slash commands `/no-vibe`, `/no-vibe-btw`, `/no-vibe-challenge`, `/no-vibe-forget`, `/no-vibe-clear` are available.

## What gets installed

- TypeScript extension (`extensions/no-vibe/index.ts`) — provides the write guard.
- Plugin manifest (`plugin.json`).
- Skill prose, command prompts, guard data (`shared/guard/*.json`), templates.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Hard.** The TS extension reads `shared/guard/write-tools.json` and blocks writes to project paths. Same allowlist as Claude / OpenCode.
