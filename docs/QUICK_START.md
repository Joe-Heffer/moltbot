# Quick Start

Get OpenClaw running on a Linux VPS in minutes.

## Prerequisites

- **OS**: Ubuntu 24.04 LTS (also supports Debian, RHEL, Oracle Linux)
- **RAM**: At least 2 GB (4 GB recommended; see [Low-Memory VPS](./LOW_MEMORY_VPS.md))
- **Root/sudo access**
- **API key**: From [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/), or [Google Gemini](https://aistudio.google.com/apikey)

## Installation

```bash
# Clone the repository
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot

# Run the deployment script (idempotent — safe to run multiple times)
sudo ./deploy/deploy.sh
```

The script will:
- Install Node.js 22
- Create a dedicated `openclaw` user
- Install OpenClaw globally via npm
- Set up the `openclaw-gateway` systemd service
- Configure AI provider fallbacks

## Configuration

### Run Onboarding

```bash
sudo -u openclaw -i openclaw onboard
```

The wizard guides you through:
- LLM provider selection (Anthropic, OpenAI, or Google Gemini)
- Workspace setup
- Channel connections (WhatsApp, Telegram, Discord, Slack, etc.)
- Skills installation

### Manual Environment Setup (Optional)

If you prefer to configure manually instead of running onboarding:

```bash
# Copy the environment template
sudo -u openclaw cp /home/openclaw/.config/openclaw/openclaw.env.template /home/openclaw/.config/openclaw/.env

# Edit with your API keys
sudo -u openclaw nano /home/openclaw/.config/openclaw/.env
```

Key settings:
- `ANTHROPIC_API_KEY` — Anthropic Claude API key
- `OPENAI_API_KEY` — OpenAI API key (optional)
- `GEMINI_API_KEY` — Google Gemini API key (optional)
- `OPENCLAW_PORT` — Gateway port (default: 18789)

## Start the Service

```bash
sudo systemctl start openclaw-gateway
sudo systemctl enable openclaw-gateway
```

## Access the Gateway UI

Open your browser and visit:

```
http://<your-vm-ip>:18789
```

Replace `<your-vm-ip>` with your server's IP address.

**Authentication**: The onboarding wizard generates an auth token automatically. Retrieve it with:

```bash
sudo -u openclaw -i cat /home/openclaw/clawd/moltbot.json | jq -r '.gateway.auth.token'
```

Use the token in the URL or paste it into the Gateway UI login screen.

For details, see [Gateway UI Setup](./GATEWAY_UI.md).

## What's Next?

- **Connect channels**: Configure WhatsApp, Telegram, Discord, Slack, etc. (see [official channel docs](https://docs.openclaw.ai/channels))
- **Install skills**: Explore the [Skills Marketplace](https://docs.openclaw.ai/tools/skills)
- **Secure access**: Use [Tailscale](https://tailscale.com/) instead of exposing the port directly (see [Security Guide](./SECURITY.md))
- **Monitor service**: View logs with `sudo journalctl -u openclaw-gateway -f`
- **Run diagnostics**: Execute `sudo -u openclaw -i openclaw doctor`

## Troubleshooting

- **Service won't start**: Check logs with `sudo journalctl -u openclaw-gateway -n 50`
- **Out of memory**: See [Low-Memory VPS](./LOW_MEMORY_VPS.md)
- **Node.js issues**: Verify Node.js v22+ with `sudo -u openclaw -i node -v`
- **More help**: See [Troubleshooting Guide](./TROUBLESHOOTING.md)

## Next Steps

- [Configuration Guide](./CONFIGURATION.md) — AI providers, fallbacks, and environment variables
- [Deployment Options](./DEPLOYMENT.md) — Other platforms (local, Docker, NAS, etc.)
- [GitHub Actions CI/CD](./GITHUB_ACTIONS_DEPLOYMENT.md) — Automated deployment and updates
- [Service Management](./SERVICE_MANAGEMENT.md) — Start, stop, restart, and logs
