# Project canvas

This file is the AI's working notes for *this* project — teaching format,
conventions, and notes specific to this codebase. The user (and you, when
justified) may freely edit any section below to improve the user's learning
experience. NOT for lesson state — that lives in `.no-vibe/session.md`.

## How to teach each layer

You have flexibility in HOW you teach each layer, but the outcomes below
are non-negotiable. The defaults are starting points — replace any clause
that doesn't serve the user's learning experience.

### Outcomes every layer must achieve

1. **Claim stated** — open with a bold one-line title plus a sentence naming what this layer adds and why it's the next step.
2. **Locator anchor** — a literal `Where:` line giving the file + line or unambiguous position. (`Where:` IS meant to appear verbatim — it's a locator, not a heading.)
3. **Evidence shown** — the code, in the form determined by the scaffolding mode below.
4. **Claim closed** — one sentence tying the evidence back to the stated claim. Not "here's why the code is shaped this way" generically — tie it to what the layer promised. (e.g., "We said this layer adds the tick; the static timer is what produces 500 ms intervals that survive across frames.")
5. **Runnable verification** — a literal `Run:` line with the command and a one-line expected output signature.

### Scaffolding modes — pick one per layer based on user expertise

The same teaching turn helps a novice and bores an expert. Match the form
to the learner. Read `~/.no-vibe/NO-VIBE.md` `## User additions` for
stated expertise ("new to async", "solid on Rust"); also watch this
session — quick correct fixes signal expertise, repeated misses signal
scaffolding should go up, not down.

**Worked example** — full code, full why. Use when:
- First layer of the lesson, OR
- Topic the user is new to per NO-VIBE.md, OR
- Last layer had a Block verdict (user struggled).

**Faded** — show ~80% of the code; blank one line with a comment like `// <user fills in: short hint>`; the claim and why stay intact. Use when:
- User has cleared 2+ consecutive layers in this lesson, AND
- Topic is not flagged as new in NO-VIBE.md.

**Problem-only** — describe the goal, constraints, and the anchor; do not show code. The user writes everything; the AI reviews after. Use when:
- NO-VIBE.md flags the topic as solid ("user knows X cold"), OR
- User has cleared 4+ consecutive layers in this lesson with no Block.

When in doubt, scaffold up (worked example). Under-scaffolding produces
silent failure; over-scaffolding just feels slow, and the user can say
"skip ahead."

### Anti-form rules (constant across all modes)

- Do **not** invent labeled subheadings ("Show code", "Explain code", "Description + purpose"). The pattern above is prose with two literal labels (`Where:` and `Run:`); everything else flows as prose.
- Do **not** restate what the code says. The "claim closed" sentence explains the *why*, never the *what*.
- Do **not** dump multiple code blocks then explain at the end. Pair each block with its anchor and closing sentence. One `Run:` line per layer at the end.
- Do **not** silently advance on a Block. If verification doesn't match the expected signature, surface the gap before moving on.

### Concrete example — worked example mode

> **Add the blink timer.** Cursor blink needs a 500 ms tick before we wire the toggle in the next layer.
>
> Where: `src/cursor.c:42`, immediately after the existing `cursor_init()` declaration.
>
> ```c
> static struct timer_t blink_timer;
> timer_init(&blink_timer, 500);
> ```
>
> We said this layer adds the tick; the static timer is what produces a 500 ms interval that survives across frames, and `static` keeps it private so other modules can't restart it mid-frame.
>
> Run: `make && ./build/cursor_demo` → expected: compiles cleanly, no visible change yet.

### Concrete example — faded mode

> **Wire the toggle.** Now make the timer flip the cursor's visible state on every tick.
>
> Where: `src/cursor.c:57`, inside `cursor_render()`, before the existing draw call.
>
> ```c
> if (timer_elapsed(&blink_timer)) {
>     // <user fills in: toggle cursor.visible and reset the timer>
> }
> ```
>
> The toggle has to live behind `timer_elapsed` so we don't flip the cursor every frame — that would be a stutter, not a blink.
>
> Run: `./build/cursor_demo` → expected: cursor visibly blinks at ~2 Hz.

### Concrete example — problem-only mode

> **Add input handling.** The cursor demo currently ignores keypresses. Make `q` exit cleanly and the arrow keys move the cursor by one cell.
>
> Where: `src/cursor.c`, inside the main loop. You'll need a new helper file `src/input.c` for key-reading if you want to keep `cursor.c` focused.
>
> Constraints: use the existing `term_read()` API (see `term.h:14`); no new dependencies; cursor stays inside the screen bounds.
>
> Run: `./build/cursor_demo` → expected: arrow keys move the visible cursor; `q` exits with status 0.

The closing-tied-to-claim convention and the anti-form rules apply
identically across all three modes.

Multi-block layers (e.g., a change in two files): repeat the
title/Where/code/why pattern per block, then **one** `Run:` line at the
end. Never dump all blocks first and explain after — the explanation
lives next to the block it's about.

## Conventions

<!-- AI: durable conventions specific to this project go here. Examples:
     naming patterns the user has chosen, file layout decisions, library
     choices the user has committed to, idioms the user prefers in this
     stack. NOT lesson state — that lives in session.md. -->

## Notes

<!-- AI: anything the next session should pick up on but doesn't fit the
     two sections above. Stay terse — one line per note. Apply the same
     "would still apply tomorrow" cadence rule as the global file. -->

