# no-vibe-clear

Permanently remove all no-vibe state for current project and current user.

When asked to run this skill:

1. Ask for strong confirmation:
   "This will permanently delete this project's `.no-vibe/` and global `~/.no-vibe/`. This cannot be undone. Type `yes, clear all` exactly to continue:"
2. If response is not exactly `yes, clear all`, cancel with no changes.
3. Remove:
   - `.no-vibe/`
   - `~/.no-vibe/`
4. Reply with:
   "Cleared. Project `.no-vibe/` and global `~/.no-vibe/` removed."
