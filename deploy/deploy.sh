#!/bin/bash
#
# Moltbot Deployment Script
# Idempotent: handles both first-time installation and subsequent updates.
# Always regenerates the systemd service so that configuration changes
# (security hardening, resource limits, paths, etc.) are rolled out on
# every deployment — not just on first install.
#
# Supports: Ubuntu/Debian and Oracle Linux/RHEL
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_HOME="/home/${MOLTBOT_USER}"
MOLTBOT_CONFIG_DIR="${MOLTBOT_HOME}/.config/moltbot"
MOLTBOT_DATA_DIR="${MOLTBOT_HOME}/.local/share/moltbot"
NODE_VERSION="22"
MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
SERVICE_NAME="moltbot-gateway"
OS_FAMILY=""
TOTAL_RAM_MB=0
MEMORY_MAX=""
NODE_HEAP_SIZE=""

# Track progress for cleanup on failure
DEPLOY_PHASE=""

# Whether the service was already running before this deployment
SERVICE_WAS_RUNNING=false

cleanup_on_failure() {
    # Always clean up temporary swap, even on failure
    remove_temp_swap
    if [[ -n "$DEPLOY_PHASE" ]]; then
        log_error "Deployment failed during phase: ${DEPLOY_PHASE}"
        log_error "The system may be in a partially configured state."
        log_error "Review the output above and re-run the script after fixing any issues."
    fi
}

trap cleanup_on_failure ERR

detect_os() {
    if command -v apt-get &> /dev/null; then
        OS_FAMILY="debian"
        log_info "Detected Debian/Ubuntu: $(lsb_release -ds 2>/dev/null || (source /etc/os-release && echo "$PRETTY_NAME"))"
    elif command -v dnf &> /dev/null; then
        OS_FAMILY="rhel"
        log_info "Detected RHEL/Oracle Linux: $(cat /etc/oracle-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || echo 'unknown')"
    else
        log_error "Unsupported OS: requires apt-get (Debian/Ubuntu) or dnf (RHEL/Oracle Linux)"
        exit 1
    fi
}

detect_resources() {
    log_info "Detecting system resources..."

    # Detect total RAM in MB
    TOTAL_RAM_MB=$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)
    log_info "Total RAM: ${TOTAL_RAM_MB} MB"

    if [[ "$TOTAL_RAM_MB" -lt 2048 ]]; then
        log_error "System has less than 2 GB RAM (minimum requirement)"
        log_error "Moltbot requires at least 2 GB RAM to run reliably."
        log_error "See: https://docs.molt.bot/help/faq"
        exit 1
    elif [[ "$TOTAL_RAM_MB" -lt 4096 ]]; then
        log_warn "System has less than 4 GB RAM (recommended)"
        log_info "Applying low-memory optimizations automatically"
    fi

    # Compute V8 heap and systemd MemoryMax from available RAM.
    # See compute_memory_limits() in lib.sh for the formula.
    compute_memory_limits
    MEMORY_MAX="$LIB_MEMORY_MAX"
    NODE_HEAP_SIZE="$LIB_NODE_HEAP_SIZE"

    log_info "Systemd MemoryMax: ${MEMORY_MAX}"
    log_info "Node.js heap limit: ${NODE_HEAP_SIZE} MB"
}

install_dependencies() {
    log_info "Installing system dependencies..."

    if [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get update
        apt-get install -y \
            curl \
            wget \
            git \
            gcc \
            g++ \
            make \
            python3 \
            tar \
            xz-utils \
            unzip \
            jq
    else
        dnf check-update || true
        dnf install -y \
            curl \
            wget \
            git \
            gcc \
            gcc-c++ \
            make \
            python3 \
            tar \
            xz \
            unzip \
            jq \
            firewalld \
            || true
    fi

    log_success "System dependencies installed"
}

install_nodejs() {
    log_info "Installing Node.js ${NODE_VERSION}..."

    # Check if Node.js is already installed with correct version
    if command -v node &> /dev/null; then
        CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$CURRENT_NODE_VERSION" -ge "$NODE_VERSION" ]]; then
            log_info "Node.js $(node -v) already installed"
            return 0
        fi
    fi

    # Install Node.js via NodeSource repository
    if [[ "$OS_FAMILY" == "debian" ]]; then
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
        apt-get install -y nodejs
    else
        curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash -
        dnf install -y nodejs
    fi

    # Verify installation
    if ! command -v node &> /dev/null; then
        log_error "Node.js installation failed — 'node' command not found"
        exit 1
    fi

    NODE_INSTALLED_VERSION=$(node -v)
    log_success "Node.js ${NODE_INSTALLED_VERSION} installed"

    # Install pnpm globally
    npm install -g pnpm
    log_success "pnpm installed"
}

create_moltbot_user() {
    log_info "Creating moltbot user..."

    if id "$MOLTBOT_USER" &>/dev/null; then
        log_info "User ${MOLTBOT_USER} already exists"
    else
        useradd -r -m -s /bin/bash -d "$MOLTBOT_HOME" "$MOLTBOT_USER"
        log_success "User ${MOLTBOT_USER} created"
    fi

    # Create necessary directories
    mkdir -p "$MOLTBOT_CONFIG_DIR"
    mkdir -p "$MOLTBOT_DATA_DIR"
    mkdir -p "${MOLTBOT_HOME}/.npm-global"
    mkdir -p "${MOLTBOT_HOME}/.clawdbot"
    chmod 700 "${MOLTBOT_HOME}/.clawdbot"
    mkdir -p "${MOLTBOT_HOME}/clawd/memory"
    chmod 700 "${MOLTBOT_HOME}/clawd"

    # Ensure npm prefix is configured.
    # Write .npmrc directly to avoid sudo HOME environment issues
    # (sudo -u without -H keeps caller's HOME, so npm config set
    # would write to the wrong .npmrc).
    # Also fixes missing .npmrc from earlier installs.
    cat > "${MOLTBOT_HOME}/.npmrc" << NPMRC
prefix=${MOLTBOT_HOME}/.npm-global
NPMRC
    chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_HOME}/.npmrc"

    # Ensure PATH includes npm global bin in shell profiles.
    # useradd -r (system user) skips /etc/skel, so the moltbot user may
    # have no .profile at all.  Login shells (sudo -u moltbot -i) read
    # .profile / .bash_profile — not .bashrc — so the PATH must be set
    # there.  We also keep .bashrc for interactive non-login shells.
    if ! grep -q ".npm-global/bin" "${MOLTBOT_HOME}/.bashrc" 2>/dev/null; then
        echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"' >> "${MOLTBOT_HOME}/.bashrc"
    fi
    if [[ ! -f "${MOLTBOT_HOME}/.profile" ]]; then
        # Create a minimal .profile that mirrors the Ubuntu /etc/skel default:
        # source .bashrc (if it exists) and set the npm-global PATH for login shells.
        cat > "${MOLTBOT_HOME}/.profile" << 'PROFILE'
# ~/.profile: executed by the command interpreter for login shells.

# if running bash, include .bashrc if it exists
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's npm global bin if it exists
if [ -d "$HOME/.npm-global/bin" ]; then
    PATH="$HOME/.npm-global/bin:$PATH"
fi
PROFILE
        chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_HOME}/.profile"
    elif ! grep -q ".npm-global/bin" "${MOLTBOT_HOME}/.profile" 2>/dev/null; then
        echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"' >> "${MOLTBOT_HOME}/.profile"
    fi

    chown -R "${MOLTBOT_USER}:${MOLTBOT_USER}" "$MOLTBOT_HOME"
    log_success "Directories configured"
}

install_moltbot() {
    log_info "Installing/updating moltbot..."

    # Show current version if already installed
    if command -v moltbot &> /dev/null; then
        local current_version
        current_version=$(sudo -u "$MOLTBOT_USER" -i moltbot --version 2>/dev/null || echo "unknown")
        log_info "Current version: ${current_version}"
    fi

    # Clean up stale npm temporary directories that cause ENOTEMPTY on reinstall.
    # npm renames the existing package to a dotfile before replacing it; if a
    # previous run was interrupted these leftovers block the next attempt.
    local npm_modules="${MOLTBOT_HOME}/.npm-global/lib/node_modules"
    if [[ -d "$npm_modules" ]]; then
        find "$npm_modules" -maxdepth 1 -name '.moltbot-*' -type d -exec rm -rf {} + 2>/dev/null || true
    fi

    # Ensure enough memory for npm install (OOM-killed on low-memory VPS)
    ensure_swap_for_install

    # Install/update moltbot as the moltbot user (-i loads login shell which sets HOME)
    sudo -u "$MOLTBOT_USER" -i npm install -g openclaw@latest

    remove_temp_swap

    # Verify binary was installed to the correct location
    if [[ ! -x "${MOLTBOT_HOME}/.npm-global/bin/moltbot" ]]; then
        log_error "moltbot binary not found at ${MOLTBOT_HOME}/.npm-global/bin/moltbot"
        log_error "npm prefix may not be configured correctly"
        log_error "Contents of ${MOLTBOT_HOME}/.npmrc:"
        cat "${MOLTBOT_HOME}/.npmrc" 2>/dev/null || echo "(file not found)"
        log_error "npm global prefix reported by npm:"
        sudo -u "$MOLTBOT_USER" -i npm prefix -g 2>/dev/null || echo "(unable to determine)"
        exit 1
    fi

    # Create a symlink in /usr/local/bin so that `moltbot` is on the default
    # PATH for all users and shell types (login, non-login, sudo without -i).
    ln -sf "${MOLTBOT_HOME}/.npm-global/bin/moltbot" /usr/local/bin/moltbot

    local new_version
    new_version=$(sudo -u "$MOLTBOT_USER" -i moltbot --version 2>/dev/null || echo "unknown")
    log_success "Moltbot version: ${new_version}"
}

setup_systemd_service() {
    log_info "Setting up systemd service..."

    # Always regenerate the service file so that configuration changes
    # (security hardening, paths, environment, etc.) are rolled out on
    # every deployment — not just on first install.
    cat > /etc/systemd/system/moltbot-gateway.service << EOF
[Unit]
Description=Moltbot Gateway - Personal AI Assistant
Documentation=https://docs.molt.bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${MOLTBOT_USER}
Group=${MOLTBOT_USER}
WorkingDirectory=${MOLTBOT_HOME}
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=${NODE_HEAP_SIZE}
Environment=PATH=${MOLTBOT_HOME}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=${MOLTBOT_HOME}
EnvironmentFile=-${MOLTBOT_CONFIG_DIR}/.env
ExecStartPre=+/bin/sh -c 'mkdir -p ${MOLTBOT_HOME}/.clawdbot ${MOLTBOT_HOME}/clawd/memory && chown -R ${MOLTBOT_USER}:${MOLTBOT_USER} ${MOLTBOT_HOME}/.clawdbot ${MOLTBOT_HOME}/clawd && chmod 700 ${MOLTBOT_HOME}/.clawdbot ${MOLTBOT_HOME}/clawd'
ExecStartPre=/bin/sh -c 'echo "moltbot-gateway: pre-start checks..." && test -x ${MOLTBOT_HOME}/.npm-global/bin/moltbot || { echo "FATAL: ${MOLTBOT_HOME}/.npm-global/bin/moltbot not found or not executable"; exit 1; } && test -f ${MOLTBOT_CONFIG_DIR}/.env || echo "WARN: ${MOLTBOT_CONFIG_DIR}/.env not found, running without env file"'
ExecStart=${MOLTBOT_HOME}/.npm-global/bin/moltbot gateway --port ${MOLTBOT_PORT}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=moltbot

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${MOLTBOT_CONFIG_DIR} ${MOLTBOT_DATA_DIR} ${MOLTBOT_HOME}/.npm-global ${MOLTBOT_HOME}/.clawdbot ${MOLTBOT_HOME}/clawd
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
LockPersonality=yes

# Resource limits
LimitNOFILE=65535
MemoryMax=${MEMORY_MAX}

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload

    log_success "Systemd service configured"
}

configure_firewall() {
    log_info "Configuring firewall..."

    if systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="${MOLTBOT_PORT}/tcp"
        firewall-cmd --reload
        log_success "Firewall configured via firewalld (port ${MOLTBOT_PORT} opened)"
    elif command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow "${MOLTBOT_PORT}/tcp"
        log_success "Firewall configured via ufw (port ${MOLTBOT_PORT} opened)"
    else
        log_warn "No active firewall detected, skipping firewall configuration"
    fi
}

copy_env_template() {
    log_info "Creating environment template..."

    if [[ -f "${SCRIPT_DIR}/moltbot.env.template" ]]; then
        cp "${SCRIPT_DIR}/moltbot.env.template" "${MOLTBOT_CONFIG_DIR}/moltbot.env.template"
        chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_CONFIG_DIR}/moltbot.env.template"
        log_success "Environment template copied to ${MOLTBOT_CONFIG_DIR}"

        # Create .env from template if it doesn't already exist
        if [[ ! -f "${MOLTBOT_CONFIG_DIR}/.env" ]]; then
            cp "${SCRIPT_DIR}/moltbot.env.template" "${MOLTBOT_CONFIG_DIR}/.env"
            chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_CONFIG_DIR}/.env"
            chmod 600 "${MOLTBOT_CONFIG_DIR}/.env"
            log_warn "Created ${MOLTBOT_CONFIG_DIR}/.env from template — edit it to add your API keys before starting the service"
        else
            log_info "Existing .env file preserved at ${MOLTBOT_CONFIG_DIR}/.env"
        fi
    fi

    # Copy fallback configuration template
    if [[ -f "${SCRIPT_DIR}/moltbot.fallbacks.json" ]]; then
        cp "${SCRIPT_DIR}/moltbot.fallbacks.json" "${MOLTBOT_CONFIG_DIR}/moltbot.fallbacks.json"
        chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_CONFIG_DIR}/moltbot.fallbacks.json"
        log_success "Fallback configuration template copied to ${MOLTBOT_CONFIG_DIR}"
    fi
}

setup_model_fallbacks() {
    log_info "Setting up AI provider fallbacks..."

    if [[ -f "${SCRIPT_DIR}/configure-fallbacks.sh" ]]; then
        # Run fallback configuration script
        # This will only configure fallbacks if API keys are present
        "${SCRIPT_DIR}/configure-fallbacks.sh" || {
            log_warn "Fallback configuration will be applied after onboarding"
        }
    else
        log_warn "Fallback configuration script not found, skipping"
    fi
}

restart_service() {
    log_info "Restarting ${SERVICE_NAME}..."

    # Stop the service and reset failure state to break any existing restart
    # loops.  Without this, systemd may still be scheduling restarts from a
    # previous crash cycle, and our `start` would race with those restarts.
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    log_success "Service started (clean)"
}

wait_for_healthy() {
    log_info "Waiting for service to become healthy..."

    local max_attempts=120
    local attempt=1
    local last_pid=""
    local restarts=0
    local max_restarts=5
    local current_pid

    while [ $attempt -le $max_attempts ]; do
        if systemctl is-failed --quiet "$SERVICE_NAME"; then
            echo ""
            log_error "Service entered failed state"
            return 1
        fi

        if systemctl is-active --quiet "$SERVICE_NAME"; then
            # Track PID to detect crash-restart loops
            current_pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null || echo "")
            if [[ -n "$last_pid" && "$last_pid" != "0" \
               && -n "$current_pid" && "$current_pid" != "0" \
               && "$last_pid" != "$current_pid" ]]; then
                restarts=$((restarts + 1))
                log_warn "Service restarted during health check (PID ${last_pid} -> ${current_pid}, #${restarts})"
                if [[ "$restarts" -ge "$max_restarts" ]]; then
                    echo ""
                    log_error "Service restarted ${restarts} times during health check (crash loop)"
                    return 1
                fi
            fi
            if [[ -n "$current_pid" && "$current_pid" != "0" ]]; then
                last_pid="$current_pid"
            fi

            # Check if configured port is listening
            if ss -tln 2>/dev/null | grep -q ":${MOLTBOT_PORT}\b"; then
                echo ""
                log_success "Service is healthy (${attempt}s)"
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

run_doctor() {
    log_info "Running moltbot doctor --repair..."
    sudo -u "$MOLTBOT_USER" -i moltbot doctor --repair 2>/dev/null || true
}

show_status() {
    echo ""
    log_info "Current status:"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
}

print_first_install_steps() {
    echo ""
    echo "=============================================="
    echo -e "${LIB_GREEN}Moltbot installation complete!${LIB_NC}"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Run the onboarding wizard as the moltbot user:"
    echo "   sudo -u ${MOLTBOT_USER} -i moltbot onboard"
    echo ""
    echo "2. Start the service:"
    echo "   sudo systemctl start moltbot-gateway"
    echo "   sudo systemctl enable moltbot-gateway"
    echo ""
    echo "3. Check service status:"
    echo "   sudo systemctl status moltbot-gateway"
    echo "   sudo journalctl -u moltbot-gateway -f"
    echo ""
    echo "4. Access the Gateway UI at:"
    echo "   http://<your-vm-ip>:${MOLTBOT_PORT}"
    echo ""
    echo "Configuration directory: ${MOLTBOT_CONFIG_DIR}"
    echo "Data directory: ${MOLTBOT_DATA_DIR}"
    echo ""
    echo "Security recommendations:"
    echo "  - Use Tailscale for secure remote access"
    echo "  - Configure DM pairing policies"
    echo "  - Run 'moltbot doctor' to check configuration"
    echo ""
}

main() {
    log_info "Starting Moltbot deployment..."
    echo ""

    require_root
    validate_port "$MOLTBOT_PORT" "MOLTBOT_PORT"

    # Check whether the service is already running (i.e. this is an update,
    # not a first-time install).  We use this later to decide whether to
    # restart the service or print first-install instructions.
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        SERVICE_WAS_RUNNING=true
    fi

    DEPLOY_PHASE="OS detection"
    detect_os

    DEPLOY_PHASE="resource detection"
    detect_resources

    DEPLOY_PHASE="dependency installation"
    install_dependencies

    DEPLOY_PHASE="Node.js installation"
    install_nodejs

    DEPLOY_PHASE="user creation"
    create_moltbot_user

    DEPLOY_PHASE="moltbot installation"
    install_moltbot

    DEPLOY_PHASE="systemd setup"
    setup_systemd_service

    DEPLOY_PHASE="firewall configuration"
    configure_firewall

    DEPLOY_PHASE="environment template"
    copy_env_template

    DEPLOY_PHASE="model fallback configuration"
    setup_model_fallbacks

    # Clear phase — core deployment succeeded
    DEPLOY_PHASE=""

    # If the service was already running this is an update: restart and
    # health-check.  On first install, print manual next steps instead
    # (the user needs to run onboarding before starting the service).
    if [[ "$SERVICE_WAS_RUNNING" == true ]]; then
        DEPLOY_PHASE="service restart"
        restart_service

        if wait_for_healthy; then
            run_doctor
            show_status
            log_success "Deployment completed successfully"
        else
            show_status
            log_error "Deployment completed but service may not be healthy"
            exit 1
        fi
        DEPLOY_PHASE=""
    else
        print_first_install_steps
    fi
}

main "$@"
