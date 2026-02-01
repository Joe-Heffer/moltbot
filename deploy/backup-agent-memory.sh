#!/usr/bin/env bash
# Agent Memory Backup Script
# Backs up OpenClaw agent memory and soul files to prevent data loss
# Supports Git repositories and cloud storage via rclone

set -euo pipefail

# Source shared library for logging and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Default paths
OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_HOME="/home/${OPENCLAW_USER}"
BACKUP_CONFIG="${OPENCLAW_HOME}/.config/openclaw/backup.conf"
BACKUP_STAGING_DIR="/tmp/openclaw-backup-$$"

# Directories to backup
BACKUP_SOURCES=(
    "${OPENCLAW_HOME}/.clawdbot"
    "${OPENCLAW_HOME}/clawd/memory"
    "${OPENCLAW_HOME}/.config/openclaw"
    "${OPENCLAW_HOME}/.local/share/openclaw"
)

# Files to exclude for privacy (add patterns here)
EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    ".env"
    "node_modules"
    ".npm"
)

cleanup() {
    if [[ -d "${BACKUP_STAGING_DIR}" ]]; then
        log_info "Cleaning up staging directory"
        rm -rf "${BACKUP_STAGING_DIR}"
    fi
}

trap cleanup EXIT

load_backup_config() {
    if [[ ! -f "${BACKUP_CONFIG}" ]]; then
        log_error "Backup configuration not found: ${BACKUP_CONFIG}"
        log_info "Create ${BACKUP_CONFIG} with BACKUP_METHOD=git or BACKUP_METHOD=rclone"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${BACKUP_CONFIG}"

    if [[ -z "${BACKUP_METHOD:-}" ]]; then
        log_error "BACKUP_METHOD not set in ${BACKUP_CONFIG}"
        log_info "Set BACKUP_METHOD=git or BACKUP_METHOD=rclone"
        exit 1
    fi
}

create_staging_area() {
    log_info "Creating staging area"
    mkdir -p "${BACKUP_STAGING_DIR}"

    for source_dir in "${BACKUP_SOURCES[@]}"; do
        if [[ ! -d "${source_dir}" ]]; then
            log_warn "Source directory not found (skipping): ${source_dir}"
            continue
        fi

        # Create relative path structure in staging
        local rel_path="${source_dir#${OPENCLAW_HOME}/}"
        local dest_dir="${BACKUP_STAGING_DIR}/${rel_path}"
        mkdir -p "$(dirname "${dest_dir}")"

        log_info "Copying ${source_dir}"

        # Build rsync exclude options
        local exclude_opts=()
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            exclude_opts+=(--exclude="${pattern}")
        done

        # Copy with rsync to handle exclusions
        rsync -a "${exclude_opts[@]}" "${source_dir}/" "${dest_dir}/" || {
            log_warn "Failed to copy ${source_dir}, continuing anyway"
        }
    done

    # Add metadata
    cat > "${BACKUP_STAGING_DIR}/backup-metadata.txt" <<EOF
Backup created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Hostname: $(hostname)
OpenClaw user: ${OPENCLAW_USER}
Backup method: ${BACKUP_METHOD}
OpenClaw version: $(sudo -u "${OPENCLAW_USER}" openclaw --version 2>/dev/null || echo "unknown")
EOF

    log_success "Staging area created: ${BACKUP_STAGING_DIR}"
}

backup_to_git() {
    local git_repo="${BACKUP_GIT_REPO:-}"
    local git_branch="${BACKUP_GIT_BRANCH:-main}"
    local git_remote="${BACKUP_GIT_REMOTE:-origin}"

    if [[ -z "${git_repo}" ]]; then
        log_error "BACKUP_GIT_REPO not set in ${BACKUP_CONFIG}"
        exit 1
    fi

    log_info "Backing up to Git repository: ${git_repo}"

    local repo_dir="${BACKUP_STAGING_DIR}/repo"

    # Clone or pull existing repo
    if [[ -d "${OPENCLAW_HOME}/.openclaw-backup-repo/.git" ]]; then
        log_info "Using existing backup repository"
        cp -a "${OPENCLAW_HOME}/.openclaw-backup-repo" "${repo_dir}"
        cd "${repo_dir}"

        # Fetch latest changes
        git fetch "${git_remote}" "${git_branch}" || log_warn "Failed to fetch latest changes"
        git reset --hard "${git_remote}/${git_branch}" || log_warn "Failed to reset to remote branch"
    else
        log_info "Cloning backup repository"
        git clone --depth=1 -b "${git_branch}" "${git_repo}" "${repo_dir}" || {
            log_info "Branch ${git_branch} not found, creating new repository"
            mkdir -p "${repo_dir}"
            cd "${repo_dir}"
            git init
            git checkout -b "${git_branch}"
            git remote add "${git_remote}" "${git_repo}"
        }
    fi

    cd "${repo_dir}"

    # Copy backup data to repo
    log_info "Copying backup data to repository"
    for source_dir in "${BACKUP_SOURCES[@]}"; do
        local rel_path="${source_dir#${OPENCLAW_HOME}/}"
        local staging_source="${BACKUP_STAGING_DIR}/${rel_path}"

        if [[ -d "${staging_source}" ]]; then
            mkdir -p "${rel_path}"
            rsync -a --delete "${staging_source}/" "${rel_path}/"
        fi
    done

    # Copy metadata
    cp "${BACKUP_STAGING_DIR}/backup-metadata.txt" .

    # Create .gitignore if it doesn't exist
    if [[ ! -f .gitignore ]]; then
        cat > .gitignore <<'EOF'
# Sensitive files
.env
*.key
*.pem
credentials.json

# Logs and temporary files
*.log
*.tmp
.DS_Store

# Node modules
node_modules/
EOF
    fi

    # Commit changes
    git add -A

    if git diff --cached --quiet; then
        log_info "No changes to commit"
    else
        local commit_msg
        commit_msg="Automated backup: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        git commit -m "${commit_msg}"

        log_info "Pushing to remote repository"
        if git push "${git_remote}" "${git_branch}"; then
            log_success "Backup pushed successfully"

            # Cache the repo for next time
            rm -rf "${OPENCLAW_HOME}/.openclaw-backup-repo"
            cp -a "${repo_dir}" "${OPENCLAW_HOME}/.openclaw-backup-repo"
            chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "${OPENCLAW_HOME}/.openclaw-backup-repo"
        else
            log_error "Failed to push backup to remote repository"
            exit 1
        fi
    fi
}

backup_to_rclone() {
    local rclone_remote="${BACKUP_RCLONE_REMOTE:-}"
    local rclone_path="${BACKUP_RCLONE_PATH:-openclaw-backup}"

    if [[ -z "${rclone_remote}" ]]; then
        log_error "BACKUP_RCLONE_REMOTE not set in ${BACKUP_CONFIG}"
        log_info "Example: BACKUP_RCLONE_REMOTE=gdrive:backups"
        exit 1
    fi

    if ! command -v rclone &> /dev/null; then
        log_error "rclone not found. Install it with: curl https://rclone.org/install.sh | sudo bash"
        exit 1
    fi

    log_info "Backing up to rclone remote: ${rclone_remote}/${rclone_path}"

    # Create timestamped backup directory
    local timestamp
    timestamp=$(date -u +"%Y%m%d-%H%M%S")
    local remote_backup_dir="${rclone_remote}/${rclone_path}/${timestamp}"

    # Sync to remote
    if rclone sync "${BACKUP_STAGING_DIR}" "${remote_backup_dir}" --progress; then
        log_success "Backup synced to ${remote_backup_dir}"

        # Create a "latest" symlink/copy if supported
        rclone copy "${remote_backup_dir}/backup-metadata.txt" \
            "${rclone_remote}/${rclone_path}/latest-backup-metadata.txt" 2>/dev/null || true
    else
        log_error "Failed to sync backup to rclone remote"
        exit 1
    fi

    # Optional: cleanup old backups
    if [[ -n "${BACKUP_RETENTION_DAYS:-}" ]] && [[ "${BACKUP_RETENTION_DAYS}" -gt 0 ]]; then
        log_info "Cleaning up backups older than ${BACKUP_RETENTION_DAYS} days"
        # Note: This requires rclone to support filtering by date
        # Implementation depends on cloud provider
        log_warn "Automatic retention cleanup not yet implemented for rclone"
    fi
}

main() {
    log_info "Starting agent memory backup"

    # Load configuration
    load_backup_config

    # Create staging area with backup data
    create_staging_area

    # Perform backup based on method
    case "${BACKUP_METHOD}" in
        git)
            backup_to_git
            ;;
        rclone)
            backup_to_rclone
            ;;
        *)
            log_error "Unknown backup method: ${BACKUP_METHOD}"
            log_info "Supported methods: git, rclone"
            exit 1
            ;;
    esac

    log_success "Agent memory backup completed successfully"
}

main "$@"
