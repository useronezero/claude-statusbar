#!/bin/bash
# claude-statusbar installer
# Usage: curl -fsSL https://raw.githubusercontent.com/useronezero/claude-statusbar/main/install.sh | bash
set -e

REPO_URL="https://raw.githubusercontent.com/useronezero/claude-statusbar/main"
INSTALL_DIR="${HOME}/.claude"
SCRIPT_PATH="${INSTALL_DIR}/statusline.sh"
SETTINGS_PATH="${INSTALL_DIR}/settings.json"

info()  { printf '\033[38;2;166;227;161m%s\033[0m\n' "$1"; }
warn()  { printf '\033[38;2;249;226;175m%s\033[0m\n' "$1"; }
error() { printf '\033[38;2;243;139;168m%s\033[0m\n' "$1"; }

# ─── Check dependencies ──────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
    error "Error: jq is required but not installed."
    echo ""
    echo "Install jq:"
    echo "  macOS:  brew install jq"
    echo "  Ubuntu: sudo apt install jq"
    echo "  Fedora: sudo dnf install jq"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    error "Error: curl is required but not installed."
    exit 1
fi

# ─── Download statusline.sh ──────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

info "Downloading statusline.sh..."
curl -fsSL "${REPO_URL}/statusline.sh" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# ─── Configure settings.json ─────────────────────────────────────────────────
STATUSLINE_CONFIG='{"type":"command","command":"bash '"$SCRIPT_PATH"'","refresh":150}'

if [ -f "$SETTINGS_PATH" ]; then
    # Backup existing settings
    cp "$SETTINGS_PATH" "${SETTINGS_PATH}.bak"
    info "Backed up settings.json → settings.json.bak"

    # Merge statusLine into existing settings
    jq --argjson sl "$STATUSLINE_CONFIG" '.statusLine = $sl' "$SETTINGS_PATH" > "${SETTINGS_PATH}.tmp" \
        && mv "${SETTINGS_PATH}.tmp" "$SETTINGS_PATH"
else
    # Create new settings file
    echo "{\"statusLine\":$STATUSLINE_CONFIG}" | jq '.' > "$SETTINGS_PATH"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
info "claude-statusbar installed successfully!"
echo ""
echo "  Script:   $SCRIPT_PATH"
echo "  Settings: $SETTINGS_PATH"
echo ""
echo "Restart Claude Code to see the statusline."
echo "To uninstall: curl -fsSL ${REPO_URL}/uninstall.sh | bash"
