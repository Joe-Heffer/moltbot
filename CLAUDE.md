# CLAUDE.md

Project-specific instructions for AI assistants working on this repository.

## Project Overview

OpenClaw deployment repository — Bash scripts, CI/CD workflows, and documentation for running [OpenClaw](https://openclaw.ai) on Linux VPS. This repo does **not** contain the OpenClaw application itself (installed via `npm install -g openclaw`).

**Repository type**: Scripts and documentation only (no build step, no test suite).

## Finding Your Way Around

- **Deployment scripts**: `deploy/` directory contains all bash scripts and systemd templates
- **CI/CD workflows**: `.github/workflows/` for GitHub Actions
- **Documentation**: Extended guides in `docs/` directory
- **Key files**: `@README.md` for quick start, `@CONTRIBUTING.md` for commit format, `@RELEASING.md` for versioning process

## Key Commands

### Linting (CI runs these on every push/PR)

```bash
shellcheck deploy/*.sh          # Bash linting (warning severity)
actionlint                      # GitHub Actions workflow validation
yamllint .                      # YAML linting (200-char line limit)
```

There is no build step or test suite — this is a scripts-and-docs repository.

## Development Conventions

### Bash Scripts
- ALWAYS use `set -euo pipefail` at the top of scripts
- Source `deploy/lib.sh` for logging functions (`log_info`, `log_success`, `log_warn`, `log_error`) and utilities (`require_root`, `validate_port`)
- Must support both Debian/Ubuntu and RHEL-family distributions
- Never hardcode paths that vary across distributions — use detection logic

### GitHub Actions
- Pin actions to **full commit SHAs** with version comments (e.g., `uses: actions/checkout@a1b2c3d4 # v4.1.0`)
- NEVER use mutable tags like `@v4` or `@main`

### YAML
- Lines under 200 characters
- yamllint config extends `default` with relaxed `truthy` and `comments` rules

### Commit Messages (CRITICAL for versioning)
Use **conventional commits** format — automated release process depends on this:
- `feat:` → MINOR version bump
- `fix:` → PATCH version bump
- `docs:`, `chore:`, `ci:` → no version bump
- `BREAKING CHANGE:` in footer or `!` suffix → MAJOR version bump
- See `@CONTRIBUTING.md` and `@RELEASING.md` for details

### Documentation
- Extended documentation goes in `docs/` directory
- Keep `README.md` focused on quick start and deployment
- Link to detailed guides rather than duplicating content

## Versioning & Releases

**Semantic versioning** (MAJOR.MINOR.PATCH) starting at 0.1.0:

- **VERSION file**: Single source of truth (`0.1.0`)
- **Git tags**: Format `v0.1.0`, `v0.2.0`, etc.
- **Release workflow**: `.github/workflows/release.yml` automates releases:
  - Analyzes commits since last release (conventional commit format required)
  - Auto-detects version bump type
  - Updates VERSION file, creates git tag, generates GitHub Release
- **Deployment tracking**: VERSION stored at `/opt/openclaw-version` on deployed VPS
- **PR workflow**: ALWAYS use "squash and merge" to keep release history clean

See `@RELEASING.md` for complete release process.

## Deployment Architecture

**Target environment**: Ubuntu 24.04 LTS (RHEL/Oracle Linux also supported)

**Critical deployment details**:
- Node.js v22 via NodeSource repositories
- Dedicated `openclaw` system user (non-root, created by deploy script)
- Service runs as `openclaw-gateway` systemd unit on port 18789
- Hardened systemd security: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=read-only`
- Low-memory optimization: auto-tunes `MemoryMax` and `--max-old-space-size`; creates temporary swap on <4GB RAM; **minimum 2GB RAM required**

## Where to Find Information

**For OpenClaw features and troubleshooting**, use progressive disclosure:
- Primary: [OpenClaw Documentation](https://docs.openclaw.ai/) — architecture, configuration, channels
- Source: [OpenClaw GitHub](https://github.com/openclaw/openclaw) — issues, discussions, source code
- Product: [OpenClaw Website](https://openclaw.ai/) — overview and features

**For deployment questions**, check these files first:
- `@README.md` — Quick start and deployment instructions
- `@docs/DEPLOYMENT.md` — Multi-platform deployment options
- `@docs/SECURITY.md` — Security hardening and risk assessment
- `@docs/TROUBLESHOOTING.md` — Common issues and solutions

When uncertain about how something works, explore the codebase or documentation before making assumptions.
