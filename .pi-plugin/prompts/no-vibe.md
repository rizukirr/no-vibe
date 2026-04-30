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
