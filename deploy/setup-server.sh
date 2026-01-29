#!/bin/bash
#
# Initial Server Setup for Moltbot Deployment
# Run this ONCE on a fresh VPS to prepare for CI/CD deployments
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_PATH="/opt/moltbot-deploy"
GITHUB_REPO="${GITHUB_REPO:-Joe-Heffer/moltbot}"

create_deploy_user() {
    log_info "Setting up deployment user..."

    if id "$DEPLOY_USER" &>/dev/null; then
        log_info "User ${DEPLOY_USER} already exists"
    else
        useradd -r -m -s /bin/bash "$DEPLOY_USER"
        log_success "User ${DEPLOY_USER} created"
    fi

    # Add deploy user to sudoers for specific commands (passwordless)
    # Resolve actual binary paths (handles /bin vs /usr/bin symlink differences)
    local systemctl_path journalctl_path su_path
    systemctl_path=$(command -v systemctl)
    journalctl_path=$(command -v journalctl)
    su_path=$(command -v su)

    # Principle of least privilege: only allow the specific commands needed
    # for deployment operations. Avoid broad wildcards that could enable
    # privilege escalation.
    cat > /etc/sudoers.d/moltbot-deploy << EOF
# Allow deploy user to manage moltbot service and run deploy scripts
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} start moltbot-gateway
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} stop moltbot-gateway
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} restart moltbot-gateway
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} status moltbot-gateway
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} status moltbot-gateway --no-pager
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} is-active moltbot-gateway
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${systemctl_path} daemon-reload
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${journalctl_path} -u moltbot-gateway *
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /opt/moltbot-deploy/deploy/install.sh
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /opt/moltbot-deploy/deploy/update.sh
${DEPLOY_USER} ALL=(ALL) NOPASSWD: ${su_path} - moltbot -c *
EOF

    chmod 440 /etc/sudoers.d/moltbot-deploy

    # Validate sudoers syntax to avoid lockout
    if command -v visudo &> /dev/null; then
        if ! visudo -cf /etc/sudoers.d/moltbot-deploy; then
            log_error "Invalid sudoers syntax — removing file to prevent lockout"
            rm -f /etc/sudoers.d/moltbot-deploy
            exit 1
        fi
    fi

    log_success "Sudoers configured for user '${DEPLOY_USER}'"
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
    echo -e "${LIB_YELLOW}ACTION REQUIRED: Add your GitHub Actions SSH public key${LIB_NC}"
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
    echo -e "${LIB_YELLOW}SSH Security Recommendations${LIB_NC}"
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
    echo -e "${LIB_GREEN}Server Setup Complete!${LIB_NC}"
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

    require_root
    create_deploy_user
    setup_deploy_directory
    configure_firewall_ssh
    setup_ssh_for_deploy
    harden_ssh
    print_next_steps
}

main "$@"
