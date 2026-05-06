# Install no-vibe — Codex

Codex has no marketplace. It reads `AGENTS.md` from the project root, so install is **per-project**.

## Steps (script)

1. Clone the repo somewhere (one-time):

   ```bash
   git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
   ```

2. From inside the project the user wants tutor-mode in:

   ```bash
   bash ~/tools/no-vibe/install/install-codex.sh
   ```

   The script refuses to overwrite if the project already has an `AGENTS.md`. In that case, merge by hand: copy the relevant sections from `~/tools/no-vibe/runtimes/codex/AGENTS.md` into the existing file.

## Manual installation (no script)

For when the script can't be run. These commands replicate `install/install-codex.sh`. Run from inside the target project:

```bash
# 1. Clone (one-time, anywhere)
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
REPO=~/tools/no-vibe

# 2. Regenerate runtimes/codex/AGENTS.md from /shared/
bash "$REPO/scripts/sync.sh"

# 3. Copy AGENTS.md to project root — REFUSE if one already exists
if [ -f AGENTS.md ]; then
    echo "AGENTS.md exists — merge manually from $REPO/runtimes/codex/AGENTS.md"
else
    cp "$REPO/runtimes/codex/AGENTS.md" AGENTS.md
fi

# 4. Copy skill prose + commands to .no-vibe/codex/ for reference
mkdir -p .no-vibe/codex/skill .no-vibe/codex/commands
cp "$REPO"/shared/skill/*.md .no-vibe/codex/skill/
cp "$REPO"/shared/commands/*.md .no-vibe/codex/commands/

# 5. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp "$REPO/shared/templates/NO-VIBE.global.md" "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp "$REPO/shared/templates/memory-readme.md" "$HOME/.no-vibe/memory/README.md"
```

If `AGENTS.md` already existed, open both files and copy the no-vibe sections from `$REPO/runtimes/codex/AGENTS.md` into the project's `AGENTS.md`.

## Verify

- `<project>/AGENTS.md` exists and starts with the no-vibe header.
- `<project>/.no-vibe/codex/skill/` and `.no-vibe/codex/commands/` contain the skill prose and command files.
- `~/.no-vibe/NO-VIBE.md` exists (seeded from template if it didn't already).

## What gets installed

- `AGENTS.md` at the project root (Codex auto-loads this on session start).
- Skill prose + command files copied to `.no-vibe/codex/` for reference.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Soft.** Codex has no hook surface. Enforcement is instruction-only: the rule lives in `AGENTS.md` and binds the AI behaviorally. There is no kernel-level guard. If the model deviates, only the instruction stops it.

## Per-project nature

Re-run the installer in every project where the user wants tutor-mode. Removing tutor-mode is `rm <project>/AGENTS.md` (or the no-vibe section, if it was merged into an existing file).
