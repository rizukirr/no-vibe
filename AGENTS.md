# AGENTS

## Repo purpose
- This repo is a plugin package (`no-vibe`) that enforces tutor-style coding: AI can teach/review, but should not write project files during active no-vibe sessions.

## Architecture (high-signal files)
- OpenCode plugin entrypoint: `index.js` re-exports `.opencode/plugins/no-vibe.js`.
- Main OpenCode logic lives in `.opencode/plugins/no-vibe.js`:
  - injects no-vibe bootstrap into the first user message,
  - registers bundled skills path,
  - blocks write tools outside `.no-vibe/` when `.no-vibe/active` exists.
- Claude hook equivalent is `hooks/block-writes.sh` (PreToolUse for Edit/Write/NotebookEdit/MultiEdit).
- Claude SessionStart hook `hooks/status.sh` prints `no-vibe: ON|OFF` — silent in projects without a `.no-vibe/` dir to avoid noise elsewhere. OpenCode plugin mirrors the same behavior in its bootstrap inject.
- Command specs are split by platform:
  - Claude-style command docs: `commands/no-vibe.md`, `commands/no-vibe-challenge.md`, `commands/no-vibe-btw.md`
  - OpenCode command docs: `.opencode/commands/no-vibe.md`, `.opencode/commands/no-vibe-challenge.md`
  - Gemini CLI commands (TOML): `.gemini/commands/no-vibe.toml`, `.gemini/commands/no-vibe-challenge.toml`, `.gemini/commands/no-vibe-btw.toml`
- Gemini CLI surface: `gemini-extension.json` + `GEMINI.md` + `.gemini/tool-mapping.md`. No PreToolUse hook equivalent — write guard is instruction-based (soft block); keep `GEMINI.md` guard rules aligned with `hooks/block-writes.sh` and `.opencode/plugins/no-vibe.js` behavior.

## Verification commands
- Run all local test suites before finishing plugin changes:
  - `bash tests/test_block_writes.sh`
  - `bash tests/test_status.sh`
  - `node tests/test_opencode_plugin.mjs`
- There is no root npm script runner; run tests directly with the commands above.

## Conventions that are easy to miss
- Keep behavior aligned between the shell hook (`hooks/block-writes.sh`) and OpenCode plugin guard (`.opencode/plugins/no-vibe.js`). If one path-handling rule changes, update the other.
- Keep command docs aligned across `commands/` and `.opencode/commands/` when changing no-vibe flow or data-tracking requirements.
- Data contracts for learner tracking live in `skills/no-vibe/DATA-SCHEMA.md`; session/profile/mistake JSON shapes should match that schema exactly.
- `mistakes.json` records *teaching failures*, not learner flaws: every entry captures the AI teaching gap that caused a user error, plus the corrective action. `ai-notes.json` captures user-driven AI adjustments (corrections, preferences, requests). See DATA-SCHEMA.md for field semantics and legacy-entry tolerance.
- `.no-vibe/` is intentionally writable during active mode; project paths outside it are intentionally blocked.

## Release/versioning notes
- Version numbers are repeated in:
  - `package.json`
  - `.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`
  - `gemini-extension.json`
- Use `scripts/bump-version.sh <version|patch|minor|major>` to keep plugin/marketplace versions in sync.
