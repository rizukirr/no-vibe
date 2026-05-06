#!/usr/bin/env bash
# bump-version.sh — set the version across all manifest files from VERSION.
#
# Usage:
#   scripts/bump-version.sh 2.1.0          # set to 2.1.0
#   scripts/bump-version.sh --check        # verify all manifests match VERSION
#
# Updates: VERSION, package.json, runtimes/claude/.claude-plugin/plugin.json,
# runtimes/claude/.claude-plugin/marketplace.json, runtimes/gemini/gemini-extension.json,
# runtimes/pi/.pi-plugin/plugin.json.

set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION_FILE="$REPO_ROOT/VERSION"

CHECK_MODE=0
if [ "${1:-}" = "--check" ]; then
    CHECK_MODE=1
    new_version=$(tr -d '[:space:]' < "$VERSION_FILE")
elif [ -n "${1:-}" ]; then
    new_version="$1"
else
    new_version=$(tr -d '[:space:]' < "$VERSION_FILE")
fi

manifests=(
    "$REPO_ROOT/package.json"
    "$REPO_ROOT/.claude-plugin/marketplace.json"
    "$REPO_ROOT/runtimes/claude/.claude-plugin/plugin.json"
    "$REPO_ROOT/runtimes/gemini/gemini-extension.json"
    "$REPO_ROOT/runtimes/pi/.pi-plugin/plugin.json"
)

# marketplace.json has nested .plugins[].version too — handle it.

if [ "$CHECK_MODE" = "1" ]; then
    fail=0
    for f in "${manifests[@]}"; do
        [ -f "$f" ] || continue
        got=$(jq -r '.version // ""' "$f")
        if [ "$got" != "$new_version" ]; then
            echo "MISMATCH: $f has '$got', expected '$new_version'" >&2
            fail=1
        fi
    done
    mp="$REPO_ROOT/.claude-plugin/marketplace.json"
    if [ -f "$mp" ]; then
        nested=$(jq -r '.plugins[0].version // ""' "$mp")
        if [ "$nested" != "$new_version" ]; then
            echo "MISMATCH: $mp .plugins[0].version has '$nested', expected '$new_version'" >&2
            fail=1
        fi
    fi
    [ "$fail" = "0" ] && echo "version parity OK ($new_version)"
    exit "$fail"
fi

echo "$new_version" > "$VERSION_FILE"

for f in "${manifests[@]}"; do
    [ -f "$f" ] || continue
    tmp=$(mktemp)
    jq --arg v "$new_version" '.version = $v' "$f" > "$tmp" && mv "$tmp" "$f"
    echo "updated: $f"
done

# Nested marketplace plugins[].version.
mp="$REPO_ROOT/.claude-plugin/marketplace.json"
if [ -f "$mp" ]; then
    tmp=$(mktemp)
    jq --arg v "$new_version" '.plugins[0].version = $v | .version = $v' "$mp" > "$tmp" && mv "$tmp" "$mp"
    echo "updated: $mp (nested plugins[0].version)"
fi

echo "bumped to $new_version."
