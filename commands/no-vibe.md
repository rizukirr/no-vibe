---
description: Enter no-vibe mode — AI guides you through writing code yourself, never editing your project files
argument-hint: [on|off|<topic>] [--ref <name-or-url>] [--mode concept|skill|debug]
---

# /no-vibe

Enter no-vibe mode. AI will not write code to your project files; it will guide you through writing the code yourself, top-down from a high-level API to its foundations, optionally grounded in real reference projects.

## Arguments

`$ARGUMENTS` may be one of:

- `on` — turn persistent no-vibe mode on (marker stays until `/no-vibe off`)
- `off` — turn persistent no-vibe mode off (synthesize current lesson if any, then remove marker)
- `<topic>` — one-shot lesson on the given topic
- Any of the above plus `--ref <name-or-url>` to attach reference project(s)
- Any of the above plus `--mode {concept|skill|debug}` to set the teaching mode

Examples:
- `/no-vibe build a linear layer like pytorch's`
- `/no-vibe --ref pytorch --mode concept how does autograd work`
- `/no-vibe on`
- `/no-vibe off`

## Instructions for Claude

You are entering no-vibe mode. Follow these steps in order.

### 1. Parse `$ARGUMENTS`

Determine which form was invoked:
- If `$ARGUMENTS` is empty or just `on` → persistent mode on, no topic yet
- If `$ARGUMENTS` is `off` → persistent mode off
- Otherwise → one-shot or persistent-with-topic; extract `--ref` and `--mode` flags and the remaining text as the topic

### 2. Manage the marker file

- If turning ON or starting any lesson:
  ```bash
  # Project level
  mkdir -p .no-vibe/notes .no-vibe/refs .no-vibe/data/sessions && touch .no-vibe/active
  [ -f .no-vibe/data/mistakes.json ] || echo '[]' > .no-vibe/data/mistakes.json
  [ -f .no-vibe/data/ai-notes.json ] || echo '[]' > .no-vibe/data/ai-notes.json
  # Global level
  mkdir -p ~/.no-vibe
  [ -f ~/.no-vibe/profile.json ] || echo '{"skill_levels":{},"total_sessions":0,"total_layers_completed":0,"common_strengths":[],"common_weaknesses":[],"projects":{},"user_preferences":[],"ai_directives":[],"teaching_gaps":{}}' > ~/.no-vibe/profile.json
  [ -f ~/.no-vibe/profile.md ] || touch ~/.no-vibe/profile.md
  [ -f ~/.no-vibe/mistakes.json ] || echo '[]' > ~/.no-vibe/mistakes.json
  [ -f ~/.no-vibe/ai-notes.json ] || echo '[]' > ~/.no-vibe/ai-notes.json
  ```
- If turning OFF: if a lesson is mid-flight (check `.no-vibe/session.md` for unchecked items), run Phase 6 synthesis first. **Even if skipping Phase 6**, you MUST update global `~/.no-vibe/profile.json`, rewrite `~/.no-vibe/profile.md`, and update the session JSON with what you observed during the session. Then `rm -f .no-vibe/active`

### 3. Clone any `--ref` URLs

For each `--ref <url>` flag:
```bash
name=$(basename "$url" .git)
[ -d ".no-vibe/refs/$name" ] || git clone --depth 1 "$url" ".no-vibe/refs/$name"
```

If `--ref <name>` is a bare name (no `://`, no `/`), use `.no-vibe/refs/$name` as-is and warn if it doesn't exist.

### 4. Load and follow the no-vibe skill

Use the Skill tool to load `no-vibe`. Then follow the six-phase teaching cycle defined in `.claude-plugin/skills/no-vibe/SKILL.md` from Phase 1a (context analysis).

If `$ARGUMENTS` was empty or `on` (no topic), wait for the user's next message to be the topic, then begin Phase 1a.

### 5. On lesson completion (one-shot mode only)

After Phase 6 (synthesize + tease) completes, if this was a one-shot invocation (not `/no-vibe on`), remove the marker:

```bash
rm -f .no-vibe/active
```

If persistent mode is on, leave the marker in place — the user will continue with new topics until `/no-vibe off`.

## Hard reminders

- The hook will refuse Edit/Write/NotebookEdit/MultiEdit on any path outside `.no-vibe/`. Don't try.
- Bash is not blocked, but you must not use it to write to project files either. The skill explains why.
- Show all code in chat. The user types everything themselves.
- Read/Grep/Glob/WebFetch are all allowed and encouraged for context analysis and reference grounding.
