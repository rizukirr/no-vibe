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
- Command specs are split by platform:
  - Claude-style command docs: `commands/no-vibe.md`, `commands/no-vibe-challenge.md`, `commands/no-vibe-btw.md`
  - OpenCode command docs: `.opencode/commands/no-vibe.md`, `.opencode/commands/no-vibe-challenge.md`

## Verification commands
- Run both local test suites before finishing plugin changes:
  - `bash tests/test_block_writes.sh`
  - `node tests/test_opencode_plugin.mjs`
- There is no root npm script runner; run tests directly with the commands above.

## Conventions that are easy to miss
- Keep behavior aligned between the shell hook (`hooks/block-writes.sh`) and OpenCode plugin guard (`.opencode/plugins/no-vibe.js`). If one path-handling rule changes, update the other.
- Keep command docs aligned across `commands/` and `.opencode/commands/` when changing no-vibe flow or data-tracking requirements.
- Data contracts for learner tracking live in `skills/no-vibe/DATA-SCHEMA.md`; session/profile/mistake JSON shapes should match that schema exactly.
- `.no-vibe/` is intentionally writable during active mode; project paths outside it are intentionally blocked.

## Release/versioning notes
- Version numbers are repeated in:
  - `package.json`
  - `.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`
- Use `scripts/bump-version.sh <version|patch|minor|major>` to keep plugin/marketplace versions in sync.
