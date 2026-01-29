#!/bin/bash
#
# Moltbot Uninstallation Script for Oracle Linux
# Removes moltbot and its configuration
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

confirm_uninstall() {
    echo -e "${YELLOW}WARNING: This will remove moltbot and all its data!${NC}"
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

remove_firewall_rule() {
    log_info "Removing firewall rule..."

    if systemctl is-active --quiet firewalld; then
        if firewall-cmd --list-ports | grep -q "${MOLTBOT_PORT}/tcp"; then
            firewall-cmd --permanent --remove-port=${MOLTBOT_PORT}/tcp
            firewall-cmd --reload
            log_success "Firewall rule removed"
        else
            log_info "Firewall rule not found"
        fi
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

    check_root
    confirm_uninstall

    stop_service
    remove_service
    remove_firewall_rule
    remove_user

    echo ""
    log_success "Moltbot has been uninstalled"
}

main "$@"
