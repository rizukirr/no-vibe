---
name: no-vibe-challenge
description: Generate a one-shot coding challenge based on current no-vibe session or project context. User writes all code; AI only gives constraints, hints, and review.
---

# no-vibe-challenge

Generate a hands-on coding challenge. The user writes everything.

## Inputs

Treat text after `$no-vibe-challenge` as an optional focus area.

Examples:
- `$no-vibe-challenge`
- `$no-vibe-challenge error handling`
- `$no-vibe-challenge recursion`

## Workflow

### 1. Activate no-vibe mode

Run:

```bash
mkdir -p .no-vibe/notes .no-vibe/refs .no-vibe/data/sessions && touch .no-vibe/active
```

Verify:

```bash
test -f .no-vibe/active
```

If verified, state: `no-vibe is active (.no-vibe/active exists)`.

### 2. Determine challenge context

Check for in-progress sessions:

```bash
grep -rl '"status": "in_progress"' .no-vibe/data/sessions/ 2>/dev/null
```

- If an active session exists: read session JSON and generate a challenge that reinforces what the user just learned.
- If no active session exists: inspect the project to infer stack/domain and generate a relevant challenge.
- If a focus area was provided: narrow challenge scope to that area while keeping project/session relevance.

### 3. Read the adaptation stack

Read (when present):
- `~/.no-vibe/PROFILE.md` — global progression. The AI's record of how this user learns.
- `.no-vibe/PROFILE.md` — project progression. Domain knowledge in this codebase, recent layer outcomes.
- Every `*.md` under `~/.no-vibe/user/` and `.no-vibe/user/` — user-only overrides; authoritative on conflict, AI never writes here.

Calibrate challenge difficulty:
- PROFILE.md `## Identity & expertise` or `## Observed strengths` flags topic competence ("solid on Go", `(seen 4×)`) → tune scope upward.
- PROFILE.md `## Known gaps` flags weak areas → tune scope downward, more scaffolding.
- `## Recent layer outcomes` — reinforce a recent Block area, or build on a recent Clear.
- Any `user/*.md` file naming an explicit constraint → respect it without re-asking.

### 4. Present the challenge

Use this structure:

> **Challenge: {title}**
>
> {1-3 sentence description}
>
> **Acceptance criteria:**
> - {specific, testable criterion}
> - {specific, testable criterion}
>
> **Run command:** `{exact command to test}`
>
> Ready? Start coding. Ask for hints anytime, or say "review" when done.

Rules:
- No code output for the user to copy.
- Acceptance criteria must be observable/testable.
- Scope should fit 5-20 minutes.

### 5. Guide and review

After presenting:
- Provide hints, not full solutions.
- When user says "review", read their code and provide feedback.
- On completion, log a challenge session to `.no-vibe/data/sessions/challenge-<slug>.json` with mode `"skill"`.

### 6. Deactivate (one-shot)

When challenge flow is finished:

```bash
rm -f .no-vibe/active
```

Verify:

```bash
test ! -f .no-vibe/active
```

If verified, state: `no-vibe is off (.no-vibe/active removed)`.

## Hard rules

- Never write code to project files.
- Challenge must stay in 5-20 minute scope.
- Always calibrate difficulty using learner data when available.
- In active mode, `.no-vibe/**` is the only write-allowed area.
