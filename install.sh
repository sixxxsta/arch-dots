#!/usr/bin/env bash
# DonArch Installer
# Don's Arch Configurations for Hyprland & Niri with DankMaterialShell

set -euo pipefail

# Get repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$REPO_DIR/lib/utils.sh"
source "$REPO_DIR/lib/checks.sh"
source "$REPO_DIR/lib/packages.sh"
source "$REPO_DIR/lib/dotfiles.sh"
source "$REPO_DIR/lib/themes.sh"
source "$REPO_DIR/lib/greeter.sh"
source "$REPO_DIR/lib/dcli.sh"

# Installation state variables
INSTALL_HYPRLAND=false
INSTALL_NIRI=false
INSTALL_DCLI=false
SELECTED_SHELL="noctalia"  # Default to noctalia
OPTIONAL_APPS=()
NVIDIA_HEADERS=""

# Display welcome screen
show_welcome() {
    print_banner

    cat << 'EOF'
This installer will set up Beautiful Dots configurations for:
  • Niri - Scrollable-tiling Wayland compositor
  • Desktop Shell - Choose between Noctalia (recommended) or DMS
  • Catppuccin Mocha theme across all applications
  • NVIDIA GPU support (auto-detected and installed if available)

The installer will:
  1. Check your system requirements
  2. Detect and install NVIDIA drivers if GPU is present
  3. Install the Niri compositor and desktop shell
  4. Let you choose your preferred desktop shell (Noctalia or DMS)
  5. Install required packages and optional applications
  6. Deploy configuration files (via symlinks)
  7. Apply themes and set up the display manager

Your existing .config will be backed up before any changes.

EOF

    if ! prompt_yes_no "Do you want to continue?" "y"; then
        echo ""
        log_info "Installation cancelled"
        exit 0
    fi
}

# User selection menu for compositors
select_compositors() {
    log_step "Compositor Selection"

    # Hyprland temporarily disabled - only Niri available
    log_info "Hyprland configuration is currently being reworked."
    log_info "Only Niri is available for installation at this time."
    echo ""

    INSTALL_HYPRLAND=false
    INSTALL_NIRI=true

    log_info "Selected compositor: Niri"
    echo ""
}

# User selection menu for shell (noctalia or dms)
select_shell() {
    log_step "Desktop Shell Selection"

    echo "Which desktop shell would you like to use?"
    echo ""
    echo "1) Noctalia Shell (Recommended) - Lightweight, stable, Material Design"
    echo "2) Dank Material Shell (DMS) - Feature-rich, some users report install issues"
    echo ""

    local choice
    while true; do
        read -p "Enter your choice (1-2) [default: 1]: " choice
        # Default to 1 if empty
        choice=${choice:-1}
        case $choice in
            1)
                SELECTED_SHELL="noctalia"
                break
                ;;
            2)
                SELECTED_SHELL="dms"
                break
                ;;
            *)
                log_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done

    echo ""
    if [ "$SELECTED_SHELL" = "noctalia" ]; then
        log_info "Selected shell: Noctalia Shell"
    else
        log_info "Selected shell: Dank Material Shell (DMS)"
    fi
    echo ""
}

# User selection menu for optional apps
select_optional_apps() {
    log_step "Optional Applications"

    echo "Select optional applications to install (enter numbers separated by spaces, or press Enter to skip):"
    echo ""
    echo "1) Zen Browser (privacy-focused browser)"
    echo "2) Zed (modern code editor)"
    echo "3) Helix (modal text editor)"
    echo ""

    read -p "Enter your choices (e.g., '1 3' or just Enter to skip): " choices

    # Parse selections
    for choice in $choices; do
        case $choice in
            1) OPTIONAL_APPS+=("zen-browser-bin") ;;
            2) OPTIONAL_APPS+=("zed") ;;
            3) OPTIONAL_APPS+=("helix") ;;
            *) log_warn "Invalid choice '$choice' ignored" ;;
        esac
    done

    echo ""
    if [ ${#OPTIONAL_APPS[@]} -gt 0 ]; then
        log_info "Selected optional applications:"
        for app in "${OPTIONAL_APPS[@]}"; do
            echo "  • $app"
        done
    else
        log_info "No optional applications selected"
    fi
    echo ""
}

# Ask user if they want dcli integration
select_dcli() {
    clear
    if prompt_dcli_installation; then
        INSTALL_DCLI=true
        log_info "dcli will be installed and configured"
    else
        INSTALL_DCLI=false
        log_info "Skipping dcli installation"
    fi
    echo ""
}

# Backup confirmation
confirm_backup() {
    log_step "Configuration Backup"

    log_info "Your existing ~/.config directory will be backed up before installation"
    echo ""

    if prompt_yes_no "Create backup of existing configurations?" "y"; then
        backup_existing_configs
    else
        log_warn "Skipping backup (not recommended)"
    fi
    echo ""
}

# Validate Niri configuration after deployment
validate_niri_configuration() {
    local user_home
    user_home="$(get_user_home)"
    local niri_config="$user_home/.config/niri/config.kdl"

    if [ "$INSTALL_NIRI" != true ]; then
        return 0
    fi

    if ! command_exists niri; then
        log_warn "niri command not found, skipping config validation"
        return 0
    fi

    if [ ! -f "$niri_config" ]; then
        log_error "Niri config not found at $niri_config"
        return 1
    fi

    log_info "Validating Niri configuration..."
    if ! niri validate; then
        log_error "Niri configuration validation failed"
        log_info "Fix config errors and run the installer again"
        return 1
    fi

    log_success "Niri configuration is valid"
    return 0
}

# Post-installation steps
post_install() {
    log_step "Post-Installation"

    # Offer to set fish as default shell
    if command_exists fish; then
        echo ""
        if prompt_yes_no "Set fish as your default shell?" "y"; then
            sudo chsh -s /usr/bin/fish "$(detect_user)"
            log_success "Default shell set to fish"
        fi
    fi

    echo ""
    print_separator
    echo ""
    log_success "Installation Complete!"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Reboot your system to activate the display manager"
    echo "  2. At the login screen, select your preferred session:"
    echo "     • Niri"
    echo "  3. Log in and enjoy your beautiful desktop!"
    echo ""
    echo -e "${CYAN}Key Bindings:${NC}"
    if [ "$SELECTED_SHELL" = "noctalia" ]; then
        echo "  • Super+Space    - Application launcher (Noctalia)"
    else
        echo "  • Super+Space    - Application launcher (DMS)"
    fi
    echo "  • Super+T        - Terminal (kitty)"
    echo "  • Super+Q        - Close window"
    echo "  • Super+F        - File manager (nemo)"
    echo ""
    echo -e "${CYAN}Configuration Files:${NC}"
    echo "  All configs are symlinked from: $REPO_DIR/configs/"
    echo "  Edit files in the repo and changes will apply immediately"
    echo ""

    if [ "$INSTALL_DCLI" = true ]; then
        echo -e "${CYAN}dcli Configuration:${NC}"
        echo "  dcli config location: ~/.config/arch-config"
        echo "  Run 'dcli status' to view your configuration"
        echo "  Run 'dcli repo init' to set up git tracking (recommended)"
        echo ""
    fi

    echo -e "${YELLOW}Tip:${NC} Keep the donarch directory to easily update configs!"
    echo ""
    print_separator
    echo ""

    if prompt_yes_no "Reboot now?" "n"; then
        log_info "Rebooting..."
        sleep 2
        sudo reboot
    else
        log_info "Remember to reboot before using the new desktop environment"
    fi
}

# Main installation flow
main() {
    # Welcome screen
    show_welcome

    # Run system checks
    run_all_checks || die "System checks failed"

    # Detect NVIDIA GPU
    if NVIDIA_HEADERS=$(detect_nvidia); then
        log_info "NVIDIA GPU detected"
    else
        log_info "No NVIDIA GPU detected, skipping driver installation"
        NVIDIA_HEADERS=""
    fi

    # User selections
    select_compositors
    select_shell
    select_optional_apps
    select_dcli

    # Confirm backup
    confirm_backup

    # Install packages
    install_core_packages "$REPO_DIR" || die "Failed to install core packages"
    install_compositor_packages "$REPO_DIR" "$INSTALL_HYPRLAND" "$INSTALL_NIRI" || die "Failed to install compositor packages"
    install_theme_packages "$REPO_DIR" || die "Failed to install theme packages"
    
    # Install NVIDIA drivers if GPU detected
    if [ -n "$NVIDIA_HEADERS" ]; then
        install_nvidia_drivers "$REPO_DIR" "$NVIDIA_HEADERS" || log_warn "NVIDIA driver installation had issues"
    fi
    
    install_shell_packages "$REPO_DIR" "$SELECTED_SHELL" || die "Failed to install shell packages"
    install_required_apps "$REPO_DIR" || die "Failed to install required applications"

    if [ ${#OPTIONAL_APPS[@]} -gt 0 ]; then
        install_optional_apps "$REPO_DIR" "${OPTIONAL_APPS[@]}"
    fi

    # Deploy configurations
    deploy_configurations "$REPO_DIR" "$INSTALL_HYPRLAND" "$INSTALL_NIRI" "$SELECTED_SHELL" || die "Failed to deploy configurations"

    # Validate compositor configuration
    validate_niri_configuration || die "Failed to validate Niri configuration"

    # Apply themes
    apply_themes "$REPO_DIR" "$INSTALL_HYPRLAND" "$INSTALL_NIRI" || die "Failed to apply themes"

    # Setup greeter
    setup_greeter "$INSTALL_HYPRLAND" "$INSTALL_NIRI" "$SELECTED_SHELL" || die "Failed to setup greeter"

    # Setup dcli if selected
    if [ "$INSTALL_DCLI" = true ]; then
        setup_dcli "$(detect_user)" "$REPO_DIR" "$INSTALL_HYPRLAND" "$INSTALL_NIRI" "$SELECTED_SHELL" "${OPTIONAL_APPS[@]}" || log_warn "dcli setup failed, but continuing with installation"
    fi

    # Post-installation
    post_install
}

# Run main installation
main
