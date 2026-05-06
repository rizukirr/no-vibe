---
description: Get a coding challenge based on your project or current no-vibe session
argument-hint: [<focus-area>]
# AUTO-GENERATED FROM /shared — DO NOT EDIT — run scripts/sync.sh
---

# /no-vibe-challenge

Generate a hands-on coding challenge. You write everything — no AI code in your files.

## Arguments

`$ARGUMENTS` is an optional focus area.

- `/no-vibe-challenge` — general challenge from project / session context.
- `/no-vibe-challenge error handling` — focused on error handling.

## Instructions

### 1. Activate no-vibe mode

```bash
mkdir -p .no-vibe/refs .no-vibe/memory && touch .no-vibe/active
```

### 2. Determine context

Check `.no-vibe/session.md` for an in-progress curriculum.

- **Active session** → generate a challenge that exercises what the user just learned. (Built a tokenizer → "write a simple expression parser that uses your tokenizer".)
- **No active session** → analyze the project (Read / Grep) for stack, patterns, domain. Generate a challenge relevant to the actual codebase.
- **`$ARGUMENTS` provided** → narrow to that focus area.

### 3. Read NO-VIBE.md

Load `~/.no-vibe/NO-VIBE.md` (style) and `.no-vibe/NO-VIBE.md` (project canvas) if they exist. Calibrate difficulty to the user's known mental-model state in this codebase.

### 4. Present the challenge

```
**Challenge: <title>**

<1–3 sentence description of what to build>

**Acceptance criteria:**
- <specific, observable criterion>
- <specific, observable criterion>

**Run command:** `<exact command to test>`

Ready? Start coding. Ask me to review when done, or for hints along the way.
```

Rules:
- No code shown. User writes everything.
- Acceptance criteria must be observable (output, behavior, test passing).
- Scope: 5–20 minutes of work.

### 5. Guide and review

After presenting:
- Answer questions with hints, not solutions (clause 6 of default style: pointer → rule → worked sub-example → corrected code).
- On "review": Read the user's code, give feedback per Phase 4 verdicts (Clear / Block / Override).

### 6. Deactivate (one-shot)

After completion:
```bash
rm -f .no-vibe/active
```

## Hard rules

- Never write code to project files. Hints in chat only.
- Challenge scoped to 5–20 minutes.
- Acceptance criteria concrete and testable.
- Calibrate to NO-VIBE.md when present.