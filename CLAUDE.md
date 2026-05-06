# CLAUDE.md

Guidance for Claude Code working in this repository.

## Repo purpose

This repo **is** the `no-vibe` plugin — not a consumer of it. It ships tutor-style coding mode across five AI CLIs (Claude Code, OpenCode, Codex, Gemini CLI, Pi). When users install it, AI stops writing their project files and walks them through writing code themselves.

Editing files inside this repo is normal plugin development — the no-vibe write guard does not apply here unless `.no-vibe/active` exists at the repo root.

## v2 architecture — single source, thin runtime adapters

Authoring lives in `/shared/`. Every runtime reads or copies from it. Runtime-specific code is small.

```
/.claude-plugin/marketplace.json  # Claude marketplace entry — points source to ./runtimes/claude
/shared/                          # Single source of truth (authoring)
  skill/        SKILL.md, phases.md, teaching-style.md, reference-grounding.md, curriculum.md
  commands/     no-vibe*.md (canonical command prose)
  guard/        patterns.json (Bash dangerous patterns + safe-target allowlist), write-tools.json
  status/       format.txt (status-line format)
  templates/    NO-VIBE.global.md, NO-VIBE.project.md, memory-readme.md

/runtimes/<name>/                 # Manifests + enforcement code (+ generated copies for Claude)
  claude/       .claude-plugin/, hooks/*.sh, skills/no-vibe/* [GENERATED], commands/* [GENERATED], shared/guard/* [GENERATED]
  opencode/     plugins/no-vibe.js, index.js
  pi/           .pi-plugin/{plugin.json, extensions/no-vibe/index.ts}
  codex/        AGENTS.md.template (+ generated AGENTS.md)
  gemini/       gemini-extension.json, GEMINI.md.template (+ generated GEMINI.md), .gemini/{commands/*.toml, tool-mapping.md}

/install/                         # Per-runtime installers (copy shared+runtime → user CLI dir)
/scripts/                         # sync.sh + bump-version.sh
VERSION                           # Single version source
index.js                          # OpenCode npm entrypoint (re-exports runtimes/opencode)
```

### Claude marketplace flow

Claude Code's `/plugin marketplace add rizukirr/no-vibe` clones the repo and reads `/.claude-plugin/marketplace.json` at the root. That manifest points `source: "./runtimes/claude"`, so Claude treats `runtimes/claude/` as the plugin tree. For Claude to find the skill and commands, sync.sh populates `runtimes/claude/skills/no-vibe/`, `runtimes/claude/commands/`, and `runtimes/claude/shared/guard/` from `/shared/`. These generated files carry an `<!-- AUTO-GENERATED FROM /shared -->` header (placed after the YAML frontmatter so Claude's parser still sees `---` on line 1) and are committed to git.

**Critical:** if you change anything under `/shared/`, run `bash scripts/sync.sh` before committing — otherwise Claude marketplace users will get stale files. `tests/test_sync.sh` and `scripts/sync.sh --check` enforce this.

## How sharing works

Three patterns:

**A — runtime reads `/shared/` at execution time** (Claude, OpenCode, Pi):
- Claude bash hooks `jq` `shared/guard/*.json` for tool names + path fields. Patterns are parsed in shell (logic) but the safe-target allowlist + tool list come from JSON.
- OpenCode JS plugin `import`s `shared/guard/*.json`.
- Pi TS extension does the same.

**B — instruction-only runtimes get text injection at sync time** (Codex, Gemini):
- `scripts/sync.sh` reads `shared/skill/SKILL.md` and `shared/guard/patterns.json`, injects them into `runtimes/codex/AGENTS.md.template` and `runtimes/gemini/GEMINI.md.template`, writes generated `.md` files with `AUTO-GENERATED FROM /shared` headers.
- Same script converts `shared/commands/*.md` to Gemini's `.toml` format.
- `tests/test_sync.sh` enforces no drift (CI-runnable as `scripts/sync.sh --check`).

**C — skill prose** (`shared/skill/*.md`): every runtime's discovery mechanism points at the shared path; no copying needed in-repo.

If you change `shared/guard/patterns.json` or `shared/skill/SKILL.md`, run `bash scripts/sync.sh` to regenerate Codex/Gemini outputs.

## Memory model

v2 has **no JSON logging.** Two NO-VIBE.md files, plain Markdown:

- **`~/.no-vibe/NO-VIBE.md`** — global, teaching style. Deviations from the eight-clause Feynman default. ~0–10 lines.
- **`.no-vibe/NO-VIBE.md`** — project canvas. Where we are, mental-model state, conventions, pickup hint. ~20–60 lines.

Write rule: only when contents contradict reality, miss load-bearing context, are stale, or the file doesn't exist. Surgical edits (line > section > whole-file). Whole-file rewrites archive the prior version to `memory/`. Surgical edits do not archive. Cross-project test (`would this still apply in a different project?`) decides which file. Every line lives in exactly one file.

Archives:
- `~/.no-vibe/memory/NO-VIBE-<ISO-timestamp>.md`
- `.no-vibe/memory/NO-VIBE-<ISO-timestamp>.md`

Archives are write-once and consulted on demand only — never loaded automatically.

## Verification

Run all tests before finishing plugin changes:

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

`test_sync.sh` covers drift between `/shared/` and generated Codex / Gemini outputs, plus version parity across the five manifest files.

## Versioning

Single source: `/VERSION`. Use `scripts/bump-version.sh <version>` to update all five manifests:

- `package.json`
- `.claude-plugin/marketplace.json` (root — Claude marketplace entry)
- `runtimes/claude/.claude-plugin/plugin.json`
- `runtimes/gemini/gemini-extension.json`
- `runtimes/pi/.pi-plugin/plugin.json`

`scripts/bump-version.sh --check` verifies parity. `tests/test_sync.sh` runs it.

## Common gotchas

- **Don't edit `runtimes/codex/AGENTS.md` or `runtimes/gemini/GEMINI.md` directly** — they're generated. Edit the corresponding `.template` files or `/shared/` content, then `bash scripts/sync.sh`.
- **Don't edit `runtimes/gemini/.gemini/commands/*.toml` directly** — generated from `shared/commands/`.
- **Path mirror:** the Bash-pattern parsing logic still lives in three runtime files (Claude bash hook, OpenCode plugin, Pi extension). Only the *data* (safe-target allowlist, tool names) is shared via JSON. If you change parsing, update all three files; if you change the allowlist, just edit `shared/guard/patterns.json`.
- **Windows line endings:** `jq` on Git Bash sometimes emits CRLF; the hook strips `\r` from JSON-derived tool names. If parity tests fail with weird match issues, check for stray `\r`.
