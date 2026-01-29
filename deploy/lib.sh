#!/bin/bash
#
# Shared library for Moltbot deployment scripts
# Source this file at the top of each script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib.sh"
#

# Colors for output
readonly LIB_RED='\033[0;31m'
readonly LIB_GREEN='\033[0;32m'
readonly LIB_YELLOW='\033[1;33m'
readonly LIB_BLUE='\033[0;34m'
readonly LIB_NC='\033[0m' # No Color

log_info() {
    echo -e "${LIB_BLUE}[INFO]${LIB_NC} $1"
}

log_success() {
    echo -e "${LIB_GREEN}[SUCCESS]${LIB_NC} $1"
}

log_warn() {
    echo -e "${LIB_YELLOW}[WARN]${LIB_NC} $1"
}

log_error() {
    echo -e "${LIB_RED}[ERROR]${LIB_NC} $1"
}

# Verify the script is running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Validate that a value is a valid TCP/UDP port number (1-65535)
validate_port() {
    local port="$1"
    local name="${2:-port}"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "Invalid ${name}: '${port}' (must be 1-65535)"
        exit 1
    fi
}
