# no-vibe

Turn your AI assistant into a teacher. It finds your level, plans what you will learn and shows you code in chat, and **you** type every line into your project.

## Why no-vibe

Vibe-coding produces output without producing understanding. What transfers is the thinking and the typing: deciding what you want, reading code until it makes sense, and writing it with your own hands until the patterns stick.

While no-vibe is on, the agent refuses to write your project files. A hook blocks file tools and shell writes on every supported runtime. The agent teaches in chat, and you type the code.

## How it works

In an existing project, the agent first reads it: stack and exact versions, layout, conventions, what already works and what is in progress. It saves a short summary to `.no-vibe/project.md`, confirms it with you, and reuses it for later topics. The questions, goal options and syllabus then fit your project, and nothing it teaches asks you to break what already works. With no project, or a topic unrelated to it, it skips this.

A lesson is a book. Your goal is the book's goal, chapters lead to it one step at a time, and sections lead to each chapter's goal. Every reply starts with a header that names the current step, chapter, section and exercise.

1. Level. The agent asks multiple-choice questions whose options are concrete statements about the topic, such as "I can write small programs but fight the borrow checker". Every question ends with an option to answer in your own words. It stops once it knows where to start, which terms you already know and how you like to learn.
2. Goal. It offers concrete outcomes of different scope, in words you understand, and narrows them down with you until the goal fits in one sentence you confirm. In a project, the goal can be building something real in it.
3. Syllabus. It writes `.no-vibe/syllabus.md`, one line per chapter with a title and what you can do at its end, and revises it until you approve.
4. Chapters. Each chapter starts with its goal. The agent plans one section at a time, says its goal, teaches it briefly, and gives at least 3 exercises with the full code shown, which you type and run in a practice folder you choose once. From how you do, it picks the next section: more practice, another explanation, or the next step.
5. Build. For a project goal, the last chapters are build chapters in your project. The agent reads the code the feature touches, reuses what exists, follows the project's style, and shows each piece for you to type into your own files.
6. Check. Each chapter ends with a check on its core ideas, such as finding a bug, predicting output or fixing broken code. The agent re-explains what you miss until you get it, then asks whether anything is still unclear.

Later sections and chapters reuse earlier material, so you repeat it without a separate recap.

`.no-vibe/syllabus.md` holds the book: your level, the goal, the chapters with a checkbox each, where you are, and the agent's notes on each section. Run `/no-vibe on` in a later session and the agent resumes from it.

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

Plugin hooks must be trusted once before they run. Codex asks on first use. Requires a Codex CLI build with plugin marketplace support. See `INSTALL.codex.md` for verification steps.

### Pi

```bash
pi install npm:no-vibe
```

Or pin to git: `pi install git:github.com/rizukirr/no-vibe`. See `INSTALL.pi.md` for verification steps.

### Antigravity

```bash
agy plugin install https://github.com/rizukirr/no-vibe
```

Verify with `agy plugin list`.

### opencode

Requires opencode v2 and `bash` on PATH. Add the package to the `plugin` array in `opencode.json`:

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

Run `opencode reload`. See `.opencode/INSTALL.md` for verification steps.

### Your first lesson

```
/no-vibe build a linear layer like pytorch's
```

Codex uses `$` instead of `/`.

## Commands

<!-- no-vibe:generated:commands -->
| Command | Effect |
|---|---|
| `/no-vibe [on\|off\|<topic>]` | Learning mode. Use ONLY when `.no-vibe/active` exists at the project root or the user invoked `/no-vibe`. The agent teaches in chat and never writes project files. Every reply starts with the header `[no-vibe] Step: <context\|level\|goal\|syllabus\|learn\|exercise\|check> · Chapter: <n/total\|-> · Section: <k\|-> · Exercise: <k\|->`. |
| `/no-vibe-btw <task>` | One-shot escape hatch to temporarily disable no-vibe write guard for a single scoped task, then restore the marker. |
| `/no-vibe-challenge [focus]` | One coding challenge built from the current syllabus or the project. The user writes all the code. The agent gives the task, hints when asked, and reviews when asked. |
<!-- /no-vibe:generated -->

## Platform support

| Feature | Claude Code | Codex | opencode | Pi | Antigravity |
|---|:-:|:-:|:-:|:-:|:-:|
| Write guard | hook | hook | plugin | extension | hook |
| Status and resume line | hook | hook | plugin | extension | `rules/AGENTS.md` |
| Commands | yes | yes | yes | yes | yes |

Every runtime runs the same guard scripts, `hooks/block-writes.sh` and `hooks/block-bash-writes.sh`. Antigravity has no session-start event, so its always-on rule file tells the agent to check for `.no-vibe/active` and resume the syllabus.

These runtimes were checked live:

- Codex (codex-cli 0.163.0): marketplace discovery confirmed. An earlier probe confirmed that the PreToolUse hook blocks writes with exit 2, that SessionStart injects the status line, and that plugin hooks must be trusted once.
- opencode (2.0.32): the plugin loaded and injected the skill and the status line. The guard was not exercised live and is covered by `tests/test_guard_parity.mjs`. The slash command listing was not confirmed live.
- Pi (1.3.0): the guard blocked a live `write` tool call.

Claude Code was not checked in a live session. Its guard and status hooks are covered by the shell tests and by `tests/test_manifests.mjs`, which runs them through `run-hook.cmd`. Antigravity was not run live and is covered by `tests/test_guard_parity.mjs` only.

## What the guard covers

The guard checks each file write and each shell command before it runs, and refuses writes outside `.no-vibe/` (the shell guard also allows `/tmp`). It catches the ways an agent usually writes files when it slips. It is not a sandbox. The shell guard reads command text with patterns, so some shell gets past it: a variable inside a path, `>|` or `>&` redirects, a second `cp`, `tee` or `sed -i` in one command, a quoted space in a path, writes through `/dev/fd`, a symlink created and used in the same command, and scripts or build tools that write files themselves. no-vibe relies on the agent following the skill, and the guard catches it when it slips.

## License

MIT. Issues and PRs welcome at [github.com/rizukirr/no-vibe/issues](https://github.com/rizukirr/no-vibe/issues).
