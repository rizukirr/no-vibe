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
2. Run `/no-vibe on` — should create `.no-vibe/active` marker
3. Try editing a project file — should be blocked with "no-vibe mode is active" message
4. Run `/no-vibe off` — should remove marker

## Requirements

- Codex CLI
- `jq` (for the write-guard hook)

## Usage

```
/no-vibe build a REST API handler          # one-shot lesson
/no-vibe on                                 # persistent mode
/no-vibe --ref pytorch --mode concept       # with reference + mode
/no-vibe:challenge                          # get a coding challenge
/no-vibe off                                # exit
```

## Troubleshooting

**Skills not discovered:**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Hook not blocking writes:**
- Verify `jq` is installed: `which jq`
- Check marker exists: `test -f .no-vibe/active && echo "active"`
