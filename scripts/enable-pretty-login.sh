#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
    printf '[pretty-login] %s\n' "$1"
}

install_aur_first_available() {
    local pkg
    for pkg in "$@"; do
        if paru -S --needed --noconfirm "$pkg"; then
            log "Installed AUR package: ${pkg}"
            return 0
        fi
    done
    return 1
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

SELECTED_THEME=""
SUGAR_THEME=""
CATPPUCCIN_THEME=""

if command -v paru >/dev/null 2>&1; then
    log "Trying to install SDDM themes from AUR..."
    install_aur_first_available \
        sddm-sugar-candy-git \
        sddm-theme-sugar-candy-git \
        catppuccin-sddm-theme-git \
        sddm-theme-catppuccin \
        catppuccin-sddm \
        || true
fi

if [[ -d /usr/share/sddm/themes ]]; then
    SUGAR_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -Ei 'sugar[-_ ]?candy' | head -n 1 || true)"
    CATPPUCCIN_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -Ei '^catppuccin' | head -n 1 || true)"
fi

if [[ -n "${SUGAR_THEME}" ]]; then
    SELECTED_THEME="${SUGAR_THEME}"
elif [[ -n "${CATPPUCCIN_THEME}" ]]; then
    SELECTED_THEME="${CATPPUCCIN_THEME}"
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
if [[ -n "${SELECTED_THEME}" ]]; then
    sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null << EOF
[Theme]
Current=${SELECTED_THEME}
EOF
    log "Using SDDM theme: ${SELECTED_THEME}"
else
    log "No Catppuccin SDDM theme found; leaving default SDDM theme."
fi

if [[ -n "${SUGAR_THEME}" ]]; then
    THEME_DIR="/usr/share/sddm/themes/${SUGAR_THEME}"
    WALLPAPER_SRC="${REPO_DIR}/assets/wallpapers/wallpaper.png"
    WALLPAPER_DST="${THEME_DIR}/Backgrounds/donarch-wallpaper.png"

    if [[ -f "${WALLPAPER_SRC}" ]]; then
        sudo mkdir -p "${THEME_DIR}/Backgrounds"
        sudo cp "${WALLPAPER_SRC}" "${WALLPAPER_DST}"
    else
        WALLPAPER_DST=""
    fi

    log "Customizing Sugar Candy theme style..."
    if [[ -n "${WALLPAPER_DST}" ]]; then
        sudo tee "${THEME_DIR}/theme.conf.user" >/dev/null << EOF
Background="${WALLPAPER_DST}"
DimBackgroundImage="0.20"
BlurRadius="18"
ScaleImageCropped="true"

ScreenPadding="40"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
FullBlur="false"
FormBackgroundColor="\"#11111bdd\""
BackgroundColor="\"#1e1e2eff\""
MainColor="\"#cba6f7ff\""
AccentColor="\"#89b4faff\""
OverrideLoginButtonTextColor="\"#11111bff\""
RoundCorners="24"
HeaderText="Welcome"
EOF
    else
        sudo tee "${THEME_DIR}/theme.conf.user" >/dev/null << 'EOF'
DimBackgroundImage="0.20"
BlurRadius="18"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
RoundCorners="24"
HeaderText="Welcome"
EOF
    fi
fi

log "Switching display manager to SDDM..."
sudo systemctl disable --now ly 2>/dev/null || true
sudo systemctl disable --now greetd 2>/dev/null || true
sudo systemctl enable --now sddm

log "Done. Reboot to see the new login screen."
