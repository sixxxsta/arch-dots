#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[ru-en] %s\n' "$1"
}

if [[ "${EUID}" -eq 0 ]]; then
    log "Run this script as a normal user (it uses sudo internally)."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is required."
    exit 1
fi

log "Enabling RU/EN locales in /etc/locale.gen..."
sudo sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#\s*ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen

log "Generating locales..."
sudo locale-gen

log "Setting default locale to Russian (change manually if needed)..."
sudo localectl set-locale LANG=ru_RU.UTF-8

log "Configuring keyboard layouts US/RU with Alt+Shift switch..."
sudo localectl set-keymap us,ru
sudo localectl set-x11-keymap us,ru "" "" grp:alt_shift_toggle

log "Done. Re-login (or reboot) to apply language/input changes everywhere."
