# no-vibe

Turn your AI assistant into a personal tutor that empowers you to write the code yourself. It shows you what to build and explains the 'why' while reviewing your work. The plugin adapts to your level and improves its teaching based on your learning progress, all without touching your project files. Keep the muscle memory, lose the dependency.

## Why

We’ve all felt it: the more we 'vibe-code', the more our skills slip away. I built this to stop the drain. The AI acts as your mentor—planning and reviewing every step—but you’re the one typing every character. It’s the productivity of AI with the growth of manual coding. Break the dependency loop.

Maximize your workflow by pairing no-vibe with [vibekit](https://github.com/rizukirr/vibekit). Use the vibekit pipeline to build fast, and switch to no-vibe when you want the AI to tutor you through the manual coding process. Stay productive, keep learning

## How it works

- **Top-down, one layer at a time.** Minimal runnable skeleton first; each layer runs and shows output before the next is added.
- **Show the why.** Each step says where the code goes, what it does, and what the next run should print.
- **Real code, not hallucinations.** Attach `--ref <url>` and the AI quotes actual source with `file:line` citations instead of inventing APIs.
- **Adapts to you.** Tracks where you stumble across sessions. Weak area → more scaffolding. Solid area → skip ahead. Closed mid-lesson → resumes.
- **Your files stay yours.** Hard write-guards on Claude Code, OpenCode, and Pi block writes (file *and* Bash) outside `.no-vibe/**`. Codex/Gemini enforce the same rule via instruction.

Learner data is local: project-level `.no-vibe/data/`, global `~/.no-vibe/`.

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
| `/no-vibe:challenge [<focus>]` | get a coding challenge |

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
| Skill + learner tracking | ✓ | ✓ | ✓ | ✓ | ✓ |

"soft" = instruction-enforced (no hook surface available); the rule still binds.

## Contributing

Issues and PRs welcome at [issues](https://github.com/rizukirr/no-vibe/issues).

## License

MIT
