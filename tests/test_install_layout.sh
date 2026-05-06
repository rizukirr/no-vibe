#!/usr/bin/env bash
# Verifies installer output layout for runtimes with extension-based
# bootstrap loaders (Pi, OpenCode). Both runtimes resolve SHARED_DIR at
# runtime by walking up to find a `shared/` directory. The installer must
# populate `$DEST/shared/skill/` so buildBootstrap() can read the full
# skill bundle (SKILL + phases + teaching-style + reference-grounding +
# curriculum). If skill/ is missing, the runtime falls through to a
# one-line fallback string and the user gets no teaching discipline.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
. "$SCRIPT_DIR/helpers.sh"

tmpbase=$(mktemp -d)
trap 'rm -rf "$tmpbase"' EXIT

SKILL_FILES=(SKILL.md phases.md teaching-style.md reference-grounding.md curriculum.md)

run_install_and_check() {
    local label="$1" script="$2"
    local dest="$tmpbase/$label/dest"
    local fakehome="$tmpbase/$label/home"
    mkdir -p "$dest" "$fakehome"

    # Use a fake HOME so the Pi installer's "already installed" guard
    # (which checks $HOME/.agents/skills/no-vibe etc.) doesn't false-trip
    # when the developer running tests has the plugin installed locally.
    if ! NO_VIBE_DEST="$dest" HOME="$fakehome" bash "$script" >"$tmpbase/$label.log" 2>&1; then
        fail "$label installer exited non-zero"
        cat "$tmpbase/$label.log" >&2
        return
    fi

    for f in "${SKILL_FILES[@]}"; do
        if [ -f "$dest/shared/skill/$f" ]; then
            pass "$label install: shared/skill/$f present"
        else
            fail "$label install: shared/skill/$f MISSING — buildBootstrap() will fall back to default"
        fi
    done

    # Native skill loader path also gets the files (parity check).
    for f in "${SKILL_FILES[@]}"; do
        if [ -f "$dest/skills/no-vibe/$f" ]; then
            pass "$label install: skills/no-vibe/$f present"
        else
            fail "$label install: skills/no-vibe/$f MISSING"
        fi
    done
}

run_install_and_check pi "$REPO_ROOT/install/install-pi.sh"
run_install_and_check opencode "$REPO_ROOT/install/install-opencode.sh"

summary
