---
description: Generate a coding challenge based on the current no-vibe session or project context
argument-hint: "[difficulty: easy|medium|hard] [topic]"
---

Invoke the `no-vibe-challenge` skill.

**User arguments:** $ARGUMENTS

Procedure:
1. Read the current `.no-vibe/active` session (if any) plus the adaptation stack — `~/.no-vibe/PROFILE.md`, `.no-vibe/SUMMARY.md`, and every `*.md` under `~/.no-vibe/user/` and `.no-vibe/user/` (sorted by filename) — to calibrate difficulty. PROFILE flags competence and gaps; SUMMARY flags open questions and recent accomplishments to build on or reinforce.
2. If no session exists, infer a topic from the current project context (`README.md`, top-level source files, `package.json`/`Cargo.toml`/etc.).
3. Produce a single, scoped challenge: constraint statement, success criteria, and 2-3 hint ladders.
4. Do **not** write the solution. Do **not** write any project files. The user writes the code; you give constraints, hints, and review afterward.
5. After the user submits, review their solution: correctness, idiom, edge cases, and a single highest-value follow-up.
