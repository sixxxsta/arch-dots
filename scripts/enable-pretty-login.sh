#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
    printf '[pretty-login] %s\n' "$1"
}

detect_current_wallpaper() {
    local user_home
    user_home="${HOME}"
    local cfg
    local wp

    # Try to read currently configured swaybg wallpaper from Niri startup.
    cfg="${user_home}/.config/niri/startup.kdl"
    if [[ -f "${cfg}" ]]; then
        wp="$(grep -Eo 'swaybg -i "[^"]+"' "${cfg}" | head -n 1 | sed -E 's/^swaybg -i "(.*)"$/\1/' || true)"
        if [[ -n "${wp}" ]]; then
            wp="${wp/#\$HOME/${user_home}}"
            [[ -f "${wp}" ]] && echo "${wp}" && return 0
        fi
    fi

    # Common DonArch wallpaper locations.
    for wp in \
        "${user_home}/.config/niri/wallpapers/wallpaper.png" \
        "${user_home}/.config/hypr/wallpapers/wallpaper.png" \
        "${user_home}/.config/donarch/assets/wallpapers/wallpaper.png" \
        "${REPO_DIR}/assets/wallpapers/wallpaper.png"; do
        if [[ -f "${wp}" ]]; then
            echo "${wp}"
            return 0
        fi
    done

    return 1
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

install_sugar_candy_from_git() {
    local target_theme_dir="/usr/share/sddm/themes/sugar-candy"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if ! command -v git >/dev/null 2>&1; then
        log "git is required for Sugar Candy fallback install."
        rm -rf "${tmp_dir}"
        return 1
    fi

    log "Installing Sugar Candy theme from GitHub fallback..."
    if git clone --depth 1 https://github.com/Kangie/sddm-sugar-candy.git "${tmp_dir}/sugar-candy"; then
        sudo rm -rf "${target_theme_dir}"
        sudo mkdir -p "${target_theme_dir}"
        sudo cp -r "${tmp_dir}/sugar-candy/"* "${target_theme_dir}/"
        rm -rf "${tmp_dir}"
        log "Installed fallback theme to ${target_theme_dir}"
        return 0
    fi

    rm -rf "${tmp_dir}"
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
GENERIC_THEME=""

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

# If AUR did not provide Sugar Candy, try direct GitHub fallback.
if [[ ! -d /usr/share/sddm/themes/sugar-candy ]]; then
    install_sugar_candy_from_git || true
fi

if [[ -d /usr/share/sddm/themes ]]; then
    SUGAR_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -Ei 'sugar[-_ ]?candy' | head -n 1 || true)"
    CATPPUCCIN_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -Ei '^catppuccin' | head -n 1 || true)"
    GENERIC_THEME="$(find /usr/share/sddm/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n 1 || true)"
fi

if [[ -n "${SUGAR_THEME}" ]]; then
    SELECTED_THEME="${SUGAR_THEME}"
elif [[ -n "${CATPPUCCIN_THEME}" ]]; then
    SELECTED_THEME="${CATPPUCCIN_THEME}"
elif [[ -n "${GENERIC_THEME}" ]]; then
    SELECTED_THEME="${GENERIC_THEME}"
fi

# If Sugar Candy is unavailable, fall back to a built-in theme with cleaner look.
if [[ -z "${SELECTED_THEME}" ]]; then
    for candidate in maya elarun maldives; do
        if [[ -d "/usr/share/sddm/themes/${candidate}" ]]; then
            SELECTED_THEME="${candidate}"
            break
        fi
    done
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
    log "No SDDM themes detected in /usr/share/sddm/themes; keeping defaults."
fi

# Ensure theme exists before continuing.
if [[ -n "${SELECTED_THEME}" && ! -d "/usr/share/sddm/themes/${SELECTED_THEME}" ]]; then
    log "Selected theme directory is missing: /usr/share/sddm/themes/${SELECTED_THEME}"
    exit 1
fi

if [[ -n "${SUGAR_THEME}" ]]; then
    THEME_DIR="/usr/share/sddm/themes/${SUGAR_THEME}"
    WALLPAPER_SRC="$(detect_current_wallpaper || true)"
    WALLPAPER_DST="${THEME_DIR}/Backgrounds/donarch-wallpaper.png"

    if [[ -f "${WALLPAPER_SRC}" ]]; then
        sudo mkdir -p "${THEME_DIR}/Backgrounds"
        sudo cp "${WALLPAPER_SRC}" "${WALLPAPER_DST}"
        log "Using current desktop wallpaper: ${WALLPAPER_SRC}"
    else
        WALLPAPER_DST=""
    fi

    log "Customizing Sugar Candy theme style..."
    if [[ -n "${WALLPAPER_DST}" ]]; then
        sudo tee "${THEME_DIR}/theme.conf.user" >/dev/null << EOF
Background="${WALLPAPER_DST}"
DimBackgroundImage="0.30"
BlurRadius="28"
ScaleImageCropped="true"

ScreenPadding="40"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
FullBlur="false"
FormBackgroundColor="\"#0f1117dd\""
BackgroundColor="\"#1e1e2eff\""
MainColor="\"#d0d8ffff\""
AccentColor="\"#8ec5fcff\""
OverrideLoginButtonTextColor="\"#0b1020ff\""
RoundCorners="20"
HeaderText="Welcome"
EOF
    else
        sudo tee "${THEME_DIR}/theme.conf.user" >/dev/null << 'EOF'
DimBackgroundImage="0.30"
BlurRadius="28"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
RoundCorners="20"
HeaderText="Welcome"
EOF
    fi
fi

log "Switching display manager to SDDM..."
sudo systemctl disable --now ly 2>/dev/null || true
sudo systemctl disable --now greetd 2>/dev/null || true
sudo systemctl enable --now sddm

log "Active theme config:"
sudo cat /etc/sddm.conf.d/10-theme.conf || true

log "Done. Reboot to see the new login screen."
