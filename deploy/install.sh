#!/bin/bash
#
# Moltbot Installation Script
# Installs moltbot and configures it as a systemd service
# Supports: Ubuntu/Debian and Oracle Linux/RHEL
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_HOME="/home/${MOLTBOT_USER}"
MOLTBOT_CONFIG_DIR="${MOLTBOT_HOME}/.config/moltbot"
MOLTBOT_DATA_DIR="${MOLTBOT_HOME}/.local/share/moltbot"
NODE_VERSION="22"
MOLTBOT_PORT="${MOLTBOT_PORT:-18789}"
OS_FAMILY=""

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

detect_os() {
    if command -v apt-get &> /dev/null; then
        OS_FAMILY="debian"
        log_info "Detected Debian/Ubuntu: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    elif command -v dnf &> /dev/null; then
        OS_FAMILY="rhel"
        log_info "Detected RHEL/Oracle Linux: $(cat /etc/oracle-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || echo 'unknown')"
    else
        log_error "Unsupported OS: requires apt-get (Debian/Ubuntu) or dnf (RHEL/Oracle Linux)"
        exit 1
    fi
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
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
        apt-get install -y nodejs
    else
        curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash -
        dnf install -y nodejs
    fi

    # Verify installation
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

    # Set npm global prefix for the moltbot user
    sudo -u "$MOLTBOT_USER" npm config set prefix "${MOLTBOT_HOME}/.npm-global"

    # Ensure PATH includes npm global bin in profile
    if ! grep -q ".npm-global/bin" "${MOLTBOT_HOME}/.bashrc" 2>/dev/null; then
        echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"' >> "${MOLTBOT_HOME}/.bashrc"
    fi

    chown -R "${MOLTBOT_USER}:${MOLTBOT_USER}" "$MOLTBOT_HOME"
    log_success "Directories configured"
}

install_moltbot() {
    log_info "Installing moltbot..."

    # Install moltbot as the moltbot user (.bashrc sets up PATH)
    sudo -u "$MOLTBOT_USER" -i npm install -g moltbot@latest

    log_success "Moltbot installed"
}

setup_systemd_service() {
    log_info "Setting up systemd service..."

    # Copy service file
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Create service file
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
Environment=PATH=${MOLTBOT_HOME}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=${MOLTBOT_HOME}
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
ReadWritePaths=${MOLTBOT_CONFIG_DIR} ${MOLTBOT_DATA_DIR} ${MOLTBOT_HOME}/.npm-global

# Resource limits
LimitNOFILE=65535
MemoryMax=2G

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
        firewall-cmd --permanent --add-port=${MOLTBOT_PORT}/tcp
        firewall-cmd --reload
        log_success "Firewall configured via firewalld (port ${MOLTBOT_PORT} opened)"
    elif command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow ${MOLTBOT_PORT}/tcp
        log_success "Firewall configured via ufw (port ${MOLTBOT_PORT} opened)"
    else
        log_warn "No active firewall detected, skipping firewall configuration"
    fi
}

copy_env_template() {
    log_info "Creating environment template..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "${SCRIPT_DIR}/moltbot.env.template" ]]; then
        cp "${SCRIPT_DIR}/moltbot.env.template" "${MOLTBOT_CONFIG_DIR}/moltbot.env.template"
        chown "${MOLTBOT_USER}:${MOLTBOT_USER}" "${MOLTBOT_CONFIG_DIR}/moltbot.env.template"
        log_success "Environment template copied to ${MOLTBOT_CONFIG_DIR}"
    fi
}

print_next_steps() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Moltbot installation complete!${NC}"
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

    check_root
    detect_os
    install_dependencies
    install_nodejs
    create_moltbot_user
    install_moltbot
    setup_systemd_service
    configure_firewall
    copy_env_template
    print_next_steps
}

main "$@"
