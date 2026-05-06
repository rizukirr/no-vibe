# no-vibe

Turn your AI assistant into a tutor. It plans, shows code, and reviews — but **you type every line**. Keep the muscle memory; lose the dependency.

Pair with [vibekit](https://github.com/rizukirr/vibekit): vibekit when you want speed, no-vibe when you want to learn.

## How it works

- **Top-down, one layer at a time.** Minimal runnable skeleton first; each layer runs and shows output before the next.
- **Where → code → why → run + verify.** Each step says exactly which file and line, then what runs and what should print.
- **Real code, not hallucinations.** Attach `--ref <url>` and the AI quotes actual source with `file:line` citations.
- **Adapts to you.** You and the AI co-edit two `NO-VIBE.md` files that capture *how* you want to be taught.
- **Your files stay yours.** Hard write-guards on Claude Code, OpenCode, and Pi block writes (file *and* Bash) outside `.no-vibe/**`. Codex/Gemini enforce the same rule via instruction.

## Customizing how the AI teaches you

no-vibe adapts via two plain-Markdown files. **You can edit either at any time** — the AI re-reads them every turn, so changes take effect immediately. They're seeded with sensible defaults on your first `/no-vibe on`; the defaults are starting points, not gospel.

| File | Scope | What goes in it |
|---|---|---|
| `~/.no-vibe/NO-VIBE.md` | Global — applies in any project | Teaching style: pacing, jargon tolerance, analogies you like, topics you're already solid on |
| `.no-vibe/NO-VIBE.md` | This project only | Format for code blocks, project-specific conventions, notes the next session should pick up |

**Why this matters for learning faster:** the AI's teaching is only as good as the model it has of you. Editing these files directly — instead of waiting for the AI to figure you out — closes the loop in one turn instead of ten. A few examples:

- *"Use Rust analogies when you explain memory or ownership."* → global, applies everywhere
- *"I'm already solid on async/await — skip the basics."* → global, AI stops explaining what you know
- *"This project uses tabs not spaces; don't comment on it."* → project, kills repeated nudges
- *"Always show the failing run before the fix."* → global, changes how reviews happen

If a default clause doesn't fit you, replace it. If something durable comes up mid-session, jot it under `## User additions` (global) or `## Notes` (project). The cadence rule for the AI: write only when *the next session would behave better because of this line*. You can be more liberal — it's your file.

Per-session cycle state (current phase, layer, resume hints) lives separately in `.no-vibe/data/sessions/<slug>.json` — you generally don't touch that.

## Quick start

### Claude Code

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Restart Claude Code.

### OpenCode / Codex / Gemini CLI / Pi

Paste into the relevant CLI:

```
Fetch and follow instructions from https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/INSTALL.opencode.md
```

(Swap `INSTALL.opencode.md` for `INSTALL.codex.md`, `INSTALL.gemini.md`, or `INSTALL.pi.md` as appropriate. Manual install: see each file directly.)

### Your first lesson

```
/no-vibe build a linear layer like pytorch's
```

Codex uses `$` instead of `/`.

## Commands

| Command | Effect |
|---|---|
| `/no-vibe on` / `off` | persistent mode toggle |
| `/no-vibe <topic>` | one-shot lesson |
| `/no-vibe --ref <url> <topic>` | attach a reference project |
| `/no-vibe --mode concept\|skill\|debug <topic>` | set teaching style |
| `/no-vibe-btw <task>` | one-shot escape hatch — AI may write for this task only |
| `/no-vibe-challenge [<focus>]` | get a coding challenge |

Flags combine: `/no-vibe --ref pytorch --mode concept how does autograd work`.

## Modes

| Mode | Best for | Style |
|------|----------|-------|
| **concept** (default) | "teach me how X works" | more prose, deeper check-ins |
| **skill** | "I want to practice writing Y" | muscle-memory repetition |
| **debug** | "why does Z behave like this" | start from symptom, descend |

## Platform support

| Feature | Claude Code | OpenCode | Pi | Codex | Gemini CLI |
|---|:-:|:-:|:-:|:-:|:-:|
| File-write guard (hook) | ✓ | ✓ | ✓ | soft | soft |
| Bash-write guard (hook) | ✓ | ✓ | ✓ | soft | soft |
| Status + resume hint | ✓ | ✓ | ✓ | soft | soft |
| Commands | ✓ | ✓ | ✓ | ✓ | ✓ |
| NO-VIBE.md adaptation | ✓ | ✓ | ✓ | ✓ | ✓ |

"soft" = instruction-enforced (no hook surface available); the rule still binds.

## License

MIT. Issues and PRs welcome at [github.com/rizukirr/no-vibe/issues](https://github.com/rizukirr/no-vibe/issues).
