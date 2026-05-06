#!/usr/bin/env bash
# install.sh — auto-detect available CLIs and install no-vibe for each.
#
# Usage:
#   ./install/install.sh               # detect + offer per runtime
#   ./install/install.sh claude        # install only for the named runtime
#   ./install/install.sh all           # install for every runtime, no prompts

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET="${1:-detect}"

available=()
command -v claude >/dev/null 2>&1 && available+=("claude")
command -v opencode >/dev/null 2>&1 && available+=("opencode")
command -v pi >/dev/null 2>&1 && available+=("pi")
command -v codex >/dev/null 2>&1 && available+=("codex")
command -v gemini >/dev/null 2>&1 && available+=("gemini")

run_installer() {
    bash "$REPO_ROOT/install/install-$1.sh"
}

case "$TARGET" in
    claude|opencode|pi|codex|gemini)
        run_installer "$TARGET"
        ;;
    all)
        for r in claude opencode pi codex gemini; do
            run_installer "$r"
        done
        ;;
    detect)
        if [ "${#available[@]}" -eq 0 ]; then
            echo "No supported CLI detected. Pass a runtime name explicitly:" >&2
            echo "  ./install/install.sh {claude|opencode|pi|codex|gemini|all}" >&2
            exit 1
        fi
        echo "Detected: ${available[*]}"
        for r in "${available[@]}"; do
            printf "Install for %s? [y/N] " "$r"
            read -r ans
            case "$ans" in
                y|Y|yes|YES) run_installer "$r" ;;
                *) echo "skipped $r" ;;
            esac
        done
        ;;
    *)
        echo "Unknown target: $TARGET" >&2
        echo "Usage: ./install/install.sh {claude|opencode|pi|codex|gemini|all|detect}" >&2
        exit 1
        ;;
esac
