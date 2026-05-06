# Install no-vibe — Codex

Codex has no marketplace. It reads `AGENTS.md` from the project root, so install is **per-project**.

## Prerequisites

- **Git**
- **Bash**, **Awk**, and **jq** (required for the `sync.sh` step to regenerate runtime files).
  - *Windows:* These are included with **Git Bash**. Ensure they are in your PATH if using PowerShell.

## Steps (script)

1. Clone the repo somewhere (one-time):

   ```bash
   git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
   ```

2. Remove old Codex no-vibe skills first (fresh install/update):

   ```bash
   rm -rf ~/.codex/no-vibe
   ```

3. From inside the project the user wants tutor-mode in:

   ```bash
   bash ~/tools/no-vibe/install/install-codex.sh
   ```

   The script refuses to overwrite if the project already has an `AGENTS.md`. In that case, merge by hand: copy the relevant sections from `~/tools/no-vibe/runtimes/codex/AGENTS.md` into the existing file.

## Manual installation (no script)

For when the script can't be run. Run from inside the target project.

### Option A: Bash / Zsh (Linux, macOS, Git Bash)

```bash
# 1. Clone (one-time, anywhere)
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe

# 2. Remove old Codex no-vibe skills first
rm -rf ~/.codex/no-vibe

# 3. Regenerate runtimes/codex/AGENTS.md from /shared/
bash "$REPO/scripts/sync.sh"

# 4. Copy AGENTS.md to project root — REFUSE if one already exists
if [ -f AGENTS.md ]; then
    echo "AGENTS.md exists — merge manually from $REPO/runtimes/codex/AGENTS.md"
else
    cp "$REPO/runtimes/codex/AGENTS.md" AGENTS.md
fi

# 5. Copy skill prose + commands to .no-vibe/codex/ for reference
mkdir -p .no-vibe/codex/skill .no-vibe/codex/commands
cp "$REPO"/shared/skill/*.md .no-vibe/codex/skill/
cp "$REPO"/shared/commands/*.md .no-vibe/codex/commands/

# 6. Install Codex-visible skills
mkdir -p "$HOME/.codex/no-vibe/skills/no-vibe" "$HOME/.codex/no-vibe/skills/no-vibe-btw" "$HOME/.codex/no-vibe/skills/no-vibe-challenge" "$HOME/.codex/no-vibe/skills/no-vibe-forget" "$HOME/.codex/no-vibe/skills/no-vibe-clear"
cp "$REPO/runtimes/codex/skills/no-vibe/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe/SKILL.md"
cp "$REPO/runtimes/codex/skills/no-vibe-btw/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-btw/SKILL.md"
cp "$REPO/runtimes/codex/skills/no-vibe-challenge/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-challenge/SKILL.md"
cp "$REPO/runtimes/codex/skills/no-vibe-forget/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-forget/SKILL.md"
cp "$REPO/runtimes/codex/skills/no-vibe-clear/SKILL.md" "$HOME/.codex/no-vibe/skills/no-vibe-clear/SKILL.md"

# 7. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"

# 8. Clean up
rm -rf ~/tools/no-vibe
```

### Option B: Windows (PowerShell)

Run these in a PowerShell terminal inside your project directory. Note: Step 3 still requires `bash` (e.g., from Git Bash) to be in your PATH.

```powershell
# 1. Clone (one-time, anywhere)
git clone -b v2 https://github.com/rizukirr/no-vibe.git "$HOME\tools\no-vibe"
$REPO = "$HOME\tools\no-vibe"

# 2. Remove old Codex no-vibe skills first
if (Test-Path "$HOME\.codex\no-vibe") { Remove-Item -Recurse -Force "$HOME\.codex\no-vibe" }

# 3. Regenerate runtimes (requires bash/awk/jq in PATH)
bash "$REPO\scripts\sync.sh"

# 4. Copy AGENTS.md to project root — REFUSE if one already exists
if (Test-Path "AGENTS.md") {
    Write-Host "AGENTS.md exists — merge manually from $REPO\runtimes\codex\AGENTS.md" -ForegroundColor Yellow
} else {
    Copy-Item "$REPO\runtimes\codex\AGENTS.md" "AGENTS.md"
}

# 5. Copy skill prose + commands to .no-vibe/codex/ for reference
New-Item -ItemType Directory -Force -Path ".no-vibe\codex\skill", ".no-vibe\codex\commands"
Copy-Item "$REPO\shared\skill\*.md" ".no-vibe\codex\skill\"
Copy-Item "$REPO\shared\commands\*.md" ".no-vibe\codex\commands\"

# 6. Install Codex-visible skills
$SKILLS = "no-vibe", "no-vibe-btw", "no-vibe-challenge", "no-vibe-forget", "no-vibe-clear"
foreach ($s in $SKILLS) {
    New-Item -ItemType Directory -Force -Path "$HOME\.codex\no-vibe\skills\$s"
    Copy-Item "$REPO\runtimes\codex\skills\$s\SKILL.md" "$HOME\.codex\no-vibe\skills\$s\SKILL.md"
}

# 7. Seed global ~/.no-vibe/ if first install
New-Item -ItemType Directory -Force -Path "$HOME\.no-vibe\memory"
if (-not (Test-Path "$HOME\.no-vibe\NO-VIBE.md")) { Copy-Item "$REPO\shared\templates\NO-VIBE.global.md" "$HOME\.no-vibe\NO-VIBE.md" }
if (-not (Test-Path "$HOME\.no-vibe\memory\README.md")) { Copy-Item "$REPO\shared\templates\memory-readme.md" "$HOME\.no-vibe\memory\README.md" }

# 8. Clean up
Remove-Item -Recurse -Force $REPO
```

If `AGENTS.md` already existed, **don't delete the clone yet** — open both files and copy the no-vibe sections from `$REPO/runtimes/codex/AGENTS.md` into the project's `AGENTS.md`. Delete the clone after the merge.

## Updating an existing install

If `AGENTS.md` already exists in the project, compare it with the latest generated no-vibe file first:

```bash
# Generate latest codex AGENTS.md from the cloned repo
bash "$HOME/tools/no-vibe/scripts/sync.sh"

# Compare current project file vs latest no-vibe file
if cmp -s AGENTS.md "$HOME/tools/no-vibe/runtimes/codex/AGENTS.md"; then
  echo "Up-to-date: skip reinstall/replace."
else
  echo "Different: update required."
fi
```

If different:

- If project `AGENTS.md` is no-vibe-generated, replace it with the latest file.
- If project `AGENTS.md` is custom, merge new no-vibe sections from `~/tools/no-vibe/runtimes/codex/AGENTS.md` by hand (remove old no-vibe block first).

Don't touch `~/.no-vibe/` — user data, survives upgrades. `.no-vibe/codex/skill/` and `.no-vibe/codex/commands/` can be safely overwritten.

## Verify

- `<project>/AGENTS.md` exists and starts with the no-vibe header.
- `<project>/.no-vibe/codex/skill/` and `.no-vibe/codex/commands/` contain the skill prose and command files.
- `~/.codex/no-vibe/skills/` contains `no-vibe`, `no-vibe-btw`, `no-vibe-challenge`, `no-vibe-forget`, `no-vibe-clear` with valid `SKILL.md` files.
- `~/.no-vibe/NO-VIBE.md` exists (seeded from template if it didn't already).

## What gets installed

- `AGENTS.md` at the project root (Codex auto-loads this on session start).
- Skill prose + command files copied to `.no-vibe/codex/` for reference.
- Codex skills installed under `~/.codex/no-vibe/skills/` for command visibility.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Soft.** Codex has no hook surface. Enforcement is instruction-only: the rule lives in `AGENTS.md` and binds the AI behaviorally. There is no kernel-level guard. If the model deviates, only the instruction stops it.

## Per-project nature

Re-run the installer in every project where the user wants tutor-mode. Removing tutor-mode is `rm <project>/AGENTS.md` (or the no-vibe section, if it was merged into an existing file).
