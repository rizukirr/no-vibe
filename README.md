# no-vibe

Turn your AI assistant into a tutor. It plans, shows code, and reviews — but **you type every line**. Keep the muscle memory; lose the dependency.

Pair with [vibekit](https://github.com/rizukirr/vibekit): vibekit when you want speed, no-vibe when you want to learn.

## How it works

- **Top-down, one layer at a time.** Minimal runnable skeleton first; each layer runs and shows output before the next.
- **Where → code → why → run + verify.** Each step says exactly which file and line, then what runs and what should print.
- **Real code, not hallucinations.** Attach `--ref <url>` and the AI quotes actual source with `file:line` citations.
- **Adapts to you.** The AI keeps a `PROFILE.md` it writes itself — observed strengths, known gaps, style notes that improve over sessions. You can edit it, or layer explicit overrides via `user/*.md`.
- **Your files stay yours.** Hard write-guards on Claude Code, OpenCode, and Pi block writes (file *and* Bash) outside `.no-vibe/**`. Codex/Gemini enforce the same rule via instruction.

## How adaptation works

no-vibe uses a three-layer stack:

| Layer | Owner | What lives in it |
|---|---|---|
| **Default teaching style** | **Plugin** — defined in `skills/no-vibe/SKILL.md` | Plain words first, concrete-before-abstract, hint-before-answer, run + verify after every layer. The floor. |
| `~/.no-vibe/PROFILE.md` and `.no-vibe/PROFILE.md` | **AI** — created on first `/no-vibe`, rewritten per layer when something durable is observed | Identity, expertise, observed strengths, known gaps, style notes, recent layer outcomes |
| `~/.no-vibe/user/*.md` and `.no-vibe/user/*.md` | **You** — AI never creates, edits, or deletes anything inside | Explicit overrides: instructions you want the AI to follow without inferring them |

**PROFILE.md is the AI's progression file.** On your first `/no-vibe` activation, the AI creates it with empty section headings. After each layer, the AI runs a one-line self-check — *"did this layer reveal something that would make next session better?"* — and only rewrites the file when the answer is yes. Most layers produce no write. The schema is fixed (Identity & expertise, Observed strengths, Known gaps, Style notes, Recent layer outcomes); the AI consolidates entries when they pile up so the file stays small. Read it any time to see what the AI has learned about you; edit it yourself if something looks wrong.

**`user/*.md` is your override layer.** Drop any `.md` file into `~/.no-vibe/user/` (global) or `.no-vibe/user/` (project) and the AI loads it sorted by filename. Anything in `user/` wins on conflict with PROFILE.md or the default style. The AI is forbidden from writing to `user/` — when it notices a pattern that belongs there, it shows you the exact line and lets you add it.

Practical examples — anything in this style works in `user/*.md`:

- *"Use Rust analogies when you explain memory or ownership."* → global, applies everywhere
- *"I'm already solid on async/await — skip the basics."* → global, AI stops explaining what you know
- *"This project uses tabs not spaces; don't comment on it."* → project, kills repeated nudges
- *"Always show the failing run before the fix."* → global, changes how reviews happen

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
| PROFILE.md + user/ overrides | ✓ | ✓ | ✓ | ✓ | ✓ |

"soft" = instruction-enforced (no hook surface available); the rule still binds.

## License

MIT. Issues and PRs welcome at [github.com/rizukirr/no-vibe/issues](https://github.com/rizukirr/no-vibe/issues).
