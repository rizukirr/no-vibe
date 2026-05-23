# no-vibe — Codex Installation

## Install (marketplace — recommended)

Requires a Codex CLI build with plugin marketplace support (see https://developers.openai.com/codex/plugins/build).

```bash
codex plugin marketplace add rizukirr/no-vibe
codex plugin add no-vibe --marketplace no-vibe
```

This installs skills, prompts, and the PreToolUse / SessionStart hooks declared in `.codex-plugin/plugin.json`. Hooks are non-managed by default — Codex will prompt you to review and trust them on first activation, giving you a **hard block** on writes (exit code 2) instead of the instruction-only soft block of the legacy install.

## Install (legacy — manual symlink)

Works on Codex builds that pre-date plugin marketplace support. Provides skills + prompts only; the write guard falls back to **soft block** (SKILL.md Iron Law, no PreToolUse hook).

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/.codex/no-vibe

mkdir -p ~/.agents/skills
ln -s ~/.codex/no-vibe/skills ~/.agents/skills/no-vibe
```

On Windows (PowerShell):

```powershell
git clone https://github.com/rizukirr/no-vibe.git "$env:USERPROFILE\.codex\no-vibe"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\no-vibe" "$env:USERPROFILE\.codex\no-vibe\skills"
```

## Verify Installation

1. Start a Codex session in any project
2. Run `$no-vibe on` — should create `.no-vibe/active` marker. PROFILE.md is not created yet; it is created by the AI on its first reply.
3. Send a topic. On the AI's first reply, confirm `~/.no-vibe/PROFILE.md` exists with the schema headings (`## Identity & expertise`, `## Learning style`, `## Disclosure mode`, `## Observed strengths`, `## Known gaps`) and empty bullets under each. `.no-vibe/SUMMARY.md` should NOT exist yet — it appears at the first layer close worth recording, with sections `## Current Focus`, `## Accomplishments`, `## Open Questions`.
4. Ask the assistant to edit a project file:
   - **Marketplace install (hook-based):** Codex should reject the `apply_patch` call with the no-vibe guard message (hard block, exit code 2 from `hooks/block-writes.sh`).
   - **Legacy install (instruction-based):** the assistant should refuse via SKILL.md's Iron Law (soft block).
5. Ask the assistant to `echo bad > someproj.py` or `sed -i …` on a project file — same as above; hard block under marketplace install (via `hooks/block-bash-writes.sh`), soft block under legacy.
6. Start a fresh session with an in-progress session JSON in `.no-vibe/data/sessions/` — the assistant should announce the resume hint (topic + `layer N/M, phaseX`) on the first turn (Phase 0 auto-resume).
7. Run `$no-vibe off` — should remove marker

## Hook portability

The hooks in `hooks/*.sh` are shared with Claude Code. Codex's hook spec is near-identical: PreToolUse events, JSON on stdin, exit code 2 to block, and `${CLAUDE_PLUGIN_ROOT}` provided as a legacy alias for the native `${PLUGIN_ROOT}`. The hooks parse `.cwd`, `.tool_name`, and `.tool_input.file_path` from stdin — fields Codex documents as PreToolUse common payload. If a Codex release changes those field names, the hooks need updating in lockstep with the Claude versions.

The legacy symlink install path has no PreToolUse hook surface, so both the file write guard and the Bash write-guard fall back to SKILL.md's Iron Law (soft block).

## Requirements

- Codex CLI (marketplace install requires plugin marketplace support; legacy install works on any version)

## Usage

```
$no-vibe build a REST API handler          # one-shot lesson
$no-vibe on                                # persistent mode
$no-vibe --ref pytorch --mode concept      # with reference + mode
$no-vibe-challenge                         # get a coding challenge
$no-vibe-challenge recursion               # challenge with focus area
$no-vibe-btw add a .gitignore for node     # one-shot escape hatch
$no-vibe off                               # exit
```

## Customizing teaching style

no-vibe uses a four-layer adaptation stack, split by *write cadence* and *scope*:

- **Default teaching style** — the floor. Defined in `skills/no-vibe/SKILL.md`. Ships with the plugin; you never edit this directly.
- **`~/.no-vibe/PROFILE.md` — global, stable identity (AI-managed):** identity, expertise, learning style, disclosure mode (guided vs. showcase default), observed strengths, known gaps. AI-created on your first `/no-vibe` activation, rewritten only when something cross-project durable shifts.
- **`.no-vibe/SUMMARY.md` — project, running journey (AI-managed):** current focus, accomplishments, open questions in *this* project. AI-created at the first layer close worth recording (not seeded on activation), updated frequently, pruned aggressively.
- **`user/*.md` — your override files (user-managed, AI never touches):**
  - `~/.no-vibe/user/*.md` — global overrides. Any `.md` file in this directory becomes authoritative on conflict with PROFILE.md, SUMMARY.md, or the default style.
  - `.no-vibe/user/*.md` — same, project-scoped.

You don't need to do anything to bootstrap — the AI creates PROFILE.md on first activation and SUMMARY.md when the journey produces an outcome worth recording. Read either file any time to see what the AI has learned; edit them yourself if something looks wrong.

To add an explicit override the AI must respect, create a file under `user/`:

```bash
mkdir -p ~/.no-vibe/user
cat > ~/.no-vibe/user/style.md <<'EOF'
- Skip the 12-year-old framing — I have a CS background; technical vocab is fine.
- Prefer direct mechanism over kitchen/sports analogies.
EOF
```

The filename is yours to choose; the AI loads every `.md` file in `user/` sorted by filename. Anything in `user/` is read-only for the AI.

Under the marketplace install, the `SessionStart` hook (`hooks/status.sh`) injects the `no-vibe: ON|OFF` status and Background Memory block at session start, the same as on Claude Code / OpenCode / Pi. Under the legacy symlink install, no SessionStart hook fires, and the AI is instructed (per `skills/no-vibe/SKILL.md`) to read `~/.no-vibe/PROFILE.md`, `.no-vibe/SUMMARY.md`, and every `user/*.md` at session start, and to create PROFILE.md on first activation if missing. SUMMARY.md absence is fine — it gets created later when there's a journey outcome to record.

## Troubleshooting

**Skills not discovered:**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Guard ignored:**
- Check marker exists: `test -f .no-vibe/active && echo "active"`
- Remind the model that no-vibe mode is active or use `/no-vibe off` for normal editing
