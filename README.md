# no-vibe

A tutor mode for AI coding agents. The agent teaches, and **you** type every line of code.

Works with Claude Code, Codex, opencode, Pi and Antigravity.

## Why

When an AI writes your code, the work gets done but you learn little. You learn by thinking it through and typing it yourself. no-vibe turns your agent into a teacher and stops it from writing your project files.

## A lesson

```
/no-vibe add a linear layer to my model
```

1. If you are in a project, the agent reads it first, so the lesson fits your stack and never breaks what already works.
2. It finds your level with a few multiple-choice questions.
3. It agrees a one-sentence goal with you.
4. It plans chapters you approve, each building on the last.
5. Each chapter is taught one section at a time: a short lesson, then at least 3 exercises with the full code shown for you to type and run.
6. Each chapter ends with a check, such as finding a bug or predicting output, and the agent re-explains what you miss.
7. For a goal in your project, the last chapters guide you to type the real feature into your own code.

Progress is saved in `.no-vibe/`, so `/no-vibe on` picks up where you left off.

## Install

Claude Code, then restart it:

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Codex, which asks you to trust the plugin hooks on first use (see `INSTALL.codex.md`):

```bash
codex plugin marketplace add rizukirr/no-vibe
codex plugin add no-vibe --marketplace no-vibe
```

Pi (see `INSTALL.pi.md`):

```bash
pi install npm:no-vibe
```

Antigravity:

```bash
agy plugin install https://github.com/rizukirr/no-vibe
```

opencode v2, with `bash` on PATH: add the plugin to `opencode.json`, then run `opencode reload` (see `.opencode/INSTALL.md`):

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

## Commands

Codex uses `$` instead of `/`.

<!-- no-vibe:generated:commands -->
| Command | Effect |
|---|---|
| `/no-vibe [on\|off\|<topic>]` | Learning mode. Use ONLY when `.no-vibe/active` exists at the project root or the user invoked `/no-vibe`. The agent teaches in chat and never writes project files. Every reply starts with the header `[no-vibe] Step: <context\|level\|goal\|syllabus\|learn\|exercise\|check> · Chapter: <n/total\|-> · Section: <k\|-> · Exercise: <k\|->`. |
| `/no-vibe-btw <task>` | One-shot escape hatch to temporarily disable no-vibe write guard for a single scoped task, then restore the marker. |
| `/no-vibe-challenge [focus]` | One coding challenge built from the current syllabus or the project. The user writes all the code. The agent gives the task, hints when asked, and reviews when asked. |
<!-- /no-vibe:generated -->

## The write guard

While no-vibe is on, a hook refuses file writes and shell writes outside `.no-vibe/` (shell commands may also write to `/tmp`). It catches an agent that slips, but it is not a sandbox: some shell forms get past it, such as a variable inside a path or a build tool that writes files itself. no-vibe relies on the agent following the skill, and the guard catches it when it does not.

## License

MIT. Issues and PRs welcome at [github.com/rizukirr/no-vibe/issues](https://github.com/rizukirr/no-vibe/issues).
