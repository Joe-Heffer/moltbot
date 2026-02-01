#!/bin/bash
#
# OpenClaw Deployment Script
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

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_HOME="/home/${OPENCLAW_USER}"
OPENCLAW_CONFIG_DIR="${OPENCLAW_HOME}/.config/openclaw"
OPENCLAW_DATA_DIR="${OPENCLAW_HOME}/.local/share/openclaw"
NODE_VERSION="22"
BREW_PREFIX="/home/linuxbrew/.linuxbrew"
OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"
SERVICE_NAME="openclaw-gateway"
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
        log_error "OpenClaw requires at least 2 GB RAM to run reliably."
        log_error "See: https://docs.openclaw.ai/help/faq"
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

create_openclaw_user() {
    log_info "Creating openclaw user..."

    if id "$OPENCLAW_USER" &>/dev/null; then
        log_info "User ${OPENCLAW_USER} already exists"
    else
        useradd -r -m -s /bin/bash -d "$OPENCLAW_HOME" "$OPENCLAW_USER"
        log_success "User ${OPENCLAW_USER} created"
    fi

    # Create necessary directories with secure permissions
    # Set restrictive umask before creating directories to prevent world-writable files
    local old_umask
    old_umask=$(umask)
    umask 0077

    mkdir -p "$OPENCLAW_CONFIG_DIR"
    mkdir -p "$OPENCLAW_DATA_DIR"
    mkdir -p "${OPENCLAW_HOME}/.npm-global"

    # Ensure state directories are real directories, not symlinks.
    # A symlink here is a security risk: an attacker who can control the
    # target could redirect state writes to an arbitrary location.
    local dir
    for dir in "${OPENCLAW_HOME}/.clawdbot" "${OPENCLAW_HOME}/clawd"; do
        if [[ -L "$dir" ]]; then
            log_warn "${dir} is a symlink — replacing with a real directory"
            rm -f "$dir"
        fi
    done

    mkdir -p "${OPENCLAW_HOME}/.clawdbot"
    mkdir -p "${OPENCLAW_HOME}/clawd/memory"

    # Restore original umask
    umask "$old_umask"

    # Ensure restrictive permissions on sensitive directories
    chmod 700 "${OPENCLAW_HOME}/.clawdbot"
    chmod 700 "${OPENCLAW_HOME}/clawd"

    # Ensure npm prefix is configured.
    # Write .npmrc directly to avoid sudo HOME environment issues
    # (sudo -u without -H keeps caller's HOME, so npm config set
    # would write to the wrong .npmrc).
    # Also fixes missing .npmrc from earlier installs.
    cat > "${OPENCLAW_HOME}/.npmrc" << NPMRC
prefix=${OPENCLAW_HOME}/.npm-global
NPMRC
    chmod 644 "${OPENCLAW_HOME}/.npmrc"
    chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_HOME}/.npmrc"

    # Ensure PATH includes npm global bin in shell profiles.
    # useradd -r (system user) skips /etc/skel, so the openclaw user may
    # have no .profile at all.  Login shells (sudo -u openclaw -i) read
    # .profile / .bash_profile — not .bashrc — so the PATH must be set
    # there.  We also keep .bashrc for interactive non-login shells.
    if ! grep -q ".npm-global/bin" "${OPENCLAW_HOME}/.bashrc" 2>/dev/null; then
        echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"' >> "${OPENCLAW_HOME}/.bashrc"
        chmod 644 "${OPENCLAW_HOME}/.bashrc"
    fi
    if [[ ! -f "${OPENCLAW_HOME}/.profile" ]]; then
        # Create a minimal .profile that mirrors the Ubuntu /etc/skel default:
        # source .bashrc (if it exists) and set the npm-global PATH for login shells.
        cat > "${OPENCLAW_HOME}/.profile" << 'PROFILE'
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
        chmod 644 "${OPENCLAW_HOME}/.profile"
        chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_HOME}/.profile"
    elif ! grep -q ".npm-global/bin" "${OPENCLAW_HOME}/.profile" 2>/dev/null; then
        echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"' >> "${OPENCLAW_HOME}/.profile"
        chmod 644 "${OPENCLAW_HOME}/.profile"
    fi

    # Add Homebrew (Linuxbrew) environment to shell profiles so that
    # interactive shells (sudo -u openclaw -i) and the openclaw application
    # can locate the brew binary and brew-installed packages.
    if ! grep -q "linuxbrew" "${OPENCLAW_HOME}/.bashrc" 2>/dev/null; then
        cat >> "${OPENCLAW_HOME}/.bashrc" << 'BREWRC'

# Homebrew (Linuxbrew)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
BREWRC
        chmod 644 "${OPENCLAW_HOME}/.bashrc"
    fi
    if ! grep -q "linuxbrew" "${OPENCLAW_HOME}/.profile" 2>/dev/null; then
        cat >> "${OPENCLAW_HOME}/.profile" << 'BREWPROFILE'

# Homebrew (Linuxbrew)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
BREWPROFILE
        chmod 644 "${OPENCLAW_HOME}/.profile"
    fi

    chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "$OPENCLAW_HOME"
    log_success "Directories configured"
}

install_homebrew() {
    log_info "Installing Homebrew (Linuxbrew)..."

    local brew_bin="${BREW_PREFIX}/bin/brew"

    # Check if Homebrew is already installed
    if [[ -x "$brew_bin" ]]; then
        local brew_version
        brew_version=$(sudo -u "$OPENCLAW_USER" "$brew_bin" --version 2>/dev/null | head -1 || echo "unknown")
        log_info "Homebrew already installed: ${brew_version}"
        return 0
    fi

    # Create the Homebrew prefix directory with moltbot ownership.
    # Homebrew on Linux installs to /home/linuxbrew/.linuxbrew by convention.
    mkdir -p "${BREW_PREFIX}"
    chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" /home/linuxbrew

    # Install Homebrew via git clone (manual method).
    # The interactive installer script requires sudo access from the installing
    # user, which the moltbot system user does not have.  The git clone approach
    # is the officially documented alternative for automated/non-interactive
    # environments.
    if ! sudo -u "$OPENCLAW_USER" git clone https://github.com/Homebrew/brew "${BREW_PREFIX}/Homebrew"; then
        log_warn "Failed to clone Homebrew repository — skills requiring brew will not work"
        return 0
    fi

    sudo -u "$OPENCLAW_USER" mkdir -p "${BREW_PREFIX}/bin"
    sudo -u "$OPENCLAW_USER" ln -sf ../Homebrew/bin/brew "${brew_bin}"

    # Run initial setup (downloads tap metadata)
    sudo -u "$OPENCLAW_USER" "${brew_bin}" update --force --quiet || {
        log_warn "Homebrew initial setup incomplete — run 'brew update' manually to finish"
    }

    # Verify installation
    if [[ ! -x "$brew_bin" ]]; then
        log_warn "Homebrew installation could not be verified — skills requiring brew may not work"
        return 0
    fi

    local brew_version
    brew_version=$(sudo -u "$OPENCLAW_USER" "$brew_bin" --version 2>/dev/null | head -1 || echo "unknown")
    log_success "Homebrew installed: ${brew_version}"
}

install_openclaw() {
    log_info "Installing/updating openclaw..."

    # Show current version if already installed
    if command -v openclaw &> /dev/null; then
        local current_version
        current_version=$(sudo -u "$OPENCLAW_USER" -i openclaw --version 2>/dev/null || echo "unknown")
        log_info "Current version: ${current_version}"
    fi

    # Clean up stale npm temporary directories that cause ENOTEMPTY on reinstall.
    # npm renames the existing package to a dotfile before replacing it; if a
    # previous run was interrupted these leftovers block the next attempt.
    local npm_modules="${OPENCLAW_HOME}/.npm-global/lib/node_modules"
    if [[ -d "$npm_modules" ]]; then
        find "$npm_modules" -maxdepth 1 -name '.openclaw-*' -type d -exec rm -rf {} + 2>/dev/null || true
    fi

    # Ensure enough memory for npm install (OOM-killed on low-memory VPS)
    ensure_swap_for_install

    # Install/update openclaw as the openclaw user (-i loads login shell which sets HOME)
    sudo -u "$OPENCLAW_USER" -i npm install -g openclaw@latest

    remove_temp_swap

    local expected_bin="${OPENCLAW_HOME}/.npm-global/bin/openclaw"

    # Determine where npm actually installed — the global prefix may differ
    # from what .npmrc requests (e.g. system-level /etc/npmrc override,
    # NPM_CONFIG_PREFIX env var, or Node.js built-in default).
    local npm_global_prefix
    npm_global_prefix=$(sudo -u "$OPENCLAW_USER" -i npm prefix -g 2>/dev/null || true)
    if [[ -n "$npm_global_prefix" ]]; then
        log_info "npm global prefix: ${npm_global_prefix}"
        if [[ "$npm_global_prefix" != "${OPENCLAW_HOME}/.npm-global" ]]; then
            log_warn "npm global prefix '${npm_global_prefix}' differs from expected '${OPENCLAW_HOME}/.npm-global'"
        fi
    fi

    # If the binary isn't at the expected path, try to locate it via the
    # openclaw user's login shell (npm may have used a different prefix).
    if [[ ! -e "$expected_bin" ]]; then
        local actual_bin
        actual_bin=$(sudo -u "$OPENCLAW_USER" -i sh -c 'command -v openclaw' 2>/dev/null || true)
        if [[ -n "$actual_bin" && -x "$actual_bin" ]]; then
            log_warn "openclaw installed at ${actual_bin} instead of ${expected_bin}"
            mkdir -p "$(dirname "$expected_bin")"
            ln -sf "$actual_bin" "$expected_bin"
            chown -h "${OPENCLAW_USER}:${OPENCLAW_USER}" "$expected_bin"
            log_info "Created symlink: ${expected_bin} -> ${actual_bin}"
        fi
    fi

    # Second fallback: check the directory npm reports as its global prefix.
    # Covers cases where .npmrc prefix is overridden by a system-level config
    # or environment variable, and the binary is not on the login shell PATH.
    if [[ ! -e "$expected_bin" && -n "${npm_global_prefix:-}" ]]; then
        local npm_prefix_bin="${npm_global_prefix}/bin/openclaw"
        if [[ -x "$npm_prefix_bin" ]]; then
            log_warn "Found openclaw at ${npm_prefix_bin} (npm prefix: ${npm_global_prefix})"
            mkdir -p "$(dirname "$expected_bin")"
            ln -sf "$npm_prefix_bin" "$expected_bin"
            chown -h "${OPENCLAW_USER}:${OPENCLAW_USER}" "$expected_bin"
            log_info "Created symlink: ${expected_bin} -> ${npm_prefix_bin}"
        fi
    fi

    # Ensure the binary (and its symlink target) is executable.
    # npm should set this, but some versions or interrupted installs can
    # leave the execute bit unset — which root wouldn't notice but the
    # openclaw service user would.
    if [[ -e "$expected_bin" || -L "$expected_bin" ]]; then
        chmod +x "$expected_bin" 2>/dev/null || true
        local resolved
        resolved=$(readlink -f "$expected_bin" 2>/dev/null || true)
        if [[ -n "$resolved" && -f "$resolved" ]]; then
            chmod +x "$resolved" 2>/dev/null || true
        fi
    fi

    # Verify the binary is executable by the openclaw user (not just root)
    # to match the systemd ExecStartPre check context.
    if ! sudo -u "$OPENCLAW_USER" test -x "$expected_bin"; then
        log_error "openclaw binary not found at ${expected_bin}"
        log_error "npm prefix may not be configured correctly"
        log_error "Contents of ${OPENCLAW_HOME}/.npmrc:"
        cat "${OPENCLAW_HOME}/.npmrc" 2>/dev/null || echo "(file not found)"
        log_error "npm global prefix reported by npm:"
        sudo -u "$OPENCLAW_USER" -i npm prefix -g 2>/dev/null || echo "(unable to determine)"
        log_error "Contents of ${OPENCLAW_HOME}/.npm-global/bin/:"
        ls -la "${OPENCLAW_HOME}/.npm-global/bin/" 2>/dev/null || echo "(directory not found)"
        exit 1
    fi

    # Create a symlink in /usr/local/bin so that `openclaw` is on the default
    # PATH for all users and shell types (login, non-login, sudo without -i).
    # Resolve to the final binary target to avoid a broken chain if the
    # intermediate symlink in .npm-global/bin is recreated by a future install.
    local resolved_bin
    resolved_bin=$(readlink -f "$expected_bin" 2>/dev/null || echo "$expected_bin")
    ln -sf "$resolved_bin" /usr/local/bin/openclaw

    local new_version
    new_version=$(sudo -u "$OPENCLAW_USER" -i openclaw --version 2>/dev/null || echo "unknown")
    log_success "OpenClaw version: ${new_version}"
}

setup_systemd_service() {
    log_info "Setting up systemd service..."

    # Always regenerate the service file so that configuration changes
    # (security hardening, paths, environment, etc.) are rolled out on
    # every deployment — not just on first install.

    # Read the template and substitute placeholders with actual values
    local template_file="${SCRIPT_DIR}/openclaw-gateway.service"

    if [[ ! -f "$template_file" ]]; then
        log_error "Service template not found: ${template_file}"
        exit 1
    fi

    # Perform variable substitution and write to systemd directory
    sed -e "s|{{OPENCLAW_USER}}|${OPENCLAW_USER}|g" \
        -e "s|{{OPENCLAW_HOME}}|${OPENCLAW_HOME}|g" \
        -e "s|{{OPENCLAW_CONFIG_DIR}}|${OPENCLAW_CONFIG_DIR}|g" \
        -e "s|{{OPENCLAW_DATA_DIR}}|${OPENCLAW_DATA_DIR}|g" \
        -e "s|{{NODE_HEAP_SIZE}}|${NODE_HEAP_SIZE}|g" \
        -e "s|{{MEMORY_MAX}}|${MEMORY_MAX}|g" \
        -e "s|{{BREW_PREFIX}}|${BREW_PREFIX}|g" \
        -e "s|{{OPENCLAW_PORT}}|${OPENCLAW_PORT}|g" \
        "$template_file" > /etc/systemd/system/openclaw-gateway.service

    # Reload systemd
    systemctl daemon-reload

    log_success "Systemd service configured"
}

setup_backup_service() {
    log_info "Installing backup systemd service and timer..."

    # Copy backup service and timer to systemd
    cp "${SCRIPT_DIR}/openclaw-backup.service" /etc/systemd/system/openclaw-backup.service
    cp "${SCRIPT_DIR}/openclaw-backup.timer" /etc/systemd/system/openclaw-backup.timer

    # Reload systemd to pick up new units
    systemctl daemon-reload

    log_info "Backup service installed (not enabled by default)"
    log_info "To enable automated backups:"
    log_info "  1. Copy and configure ${OPENCLAW_CONFIG_DIR}/backup.conf.template to ${OPENCLAW_CONFIG_DIR}/backup.conf"
    log_info "  2. Run: sudo systemctl enable --now openclaw-backup.timer"
}

copy_env_template() {
    log_info "Creating environment template..."

    if [[ -f "${SCRIPT_DIR}/openclaw.env.template" ]]; then
        cp "${SCRIPT_DIR}/openclaw.env.template" "${OPENCLAW_CONFIG_DIR}/openclaw.env.template"
        chmod 644 "${OPENCLAW_CONFIG_DIR}/openclaw.env.template"
        chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_CONFIG_DIR}/openclaw.env.template"
        log_success "Environment template copied to ${OPENCLAW_CONFIG_DIR}"

        # Create .env from template if it doesn't already exist
        if [[ ! -f "${OPENCLAW_CONFIG_DIR}/.env" ]]; then
            cp "${SCRIPT_DIR}/openclaw.env.template" "${OPENCLAW_CONFIG_DIR}/.env"
            chmod 600 "${OPENCLAW_CONFIG_DIR}/.env"
            chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_CONFIG_DIR}/.env"
            log_warn "Created ${OPENCLAW_CONFIG_DIR}/.env from template — edit it to add your API keys before starting the service"
        else
            log_info "Existing .env file preserved at ${OPENCLAW_CONFIG_DIR}/.env"
        fi
    fi

    # Copy fallback configuration template
    if [[ -f "${SCRIPT_DIR}/openclaw.fallbacks.json" ]]; then
        cp "${SCRIPT_DIR}/openclaw.fallbacks.json" "${OPENCLAW_CONFIG_DIR}/openclaw.fallbacks.json"
        chmod 644 "${OPENCLAW_CONFIG_DIR}/openclaw.fallbacks.json"
        chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_CONFIG_DIR}/openclaw.fallbacks.json"
        log_success "Fallback configuration template copied to ${OPENCLAW_CONFIG_DIR}"
    fi

    # Copy backup configuration template
    if [[ -f "${SCRIPT_DIR}/backup.conf.template" ]]; then
        cp "${SCRIPT_DIR}/backup.conf.template" "${OPENCLAW_CONFIG_DIR}/backup.conf.template"
        chmod 644 "${OPENCLAW_CONFIG_DIR}/backup.conf.template"
        chown "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_CONFIG_DIR}/backup.conf.template"
        log_info "Backup configuration template copied to ${OPENCLAW_CONFIG_DIR}"
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
    local max_restarts=3
    local current_pid
    local sub_state
    local in_restart=false

    while [ $attempt -le $max_attempts ]; do
        # Hard failure — systemd gave up restarting (e.g. start-limit hit)
        if systemctl is-failed --quiet "$SERVICE_NAME"; then
            echo ""
            log_error "Service entered failed state"
            log_info "Recent logs:"
            journalctl -u "$SERVICE_NAME" --no-pager -n 20 2>/dev/null || true
            return 1
        fi

        sub_state=$(systemctl show -p SubState --value "$SERVICE_NAME" 2>/dev/null || echo "")

        # Detect crash-restart cycle: service crashed and systemd is
        # waiting RestartSec before retrying.  The old PID-only check
        # could not see this state and just printed dots for 10 seconds.
        if [[ "$sub_state" == "auto-restart" && "$in_restart" == false ]]; then
            in_restart=true
            restarts=$((restarts + 1))
            echo ""
            log_warn "Service crashed and is restarting (#${restarts})"
            journalctl -u "$SERVICE_NAME" --no-pager -n 5 2>/dev/null || true
            last_pid=""
            if [[ "$restarts" -ge "$max_restarts" ]]; then
                log_error "Service crashed ${restarts} times — giving up (crash loop)"
                log_info "Full recent logs:"
                journalctl -u "$SERVICE_NAME" --no-pager -n 30 2>/dev/null || true
                return 1
            fi
        fi

        if [[ "$sub_state" == "running" ]]; then
            in_restart=false

            # Track PID as a fallback crash-loop detector (covers edge
            # cases where the SubState transition is too fast to observe)
            current_pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null || echo "")
            if [[ -n "$last_pid" && "$last_pid" != "0" \
               && -n "$current_pid" && "$current_pid" != "0" \
               && "$last_pid" != "$current_pid" ]]; then
                restarts=$((restarts + 1))
                echo ""
                log_warn "Service restarted during health check (PID ${last_pid} -> ${current_pid}, #${restarts})"
                if [[ "$restarts" -ge "$max_restarts" ]]; then
                    log_error "Service crashed ${restarts} times — giving up (crash loop)"
                    log_info "Full recent logs:"
                    journalctl -u "$SERVICE_NAME" --no-pager -n 30 2>/dev/null || true
                    return 1
                fi
            fi
            if [[ -n "$current_pid" && "$current_pid" != "0" ]]; then
                last_pid="$current_pid"
            fi

            # Check if configured port is listening
            if ss -tln 2>/dev/null | grep -q ":${OPENCLAW_PORT}\b"; then
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
    log_info "Recent logs:"
    journalctl -u "$SERVICE_NAME" --no-pager -n 20 2>/dev/null || true
    return 1
}

configure_trusted_proxies() {
    # Read GATEWAY_TRUSTED_PROXIES from the .env file (or the current
    # environment, e.g. passed on the command line).  When set, write the
    # value into gateway.trustedProxies so the moltbot gateway reads the
    # real client IP from X-Forwarded-For headers behind a reverse proxy.
    local proxies="${GATEWAY_TRUSTED_PROXIES:-}"
    local env_file="${OPENCLAW_CONFIG_DIR}/.env"

    # Fall back to the .env file if the variable is not in the environment.
    if [[ -z "$proxies" && -f "$env_file" ]]; then
        proxies=$(grep -E "^GATEWAY_TRUSTED_PROXIES=.+" "$env_file" 2>/dev/null \
                  | head -1 | cut -d'=' -f2- || true)
    fi

    if [[ -z "$proxies" ]]; then
        return 0
    fi

    log_info "Configuring gateway.trustedProxies..."

    # Convert comma-separated list (e.g. "127.0.0.1,::1") into a JSON
    # array (e.g. ["127.0.0.1","::1"]).
    local json_array
    json_array=$(printf '%s' "$proxies" \
                 | tr ',' '\n' \
                 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
                 | jq -R . | jq -sc .)

    if sudo -u "$OPENCLAW_USER" -i openclaw config set gateway.trustedProxies "$json_array" 2>/dev/null; then
        log_success "gateway.trustedProxies set to ${json_array}"
    else
        log_warn "Could not set gateway.trustedProxies — configure manually with: openclaw config set gateway.trustedProxies '${json_array}'"
    fi
}

run_doctor() {
    log_info "Running openclaw doctor --repair..."
    sudo -u "$OPENCLAW_USER" -i openclaw doctor --repair 2>/dev/null || true
}

save_deploy_version() {
    # Save the repo VERSION to /opt/openclaw-version for deployment tracking.
    # Previously this was done in the CI workflow with sudo tee/chown, but
    # those commands were not covered by the deploy user's sudoers rules,
    # causing "a terminal is required to read the password" errors.
    # Since deploy.sh already runs as root, it can write the file directly.
    local version_file="${SCRIPT_DIR}/../VERSION"
    if [[ -f "$version_file" ]]; then
        local version
        version=$(cat "$version_file")
        echo "$version" > /opt/openclaw-version
        chown "${OPENCLAW_USER}:${OPENCLAW_USER}" /opt/openclaw-version
        chmod 644 /opt/openclaw-version
        log_info "Deploy version saved: ${version}"
    fi
}

show_status() {
    echo ""
    log_info "Current status:"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
}

print_first_install_steps() {
    echo ""
    echo "=============================================="
    echo -e "${LIB_GREEN}OpenClaw installation complete!${LIB_NC}"
    echo "=============================================="
    echo ""
    echo "The service is now running and enabled to start on boot."
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Run the onboarding wizard as the openclaw user:"
    echo "   sudo -u ${OPENCLAW_USER} -i openclaw onboard"
    echo ""
    echo "2. Access the Gateway UI at:"
    echo "   http://<your-vm-ip>:${OPENCLAW_PORT}"
    echo ""
    echo "3. Monitor service logs:"
    echo "   sudo journalctl -u openclaw-gateway -f"
    echo ""
    echo "Configuration directory: ${OPENCLAW_CONFIG_DIR}"
    echo "Data directory: ${OPENCLAW_DATA_DIR}"
    echo ""
    echo "Security recommendations:"
    echo "  - Use Tailscale for secure remote access"
    echo "  - Configure DM pairing policies"
    echo "  - Run 'openclaw doctor' to check configuration"
    echo ""
}

main() {
    log_info "Starting OpenClaw deployment..."
    echo ""

    require_root
    validate_port "$OPENCLAW_PORT" "OPENCLAW_PORT"

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
    create_openclaw_user

    DEPLOY_PHASE="Homebrew installation"
    install_homebrew

    DEPLOY_PHASE="openclaw installation"
    install_openclaw

    DEPLOY_PHASE="systemd setup"
    setup_systemd_service

    DEPLOY_PHASE="environment template"
    copy_env_template

    DEPLOY_PHASE="model fallback configuration"
    setup_model_fallbacks

    DEPLOY_PHASE="trusted proxy configuration"
    configure_trusted_proxies

    DEPLOY_PHASE="backup service installation"
    setup_backup_service

    DEPLOY_PHASE="version tracking"
    save_deploy_version

    # Clear phase — core deployment succeeded
    DEPLOY_PHASE=""

    # Start the service and run health checks.
    # On first install, also print helpful next steps about onboarding.
    DEPLOY_PHASE="service restart"
    restart_service

    if wait_for_healthy; then
        run_doctor
        show_status
        if [[ "$SERVICE_WAS_RUNNING" == false ]]; then
            print_first_install_steps
        fi
        log_success "Deployment completed successfully"
    else
        show_status
        log_error "Deployment completed but service may not be healthy"
        exit 1
    fi
    DEPLOY_PHASE=""
}

main "$@"
