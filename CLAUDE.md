# CLAUDE.md

This file provides context for AI assistants working on this repository.

## Project Overview

Moltbot deployment repository — Bash scripts, CI/CD workflows, and documentation for running [Moltbot](https://molt.bot) on Linux VPS. This repo does **not** contain the Moltbot application itself (installed via `npm install -g moltbot`).

## Repository Structure

```
deploy/               Bash deployment scripts
  install.sh          Full installation (OS deps, Node.js, user, npm, systemd, firewall)
  update.sh           CI/CD update script
  uninstall.sh        Removal script
  setup-server.sh     One-time CI/CD server preparation
  lib.sh              Shared library (logging, root check, port validation, swap helpers)
  moltbot-gateway.service  Systemd service template
  moltbot.env.template     Environment variable template

.github/workflows/
  deploy.yml          GitHub Actions: deploy to VPS via SSH
  lint.yml            GitHub Actions: ShellCheck, actionlint, yamllint

docs/                 Extended documentation (use cases, deployment, security, costs)
README.md             Quick start and reference
CONTRIBUTING.md       Contribution guidelines
LICENSE               MIT License
```

## Key Commands

### Linting (CI runs these on every push/PR)

```bash
shellcheck deploy/*.sh          # Bash linting (warning severity)
actionlint                      # GitHub Actions workflow validation
yamllint .                      # YAML linting (200-char line limit)
```

There is no build step or test suite — this is a scripts-and-docs repository.

## Development Conventions

- **Bash scripts**: Use `set -euo pipefail`. Source `deploy/lib.sh` for logging (`log_info`, `log_success`, `log_warn`, `log_error`) and utilities (`require_root`, `validate_port`). Support Debian/Ubuntu and RHEL-family.
- **GitHub Actions**: Pin actions to full commit SHAs with version comments.
- **YAML**: Lines under 200 characters. yamllint config extends `default` with relaxed `truthy` and `comments` rules.
- **Commit messages**: Imperative mood, concise, contextual (e.g., "Fix OOM kill during npm install on low-memory VPS").
- **Documentation**: Markdown in `docs/`, linked from `docs/README.md`. Keep top-level `README.md` focused.

## Architecture Notes

- **Target OS**: Ubuntu 24.04 LTS (also supports RHEL/Oracle Linux)
- **Node.js**: v22 via NodeSource
- **System user**: `moltbot` (non-root, created by installer)
- **Service**: `moltbot-gateway` systemd unit on port 18789
- **Security**: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=read-only`, dedicated user
- **Low-memory**: Auto-tunes `MemoryMax` and `--max-old-space-size`; temporary swap for installs on <4 GB RAM; minimum 2 GB RAM enforced by installer

## Official Documentation Links

For solving problems and understanding OpenClaw/Moltbot features, refer to the official documentation:

### Core Resources
- **[OpenClaw Documentation](https://docs.openclaw.ai/)** — Main documentation hub (index, architecture, configuration reference)
- **[OpenClaw GitHub](https://github.com/openclaw/openclaw)** — Source code, issues, and discussions
- **[OpenClaw Website](https://openclaw.ai/)** — Product overview and features

### Relevant Documentation Sections
- **[Gateway UI Guide](https://docs.openclaw.ai/)** — Browser control panel (chat, config, nodes, sessions)
- **[Channel Configuration](https://docs.openclaw.ai/)** — WhatsApp, Telegram, Discord, Slack, Signal, iMessage, Teams, Matrix, and other channel setup
- **[Installation & Onboarding](https://docs.openclaw.ai/)** — Global npm install, configuration, service management
- **[Architecture Overview](https://docs.openclaw.ai/)** — Gateway + protocol model, design patterns
- **[Configuration Reference](https://docs.openclaw.ai/)** — Complete environment variables and settings

### Related Deployment Guides
- **[README.md](README.md)** — Quick start and deployment instructions
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** — Multi-platform deployment options
- **[docs/SECURITY.md](docs/SECURITY.md)** — Security hardening and risk assessment
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — Common issues and solutions
