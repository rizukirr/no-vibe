# Project canvas

This file is the AI's working notes for *this* project — teaching format,
conventions, and notes specific to this codebase. The user (and you, when
justified) may freely edit any section below to improve the user's learning
experience. NOT for lesson state — that lives in `.no-vibe/session.md`.

## Format

This describes a *pattern of prose*, not literal section headings. Write
each layer's reply as flowing text that contains these elements in order.
Do **not** turn the elements into labeled sections like "Show code" or
"Explain code" — only `Where:` and `Run:` are meant to appear as literal
labels (they're locator anchors).

The elements, in order:

1. A bold one-line title plus a sentence stating what this layer adds and why it's the next step.
2. A `Where:` line giving the file + line number or unambiguous anchor (e.g. `Where: src/cursor.c:42, after the cursor_init() declaration`).
3. The code block. For replacements or deletions, quote the existing code first so the user can find it, then show the new version.
4. One sentence on *why* this code is shaped this way — the code already shows *what*, so don't restate it.
5. A `Run:` line with the command and a one-line expected output signature.

### Concrete example (this is how the layer should look in chat)

> **Add the blink timer.** Cursor blink needs a 500 ms tick before we wire the toggle in the next layer.
>
> Where: `src/cursor.c:42`, immediately after the existing `cursor_init()` declaration.
>
> ```c
> static struct timer_t blink_timer;
> timer_init(&blink_timer, 500);
> ```
>
> A static timer keeps the blink state local to this file — exposing it would let other modules accidentally restart the blink mid-frame.
>
> Run: `make && ./build/cursor_demo` → expected: compiles cleanly, no visible change yet.

Note how the example weaves the elements as prose. There is no "Show code" heading, no "Explain code" heading — just one bold title at the top, then text, then code, then text, then a `Run:` line.

Multi-block layers (e.g., a change in two files): repeat the title/Where/code/why pattern per block, then **one** `Run:` line at the end. Never dump all blocks first and explain after — the explanation lives next to the block it's about.

## Conventions

<!-- AI: durable conventions specific to this project go here. Examples:
     naming patterns the user has chosen, file layout decisions, library
     choices the user has committed to, idioms the user prefers in this
     stack. NOT lesson state — that lives in session.md. -->

## Notes

<!-- AI: anything the next session should pick up on but doesn't fit the
     two sections above. Stay terse — one line per note. Apply the same
     "would still apply tomorrow" cadence rule as the global file. -->

