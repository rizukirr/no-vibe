# Install no-vibe — OpenCode

OpenCode has no marketplace. Install copies the plugin tree into OpenCode's plugins directory.

## Steps (script)

```bash
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
rm -rf "$HOME/.config/opencode/plugins/no-vibe"
bash ~/tools/no-vibe/install/install-opencode.sh
```

Default destination: `~/.config/opencode/plugins/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-opencode.sh`

Restart OpenCode after install.

## Manual installation (no script)

For when the script can't be run. These commands replicate `install/install-opencode.sh`.

**Environment:** the commands below are bash. **If the user is on Windows**, translate to whichever shell they have — PowerShell, Git Bash, or WSL. Use `$env:USERPROFILE` (PowerShell) or `%USERPROFILE%` (cmd) instead of `$HOME`. On PowerShell, use `Copy-Item` for `cp` and `New-Item -ItemType Directory -Force` for `mkdir -p`. Same logical steps on every OS.

```bash
# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe
DEST="$HOME/.config/opencode/plugins/no-vibe"

# 2. Remove old OpenCode no-vibe plugin first (fresh install/update)
rm -rf "$DEST"

# 3. Create destination tree
mkdir -p "$DEST/plugins" "$DEST/commands" "$DEST/skills/no-vibe" \
         "$DEST/shared/guard" "$DEST/shared/templates"

# 4. Copy runtime adapter
cp "$REPO/runtimes/opencode/plugins/no-vibe.js" "$DEST/plugins/"
cp "$REPO/runtimes/opencode/index.js" "$DEST/"

# 5. Copy shared content
cp "$REPO"/shared/skill/*.md "$DEST/skills/no-vibe/"
cp "$REPO"/shared/commands/*.md "$DEST/commands/"
cp "$REPO"/shared/guard/*.json "$DEST/shared/guard/"
cp "$REPO"/shared/templates/*.md "$DEST/shared/templates/"

# 6. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"

# 7. Clean up — the clone is no longer needed
rm -rf ~/tools/no-vibe
```

Then restart OpenCode.

## Updating an existing install

If the user already has no-vibe installed at `~/.config/opencode/plugins/no-vibe/`, remove it before reinstalling:

```bash
rm -rf "$HOME/.config/opencode/plugins/no-vibe"
```

Then run the script or manual install steps above. Don't touch `~/.no-vibe/` — user data, survives upgrades.

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
