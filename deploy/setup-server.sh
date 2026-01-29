#!/bin/bash
#
# Initial Server Setup for Moltbot Deployment
# Run this ONCE on a fresh Ionos VPS to prepare for CI/CD deployments
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_PATH="/opt/moltbot-deploy"
GITHUB_REPO="${GITHUB_REPO:-Joe-Heffer/moltbot}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
        exit 1
    fi
}

create_deploy_user() {
    log_info "Setting up deployment user..."

    if id "$DEPLOY_USER" &>/dev/null; then
        log_info "User ${DEPLOY_USER} already exists"
    else
        useradd -r -m -s /bin/bash "$DEPLOY_USER"
        log_success "User ${DEPLOY_USER} created"
    fi

    # Add deploy user to sudoers for specific commands (passwordless)
    cat > /etc/sudoers.d/moltbot-deploy << 'EOF'
# Allow deploy user to manage moltbot service and run deploy scripts
deploy ALL=(ALL) NOPASSWD: /bin/systemctl start moltbot-gateway
deploy ALL=(ALL) NOPASSWD: /bin/systemctl stop moltbot-gateway
deploy ALL=(ALL) NOPASSWD: /bin/systemctl restart moltbot-gateway
deploy ALL=(ALL) NOPASSWD: /bin/systemctl status moltbot-gateway
deploy ALL=(ALL) NOPASSWD: /bin/systemctl is-active moltbot-gateway
deploy ALL=(ALL) NOPASSWD: /bin/journalctl -u moltbot-gateway *
deploy ALL=(ALL) NOPASSWD: /opt/moltbot-deploy/deploy/install.sh
deploy ALL=(ALL) NOPASSWD: /opt/moltbot-deploy/deploy/update.sh
deploy ALL=(ALL) NOPASSWD: /usr/bin/git *
deploy ALL=(ALL) NOPASSWD: /bin/mkdir -p /opt/moltbot-deploy
deploy ALL=(ALL) NOPASSWD: /bin/chmod *
deploy ALL=(ALL) NOPASSWD: /bin/su - moltbot *
EOF

    chmod 440 /etc/sudoers.d/moltbot-deploy
    log_success "Sudoers configured"
}

setup_ssh_for_deploy() {
    log_info "Setting up SSH for deployment user..."

    local ssh_dir="/home/${DEPLOY_USER}/.ssh"
    mkdir -p "$ssh_dir"

    # Create authorized_keys if it doesn't exist
    touch "${ssh_dir}/authorized_keys"

    # Set permissions
    chmod 700 "$ssh_dir"
    chmod 600 "${ssh_dir}/authorized_keys"
    chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$ssh_dir"

    echo ""
    echo "=============================================="
    echo -e "${YELLOW}ACTION REQUIRED: Add your GitHub Actions SSH public key${NC}"
    echo "=============================================="
    echo ""
    echo "1. Generate an SSH key pair for GitHub Actions (on your local machine):"
    echo "   ssh-keygen -t ed25519 -C \"github-actions-moltbot\" -f ~/.ssh/moltbot-deploy"
    echo ""
    echo "2. Add the PUBLIC key to this server:"
    echo "   Edit: ${ssh_dir}/authorized_keys"
    echo "   Paste the contents of: ~/.ssh/moltbot-deploy.pub"
    echo ""
    echo "3. Add the PRIVATE key to GitHub repository secrets:"
    echo "   - Go to: https://github.com/${GITHUB_REPO}/settings/secrets/actions"
    echo "   - Add secret: VPS_SSH_KEY (paste contents of ~/.ssh/moltbot-deploy)"
    echo "   - Add secret: VPS_HOST (your server IP)"
    echo "   - Add secret: VPS_USERNAME (${DEPLOY_USER})"
    echo "   - Add secret: VPS_PORT (22 or your SSH port)"
    echo ""
}

setup_deploy_directory() {
    log_info "Setting up deployment directory..."

    mkdir -p "$DEPLOY_PATH"
    chown "${DEPLOY_USER}:${DEPLOY_USER}" "$DEPLOY_PATH"

    log_success "Deployment directory created at ${DEPLOY_PATH}"
}

configure_firewall_ssh() {
    log_info "Ensuring SSH is allowed through firewall..."

    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
        firewall-cmd --reload
        log_success "SSH allowed through firewall"
    fi
}

harden_ssh() {
    log_info "Applying SSH security recommendations..."

    echo ""
    echo "=============================================="
    echo -e "${YELLOW}SSH Security Recommendations${NC}"
    echo "=============================================="
    echo ""
    echo "Consider adding these to /etc/ssh/sshd_config:"
    echo ""
    echo "  # Disable root login"
    echo "  PermitRootLogin no"
    echo ""
    echo "  # Use key-based authentication only"
    echo "  PasswordAuthentication no"
    echo "  PubkeyAuthentication yes"
    echo ""
    echo "  # Limit to deploy user for automated deployments"
    echo "  # AllowUsers ${DEPLOY_USER} your-admin-user"
    echo ""
    echo "After making changes, restart SSH:"
    echo "  sudo systemctl restart sshd"
    echo ""
}

print_next_steps() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Server Setup Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Add your SSH public key to: /home/${DEPLOY_USER}/.ssh/authorized_keys"
    echo ""
    echo "2. Add GitHub repository secrets:"
    echo "   - VPS_HOST: Your server IP address"
    echo "   - VPS_USERNAME: ${DEPLOY_USER}"
    echo "   - VPS_SSH_KEY: Your SSH private key"
    echo "   - VPS_PORT: 22 (or custom SSH port)"
    echo ""
    echo "3. Run initial install (either manually or via GitHub Actions):"
    echo "   - Manual: sudo ${DEPLOY_PATH}/deploy/install.sh"
    echo "   - GitHub: Trigger workflow with 'install' action"
    echo ""
    echo "4. Complete moltbot onboarding:"
    echo "   sudo -u moltbot -i moltbot onboard"
    echo ""
}

main() {
    log_info "Moltbot Server Setup Script"
    echo ""

    check_root
    create_deploy_user
    setup_deploy_directory
    configure_firewall_ssh
    setup_ssh_for_deploy
    harden_ssh
    print_next_steps
}

main "$@"
