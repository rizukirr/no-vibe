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
  [ -f ~/.no-vibe/profile.md ] || touch ~/.no-vibe/profile.md
  [ -f ~/.no-vibe/profile.archive.md ] || touch ~/.no-vibe/profile.archive.md
  [ -f ~/.no-vibe/.synth-state.json ] || echo '{"last_successful_synth":null,"consecutive_failures":0,"no_change_streak":0,"missing_consumed_marker_streak":0,"strict_audit_active":false,"migration_pending":false,"last_project_synced":null,"pruning_cursor":{}}' > ~/.no-vibe/.synth-state.json
  ```
- If turning OFF: if a lesson is mid-flight (check `.no-vibe/session.md` for unchecked items), run Phase 6 synthesis first. **Even if skipping Phase 6**, you MUST rewrite global `~/.no-vibe/profile.md`, update `~/.no-vibe/.synth-state.json` as needed, and update the session JSON with what you observed during the session. Then `rm -f .no-vibe/active`

### 3. Clone any `--ref` URLs

For each `--ref <url>` flag:
```bash
name=$(basename "$url" .git)
[ -d ".no-vibe/refs/$name" ] || git clone --depth 1 "$url" ".no-vibe/refs/$name"
```

If `--ref <name>` is a bare name (no `://`, no `/`), use `.no-vibe/refs/$name` as-is and warn if it doesn't exist.

### 4. Load and follow the no-vibe skill

Use the Skill tool to load `no-vibe`. Then follow the six-phase teaching cycle defined in `skills/no-vibe/SKILL.md` from Phase 1a (context analysis).

If `$ARGUMENTS` was empty or `on` (no topic), wait for the user's next message to be the topic, then begin Phase 1a.

### 5. On lesson completion (one-shot mode only)

After Phase 6 (synthesize + tease) completes, if this was a one-shot invocation (not `/no-vibe on`), remove the marker:

```bash
rm -f .no-vibe/active
```

If persistent mode is on, leave the marker in place — the user will continue with new topics until `/no-vibe off`.

## Turn Response Contract (binding for every reply while ON)

While `no-vibe: ON`, every reply MUST begin with this exact one-line header:

```
[no-vibe] Phase: <0|1a|1b|1c|2|3|4|5|6> · Session: <slug-or-none> · Layer: <n/total-or--> · Next: <one short action>
```

Per-turn order:

1. **Read** `.no-vibe/data/sessions/<current>.json` if a session is active. File of record beats in-context state.
2. **Run** the pre-turn gap-action audit per `skills/no-vibe/data-logging.md` when `errors_this_session >= 1`.
3. **Emit** the header above. First line. No greeting or tool call before it.
4. **Act** for the current phase — chat-only, no project writes (Iron Law).
5. **Log** per data-logging.md triggers before ending the turn (Phase 4 user error → `mistakes.json`; user correction/feedback/request/complaint/preference → `ai-notes.json`).
6. **Update** `sessions/<slug>.json` if any tracked field changed this turn.

Header rules:
- `Phase:` uses the human form (`1a`, `3`, etc.) — distinct from JSON `current_phase` (`phase1a`..`phase6`). Never cross them.
- `Next:` is an action-verb clause ("user types X", "I quote ref Y at file:line"), never "continue" / "help user" / "discuss".
- One reply = one phase. Cross a phase boundary → stop and let the next turn open the new phase.
- Missed header → emit on the very next reply. Do NOT log to mistakes.json or ai-notes.json.

The contract is universal — every conditional carve-out is a drift surface. Full discussion in `skills/no-vibe/SKILL.md`.

## Hard reminders

- The hook will refuse Edit/Write/NotebookEdit/MultiEdit/ApplyPatch on any path outside `.no-vibe/`. Don't try.
- Bash is not blocked, but you must not use it to write to project files either. The skill explains why.
- Show all code in chat. The user types everything themselves.
- Read/Grep/Glob/WebFetch are all allowed and encouraged for context analysis and reference grounding.
