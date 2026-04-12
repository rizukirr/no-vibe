# no-vibe — Codex Installation

## Option 1: Plugin Install (Recommended)

Codex supports Claude Code plugin format natively:

```bash
claude plugin add rizukirr/no-vibe
```

This installs hooks, commands, and skills automatically.

## Option 2: Manual Symlink

```bash
# Clone the repo
git clone https://github.com/rizukirr/no-vibe.git ~/.codex/no-vibe

# Symlink skills into Codex discovery path
mkdir -p ~/.agents/skills
ln -s ~/.codex/no-vibe/skills ~/.agents/skills/no-vibe

# Restart Codex
```

> **Note:** Manual symlink only exposes skills. Hooks (write guard) and slash commands require the plugin install method.

## Verify Installation

1. Start a Codex session in any project
2. Run `/no-vibe on` — should create `.no-vibe/active` marker
3. Try editing a project file — should be blocked with "no-vibe mode is active" message
4. Run `/no-vibe off` — should remove marker

## Requirements

- Codex CLI
- `jq` (for the write-guard hook)

## Usage

```bash
/no-vibe build a REST API handler          # one-shot lesson
/no-vibe on                                 # persistent mode
/no-vibe --ref pytorch --mode concept       # with reference + mode
/no-vibe:challenge                          # get a coding challenge
/no-vibe off                                # exit
```

## Troubleshooting

**Hook not blocking writes:**
- Verify `jq` is installed: `which jq`
- Check marker exists: `test -f .no-vibe/active && echo "active"`

**Skills not discovered (symlink method):**
- Verify symlink: `ls -la ~/.agents/skills/no-vibe`
- Should point to `~/.codex/no-vibe/skills`

**Commands not found:**
- Manual symlink does not register commands — use plugin install method instead
