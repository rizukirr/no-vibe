---
name: no-vibe-challenge
description: Generate a scoped coding challenge based on project/session context; user writes all code.
---

# no-vibe-challenge

When invoked:

1. Ensure no-vibe mode is active (`.no-vibe/active`).
2. Derive challenge context from `.no-vibe/session.md`, project files, and optional focus argument.
3. Present a 5-20 minute challenge with concrete acceptance criteria and a run command.
4. Provide hints (not full solutions) while user works.
5. Review user code against criteria when asked.
