# AGENTS

## Repo purpose
- This repo is a plugin package (`no-vibe`) that enforces tutor-style coding: AI can teach/review, but should not write project files during active no-vibe sessions.

## Architecture (high-signal files)
- OpenCode plugin entrypoint: `index.js` re-exports `.opencode/plugins/no-vibe.js`.
- Main OpenCode logic lives in `.opencode/plugins/no-vibe.js`:
  - injects no-vibe bootstrap into the first user message,
  - registers bundled skills path,
  - blocks write tools outside `.no-vibe/` when `.no-vibe/active` exists.
- Claude hook equivalent is `hooks/block-writes.sh` (PreToolUse for Edit/Write/NotebookEdit/MultiEdit/ApplyPatch) plus `hooks/block-bash-writes.sh` (PreToolUse for Bash).
- Pi surface: `.pi-plugin/plugin.json` + `.pi-plugin/extensions/no-vibe/index.ts` (TS extension hooking `before_agent_start` for bootstrap injection and `tool_call` for write/Bash hard block) + `.pi-plugin/prompts/no-vibe*.md`. Mirror of the OpenCode plugin (hard block). Wired via the `pi` key in `package.json`.
- Claude SessionStart hook `hooks/status.sh` prints `no-vibe: ON|OFF` — silent in projects without a `.no-vibe/` dir to avoid noise elsewhere. OpenCode plugin and Pi extension mirror the same behavior in their bootstrap inject / `before_agent_start` injection.
- Command specs are split by platform:
  - Claude-style command docs: `commands/no-vibe.md`, `commands/no-vibe-challenge.md`, `commands/no-vibe-btw.md`
  - OpenCode command docs: `.opencode/commands/no-vibe.md`, `.opencode/commands/no-vibe-challenge.md`, `.opencode/commands/no-vibe-btw.md`
  - Pi prompt templates: `.pi-plugin/prompts/no-vibe.md`, `.pi-plugin/prompts/no-vibe-challenge.md`, `.pi-plugin/prompts/no-vibe-btw.md`
  - Gemini CLI commands (TOML): `.gemini/commands/no-vibe.toml`, `.gemini/commands/no-vibe-challenge.toml`, `.gemini/commands/no-vibe-btw.toml`
- Gemini CLI surface: `gemini-extension.json` + `GEMINI.md` + `.gemini/tool-mapping.md`. No PreToolUse hook equivalent — write guard is instruction-based (soft block); keep `GEMINI.md` guard rules aligned with `hooks/block-writes.sh`, `.opencode/plugins/no-vibe.js`, and `.pi-plugin/extensions/no-vibe/index.ts` behavior.

## Verification commands
- Run all local test suites before finishing plugin changes:
  - `bash tests/test_block_writes.sh`
  - `bash tests/test_block_bash_writes.sh`
  - `bash tests/test_status.sh`
  - `node tests/test_opencode_plugin.mjs`
  - `bash tests/test_escape_hatch.sh`
  - `bash tests/test_gemini_guard.sh`
  - `node tests/test_pi_plugin.mjs`
- There is no root npm script runner; run tests directly with the commands above.

## Conventions that are easy to miss
- Keep behavior aligned across the three hard-block surfaces — Claude shell hooks (`hooks/block-writes.sh`, `hooks/block-bash-writes.sh`), OpenCode plugin guard (`.opencode/plugins/no-vibe.js`), and Pi extension (`.pi-plugin/extensions/no-vibe/index.ts`). If one path-handling, allowlist, or Bash-pattern rule changes, update the others.
- Keep command docs aligned across `commands/`, `.opencode/commands/`, `.pi-plugin/prompts/`, and `.gemini/commands/` when changing no-vibe flow or memory requirements.
- Adaptation memory is two plain-Markdown files: `~/.no-vibe/NO-VIBE.md` (global teaching style) and `.no-vibe/NO-VIBE.md` (project canvas). Defaults are seeded from `templates/NO-VIBE.global.md` and `templates/NO-VIBE.project.md`. The four runtime hooks (`hooks/status.sh`, `.opencode/plugins/no-vibe.js`, `.pi-plugin/extensions/no-vibe/index.ts`, plus the Codex/Gemini context files) inject both NO-VIBE.md contents into the system prompt at session start so the AI cannot skip the user's stated preferences.
- Per-session JSON state (`.no-vibe/data/sessions/<slug>.json`) still tracks `current_phase`, `current_layer`, `revision_id`, `status`, etc. — that is the cycle state machine, separate from adaptation memory.
- `.no-vibe/` is intentionally writable during active mode; project paths outside it are intentionally blocked.

## Release/versioning notes
- Version numbers are repeated in:
  - `package.json`
  - `.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`
  - `gemini-extension.json`
  - `.pi-plugin/plugin.json`
- Use `scripts/bump-version.sh <version|patch|minor|major>` to keep plugin/marketplace versions in sync. The pi parity test (`tests/test_pi_plugin.mjs`) asserts `package.json` and `.pi-plugin/plugin.json` versions match.
