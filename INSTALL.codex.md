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
2. Run `$no-vibe on` — should create `.no-vibe/active` marker
3. Ask the assistant to edit a project file — it should refuse with the no-vibe guard message (instruction-based soft block)
4. Ask the assistant to `echo bad > someproj.py` or `sed -i …` on a project file — it should also refuse, citing the Iron Law's Bash list in `skills/no-vibe/SKILL.md`. If it complies, the model is drifting; remind it.
5. Start a fresh session with an in-progress session JSON in `.no-vibe/data/sessions/` — the assistant should announce the resume hint (topic + `layer N/M, phaseX`) on the first turn (Phase 0 auto-resume).
6. Run `$no-vibe off` — should remove marker

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

no-vibe adapts via two plain-Markdown files: `~/.no-vibe/NO-VIBE.md` (global teaching style — applies in any project) and `.no-vibe/NO-VIBE.md` (per-project canvas — teaching format, conventions, notes for *this* codebase).

Codex has no SessionStart hook, so the AI is instructed (per `skills/no-vibe/SKILL.md`) to seed both from `templates/` on first activation. For more reliable behavior, seed them yourself with a one-time copy:

```bash
# Global (once per machine)
mkdir -p ~/.no-vibe
[ -f ~/.no-vibe/NO-VIBE.md ] || cp ~/.codex/no-vibe/templates/NO-VIBE.global.md ~/.no-vibe/NO-VIBE.md

# Per-project (once per project, after `$no-vibe on`)
[ -f .no-vibe/NO-VIBE.md ] || cp ~/.codex/no-vibe/templates/NO-VIBE.project.md .no-vibe/NO-VIBE.md
```

Edit either file at any time to override the defaults — the AI re-reads them every turn. The defaults are starting points, not gospel; replace clauses cleanly when something better serves you.

## Troubleshooting

**Skills not discovered:**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Guard ignored:**
- Check marker exists: `test -f .no-vibe/active && echo "active"`
- Remind the model that no-vibe mode is active or use `/no-vibe off` for normal editing
