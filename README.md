# no-vibe

No-vibe turns your AI coding assistant into a tutor that works alongside you on your actual projects. Instead of writing your code for you, it shows you what to write, explains the *why*, and reviews what you type. It learns where you get stuck, adapts to how you learn, and meets you at your level — more scaffolding in areas you're weak, less in areas you already know.

Every line in your codebase is one you wrote yourself. The AI never touches your project files; a built-in guard blocks it from doing so. You keep your skill. You finish your project. And along the way you build a real mental model of how it works.

## Why

Vibe-coding is fast until it isn't. You accept AI-written code you don't fully understand, and a week later you're debugging something you didn't write, extending a design you didn't choose, and reaching for the AI again to explain what you just shipped. The loop is seductive — and it quietly erodes your skill.

No-vibe breaks the loop. The AI can still plan, explain, and review — but the code lands through your fingers. You debug what you wrote. You extend what you understand. You keep shipping, and you keep getting sharper instead of duller.

## How it works

Start no-vibe mode and the AI becomes your tutor for the lesson at hand.

**Top-down, one layer at a time.** You build the minimal runnable skeleton first, then add one concept per step. Every layer runs and shows output — no broken intermediate states, no "just trust me, it'll work later".

**Show the why, not just the what.** Each step tells you exactly where the code goes, what it does, and what the next run should print. If something doesn't work, you write a one-line test that reproduces the problem before the AI proposes a fix.

**Grounded in real code.** When a reference project is attached, the AI quotes actual source with `file:line` citations instead of inventing APIs.

**Adapts to you.** It tracks what you get right, what trips you up, and common mistake patterns across sessions. Weak area? Extra scaffolding. Solid area? Skip ahead. Close mid-lesson? It picks up where you left off.

**Your files stay yours.** A pre-write guard blocks the AI from touching your project. Every change lands through your keyboard.

All learner data stays local in two places: project-level `.no-vibe/data/` and global `~/.no-vibe/`.

## References — learn from real code, not hallucinations

When the AI teaches you how something "usually" works, it's guessing from training data. Guesses drift into invented APIs and plausible-but-wrong patterns. Attach a real reference project and the AI has to ground every example in that project's actual source.

Pass `--ref <url>` (or `--ref <name>` for something you've already cloned):

```
/no-vibe --ref https://github.com/pytorch/pytorch build a Linear layer
```

The AI clones it into `.no-vibe/refs/`, then for each conceptual layer it greps the reference, finds the smallest piece that owns the same responsibility as your current step, and quotes it with a `file:line` citation. If the reference does something *beyond* your current layer (production-grade concerns you haven't reached yet), the AI names what's deliberately out of scope instead of demanding you copy it. If the reference has no equivalent at all, it says so — it won't fabricate a citation.

No ref attached? The AI proposes 2–3 candidates with different pedagogical angles (production-polished, minimal-real, pure-pedagogical) and lets you pick. That way you choose whether your lesson is anchored to battle-tested complexity or a stripped-down teaching implementation — both valid, different tradeoffs.

## Quick start

### Claude Code

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Then restart Claude Code.

### OpenCode

Tell your agent:

```
Fetch and follow instructions from https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/INSTALL.opencode.md
```

Or see `.opencode/INSTALL.md` for the manual setup.

### Codex

Paste this into Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/INSTALL.codex.md
```

### Gemini CLI

Paste this into Gemini CLI:

```
Fetch and follow instructions from https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/INSTALL.gemini.md
```

### Your first lesson

```
/no-vibe build a linear layer like pytorch's
```

Codex equivalent:

```
$no-vibe build a linear layer like pytorch's
```

## Commands

```
/no-vibe on                                  # persistent mode — stays on across topics
/no-vibe off                                 # exit mode, synthesize current lesson
/no-vibe <topic>                             # one-shot lesson on a topic
/no-vibe --ref <url> <topic>                 # attach a reference project
/no-vibe --mode concept|skill|debug <topic>  # set teaching style
/no-vibe-btw <task>                          # one-shot escape hatch for AI-written edits
/no-vibe:challenge                           # get a coding challenge
/no-vibe:challenge <focus>                   # challenge with focus area
```

Flags can be combined: `/no-vibe --ref pytorch --mode concept how does autograd work`

Codex command equivalents:

```
$no-vibe on
$no-vibe off
$no-vibe --ref <url> <topic>
$no-vibe --mode concept|skill|debug <topic>
$no-vibe-btw <task>
$no-vibe-challenge
$no-vibe-challenge <focus>
```

## Modes

| Mode | Best for | Style |
|------|----------|-------|
| **concept** | "teach me how X works" | More prose, more "why", deeper check-ins |
| **skill** | "I want to practice writing Y" | "Type this exactly", muscle-memory repetition |
| **debug** | "why does my Z behave like this" | Start from symptom, descend toward root cause |

## Platform support

| Feature | Claude Code | OpenCode | Codex | Gemini CLI |
|---------|:-----------:|:--------:|:-----:|:----------:|
| Write guard (hook) | ✓ | ✓ | ✗ (soft) | ✗ (soft) |
| Slash/workflow commands | ✓ | ✓ | ✓ | ✓ |
| Teaching skill | ✓ | ✓ | ✓ | ✓ |
| Challenge command | ✓ | ✓ | ✓ | ✓ |
| Learner tracking | ✓ | ✓ | ✓ | ✓ |

Codex and Gemini CLI have no bundled PreToolUse hook in this repo — write guard on those surfaces is instruction-based (soft block).

## Contributing

Issues and PRs welcome at [issues](https://github.com/rizukirr/no-vibe/issues).

## License

MIT
