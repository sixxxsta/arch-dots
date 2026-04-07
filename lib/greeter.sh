#!/usr/bin/env bash
# Ly display manager setup functions for donarch installer

# Source utils for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Disable conflicting display managers and getty
disable_other_display_managers() {
    log_info "Checking for conflicting display managers..."

    local disabled_any=false
    for dm in gdm sddm lightdm lxdm greetd; do
        if systemctl is-enabled "${dm}.service" &>/dev/null; then
            log_warn "Disabling ${dm} display manager..."
            sudo systemctl disable "${dm}.service" 2>/dev/null || true
            disabled_any=true
        fi
    done

    # Disable getty@tty1 to allow ly to use it
    if systemctl is-enabled getty@tty1.service &>/dev/null; then
        log_warn "Disabling getty@tty1.service for ly..."
        sudo systemctl disable getty@tty1.service
        disabled_any=true
    fi

    if [ "$disabled_any" = false ]; then
        log_info "No conflicting display managers found"
    else
        log_success "Conflicting display managers disabled"
    fi
}

# Enable ly service
enable_ly() {
    log_info "Enabling ly display manager service..."

    if systemctl is-enabled ly@tty1.service &>/dev/null; then
        log_info "ly is already enabled"
    else
        sudo systemctl enable ly@tty1.service
        log_success "ly service enabled"
    fi
}

# Configure ly
configure_ly() {
    log_info "Configuring ly display manager..."

    # Ly configuration is in /etc/ly/config.ini
    # For now, we'll use the defaults which work well
    # Users can customize ~/.config/ly/config.ini later

    log_success "ly configuration complete (using defaults)"
    log_info "You can customize ly at ~/.config/ly/config.ini"
}

# Create Wayland session desktop files
create_session_files() {
    local install_hyprland="$1"
    local install_niri="$2"
    local selected_shell="${3:-noctalia}"

    log_info "Creating Wayland session files..."

    sudo mkdir -p /usr/share/wayland-sessions

    # Create Hyprland session file
    if [ "$install_hyprland" = "true" ]; then
        local shell_name="Noctalia"
        [ "$selected_shell" = "dms" ] && shell_name="DMS"
        sudo tee /usr/share/wayland-sessions/hyprland-dms.desktop > /dev/null << EOFHYPR
[Desktop Entry]
Name=Hyprland (${shell_name})
Comment=Hyprland with ${shell_name} shell
Exec=Hyprland
Type=Application
EOFHYPR
        log_success "Hyprland session file created"
    fi

    # Create Niri session file
    if [ "$install_niri" = "true" ]; then
        local shell_name="Noctalia"
        [ "$selected_shell" = "dms" ] && shell_name="DMS"
        sudo tee /usr/share/wayland-sessions/niri-dms.desktop > /dev/null << EOFNIRI
[Desktop Entry]
Name=Niri (${shell_name})
Comment=Niri with ${shell_name} shell
Exec=niri-session
Type=Application
EOFNIRI
        log_success "Niri session file created"
    fi
}

# Main greeter setup function
setup_greeter() {
    local install_hyprland="$1"
    local install_niri="$2"
    local selected_shell="${3:-noctalia}"

    log_step "Setting Up Display Manager"

    log_info "This step requires sudo privileges to configure the display manager"
    echo ""

    disable_other_display_managers
    enable_ly
    configure_ly
    create_session_files "$install_hyprland" "$install_niri" "$selected_shell"

    echo ""
    log_success "Display manager setup complete!"
    echo ""
    log_info "Session selection:"
    local shell_name="Noctalia"
    [ "$selected_shell" = "dms" ] && shell_name="DMS"
    [ "$install_hyprland" = "true" ] && echo "  • Hyprland (${shell_name}) - Available at login"
    [ "$install_niri" = "true" ] && echo "  • Niri (${shell_name}) - Available at login"
    echo ""
    log_warn "You will need to reboot to use the new display manager"
}
