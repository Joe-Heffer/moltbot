# OpenClaw Deployment

[![Deploy to VPS](https://github.com/Joe-Heffer/moltbot/actions/workflows/deploy.yml/badge.svg)](https://github.com/Joe-Heffer/moltbot/actions/workflows/deploy.yml)
[![Lint](https://github.com/Joe-Heffer/moltbot/actions/workflows/lint.yml/badge.svg)](https://github.com/Joe-Heffer/moltbot/actions/workflows/lint.yml)

Deployment scripts and configuration for running [OpenClaw](https://openclaw.ai) on Linux VPS.

## What is OpenClaw?

OpenClaw is a personal AI assistant that runs on your own hardware. It connects to messaging platforms you already use (WhatsApp, Telegram, Slack, Discord, etc.) and can perform tasks, manage your calendar, browse the web, organize files, and run terminal commands.

- **Documentation**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw

## Quick Start

```bash
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot
sudo ./deploy/deploy.sh
sudo -u moltbot -i moltbot onboard
sudo systemctl start moltbot-gateway
sudo systemctl enable moltbot-gateway
```

Then access the Gateway UI at `http://<your-vm-ip>:18789`

For detailed instructions, see **[Quick Start Guide](docs/QUICK_START.md)**.

## Prerequisites

- Ubuntu 24.04 LTS (Debian, RHEL, Oracle Linux also supported)
- Root/sudo access
- At least 2 GB RAM (4 GB recommended)
- API key from [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/), or [Google Gemini](https://aistudio.google.com/apikey)

## Documentation

**Start here**: [Documentation Hub](docs/README.md) — Overview of all guides

### Core Guides
- **[Quick Start](docs/QUICK_START.md)** — Minimal steps to deploy (5-10 min)
- **[Configuration](docs/CONFIGURATION.md)** — AI providers, environment variables, onboarding
- **[Service Management](docs/SERVICE_MANAGEMENT.md)** — Start, stop, monitor, troubleshoot
- **[Deployment Options](docs/DEPLOYMENT.md)** — VPS, local, Docker, NAS, and more

### Operations
- **[GitHub Actions CI/CD](docs/GITHUB_ACTIONS_DEPLOYMENT.md)** — Automated deployment and updates
- **[Low-Memory VPS](docs/LOW_MEMORY_VPS.md)** — Optimization for 2–4 GB RAM systems
- **[Gateway UI Setup](docs/GATEWAY_UI.md)** — Web interface access and authentication

### Security & Planning
- **[Security Guide](docs/SECURITY.md)** — Hardening checklist and best practices
- **[Public vs. Private Repo](docs/PUBLIC_VS_PRIVATE.md)** — Repository visibility considerations
- **[Repository Structure](docs/REPOSITORY_STRUCTURE.md)** — Files and deployment scripts
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — Common issues and solutions

### Learning
- **[Use Cases](docs/USE_CASES.md)** — Real-world applications
- **[Cost Expectations](docs/COST_EXPECTATIONS.md)** — Pricing and budget planning
- **[Community Applications](docs/COMMUNITY_APPLICATIONS.md)** — Examples from the community

## What This Repository Does

This repository provides:
- **`deploy/deploy.sh`** — Idempotent deployment script (install + update)
- **`deploy/setup-server.sh`** — CI/CD server preparation
- **`deploy/lib.sh`** — Shared utilities (logging, validation, memory tuning)
- **GitHub Actions workflows** — Automated deployment and semantic versioning
- **Documentation** — Setup guides, security hardening, troubleshooting

It does **not** contain the OpenClaw application itself (installed via `npm install -g moltbot`).

## Automated Deployment (GitHub Actions)

For CI/CD deployment to your VPS:

1. Run one-time setup on VPS:
   ```bash
   sudo ./deploy/setup-server.sh
   ```

2. Add repository secrets (`VPS_HOST`, `VPS_USERNAME`, `VPS_SSH_KEY`, `VPS_PORT`)

3. Push to `main` branch or manually trigger workflow

See **[GitHub Actions CI/CD Guide](docs/GITHUB_ACTIONS_DEPLOYMENT.md)** for details.

## Common Tasks

### Restart the Service
```bash
sudo systemctl restart moltbot-gateway
```

### View Logs
```bash
sudo journalctl -u moltbot-gateway -f
```

### Run Diagnostics
```bash
sudo -u moltbot -i moltbot doctor
```

### Update OpenClaw
```bash
sudo ./deploy/deploy.sh
```

For more, see **[Service Management](docs/SERVICE_MANAGEMENT.md)**.

## Agent Memory Backup

OpenClaw agents learn from conversations and build context over time. To prevent data loss if your VM is reset or fails, configure automated backups:

```bash
# Copy and configure backup settings
sudo cp /home/moltbot/.config/moltbot/backup.conf.template /home/moltbot/.config/moltbot/backup.conf
sudo nano /home/moltbot/.config/moltbot/backup.conf

# Enable automated daily backups
sudo systemctl enable --now moltbot-backup.timer
```

Supports Git repositories (GitHub, GitLab) and cloud storage (via rclone). See **[Agent Memory Backup Guide](docs/AGENT_MEMORY_BACKUP.md)** for detailed setup instructions.

## Troubleshooting

**Service won't start?**
```bash
sudo journalctl -u moltbot-gateway -n 50
```

**Out of memory?**
See **[Low-Memory VPS](docs/LOW_MEMORY_VPS.md)** for swap setup.

**Gateway unreachable?**
See **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.

## Repository Visibility

This repository is safe to make **public** — it contains no secrets, only generic deployment scripts and documentation. API keys are loaded from `.env` files (excluded by `.gitignore`) or GitHub Actions encrypted secrets.

See **[Public vs. Private](docs/PUBLIC_VS_PRIVATE.md)** for details.

## Contributing

We welcome contributions! See **[Contributing Guidelines](CONTRIBUTING.md)** for:
- Conventional commit format
- Pull request process
- Code review standards

## Release Process

This repository uses **semantic versioning** (0.1.0, 0.2.0, etc.). See **[Releasing Guide](RELEASING.md)** for:
- How releases are automated
- Version bumping rules
- Deployment tracking

## Resources

- **[OpenClaw Official Docs](https://docs.openclaw.ai)** — Complete guide to OpenClaw
- **[OpenClaw GitHub](https://github.com/openclaw/openclaw)** — Source code and issues
- **[Awesome Moltbot Skills](https://github.com/VoltAgent/awesome-moltbot-skills)** — 700+ community skills
- **[Deployment Examples](https://docs.openclaw.ai)** — Installation on different platforms

## License

MIT License - See [LICENSE](LICENSE) file

---

**Questions?** Start with the **[Quick Start Guide](docs/QUICK_START.md)** or check the **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.
