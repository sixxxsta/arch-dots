#!/usr/bin/env bash
# Theme application functions for donarch installer
# Adapted from install-hyprland-dotfiles.sh and install-niri-dotfiles.sh

# Source utils for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Apply gsettings (handles both sudo and non-sudo cases)
apply_gsettings() {
    local user=$(detect_user)
    local user_id=$(id -u "$user")

    if [ "$EUID" -eq 0 ]; then
        sudo -u "$user" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_id/bus" gsettings "$@" 2>/dev/null || true
    else
        gsettings "$@" 2>/dev/null || true
    fi
}

# Apply GTK theme settings
apply_gtk_theme() {
    log_info "Applying GTK theme settings..."

    # Apply theme settings via gsettings
    apply_gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default'
    apply_gsettings set org.gnome.desktop.interface icon-theme 'Tela-purple-dark'
    apply_gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
    apply_gsettings set org.gnome.desktop.interface font-name 'Inter Variable 10'
    apply_gsettings set org.gnome.desktop.interface cursor-size 24

    log_success "GTK theme settings applied"
}

# Create GTK2 configuration
create_gtk2_config() {
    local user_home=$(get_user_home)
    local gtkrc="$user_home/.gtkrc-2.0"

    log_info "Creating GTK2 configuration..."

    cat > "$gtkrc" << 'EOFGTK2'
gtk-theme-name="catppuccin-mocha-mauve-standard+default"
gtk-icon-theme-name="Tela-purple-dark"
gtk-font-name="Inter Variable 10"
gtk-cursor-theme-name="Bibata-Modern-Ice"
gtk-cursor-theme-size=24
EOFGTK2

    # Fix ownership if running as root
    if [ "$EUID" -eq 0 ]; then
        local user=$(detect_user)
        chown "$user:$user" "$gtkrc"
    fi

    log_success "GTK2 configuration created"
}

# Set default cursor theme
set_cursor_theme() {
    local user_home=$(get_user_home)
    local icons_dir="$user_home/.icons/default"

    log_info "Setting default cursor theme..."

    mkdir -p "$icons_dir"

    cat > "$icons_dir/index.theme" << 'EOFCURSOR'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOFCURSOR

    # Fix ownership if running as root
    if [ "$EUID" -eq 0 ]; then
        local user=$(detect_user)
        chown -R "$user:$user" "$user_home/.icons"
    fi

    log_success "Default cursor theme set"
}

# Create Xresources for cursor
create_xresources() {
    local user_home=$(get_user_home)
    local xresources="$user_home/.Xresources"

    log_info "Creating Xresources for cursor..."

    cat > "$xresources" << 'EOFXRES'
Xcursor.theme: Bibata-Modern-Ice
Xcursor.size: 24
EOFXRES

    # Fix ownership if running as root
    if [ "$EUID" -eq 0 ]; then
        local user=$(detect_user)
        chown "$user:$user" "$xresources"
    fi

    log_success "Xresources created"
}

# Setup wallpaper symlinks
setup_wallpapers() {
    local repo_dir="$1"
    local install_hyprland="$2"
    local install_niri="$3"
    local user_home=$(get_user_home)
    local user=$(detect_user)

    log_info "Setting up wallpapers..."

    local wallpaper_source="$repo_dir/assets/wallpapers/wallpaper.png"

    if [ ! -f "$wallpaper_source" ]; then
        log_warn "Default wallpaper not found, skipping"
        return 0
    fi

    # Setup for Hyprland
    if [ "$install_hyprland" = "true" ]; then
        local hypr_wallpaper_dir="$user_home/.config/hypr/wallpapers"
        mkdir -p "$hypr_wallpaper_dir"
        ln -sf "$wallpaper_source" "$hypr_wallpaper_dir/wallpaper.png"

        if [ "$EUID" -eq 0 ]; then
            chown -h "$user:$user" "$hypr_wallpaper_dir/wallpaper.png"
            chown "$user:$user" "$hypr_wallpaper_dir"
        fi

        log_success "Hyprland wallpaper linked"
    fi

    # Setup for Niri
    if [ "$install_niri" = "true" ]; then
        local niri_wallpaper_dir="$user_home/.config/niri/wallpapers"
        mkdir -p "$niri_wallpaper_dir"
        ln -sf "$wallpaper_source" "$niri_wallpaper_dir/wallpaper.png"

        if [ "$EUID" -eq 0 ]; then
            chown -h "$user:$user" "$niri_wallpaper_dir/wallpaper.png"
            chown "$user:$user" "$niri_wallpaper_dir"
        fi

        log_success "Niri wallpaper linked"
    fi
}

# Main theme application function
apply_themes() {
    local repo_dir="$1"
    local install_hyprland="$2"
    local install_niri="$3"

    log_step "Applying Themes"

    apply_gtk_theme
    create_gtk2_config
    set_cursor_theme
    create_xresources
    setup_wallpapers "$repo_dir" "$install_hyprland" "$install_niri"

    log_success "Themes applied successfully"
    echo ""
    log_info "Theme changes will take full effect after logging out and back in"
}
