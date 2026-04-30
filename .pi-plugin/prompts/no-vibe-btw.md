---
description: One-shot escape hatch — let AI write project files for a single scoped task, then restore no-vibe
argument-hint: "<scoped task description>"
---

Invoke the `no-vibe-btw` skill (one-shot escape hatch) with the user's task.

**Scoped task:** $ARGUMENTS

Procedure:
1. Confirm the `.no-vibe/active` marker currently exists. If not, refuse — there's nothing to "escape from".
2. Confirm the user's scoped task in one sentence; ask for clarification if the scope is unclear.
3. Temporarily move `.no-vibe/active` aside (e.g. to `.no-vibe/.active.suspended`).
4. Execute the single task — limited strictly to what the user described.
5. Restore the `.no-vibe/active` marker.
6. Summarize what was changed and which files were touched.

Never expand scope beyond the user's task. If you discover the scope is larger than expected, stop and ask before continuing.
