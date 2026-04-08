#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[pretty-login] %s\n' "$1"
}

if [[ "${EUID}" -eq 0 ]]; then
    log "Run this script as a normal user (it uses sudo internally)."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is required."
    exit 1
fi

log "Installing SDDM..."
sudo pacman -S --needed --noconfirm sddm

CATPPUCCIN_THEME=""
if command -v paru >/dev/null 2>&1; then
    log "Trying to install a Catppuccin SDDM theme from AUR..."
    THEME_PKG="$(paru -Ssq 'sddm-theme-catppuccin|catppuccin-sddm' | head -n 1 || true)"

    if [[ -n "${THEME_PKG}" ]]; then
        paru -S --needed --noconfirm "${THEME_PKG}" || true
    fi
fi

if [[ -d /usr/share/sddm/themes ]]; then
    CATPPUCCIN_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -Ei '^catppuccin' | head -n 1 || true)"
fi

log "Ensuring Niri session entry exists..."
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/niri.desktop >/dev/null << 'EOF'
[Desktop Entry]
Name=Niri
Comment=Niri Wayland Session
Exec=niri-session
Type=Application
EOF

log "Writing SDDM config..."
sudo mkdir -p /etc/sddm.conf.d
if [[ -n "${CATPPUCCIN_THEME}" ]]; then
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null << EOF
[Theme]
Current=${CATPPUCCIN_THEME}
EOF
    log "Using SDDM theme: ${CATPPUCCIN_THEME}"
else
    log "No Catppuccin SDDM theme found; leaving default SDDM theme."
fi

log "Switching display manager to SDDM..."
sudo systemctl disable --now ly 2>/dev/null || true
sudo systemctl disable --now greetd 2>/dev/null || true
sudo systemctl enable --now sddm

log "Done. Reboot to see the new login screen."
