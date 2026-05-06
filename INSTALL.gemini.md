# Install no-vibe — Gemini CLI

Gemini CLI uses extensions. Install copies the extension tree into Gemini's extensions directory.

## Steps

```bash
git clone https://github.com/rizukirr/no-vibe.git ~/tools/no-vibe
bash ~/tools/no-vibe/install/install-gemini.sh
```

Default destination: `~/.gemini/extensions/no-vibe/`.

To install elsewhere: `NO_VIBE_DEST=/custom/path bash ~/tools/no-vibe/install/install-gemini.sh`

Restart Gemini CLI after install.

## Verify

- `~/.gemini/extensions/no-vibe/gemini-extension.json` exists.
- `~/.gemini/extensions/no-vibe/GEMINI.md` exists.
- `~/.gemini/extensions/no-vibe/.gemini/commands/` contains five `.toml` command files.
- `~/.gemini/extensions/no-vibe/skills/no-vibe/SKILL.md` exists.
- `~/.no-vibe/NO-VIBE.md` exists (seeded if missing).
- After Gemini restart, the slash commands `/no-vibe`, `/no-vibe-btw`, `/no-vibe-challenge`, `/no-vibe-forget`, `/no-vibe-clear` are available.

## What gets installed

- Extension manifest (`gemini-extension.json`).
- `GEMINI.md` (auto-loaded by Gemini CLI on session start).
- Five `.toml` command definitions under `.gemini/commands/`.
- Skill prose under `skills/no-vibe/`.
- Global `~/.no-vibe/NO-VIBE.md` seeded if missing.

## Enforcement

**Soft.** Gemini CLI has no write-hook surface for third-party extensions. Enforcement is instruction-only: the rule lives in `GEMINI.md` and binds the AI behaviorally. There is no kernel-level guard. If the model deviates, only the instruction stops it.
