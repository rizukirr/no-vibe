# Project canvas

This file is the AI's working notes for *this* project — teaching format,
conventions, and notes specific to this codebase. The user (and you, when
justified) may freely edit any section below to improve the user's learning
experience. NOT for lesson state — that lives in `.no-vibe/session.md`.

## Format

For each layer, structure the chat reply as:

```
**<title>** — short description and the goal of this layer.

Where: <file path>:<line number or anchor — e.g. "inside fn handle_request, after the let mut buf line">

For replacements or deletions, quote the existing code first so the user
can locate it unambiguously, then show the new code.

<code block with the change>

One-sentence why this code is shaped this way.

Run: <command> → expected: <one-line output signature>
```

Multi-block layers (e.g., one change in two files): repeat the
Where/code/why pattern per block. One run command per layer at the end.
Never dump all blocks first and explain after — the explanation lives
next to the block it's about.

## Conventions

<!-- AI: durable conventions specific to this project go here. Examples:
     naming patterns the user has chosen, file layout decisions, library
     choices the user has committed to, idioms the user prefers in this
     stack. NOT lesson state — that lives in session.md. -->

## Notes

<!-- AI: anything the next session should pick up on but doesn't fit the
     two sections above. Stay terse — one line per note. Apply the same
     "would still apply tomorrow" cadence rule as the global file. -->

