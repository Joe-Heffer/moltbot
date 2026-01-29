# Moltbot Documentation

Welcome to the Moltbot documentation. This directory contains guides for use cases, deployment options, security, community applications, and cost information.

## Quick Links

### Getting Started
- **[Official Documentation](https://docs.molt.bot/start/getting-started)** - Complete getting started guide
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
├── COST_EXPECTATIONS.md           (pricing information)
└── use-cases-and-deployment.md    (legacy combined file - deprecated)
```

For the canonical combined reference, see [use-cases-and-deployment.md](./use-cases-and-deployment.md).
