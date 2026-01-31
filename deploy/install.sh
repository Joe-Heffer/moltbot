#!/bin/bash
#
# Moltbot Installation Script
# Installs moltbot and configures it as a systemd service
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
OS_FAMILY=""
TOTAL_RAM_MB=0
MEMORY_MAX=""
NODE_HEAP_SIZE=""

# Track installation progress for cleanup on failure
INSTALL_PHASE=""

cleanup_on_failure() {
    # Always clean up temporary swap, even on failure
    remove_temp_swap
    if [[ -n "$INSTALL_PHASE" ]]; then
        log_error "Installation failed during phase: ${INSTALL_PHASE}"
        log_error "The system may be in a partially configured state."
        log_error "Review the output above and re-run the installer after fixing any issues."
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

    # Set npm global prefix for the moltbot user
    # Write .npmrc directly to avoid sudo HOME environment issues
    # (sudo -u without -H keeps caller's HOME, so npm config set
    # would write to the wrong .npmrc)
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
    # Add Homebrew (Linuxbrew) to shell environment if installed
    if ! grep -q "linuxbrew" "${MOLTBOT_HOME}/.bashrc" 2>/dev/null; then
        cat >> "${MOLTBOT_HOME}/.bashrc" << 'BREWRC'

# Homebrew (Linuxbrew) — required by moltbot skills
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
BREWRC
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
    log_info "Installing moltbot..."

    # Clean up stale npm temporary directories that cause ENOTEMPTY on reinstall.
    # npm renames the existing package to a dotfile before replacing it; if a
    # previous run was interrupted these leftovers block the next attempt.
    local npm_modules="${MOLTBOT_HOME}/.npm-global/lib/node_modules"
    if [[ -d "$npm_modules" ]]; then
        find "$npm_modules" -maxdepth 1 -name '.moltbot-*' -type d -exec rm -rf {} + 2>/dev/null || true
    fi

    # Ensure enough memory for npm install (OOM-killed on low-memory VPS)
    ensure_swap_for_install

    # Install moltbot as the moltbot user (-i loads login shell which sets HOME)
    # Use @beta tag: the @latest (v0.1.0) tag is a placeholder package
    # missing the "bin" field, so npm creates no executable.
    # See https://github.com/moltbot/moltbot/issues/3787
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

    log_success "Moltbot installed at ${MOLTBOT_HOME}/.npm-global/bin/moltbot"
    sudo -u "$MOLTBOT_USER" -i moltbot --version || true
}

install_homebrew() {
    log_info "Installing Homebrew (Linuxbrew) for skill dependencies..."

    if [[ -x "${LIB_BREW_PREFIX}/bin/brew" ]]; then
        log_info "Homebrew already installed at ${LIB_BREW_PREFIX}"
        return 0
    fi

    # Clone Homebrew core repository (shallow clone to save time and space)
    mkdir -p "${LIB_BREW_PREFIX}"
    git clone --depth=1 https://github.com/Homebrew/brew "${LIB_BREW_PREFIX}/Homebrew"

    # Create bin directory with symlink to brew executable
    mkdir -p "${LIB_BREW_PREFIX}/bin"
    ln -sf ../Homebrew/bin/brew "${LIB_BREW_PREFIX}/bin/brew"

    # Create standard Homebrew directory structure
    mkdir -p "${LIB_BREW_PREFIX}/etc" \
             "${LIB_BREW_PREFIX}/include" \
             "${LIB_BREW_PREFIX}/lib" \
             "${LIB_BREW_PREFIX}/opt" \
             "${LIB_BREW_PREFIX}/sbin" \
             "${LIB_BREW_PREFIX}/share" \
             "${LIB_BREW_PREFIX}/var/homebrew/linked" \
             "${LIB_BREW_PREFIX}/Cellar"

    # Set ownership so moltbot user can install packages via brew
    chown -R "${MOLTBOT_USER}:${MOLTBOT_USER}" "${LIB_BREW_PREFIX}"

    # Verify installation
    if [[ ! -x "${LIB_BREW_PREFIX}/bin/brew" ]]; then
        log_error "Homebrew installation failed — brew binary not found"
        exit 1
    fi

    log_success "Homebrew installed at ${LIB_BREW_PREFIX}"
}

setup_systemd_service() {
    log_info "Setting up systemd service..."

    # Create service file with auto-tuned resource limits
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
Environment=PATH=${MOLTBOT_HOME}/.npm-global/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/bin:/bin
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
ReadWritePaths=${MOLTBOT_CONFIG_DIR} ${MOLTBOT_DATA_DIR} ${MOLTBOT_HOME}/.npm-global ${MOLTBOT_HOME}/.clawdbot ${MOLTBOT_HOME}/clawd /home/linuxbrew/.linuxbrew
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
}

print_next_steps() {
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
    log_info "Starting Moltbot installation..."
    echo ""

    require_root
    validate_port "$MOLTBOT_PORT" "MOLTBOT_PORT"
    detect_os

    INSTALL_PHASE="resource detection"
    detect_resources

    INSTALL_PHASE="dependency installation"
    install_dependencies

    INSTALL_PHASE="Node.js installation"
    install_nodejs

    INSTALL_PHASE="user creation"
    create_moltbot_user

    INSTALL_PHASE="homebrew installation"
    install_homebrew

    INSTALL_PHASE="moltbot installation"
    install_moltbot

    INSTALL_PHASE="systemd setup"
    setup_systemd_service

    INSTALL_PHASE="firewall configuration"
    configure_firewall

    INSTALL_PHASE="environment template"
    copy_env_template

    # Clear phase — installation succeeded
    INSTALL_PHASE=""
    print_next_steps
}

main "$@"
