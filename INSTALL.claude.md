# Install no-vibe — Claude Code

The recommended path is the marketplace (no clone required). Use the offline path only if the user can't reach the marketplace or wants a pinned local version.

## Recommended: marketplace install

Tell the user to run these two slash commands in Claude Code:

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Then restart Claude Code.

## Verify

After restart, the user should see four new slash commands:

- `/no-vibe`
- `/no-vibe-btw`
- `/no-vibe-challenge`
- `/no-vibe-forget`
- `/no-vibe-clear`

And `/plugin` should list `no-vibe` at version `2.0.0`.

## Offline / local fallback (script)

If the marketplace install fails, clone and run the local installer:

```bash
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-claude.sh
```

This copies `runtimes/claude/` into `~/.claude/plugins/no-vibe/`. Restart Claude Code afterward.

## Manual installation (no script)

For when the script can't be run. These commands replicate `install/install-claude.sh`.

**Environment:** the commands below are bash. **If the user is on Windows**, translate to whichever shell they have — PowerShell, Git Bash, or WSL. Use `$env:USERPROFILE` (PowerShell) or `%USERPROFILE%` (cmd) instead of `$HOME`. On PowerShell, use `Copy-Item -Recurse` for `cp -R`, `New-Item -ItemType Directory -Force` for `mkdir -p`. The clone, sync, and copy steps are the same logical operations on every OS.

```bash
# 1. Clone
git clone -b v2 https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
cd ~/tools/no-vibe

# 2. Regenerate runtimes/claude/ from /shared/ (populates skills/, commands/, shared/guard/)
bash scripts/sync.sh

# 3. Copy the self-contained Claude plugin tree
DEST="$HOME/.claude/plugins/no-vibe"
mkdir -p "$DEST"
cp -R runtimes/claude/. "$DEST/"
chmod +x "$DEST/hooks"/*.sh

# 4. Seed global ~/.no-vibe/ if first install
mkdir -p "$HOME/.no-vibe/memory"
[ -f "$HOME/.no-vibe/NO-VIBE.md" ] || cp shared/templates/NO-VIBE.global.md "$HOME/.no-vibe/NO-VIBE.md"
[ -f "$HOME/.no-vibe/memory/README.md" ] || cp shared/templates/memory-readme.md "$HOME/.no-vibe/memory/README.md"

# 5. Clean up — the clone is no longer needed
cd ~ && rm -rf ~/tools/no-vibe
```

Then restart Claude Code.

## What gets installed

- Skill prose and commands (auto-discovered by Claude).
- Three hooks: `block-writes.sh`, `block-bash-writes.sh`, `status.sh`.
- Guard data in `shared/guard/*.json` (read by the hooks at runtime).
- Seeds `~/.no-vibe/NO-VIBE.md` from a template if missing.

## Enforcement

**Hard.** File writes (Edit/Write/NotebookEdit/MultiEdit/ApplyPatch) and dangerous Bash patterns (redirects, `tee`, `sed -i`, `cp`, `mv`, `dd of=`) are blocked by hooks while no-vibe mode is active. Writes to `.no-vibe/`, `~/.no-vibe/`, `/tmp`, and `/dev/null` family are allowed.
