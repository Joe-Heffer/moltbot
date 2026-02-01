#!/bin/bash
#
# Shared library for OpenClaw deployment scripts
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

# Temporary swap support for low-memory systems
# npm install can exceed available RAM on small VPS instances (<4 GB),
# causing the OOM killer to SIGKILL the process.  These helpers create
# a temporary swap file before the install and clean it up afterwards.

readonly LIB_INSTALL_MIN_MEMORY_MB=2048
readonly LIB_TEMP_SWAP_FILE="/var/tmp/openclaw-install.swap"

# Create and activate a temporary swap file if RAM + existing swap is
# below LIB_INSTALL_MIN_MEMORY_MB.  Safe to call as a no-op when there
# is already enough memory.
ensure_swap_for_install() {
    local total_ram_mb
    total_ram_mb=$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)

    local total_swap_mb
    total_swap_mb=$(awk '/^SwapTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)

    local total_mb=$(( total_ram_mb + total_swap_mb ))

    if [[ "$total_mb" -ge "$LIB_INSTALL_MIN_MEMORY_MB" ]]; then
        return 0
    fi

    local needed_mb=$(( LIB_INSTALL_MIN_MEMORY_MB - total_mb ))
    # Minimum 512 MB swap to leave comfortable headroom
    if [[ "$needed_mb" -lt 512 ]]; then
        needed_mb=512
    fi

    log_info "Low memory detected (${total_mb} MB total). Creating ${needed_mb} MB temporary swap file..."

    dd if=/dev/zero of="$LIB_TEMP_SWAP_FILE" bs=1M count="$needed_mb" status=none
    chmod 600 "$LIB_TEMP_SWAP_FILE"
    mkswap "$LIB_TEMP_SWAP_FILE" > /dev/null
    swapon "$LIB_TEMP_SWAP_FILE"

    log_success "Temporary swap activated (${needed_mb} MB)"
}

# Remove the temporary swap file if it is active.
# Safe to call even if no swap was created.
remove_temp_swap() {
    if [[ -f "$LIB_TEMP_SWAP_FILE" ]]; then
        swapoff "$LIB_TEMP_SWAP_FILE" 2>/dev/null || true
        rm -f "$LIB_TEMP_SWAP_FILE"
        log_info "Temporary swap file removed"
    fi
}

# Compute memory limits for the openclaw-gateway systemd service.
# Sets two globals:
#   LIB_NODE_HEAP_SIZE  — V8 --max-old-space-size in MB
#   LIB_MEMORY_MAX      — systemd MemoryMax value (e.g. "1024M" or "2G")
#
# The gateway idles at ~200 MB V8 heap but can spike above 400 MB under
# load (channel reconnects, large message bursts).  Node.js also uses
# 150–300 MB of native memory (buffers, libuv, OpenSSL, etc.) on top of
# the V8 heap.  The formulas below ensure that:
#   1. V8 gets enough room to handle spikes without heap OOM.
#   2. systemd MemoryMax leaves headroom for native overhead so the
#      cgroup OOM-killer doesn't fire before V8 can GC.
# Set by compute_memory_limits(), read by sourcing scripts (deploy.sh)
# shellcheck disable=SC2034
LIB_NODE_HEAP_SIZE=""
# shellcheck disable=SC2034
LIB_MEMORY_MAX=""

# shellcheck disable=SC2034
compute_memory_limits() {
    local total_ram_mb
    total_ram_mb=$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)

    # V8 heap: 65% of RAM, floor 256 MB, cap 1536 MB
    local heap_size=$(( total_ram_mb * 65 / 100 ))
    if [[ "$heap_size" -gt 1536 ]]; then
        heap_size=1536
    fi
    if [[ "$heap_size" -lt 256 ]]; then
        heap_size=256
    fi
    LIB_NODE_HEAP_SIZE="$heap_size"

    # MemoryMax: heap + 512 MB overhead for native memory (buffers, libuv,
    # OpenSSL, etc.), but never more than 90% of total RAM so the OS and
    # other services still have room.  Floor 512 MB, cap 2 GB.
    local mem_max_mb=$(( heap_size + 512 ))
    local ram_90pct=$(( total_ram_mb * 90 / 100 ))
    if [[ "$mem_max_mb" -gt "$ram_90pct" ]]; then
        mem_max_mb="$ram_90pct"
    fi
    if [[ "$mem_max_mb" -lt 512 ]]; then
        mem_max_mb=512
    fi
    if [[ "$mem_max_mb" -ge 2048 ]]; then
        LIB_MEMORY_MAX="2G"
    else
        LIB_MEMORY_MAX="${mem_max_mb}M"
    fi
}
