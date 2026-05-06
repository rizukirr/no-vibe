# AGENTS

## Repo purpose

`no-vibe` plugin — a tutor mode for AI coding assistants. AI shows code and reviews; user types every line. Ships across five CLIs (Claude Code, OpenCode, Codex, Gemini CLI, Pi).

## v2 architecture (single source of truth)

- `/.claude-plugin/marketplace.json` — Claude marketplace entry; `source: "./runtimes/claude"`.
- `/shared/` — skill prose, command prose, guard data, status format, templates. Authoritative source.
- `/runtimes/<name>/` — per-runtime manifests + enforcement code (Claude bash hooks, OpenCode JS plugin, Pi TS extension, Codex/Gemini instruction templates). For Claude, `runtimes/claude/skills/no-vibe/`, `runtimes/claude/commands/`, and `runtimes/claude/shared/guard/` are populated from `/shared/` by sync (with AUTO-GENERATED headers after the frontmatter).
- `/install/install-<runtime>.sh` — per-runtime installers (offline / manual fallback). Recommended Claude install is `/plugin marketplace add rizukirr/no-vibe`.
- `/scripts/sync.sh` — regenerates Codex `AGENTS.md`, Gemini `GEMINI.md`, Gemini `.toml` commands, AND the Claude runtime tree (skills/commands/shared/guard) from `/shared/`.
- `/scripts/bump-version.sh` — single-source version updates across the five manifest files.

Pattern A (live reads): Claude bash hooks, OpenCode plugin, Pi extension all read `shared/guard/*.json` directly — tool names and safe-target allowlist are single-source.

Pattern B (sync-time injection): Codex `AGENTS.md` and Gemini `GEMINI.md` are generated from templates with `<!-- INJECT:SKILL_BODY -->` and `<!-- INJECT:GUARD_PATTERNS -->` markers. Don't hand-edit the generated files; edit the templates or `/shared/` and re-run sync.

## Memory model (v2)

Two NO-VIBE.md files (no JSON):
- `~/.no-vibe/NO-VIBE.md` — global tutor style (deviations from the eight-clause Feynman default).
- `.no-vibe/NO-VIBE.md` — project canvas (where we are, mental model, conventions).

Write only when contradicted / stale / missing / first-time. Surgical edits preferred. Whole-file rewrites archive prior versions to `memory/`. No append-only logging.

## Verification commands

Run all before finishing plugin changes:

```bash
bash tests/test_block_writes.sh
bash tests/test_block_bash_writes.sh
bash tests/test_status.sh
bash tests/test_escape_hatch.sh
bash tests/test_gemini_guard.sh
bash tests/test_sync.sh
node tests/test_opencode_plugin.mjs
node tests/test_pi_plugin.mjs
```

`test_sync.sh` checks both shared→generated drift and version parity across manifests.

## Conventions that are easy to miss

- Bash-pattern parsing logic is still mirrored across three runtime files (Claude bash hook, OpenCode plugin, Pi extension). The safe-target allowlist + write-tool list are shared (`shared/guard/*.json`); the parser is per-language. If you change parsing, update all three files.
- Don't edit `runtimes/codex/AGENTS.md`, `runtimes/gemini/GEMINI.md`, or `runtimes/gemini/.gemini/commands/*.toml` — generated. Edit `/shared/` or the templates, then run `bash scripts/sync.sh`.
- `.no-vibe/` and `~/.no-vibe/` are intentionally writable during active mode; project paths outside them are intentionally blocked.

## Release/versioning

Single source: `/VERSION`. Run `bash scripts/bump-version.sh <version>` to update all five manifests in lockstep. `bash scripts/bump-version.sh --check` verifies parity.
