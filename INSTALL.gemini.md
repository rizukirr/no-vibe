# Install no-vibe — Gemini CLI

Gemini CLI uses extensions. Install copies the extension tree into Gemini's extensions directory.

## Steps (script)

```bash
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-gemini.sh
```

Default destination: `~/.gemini/extensions/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-gemini.sh`

Restart Gemini CLI after install.

## Manual installation (no script)

For when the script can't be run. These commands replicate `install/install-gemini.sh`.

**Environment:** the commands below are bash. **If the user is on Windows**, translate to whichever shell they have — PowerShell, Git Bash, or WSL. Use `$env:USERPROFILE` (PowerShell) or `%USERPROFILE%` (cmd) instead of `$HOME`. On PowerShell, use `Copy-Item` for `cp` and `New-Item -ItemType Directory -Force` for `mkdir -p`. Same logical steps on every OS.

```bash
# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe
DEST="$HOME/.gemini/extensions/no-vibe"

# 2. Regenerate runtimes/gemini/ from /shared/ (GEMINI.md + .toml commands)
bash "$REPO/scripts/sync.sh"

# 3. Create destination tree
mkdir -p "$DEST/.gemini/commands" "$DEST/skills/no-vibe"

# 4. Copy runtime adapter
cp "$REPO/runtimes/gemini/gemini-extension.json" "$DEST/"
cp "$REPO/runtimes/gemini/GEMINI.md" "$DEST/"
cp "$REPO/runtimes/gemini/.gemini/tool-mapping.md" "$DEST/.gemini/"
cp "$REPO"/runtimes/gemini/.gemini/commands/*.toml "$DEST/.gemini/commands/"

# 5. Copy skill prose
cp "$REPO"/shared/skill/*.md "$DEST/skills/no-vibe/"

# 6. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"

# 7. Clean up — the clone is no longer needed
rm -rf ~/tools/no-vibe
```

Then restart Gemini CLI.

## Updating an existing install

If the user already has no-vibe installed at `~/.gemini/extensions/no-vibe/`, check the version and remove before reinstalling:

```bash
# Check existing version
jq -r '.version' "$HOME/.gemini/extensions/no-vibe/gemini-extension.json" 2>/dev/null

# Remove the existing extension
rm -rf "$HOME/.gemini/extensions/no-vibe"
```

Then run the script or manual install steps above. Don't touch `~/.no-vibe/` — user data, survives upgrades.

## Verify

- `~/.gemini/extensions/no-vibe/gemini-extension.json` exists.
- `~/.gemini/extensions/no-vibe/GEMINI.md` exists.
- `~/.gemini/extensions/no-vibe/.gemini/commands/` contains five `.toml` command files.
- `~/.gemini/extensions/no-vibe/skills/no-vibe/SKILL.md` exists.
- `~/.no-vibe/NO-VIBE.md` exists (seeded if missing).
- After Gemini restart, the slash commands `/no-vibe`, `/no-vibe-btw`, `/no-vibe-challenge`, `/no-vibe-forget`, `/no-vibe-clear` are available.

## What gets installed

- Extension manifest (`gemini-extension.json`).
- `GEMINI.md` (auto-loaded by Gemini CLI on session start).
- Five `.toml` command definitions under `.gemini/commands/`.
- Skill prose under `skills/no-vibe/`.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Soft.** Gemini CLI has no write-hook surface for third-party extensions. Enforcement is instruction-only: the rule lives in `GEMINI.md` and binds the AI behaviorally. There is no kernel-level guard. If the model deviates, only the instruction stops it.
