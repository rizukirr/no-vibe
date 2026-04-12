# no-vibe

A plugin that turns your AI coding assistant into a tutor. It shows code in chat and reviews what you write — but never touches your project files. You do the typing and learn while getting the project done.

## Why

If you feel like AI is draining your skill, making you forget how to do things and now you just want to actually understand how things work — this plugin is for you.

No-vibe is designed to help you finish your project by your own hands while learning how things work along the way. It's not a classroom — it's a tutor that walks with you through real work.

## How it works

Turn on no-vibe mode and the AI guides you through building code top-down: start with the shape, add one concept at a time, run it at every step. Each layer is grounded in real reference projects when available. A write-guard hook prevents the AI from editing your files — everything goes through chat and into your hands.

## Quick start

### Claude Code

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Then restart Claude Code.

### OpenCode

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

See `.opencode/INSTALL.md` for details.

### Codex

Paste this into Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/rizukirr/no-vibe/refs/heads/main/INSTALL.codex.md
```

### Then

```
/no-vibe build a linear layer like pytorch's
```

## Commands

```
/no-vibe on                                  # persistent mode — stays on across topics
/no-vibe off                                 # exit mode, synthesize current lesson
/no-vibe <topic>                             # one-shot lesson on a topic
/no-vibe --ref <url> <topic>                 # attach a reference project
/no-vibe --mode concept|skill|debug <topic>  # set teaching style
/no-vibe:challenge                           # get a coding challenge
/no-vibe:challenge <focus>                   # challenge with focus area
```

Flags can be combined: `/no-vibe --ref pytorch --mode concept how does autograd work`

## Modes

| Mode | Best for | Style |
|------|----------|-------|
| **concept** | "teach me how X works" | More prose, more "why", deeper check-ins |
| **skill** | "I want to practice writing Y" | "Type this exactly", muscle-memory repetition |
| **debug** | "why does my Z behave like this" | Start from symptom, descend toward root cause |

## Learner tracking

No-vibe remembers how you're doing across sessions. It tracks skill levels per topic, logs mistakes to surface patterns, and adapts future lessons — more scaffolding where you struggle, skipping basics where you're strong. Interrupted sessions auto-resume where you left off.

All data stays local in `.no-vibe/data/`.

## Platform support

| Feature | Claude Code | OpenCode | Codex |
|---------|:-----------:|:--------:|:-----:|
| Write guard (hook) | ✓ | ✓ | ✓ |
| Slash commands | ✓ | ✓ | ✓ |
| Teaching skill | ✓ | ✓ | ✓ |
| Challenge command | ✓ | ✓ | ✓ |
| Learner tracking | ✓ | ✓ | ✓ |

## Contributing

Issues and PRs welcome at [github.com/rizukirr/no-vibe](https://github.com/rizukirr/no-vibe).

## License

MIT
