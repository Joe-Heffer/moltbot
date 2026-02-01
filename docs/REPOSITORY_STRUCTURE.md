# Repository Structure

Overview of files and directories in the OpenClaw deployment repository.

## Directory Tree

```
moltbot/
├── deploy/                         # Deployment scripts
│   ├── deploy.sh                   # Main idempotent deployment script
│   ├── uninstall.sh                # Removal script
│   ├── setup-server.sh             # One-time CI/CD server preparation
│   ├── configure-fallbacks.sh      # AI provider fallback configuration
│   ├── lib.sh                      # Shared library (logging, validation)
│   ├── openclaw-gateway.service     # Systemd service template
│   ├── openclaw.env.template        # Environment variable template
│   └── openclaw.fallbacks.json      # AI provider fallback configuration template
│
├── .github/
│   └── workflows/
│       ├── deploy.yml              # GitHub Actions: deploy to VPS
│       ├── release.yml             # GitHub Actions: semantic versioning
│       └── lint.yml                # GitHub Actions: code quality checks
│
├── docs/                           # Extended documentation
│   ├── README.md                   # Documentation hub and navigation
│   ├── QUICK_START.md              # Deployment quick start
│   ├── CONFIGURATION.md            # AI providers, env vars, onboarding
│   ├── SERVICE_MANAGEMENT.md       # systemctl commands, monitoring
│   ├── GITHUB_ACTIONS_DEPLOYMENT.md # CI/CD setup and workflows
│   ├── DEPLOYMENT.md               # Multi-platform deployment options
│   ├── LOW_MEMORY_VPS.md           # Low-memory VPS optimization
│   ├── REPOSITORY_STRUCTURE.md     # This file
│   ├── PUBLIC_VS_PRIVATE.md        # Public/private repo considerations
│   ├── GATEWAY_UI.md               # Gateway web interface setup
│   ├── SECURITY.md                 # Security hardening checklist
│   ├── TROUBLESHOOTING.md          # Common issues and fixes
│   ├── USE_CASES.md                # Real-world applications
│   ├── COST_EXPECTATIONS.md        # Pricing and budget planning
│   ├── COMMUNITY_APPLICATIONS.md   # Community examples
│   ├── TELEGRAM_SETUP.md           # Telegram bot setup
│   └── WHATSAPP_LEGAL.md           # WhatsApp Terms of Service
│
├── README.md                       # Main project overview and quick start
├── CONTRIBUTING.md                 # Contribution guidelines
├── RELEASING.md                    # Release versioning and process
├── CLAUDE.md                       # AI assistant context (this file)
├── VERSION                         # Current semantic version (e.g., 0.1.0)
├── LICENSE                         # MIT License
└── .gitignore                      # Git ignore rules
```

## Core Files

### Deployment Scripts (`deploy/`)

#### `deploy.sh`
**Primary deployment script — idempotent, safe to run multiple times.**

Performs:
1. Installs system dependencies (curl, git, gcc, Node.js)
2. Installs Node.js 22 via NodeSource
3. Creates dedicated `openclaw` system user
4. Installs/updates moltbot via npm
5. Generates systemd service from template
6. Configures AI provider fallbacks
7. Restarts service if already running; prints onboarding instructions on first install

**Usage:**
```bash
sudo ./deploy/deploy.sh
```

**Idempotent**: Safe to run for both first-time installation and subsequent updates.

#### `uninstall.sh`
Completely removes OpenClaw from the system.

**Usage:**
```bash
sudo ./deploy/uninstall.sh
```

Removes:
- moltbot npm package
- moltbot system user
- systemd service
- Configuration files

#### `setup-server.sh`
One-time VPS preparation for GitHub Actions CI/CD deployments.

**Usage:**
```bash
sudo ./deploy/setup-server.sh
```

Creates:
- `deploy` user with limited sudo privileges
- SSH directory for deployment key
- Sudoers entries for deployment commands

Required before setting up GitHub Actions CI/CD.

#### `configure-fallbacks.sh`
Applies AI provider fallback configuration from `openclaw.fallbacks.json`.

**Usage:**
```bash
sudo /opt/openclaw-deployment/deploy/configure-fallbacks.sh
```

Converts fallback JSON into gateway configuration.

#### `lib.sh`
Shared Bash library sourced by deployment scripts.

Provides:
- Logging functions (`log_info`, `log_success`, `log_warn`, `log_error`)
- Validation functions (`require_root`, `validate_port`)
- Memory detection and tuning (`detect_ram`, `calculate_memory_limits`)
- Cross-distro support (Debian/Ubuntu, RHEL/CentOS)

Not run directly; sourced by other scripts.

#### `openclaw-gateway.service`
Systemd service template for running OpenClaw as a background service.

Features:
- Runs as dedicated `openclaw` user (non-root)
- Security hardening: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=read-only`
- Memory and CPU limits based on detected RAM
- Automatic restart on failure
- Service dependencies (after network is online)

Deployed to `/etc/systemd/system/openclaw-gateway.service` by `deploy.sh`.

#### `openclaw.env.template`
Template for environment variables.

Copy and configure:
```bash
sudo -u openclaw cp /home/openclaw/.config/openclaw/openclaw.env.template /home/openclaw/.config/openclaw/.env
sudo -u openclaw nano /home/openclaw/.config/openclaw/.env
```

Includes settings for:
- AI provider API keys (Anthropic, OpenAI, Gemini)
- Gateway port and proxy configuration
- Channel tokens (Telegram, Discord, Slack, etc.)
- DM policy (pairing vs. open)
- Resource limits (memory, Node.js heap)

#### `openclaw.fallbacks.json`
Template for AI provider fallback configuration.

Defines:
- Provider priority order
- Model selection per provider
- Timeout and retry behavior

Customized and applied by `configure-fallbacks.sh`.

## GitHub Actions Workflows (`.github/workflows/`)

### `deploy.yml`
Automated deployment to VPS via SSH.

**Triggers:**
- Push to `main` branch in `deploy/` directory
- Manual trigger via GitHub Actions UI

**Actions:**
- `deploy` — Install or update, regenerate configuration
- `restart` — Restart the gateway service

**Features:**
- Deployment tracking in GitHub Environments
- Health checks post-deploy
- Concurrency control (one deploy at a time)
- Version tracking (`/opt/openclaw-version` on VPS)

See [GitHub Actions Deployment Guide](./GITHUB_ACTIONS_DEPLOYMENT.md).

### `release.yml`
Automated semantic versioning and GitHub Releases.

**Triggers:**
- Manual workflow dispatch with version bump type (major, minor, patch)
- Automatically analyzes commits since last release

**Process:**
1. Analyzes conventional commit messages (feat, fix, etc.)
2. Determines version bump (major/minor/patch)
3. Updates `VERSION` file
4. Creates git tag
5. Generates GitHub Release with commit history

See [RELEASING.md](../RELEASING.md) for details.

### `lint.yml`
Code quality checks on every push and pull request.

**Checks:**
- `shellcheck` — Bash script linting
- `actionlint` — GitHub Actions workflow validation
- `yamllint` — YAML linting with 200-char line limit

## Documentation Structure

### Navigation Hub
- **`docs/README.md`** — Quick links to all documentation, deployment quick start table, community resources

### Getting Started
- **`docs/QUICK_START.md`** — Minimal steps to deploy and configure
- **`docs/DEPLOYMENT.md`** — Multi-platform deployment options

### Operation & Management
- **`docs/CONFIGURATION.md`** — AI providers, environment variables, onboarding
- **`docs/SERVICE_MANAGEMENT.md`** — systemctl commands, monitoring, troubleshooting
- **`docs/GITHUB_ACTIONS_DEPLOYMENT.md`** — CI/CD setup and workflows
- **`docs/LOW_MEMORY_VPS.md`** — Optimization for limited RAM systems

### Architecture & Planning
- **`docs/REPOSITORY_STRUCTURE.md`** — This file
- **`docs/DEPLOYMENT.md`** — Architecture overview for different platforms

### Security & Hardening
- **`docs/SECURITY.md`** — Hardening checklist and best practices
- **`docs/PUBLIC_VS_PRIVATE.md`** — Repository visibility considerations

### Setup Guides
- **`docs/GATEWAY_UI.md`** — Web interface access and authentication
- **`docs/TELEGRAM_SETUP.md`** — Telegram bot configuration
- **`docs/WHATSAPP_LEGAL.md`** — WhatsApp Terms of Service and unofficial risks

### Reference & Context
- **`docs/USE_CASES.md`** — Real-world applications and workflows
- **`docs/COST_EXPECTATIONS.md`** — Pricing and budget planning
- **`docs/COMMUNITY_APPLICATIONS.md`** — Community examples and integrations
- **`docs/TROUBLESHOOTING.md`** — Common issues and solutions

### Root Documentation
- **`README.md`** — Main project overview, quick start, key information
- **`CONTRIBUTING.md`** — Contribution guidelines, conventional commit format
- **`RELEASING.md`** — Semantic versioning and release process
- **`CLAUDE.md`** — AI assistant context and development conventions
- **`VERSION`** — Current semantic version (e.g., `0.1.0`)
- **`LICENSE`** — MIT License

## Key Concepts

### Idempotent Deployment
`deploy.sh` is designed to be run multiple times safely:
- First run: installs everything
- Subsequent runs: updates npm package, regenerates systemd service, restarts service

This enables both:
- Manual updates via `sudo ./deploy/deploy.sh`
- Automated updates via GitHub Actions

### Security Model
- **Non-root execution**: OpenClaw runs as `openclaw` user, not root
- **Systemd hardening**: `NoNewPrivileges`, `ProtectSystem`, `ProtectHome` prevent privilege escalation
- **Memory/CPU limits**: Resource constraints prevent runaway processes
- **Dedicated user**: Isolates OpenClaw from other system services

### Configuration Management
- **Environment variables**: Stored in `.env`, loaded by systemd service
- **Fallback configuration**: JSON format, applied by `configure-fallbacks.sh`
- **Systemd service template**: Generated from `openclaw-gateway.service` with substituted values

### Supported Distributions
- **Debian/Ubuntu** — Primary target (Ubuntu 24.04 LTS)
- **RHEL/CentOS** — Community supported
- **Oracle Linux** — Community supported

Scripts detect and adapt to different package managers (apt, dnf, yum).

## Development Conventions

### Bash Scripts
- Use `set -euo pipefail` for safety
- Source `lib.sh` for logging and utilities
- Support Debian/Ubuntu and RHEL families
- Shellcheck-compliant

### Commit Messages
Follow [conventional commits](../CONTRIBUTING.md):
- `feat:` → MINOR version bump
- `fix:` → PATCH version bump
- `docs:`, `chore:`, `ci:` → no version bump
- `BREAKING CHANGE:` → MAJOR version bump

### YAML/Workflow Files
- Pin GitHub Actions to full commit SHAs with version comments
- Keep lines under 200 characters
- Use `actionlint` for validation

### Documentation
- Markdown in `docs/`, linked from `docs/README.md`
- Keep top-level `README.md` focused and concise
- Use cross-links to reduce redundancy

## Related Documentation

- [Quick Start](./QUICK_START.md) — Get up and running
- [Contributing Guidelines](../CONTRIBUTING.md) — How to contribute
- [Release Process](../RELEASING.md) — Versioning and releases
- [AI Assistant Context](../CLAUDE.md) — Development conventions
