# OpenClaw Deployment

[![Deploy to VPS](https://github.com/Joe-Heffer/moltbot/actions/workflows/deploy.yml/badge.svg)](https://github.com/Joe-Heffer/moltbot/actions/workflows/deploy.yml)
[![Lint](https://github.com/Joe-Heffer/moltbot/actions/workflows/lint.yml/badge.svg)](https://github.com/Joe-Heffer/moltbot/actions/workflows/lint.yml)

Deployment scripts and configuration for running [OpenClaw](https://openclaw.ai) (formerly ClawdBot) on Linux VPS.

## What is OpenClaw?

OpenClaw is a personal AI assistant that runs on your own hardware. It connects to messaging platforms you already use (WhatsApp, Telegram, Slack, Discord, etc.) and can perform tasks, manage your calendar, browse the web, organize files, and run terminal commands.

- **Documentation**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw

## Prerequisites

- Ubuntu Linux 24.04 LTS
- Root/sudo access
- At least 2 GB RAM (4 GB recommended); see the [official system requirements](https://docs.openclaw.ai/help/faq)
- An API key from [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/), or [Google Gemini](https://aistudio.google.com/apikey)

> **Low-memory VPS**: The installer automatically detects available RAM and
> tunes `MemoryMax` and Node.js heap size accordingly. Systems with less than
> 4 GB RAM should add swap space (see [Low-Memory VPS](#low-memory-vps) below).

## Quick Start

```bash
# Clone this repository
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot

# Run the deployment script
sudo ./deploy/deploy.sh

# Run onboarding as the moltbot user
sudo -u moltbot -i moltbot onboard

# Start and enable the service
sudo systemctl start moltbot-gateway
sudo systemctl enable moltbot-gateway
```

## Deployment Details

The `deploy.sh` script is idempotent — it handles both first-time installation and subsequent updates. On every run it:

1. Installs system dependencies (curl, git, gcc, etc.)
2. Installs Node.js 22 via NodeSource repository
3. Creates a dedicated `moltbot` user for security
4. Installs or updates moltbot globally via npm
5. Regenerates the systemd service (so configuration changes always propagate)
6. Opens port 18789 in the firewall (if firewalld is active)
7. Sets up AI provider fallback configuration (automatic retry on failures)

If the service was already running (i.e. this is an update), it restarts the service, runs a health check, and executes `moltbot doctor --repair`. On first install, it prints onboarding instructions instead.

## Directory Structure

```
deploy/
├── deploy.sh               # Idempotent deployment script (install + update)
├── setup-server.sh         # One-time server preparation for CI/CD
├── uninstall.sh            # Removal script
├── configure-fallbacks.sh  # AI provider fallback configuration script
├── lib.sh                  # Shared library (logging, validation, memory tuning)
├── moltbot-gateway.service # Systemd service file (reference)
├── moltbot.env.template    # Environment variable template
└── moltbot.fallbacks.json  # AI provider fallback configuration

.github/workflows/
├── deploy.yml              # GitHub Actions deployment workflow (with environment tracking)
└── lint.yml                # ShellCheck, actionlint, yamllint
```

## CI/CD Deployment (GitHub Actions)

For automated deployments to your VPS, use the included GitHub Actions workflow.

### One-Time Server Setup

1. **SSH into your VPS** and run the server setup script:

   ```bash
   # Download and run setup script
   curl -fsSL https://raw.githubusercontent.com/Joe-Heffer/moltbot/main/deploy/setup-server.sh -o setup-server.sh
   chmod +x setup-server.sh
   sudo ./setup-server.sh
   ```

   This creates a `deploy` user with limited sudo permissions for CI/CD.

2. **Generate an SSH key pair** (on your local machine):

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-moltbot" -f ~/.ssh/moltbot-deploy
   ```

3. **Add the public key to your server**:

   ```bash
   # Copy to server
   ssh-copy-id -i ~/.ssh/moltbot-deploy.pub deploy@your-server-ip
   ```

4. **Add GitHub repository secrets** at `Settings > Secrets > Actions`:

   | Secret | Value |
   |--------|-------|
   | `VPS_HOST` | Your VPS IP address |
   | `VPS_USERNAME` | `deploy` |
   | `VPS_SSH_KEY` | Contents of `~/.ssh/moltbot-deploy` (private key) |
   | `VPS_PORT` | `22` (or your custom SSH port) |

### Deployment Triggers

The workflow runs automatically when:
- Changes are pushed to `main` branch in the `deploy/` directory
- Manually triggered via GitHub Actions UI

### Manual Deployment

Go to `Actions` > `Deploy to VPS` > `Run workflow` and choose:

| Action | Description |
|--------|-------------|
| `deploy` | Installs or updates moltbot and regenerates all configuration |
| `restart` | Restarts the moltbot-gateway service |

### Workflow Features

- **Deployment tracking**: Each deploy is recorded in the GitHub Environments UI — view history, status, and the live commit under `Settings > Environments > production`
- **Concurrency control**: Only one deployment runs at a time; subsequent triggers queue instead of overlapping
- **Health checks**: Verifies service is running and port is listening after deploy
- **Zero-downtime updates**: Service restarts only after successful update
- **Automatic rollback info**: Logs previous version for easy rollback

## Configuration

### 1. Choose Your AI Provider

Moltbot is **model-agnostic** and supports multiple AI providers. You can configure one or more:

| Provider | Recommended Use | API Key Link | Notes |
|----------|----------------|--------------|-------|
| **Anthropic** | Production use | [console.anthropic.com](https://console.anthropic.com/) | Recommended - Claude Opus 4.5 offers best performance |
| **OpenAI** | Alternative | [platform.openai.com](https://platform.openai.com/api-keys) | GPT-4 and GPT-3.5 models |
| **Google Gemini** | Alternative | [aistudio.google.com](https://aistudio.google.com/apikey) | Gemini Pro and Ultra models |

Unlike ChatGPT's usage limits, you control your own API keys and rate limits. Multiple providers can be configured simultaneously for redundancy.

#### Automatic Failover

The deployment automatically configures **model fallbacks** based on your available API keys:

1. **Primary Model**: Anthropic Claude Opus 4.5 (if `ANTHROPIC_API_KEY` is set)
2. **Fallback 1**: OpenAI GPT-4 (if `OPENAI_API_KEY` is set)
3. **Fallback 2**: Google Gemini Pro (if `GEMINI_API_KEY` is set)

If the primary model fails (rate limits, API errors, etc.), Moltbot automatically switches to the next available fallback. This ensures **continuous operation** even during API outages or rate limiting.

**Customize Fallbacks**: Edit `~/.config/moltbot/moltbot.fallbacks.json` to change the provider priority or add additional models, then run:

```bash
sudo /opt/moltbot-deployment/deploy/configure-fallbacks.sh
```

### 2. Run Onboarding

The onboarding wizard guides you through:
- LLM provider setup (choose from Anthropic, OpenAI, or Google Gemini)
- Workspace configuration
- Channel connections (WhatsApp, Telegram, etc.)
- Skills installation

```bash
sudo -u moltbot -i moltbot onboard
```

### 3. Environment Variables

Copy the template and configure your API keys:

```bash
sudo -u moltbot cp /home/moltbot/.config/moltbot/moltbot.env.template /home/moltbot/.config/moltbot/.env
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Key settings:
- **AI Provider** (choose one or more):
  - `ANTHROPIC_API_KEY` - Anthropic Claude API key (recommended for Claude Opus 4.5)
  - `OPENAI_API_KEY` - OpenAI API key (GPT models)
  - `GEMINI_API_KEY` - Google Gemini API key
- `MOLTBOT_PORT` - Gateway port (default: 18789)

## Service Management

```bash
# Start the service
sudo systemctl start moltbot-gateway

# Stop the service
sudo systemctl stop moltbot-gateway

# Restart the service
sudo systemctl restart moltbot-gateway

# Check status
sudo systemctl status moltbot-gateway

# View logs
sudo journalctl -u moltbot-gateway -f

# Enable auto-start on boot
sudo systemctl enable moltbot-gateway
```

## Accessing the Gateway

Once running, access the Gateway UI at:

```
http://<your-vm-ip>:18789
```

### Gateway Token

The Gateway UI requires an authentication token. The onboarding wizard (`moltbot onboard`) generates this token automatically and stores it in the OpenClaw config file.

To retrieve the token:

```bash
sudo -u moltbot -i cat /home/moltbot/.moltbot/moltbot.json | jq -r '.gateway.auth.token'
```

Then open the Gateway UI with the token as a query parameter:

```
http://<your-vm-ip>:18789?token=YOUR_TOKEN
```

Or paste the token into the **Overview > Gateway Access** panel in the dashboard.

For full setup instructions including firewall configuration, secure remote access, and troubleshooting, see the [Gateway UI Setup Guide](docs/GATEWAY_UI.md).

For secure remote access, consider using [Tailscale Serve/Funnel](https://docs.openclaw.ai/gateway/tailscale).

## Security Recommendations

1. **Use a dedicated user**: The install script creates a `moltbot` user with limited privileges

2. **Configure DM policies**: Use pairing mode (default) to require approval for new contacts
   ```bash
   sudo -u moltbot -i moltbot doctor
   ```

3. **Don't run as root**: Never run moltbot with elevated privileges

4. **Use Tailscale**: For remote access, use Tailscale instead of exposing ports directly

5. **Review skills**: Only install skills from trusted sources

6. **Isolate the VM**: Run moltbot on a dedicated VM that doesn't contain sensitive data

## Public or Private Repository?

This repository is safe to make **public**. It contains only generic deployment scripts, systemd configuration, and documentation — no secrets, credentials, or server-specific details. API keys and SSH credentials are loaded from `.env` files (excluded by `.gitignore`) or GitHub Actions encrypted secrets, never from committed files.

That said, consider the trade-offs before deciding:

**Reasons to keep it public:**

- **No secrets in the repo.** All credentials (API keys, SSH keys, hostnames) live in `.env` files or GitHub Actions secrets, not in version-controlled code. The `.env.template` contains only empty placeholders.
- **Community benefit.** Others deploying OpenClaw can reuse and improve these scripts. Public visibility also invites bug reports, security audits, and contributions.
- **Security through obscurity is not a defence.** The deployment patterns here (systemd hardening, SSH-based CI/CD, dedicated service user) are standard. Hiding them does not make your server safer; properly configuring them does.

**Reasons to keep it private:**

- **Reduces reconnaissance surface.** A public repo reveals your deployment architecture: CI/CD tooling, systemd sandbox boundaries, sudoers policy, default ports, and directory paths. An attacker who knows you run this stack can tailor their approach, even though no single detail is a vulnerability on its own.
- **Operational privacy.** If you prefer not to publicly associate your GitHub account with a specific service running on your infrastructure, a private repo avoids that link.
- **Fork-specific customisations.** If you add server-specific configuration (IP ranges, internal hostnames, custom firewall rules) to your fork, those details should not be public. A private repo prevents accidental exposure.

**Recommendation:** If you use this repo as-is (without adding server-specific details), public is fine. If you fork it and customise it with details specific to your infrastructure, make the fork private or keep those changes in `.env` files and gitignored overlays.

## Low-Memory VPS

The minimum RAM for running OpenClaw is 2 GB (see [official system requirements](https://docs.openclaw.ai/help/faq)). Systems with 1 GB RAM do not have enough memory for the Node.js runtime, V8 heap, and channel connections combined — the OOM killer will terminate the gateway under normal operation.

The installer automatically tunes resource limits based on detected RAM:

| Setting | 2 GB RAM | 4 GB+ RAM |
|---------|----------|-----------|
| `MemoryMax` | 1536M | 2G |
| `--max-old-space-size` | 1024 MB | 1536 MB |

### Adding swap space (recommended for 2 GB RAM)

Creating a swap file prevents the OOM killer from terminating moltbot during memory spikes:

```bash
# Create a 2 GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make it permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Reduce swappiness so swap is only used under pressure
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Reducing channel overhead

Each messaging channel (WhatsApp, Telegram, Discord, Slack) maintains a persistent connection that consumes memory. On a 2 GB VPS, enable only the channels you need in your `.env` file.

## Troubleshooting

### Service won't start

Check the logs:
```bash
sudo journalctl -u moltbot-gateway -n 50
```

### Node.js version issues

Verify Node.js is v22+:
```bash
sudo -u moltbot -i node -v
```

### Systemd service not found

Reload systemd:
```bash
sudo systemctl daemon-reload
```

### Run diagnostics

```bash
sudo -u moltbot -i moltbot doctor
```

## Updating OpenClaw

Re-run the deployment script. It's idempotent — it will update the package, regenerate the systemd service, and restart:

```bash
sudo ./deploy/deploy.sh
```

## Uninstalling

```bash
sudo ./deploy/uninstall.sh
```

## Resources

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [Getting Started Guide](https://docs.openclaw.ai/start/getting-started)
- [Security Guide](https://docs.openclaw.ai/gateway/security)
- [Channels Configuration](https://docs.openclaw.ai/channels)
- [Skills Platform](https://docs.openclaw.ai/tools/skills)

## License

MIT License - See [LICENSE](LICENSE) file
