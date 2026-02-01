# Contributing to OpenClaw Deployment

Thank you for your interest in contributing to the OpenClaw deployment repository. This guide covers how to get started, the development workflow, and project conventions.

## Repository Scope

This repository contains **deployment scripts, CI/CD workflows, and documentation** for running [OpenClaw](https://openclaw.ai) on Linux VPS. It does not contain the OpenClaw application itself (which is installed via npm).

Key areas you can contribute to:

- **Deployment scripts** (`deploy/`) — Bash scripts for installing, updating, and managing OpenClaw
- **CI/CD workflows** (`.github/workflows/`) — GitHub Actions for automated deployment and linting
- **Documentation** (`docs/`, `README.md`) — Guides, use cases, and reference material

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/moltbot.git
   cd moltbot
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b your-branch-name
   ```

## Development Guidelines

### Bash Scripts

All deployment scripts live in `deploy/` and must pass [ShellCheck](https://www.shellcheck.net/) at warning severity.

- Source the shared library for logging and utilities:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/lib.sh"
  ```
- Use `log_info`, `log_success`, `log_warn`, and `log_error` from `deploy/lib.sh` for output
- Use `require_root` to enforce root privileges where needed
- Use `validate_port` for port number validation
- Quote variables and use `set -euo pipefail` at the top of scripts
- Support both Debian/Ubuntu and RHEL-family distributions where applicable

### GitHub Actions Workflows

Workflows in `.github/workflows/` must pass [actionlint](https://github.com/rhysd/actionlint) and [yamllint](https://github.com/adrienverge/yamllint).

- Pin actions to full commit SHAs with a version comment (e.g., `uses: actions/checkout@<sha> # v4`)
- Keep YAML lines under 200 characters

### Documentation

- Use standard Markdown (GitHub-flavored)
- Place detailed guides in `docs/` and link them from `docs/README.md`
- Keep the top-level `README.md` focused on quick start and essential reference

## Linting

The CI pipeline runs three linters on every push to `main` and on all pull requests:

| Linter | Scope | What it checks |
|--------|-------|----------------|
| **ShellCheck** | `deploy/*.sh` | Bash script correctness and best practices |
| **actionlint** | `.github/workflows/` | GitHub Actions workflow syntax |
| **yamllint** | All `.yml` files | YAML formatting (200-char line limit) |

Run ShellCheck locally before submitting:

```bash
shellcheck deploy/*.sh
```

## Submitting Changes

1. **Ensure linters pass** — ShellCheck, actionlint, and yamllint must all pass
2. **Write clear commit messages** — Use conventional commits format (see below)
3. **Open a pull request** against `main` with a description of what changed and why
4. **Keep PRs focused** — One logical change per pull request

## Conventional Commits

This repository uses **conventional commits** for clear, automated release versioning. Format your commits as:

```
<type>: <description>

[optional body]

[optional footer]
```

### Commit Types

| Type | Bumps | Purpose |
|------|-------|---------|
| `feat:` | MINOR | New deployment script, new workflow capability, new feature |
| `fix:` | PATCH | Bug fixes, security hardening, script improvements |
| `docs:` | — | Documentation updates (README, guides, comments) |
| `chore:` | — | Config updates, dependency updates, no code changes |
| `ci:` | — | GitHub Actions workflow changes, CI/CD improvements |
| `refactor:` | — | Code restructuring without changing behavior |
| `test:` | — | Adding or updating tests, linting improvements |

### Examples

**Feature:**
```
feat: add systemd hardening for openclaw service

- Add ProtectSystem=strict
- Add NoNewPrivileges=yes
```

**Bug Fix:**
```
fix: prevent OOM kill during npm install on low-memory VPS

Increase temporary swap file size from 1GB to 2GB
```

**Documentation:**
```
docs: clarify deployment steps in README
```

**Breaking Change:**

For breaking changes, use `BREAKING CHANGE:` footer or suffix the type with `!`:

```
feat!: rewrite deploy.sh with new structure

BREAKING CHANGE: The systemd service file format has changed
```

or

```
feat!: change openclaw user directory structure
```

See [RELEASING.md](RELEASING.md) for more details on versioning and releases.

## Reporting Issues

If you find a bug or have a suggestion, please [open an issue](https://github.com/openclaw/openclaw-deploy/issues) with:

- A clear title describing the problem
- Steps to reproduce (if applicable)
- Your environment (OS, Node.js version, RAM)
- Relevant logs (`sudo journalctl -u openclaw-gateway -n 50`)

## Testing Changes

Since this repository contains deployment scripts (not application code), testing typically involves:

- **Linting**: Run ShellCheck on modified scripts
- **Manual testing**: Test scripts on a fresh Ubuntu 24.04 VPS or VM (1-4 GB RAM)
- **CI verification**: Push to your fork and verify GitHub Actions pass

## Security

If you discover a security vulnerability, please report it responsibly. Do **not** open a public issue. Instead, contact the maintainer directly.

See [docs/SECURITY.md](docs/SECURITY.md) for the project's security model and hardening recommendations.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
