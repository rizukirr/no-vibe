---
description: Reset both NO-VIBE.md files to defaults; archive prior versions to memory/
argument-hint:
# AUTO-GENERATED FROM /shared — DO NOT EDIT — run scripts/sync.sh
---

# /no-vibe-forget

Resets both NO-VIBE.md files (global tutor profile + project canvas) to default templates. Prior versions are archived, not deleted.

## What gets archived

- `~/.no-vibe/NO-VIBE.md` → `~/.no-vibe/memory/NO-VIBE-<ISO-timestamp>.md`
- `.no-vibe/NO-VIBE.md` → `.no-vibe/memory/NO-VIBE-<ISO-timestamp>.md`

If a file is empty or missing, skip its archive (nothing to preserve).

## Instructions

### 1. Confirm

Prompt:

> *"This will reset your tutor profile (`~/.no-vibe/NO-VIBE.md`) and this project's notes (`.no-vibe/NO-VIBE.md`) to defaults. Both will be archived to their `memory/` folders. Continue? (y/N)"*

Anything other than `y` / `yes` → cancel, no changes.

### 2. Archive non-empty files

```bash
ts=$(date -u +%Y-%m-%dT%H-%M-%S)

if [ -s ~/.no-vibe/NO-VIBE.md ]; then
    mkdir -p ~/.no-vibe/memory
    mv ~/.no-vibe/NO-VIBE.md ~/.no-vibe/memory/NO-VIBE-$ts.md
fi

if [ -s .no-vibe/NO-VIBE.md ]; then
    mkdir -p .no-vibe/memory
    mv .no-vibe/NO-VIBE.md .no-vibe/memory/NO-VIBE-$ts.md
fi
```

### 3. Recreate from templates

Copy `shared/templates/NO-VIBE.global.md` → `~/.no-vibe/NO-VIBE.md`. Copy `shared/templates/NO-VIBE.project.md` → `.no-vibe/NO-VIBE.md`.

### 4. Acknowledge

One line in chat naming what was archived (or skipped if empty).

## Notes

- AI may consult `memory/` files later if the user references prior context the current empty NO-VIBE.md doesn't cover.
- For full erasure (memory/ included), use `/no-vibe-clear` instead.