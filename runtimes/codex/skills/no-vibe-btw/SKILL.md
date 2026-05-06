---
name: no-vibe-btw
description: One-shot escape hatch to write code for a single scoped task, then restore no-vibe marker.
---

# no-vibe-btw

When invoked:

1. Require a task description. If missing, ask for it and stop.
2. Capture whether `.no-vibe/active` exists.
3. Remove `.no-vibe/active`.
4. Execute only the requested task (no scope creep).
5. Restore `.no-vibe/active` if it was present before.
6. Report changed files briefly.
