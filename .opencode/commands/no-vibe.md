---
description: Enter no-vibe mode in OpenCode (tutor mode, no direct project file writes)
argument-hint: [on|off|<topic>] [--ref <name-or-url>] [--mode concept|skill|debug]
---

# /no-vibe

Enter no-vibe mode. The agent teaches in chat, and you write code yourself.

## Arguments

`$ARGUMENTS` may be one of:

- `on` - turn persistent no-vibe mode on (marker stays until `/no-vibe off`)
- `off` - turn persistent no-vibe mode off (synthesize current lesson if any, then remove marker)
- `<topic>` - one-shot lesson on the given topic
- Any of the above plus `--ref <name-or-url>` to attach reference project(s)
- Any of the above plus `--mode {concept|skill|debug}` to set the teaching mode

Examples:
- `/no-vibe build a linear layer like pytorch's`
- `/no-vibe --ref pytorch --mode concept how does autograd work`
- `/no-vibe on`
- `/no-vibe off`

## Instructions for OpenCode

You are entering no-vibe mode. Follow these steps in order.

### 1. Parse `$ARGUMENTS`

Determine which form was invoked:
- If `$ARGUMENTS` is empty or just `on` -> persistent mode on, no topic yet
- If `$ARGUMENTS` is `off` -> persistent mode off
- Otherwise -> one-shot or persistent-with-topic; extract `--ref` and `--mode` flags and the remaining text as the topic

### 2. Manage the marker file

- If turning ON or starting any lesson, you MUST run this exact bash command:

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

Then verify with:

```bash
test -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is active (.no-vibe/active exists)`.

- If turning OFF: if a lesson is mid-flight (check `.no-vibe/session.md` for unchecked items), run Phase 6 synthesis first. **Even if skipping Phase 6**, you MUST update global `~/.no-vibe/profile.json`, rewrite `~/.no-vibe/profile.md`, and update the session JSON with what you observed during the session. Then you MUST run:

```bash
rm -f .no-vibe/active
```

Then verify with:

```bash
test ! -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is off (.no-vibe/active removed)`.

### 3. Clone any `--ref` URLs

For each `--ref <url>` flag:

```bash
name=$(basename "$url" .git)
[ -d ".no-vibe/refs/$name" ] || git clone --depth 1 "$url" ".no-vibe/refs/$name"
```

If `--ref <name>` is a bare name (no `://`, no `/`), use `.no-vibe/refs/$name` as-is and warn if it does not exist.

### 4. Load and follow the no-vibe skill

Use the `skill` tool to load `no-vibe`. Follow the six-phase teaching cycle from `skills/no-vibe/SKILL.md`, starting at Phase 1a (context analysis).

If `$ARGUMENTS` was empty or `on` (no topic), wait for the user's next message as the topic, then begin Phase 1a.

### 5. On lesson completion (one-shot mode only)

After Phase 6 completes, if this was a one-shot invocation (not `/no-vibe on`), you MUST run:

```bash
rm -f .no-vibe/active
```

Then verify with:

```bash
test ! -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is off (.no-vibe/active removed)`.

If persistent mode is on, leave the marker in place until `/no-vibe off`.

## Hard rules

- Never write project files directly; show all code in chat.
- `.no-vibe/**` and `~/.no-vibe/` are the only allowed write areas in active mode.
- Use Read/Grep/Glob/WebFetch for context analysis and reference grounding.
- Preserve the teaching cycle and runnability invariant while active mode is on.
