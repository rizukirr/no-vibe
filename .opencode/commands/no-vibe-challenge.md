---
description: Get a coding challenge based on your project or current no-vibe session
argument-hint: [<focus-area>]
---

# /no-vibe:challenge

Generate a hands-on coding challenge. You write everything — no AI code in your files.

## Arguments

`$ARGUMENTS` is an optional focus area. Examples:
- `/no-vibe:challenge` — general challenge from project or session context
- `/no-vibe:challenge error handling` — challenge focused on error handling
- `/no-vibe:challenge recursion` — challenge focused on recursion

## Instructions for OpenCode

### 1. Activate no-vibe mode

You MUST run this exact bash command:

```bash
mkdir -p .no-vibe/notes .no-vibe/refs .no-vibe/data/sessions && touch .no-vibe/active
```

Then verify with:

```bash
test -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is active (.no-vibe/active exists)`.

### 2. Determine challenge context

Check for an active no-vibe session:

```bash
grep -rl '"status": "in_progress"' .no-vibe/data/sessions/ 2>/dev/null
```

**If active session found:**
- Read the session JSON to get topic, current layer, mode
- Generate a challenge that exercises what the user just learned
- Example: user just built a tokenizer → "Write a simple expression parser that uses your tokenizer"

**If no active session:**
- Analyze the user's project: Read/Grep key files to understand stack, patterns, domain
- Generate a challenge relevant to the actual codebase
- Example: project has a REST API → "Add a new endpoint with input validation from scratch"

**If `$ARGUMENTS` provided:**
- Use the focus area to narrow the challenge topic
- Combine with session/project context for relevance

### 3. Read learner profile

Read `~/.no-vibe/profile.md` and `.no-vibe/data/mistakes.json` if they exist. Calibrate challenge difficulty:
- `struggling`/`new` → smaller scope, more specific acceptance criteria
- `comfortable`/`strong` → broader scope, less hand-holding
- Recurring mistake categories → design challenge to practice that area

### 4. Present the challenge

Format:

> **Challenge: {title}**
>
> {1-3 sentence description of what to build}
>
> **Acceptance criteria:**
> - {specific, testable criterion}
> - {specific, testable criterion}
> - ...
>
> **Run command:** `{exact command to test}`
>
> Ready? Start coding. Ask me to review when done, or ask for hints along the way.

Rules:
- No code shown. User writes everything.
- Acceptance criteria must be observable (output, behavior, test passing)
- Challenge should take 5-20 minutes depending on difficulty level

### 5. Guide and review

After presenting the challenge:
- Answer questions with hints, not solutions
- When user says "review": use Read to check their code, give feedback
- On completion: log the session in `.no-vibe/data/sessions/challenge-<slug>.json` with mode `"skill"`

### 6. Deactivate (one-shot)

After challenge is complete, you MUST run:

```bash
rm -f .no-vibe/active
```

Then verify with:

```bash
test ! -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is off (.no-vibe/active removed)`.

## Hard rules

- Never write code to project files. Show hints in chat only.
- Challenge must be scoped to 5-20 minutes of work.
- Acceptance criteria must be concrete and testable.
- Always calibrate to learner profile if available.
- `.no-vibe/**` is the only allowed write area in active mode.
