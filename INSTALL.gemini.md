# no-vibe — Gemini CLI Installation

## Install

Gemini CLI loads extensions from `~/.gemini/extensions/<name>/` (user scope)
or `<project>/.gemini/extensions/<name>/` (workspace scope). Clone the repo
and symlink it in:

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/.gemini/no-vibe
mkdir -p ~/.gemini/extensions
ln -s ~/.gemini/no-vibe ~/.gemini/extensions/no-vibe
```

On Windows (PowerShell):

```powershell
git clone https://github.com/rizukirr/no-vibe.git "$env:USERPROFILE\.gemini\no-vibe"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.gemini\extensions"
cmd /c mklink /J "$env:USERPROFILE\.gemini\extensions\no-vibe" "$env:USERPROFILE\.gemini\no-vibe"
```

Restart Gemini CLI. The extension's `GEMINI.md` context and TOML commands
under `.gemini/commands/` are auto-discovered.

## Verify

1. In any project, run `/no-vibe on` — creates `.no-vibe/active` and
   bootstraps learner state.
2. Ask the assistant to edit a project file — it should refuse with the
   no-vibe guard message (soft-block; see caveat below).
3. Ask the assistant to `echo bad > someproj.py` or `sed -i 's/x/y/'
   src/file` — it should also refuse, citing the Bash guard rules in
   `GEMINI.md`. If it complies, the model is drifting; remind it.
4. Start a fresh session in a project with an in-progress session JSON
   under `.no-vibe/data/sessions/` — first turn should print
   `no-vibe: ON — resuming "<topic>" (layer N/M, phaseX)`.
5. Run `/no-vibe off` — removes the marker.

## Caveat — soft block

Gemini CLI has no PreToolUse hook equivalent to Claude Code's
`hooks/block-writes.sh` or `hooks/block-bash-writes.sh`. Both the
write guard and the Bash write-guard are enforced by strong
instructions in `GEMINI.md` and the skill content, not a process-level
hook. If you need a hard block, use the Claude Code or OpenCode surface.

## Usage

```
/no-vibe build a REST API handler          # one-shot lesson
/no-vibe on                                # persistent mode
/no-vibe --ref pytorch --mode concept      # with reference + mode
/no-vibe-challenge                         # get a coding challenge
/no-vibe-challenge recursion               # challenge with focus area
/no-vibe-btw add a .gitignore for node     # one-shot escape hatch
/no-vibe off                               # exit
```

## Customizing teaching style

no-vibe adapts via two plain-Markdown files: `~/.no-vibe/NO-VIBE.md` (global teaching style — applies in any project) and `.no-vibe/NO-VIBE.md` (per-project canvas — teaching format, conventions, notes for *this* codebase).

Gemini has no SessionStart hook, so the AI is instructed (per `GEMINI.md` and `skills/no-vibe/SKILL.md`) to seed both from `templates/` on first activation. For more reliable behavior, seed them yourself with a one-time copy:

```bash
# Global (once per machine)
mkdir -p ~/.no-vibe
[ -f ~/.no-vibe/NO-VIBE.md ] || cp ~/.gemini/no-vibe/templates/NO-VIBE.global.md ~/.no-vibe/NO-VIBE.md

# Per-project (once per project, after `/no-vibe on`)
[ -f .no-vibe/NO-VIBE.md ] || cp ~/.gemini/no-vibe/templates/NO-VIBE.project.md .no-vibe/NO-VIBE.md
```

Edit either file at any time to override the defaults — the AI re-reads them every turn. The defaults are starting points, not gospel; replace clauses cleanly when something better serves you.

## Troubleshooting

- Commands not found: verify `~/.gemini/extensions/no-vibe/.gemini/commands/` contains the `.toml` files.
- Context missing: verify `~/.gemini/extensions/no-vibe/GEMINI.md` exists and the `@` includes resolve (paths are relative to `GEMINI.md`).
- Guard ignored: Gemini enforcement is instruction-based; if the model drifts, remind it of `.no-vibe/active` or use `/no-vibe off` and a stricter surface.
