# Install no-vibe — Gemini CLI

Gemini CLI uses extensions. Install copies the extension tree into Gemini's extensions directory.

## Prerequisites

- **Git**
- **Bash**, **Awk**, and **jq** (required for the `sync.sh` step to regenerate runtime files).
  - *Windows:* These are included with **Git Bash**. Ensure they are in your PATH if using PowerShell.

## Steps (script)

If you have a Bash environment (Linux, macOS, or Git Bash on Windows):

```bash
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
rm -rf "$HOME/.gemini/extensions/no-vibe"
bash ~/tools/no-vibe/install/install-gemini.sh
```

Default destination: `~/.gemini/extensions/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-gemini.sh`

Restart Gemini CLI after install.

## Manual installation (no script)

For when the script can't be run.

### Option A: Bash / Zsh (Linux, macOS, Git Bash)

```bash
# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe
DEST="$HOME/.gemini/extensions/no-vibe"

# 2. Remove old Gemini no-vibe extension first
rm -rf "$DEST"

# 3. Regenerate runtimes/gemini/ from /shared/ (GEMINI.md + .toml commands)
bash "$REPO/scripts/sync.sh"

# 4. Create destination tree
mkdir -p "$DEST/.gemini/commands" "$DEST/skills/no-vibe"

# 5. Copy runtime adapter
cp "$REPO/runtimes/gemini/gemini-extension.json" "$DEST/"
cp "$REPO/runtimes/gemini/GEMINI.md" "$DEST/"
cp "$REPO/runtimes/gemini/.gemini/tool-mapping.md" "$DEST/.gemini/"
cp "$REPO/runtimes/gemini/.gemini/commands/"*.toml "$DEST/.gemini/commands/"

# 6. Copy skill prose
cp "$REPO/shared/skill/"*.md "$DEST/skills/no-vibe/"

# 7. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"

# 8. Clean up
rm -rf ~/tools/no-vibe
```

### Option B: Windows (PowerShell)

Run these in a PowerShell terminal. Note: Step 3 still requires `bash` (e.g., from Git Bash) to be in your PATH.

```powershell
# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git "$HOME\tools\no-vibe"
$REPO = "$HOME\tools\no-vibe"
$DEST = "$HOME\.gemini\extensions\no-vibe"

# 2. Remove old Gemini no-vibe extension first
if (Test-Path $DEST) { Remove-Item -Recurse -Force $DEST }

# 3. Regenerate runtimes (requires bash/awk/jq in PATH)
bash "$REPO\scripts\sync.sh"

# 4. Create destination tree
New-Item -ItemType Directory -Force -Path "$DEST\.gemini\commands", "$DEST\skills\no-vibe", "$HOME\.no-vibe\memory"

# 5. Copy runtime adapter
Copy-Item "$REPO\runtimes\gemini\gemini-extension.json" "$DEST\"
Copy-Item "$REPO\runtimes\gemini\GEMINI.md" "$DEST\"
Copy-Item "$REPO\runtimes\gemini\.gemini\tool-mapping.md" "$DEST\.gemini\"
Copy-Item "$REPO\runtimes\gemini\.gemini\commands\*.toml" "$DEST\.gemini\commands\"

# 6. Copy skill prose
Copy-Item "$REPO\shared\skill\*.md" "$DEST\skills\no-vibe\"

# 7. Seed global ~/.no-vibe/ if first install
if (-not (Test-Path "$HOME\.no-vibe\NO-VIBE.md")) { Copy-Item "$REPO\shared\templates\NO-VIBE.global.md" "$HOME\.no-vibe\NO-VIBE.md" }
if (-not (Test-Path "$HOME\.no-vibe\memory\README.md")) { Copy-Item "$REPO\shared\templates\memory-readme.md" "$HOME\.no-vibe\memory\README.md" }

# 8. Clean up
Remove-Item -Recurse -Force $REPO
```

Then restart Gemini CLI.

## Updating an existing install

If the user already has no-vibe installed at `~/.gemini/extensions/no-vibe/`, compare **installed** vs **latest** first:

```bash
# Installed version
installed=$(jq -r '.version // empty' "$HOME/.gemini/extensions/no-vibe/gemini-extension.json" 2>/dev/null)

# Latest version (from a freshly cloned no-vibe repo)
latest=$(jq -r '.version // empty' "$HOME/tools/no-vibe/runtimes/gemini/gemini-extension.json" 2>/dev/null)

printf 'installed=%s\nlatest=%s\n' "$installed" "$latest"

if [ -n "$installed" ] && [ -n "$latest" ] && [ "$installed" = "$latest" ]; then
  echo "Up-to-date: skip reinstall."
else
  echo "Version differs (or unknown): reinstall."
fi
```

If versions differ, remove then reinstall:

```bash
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
