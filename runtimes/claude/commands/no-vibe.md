---
description: Enter no-vibe tutor mode — AI guides you through writing code yourself, never editing your project files
argument-hint: [on|off|<topic>] [--ref <name-or-url>] [--mode concept|skill|debug]
# AUTO-GENERATED FROM /shared — DO NOT EDIT — run scripts/sync.sh
---

# /no-vibe

Enter no-vibe mode. AI does not write code to your project files; it guides you through writing them yourself, layer by layer, optionally grounded in real reference projects.

## Arguments

`$ARGUMENTS`:

- `on` — persistent mode on (marker stays until `/no-vibe off`)
- `off` — persistent mode off (synthesize current lesson if any, then remove marker)
- `<topic>` — one-shot lesson on the given topic
- Plus `--ref <name-or-url>` to attach a reference project
- Plus `--mode {concept|skill|debug}` to set teaching mode

Examples:
- `/no-vibe build a linear layer like pytorch's`
- `/no-vibe --ref pytorch --mode concept how does autograd work`
- `/no-vibe on`
- `/no-vibe off`

## Instructions

### 1. Parse arguments

- Empty or `on` → persistent mode on, no topic yet.
- `off` → persistent mode off.
- Otherwise → one-shot or persistent-with-topic; extract `--ref` / `--mode`.

### 2. Manage the marker

**On / start:**
```bash
mkdir -p .no-vibe/refs .no-vibe/memory && touch .no-vibe/active
mkdir -p ~/.no-vibe/memory
```

**Off:** if a lesson is mid-flight (check `.no-vibe/session.md` for unchecked items), run Phase 6 synthesis first. Apply the four-trigger NO-VIBE.md write rule. Then `rm -f .no-vibe/active`.

### 3. Clone any `--ref`

For each `--ref <url>` flag:
```bash
name=$(basename "$url" .git)
[ -d ".no-vibe/refs/$name" ] || git clone --depth 1 "$url" ".no-vibe/refs/$name"
```

If `--ref <name>` is a bare name, use `.no-vibe/refs/$name` and warn if missing.

### 4. Enter the skill

Load the `no-vibe` skill. Begin Phase 1a (context analysis). If no topic was provided, wait for the user's next message to be the topic.

### 5. On lesson completion (one-shot only)

After Phase 6, if not `/no-vibe on`:
```bash
rm -f .no-vibe/active
```

If persistent mode is on, leave the marker — user continues with new topics until `/no-vibe off`.

## Hard reminders

- The hook refuses Edit/Write/NotebookEdit/MultiEdit/ApplyPatch on paths outside `.no-vibe/` and `~/.no-vibe/`. Don't try.
- Bash is also guarded — see `shared/guard/patterns.json` for the patterns that get blocked.
- Show all code in chat. User types everything.
- Read/Grep/Glob/WebFetch are allowed and encouraged for context analysis and reference grounding.