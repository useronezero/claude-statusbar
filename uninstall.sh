#!/bin/bash
# claude-statusbar uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/uninstall.sh | bash
set -e

INSTALL_DIR="${HOME}/.claude"
SCRIPT_PATH="${INSTALL_DIR}/statusline.sh"
SETTINGS_PATH="${INSTALL_DIR}/settings.json"
CACHE_FILE="${TMPDIR:-/tmp}/claude_statusbar_cache.json"

info()  { printf '\033[38;2;166;227;161m%s\033[0m\n' "$1"; }
warn()  { printf '\033[38;2;249;226;175m%s\033[0m\n' "$1"; }

# ─── Remove script ───────────────────────────────────────────────────────────
if [ -f "$SCRIPT_PATH" ]; then
    rm "$SCRIPT_PATH"
    info "Removed $SCRIPT_PATH"
else
    warn "statusline.sh not found — skipping"
fi

# ─── Remove cache ────────────────────────────────────────────────────────────
if [ -f "$CACHE_FILE" ]; then
    rm "$CACHE_FILE"
    info "Removed cache file"
fi

# ─── Remove statusLine from settings.json ────────────────────────────────────
if [ -f "$SETTINGS_PATH" ] && command -v jq >/dev/null 2>&1; then
    if jq -e '.statusLine' "$SETTINGS_PATH" >/dev/null 2>&1; then
        cp "$SETTINGS_PATH" "${SETTINGS_PATH}.bak"
        jq 'del(.statusLine)' "$SETTINGS_PATH" > "${SETTINGS_PATH}.tmp" \
            && mv "${SETTINGS_PATH}.tmp" "$SETTINGS_PATH"
        info "Removed statusLine from settings.json"
    fi
fi

echo ""
info "claude-statusbar uninstalled."
echo "Restart Claude Code to apply changes."
