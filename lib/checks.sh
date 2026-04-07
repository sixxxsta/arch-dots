#!/usr/bin/env bash
# System checks for donarch installer

# Source utils for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Check if running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script must NOT be run as root"
        log_info "Please run as a normal user (sudo will be requested when needed)"
        return 1
    fi
    log_success "Not running as root"
    return 0
}

# Check if on Arch-based distribution
check_arch_based() {
    if [ ! -f /etc/arch-release ]; then
        log_error "This installer is designed for Arch-based distributions only"
        log_info "Detected OS:"
        cat /etc/os-release 2>/dev/null || echo "Unknown"
        return 1
    fi
    log_success "Arch-based distribution detected"
    return 0
}

# Detect AUR helper
detect_aur_helper() {
    local aur_helper=""

    if command_exists paru; then
        aur_helper="paru"
    elif command_exists yay; then
        aur_helper="yay"
    elif command_exists pikaur; then
        aur_helper="pikaur"
    elif command_exists pakku; then
        aur_helper="pakku"
    else
        log_error "No AUR helper found!"
        echo ""
        log_info "Please install an AUR helper first. Recommended options:"
        echo "  • paru (recommended):  sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si"
        echo "  • yay:                 sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
        echo ""
        return 1
    fi

    log_success "AUR helper detected: $aur_helper" >&2
    echo "$aur_helper"
    return 0
}

# Check for required base packages
check_base_packages() {
    local missing_packages=()
    local required_packages=("git" "base-devel")

    for pkg in "${required_packages[@]}"; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warn "Missing required packages: ${missing_packages[*]}"
        log_info "Installing required packages..."
        sudo pacman -S --needed --noconfirm "${missing_packages[@]}"
        return $?
    fi

    log_success "All base packages present"
    return 0
}

# Check if dialog is installed (for menus)
check_dialog() {
    if ! command_exists dialog; then
        log_warn "dialog not found, installing..."
        sudo pacman -S --needed --noconfirm dialog
        return $?
    fi
    log_success "dialog is installed"
    return 0
}

# Check internet connectivity
check_internet() {
    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        log_error "No internet connection detected"
        log_info "Please connect to the internet and try again"
        return 1
    fi
    log_success "Internet connection verified"
    return 0
}

# Run all checks
run_all_checks() {
    log_step "Running System Checks"

    check_not_root || return 1
    check_arch_based || return 1
    check_internet || return 1
    check_base_packages || return 1
    check_dialog || return 1

    # Detect AUR helper and store in variable
    AUR_HELPER=$(detect_aur_helper) || return 1
    export AUR_HELPER

    # Debug: verify AUR_HELPER is set correctly
    log_info "Using AUR helper: $AUR_HELPER" >&2

    echo ""
    log_success "All system checks passed!"
    echo ""

    return 0
}
