#!/usr/bin/env bash
# Verifies that scripts/sync.sh produces no diff against committed runtime
# files. Catches drift between /shared/ and runtimes/codex/AGENTS.md +
# runtimes/gemini/GEMINI.md + .gemini/commands/*.toml.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
. "$SCRIPT_DIR/helpers.sh"

# Run sync, then check files match.
bash "$REPO_ROOT/scripts/sync.sh" >/dev/null 2>&1

GENERATED_FILES=(
    "$REPO_ROOT/runtimes/codex/AGENTS.md"
    "$REPO_ROOT/runtimes/gemini/GEMINI.md"
)
for f in "$REPO_ROOT/runtimes/gemini/.gemini/commands"/*.toml; do
    [ -f "$f" ] && GENERATED_FILES+=("$f")
done
# Claude runtime tree (populated for marketplace install)
for f in "$REPO_ROOT/runtimes/claude/skills/no-vibe"/*.md; do
    [ -f "$f" ] && GENERATED_FILES+=("$f")
done
for f in "$REPO_ROOT/runtimes/claude/commands"/*.md; do
    [ -f "$f" ] && GENERATED_FILES+=("$f")
done
for f in "$REPO_ROOT/runtimes/claude/shared/guard"/*.json; do
    [ -f "$f" ] && GENERATED_FILES+=("$f")
done

drift=0
for f in "${GENERATED_FILES[@]}"; do
    [ -f "$f" ] || { fail "missing generated file: $f"; drift=1; continue; }
    case "$f" in
        *.json)
            # JSON files copied verbatim; no header check needed.
            pass "generated JSON present: $(basename "$f")"
            ;;
        *)
            head=$(head -10 "$f")
            if echo "$head" | grep -qE "AUTO-GENERATED FROM"; then
                pass "auto-generated header present: $(basename "$f")"
            else
                fail "auto-generated header missing: $f"
                drift=1
            fi
            ;;
    esac
done

# Claude marketplace.json at repo root must exist and point at runtimes/claude.
root_marketplace="$REPO_ROOT/.claude-plugin/marketplace.json"
if [ -f "$root_marketplace" ]; then
    src=$(jq -r '.plugins[0].source // ""' "$root_marketplace")
    if [ "$src" = "./runtimes/claude" ]; then
        pass "root marketplace.json source points to ./runtimes/claude"
    else
        fail "root marketplace.json source is '$src', expected './runtimes/claude'"
    fi
else
    fail "missing root .claude-plugin/marketplace.json"
fi

# Instruction-only runtimes (Codex, Gemini, Pi) must inline ALL shared/skill/*.md
# files, not just SKILL.md. They have no lazy file-load path for the model,
# so SKILL.md's references to phases.md / curriculum.md / etc. would be
# dangling pointers without bundling.
SKILL_DOCS=(phases.md teaching-style.md reference-grounding.md curriculum.md)
for runtime_file in \
    "$REPO_ROOT/runtimes/codex/AGENTS.md" \
    "$REPO_ROOT/runtimes/gemini/GEMINI.md" \
    "$REPO_ROOT/runtimes/codex/skills/no-vibe/SKILL.md"
do
    [ -f "$runtime_file" ] || continue
    name=$(basename "$(dirname "$runtime_file")")/$(basename "$runtime_file")
    for doc in "${SKILL_DOCS[@]}"; do
        if grep -q "shared/skill/$doc" "$runtime_file"; then
            pass "$name bundles $doc"
        else
            fail "$name missing $doc — instruction-only runtime needs full skill bundle"
        fi
    done
done

# Pi and OpenCode extensions must list all skill filenames in their bootstrap loaders.
declare -A JS_EXTS=(
    [pi]="$REPO_ROOT/runtimes/pi/.pi-plugin/extensions/no-vibe/index.ts"
    [opencode]="$REPO_ROOT/runtimes/opencode/plugins/no-vibe.js"
)
for label in "${!JS_EXTS[@]}"; do
    ext="${JS_EXTS[$label]}"
    [ -f "$ext" ] || continue
    for doc in SKILL.md "${SKILL_DOCS[@]}"; do
        if grep -q "\"$doc\"" "$ext"; then
            pass "$label loads $doc"
        else
            fail "$label does not reference $doc — will only inline SKILL.md"
        fi
    done
done

# Run sync --check; should exit 0 (no drift).
if bash "$REPO_ROOT/scripts/sync.sh" --check >/dev/null 2>&1; then
    pass "sync --check passes (no drift)"
else
    fail "sync --check reports drift — run 'bash scripts/sync.sh' and commit"
fi

# Version parity.
if bash "$REPO_ROOT/scripts/bump-version.sh" --check >/dev/null 2>&1; then
    pass "version parity OK across manifests"
else
    fail "version mismatch — run 'bash scripts/bump-version.sh \$VERSION'"
fi

summary
