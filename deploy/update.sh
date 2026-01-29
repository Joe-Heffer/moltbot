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

ensure_npm_prefix() {
    local npmrc_path="/home/${MOLTBOT_USER}/.npmrc"
    if ! grep -q "prefix=" "$npmrc_path" 2>/dev/null; then
        echo "prefix=/home/${MOLTBOT_USER}/.npm-global" >> "$npmrc_path"
        chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "$npmrc_path"
        log_info "Fixed: wrote npm prefix to .npmrc"
    fi
}

update_moltbot() {
    log_info "Updating moltbot..."

    CURRENT_VERSION=$(get_current_version)
    log_info "Current version: ${CURRENT_VERSION}"

    # Ensure npm prefix is configured (fixes missing .npmrc from earlier installs)
    ensure_npm_prefix

    # Ensure enough memory for npm install (OOM-killed on <1 GB VPS)
    ensure_swap_for_install

    # Update via npm (-i sources .profile which sets PATH to include .npm-global/bin)
    sudo -u "$MOLTBOT_USER" -i npm install -g moltbot@beta

    remove_temp_swap

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

retune_service_resources() {
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    if [[ ! -f "$service_file" ]]; then
        log_warn "Service file not found at ${service_file}, skipping resource re-tune"
        return 0
    fi

    compute_memory_limits

    # Extract current values from the service file
    local current_heap
    current_heap=$(sed -n 's/.*--max-old-space-size=\([0-9]*\).*/\1/p' "$service_file")
    local current_memmax
    current_memmax=$(sed -n 's/^MemoryMax=\(.*\)/\1/p' "$service_file")

    # Skip if already optimal
    if [[ "$current_heap" == "$LIB_NODE_HEAP_SIZE" ]] && \
       [[ "$current_memmax" == "$LIB_MEMORY_MAX" ]]; then
        log_info "Service resource limits already optimal (heap=${LIB_NODE_HEAP_SIZE}M, MemoryMax=${LIB_MEMORY_MAX})"
        return 0
    fi

    log_info "Re-tuning service resource limits for current system memory..."
    [[ -n "$current_heap" ]] && log_info "  Node.js heap: ${current_heap}M → ${LIB_NODE_HEAP_SIZE}M"
    [[ -n "$current_memmax" ]] && log_info "  MemoryMax: ${current_memmax} → ${LIB_MEMORY_MAX}"

    # Update the service file in place
    sed -i "s/--max-old-space-size=[0-9]*/--max-old-space-size=${LIB_NODE_HEAP_SIZE}/" "$service_file"
    sed -i "s/^MemoryMax=.*/MemoryMax=${LIB_MEMORY_MAX}/" "$service_file"

    systemctl daemon-reload
    log_success "Service resource limits updated"
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
    retune_service_resources
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
