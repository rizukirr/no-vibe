#!/usr/bin/env bash
#
# bump-version.sh — Update no-vibe plugin version across all files
#
# Usage:
#   ./scripts/bump-version.sh <new-version>
#   ./scripts/bump-version.sh patch|minor|major
#
# Examples:
#   ./scripts/bump-version.sh 0.2.0
#   ./scripts/bump-version.sh patch        # 0.1.0 -> 0.1.1
#   ./scripts/bump-version.sh minor        # 0.1.0 -> 0.2.0
#   ./scripts/bump-version.sh major        # 0.1.0 -> 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT/.claude-plugin/marketplace.json"

VERSION_FILES=("$PLUGIN_JSON" "$MARKETPLACE_JSON")

# --- helpers ---

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

get_current_version() {
    grep -m1 '"version"' "$PLUGIN_JSON" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

validate_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid semver: $1"
}

bump_semver() {
    local current="$1" part="$2"
    IFS='.' read -r major minor patch <<< "$current"
    case "$part" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "$major.$((minor + 1)).0" ;;
        patch) echo "$major.$minor.$((patch + 1))" ;;
        *) die "unknown bump type: $part (use major|minor|patch)" ;;
    esac
}

# --- main ---

[[ $# -ge 1 ]] || die "usage: $0 <version|patch|minor|major>"

CURRENT="$(get_current_version)"
validate_semver "$CURRENT"

case "$1" in
    major|minor|patch)
        NEW="$(bump_semver "$CURRENT" "$1")"
        ;;
    *)
        NEW="$1"
        validate_semver "$NEW"
        ;;
esac

[[ "$NEW" != "$CURRENT" ]] || die "already at $CURRENT"

printf 'bumping: %s -> %s\n' "$CURRENT" "$NEW"

# Replace all "version": "X.Y.Z" occurrences in version files
for f in "${VERSION_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        printf 'warning: %s not found, skipping\n' "$f" >&2
        continue
    fi
    sed -i "s/\"version\": \"$CURRENT\"/\"version\": \"$NEW\"/g" "$f"
    printf '  updated: %s\n' "${f#"$ROOT/"}"
done

# Verify all instances updated
remaining=$(grep -rn "\"version\": \"$CURRENT\"" "${VERSION_FILES[@]}" 2>/dev/null || true)
if [[ -n "$remaining" ]]; then
    printf 'warning: stale version references remain:\n%s\n' "$remaining" >&2
    exit 1
fi

printf 'done. version is now %s\n' "$NEW"
