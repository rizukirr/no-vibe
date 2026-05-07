# no-vibe — Codex Installation

## Install

```bash
# Clone the repo
git clone https://github.com/rizukirr/no-vibe.git ~/.codex/no-vibe

# Symlink skills into Codex discovery path
mkdir -p ~/.agents/skills
ln -s ~/.codex/no-vibe/skills ~/.agents/skills/no-vibe

# Restart Codex
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
3. Send a topic. On the AI's first reply, confirm `~/.no-vibe/PROFILE.md` and `.no-vibe/PROFILE.md` exist with the schema headings (`## Identity & expertise`, `## Observed strengths`, `## Known gaps`, `## Style notes`, `## Recent layer outcomes`) and empty bullets under each.
4. Ask the assistant to edit a project file — it should refuse with the no-vibe guard message (instruction-based soft block)
5. Ask the assistant to `echo bad > someproj.py` or `sed -i …` on a project file — it should also refuse, citing the Iron Law's Bash list in `skills/no-vibe/SKILL.md`. If it complies, the model is drifting; remind it.
6. Start a fresh session with an in-progress session JSON in `.no-vibe/data/sessions/` — the assistant should announce the resume hint (topic + `layer N/M, phaseX`) on the first turn (Phase 0 auto-resume).
7. Run `$no-vibe off` — should remove marker

## Caveat — soft block

Codex has no PreToolUse hook equivalent to Claude Code's
`hooks/block-writes.sh` / `hooks/block-bash-writes.sh`. Both the file
write guard and the Bash write-guard are enforced by SKILL.md's Iron
Law, not a process-level hook. If you need a hard block, use the
Claude Code or OpenCode surface.

## Requirements

- Codex CLI

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

no-vibe uses a three-layer adaptation stack:

- **Default teaching style** — the floor. Defined in `skills/no-vibe/SKILL.md`. Ships with the plugin; you never edit this directly.
- **`PROFILE.md` — the AI's progression files (AI-managed):**
  - `~/.no-vibe/PROFILE.md` — global progression. AI-created on your first `/no-vibe` activation, AI-updated per layer when it learns something durable about how *you* learn ("solid on closures", "needs a worked example for async", recent layer outcomes).
  - `.no-vibe/PROFILE.md` — same shape, project-scoped. Tracks your domain progress in this codebase.
- **`user/*.md` — your override files (user-managed, AI never touches):**
  - `~/.no-vibe/user/*.md` — global overrides. Any `.md` file in this directory becomes authoritative on conflict with PROFILE.md or the default style.
  - `.no-vibe/user/*.md` — same, project-scoped.

You don't need to do anything to bootstrap — the AI creates PROFILE.md on first activation. Read it any time to see what the AI has learned about you; you can edit it yourself if something looks wrong.

To add an explicit override the AI must respect, create a file under `user/`:

```bash
mkdir -p ~/.no-vibe/user
cat > ~/.no-vibe/user/style.md <<'EOF'
- Skip the 12-year-old framing — I have a CS background; technical vocab is fine.
- Prefer direct mechanism over kitchen/sports analogies.
EOF
```

The filename is yours to choose; the AI loads every `.md` file in `user/` sorted by filename. Anything in `user/` is read-only for the AI.

Codex has no SessionStart hook, so the AI is instructed (per `skills/no-vibe/SKILL.md`) to read PROFILE.md (both scopes) and every `user/*.md` at session start, and to create PROFILE.md on first activation if missing.

## Troubleshooting

**Skills not discovered:**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Guard ignored:**
- Check marker exists: `test -f .no-vibe/active && echo "active"`
- Remind the model that no-vibe mode is active or use `/no-vibe off` for normal editing
