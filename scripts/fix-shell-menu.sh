#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[fix-shell] %s\n' "$1"
}

if [[ "${EUID}" -eq 0 ]]; then
    log "Run this script as a normal user."
    exit 1
fi

NIRI_DIR="${HOME}/.config/niri"
START_FILE="${NIRI_DIR}/shell-switcher-startup.kdl"
BINDS_FILE="${NIRI_DIR}/shell-switcher-binds.kdl"
MAIN_CFG="${NIRI_DIR}/config.kdl"

mkdir -p "${NIRI_DIR}"

cat > "${START_FILE}" << 'EOF'
// Shell Switcher - Startup Configuration
// This file is managed by shell-switch - manual edits will be overwritten
// Current shell: Auto Fallback

spawn-at-startup "dms" "run"
EOF

cat > "${BINDS_FILE}" << 'EOF'
// Shell Switcher - Keybindings
// This file is managed by shell-switch for the switcher and launcher bindings
// Current shell: Auto Fallback

binds {
    // App launcher
    Mod+Space hotkey-overlay-title="Open Launcher" {
        spawn "dms" "ipc" "call" "spotlight" "toggle";
    }

    // Shell switcher picker
    Ctrl+Shift+S hotkey-overlay-title="Switch Desktop Shell" {
        spawn "kitty" "--class=floating-kitty" "shell-switch";
    }
}
EOF

if [[ -f "${MAIN_CFG}" ]]; then
    if ! grep -q 'include "shell-switcher-binds.kdl"' "${MAIN_CFG}"; then
        printf '\ninclude "shell-switcher-binds.kdl"\n' >> "${MAIN_CFG}"
        log "Added missing include for shell-switcher-binds.kdl"
    fi

    if ! grep -q 'include "shell-switcher-startup.kdl"' "${MAIN_CFG}"; then
        printf 'include "shell-switcher-startup.kdl"\n' >> "${MAIN_CFG}"
        log "Added missing include for shell-switcher-startup.kdl"
    fi
fi

if command -v niri >/dev/null 2>&1; then
    niri msg action load-config-file "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 || \
        niri msg action reload-config >/dev/null 2>&1 || true
fi

if ! pgrep -f 'dms run|waybar' >/dev/null 2>&1; then
    if command -v dms >/dev/null 2>&1; then
        nohup dms run >/dev/null 2>&1 &
        log "Started DMS shell"
    elif command -v waybar >/dev/null 2>&1; then
        nohup waybar >/dev/null 2>&1 &
        log "Started Waybar fallback"
    else
        log "Neither DMS nor Waybar is installed."
        exit 1
    fi
fi

log "Done. Menu and Win+Space should work now."
