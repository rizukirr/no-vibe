# Install no-vibe — Pi

Pi has no marketplace. Install copies the plugin tree into Pi's plugins directory.

**Important:** the installer **skips** if no-vibe is already installed at any of these paths. Remove the existing install first if you want to reinstall.

- `~/.agents/skills/no-vibe`
- `~/.pi/plugins/no-vibe`
- `~/.pi/extensions/no-vibe`

## Steps (script)

```bash
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-pi.sh
```

Default destination: `~/.pi/plugins/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-pi.sh`

Restart Pi after install.

## Manual installation (no script)

For when the script can't be run. These commands replicate `install/install-pi.sh`. **Check for existing installs first** and abort if found:

```bash
# 0. Skip if already installed at any known Pi location
for p in "$HOME/.agents/skills/no-vibe" "$HOME/.pi/plugins/no-vibe" "$HOME/.pi/extensions/no-vibe"; do
    [ -d "$p" ] && { echo "Already installed at $p — abort"; return 0 2>/dev/null || exit 0; }
done

# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe
DEST="$HOME/.pi/plugins/no-vibe"

# 2. Create destination tree
mkdir -p "$DEST/extensions/no-vibe" "$DEST/prompts" "$DEST/skills/no-vibe" \
         "$DEST/shared/guard" "$DEST/shared/templates"

# 3. Copy runtime adapter
cp "$REPO/runtimes/pi/.pi-plugin/plugin.json" "$DEST/"
cp "$REPO/runtimes/pi/.pi-plugin/extensions/no-vibe/index.ts" "$DEST/extensions/no-vibe/"

# 4. Copy shared content
cp "$REPO"/shared/skill/*.md "$DEST/skills/no-vibe/"
cp "$REPO"/shared/commands/*.md "$DEST/prompts/"
cp "$REPO"/shared/guard/*.json "$DEST/shared/guard/"
cp "$REPO"/shared/templates/*.md "$DEST/shared/templates/"

# 5. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
```

Then restart Pi.

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
