---
name: no-vibe-btw
description: One-shot escape hatch to temporarily disable no-vibe write guard for a single scoped task, then restore the marker.
---

# no-vibe-btw

Temporarily disable no-vibe for one scoped task, perform the task, then restore no-vibe if it was previously active.

## Inputs

Text after `$no-vibe-btw` is the required task description.

Examples:
- `$no-vibe-btw add a .gitignore for node`
- `$no-vibe-btw scaffold a Makefile with build/test/clean targets`
- `$no-vibe-btw fix typo in README.md line 42`

## Workflow

### 1. Validate task

If task text is missing, stop and tell the user:
`$no-vibe-btw requires a task description. Example: $no-vibe-btw add a .gitignore for node`.

### 2. Snapshot marker state

Run:

```bash
was_active=0
[ -f .no-vibe/active ] && was_active=1
```

### 3. Disable guard for this task

Run:

```bash
rm -f .no-vibe/active
```

Verify:

```bash
test ! -f .no-vibe/active
```

If verified, state: `temporary btw mode active (.no-vibe/active removed)`.

### 4. Execute exactly one task

Do exactly what the task asks, nothing more.

Scope rules:
- One task only; no extra cleanup or opportunistic refactors.
- No abstractions beyond task requirements.
- If task is ambiguous or too broad, ask user to narrow scope before editing.

### 5. Restore marker

Always restore marker if it was active before, even on failure:

```bash
if [ "$was_active" = "1" ]; then
  mkdir -p .no-vibe && touch .no-vibe/active
fi
```

Verify:

```bash
if [ "$was_active" = "1" ]; then
  test -f .no-vibe/active
fi
```

If verified and `was_active=1`, state: `no-vibe is active again (.no-vibe/active restored)`.

### 6. Report

Give one short summary of files changed and why.

## Hard rules

- Single-task, one-shot behavior only.
- Always restore `.no-vibe/active` when it was previously active.
- Do not modify `.no-vibe/` contents unless task explicitly targets them.
- If user wants no-vibe disabled entirely, route to `$no-vibe off`.
