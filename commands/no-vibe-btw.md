---
description: One-shot escape hatch — let AI write code to project files for a single task, then restore no-vibe mode
argument-hint: <task>
---

# /no-vibe-btw

One-shot escape from no-vibe mode. AI writes code to project files for a single task, then restores the no-vibe marker if it was active.

Use when you hit something tedious or boilerplate you'd rather not type yourself, but want to keep learning-mode on for the rest of the session.

## Arguments

`$ARGUMENTS` — the task description. Required.

Examples:
- `/no-vibe-btw add a .gitignore for node`
- `/no-vibe-btw scaffold a Makefile with build/test/clean targets`
- `/no-vibe-btw fix the typo in README.md line 42`

## Instructions for Claude

### 1. Validate arguments

If `$ARGUMENTS` is empty, stop and tell the user: `/no-vibe-btw requires a task description. Example: /no-vibe-btw add a .gitignore for node`.

### 2. Snapshot marker state

```bash
was_active=0
[ -f .no-vibe/active ] && was_active=1
```

### 3. Disable the hook for this task

```bash
rm -f .no-vibe/active
```

This lets Edit/Write/NotebookEdit/MultiEdit succeed on project files.

### 4. Execute the task

Do exactly what `$ARGUMENTS` asks — nothing more. Scope rules:

- One task only. No scope creep, no "while I'm here" cleanup.
- No refactors of untouched code.
- No new abstractions beyond what the task requires.
- If the task is ambiguous or huge (e.g. "build the whole app"), stop and ask the user to narrow it before writing anything.

### 5. Restore the marker

Always restore, even if the task failed:

```bash
if [ "$was_active" = "1" ]; then
    mkdir -p .no-vibe && touch .no-vibe/active
fi
```

### 6. Report

One short summary: what changed (files + one-line rationale). No trailing narration. If no-vibe was active before, remind the user it's back on.

## Hard rules

- Single task. One-shot. No persistent mode.
- Always restore `.no-vibe/active` if it was set — even on error. Use `trap` or explicit cleanup.
- Do not touch `.no-vibe/` contents (sessions, notes, profile) unless the task is explicitly about them.
- If the user wants to turn no-vibe off entirely, they should use `/no-vibe off` instead.
