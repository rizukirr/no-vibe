# no-vibe

Turn your AI assistant into a tutor. It plans, shows code, and reviews — but **you type every line**. Keep the muscle memory; lose the dependency.

Pair with [vibekit](https://github.com/rizukirr/vibekit): vibekit when you want speed, no-vibe when you want to learn.

## Why no-vibe

Vibe-coding produces output without producing understanding. no-vibe inverts that contract:

- **You write every line of project code.** AI refuses to. Hard-guarded by hooks across all five surfaces.
- **You learn from the project you're actually building** — not contrived exercises. Real code, real bugs, real decisions in your repo.
- **AI is a Socratic guide, not a generator.** It asks, hints, reviews, and explains *when you're ready to integrate the explanation*.
- **Bottom-up and incremental.** Six phases, small layers; your diff is the proof of progress.

If you want speed, use vibekit. If you want to be a better engineer at the end of *this* project, stay here.

## How it works

- **Top-down, one layer at a time.** Minimal runnable skeleton first; each layer runs and shows output before the next.
- **Where → code → why → run + verify.** Each step says exactly which file and line, then what runs and what should print.
- **Real code, not hallucinations.** Attach `--ref <url>` and the AI quotes actual source with `file:line` citations.
- **Adapts to you.** The AI keeps a `PROFILE.md` (global, stable identity) and a `SUMMARY.md` (per-project, running journey) it writes itself — observed strengths, known gaps, style notes, current focus, open questions. You can edit either, or layer explicit overrides via `user/*.md`.
- **Your files stay yours.** Hard write-guards on Claude Code, OpenCode, and Pi block writes (file *and* Bash) outside `.no-vibe/**`. Codex/Gemini enforce the same rule via instruction.

## How adaptation works

no-vibe uses a four-layer stack, split by *write cadence* and *scope*:

| Layer | Owner | What lives in it |
|---|---|---|
| **Default teaching style** | **Plugin** — defined in `skills/no-vibe/SKILL.md` | Plain words first, concrete-before-abstract, hint-before-answer, run + verify after every layer. The floor. |
| `~/.no-vibe/PROFILE.md` (global, stable identity) | **AI** — created on first `/no-vibe`, rewritten *rarely* when cross-project identity / style shifts | Identity & expertise, learning style, observed strengths, known gaps |
| `.no-vibe/SUMMARY.md` (project, running journey) | **AI** — created at the first layer close worth recording, rewritten *often* (every closed layer is a candidate) | Current Focus, Accomplishments, Open Questions in *this* project |
| `~/.no-vibe/user/*.md` and `.no-vibe/user/*.md` | **You** — AI never creates, edits, or deletes anything inside | Explicit overrides: instructions you want the AI to follow without inferring them |

**Why the split.** Stable identity (the things that wouldn't change if you opened a different project tomorrow) and running journey (the things that only make sense inside *this* project) update on totally different cadences. Keeping them in one file forces the AI to decide on every rewrite whether *this* fact is stable or transient — and gets it wrong. PROFILE only holds cross-project-durable facts; SUMMARY only holds project-bound state.

**PROFILE.md is the AI's global progression file.** On your first `/no-vibe` activation, the AI creates it with empty section headings (Identity & expertise, Learning style, Observed strengths, Known gaps). It's rewritten only when something durable about how you learn shifts — most layers produce no PROFILE update.

**SUMMARY.md is the AI's per-project journey file.** It's not seeded on activation — the AI creates it the first time a layer close produces an outcome worth recording, then keeps it tight by pruning resolved Open Questions and old Accomplishments. The most valuable section is `Open Questions` — things you dodged with a workaround or didn't fully integrate, surfaced so the next session can revisit them.

**The silent-default + NO_CHANGE rule.** Both files follow two disciplines: *most layer-closes produce no write* (silent default), and *the AI never rewrites a file with content equivalent to what's already there* (NO_CHANGE). A no-op write is treated as a bug. Read either file any time to see what the AI has learned; edit them yourself if something looks wrong.

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
