# no-vibe for Codex

## Install (marketplace)

Requires a Codex CLI build with plugin marketplace support (see https://developers.openai.com/codex/plugins/build).

```bash
codex plugin marketplace add rizukirr/no-vibe
codex plugin add no-vibe --marketplace no-vibe
```

Plugin hooks need a one-time trust approval. Codex asks you to review and trust them on first use, and until you do, the write guard and the status line do not run.

This installs the skills and the PreToolUse and SessionStart hooks declared in `hooks/hooks.json`. The guard is a hard block: a refused write exits with code 2.

## Verify installation

1. Start a Codex session in any project.
2. Run `$no-vibe on`. It should create the `.no-vibe/active` marker.
3. Send a topic. The agent should start with multiple-choice questions about your level, and every reply should start with the `[no-vibe] Step: ...` header.
4. Ask the assistant to edit a project file. Codex should reject the `apply_patch` call with the no-vibe guard message from `hooks/block-writes.sh`.
5. Ask the assistant to run `echo bad > someproj.py` or `sed -i` on a project file. `hooks/block-bash-writes.sh` should block it the same way.
6. Once a syllabus is approved, start a fresh session. The status line should read `no-vibe: ON, resuming "<topic>" (section n/total)`.
7. Run `$no-vibe off`. It should remove the marker.

## Hook portability

The hooks in `hooks/*.sh` are shared with Claude Code. Codex's hook spec is near-identical: PreToolUse events, JSON on stdin, exit code 2 to block, and `${CLAUDE_PLUGIN_ROOT}` provided as a legacy alias for the native `${PLUGIN_ROOT}`. The hooks parse `.cwd`, `.tool_name` and `.tool_input` from stdin, fields Codex documents as the PreToolUse common payload. If a Codex release renames those fields, the hooks need updating for every runtime at once.

## Requirements

- Codex CLI with plugin marketplace support
- `bash` on PATH

## Usage

```
$no-vibe build a REST API handler          # start a lesson on a topic
$no-vibe on                                # turn on, or resume an approved syllabus
$no-vibe-challenge                         # get a coding challenge
$no-vibe-challenge recursion               # challenge with focus area
$no-vibe-btw add a .gitignore for node     # one-shot escape hatch
$no-vibe off                               # exit
```

## Troubleshooting

If the guard is ignored, check that the marker exists with `test -f .no-vibe/active && echo active`, and that you trusted the plugin hooks. Run `$no-vibe off` for normal editing.
