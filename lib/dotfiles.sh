#!/usr/bin/env bash
# Dotfiles deployment functions for donarch installer

# Source utils for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Create symlink (removing existing files/symlinks first)
create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if it doesn't exist
    local target_dir=$(dirname "$target")
    mkdir -p "$target_dir"

    # Remove existing file/symlink if present
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
    fi

    # Create symlink
    ln -sf "$source" "$target"
}

# Deploy assets directory
deploy_assets() {
    local repo_dir="$1"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"

    log_info "Deploying assets..."

    if [ -d "$repo_dir/assets" ]; then
        create_symlink "$repo_dir/assets" "$config_dir/donarch/assets"
        log_success "Assets linked to $config_dir/donarch/assets"
    fi
}

# Deploy shared configurations
deploy_shared_configs() {
    local repo_dir="$1"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"

    log_info "Deploying shared configurations..."

    local shared_configs=(
        "kitty"
        "fish"
        "gtk-3.0"
        "gtk-4.0"
        "noctalia"
        "shell-switch"
    )

    for config in "${shared_configs[@]}"; do
        if [ -d "$repo_dir/configs/shared/$config" ]; then
            if [ "$config" = "shell-switch" ]; then
                log_info "Linking $config..."
                create_symlink "$repo_dir/configs/shared/$config" "$config_dir/$config"

                # Ensure shell-switch binary is available in PATH
                if [ -f "$repo_dir/configs/shared/$config/shell-switch" ]; then
                    chmod +x "$repo_dir/configs/shared/$config/shell-switch" 2>/dev/null || true
                    mkdir -p "$user_home/.local/bin"
                    ln -sf "$repo_dir/configs/shared/$config/shell-switch" "$user_home/.local/bin/shell-switch"
                    log_success "shell-switch linked to $user_home/.local/bin/shell-switch"
                else
                    log_warn "shell-switch executable not found in shared config; skipping ~/.local/bin link"
                fi
            else
                log_info "Linking $config..."
                create_symlink "$repo_dir/configs/shared/$config" "$config_dir/$config"
            fi
        fi
    done

    # Handle Qt configs separately to process $HOME variable
    for qt_config in "qt5ct" "qt6ct"; do
        if [ -d "$repo_dir/configs/shared/$qt_config" ]; then
            log_info "Processing $qt_config config with path expansion..."
            mkdir -p "$config_dir/$qt_config"
            if [ -f "$repo_dir/configs/shared/$qt_config/${qt_config}.conf" ]; then
                sed "s|\$HOME|$user_home|g" "$repo_dir/configs/shared/$qt_config/${qt_config}.conf" > "$config_dir/$qt_config/${qt_config}.conf"
            fi
            # Copy other files if they exist
            find "$repo_dir/configs/shared/$qt_config" -type f ! -name "${qt_config}.conf" -exec cp {} "$config_dir/$qt_config/" \; 2>/dev/null || true
        fi
    done

    # Handle fastfetch separately to process $HOME variable
    if [ -d "$repo_dir/configs/shared/fastfetch" ]; then
        log_info "Processing fastfetch config with path expansion..."
        mkdir -p "$config_dir/fastfetch"
        if [ -f "$repo_dir/configs/shared/fastfetch/config.jsonc" ]; then
            sed "s|\$HOME|$user_home|g" "$repo_dir/configs/shared/fastfetch/config.jsonc" > "$config_dir/fastfetch/config.jsonc"
        fi
        # Copy other fastfetch files if they exist
        find "$repo_dir/configs/shared/fastfetch" -type f ! -name "config.jsonc" -exec cp {} "$config_dir/fastfetch/" \; 2>/dev/null || true
    fi

    log_success "Shared configurations deployed"
}

# Deploy Hyprland configurations
deploy_hyprland_configs() {
    local repo_dir="$1"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"

    log_info "Deploying Hyprland configurations..."

    # Link hypr directory
    if [ -d "$repo_dir/configs/hyprland/hypr" ]; then
        log_info "Linking Hyprland configs..."
        create_symlink "$repo_dir/configs/hyprland/hypr" "$config_dir/hypr"
    fi

    # Link zed directory
    if [ -d "$repo_dir/configs/hyprland/zed" ]; then
        log_info "Linking Zed editor configs..."
        create_symlink "$repo_dir/configs/hyprland/zed" "$config_dir/zed"
    fi

    log_success "Hyprland configurations deployed"
}

# Deploy Niri configurations
deploy_niri_configs() {
    local repo_dir="$1"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"

    log_info "Deploying Niri configurations..."

    # Link niri directory
    if [ -d "$repo_dir/configs/niri/niri" ]; then
        log_info "Linking Niri configs..."
        create_symlink "$repo_dir/configs/niri/niri" "$config_dir/niri"
    fi

    log_success "Niri configurations deployed"
}

# Merge DMS settings (base + compositor-specific)
merge_dms_configs() {
    local repo_dir="$1"
    local compositor="$2"  # "hyprland" or "niri"
    local selected_shell="${3:-dms}"  # "noctalia" or "dms"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"
    local dms_dir="$config_dir/DankMaterialShell"

    # Skip DMS config if noctalia is selected
    if [ "$selected_shell" = "noctalia" ]; then
        log_info "Noctalia selected - skipping DMS configuration"
        return 0
    fi

    log_info "Merging DMS configurations for $compositor..."

    # Check if jq is installed
    if ! command_exists jq; then
        log_warn "jq not installed, falling back to direct copy"
        create_symlink "$repo_dir/configs/$compositor/DankMaterialShell" "$dms_dir"
        return 0
    fi

    local base_settings="$repo_dir/configs/shared/DankMaterialShell/settings.json"
    local compositor_settings="$repo_dir/configs/$compositor/DankMaterialShell/settings.json"

    if [ ! -f "$base_settings" ]; then
        log_warn "Base DMS settings not found, using compositor settings only"
        create_symlink "$repo_dir/configs/$compositor/DankMaterialShell" "$dms_dir"
        return 0
    fi

    if [ ! -f "$compositor_settings" ]; then
        log_warn "Compositor-specific DMS settings not found, using base settings only"
        create_symlink "$repo_dir/configs/shared/DankMaterialShell" "$dms_dir"
        return 0
    fi

    # Create DMS directory
    mkdir -p "$dms_dir"

    # Merge JSON files with jq and replace hardcoded paths
    jq -s '.[0] * .[1]' "$base_settings" "$compositor_settings" | \
        sed "s|\$HOME|$user_home|g" | \
        sed "s|/home/don/bd-configs/assets|$config_dir/donarch/assets|g" | \
        sed "s|/home/don/.config/arch-config/modules/bdots-hypr|$config_dir/donarch/assets|g" \
        > "$dms_dir/settings.json"

    # Copy other DMS files from compositor-specific directory
    if [ -d "$repo_dir/configs/$compositor/DankMaterialShell/themes" ]; then
        cp -r "$repo_dir/configs/$compositor/DankMaterialShell/themes" "$dms_dir/"
    fi

    # Also copy from shared if they exist
    if [ -d "$repo_dir/configs/shared/DankMaterialShell/themes" ]; then
        cp -r "$repo_dir/configs/shared/DankMaterialShell/themes" "$dms_dir/" 2>/dev/null || true
    fi

    # Copy any CSS files
    cp "$repo_dir/configs/shared/DankMaterialShell"/*.css "$dms_dir/" 2>/dev/null || true
    cp "$repo_dir/configs/$compositor/DankMaterialShell"/*.css "$dms_dir/" 2>/dev/null || true

    log_success "DMS configurations merged"
}

# Configure shell startup for compositors
configure_shell_startup() {
    local repo_dir="$1"
    local compositor="$2"  # "hyprland" or "niri"
    local selected_shell="${3:-noctalia}"
    local user_home=$(get_user_home)
    local config_dir="$user_home/.config"

    log_info "Configuring $compositor startup for $selected_shell shell..."

    local shell_name
    local launch_cmd
    local launcher_cmd

    if [ "$selected_shell" = "noctalia" ]; then
        shell_name="Noctalia Shell"
        launch_cmd="qs -c noctalia-shell"
        launcher_cmd="qs -c noctalia-shell ipc call launcher toggle"
    else
        shell_name="Dank Material Shell"
        launch_cmd="dms run"
        launcher_cmd="dms ipc call spotlight toggle"
    fi

    if [ "$compositor" = "hyprland" ]; then
        # Create hyprland shell startup config
        local hypr_config_dir="$config_dir/hypr"
        mkdir -p "$hypr_config_dir"

        # Generate shell-start.conf
        cat > "$hypr_config_dir/shell-start.conf" << EOF
# Shell Switcher - Startup Configuration
# This file is managed by shell-switch - manual edits will be overwritten
# Current shell: ${shell_name}

exec-once = ${launch_cmd}
EOF

        # Generate shell-binds.conf
        cat > "$hypr_config_dir/shell-binds.conf" << EOF
# Shell Switcher - Keybindings
# This file is managed by shell-switch - manual edits will be overwritten
# Current shell: ${shell_name}

# Application launcher
bind = SUPER, Space, exec, ${launcher_cmd}
EOF

        log_success "Hyprland shell configuration created"

    elif [ "$compositor" = "niri" ]; then
        # Create niri shell startup config
        local niri_config_dir="$config_dir/niri"
        mkdir -p "$niri_config_dir"

        # Format command as quoted arguments for KDL
        local launch_cmd_args
        launch_cmd_args=$(echo "$launch_cmd" | awk '{for(i=1;i<=NF;i++) printf "\"%s\" ", $i}' | sed 's/ $//')

        local launcher_cmd_args
        launcher_cmd_args=$(echo "$launcher_cmd" | awk '{for(i=1;i<=NF;i++) printf "\"%s\" ", $i}' | sed 's/ $//')

        # Generate shell-switcher-startup.kdl
        cat > "$niri_config_dir/shell-switcher-startup.kdl" << EOF
// Shell Switcher - Startup Configuration
// This file is managed by shell-switch - manual edits will be overwritten
// Current shell: ${shell_name}

spawn-at-startup ${launch_cmd_args}
EOF

        # Generate shell-switcher-binds.kdl
        cat > "$niri_config_dir/shell-switcher-binds.kdl" << EOF
// Shell Switcher - Keybindings
// This file is managed by shell-switch - manual edits will be overwritten
// Current shell: ${shell_name}

// Application launcher
Mod+Space {
    spawn ${launcher_cmd_args}
    hotkey-overlay-title = "Launcher"
}
EOF

        log_success "Niri shell configuration created"
    fi
}

# Main deployment function
deploy_configurations() {
    local repo_dir="$1"
    local install_hyprland="$2"
    local install_niri="$3"
    local selected_shell="${4:-noctalia}"

    log_step "Deploying Configurations"

    # Deploy assets first
    deploy_assets "$repo_dir"

    # Always deploy shared configs
    deploy_shared_configs "$repo_dir"

    # Deploy compositor-specific configs
    if [ "$install_hyprland" = "true" ]; then
        deploy_hyprland_configs "$repo_dir"
        configure_shell_startup "$repo_dir" "hyprland" "$selected_shell"
        merge_dms_configs "$repo_dir" "hyprland" "$selected_shell"
    fi

    if [ "$install_niri" = "true" ]; then
        deploy_niri_configs "$repo_dir"
        configure_shell_startup "$repo_dir" "niri" "$selected_shell"
        # If both are installed and we already merged for hyprland, skip niri merge
        # Or we could merge both - for now, prefer the first one selected
        if [ "$install_hyprland" != "true" ]; then
            merge_dms_configs "$repo_dir" "niri" "$selected_shell"
        fi
    fi

    log_success "All configurations deployed successfully"
}
