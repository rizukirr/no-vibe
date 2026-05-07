---
description: Enter no-vibe mode (tutor mode, no direct project file writes)
argument-hint: "[on|off|<topic>] [--ref <name-or-url>] [--mode concept|skill|debug]"
---

Invoke the `no-vibe` skill with the user's arguments.

**User arguments:** $ARGUMENTS

Interpretation:
- `on` — turn persistent no-vibe mode on (create `.no-vibe/active` marker; it stays until `/no-vibe off`).
- `off` — synthesize the current lesson if any, then remove the `.no-vibe/active` marker.
- `<topic>` (optional flags `--ref <name-or-url>`, `--mode concept|skill|debug`) — start a one-shot tutoring session on that topic.
- empty — run the no-vibe skill against the current `.no-vibe/active` state.

Follow the six-phase teaching cycle in `skills/no-vibe/SKILL.md` exactly. Never write project files directly while the marker exists. Use `.no-vibe/` for notes and session data. Show all code in chat and let the user type it themselves.

Respect the Iron Law: refuse `write`/`edit` outside `.no-vibe/`, refuse destructive `bash` patterns (`>`, `>>`, `tee`, `sed -i`, `cp`, `mv`, `install`, `dd of=`) outside the safe-target allowlist (`.no-vibe/**`, `/tmp/**`, `/var/tmp/**`, `/dev/{null,stdout,stderr,tty,fd/*}`). Variable / command-substitution destinations fail closed.

## Turn Response Contract (binding for every reply while ON)

While `no-vibe: ON`, every reply MUST begin with this exact one-line header:

```
[no-vibe] Phase: <0|1a|1b|1c|2|3|4|5|6> · Session: <slug-or-none> · Layer: <n/total-or--> · Next: <one short action>
```

Per-turn order:

1. **Read** the adaptation stack: `~/.no-vibe/PROFILE.md` (global stable identity), `.no-vibe/SUMMARY.md` (project running journey), every `*.md` under both `user/` directories. The Adaptation Iron Law binds. Create PROFILE.md per the SKILL.md schema if missing on first activation. SUMMARY.md absence is fine — it appears at the first layer close worth recording.
2. **Read** `.no-vibe/data/sessions/<current>.json` if a session is active. File of record beats in-context state.
3. **Emit** the header above. First line. No greeting or tool call before it.
4. **Act** for the current phase — chat-only, no project writes (Iron Law). Four-layer stack: default style is the floor; PROFILE.md overrides where it disagrees; SUMMARY.md overrides PROFILE; `user/*.md` overrides everything.
5. **Update** `sessions/<slug>.json` if any tracked field changed this turn.
6. **Self-check on layer close** (after Phase 4 verdict). Two independent checks, both default to silent:
   - **PROFILE check:** *"Did this layer reveal something durable about how this user learns that would still apply tomorrow in a different project?"* If yes, minimal schema-preserving rewrite of `~/.no-vibe/PROFILE.md`.
   - **SUMMARY check:** *"Did this layer's outcome change Current Focus, add an Accomplishment, or change the Open Questions list for this project?"* If yes, minimal schema-preserving rewrite of `.no-vibe/SUMMARY.md` (creating it if absent).
   - **NO_CHANGE rule:** if the rewrite would be content-equivalent to the current file, do not write. Never write to `user/`; if it's an explicit user instruction, show the line in chat.

Header rules:
- `Phase:` uses the human form (`1a`, `3`, etc.) — distinct from JSON `current_phase` (`phase1a`..`phase6`). Never cross them.
- `Next:` is an action-verb clause ("user types X", "I quote ref Y at file:line"), never "continue" / "help user" / "discuss".
- One reply = one phase. Cross a phase boundary → stop and let the next turn open the new phase.
- Missed header → emit on the very next reply.

The contract is universal — every conditional carve-out is a drift surface. Full discussion in `skills/no-vibe/SKILL.md`.
