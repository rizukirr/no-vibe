---
description: One-shot escape hatch — let AI write code to project files for a single task, then restore no-vibe mode
argument-hint: <task>
---

# /no-vibe-btw

One-shot escape from no-vibe mode. AI writes code to project files for a single task, then restores the no-vibe marker if it was active.

Use when you hit something tedious or boilerplate you would rather not type yourself, but want learning mode back on for the rest of the session.

## Arguments

`$ARGUMENTS` — the task description. Required.

Examples:
- `/no-vibe-btw add a .gitignore for node`
- `/no-vibe-btw scaffold a Makefile with build/test/clean targets`
- `/no-vibe-btw fix the typo in README.md line 42`

## Instructions for OpenCode

### 1. Validate arguments

If `$ARGUMENTS` is empty, stop and tell the user:
`/no-vibe-btw requires a task description. Example: /no-vibe-btw add a .gitignore for node`.

### 2. Snapshot marker state

You MUST run:

```bash
was_active=0
[ -f .no-vibe/active ] && was_active=1
```

### 3. Disable no-vibe guard for this one task

You MUST run:

```bash
rm -f .no-vibe/active
```

Then verify with:

```bash
test ! -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `temporary btw mode active (.no-vibe/active removed)`.

### 4. Execute the task

Do exactly what `$ARGUMENTS` asks — nothing more.

Scope rules:
- One task only. No scope creep, no "while I am here" cleanup.
- No refactors of untouched code.
- No new abstractions beyond what the task requires.
- If the task is ambiguous or too broad (for example "build the whole app"), stop and ask the user to narrow it before writing anything.

### 5. Restore marker state

Always restore if it was active before, even if the task failed:

```bash
if [ "$was_active" = "1" ]; then
    mkdir -p .no-vibe && touch .no-vibe/active
fi
```

Then verify with:

```bash
if [ "$was_active" = "1" ]; then
    test -f .no-vibe/active
fi
```

If verification succeeds and `was_active=1`, explicitly state in chat: `no-vibe is active again (.no-vibe/active restored)`.

### 6. Report

One short summary: what changed (files + one-line rationale). No trailing narration.

## Hard rules

- Single task only.
- Always restore `.no-vibe/active` if it was set before running this command.
- Do not modify `.no-vibe/` contents unless the task is explicitly about them.
- If the user wants no-vibe disabled entirely, they should use `/no-vibe off` instead.
