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

1. In any project, run `/no-vibe on` — creates `.no-vibe/active`. PROFILE.md
   is not created yet; it is created by the AI on its first reply.
2. Send a topic. On the AI's first reply, confirm `~/.no-vibe/PROFILE.md`
   exists with the schema headings (`## Identity & expertise`,
   `## Learning style`, `## Disclosure mode`, `## Observed strengths`,
   `## Known gaps`) and
   empty bullets under each. `.no-vibe/SUMMARY.md` should NOT exist
   yet — it appears at the first layer close worth recording, with
   sections `## Current Focus`, `## Accomplishments`, `## Open Questions`.
3. Ask the assistant to edit a project file — it should refuse with the
   no-vibe guard message (soft-block; see caveat below).
4. Ask the assistant to `echo bad > someproj.py` or `sed -i 's/x/y/'
   src/file` — it should also refuse, citing the Bash guard rules in
   `GEMINI.md`. If it complies, the model is drifting; remind it.
5. Start a fresh session in a project with an in-progress session JSON
   under `.no-vibe/data/sessions/` — first turn should print
   `no-vibe: ON — resuming "<topic>" (layer N/M, phaseX)`.
6. Run `/no-vibe off` — removes the marker.

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

no-vibe uses a four-layer adaptation stack, split by *write cadence* and *scope*:

- **Default teaching style** — the floor. Defined in `skills/no-vibe/SKILL.md`. Ships with the plugin; you never edit this directly.
- **`~/.no-vibe/PROFILE.md` — global, stable identity (AI-managed):** identity, expertise, learning style, disclosure mode (guided vs. showcase default), observed strengths, known gaps. AI-created on your first `/no-vibe` activation, rewritten only when something cross-project durable shifts.
- **`.no-vibe/SUMMARY.md` — project, running journey (AI-managed):** current focus, accomplishments, open questions in *this* project. AI-created at the first layer close worth recording, updated frequently, pruned aggressively.
- **`user/*.md` — your override files (user-managed, AI never touches):**
  - `~/.no-vibe/user/*.md` — global overrides
  - `.no-vibe/user/*.md` — project overrides

You don't need to do anything to bootstrap — the AI creates PROFILE.md on first activation and SUMMARY.md when the journey produces an outcome worth recording. To add an explicit override the AI must respect, create a file under `user/`:

```bash
mkdir -p ~/.no-vibe/user
cat > ~/.no-vibe/user/style.md <<'EOF'
- Skip the 12-year-old framing — I have a CS background; technical vocab is fine.
- Prefer direct mechanism over kitchen/sports analogies.
EOF
```

The filename is yours to choose; the AI loads every `.md` file in `user/` sorted by filename. Anything in `user/` is read-only for the AI.

Gemini has no SessionStart hook, so the AI is instructed (per `GEMINI.md` and `skills/no-vibe/SKILL.md`) to read `~/.no-vibe/PROFILE.md`, `.no-vibe/SUMMARY.md`, and every `user/*.md` at session start, and to create PROFILE.md on first activation if missing. SUMMARY.md absence is fine — it gets created later when there's a journey outcome to record.

## Troubleshooting

- Commands not found: verify `~/.gemini/extensions/no-vibe/.gemini/commands/` contains the `.toml` files.
- Context missing: verify `~/.gemini/extensions/no-vibe/GEMINI.md` exists and the `@` includes resolve (paths are relative to `GEMINI.md`).
- Guard ignored: Gemini enforcement is instruction-based; if the model drifts, remind it of `.no-vibe/active` or use `/no-vibe off` and a stricter surface.
