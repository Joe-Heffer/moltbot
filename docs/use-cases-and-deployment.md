# Moltbot: Use Cases and Deployment Guide

Moltbot is a self-hosted, open-source personal AI assistant that connects to
messaging platforms and executes real tasks on your machine. Unlike traditional
chatbots that only produce text, Moltbot runs shell commands, manages files,
browses the web, and automates workflows autonomously. It is powered by LLMs
(Anthropic Claude recommended, OpenAI supported) and communicates through
WhatsApp, Telegram, Slack, Discord, Signal, and many other channels.

This document covers appropriate use cases, deployment architectures, security
considerations, and community-driven applications. For the canonical getting
started guide, see the [official documentation](https://docs.molt.bot/start/getting-started).

---

## Table of Contents

1. [Use Cases](#use-cases)
   - [Personal Productivity](#personal-productivity)
   - [Developer and DevOps Workflows](#developer-and-devops-workflows)
   - [Home Automation and IoT](#home-automation-and-iot)
   - [Media and Content Management](#media-and-content-management)
   - [Finance and Tracking](#finance-and-tracking)
   - [Research and Knowledge Management](#research-and-knowledge-management)
2. [Deployment Setups](#deployment-setups)
   - [Linux VPS (This Repository)](#linux-vps-this-repository)
   - [DigitalOcean 1-Click Image](#digitalocean-1-click-image)
   - [Cloudflare Workers (Moltworker)](#cloudflare-workers-moltworker)
   - [Local Machine (Mac, Linux, WSL2)](#local-machine-mac-linux-wsl2)
   - [NAS and Embedded Hardware](#nas-and-embedded-hardware)
3. [Security Considerations](#security-considerations)
4. [Community Applications](#community-applications)
5. [Cost Expectations](#cost-expectations)
6. [Further Reading](#further-reading)

---

## Use Cases

### Personal Productivity

Moltbot excels as a general-purpose assistant that stays available 24/7 across
your preferred messaging apps. Typical productivity use cases include:

- **Calendar and scheduling** -- managing appointments, setting reminders, and
  coordinating across time zones. Community skills integrate with Google
  Calendar, CalDAV, and iCloud Calendar.
- **Email triage** -- screening incoming mail, drafting replies, and
  surfacing important threads. Gmail Pub/Sub integration enables real-time
  notifications.
- **Task management** -- creating and updating items in Notion, Todoist,
  Linear, or Jira through natural language commands.
- **File organization** -- sorting downloads, renaming batches of files,
  and classifying documents into folder structures.
- **Document processing** -- extracting data from receipts, invoices, or
  images and structuring it into spreadsheets or databases.

The official documentation describes Moltbot as an assistant that can "perform
tasks, manage your calendar, browse the web, organize files, and run terminal
commands" ([docs.molt.bot](https://docs.molt.bot/start/getting-started)).

### Developer and DevOps Workflows

Moltbot has deep integration with development tools:

- **Remote server management** -- monitor services, tail logs, restart
  processes, and deploy code on remote machines via messaging apps.
- **CI/CD orchestration** -- trigger builds, check pipeline status, and
  receive notifications on failures.
- **Git workflows** -- create branches, review diffs, manage pull requests,
  and enforce conventional commits through community skills.
- **Code generation and refactoring** -- leverage the underlying LLM to
  generate boilerplate, write tests, or refactor existing code.
- **Database operations** -- query databases, run migrations, and generate
  reports using DuckDB or other CLI tools.

The [MoltHub skills directory](https://docs.molt.bot/tools/skills) lists 40+
DevOps and cloud skills covering Azure CLI, Docker, Kubernetes, Cloudflare,
Vercel, and more.

### Home Automation and IoT

The community has built 30+ skills for smart home control:

- **Home Assistant integration** -- control lights, thermostats, locks, and
  cameras through conversational commands.
- **Tesla vehicle management** -- lock/unlock, adjust climate, monitor charge
  status, and locate the vehicle.
- **3D printer management** -- monitor print jobs, adjust temperatures, and
  receive completion notifications.
- **Proactive monitoring** -- Moltbot can watch directories, sensor readings,
  or system metrics and reach out when thresholds are exceeded, without
  being prompted.

### Media and Content Management

- **Music and streaming** -- control Spotify, Plex, or YouTube playback.
- **Image and video generation** -- invoke ComfyUI, DALL-E, or Figma
  through conversational commands.
- **Transcription and speech** -- process audio with Whisper, generate
  voice responses with ElevenLabs, and take voice commands on macOS/iOS.
- **Podcast and video workflows** -- download, transcribe, summarize, and
  tag media files.

### Finance and Tracking

- **Budget management** -- track expenses, categorize transactions, and
  generate spending reports.
- **Cryptocurrency monitoring** -- watch portfolio balances and receive
  alerts on price movements.
- **Invoice processing** -- extract line items from invoices and reconcile
  against records.

### Research and Knowledge Management

- **Web research** -- browse the web, extract information, and compile
  summaries using a dedicated Chromium instance.
- **Personal knowledge bases** -- integrate with Obsidian, Logseq, Bear,
  or Apple Notes for storing and retrieving information.
- **Academic research** -- search papers, extract citations, and organize
  references.

The skills marketplace lists search integrations with Brave Search, Exa AI,
Kagi, and Tavily.

---

## Deployment Setups

### Linux VPS (This Repository)

This repository provides production-ready deployment scripts for running
Moltbot on a Linux VPS. It is the recommended approach for always-on
operation.

**Supported operating systems:**

- Ubuntu / Debian
- RHEL / Oracle Linux

**Hardware requirements** (see [official system requirements](https://docs.molt.bot/help/faq)):

| RAM   | MemoryMax | Node.js Heap | Notes                             |
| ----- | --------- | ------------ | --------------------------------- |
| 2 GB  | 1.5 GB    | 1 GB         | Minimum; consider adding swap     |
| 4+ GB | 2 GB      | 1.5 GB       | Recommended; comfortable headroom |

The installer auto-tunes resource limits based on detected RAM.

**Quick start:**

```bash
git clone https://github.com/Joe-Heffer/moltbot.git
cd moltbot
sudo ./deploy/deploy.sh
```

The installer handles Node.js 22 installation, dedicated user creation,
systemd service setup, firewall configuration, and resource tuning. After
installation, run the onboarding wizard to configure API keys and channels.

**CI/CD deployment:**

For automated deployments via GitHub Actions:

1. Run `sudo ./deploy/setup-server.sh` once on the VPS to create a deploy
   user with limited sudo privileges.
2. Add repository secrets: `VPS_HOST`, `VPS_USERNAME`, `VPS_SSH_KEY`,
   `VPS_PORT`.
3. Push to the `main` branch or trigger the workflow manually to install,
   update, or restart.

See the project [README](../README.md) for full CI/CD instructions.

**Service management:**

```bash
sudo systemctl start moltbot-gateway
sudo systemctl stop moltbot-gateway
sudo systemctl restart moltbot-gateway
sudo journalctl -u moltbot-gateway -f   # View logs
sudo -u moltbot -i moltbot doctor       # Run diagnostics
```

### DigitalOcean 1-Click Image

DigitalOcean offers a pre-configured marketplace image for Moltbot. This is
the fastest path to a running instance:

1. Create a droplet from the Moltbot marketplace image.
2. SSH in and run the onboarding wizard.
3. Configure channels and API keys.

A detailed walkthrough is available in the
[DigitalOcean community tutorial](https://www.digitalocean.com/community/tutorials/moltbot-quickstart-guide).

### Cloudflare Workers (Moltworker)

For serverless deployment at approximately $5/month, the
[Moltworker project](https://github.com/cloudflare/moltworker) runs Moltbot
on Cloudflare Workers. This approach trades some local execution capabilities
for lower maintenance and global edge distribution. See the
[Cloudflare blog post](https://blog.cloudflare.com/moltworker-self-hosted-ai-agent/)
for architecture details.

### Local Machine (Mac, Linux, WSL2)

For development or personal use on your own workstation:

```bash
npm install -g openclaw@latest
moltbot onboard --install-daemon
```

This installs Moltbot globally and sets up a background daemon. macOS users
get additional capabilities including camera access, screen recording,
location services, and native voice support.

**Supported platforms:**

- macOS (Intel and Apple Silicon)
- Linux (x86_64 and ARM64)
- Windows via WSL2

Guides for local setups:

- [Beebom: Mac Mini setup](https://beebom.com/how-to-set-up-clawdbot-moltbot-on-mac-mini/)
- [Medium: Local setup walkthrough](https://kasata.medium.com/how-to-set-up-moltbot-your-personal-ai-assistant-running-locally-on-your-computer-5f9b932e4793)

### NAS and Embedded Hardware

Community members have deployed Moltbot on:

- **QNAP NAS** -- via Ubuntu Linux Station. See the
  [QNAP tutorial](https://www.qnap.com/en/how-to/tutorial/article/how-to-install-and-run-moltbot-formerly-clawdbot-on-qnap-ubuntu-linux-station).
- **Raspberry Pi** -- ARM64 builds run on Pi 4 and later models with 4+ GB
  RAM.
- **Synology NAS** -- via Docker or native Node.js installation.

These setups are best suited for lightweight workloads with fewer active
channels.

---

## Security Considerations

Moltbot has full access to the host system it runs on. The official
[security documentation](https://docs.molt.bot/gateway/security) and the
project's RAK threat framework identify three primary risk vectors:

- **Root Risk** -- compromise of the host machine through the agent's shell
  access.
- **Agency Risk** -- unintended destructive actions taken autonomously by the
  agent.
- **Keys Risk** -- theft of API keys, tokens, and credentials stored on the
  host.

### Hardening checklist

1. **Dedicated machine or VM.** Never run Moltbot on a workstation that holds
   sensitive data, production credentials, or access to critical
   infrastructure.

2. **Non-root execution.** The install script in this repository creates a
   dedicated `moltbot` user with limited privileges. The systemd service
   enforces `NoNewPrivileges`, `ProtectSystem=strict`, and
   `ProtectHome=read-only`.

3. **DM pairing mode.** The default `DM_POLICY=pairing` setting requires an
   approval code before new contacts can interact with the bot. Do not set
   this to `open` in production.

4. **Network isolation.** Use [Tailscale](https://tailscale.com/) or a VPN
   for remote access instead of exposing the gateway port directly to the
   internet. Hundreds of unprotected Moltbot instances have been found via
   Shodan with open admin ports.

5. **Review community skills.** Skills from MoltHub are not audited.
   Security researchers have demonstrated proof-of-concept attacks through
   malicious skills that execute arbitrary commands. Review the source of
   every skill before installation.

6. **Credential management.** Store API keys in environment files with
   restrictive permissions (mode `0600`, owned by the moltbot user). Consider
   using a secrets manager such as 1Password or Bitwarden. GitGuardian
   reported 181 leaked secrets across public Moltbot repositories.

7. **Docker sandboxing.** For additional isolation, wrap the agent in a
   hardened Docker container. See the
   [Composio hardening guide](https://composio.dev/blog/secure-moltbot-clawdbot-setup-composio)
   for a walkthrough.

8. **Keep Moltbot updated.** Run `./deploy/deploy.sh` or trigger the CI/CD
   update workflow regularly to pick up security patches.

For in-depth security analysis, see:

- [1Password: It's Incredible. It's Terrifying. It's MoltBot.](https://1password.com/blog/its-moltbot)
- [Cisco: Personal AI Agents Like Moltbot Are a Security Nightmare](https://blogs.cisco.com/ai/personal-ai-agents-like-moltbot-are-a-security-nightmare)
- [GitGuardian: Moltbot Goes Viral -- And So Do Your Secrets](https://blog.gitguardian.com/moltbot-personal-assistant-goes-viral-and-so-do-your-secrets/)
- [Hostinger: How to Secure and Harden Moltbot](https://www.hostinger.com/support/how-to-secure-and-harden-moltbot-security/)

---

## Community Applications

The Moltbot community has produced creative applications beyond the core use
cases. The [awesome-moltbot-skills](https://github.com/VoltAgent/awesome-moltbot-skills)
repository catalogues 700+ skills across 28 categories.

### Notable community examples

- **Autonomous restaurant reservations.** A user asked Moltbot to book a
  restaurant. When the bot could not use OpenTable, it autonomously acquired
  AI voice software and phoned the restaurant to make the reservation.

- **Kanban board generation.** Within an hour of initial setup, a user's
  Moltbot instance had built a fully featured kanban board for task
  assignment without step-by-step instructions.

- **Tesla fleet management.** Community skills allow locking, unlocking,
  climate control, charge monitoring, and vehicle location through
  conversational commands.

- **3D printer monitoring.** Skills connect to OctoPrint and similar
  controllers to monitor print jobs, adjust temperatures, and send
  completion notifications.

- **Meal planning and grocery delivery.** Users have built workflows that
  generate weekly meal plans, create shopping lists, and place grocery
  delivery orders.

- **Multi-agent orchestration.** Advanced setups use Moltbot's sessions API
  to run multiple agents in parallel -- one monitoring email, another managing
  calendar, and a third coordinating between them.

### Skills ecosystem by category

| Category            | Skills | Examples                              |
| ------------------- | ------ | ------------------------------------- |
| DevOps and Cloud    | 41     | Azure CLI, Docker, Kubernetes, Vercel |
| CLI Utilities       | 41     | DuckDB, jq, tmux, unit conversion     |
| Productivity        | 41     | Notion, Todoist, Linear, Jira         |
| Notes and PKM       | 44     | Obsidian, Logseq, Bear, Apple Notes   |
| AI and LLMs         | 38     | Multi-model orchestration, Ollama     |
| Smart Home          | 31     | Home Assistant, Tesla, thermostats    |
| Transportation      | 34     | Tesla, flight check-in                |
| Finance             | 29     | Budgeting, crypto tracking            |
| Media               | 29     | YouTube, Spotify, Plex                |
| Health and Fitness  | 26     | Apple Health, workout tracking        |
| Communication       | 26     | Email, messaging, voice               |
| Search and Research | 23     | Brave Search, Exa AI, Kagi, Tavily    |

See the full directory at [docs.molt.bot/tools/skills](https://docs.molt.bot/tools/skills).

---

## Cost Expectations

Moltbot itself is free and open source (MIT license). The primary ongoing cost
is LLM API usage:

| Usage Level | Monthly Estimate | Typical Profile                             |
| ----------- | ---------------- | ------------------------------------------- |
| Light       | $10 -- $30       | Occasional queries, simple tasks            |
| Moderate    | $30 -- $70       | Daily use, multi-channel, background tasks  |
| Heavy       | $70 -- $150      | Continuous operation, multi-agent workflows |

Anthropic's Claude Pro or Max subscriptions can be used as an alternative to
per-token API billing. VPS hosting adds $4 -- $24/month depending on provider
and RAM. Cloudflare Workers deployment runs at approximately $5/month.

---

## Further Reading

### Official resources

- [Official documentation](https://docs.molt.bot/start/getting-started)
- [Security guide](https://docs.molt.bot/gateway/security)
- [Skills documentation](https://docs.molt.bot/tools/skills)
- [GitHub repository](https://github.com/moltbot/moltbot)

### Tutorials

- [DigitalOcean quickstart](https://www.digitalocean.com/community/tutorials/moltbot-quickstart-guide)
- [DataCamp: Control your PC from WhatsApp](https://www.datacamp.com/tutorial/moltbot-clawdbot-tutorial)
- [Hostinger VPS installation](https://www.hostinger.com/support/how-to-install-moltbot-on-hostinger-vps/)
- [AI Fire: Install and use guide](https://www.aifire.co/p/moltbot-guide-how-to-install-use-the-viral-ai-agent)

### Analysis and commentary

- [TechCrunch: Everything you need to know](https://techcrunch.com/2026/01/27/everything-you-need-to-know-about-viral-personal-ai-assistant-clawdbot-now-moltbot/)
- [DEV Community: Ultimate personal AI assistant guide](https://dev.to/czmilo/moltbot-the-ultimate-personal-ai-assistant-guide-for-2026-d4e)
- [ChatPRD: 24 hours with Moltbot](https://www.chatprd.ai/how-i-ai/24-hours-with-clawdbot-moltbot-3-workflows-for-ai-agent)
- [Cloudflare: Introducing Moltworker](https://blog.cloudflare.com/moltworker-self-hosted-ai-agent/)
