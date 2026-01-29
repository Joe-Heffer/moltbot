#!/bin/bash
#
# Moltbot Update Script
# Updates moltbot to the latest version with zero-downtime where possible
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
SERVICE_NAME="moltbot-gateway"

check_user_exists() {
    if ! id "$MOLTBOT_USER" &>/dev/null; then
        log_error "User ${MOLTBOT_USER} does not exist. Run install.sh first."
        exit 1
    fi
}

get_current_version() {
    sudo -u "$MOLTBOT_USER" -i moltbot --version 2>/dev/null || echo "unknown"
}

update_moltbot() {
    log_info "Updating moltbot..."

    CURRENT_VERSION=$(get_current_version)
    log_info "Current version: ${CURRENT_VERSION}"

    # Update via npm
    sudo -u "$MOLTBOT_USER" -i bash -c '
        export PATH="${HOME}/.npm-global/bin:${PATH}"
        npm install -g moltbot@beta
    '

    NEW_VERSION=$(get_current_version)
    log_success "Updated to version: ${NEW_VERSION}"
}

restart_service() {
    log_info "Restarting ${SERVICE_NAME}..."

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
        log_success "Service restarted"
    else
        log_warn "Service was not running, starting it..."
        systemctl start "$SERVICE_NAME"
        log_success "Service started"
    fi
}

wait_for_healthy() {
    log_info "Waiting for service to become healthy..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            # Check if configured port is listening
            if ss -tlnp 2>/dev/null | grep -q ":${MOLTBOT_PORT}\b"; then
                log_success "Service is healthy (attempt ${attempt}/${max_attempts})"
                return 0
            fi
        fi

        echo -n "."
        sleep 1
        ((attempt++))
    done

    echo ""
    log_error "Service failed to become healthy after ${max_attempts} seconds"
    return 1
}

show_status() {
    echo ""
    log_info "Current status:"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
}

run_doctor() {
    log_info "Running moltbot doctor..."
    sudo -u "$MOLTBOT_USER" -i moltbot doctor 2>/dev/null || true
}

main() {
    log_info "Moltbot Update Script"
    echo ""

    require_root
    validate_port "$MOLTBOT_PORT" "MOLTBOT_PORT"
    check_user_exists
    update_moltbot
    restart_service

    if wait_for_healthy; then
        show_status
        log_success "Update completed successfully"
    else
        show_status
        log_error "Update completed but service may not be healthy"
        exit 1
    fi
}

main "$@"
