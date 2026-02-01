#!/bin/bash
#
# Moltbot Uninstallation Script
# Removes moltbot and its configuration
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"

confirm_uninstall() {
    echo -e "${LIB_YELLOW}WARNING: This will remove moltbot and all its data!${LIB_NC}"
    echo ""
    read -p "Are you sure you want to uninstall moltbot? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
}

stop_service() {
    log_info "Stopping moltbot service..."

    if systemctl is-active --quiet moltbot-gateway; then
        systemctl stop moltbot-gateway
        log_success "Service stopped"
    else
        log_info "Service was not running"
    fi

    if systemctl is-enabled --quiet moltbot-gateway 2>/dev/null; then
        systemctl disable moltbot-gateway
        log_success "Service disabled"
    fi
}

remove_service() {
    log_info "Removing systemd service..."

    if [[ -f /etc/systemd/system/moltbot-gateway.service ]]; then
        rm /etc/systemd/system/moltbot-gateway.service
        systemctl daemon-reload
        log_success "Systemd service removed"
    else
        log_info "Service file not found"
    fi
}

remove_sudoers() {
    log_info "Removing deploy sudoers rules..."

    if [[ -f /etc/sudoers.d/moltbot-deploy ]]; then
        rm /etc/sudoers.d/moltbot-deploy
        log_success "Sudoers rules removed"
    else
        log_info "Sudoers file not found"
    fi
}

remove_symlink() {
    log_info "Removing /usr/local/bin/moltbot symlink..."

    if [[ -L /usr/local/bin/moltbot ]]; then
        rm /usr/local/bin/moltbot
        log_success "Symlink removed"
    else
        log_info "Symlink not found"
    fi
}

remove_user() {
    log_info "Removing moltbot user..."

    if id "$MOLTBOT_USER" &>/dev/null; then
        read -p "Remove moltbot user and home directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            userdel -r "$MOLTBOT_USER" 2>/dev/null || true
            log_success "User and home directory removed"
        else
            log_info "User preserved"
        fi
    else
        log_info "User not found"
    fi
}

main() {
    log_info "Moltbot Uninstallation Script"
    echo ""

    require_root
    confirm_uninstall

    stop_service
    remove_service
    remove_sudoers
    remove_symlink
    remove_user

    echo ""
    log_success "Moltbot has been uninstalled"
}

main "$@"
