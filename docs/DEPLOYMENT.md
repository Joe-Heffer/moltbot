# Deployment Setups

## Linux VPS (This Repository)

This repository provides production-ready deployment scripts for running OpenClaw on a Linux VPS. It is the recommended approach for always-on operation.

**Supported operating systems:**
- Ubuntu / Debian
- RHEL / Oracle Linux

**Hardware requirements** (see [official system requirements](https://docs.openclaw.ai/help/faq)):

| RAM | MemoryMax | Node.js Heap | Notes |
|-----|-----------|-------------|-------|
| 2 GB | 1.5 GB | 1 GB | Minimum; consider adding swap |
| 4+ GB | 2 GB | 1.5 GB | Recommended; comfortable headroom |

The installer auto-tunes resource limits based on detected RAM.

**Quick start:**

```bash
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot
sudo ./deploy/deploy.sh
```

The deploy script handles Node.js 22 installation, dedicated user creation, systemd service setup, firewall configuration, and resource tuning. It is idempotent — safe to run for both first-time installation and subsequent updates. After first installation, run the onboarding wizard to configure API keys and channels.

**CI/CD deployment:**

For automated deployments via GitHub Actions:

1. Run `sudo ./deploy/setup-server.sh` once on the VPS to create a deploy user with limited sudo privileges.
2. Add repository secrets: `VPS_HOST`, `VPS_USERNAME`, `VPS_SSH_KEY`, `VPS_PORT`.
3. Push to the `main` branch or trigger the workflow manually to deploy or restart.

See the project [README](../README.md) for full CI/CD instructions.

**Service management:**

```bash
sudo systemctl start moltbot-gateway
sudo systemctl stop moltbot-gateway
sudo systemctl restart moltbot-gateway
sudo journalctl -u moltbot-gateway -f   # View logs
sudo -u moltbot -i moltbot doctor       # Run diagnostics
```

## DigitalOcean 1-Click Image

DigitalOcean offers a pre-configured marketplace image for OpenClaw. This is the fastest path to a running instance:

1. Create a droplet from the OpenClaw marketplace image.
2. SSH in and run the onboarding wizard.
3. Configure channels and API keys.

A detailed walkthrough is available in the [DigitalOcean community tutorial](https://www.digitalocean.com/community/tutorials/moltbot-quickstart-guide).

## Cloudflare Workers (Moltworker)

For serverless deployment at approximately $5/month, the [Moltworker project](https://github.com/cloudflare/moltworker) runs OpenClaw on Cloudflare Workers. This approach trades some local execution capabilities for lower maintenance and global edge distribution. See the [Cloudflare blog post](https://blog.cloudflare.com/moltworker-self-hosted-ai-agent/) for architecture details.

## Local Machine (Mac, Linux, WSL2)

For development or personal use on your own workstation:

```bash
npm install -g moltbot@latest
moltbot onboard --install-daemon
```

This installs OpenClaw globally and sets up a background daemon. macOS users get additional capabilities including camera access, screen recording, location services, and native voice support.

**Supported platforms:**
- macOS (Intel and Apple Silicon)
- Linux (x86_64 and ARM64)
- Windows via WSL2

Guides for local setups:
- [Beebom: Mac Mini setup](https://beebom.com/how-to-set-up-clawdbot-moltbot-on-mac-mini/)
- [Medium: Local setup walkthrough](https://kasata.medium.com/how-to-set-up-moltbot-your-personal-ai-assistant-running-locally-on-your-computer-5f9b932e4793)

## NAS and Embedded Hardware

Community members have deployed OpenClaw on:

- **QNAP NAS** -- via Ubuntu Linux Station. See the [QNAP tutorial](https://www.qnap.com/en/how-to/tutorial/article/how-to-install-and-run-moltbot-formerly-clawdbot-on-qnap-ubuntu-linux-station).
- **Raspberry Pi** -- ARM64 builds run on Pi 4 and later models with 4+ GB RAM.
- **Synology NAS** -- via Docker or native Node.js installation.

These setups are best suited for lightweight workloads with fewer active channels.
