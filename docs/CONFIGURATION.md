# Configuration Guide

Configure OpenClaw's AI provider, environment variables, and fallback behavior.

## AI Providers

OpenClaw is **model-agnostic** and supports multiple AI providers. Choose one or more for redundancy.

| Provider | Recommended For | Setup | API Key |
|----------|----------------|-------|---------|
| **Anthropic** | Production (Claude Opus 4.5) | ✓ Automatic | [console.anthropic.com](https://console.anthropic.com/) |
| **OpenAI** | Alternative (GPT-4, GPT-3.5) | ✓ Automatic | [platform.openai.com](https://platform.openai.com/api-keys) |
| **Google Gemini** | Alternative (Gemini Pro, Ultra) | ✓ Automatic | [aistudio.google.com](https://aistudio.google.com/apikey) |

Unlike ChatGPT's usage limits, you control your own API keys and rate limits.

## Automatic Failover

The deployment automatically configures **model fallbacks** based on your available API keys:

1. **Primary**: Anthropic Claude Opus 4.5 (if `ANTHROPIC_API_KEY` is set)
2. **Fallback 1**: OpenAI GPT-4 (if `OPENAI_API_KEY` is set)
3. **Fallback 2**: Google Gemini Pro (if `GEMINI_API_KEY` is set)

If the primary model fails (rate limits, API errors), OpenClaw automatically switches to the next available fallback. This ensures **continuous operation** even during API outages.

### Customize Fallbacks

Edit the fallback configuration:

```bash
sudo -u openclaw nano /home/openclaw/.config/openclaw/openclaw.fallbacks.json
```

Then apply changes:

```bash
sudo /opt/openclaw-deployment/deploy/configure-fallbacks.sh
```

The fallbacks configuration file controls:
- Provider priority order
- Model selection per provider
- Timeout and retry behavior

For detailed fallback configuration options, see the template at `deploy/openclaw.fallbacks.json`.

## Environment Variables

Copy the template and configure your settings:

```bash
sudo -u openclaw cp /home/openclaw/.config/openclaw/openclaw.env.template /home/openclaw/.config/openclaw/.env
sudo -u openclaw nano /home/openclaw/.config/openclaw/.env
```

### AI Provider Keys

```bash
# Anthropic (recommended)
ANTHROPIC_API_KEY=sk-ant-...

# OpenAI (alternative)
OPENAI_API_KEY=sk-...

# Google Gemini (alternative)
GEMINI_API_KEY=AIzaSy...
```

At least one API key is required. Multiple keys enable automatic failover.

### Gateway Configuration

```bash
# Gateway web interface port (default: 18789)
OPENCLAW_PORT=18789

# Trusted proxies (if using reverse proxy like nginx or Tailscale)
GATEWAY_TRUSTED_PROXIES=127.0.0.1
# For Tailscale CGNAT range:
GATEWAY_TRUSTED_PROXIES=100.64.0.0/10
```

### DM Policy (Security)

```bash
# pairing (default) — Requires approval code for new contacts
# open — Accepts all new conversations (not recommended for production)
DM_POLICY=pairing
```

### Resource Tuning

The deploy script automatically sets these based on your RAM, but you can override:

```bash
# Memory limit for the service (e.g., 1536M for 2GB RAM, 2G for 4GB+ RAM)
MEMORY_MAX=1536M

# Node.js heap size (e.g., 1024 for 2GB RAM, 1536 for 4GB+ RAM)
NODE_MAX_OLD_SPACE_SIZE=1024
```

### Channel Configuration

Disable specific channels to reduce memory usage (each maintains a persistent connection):

```bash
# Set these to 0 or remove them to disable channels
TELEGRAM_BOT_TOKEN=...      # Enable Telegram
WHATSAPP_WEBHOOK_URL=...    # Enable WhatsApp
DISCORD_TOKEN=...           # Enable Discord
SLACK_BOT_TOKEN=...         # Enable Slack
```

For complete channel setup, see the [official channel configuration guide](https://docs.openclaw.ai/channels).

## Onboarding Wizard

The easiest way to configure OpenClaw:

```bash
sudo -u openclaw -i openclaw onboard
```

This interactive wizard guides you through:
1. **LLM Provider**: Choose Anthropic, OpenAI, or Google Gemini
2. **Workspace**: Set your workspace name and description
3. **Channels**: Connect WhatsApp, Telegram, Discord, Slack, etc.
4. **Skills**: Browse and install community skills from [ClawHub](https://www.clawhub.ai/skills)

The wizard automatically:
- Generates the auth token for the Gateway UI
- Creates your `.env` file with your API keys
- Configures the systemd service
- Sets up fallback providers if you have multiple keys

## Skills Management (ClawHub)

The deployment installs the [ClawHub](https://www.clawhub.ai/) CLI alongside OpenClaw. ClawHub is the official skill registry — a searchable directory of community skills that extend what your agent can do.

### Browse and Install Skills

```bash
# Search for skills by keyword (uses vector/embedding search)
sudo -u openclaw -i clawhub search "home assistant"

# Sync installed skills with the registry (install/update)
sudo -u openclaw -i clawhub sync
```

Skills are installed into the workspace `skills/` directory and are picked up by OpenClaw on the next session.

### How Skills Work

A skill is a folder containing a `SKILL.md` file (plus optional supporting files). OpenClaw loads workspace skills from `<workspace>/skills/` automatically. Installed skills are tracked in `.clawhub/lock.json`.

Browse the full directory at [clawhub.ai/skills](https://www.clawhub.ai/skills) or the [community skills catalogue](https://docs.openclaw.ai/tools/skills).

## Manual Configuration (Without Onboarding)

If you prefer to configure manually:

```bash
# 1. Copy the env template
sudo -u openclaw cp /home/openclaw/.config/openclaw/openclaw.env.template /home/openclaw/.config/openclaw/.env

# 2. Edit with your API keys
sudo -u openclaw nano /home/openclaw/.config/openclaw/.env

# 3. Set up fallbacks
sudo /opt/openclaw-deployment/deploy/configure-fallbacks.sh

# 4. Generate an auth token (if not already done)
sudo -u openclaw -i openclaw config set gateway.auth.token "$(openssl rand -hex 32)"

# 5. Restart the service
sudo systemctl restart openclaw-gateway
```

## Changing Configuration

After modifying `.env`:

```bash
# Restart the service to apply changes
sudo systemctl restart openclaw-gateway

# View logs to confirm it started
sudo journalctl -u openclaw-gateway -f
```

To change configuration programmatically:

```bash
# Set a value
sudo -u openclaw -i openclaw config set gateway.port 18789

# View current config
sudo -u openclaw -i cat /home/openclaw/clawd/moltbot.json | jq .
```

## Reverse Proxy Configuration

If you expose OpenClaw through a reverse proxy (nginx, Tailscale, Cloudflare):

### Set Trusted Proxies

```bash
# In /home/openclaw/.config/openclaw/.env
GATEWAY_TRUSTED_PROXIES=127.0.0.1        # Local proxy
GATEWAY_TRUSTED_PROXIES=100.64.0.0/10    # Tailscale CGNAT
```

The deploy script converts this to `gateway.trustedProxies` in the JSON config.

Or set directly:

```bash
sudo -u openclaw -i openclaw config set gateway.trustedProxies '["127.0.0.1"]'
```

This ensures the gateway reads the real client IP from `X-Forwarded-For` headers instead of the proxy's IP.

## Diagnostics

Run the doctor command to check your configuration:

```bash
sudo -u openclaw -i openclaw doctor
```

This verifies:
- All configured API keys are valid
- Required environment variables are set
- Service permissions are correct
- Channels are properly configured

Use `--repair` to fix common issues automatically:

```bash
sudo -u openclaw -i openclaw doctor --repair
```

## Related Documentation

- [Quick Start](./QUICK_START.md) — Get up and running
- [Service Management](./SERVICE_MANAGEMENT.md) — Start, stop, and monitor the service
- [Security Guide](./SECURITY.md) — Hardening and security best practices
- [Official Configuration Reference](https://docs.openclaw.ai/install/configuration) — Complete configuration documentation
