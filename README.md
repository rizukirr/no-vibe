# no-vibe

Turn your AI assistant into a personal tutor that empowers you to write the code yourself. AI shows what to build and explains the *why* while reviewing your work. Adapts to your style across sessions, never touches your project files. Keep the muscle memory, lose the dependency.

## Why

We've all felt it: the more we vibe-code, the more our skills slip away. This plugin stops the drain. AI plans and reviews every step; you type every character. Productivity of AI with the growth of manual coding.

Pair with [vibekit](https://github.com/rizukirr/vibekit) — vibekit for fast builds, no-vibe for tutored manual coding.

## How it works

- **Top-down, one layer at a time.** Minimal runnable skeleton first; each layer runs and shows output before the next.
- **Show the why.** Each step says where the code goes, what it does, and what the next run should print.
- **Real code, not hallucinations.** Attach `--ref <url>` and AI quotes actual source with `file:line` citations.
- **Adapts to you.** Two NO-VIBE.md files learn your style and project state. AI adjusts framing based on what's worked.
- **Your files stay yours.** Hard write-guards on Claude Code, OpenCode, and Pi block all writes (file *and* Bash) outside `.no-vibe/`. Codex/Gemini enforce via instruction.

State is local: project-level `.no-vibe/`, global `~/.no-vibe/`.

## Quick start

### Claude Code (recommended)

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Restart Claude Code.

### Other runtimes — install scripts

Clone the repo and run the installer for your CLI:

```bash
git clone https://github.com/rizukirr/no-vibe.git
cd no-vibe

# Auto-detect installed CLIs and prompt:
./install/install.sh

# Or pick one explicitly:
./install/install-opencode.sh
./install/install-pi.sh
./install/install-codex.sh   # installs into the current project
./install/install-gemini.sh
./install/install-claude.sh  # offline / manual fallback for Claude
```

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
| `/no-vibe-forget` | reset both NO-VIBE.md files (archives prior versions to `memory/`) |
| `/no-vibe-clear` | wipe all no-vibe state — strong confirmation required |

Flags combine: `/no-vibe --ref pytorch --mode concept how does autograd work`.

## Modes

| Mode | Best for | Style |
|------|----------|-------|
| **concept** (default) | "teach me how X works" | more prose, deeper check-ins |
| **skill** | "I want to practice writing Y" | muscle-memory repetition |
| **debug** | "why does Z behave like this" | start from symptom, descend |

## Adaptation — the two NO-VIBE.md files

- **`~/.no-vibe/NO-VIBE.md`** — your global tutor profile. Each line is a deviation from the default Feynman teaching style (12-year-old framing, plain words, one idea per turn, etc.). Edit it directly to set your preferences, or let AI add lines as it observes patterns across 2+ sessions.
- **`.no-vibe/NO-VIBE.md`** — per-project canvas. AI's working notes about *this* codebase: what's built, what mental model you've earned here, what conventions we agreed on, what to pick up next.

Both are plain Markdown. Open and edit any time. AI announces in chat when it updates either file.

## Platform support

| Feature | Claude Code | OpenCode | Pi | Codex | Gemini CLI |
|---|:-:|:-:|:-:|:-:|:-:|
| File-write guard (hook) | ✓ | ✓ | ✓ | soft | soft |
| Bash-write guard (hook) | ✓ | ✓ | ✓ | soft | soft |
| Status + resume hint | ✓ | ✓ | ✓ | soft | soft |
| Commands | ✓ | ✓ | ✓ | ✓ | ✓ |
| Skill | ✓ | ✓ | ✓ | ✓ | ✓ |

"soft" = instruction-enforced (no hook surface available); the rule still binds.

## Contributing

Issues and PRs welcome at [issues](https://github.com/rizukirr/no-vibe/issues).

## License

MIT
