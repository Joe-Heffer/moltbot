# Moltbot Deployment for Oracle Linux

Deployment scripts and configuration for running [Moltbot](https://molt.bot) (formerly Clawdbot) on Oracle Linux VPS.

## What is Moltbot?

Moltbot is a personal AI assistant that runs on your own hardware. It connects to messaging platforms you already use (WhatsApp, Telegram, Slack, Discord, etc.) and can perform tasks, manage your calendar, browse the web, organize files, and run terminal commands.

- **Documentation**: https://docs.molt.bot
- **GitHub**: https://github.com/moltbot/moltbot

## Prerequisites

- Oracle Linux 8 or 9 (or compatible RHEL-based distro)
- Root/sudo access
- At least 2GB RAM (4GB recommended)
- An API key from [Anthropic](https://console.anthropic.com/) or [OpenAI](https://platform.openai.com/)

## Quick Start

```bash
# Clone this repository
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot

# Run the installation script
sudo ./deploy/install.sh

# Run onboarding as the moltbot user
sudo -u moltbot -i moltbot onboard

# Start and enable the service
sudo systemctl start moltbot-gateway
sudo systemctl enable moltbot-gateway
```

## Installation Details

The `install.sh` script performs the following:

1. Installs system dependencies (curl, git, gcc, etc.)
2. Installs Node.js 22 via NodeSource repository
3. Creates a dedicated `moltbot` user for security
4. Installs moltbot globally via npm
5. Configures a systemd service for automatic startup
6. Opens port 18789 in the firewall (if firewalld is active)

## Directory Structure

```
deploy/
├── install.sh              # Main installation script
├── uninstall.sh            # Removal script
├── moltbot-gateway.service # Systemd service file (reference)
└── moltbot.env.template    # Environment variable template
```

## Configuration

### 1. Run Onboarding

The onboarding wizard guides you through:
- LLM provider setup (Anthropic recommended)
- Workspace configuration
- Channel connections (WhatsApp, Telegram, etc.)
- Skills installation

```bash
sudo -u moltbot -i moltbot onboard
```

### 2. Environment Variables

Copy the template and configure your API keys:

```bash
sudo -u moltbot cp /home/moltbot/.config/moltbot/moltbot.env.template /home/moltbot/.config/moltbot/.env
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Key settings:
- `ANTHROPIC_API_KEY` - Your Anthropic API key (recommended)
- `OPENAI_API_KEY` - Alternative: OpenAI API key
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

For secure remote access, consider using [Tailscale Serve/Funnel](https://docs.molt.bot/gateway/tailscale).

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

## Updating Moltbot

```bash
# Stop the service
sudo systemctl stop moltbot-gateway

# Update moltbot
sudo -u moltbot -i npm update -g moltbot

# Start the service
sudo systemctl start moltbot-gateway
```

Or use the built-in update command:
```bash
sudo -u moltbot -i moltbot update --channel stable
```

## Uninstalling

```bash
sudo ./deploy/uninstall.sh
```

## Resources

- [Moltbot Documentation](https://docs.molt.bot)
- [Getting Started Guide](https://docs.molt.bot/start/getting-started)
- [Security Guide](https://docs.molt.bot/gateway/security)
- [Channels Configuration](https://docs.molt.bot/channels)
- [Skills Platform](https://docs.molt.bot/tools/skills)

## License

MIT License - See [LICENSE](LICENSE) file
