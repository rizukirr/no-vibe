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
4. Run `$no-vibe off` — should remove marker

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

## Troubleshooting

**Skills not discovered:**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Guard ignored:**
- Check marker exists: `test -f .no-vibe/active && echo "active"`
- Remind the model that no-vibe mode is active or use `/no-vibe off` for normal editing
