# AGENTS

## Repo purpose

This repo is the no-vibe plugin for Claude Code, Codex, opencode, Pi and Antigravity. Developing the plugin is normal editing. The write guard applies only when `.no-vibe/active` exists at the repo root.

## What no-vibe is for

People learn by doing the thinking and by typing code by hand. The agent finds the user's level with concrete multiple-choice questions, agrees a goal with them, and writes a high-level syllabus they approve. It teaches each section briefly, concept first or code first, chosen per section. Each section gets at least 3 exercises with the full code shown, so the user builds muscle memory by typing it. Later sections reuse earlier material.

Test every teaching change against one question: does the user still think and still type every line?

## Sources and generated files

The hand-edited sources are `no-vibe.config.json`, `skills/*/SKILL.md`, `hooks/*.sh`, `hooks/run-hook.cmd`, `bin/`, `lib/`, `runtimes/`, `tests/` and the prose docs. Everything listed in `.no-vibe-manifest` is generated. Edit the source, run `npm run generate`, and never hand-edit a generated file. `npm run check` fails when a generated file is stale.

The version lives only in `no-vibe.config.json`.

## Write guard

`hooks/block-writes.sh` and `hooks/block-bash-writes.sh` are the only guard implementation. Claude Code, Codex and Antigravity call them as hooks, and opencode and Pi call them from their generated plugins.

The Write-tool guard allows writes only under `.no-vibe/**` and `$HOME/.no-vibe/**`, and refuses a path through a symlink or longer than 4000 bytes. The Bash guard reads each command's text and also allows `/tmp/**`, `/var/tmp/**`, `/dev/null`, `/dev/stdout`, `/dev/stderr`, `/dev/tty` and `/dev/fd/*`. It refuses a target that starts with `$` or uses `$(`, `${` or backticks, a glob, a brace or a backslash, an overlong path, a path through a symlink, and any command over 64 KB.

The guards are a guardrail against drift, not a sandbox. The Bash guard matches common write forms with patterns, so shell it does not parse gets through: a variable in the middle of a path (`.no-vibe/$X`), `>|` and `>&` redirects, a second `cp`, `tee` or `sed -i` in one command, a quoted space inside a path, writes through `/dev/fd`, a symlink created and used in the same call, and any script or build tool that writes files itself. no-vibe relies on the skill keeping the agent in chat, and the guard catches it when it slips.

## State

`.no-vibe/syllabus.md` is the only state file. `hooks/status.sh` reads it for the resume line.

## Commands

<!-- no-vibe:generated:commands -->
| Command | Effect |
|---|---|
| `/no-vibe [on\|off\|<topic>]` | Learning mode. Use ONLY when `.no-vibe/active` exists at the project root or the user invoked `/no-vibe`. The agent teaches in chat and never writes project files. Every reply starts with the header `[no-vibe] Step: <context\|level\|goal\|syllabus\|learn\|exercise> · Section: <n/total\|-> · Exercise: <k\|->`. |
| `/no-vibe-btw <task>` | One-shot escape hatch to temporarily disable no-vibe write guard for a single scoped task, then restore the marker. |
| `/no-vibe-challenge [focus]` | One coding challenge built from the current syllabus or the project. The user writes all the code. The agent gives the task, hints when asked, and reviews when asked. |
<!-- /no-vibe:generated -->

## Verification

Run these before finishing a change:

```bash
npm run check
node tests/test_generate.mjs
bash tests/test_block_writes.sh
bash tests/test_block_bash_writes.sh
bash tests/test_json.sh
bash tests/test_status.sh
bash tests/test_escape_hatch.sh
bash tests/test_contract_injection.sh
node tests/test_guard_parity.mjs
node tests/test_manifests.mjs
```
