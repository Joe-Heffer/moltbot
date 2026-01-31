#!/bin/bash
#
# Moltbot Fallback Configuration Script
# Configures AI provider fallbacks based on available API keys
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

MOLTBOT_USER="${MOLTBOT_USER:-moltbot}"
MOLTBOT_HOME="/home/${MOLTBOT_USER}"
MOLTBOT_CONFIG_DIR="${MOLTBOT_HOME}/.config/moltbot"
FALLBACK_CONFIG="${SCRIPT_DIR}/moltbot.fallbacks.json"

# Parse JSON config to get provider/model information
# Usage: get_json_value <json_file> <jq_path>
get_json_value() {
    local file="$1"
    local path="$2"
    jq -r "$path" "$file" 2>/dev/null || echo ""
}

# Check if an API key environment variable is set
# Usage: has_api_key <env_var_name>
has_api_key() {
    local key_name="$1"
    local env_file="${MOLTBOT_CONFIG_DIR}/.env"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    # Check if the key is defined and non-empty in .env
    if grep -q "^${key_name}=.\+" "$env_file" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Configure model fallbacks based on available API keys
configure_fallbacks() {
    log_info "Configuring AI provider fallbacks..."

    if [[ ! -f "$FALLBACK_CONFIG" ]]; then
        log_error "Fallback configuration file not found: ${FALLBACK_CONFIG}"
        exit 1
    fi

    # Check if auto-configuration is enabled
    local auto_configure
    auto_configure=$(get_json_value "$FALLBACK_CONFIG" '.settings.autoConfigureOnInstall')
    if [[ "$auto_configure" != "true" ]]; then
        log_info "Auto-configuration disabled in fallback config, skipping"
        return 0
    fi

    # Track configured models
    local configured_count=0
    local available_keys=()

    # Check which API keys are available
    log_info "Checking for available API keys..."

    if has_api_key "ANTHROPIC_API_KEY"; then
        available_keys+=("ANTHROPIC_API_KEY")
        log_success "  Found ANTHROPIC_API_KEY"
    fi

    if has_api_key "OPENAI_API_KEY"; then
        available_keys+=("OPENAI_API_KEY")
        log_success "  Found OPENAI_API_KEY"
    fi

    if has_api_key "GEMINI_API_KEY"; then
        available_keys+=("GEMINI_API_KEY")
        log_success "  Found GEMINI_API_KEY"
    fi

    # If no API keys found, skip configuration
    if [[ ${#available_keys[@]} -eq 0 ]]; then
        local skip_if_no_keys
        skip_if_no_keys=$(get_json_value "$FALLBACK_CONFIG" '.settings.skipIfNoApiKeys')
        if [[ "$skip_if_no_keys" == "true" ]]; then
            log_warn "No API keys configured yet, skipping fallback setup"
            log_info "Run 'moltbot onboard' or edit ${MOLTBOT_CONFIG_DIR}/.env to add API keys"
            return 0
        fi
    fi

    # Clear existing fallbacks if configured to do so
    local preserve_existing
    preserve_existing=$(get_json_value "$FALLBACK_CONFIG" '.settings.preserveExistingConfig')
    if [[ "$preserve_existing" != "true" ]]; then
        log_info "Clearing existing fallback configuration..."
        sudo -u "$MOLTBOT_USER" -i openclaw models fallbacks clear 2>/dev/null || true
    fi

    # Build fallback list from available providers
    local fallback_models=()
    local fallback_count
    fallback_count=$(jq '.models.fallbacks | length' "$FALLBACK_CONFIG")

    for ((i=0; i<fallback_count; i++)); do
        local fb_provider
        local fb_model
        local fb_key

        fb_provider=$(get_json_value "$FALLBACK_CONFIG" ".models.fallbacks[$i].provider")
        fb_model=$(get_json_value "$FALLBACK_CONFIG" ".models.fallbacks[$i].model")
        fb_key=$(get_json_value "$FALLBACK_CONFIG" ".models.fallbacks[$i].requiresApiKey")

        # Only add fallback if API key is available
        if has_api_key "$fb_key"; then
            fallback_models+=("${fb_provider}/${fb_model}")
        fi
    done

    # Configure fallbacks
    if [[ ${#fallback_models[@]} -gt 0 ]]; then
        log_info "Configuring ${#fallback_models[@]} fallback model(s)..."

        for model in "${fallback_models[@]}"; do
            log_info "  Adding fallback: ${model}"
            if sudo -u "$MOLTBOT_USER" -i openclaw models fallbacks add "$model" 2>/dev/null; then
                log_success "    Added successfully"
                ((configured_count++))
            else
                log_warn "    Failed to add ${model} (may require onboarding first)"
            fi
        done
    else
        log_warn "No fallback models configured (only one API key available)"
    fi

    # Show final configuration
    log_info "Listing configured fallbacks..."
    if sudo -u "$MOLTBOT_USER" -i openclaw models fallbacks list 2>/dev/null; then
        log_success "Fallback configuration complete (${configured_count} fallback(s) configured)"
    else
        log_warn "Unable to list fallbacks (openclaw may need to be configured via onboarding first)"
        log_info "You can configure fallbacks later by running:"
        log_info "  sudo -u ${MOLTBOT_USER} -i openclaw models fallbacks add <provider/model>"
    fi
}

main() {
    # Don't require root - this script can be run by the moltbot user
    # or by root for initial setup

    if [[ ! -d "$MOLTBOT_CONFIG_DIR" ]]; then
        log_error "Moltbot config directory not found: ${MOLTBOT_CONFIG_DIR}"
        log_error "Please run install.sh first"
        exit 1
    fi

    configure_fallbacks
}

main "$@"
