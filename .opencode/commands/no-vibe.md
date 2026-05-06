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
# NO-VIBE.md seeded from the plugin's templates/ — adjust path if your install differs.
[ -f .no-vibe/NO-VIBE.md ] || cp "$(dirname "$0")/../templates/NO-VIBE.project.md" .no-vibe/NO-VIBE.md 2>/dev/null || true
# Global level
mkdir -p ~/.no-vibe
[ -f ~/.no-vibe/NO-VIBE.md ] || cp "$(dirname "$0")/../templates/NO-VIBE.global.md" ~/.no-vibe/NO-VIBE.md 2>/dev/null || true
```

Then verify with:

```bash
test -f .no-vibe/active
```

If verification succeeds, explicitly state in chat: `no-vibe is active (.no-vibe/active exists)`.

- If turning OFF: if a lesson is mid-flight (check `.no-vibe/session.md` for unchecked items), run Phase 6 synthesis first (which includes conditional NO-VIBE.md updates per the cadence rule). Then you MUST run:

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

## Turn Response Contract (binding for every reply while ON)

While `no-vibe: ON`, every reply MUST begin with this exact one-line header:

```
[no-vibe] Phase: <0|1a|1b|1c|2|3|4|5|6> · Session: <slug-or-none> · Layer: <n/total-or--> · Next: <one short action>
```

Per-turn order:

1. **Read** `~/.no-vibe/NO-VIBE.md` and `.no-vibe/NO-VIBE.md`. The Adaptation Iron Law binds.
2. **Read** `.no-vibe/data/sessions/<current>.json` if a session is active. File of record beats in-context state.
3. **Emit** the header above. First line. No greeting or tool call before it.
4. **Act** for the current phase — chat-only, no project writes (Iron Law).
5. **Update** `sessions/<slug>.json` if any tracked field changed this turn.
6. **Update** project `.no-vibe/NO-VIBE.md` only when the cadence rule fires (would the next session behave better because of this line?). Most turns: no write.

Header rules:
- `Phase:` uses the human form (`1a`, `3`, etc.) — distinct from JSON `current_phase` (`phase1a`..`phase6`). Never cross them.
- `Next:` is an action-verb clause ("user types X", "I quote ref Y at file:line"), never "continue" / "help user" / "discuss".
- One reply = one phase. Cross a phase boundary → stop and let the next turn open the new phase.
- Missed header → emit on the very next reply.

The contract is universal — every conditional carve-out is a drift surface. Full discussion in `skills/no-vibe/SKILL.md`.

## Hard rules

- Never write project files directly; show all code in chat.
- `.no-vibe/**` and `~/.no-vibe/` are the only allowed write areas in active mode.
- Use Read/Grep/Glob/WebFetch for context analysis and reference grounding.
- Preserve the teaching cycle and runnability invariant while active mode is on.
