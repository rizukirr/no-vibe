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

## Offline / local fallback

If the marketplace install fails, clone and run the local installer:

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-claude.sh
```

This copies `runtimes/claude/` into `~/.claude/plugins/no-vibe/`. Restart Claude Code afterward.

## What gets installed

- Skill prose and commands (auto-discovered by Claude).
- Three hooks: `block-writes.sh`, `block-bash-writes.sh`, `status.sh`.
- Guard data in `shared/guard/*.json` (read by the hooks at runtime).
- Seeds `~/.no-vibe/NO-VIBE.md` from a template if missing.

## Enforcement

**Hard.** File writes (Edit/Write/NotebookEdit/MultiEdit/ApplyPatch) and dangerous Bash patterns (redirects, `tee`, `sed -i`, `cp`, `mv`, `dd of=`) are blocked by hooks while no-vibe mode is active. Writes to `.no-vibe/`, `~/.no-vibe/`, `/tmp`, and `/dev/null` family are allowed.
