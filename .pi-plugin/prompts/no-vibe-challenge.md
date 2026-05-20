---
description: Get a coding challenge based on your project or current no-vibe session
argument-hint: "[<focus-area>]"
---

Invoke the `no-vibe-challenge` skill.

**Focus area (optional):** $ARGUMENTS

Steps:

1. Activate no-vibe mode:
   ```
   mkdir -p .no-vibe/notes .no-vibe/refs .no-vibe/data/sessions && touch .no-vibe/active
   ```

2. Determine challenge context:
   - Look for in-progress sessions: `grep -rl '"status": "in_progress"' .no-vibe/data/sessions/ 2>/dev/null`
   - If active session: read the session JSON for topic / layer / mode; generate a challenge that exercises what the user just learned.
   - If no session: analyze the project (stack, patterns, domain) and generate a relevant challenge.
   - If focus area provided: narrow the challenge to that area, combined with session/project context.

3. Read the adaptation stack (`~/.no-vibe/PROFILE.md`, `.no-vibe/SUMMARY.md`, and every `*.md` under `~/.no-vibe/user/` and `.no-vibe/user/` if present). Calibrate:
   - PROFILE.md `## Identity & expertise` / `## Observed strengths` flags competence → tune scope upward.
   - PROFILE.md `## Known gaps` flags weak areas → tune scope downward; more scaffolding.
   - PROFILE.md `## Disclosure mode` sets default disclosure (`guided` vs. `showcase`) and `prediction_gate` for the challenge — honor it unless overridden by `user/*.md`.
   - SUMMARY.md `## Open Questions` flags concepts the user dodged in prior layers → reinforce them in the challenge.
   - SUMMARY.md `## Accomplishments` shows what the user has already built → build on a recent success or revisit a recent Block area.
   - Any `user/*.md` file naming an explicit constraint → respect it without re-asking.

4. Present the challenge in chat:
   > **Challenge: {title}**
   >
   > {1-3 sentence description}
   >
   > **Acceptance criteria:**
   > - {specific, testable}
   > - {specific, testable}
   >
   > **Run command:** `{exact command to test}`
   >
   > Start coding. Ask for review when done, or hints along the way.

   Rules: no code shown; criteria must be observable; 5-20 minute scope.

5. Guide and review:
   - Answer with hints, not solutions.
   - On "review": read the user's code and give feedback.
   - On completion: log the session in `.no-vibe/data/sessions/challenge-<slug>.json` with mode `"skill"`.

6. Deactivate (one-shot): `rm -f .no-vibe/active`

Hard rules: never write code to project files (the Pi extension guard enforces this for `write` / `edit`); hints only; concrete criteria; always calibrate to profile if available.
