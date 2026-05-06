# no-vibe-forget

Reset both no-vibe memory profiles to defaults while archiving prior versions.

When asked to run this skill:

1. Ask for confirmation:
   "This will reset `~/.no-vibe/NO-VIBE.md` and `.no-vibe/NO-VIBE.md` to defaults, archiving old versions to `memory/`. Continue? (y/N)"
2. If answer is not `y` or `yes`, cancel with no changes.
3. Archive non-empty files:
   - `~/.no-vibe/NO-VIBE.md` -> `~/.no-vibe/memory/NO-VIBE-<utc-ts>.md`
   - `.no-vibe/NO-VIBE.md` -> `.no-vibe/memory/NO-VIBE-<utc-ts>.md`
4. Recreate defaults:
   - copy `shared/templates/NO-VIBE.global.md` -> `~/.no-vibe/NO-VIBE.md`
   - copy `shared/templates/NO-VIBE.project.md` -> `.no-vibe/NO-VIBE.md`
5. Reply with one line describing what was archived or skipped.
