# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

This repo **is** the `no-vibe` plugin itself — not a consumer of it. It ships tutor-style coding mode across four AI CLIs (Claude Code, OpenCode, Codex, Gemini CLI). When users install it, AI stops writing their project files and walks them through writing code themselves.

Do **not** confuse "developing this plugin" with "being in no-vibe mode". Editing files inside this repo is normal plugin development — the no-vibe write guard does not apply here unless `.no-vibe/active` exists at the repo root.

## Verification

No root npm script runner. Run all test suites before finishing plugin changes:

```bash
bash tests/test_block_writes.sh
bash tests/test_status.sh
node tests/test_opencode_plugin.mjs
bash tests/test_escape_hatch.sh
bash tests/test_gemini_guard.sh
```

## Architecture — parallel surfaces, one behavior

The same no-vibe behavior is implemented four times, once per host CLI. A change to one surface almost always needs mirrored changes on the others.

**Write-guard enforcement** (hard stop when `.no-vibe/active` exists, allow `.no-vibe/` writes):
- Claude Code: `hooks/block-writes.sh` — PreToolUse hook for Edit/Write/NotebookEdit/MultiEdit/ApplyPatch
- OpenCode: `.opencode/plugins/no-vibe.js` — in-process guard in the plugin
- Codex: instruction-based guard via no-vibe skill/commands (no native PreToolUse hook wiring in this repo)
- Gemini CLI: **no hook available** — instruction-based soft block via `GEMINI.md`

Path-handling rules must stay in lockstep between `hooks/block-writes.sh` and `.opencode/plugins/no-vibe.js`. If one changes, update the other.

**Status line** (`no-vibe: ON|OFF`, silent when no `.no-vibe/` dir exists to avoid noise in unrelated projects):
- Claude: `hooks/status.sh` (SessionStart)
- OpenCode: bootstrap inject in `.opencode/plugins/no-vibe.js`

**Command specs** — one logical command, four physical copies:
- `commands/no-vibe*.md` (Claude)
- `.opencode/commands/no-vibe*.md` (OpenCode)
- `.gemini/commands/no-vibe*.toml` (Gemini)
- Codex reuses Claude's `commands/` via `INSTALL.codex.md`

**Teaching logic** lives in `skills/no-vibe/SKILL.md` (six-phase cycle) and is shared across all surfaces. Data contracts for learner tracking are in `skills/no-vibe/DATA-SCHEMA.md` — session/mistake/ai-note JSON plus global `profile.md` + synth-state contracts must match.

**Entrypoints:** `index.js` re-exports `.opencode/plugins/no-vibe.js` for OpenCode's plugin loader. Claude discovers via `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`. Gemini via `gemini-extension.json` + `GEMINI.md`.

## Two data-file semantics that are easy to misread

- `mistakes.json` records **teaching failures** (AI gap + corrective action), not learner flaws. Every entry needs `pck_gap`, `load_mismatch`, `gap_action`, `applied`.
- `ai-notes.json` records **user-driven AI adjustments** (corrections, preferences, requests).

Both are project-level logs in `.no-vibe/data/`; the cross-project learner model is synthesized into `~/.no-vibe/profile.md` (with `.synth-state.json` bookkeeping). See `skills/no-vibe/DATA-SCHEMA.md` for field semantics and legacy-entry tolerance.

## Versioning

Version numbers are duplicated in:
- `package.json`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `gemini-extension.json`

Use `scripts/bump-version.sh <version|patch|minor|major>` to keep them in sync. Do not bump by hand.
