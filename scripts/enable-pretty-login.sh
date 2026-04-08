#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
    printf '[pretty-login] %s\n' "$1"
}

ensure_niri_shell_fallback() {
    local niri_dir="${HOME}/.config/niri"
    local main_cfg="${niri_dir}/config.kdl"
    local start_cfg="${niri_dir}/shell-switcher-startup.kdl"
    local binds_cfg="${niri_dir}/shell-switcher-binds.kdl"

    mkdir -p "${niri_dir}"

    cat > "${start_cfg}" << 'EOF'
// Shell Switcher - Startup Configuration
// This file is managed by shell-switch - manual edits will be overwritten
// Current shell: Auto Fallback

spawn-at-startup "bash" "-lc" "if command -v qs >/dev/null 2>&1; then qs -c noctalia-shell; elif command -v dms >/dev/null 2>&1; then dms run; fi"
EOF

    cat > "${binds_cfg}" << 'EOF'
// Shell Switcher - Keybindings
// This file is managed by shell-switch for the switcher and launcher bindings
// Current shell: Auto Fallback

binds {
    // App launcher with fallback
    Mod+Space hotkey-overlay-title="Open Launcher" {
        spawn "bash" "-lc" "if command -v qs >/dev/null 2>&1; then qs -c noctalia-shell ipc call launcher toggle; elif command -v dms >/dev/null 2>&1; then dms ipc call spotlight toggle; fi";
    }

    // Shell switcher
    Ctrl+Shift+S hotkey-overlay-title="Switch Desktop Shell" {
        spawn "kitty" "--class=floating-kitty" "shell-switch";
    }
}
EOF

    if [[ -f "${main_cfg}" ]]; then
        if ! grep -q 'include "shell-switcher-binds.kdl"' "${main_cfg}"; then
            printf '\ninclude "shell-switcher-binds.kdl"\n' >> "${main_cfg}"
            log "Added include for shell-switcher-binds.kdl"
        fi

        if ! grep -q 'include "shell-switcher-startup.kdl"' "${main_cfg}"; then
            printf 'include "shell-switcher-startup.kdl"\n' >> "${main_cfg}"
            log "Added include for shell-switcher-startup.kdl"
        fi
    fi

    if command -v niri >/dev/null 2>&1; then
        niri msg action reload-config >/dev/null 2>&1 || true
    fi

    if ! pgrep -f 'qs.*noctalia-shell|dms run' >/dev/null 2>&1; then
        if command -v qs >/dev/null 2>&1; then
            nohup qs -c noctalia-shell >/dev/null 2>&1 &
            log "Started Noctalia shell for current session"
        elif command -v dms >/dev/null 2>&1; then
            nohup dms run >/dev/null 2>&1 &
            log "Started DMS shell for current session"
        else
            log "Neither Noctalia nor DMS is installed; shell UI cannot be started."
        fi
    fi
}

if [[ "${EUID}" -eq 0 ]]; then
    log "Run this script as a normal user (it uses sudo internally)."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is required."
    exit 1
fi

detect_current_wallpaper() {
    local user_home="${HOME}"
    local cfg
    local wp

    cfg="${user_home}/.config/niri/startup.kdl"
    if [[ -f "${cfg}" ]]; then
        wp="$(grep -Eo 'swaybg -i "[^"]+"' "${cfg}" | head -n 1 | sed -E 's/^swaybg -i "(.*)"$/\1/' || true)"
        if [[ -n "${wp}" ]]; then
            wp="${wp/#\$HOME/${user_home}}"
            [[ -f "${wp}" ]] && echo "${wp}" && return 0
        fi
    fi

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

install_sugar_candy_from_git() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local target_theme_dir="/usr/share/sddm/themes/sugar-candy"

    log "Installing Sugar Candy theme from GitHub..."
    git clone --depth 1 https://github.com/Kangie/sddm-sugar-candy.git "${tmp_dir}/sugar-candy"
    sudo rm -rf "${target_theme_dir}"
    sudo mkdir -p "${target_theme_dir}"
    sudo cp -r "${tmp_dir}/sugar-candy/"* "${target_theme_dir}/"
    rm -rf "${tmp_dir}"
}

log "Installing SDDM and required runtime dependencies..."
sudo pacman -S --needed --noconfirm \
    sddm \
    git \
    qt6-5compat \
    qt6-declarative \
    qt6-svg

# Optional AUR install first. GitHub fallback is mandatory below.
if command -v paru >/dev/null 2>&1; then
    log "Trying AUR theme packages first..."
    paru -S --needed --noconfirm sddm-sugar-candy-git || true
    paru -S --needed --noconfirm sddm-theme-sugar-candy-git || true
fi

if [[ ! -d /usr/share/sddm/themes/sugar-candy ]]; then
    install_sugar_candy_from_git
fi

if [[ ! -d /usr/share/sddm/themes/sugar-candy ]]; then
    log "Sugar Candy theme directory is missing after installation."
    exit 1
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

log "Ensuring shell UI fallback config for Niri (top bar, launcher, Win+Space)..."
ensure_niri_shell_fallback

log "Selecting wallpaper from current desktop config..."
WALLPAPER_SRC="$(detect_current_wallpaper || true)"
WALLPAPER_DST="/usr/share/sddm/themes/sugar-candy/Backgrounds/current-wallpaper.png"

if [[ -n "${WALLPAPER_SRC}" && -f "${WALLPAPER_SRC}" ]]; then
    sudo mkdir -p /usr/share/sddm/themes/sugar-candy/Backgrounds
    sudo cp "${WALLPAPER_SRC}" "${WALLPAPER_DST}"
    log "Wallpaper applied: ${WALLPAPER_SRC}"
else
    WALLPAPER_DST=""
    log "Could not detect wallpaper automatically; using theme default background."
fi

log "Writing SDDM theme selection..."
sudo mkdir -p /etc/sddm.conf.d
sudo rm -f /etc/sddm.conf.d/*theme*.conf 2>/dev/null || true
sudo tee /etc/sddm.conf.d/99-theme.conf >/dev/null << 'EOF'
[Theme]
Current=sugar-candy
EOF

# Also write a direct /etc/sddm.conf override for maximum compatibility.
sudo tee /etc/sddm.conf >/dev/null << 'EOF'
[Theme]
Current=sugar-candy
EOF

log "Writing minimalist Sugar Candy style overrides..."
if [[ -n "${WALLPAPER_DST}" ]]; then
    sudo tee /usr/share/sddm/themes/sugar-candy/theme.conf.user >/dev/null << EOF
Background="${WALLPAPER_DST}"
DimBackgroundImage="0.22"
BlurRadius="30"
ScaleImageCropped="true"

ScreenPadding="40"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
FullBlur="false"

FormBackgroundColor="\"#090d16e6\""
BackgroundColor="\"#0b1020ff\""
MainColor="\"#f8fafcff\""
AccentColor="\"#38bdf8ff\""
OverrideLoginButtonTextColor="\"#0b1020ff\""
RoundCorners="22"
HeaderText="Welcome"
EOF
else
    sudo tee /usr/share/sddm/themes/sugar-candy/theme.conf.user >/dev/null << 'EOF'
DimBackgroundImage="0.32"
BlurRadius="30"
FormPosition="center"
HaveFormBackground="true"
PartialBlur="true"
RoundCorners="22"
HeaderText="Welcome"
EOF
fi

log "Switching display manager to SDDM..."
sudo systemctl disable --now ly 2>/dev/null || true
sudo systemctl disable --now greetd 2>/dev/null || true
sudo systemctl unmask sddm.service 2>/dev/null || true
sudo systemctl set-default graphical.target
sudo systemctl enable --now sddm
sudo ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service

log "Applied configuration:"
sudo cat /etc/sddm.conf.d/99-theme.conf
log "Direct /etc/sddm.conf:"
sudo cat /etc/sddm.conf
log "Theme directory check:"
ls /usr/share/sddm/themes | sed 's/^/[pretty-login] theme: /'
log "Systemd checks:"
systemctl is-enabled sddm || true
systemctl is-active sddm || true
systemctl get-default || true
systemctl status display-manager --no-pager -l | tail -n 30 || true

log "Done. Reboot now to apply the login screen and keep shell UI stable after login."
