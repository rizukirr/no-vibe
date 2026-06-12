# no-vibe

Turn your AI assistant into a tutor. It plans, hints, reviews and adapts while **you** write every line.

- **Is:** a guide that works beside your real project in your editor
- **Is not:** a chat only window you ask for answers
- **Needs:** a project open and an editor where you type the code

> Pair with [vibekit](https://github.com/rizukirr/vibekit): vibekit when you want speed, no-vibe when you want to learn.

## Why no-vibe

Vibe-coding produces output without producing understanding and *copy-typing what the AI shows you* produces the same hollow result one keystroke at a time. The thing that actually transfers is the **thought process** and **manual code writing**: deciding what to do, predicting what will happen and naming what broke, no-vibe is built so you contribute that, not just keystrokes.

- **You write every line of project code.** AI refuses to. Hard-guarded by hooks across all five surfaces.
- **You think before you type.** Guided write is the default — AI walks you toward the code in English with graded hints (`hint` / `analogy` / `pseudo` / `show` / `less`), so the code you write comes from a decision you made, not a block you transcribed.
- **You predict before you run.** Every layer ends with a one-question prediction gate: name the edge case, the failing branch, or the intermediate value *before* the program runs. The run becomes a self-test, not passive verification.
- **AI is a Socratic guide, not a generator.** It asks, hints, reviews, and explains *when you're ready to integrate the explanation*.
- **You learn from the project you're actually building** — not contrived exercises. Real code, real bugs, real decisions in your repo. Bottom-up and incremental: six phases, small layers, your diff is the proof of progress.

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
| `~/.no-vibe/PROFILE.md` (global, stable identity) | **AI** — created on first `/no-vibe`, rewritten *rarely* when cross-project identity / style shifts | Identity & expertise, learning style, disclosure mode, observed strengths, known gaps |
| `.no-vibe/SUMMARY.md` (project, running journey) | **AI** — created at the first layer close worth recording, rewritten *often* (every closed layer is a candidate) | Current Focus, Accomplishments, Open Questions in *this* project |
| `~/.no-vibe/user/*.md` and `.no-vibe/user/*.md` | **You** — AI never creates, edits, or deletes anything inside | Explicit overrides: instructions you want the AI to follow without inferring them |

**Why the split.** Stable identity (the things that wouldn't change if you opened a different project tomorrow) and running journey (the things that only make sense inside *this* project) update on totally different cadences. Keeping them in one file forces the AI to decide on every rewrite whether *this* fact is stable or transient — and gets it wrong. PROFILE only holds cross-project-durable facts; SUMMARY only holds project-bound state.

**PROFILE.md is the AI's global progression file.** On your first `/no-vibe` activation, the AI creates it with empty section headings (Identity & expertise, Learning style, Disclosure mode, Observed strengths, Known gaps). It's rewritten only when something durable about how you learn shifts — most layers produce no PROFILE update.

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

### Codex

```bash
codex plugin marketplace add rizukirr/no-vibe
codex plugin add no-vibe --marketplace no-vibe
```

(Requires a Codex CLI build with plugin marketplace support. For older Codex builds, see `INSTALL.codex.md` for the manual symlink path — skills only, soft block.)

### Pi

```bash
pi install npm:no-vibe
```

Or pin to git: `pi install git:github.com/rizukirr/no-vibe`. See `INSTALL.pi.md` for verification steps.

### Gemini CLI

```bash
gemini extensions install https://github.com/rizukirr/no-vibe
```

Pin a version with `--ref=v2.0.3`. See `INSTALL.gemini.md` for the legacy manual-symlink path.

### OpenCode

Add to `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["no-vibe"]
}
```

OpenCode has no `plugin install` CLI, so commands also need to be fetched once:

```bash
mkdir -p ~/.config/opencode/commands
for c in no-vibe no-vibe-challenge no-vibe-btw; do
  curl -fsSL "https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/.opencode/commands/$c.md" \
    -o "$HOME/.config/opencode/commands/$c.md"
done
```

See `INSTALL.opencode.md` for verification steps and the cache-refresh tip.

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
| `/no-vibe --mode concept\|skill\|debug <topic>` | set voice mode |
| `/no-vibe-btw <task>` | one-shot escape hatch — AI may write for this task only |
| `/no-vibe-challenge [<focus>]` | get a coding challenge |

Flags combine: `/no-vibe --ref pytorch --mode concept how does autograd work`.

## Voice modes

| Mode | Best for | Style |
|------|----------|-------|
| **concept** (default) | "teach me how X works" | more prose, deeper check-ins |
| **skill** | "I want to practice writing Y" | muscle-memory repetition |
| **debug** | "why does Z behave like this" | start from symptom, descend |

Voice modes control *how AI talks*. A separate axis, **disclosure modes** (guided write vs. showcase), controls *how much AI reveals before the user writes code in a Phase 3 layer* — guided is the default and walks the user toward the code with English + graded hints on request; showcase shows the full code block upfront. Both default to running a one-question **prediction gate** before the user runs the code each layer, so the run becomes a self-test rather than passive verification. See `skills/no-vibe/SKILL.md` for the full disclosure-mode contract and the help verbs (`hint` / `analogy` / `pseudo` / `show` / `less`).

## Platform support

| Feature | Claude Code | OpenCode | Pi | Codex | Gemini CLI |
|---|:-:|:-:|:-:|:-:|:-:|
| File-write guard (hook) | ✓ | ✓ | ✓ | ✓ * | soft |
| Bash-write guard (hook) | ✓ | ✓ | ✓ | ✓ * | soft |
| Status + resume hint | ✓ | ✓ | ✓ | ✓ * | soft |
| Commands | ✓ | ✓ | ✓ | ✓ | ✓ |
| PROFILE.md + SUMMARY.md + user/ overrides | ✓ | ✓ | ✓ | ✓ | ✓ |

\* Codex hooks fire under the marketplace install (`codex plugin add no-vibe --marketplace no-vibe`). The legacy manual-symlink install path is soft-only.

"soft" = instruction-enforced (no hook surface available); the rule still binds.

## License

MIT. Issues and PRs welcome at [github.com/rizukirr/no-vibe/issues](https://github.com/rizukirr/no-vibe/issues).
