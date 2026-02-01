# OpenClaw Documentation

Welcome to the OpenClaw deployment documentation. This directory contains guides for getting started, configuring, securing, and troubleshooting your deployment.

## Quick Navigation

### 🚀 Getting Started
- **[Quick Start](./QUICK_START.md)** — Deploy in 5-10 minutes
- **[Deployment Options](./DEPLOYMENT.md)** — VPS, local, Docker, NAS, and more

### ⚙️ Configuration & Setup
- **[Configuration Guide](./CONFIGURATION.md)** — AI providers, environment variables, onboarding
- **[Service Management](./SERVICE_MANAGEMENT.md)** — Start, stop, monitor the service
- **[Gateway UI Setup](./GATEWAY_UI.md)** — Access the web interface
- **[Telegram Setup](./TELEGRAM_SETUP.md)** — Connect Telegram bot
- **[WhatsApp Legal & ToS](./WHATSAPP_LEGAL.md)** — Important considerations
- **[File Sharing Best Practices](./FILE_SHARING.md)** — Share files and projects with agents

### 🔄 Operations & Automation
- **[GitHub Actions CI/CD](./GITHUB_ACTIONS_DEPLOYMENT.md)** — Automated deployment and updates
- **[Low-Memory VPS](./LOW_MEMORY_VPS.md)** — Optimize for 2–4 GB RAM systems
- **[Agent Memory Backup](./AGENT_MEMORY_BACKUP.md)** — Automated backups to prevent data loss

### 🔒 Security & Hardening
- **[Security Guide](./SECURITY.md)** — Hardening checklist and best practices
- **[Public vs. Private Repo](./PUBLIC_VS_PRIVATE.md)** — Repository visibility considerations

### 📚 Reference & Learning
- **[Repository Structure](./REPOSITORY_STRUCTURE.md)** — Files, scripts, workflows
- **[Troubleshooting](./TROUBLESHOOTING.md)** — Common issues and solutions
- **[Use Cases](./USE_CASES.md)** — Real-world applications
- **[Cost Expectations](./COST_EXPECTATIONS.md)** — Pricing and budget planning
- **[Local LLM Backup Options](./LOCAL_LLM_BACKUP.md)** — Using local LLMs on CPU-only VPS
- **[Community Applications](./COMMUNITY_APPLICATIONS.md)** — Examples from the community

## Recommended Reading Order

**First time deploying?**
1. [Quick Start](./QUICK_START.md) — Get it running
2. [Configuration Guide](./CONFIGURATION.md) — Set up API keys
3. [Security Guide](./SECURITY.md) — Harden your setup

**Need to automate?**
1. [GitHub Actions CI/CD](./GITHUB_ACTIONS_DEPLOYMENT.md) — Set up GitHub Actions
2. [Repository Structure](./REPOSITORY_STRUCTURE.md) — Understand the scripts

**Having issues?**
1. [Troubleshooting](./TROUBLESHOOTING.md) — Find your problem
2. [Low-Memory VPS](./LOW_MEMORY_VPS.md) — If out of memory
3. [Service Management](./SERVICE_MANAGEMENT.md) — Monitor and debug

## Official OpenClaw Documentation

For OpenClaw-specific features (channels, skills, architecture), refer to the official documentation:
- **[OpenClaw Documentation](https://docs.openclaw.ai)** — Main documentation hub
- **[Channel Configuration](https://docs.openclaw.ai/channels)** — WhatsApp, Telegram, Discord, Slack, etc.
- **[Skills Marketplace](https://docs.openclaw.ai/tools/skills)** — Discover and install skills
- **[Architecture Overview](https://docs.openclaw.ai)** — System design and capabilities

## Deployment Quick Reference

| Platform | Setup Time | Best For | Cost |
|----------|-----------|---------|------|
| **Linux VPS** | 5-10 min | Always-on, production | $4-24/mo |
| **GitHub Actions** | 10 min | Automated updates | Free (with secrets) |
| **DigitalOcean 1-Click** | 5 min | Quick start | $4-24/mo |
| **Cloudflare Workers** | 15 min | Serverless | ~$5/mo |
| **Local Machine** | 5 min | Development | Free |
| **NAS/Raspberry Pi** | 20 min | Home automation | Varies |

Choose your platform and follow the **[Quick Start](./QUICK_START.md)** or **[Deployment Options](./DEPLOYMENT.md)** guide.

## File Structure

```
docs/
├── README.md                          (this file - navigation hub)
├── QUICK_START.md                     (5-min deployment guide)
├── CONFIGURATION.md                   (AI providers, env vars, onboarding)
├── SERVICE_MANAGEMENT.md              (systemctl, monitoring, logs)
├── GITHUB_ACTIONS_DEPLOYMENT.md       (CI/CD setup and automation)
├── DEPLOYMENT.md                      (multi-platform deployment options)
├── LOW_MEMORY_VPS.md                  (2-4 GB RAM optimization)
├── AGENT_MEMORY_BACKUP.md             (agent memory backup guide)
├── FILE_SHARING.md                    (file sharing best practices)
├── GATEWAY_UI.md                      (web interface setup)
├── TELEGRAM_SETUP.md                  (Telegram bot setup)
├── WHATSAPP_LEGAL.md                  (WhatsApp ToS and risks)
├── SECURITY.md                        (hardening checklist)
├── PUBLIC_VS_PRIVATE.md               (repo visibility guide)
├── REPOSITORY_STRUCTURE.md            (repo files and scripts)
├── TROUBLESHOOTING.md                 (common issues)
├── USE_CASES.md                       (real-world applications)
├── COST_EXPECTATIONS.md               (pricing guide)
├── LOCAL_LLM_BACKUP.md                (local LLM feasibility and alternatives)
└── COMMUNITY_APPLICATIONS.md          (community examples)
```

## Common Commands

### Deploy to VPS
```bash
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot
sudo ./deploy/deploy.sh
```

### Configure via Onboarding
```bash
sudo -u moltbot -i moltbot onboard
```

### Start the Service
```bash
sudo systemctl start moltbot-gateway
sudo systemctl enable moltbot-gateway
```

### View Logs
```bash
sudo journalctl -u moltbot-gateway -f
```

### Update OpenClaw
```bash
cd moltbot
git pull origin main
sudo ./deploy/deploy.sh
```

## Need Help?

- **Getting started?** → [Quick Start](./QUICK_START.md)
- **Setting up GitHub Actions?** → [GitHub Actions CI/CD](./GITHUB_ACTIONS_DEPLOYMENT.md)
- **Configuring API keys?** → [Configuration Guide](./CONFIGURATION.md)
- **Service issues?** → [Service Management](./SERVICE_MANAGEMENT.md)
- **Out of memory?** → [Low-Memory VPS](./LOW_MEMORY_VPS.md)
- **Security concerns?** → [Security Guide](./SECURITY.md)
- **Other problems?** → [Troubleshooting](./TROUBLESHOOTING.md)

## Community & Support

- **[OpenClaw GitHub Issues](https://github.com/openclaw/openclaw/issues)** — Report bugs and feature requests
- **[OpenClaw Discussions](https://github.com/openclaw/openclaw/discussions)** — Ask questions and share ideas
- **[Awesome Moltbot Skills](https://github.com/VoltAgent/awesome-moltbot-skills)** — 700+ community skills

---

**Ready to start?** Head to [Quick Start](./QUICK_START.md) or [Documentation Hub](../README.md) for an overview.
