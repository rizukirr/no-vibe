# Install no-vibe — Codex

Codex has no marketplace. It reads `AGENTS.md` from the project root, so install is **per-project**.

## Steps

1. Clone the repo somewhere (one-time):

   ```bash
   git clone https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
   ```

2. From inside the project the user wants tutor-mode in:

   ```bash
   bash ~/tools/no-vibe/install/install-codex.sh
   ```

   The script refuses to overwrite if the project already has an `AGENTS.md`. In that case, merge by hand: copy the relevant sections from `~/tools/no-vibe/runtimes/codex/AGENTS.md` into the existing file.

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
