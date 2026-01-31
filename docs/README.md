# Moltbot Documentation

Welcome to the Moltbot documentation. This directory contains guides for use cases, deployment options, security, community applications, and cost information.

## Official Documentation

The primary source for OpenClaw/Moltbot documentation is:
- **[OpenClaw Documentation](https://docs.openclaw.ai)** — Main documentation hub with index, architecture, installation, and configuration reference

## Quick Links

### Getting Started
- **[Official Getting Started Guide](https://docs.openclaw.ai)** - Complete installation and onboarding
- **[Deployment Guide](./DEPLOYMENT.md)** - How to deploy Moltbot across different platforms

### Understanding Moltbot
- **[Use Cases](./USE_CASES.md)** - Real-world applications and workflows
  - Personal productivity (calendar, email, tasks)
  - Developer and DevOps workflows
  - Home automation and IoT
  - Media and content management
  - Finance and tracking
  - Research and knowledge management

- **[Community Applications](./COMMUNITY_APPLICATIONS.md)** - Creative examples from the community
  - Notable use cases and examples
  - Skills ecosystem overview

### Running Moltbot
- **[Gateway UI Setup](./GATEWAY_UI.md)** - Access and configure the web interface
- **[Deployment Options](./DEPLOYMENT.md)** - Choose the right setup for you
  - Linux VPS (recommended for production)
  - DigitalOcean 1-Click marketplace image
  - Cloudflare Workers (serverless)
  - Local machine (Mac, Linux, WSL2)
  - NAS and embedded hardware

- **[Security Guide](./SECURITY.md)** - Secure deployment and hardening checklist
  - Risk assessment
  - Security best practices
  - Hardening recommendations

- **[Telegram Setup](./TELEGRAM_SETUP.md)** - Connect Moltbot to Telegram via BotFather
  - Creating a bot and obtaining a token
  - Configuring the token on your server
  - Security considerations

- **[WhatsApp Legal & ToS](./WHATSAPP_LEGAL.md)** - WhatsApp Terms of Service considerations
  - Unofficial automation risks and account bans
  - Official Business API vs unofficial libraries
  - 2025-2026 AI chatbot policy changes
  - Platform comparison (Discord, Telegram, Slack, Signal)

- **[Troubleshooting](./TROUBLESHOOTING.md)** - Common issues and how to fix them
  - Missing config crash loop
  - Health check failures
  - OOM kills and low-memory fixes

- **[Cost Expectations](./COST_EXPECTATIONS.md)** - Pricing and budget planning

## Deployment Quick Start

Choose your platform:

| Platform | Setup Time | Best For | Cost |
|----------|-----------|---------|------|
| **Linux VPS** | 10 min | Always-on, production | $4-24/mo |
| **DigitalOcean 1-Click** | 5 min | Quick start, no config | $4-24/mo |
| **Cloudflare Workers** | 15 min | Serverless, low-cost | ~$5/mo |
| **Local Machine** | 5 min | Development, personal | Free |
| **NAS/Raspberry Pi** | 20 min | Home automation | Varies |

For detailed instructions, see [Deployment Guide](./DEPLOYMENT.md).

## Community & Support

- **[Awesome Moltbot Skills](https://github.com/VoltAgent/awesome-moltbot-skills)** - 700+ community skills
- **[Official GitHub](https://github.com/moltbot/moltbot)** - Source code and issues
- **[Skills Marketplace](https://docs.molt.bot/tools/skills)** - Discover and install skills

## Security First

Before deploying, review the [Security Guide](./SECURITY.md) to understand risk vectors and hardening best practices.

## Additional Resources

- **Tutorials**
  - [DigitalOcean quickstart](https://www.digitalocean.com/community/tutorials/moltbot-quickstart-guide)
  - [Hostinger VPS installation](https://www.hostinger.com/support/how-to-install-moltbot-on-hostinger-vps/)
  - [Mac Mini setup](https://beebom.com/how-to-set-up-clawdbot-moltbot-on-mac-mini/)

- **Analysis & Commentary**
  - [TechCrunch: Everything you need to know](https://techcrunch.com/2026/01/27/everything-you-need-to-know-about-viral-personal-ai-assistant-clawdbot-now-moltbot/)
  - [DEV Community: Ultimate guide](https://dev.to/czmilo/moltbot-the-ultimate-personal-ai-assistant-guide-for-2026-d4e)
  - [Cloudflare: Introducing Moltworker](https://blog.cloudflare.com/moltworker-self-hosted-ai-agent/)

## File Structure

```
docs/
├── README.md                      (this file - navigation hub)
├── USE_CASES.md                   (use cases by category)
├── DEPLOYMENT.md                  (deployment options)
├── SECURITY.md                    (security hardening)
├── COMMUNITY_APPLICATIONS.md      (community examples)
├── GATEWAY_UI.md                  (gateway web interface setup)
├── TELEGRAM_SETUP.md              (Telegram bot setup guide)
├── WHATSAPP_LEGAL.md              (WhatsApp ToS and legal considerations)
├── TROUBLESHOOTING.md             (common issues and fixes)
├── COST_EXPECTATIONS.md           (pricing information)
└── use-cases-and-deployment.md    (legacy combined file - deprecated)
```

For the canonical combined reference, see [use-cases-and-deployment.md](./use-cases-and-deployment.md).
