#!/usr/bin/env bash
# Utility functions for donarch installer

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_step() {
    echo ""
    echo -e "${PURPLE}━━━${NC} ${CYAN}$1${NC} ${PURPLE}━━━${NC}"
    echo ""
}

# Error handling - exit with error message
die() {
    log_error "$1"
    exit 1
}

# Detect the actual user (handles sudo case)
detect_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Get user's home directory
get_user_home() {
    local user=$(detect_user)
    eval echo ~$user
}

# Backup existing configs
backup_existing_configs() {
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"
    local backup_dir="$user_home/.config.backup-$(date +%Y%m%d_%H%M%S)"

    if [ -d "$config_dir" ]; then
        log_info "Creating backup of existing configs..."
        cp -r "$config_dir" "$backup_dir"
        log_success "Backup created at: $backup_dir"
        return 0
    else
        log_warn "No existing .config directory found, skipping backup"
        return 1
    fi
}

# Prompt user for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" -r response
    response=${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a package is installed
is_package_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Print a separator line
print_separator() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print donarch banner
print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════╗
║                                              ║
║            DONARCH INSTALLER                 ║
║                                              ║
║    Don's Arch Configs for Hyprland & Niri    ║
║         with DankMaterialShell               ║
║                                              ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}
