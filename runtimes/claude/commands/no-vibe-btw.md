---
description: One-shot escape hatch — let AI write code to project files for a single task, then restore no-vibe mode
argument-hint: <task>
# AUTO-GENERATED FROM /shared — DO NOT EDIT — run scripts/sync.sh
---

# /no-vibe-btw

One-shot escape from no-vibe mode. AI writes code to project files for a single task, then restores the marker if it was active.

Use when you hit something tedious or boilerplate you'd rather not type yourself, but want learning-mode back on for the rest of the session.

## Arguments

`$ARGUMENTS` — task description, required.

Examples:
- `/no-vibe-btw add a .gitignore for node`
- `/no-vibe-btw scaffold a Makefile with build/test/clean targets`
- `/no-vibe-btw fix the typo in README.md line 42`

## Instructions

### 1. Validate

If `$ARGUMENTS` is empty: stop and tell the user `/no-vibe-btw requires a task description. Example: /no-vibe-btw add a .gitignore for node`.

### 2. Snapshot marker state

```bash
was_active=0
[ -f .no-vibe/active ] && was_active=1
```

### 3. Disable the hook for this task

```bash
rm -f .no-vibe/active
```

### 4. Execute the task

Do exactly what `$ARGUMENTS` asks — nothing more.

- One task only. No scope creep, no "while I'm here" cleanup.
- No refactors of untouched code.
- No new abstractions beyond what the task requires.
- If ambiguous or huge ("build the whole app"), stop and ask the user to narrow before writing.

### 5. Restore the marker

Always restore, even on failure:

```bash
if [ "$was_active" = "1" ]; then
    mkdir -p .no-vibe && touch .no-vibe/active
fi
```

### 6. Report

One short summary: files changed + one-line rationale. If no-vibe was active, remind the user it's back on.

## Hard rules

- Single task. One-shot. No persistent mode.
- Always restore the marker if it was set — even on error.
- Do not touch `.no-vibe/` contents unless the task is explicitly about them.
- For full exit, use `/no-vibe off` instead.