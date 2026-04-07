#!/usr/bin/env bash
# Package installation functions for donarch installer

# Source utils for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Install packages from a list file
install_package_list() {
    local package_file="$1"
    local description="$2"

    if [ ! -f "$package_file" ]; then
        log_error "Package list file not found: $package_file"
        return 1
    fi

    # Check if AUR_HELPER is set
    if [ -z "${AUR_HELPER:-}" ]; then
        log_error "AUR_HELPER variable is not set. Please ensure system checks have run."
        return 1
    fi

    log_info "Installing $description..."

    # Read packages from file, skip empty lines and comments
    local packages=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        packages+=("$line")
    done < "$package_file"

    if [ ${#packages[@]} -eq 0 ]; then
        log_warn "No packages found in $package_file"
        return 0
    fi

    local official_packages=()
    local aur_packages=()

    # Separate official and AUR packages
    for pkg in "${packages[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official_packages+=("$pkg")
        else
            aur_packages+=("$pkg")
        fi
    done

    # Install official packages with pacman
    if [ ${#official_packages[@]} -gt 0 ]; then
        log_info "Installing official packages: ${official_packages[*]}"
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
        if [ $? -ne 0 ]; then
            log_error "Failed to install some official packages"
            return 1
        fi
    fi

    # Install AUR packages with AUR helper
    if [ ${#aur_packages[@]} -gt 0 ]; then
        log_info "Installing AUR packages: ${aur_packages[*]}"
        local failed_packages=()
        # Install AUR packages one by one to handle conflicts better
        for pkg in "${aur_packages[@]}"; do
            log_info "Installing AUR package: $pkg"
            "${AUR_HELPER}" -S --needed --noconfirm "${pkg}"
            if [ $? -ne 0 ]; then
                log_warn "Failed to install $pkg"
                failed_packages+=("$pkg")
            else
                log_success "$pkg installed"
            fi
        done

        if [ ${#failed_packages[@]} -gt 0 ]; then
            echo ""
            log_error "Some AUR packages failed to install:"
            for pkg in "${failed_packages[@]}"; do
                echo "  ✗ $pkg"
            done
            echo ""
            log_warn "Installation continuing, but some features may not work"
            echo ""
        fi
    fi

    log_success "$description installed successfully"
    return 0
}

# Install core dependencies
install_core_packages() {
    local repo_dir="$1"
    log_step "Installing Core Dependencies"
    install_package_list "$repo_dir/packages/core.txt" "Core Dependencies"
}

# Install compositor packages
install_compositor_packages() {
    local repo_dir="$1"
    local install_hyprland="$2"
    local install_niri="$3"

    log_step "Installing Compositor Packages"

    if [ "$install_hyprland" = "true" ]; then
        install_package_list "$repo_dir/packages/hyprland.txt" "Hyprland Compositor"
    fi

    if [ "$install_niri" = "true" ]; then
        install_package_list "$repo_dir/packages/niri.txt" "Niri Compositor"
    fi
}

# Install theme packages
install_theme_packages() {
    local repo_dir="$1"
    log_step "Installing Theme Packages"
    install_package_list "$repo_dir/packages/themes.txt" "Themes"
}

# Install NVIDIA drivers if GPU is detected
install_nvidia_drivers() {
    local repo_dir="$1"
    local headers_pkg="$2"

    if [ -z "$headers_pkg" ]; then
        log_warn "No NVIDIA GPU detected or kernel headers could not be determined"
        return 0
    fi

    log_step "Installing NVIDIA Drivers"
    log_info "Detected kernel headers: $headers_pkg"

    # Install kernel headers first
    log_info "Installing kernel headers..."
    sudo pacman -S --needed --noconfirm "$headers_pkg"
    if [ $? -ne 0 ]; then
        log_warn "Failed to install kernel headers"
        return 1
    fi

    # Install NVIDIA packages
    log_info "Installing NVIDIA packages..."
    install_package_list "$repo_dir/packages/nvidia.txt" "NVIDIA Drivers"
    if [ $? -ne 0 ]; then
        log_warn "NVIDIA driver installation had issues, but continuing"
        return 0
    fi

    log_success "NVIDIA drivers installed successfully"
    return 0
}

# Install DMS packages (legacy - installs both shells)
install_dms_packages() {
    local repo_dir="$1"
    log_step "Installing DankMaterialShell"
    install_package_list "$repo_dir/packages/dms.txt" "DMS and Display Manager"
}

# Install selected shell packages (noctalia or dms)
install_shell_packages() {
    local repo_dir="$1"
    local selected_shell="$2"

    log_step "Installing Desktop Shell"

    # Install display manager first (required for login)
    log_info "Installing display manager dependency (ly)..."
    if ! sudo pacman -S --needed --noconfirm ly; then
        log_error "Failed to install ly display manager"
        return 1
    fi

    # Install shell runtime dependency based on selected shell.
    # Noctalia uses noctalia-qs, which conflicts with plain quickshell.
    if [ "$selected_shell" = "dms" ]; then
        # If switching from Noctalia -> DMS, remove Noctalia first so its deps can be removed.
        if pacman -Q noctalia-shell >/dev/null 2>&1; then
            log_info "Detected noctalia-shell; removing it to switch to DMS..."
            if ! sudo pacman -Rns --noconfirm noctalia-shell; then
                log_error "Failed to remove noctalia-shell while switching to DMS"
                return 1
            fi
        fi

        if pacman -Q noctalia-qs >/dev/null 2>&1; then
            log_info "Removing conflicting package: noctalia-qs"
            if ! sudo pacman -Rns --noconfirm noctalia-qs; then
                log_error "Failed to remove noctalia-qs"
                return 1
            fi
        fi

        log_info "Installing DMS runtime dependency (quickshell)..."
        if ! sudo pacman -S --needed --noconfirm quickshell; then
            log_error "Failed to install quickshell for DMS"
            return 1
        fi
    else
        # If switching from DMS -> Noctalia, remove DMS first so quickshell can be removed.
        if pacman -Q dms-shell-git >/dev/null 2>&1; then
            log_info "Detected dms-shell-git; removing it to switch to Noctalia..."
            if ! sudo pacman -Rns --noconfirm dms-shell-git; then
                log_error "Failed to remove dms-shell-git while switching to Noctalia"
                return 1
            fi
        fi

        if pacman -Q quickshell >/dev/null 2>&1; then
            log_info "Removing conflicting package: quickshell"
            if ! sudo pacman -Rns --noconfirm quickshell; then
                log_error "Failed to remove quickshell"
                return 1
            fi
        fi
    fi

    # Install the selected shell
    if [ "$selected_shell" = "noctalia" ]; then
        log_info "Installing Noctalia Shell..."
        if ! "${AUR_HELPER}" -S --needed --noconfirm "noctalia-shell"; then
            log_warn "Failed to install noctalia-shell from AUR"
            return 1
        fi
    elif [ "$selected_shell" = "dms" ]; then
        log_info "Installing Dank Material Shell (DMS)..."
        if ! "${AUR_HELPER}" -S --needed --noconfirm "dms-shell-git"; then
            log_warn "Failed to install dms-shell-git from AUR"
            return 1
        fi
    else
        log_error "Unknown shell selection: $selected_shell"
        return 1
    fi

    log_success "Desktop shell installed successfully"
    return 0
}

# Install required apps
install_required_apps() {
    local repo_dir="$1"
    log_step "Installing Required Applications"
    install_package_list "$repo_dir/packages/apps-required.txt" "Required Applications"
}

# Install optional apps
install_optional_apps() {
    local repo_dir="$1"
    shift
    local apps=("$@")

    if [ ${#apps[@]} -eq 0 ]; then
        log_info "No optional applications selected"
        return 0
    fi

    log_step "Installing Optional Applications"

    for app in "${apps[@]}"; do
        log_info "Installing $app..."
        $AUR_HELPER -S --needed --noconfirm "$app"
        if [ $? -eq 0 ]; then
            log_success "$app installed"
        else
            log_warn "Failed to install $app, continuing..."
        fi
    done
}
