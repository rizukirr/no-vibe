#!/usr/bin/env bash
# sync.sh — regenerate per-runtime layout from /shared/.
#
# Generated files start with a "AUTO-GENERATED FROM /shared" header.
# Run this whenever you change /shared/skill/, /shared/guard/, or
# /shared/commands/. CI runs --check to verify no drift.

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHARED="$REPO_ROOT/shared"
RUNTIMES="$REPO_ROOT/runtimes"

CHECK_MODE=0
[ "${1:-}" = "--check" ] && CHECK_MODE=1

emit() {
    if [ "$CHECK_MODE" = "1" ]; then
        local target="$1"
        local content="$2"
        if ! diff -q <(printf '%s' "$content") "$target" >/dev/null 2>&1; then
            echo "DRIFT: $target" >&2
            return 1
        fi
    else
        printf '%s' "$2" > "$1"
        echo "wrote: $1"
    fi
}

# --- Pull shared content ---

if [ ! -f "$SHARED/skill/SKILL.md" ]; then
    echo "ERROR: $SHARED/skill/SKILL.md not found" >&2
    exit 1
fi

# Strip frontmatter from SKILL.md.
skill_body=$(awk '
    BEGIN { in_fm=0; done=0 }
    NR==1 && /^---$/ { in_fm=1; next }
    in_fm && /^---$/ { in_fm=0; done=1; next }
    in_fm { next }
    { print }
' "$SHARED/skill/SKILL.md")

# Format guard/patterns.json into prose for instruction-only runtimes.
patterns_prose=$(cat <<'EOF'
**Safe targets** (writes allowed):

- `.no-vibe/**` (any path under the project's no-vibe directory)
- `$HOME/.no-vibe/**` (any path under the global no-vibe directory)
- `/tmp/**`, `/var/tmp/**`
- `/dev/null`, `/dev/stdout`, `/dev/stderr`, `/dev/tty`, `/dev/fd/*`

**Dangerous patterns** (refused outside the safe targets):

- Output redirection: `>`, `>>`, `&>`, `&>>` (fd-merge `2>&1` alone is fine)
- `tee` (each non-flag arg is a destination)
- `sed -i` / `sed --in-place` (each non-flag arg after the script is mutated)
- `cp`, `mv`, `install` (last non-flag arg is the destination)
- `dd of=PATH`
- `cat <<EOF > PATH` heredoc redirects

**Fail-closed:** variable or command-substituted destinations (`$VAR`, `$(...)`, backticks) — refuse, do not try to resolve.
EOF
)

# --- Generate Codex AGENTS.md ---

codex_template="$RUNTIMES/codex/AGENTS.md.template"
codex_target="$RUNTIMES/codex/AGENTS.md"
if [ -f "$codex_template" ]; then
    rendered=$(awk -v skill="$skill_body" -v patterns="$patterns_prose" '
        /<!-- INJECT:SKILL_BODY -->/ { print skill; next }
        /<!-- INJECT:GUARD_PATTERNS -->/ { print patterns; next }
        { print }
    ' "$codex_template")
    emit "$codex_target" "$rendered"
fi

# --- Generate Gemini GEMINI.md ---

gemini_template="$RUNTIMES/gemini/GEMINI.md.template"
gemini_target="$RUNTIMES/gemini/GEMINI.md"
if [ -f "$gemini_template" ]; then
    rendered=$(awk -v skill="$skill_body" -v patterns="$patterns_prose" '
        /<!-- INJECT:SKILL_BODY -->/ { print skill; next }
        /<!-- INJECT:GUARD_PATTERNS -->/ { print patterns; next }
        { print }
    ' "$gemini_template")
    emit "$gemini_target" "$rendered"
fi

# --- Convert shared/commands/*.md → Gemini .toml ---
# Gemini commands use TOML with a `prompt = """..."""` triple-quoted body.

mkdir -p "$RUNTIMES/gemini/.gemini/commands"
for src in "$SHARED/commands"/*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src" .md)
    dest="$RUNTIMES/gemini/.gemini/commands/${name}.toml"

    description=$(awk '
        /^description:/ { sub(/^description:[[:space:]]*/, ""); print; exit }
    ' "$src")

    body=$(awk '
        BEGIN { in_fm=0; done=0 }
        NR==1 && /^---$/ { in_fm=1; next }
        in_fm && /^---$/ { in_fm=0; done=1; next }
        in_fm { next }
        { print }
    ' "$src")

    rendered=$(printf '# AUTO-GENERATED FROM shared/commands/%s — DO NOT EDIT\n\ndescription = "%s"\n\nprompt = """\n%s\n"""\n' \
        "${name}.md" "${description//\"/\\\"}" "$body")

    emit "$dest" "$rendered"
done

# --- Populate runtimes/claude/ as a self-contained Claude plugin tree ---
# Claude marketplace clones the repo and reads the plugin at the `source`
# directory specified in /.claude-plugin/marketplace.json. For us, source
# is ./runtimes/claude. Claude auto-discovers skills at <source>/skills/<name>/
# and commands at <source>/commands/. Hooks read <source>/shared/guard/*.json.
# Populate all three from /shared/.

CLAUDE_GENERATED_HEADER='<!-- AUTO-GENERATED FROM /shared — DO NOT EDIT — run scripts/sync.sh -->'

claude_skills_dir="$RUNTIMES/claude/skills/no-vibe"
claude_commands_dir="$RUNTIMES/claude/commands"
claude_guard_dir="$RUNTIMES/claude/shared/guard"

if [ "$CHECK_MODE" = "0" ]; then
    mkdir -p "$claude_skills_dir" "$claude_commands_dir" "$claude_guard_dir"
fi

# Skill / command files have YAML frontmatter that Claude parses. Insert
# the AUTO-GENERATED header AFTER the closing `---` so frontmatter detection
# still sees `---` on line 1. For files without frontmatter, prepend.
inject_header() {
    local src="$1"
    local header="$2"
    awk -v hdr="$header" '
        BEGIN { in_fm=0; emitted=0; first=1 }
        first && /^---$/ { print; in_fm=1; first=0; next }
        first { print hdr; print ""; print; emitted=1; first=0; next }
        in_fm && /^---$/ { print; print ""; print hdr; in_fm=0; emitted=1; next }
        { print }
    ' "$src"
}

# Skill files.
for src in "$SHARED/skill"/*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dest="$claude_skills_dir/$name"
    rendered=$(inject_header "$src" "$CLAUDE_GENERATED_HEADER")
    emit "$dest" "$rendered"
done

# Command files.
for src in "$SHARED/commands"/*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dest="$claude_commands_dir/$name"
    rendered=$(inject_header "$src" "$CLAUDE_GENERATED_HEADER")
    emit "$dest" "$rendered"
done

# Guard data — JSON, copied verbatim. Hooks read these at runtime.
for src in "$SHARED/guard"/*.json; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dest="$claude_guard_dir/$name"
    body=$(cat "$src")
    emit "$dest" "$body"
done

# --- Verify version parity ---

VERSION_FILE="$REPO_ROOT/VERSION"
if [ -f "$VERSION_FILE" ]; then
    expected=$(tr -d '[:space:]' < "$VERSION_FILE")
    for f in \
        "$REPO_ROOT/package.json" \
        "$REPO_ROOT/.claude-plugin/marketplace.json" \
        "$RUNTIMES/claude/.claude-plugin/plugin.json" \
        "$RUNTIMES/gemini/gemini-extension.json" \
        "$RUNTIMES/pi/.pi-plugin/plugin.json"
    do
        [ -f "$f" ] || continue
        got=$(jq -r '.version // ""' "$f" 2>/dev/null)
        if [ "$got" != "$expected" ]; then
            echo "VERSION MISMATCH: $f has '$got', expected '$expected'" >&2
            [ "$CHECK_MODE" = "1" ] && exit 1
        fi
    done
fi

echo "sync complete."
