#!/usr/bin/env sh
# no-vibe installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rizukirr/no-vibe/main/install.sh | sh
#
# Environment overrides:
#   NO_VIBE_DIR   Install destination (default: ~/.claude/plugins/no-vibe)
#   NO_VIBE_REPO  Git repo URL (default: https://github.com/rizukirr/no-vibe.git)
#   NO_VIBE_REF   Branch, tag, or commit to check out (default: main)

set -eu

REPO="${NO_VIBE_REPO:-https://github.com/rizukirr/no-vibe.git}"
REF="${NO_VIBE_REF:-main}"
DEST="${NO_VIBE_DIR:-$HOME/.claude/plugins/no-vibe}"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || error "missing required command: $1"
}

need git
need jq

info "installing no-vibe"
info "  repo: $REPO"
info "  ref:  $REF"
info "  dest: $DEST"

mkdir -p "$(dirname "$DEST")"

if [ -d "$DEST/.git" ]; then
    info "existing checkout found, updating"
    git -C "$DEST" fetch --depth 1 origin "$REF"
    git -C "$DEST" checkout -q FETCH_HEAD
else
    if [ -e "$DEST" ]; then
        error "destination exists and is not a git checkout: $DEST"
    fi
    git clone --depth 1 --branch "$REF" "$REPO" "$DEST"
fi

# Ensure the hook is executable — required by the PreToolUse wiring.
HOOK="$DEST/.claude-plugin/hooks/block-writes.sh"
if [ -f "$HOOK" ]; then
    chmod +x "$HOOK"
else
    warn "hook script not found at $HOOK — plugin layout may have changed"
fi

info "installed to $DEST"
cat <<'EOF'

Next steps:
  1. Make sure Claude Code loads plugins from ~/.claude/plugins/ (or point
     it at the install directory you chose).
  2. Restart Claude Code so it picks up the plugin.
  3. In any project, run:  /no-vibe on
EOF
