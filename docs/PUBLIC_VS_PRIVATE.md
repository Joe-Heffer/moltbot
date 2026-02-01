# Public vs. Private Repository

Should you make your deployment repository public or keep it private? This guide outlines the trade-offs.

## Quick Answer

**If you use this repo as-is**: Public is fine.

**If you customize it with server-specific details**: Keep it private or gitignore customizations.

## Why This Repository is Safe to Make Public

### No Secrets in the Repository

- ✓ All credentials (API keys, SSH keys, hostnames) live in **`.env` files** (excluded by `.gitignore`)
- ✓ GitHub Actions secrets are encrypted and not stored in the repo
- ✓ The `.env.template` contains only empty placeholders
- ✓ No hardcoded credentials anywhere in the code

### Standard Security Practices

The deployment patterns here are **standard Linux/systemd hardening**:
- Non-root service user (`moltbot`)
- Systemd sandbox constraints (`NoNewPrivileges`, `ProtectSystem`, `ProtectHome`)
- SSH-based CI/CD with limited sudo privileges
- Dedicated service port (18789)

These practices are widely documented and don't become less secure by being public.

### Community Benefit

Making the repository public:
- Allows others to reuse and improve the scripts
- Invites bug reports and security audits
- Enables community contributions
- Helps the OpenClaw ecosystem

### Security Through Implementation, Not Obscurity

Hiding the deployment architecture does **not** make your server safer. A properly configured server is secure regardless of whether someone knows the pattern. Conversely, a misconfigured public repo cannot be made secure by making it private.

## When to Keep It Private

### Reasons to Keep It Private

1. **Reduce reconnaissance surface**
   - A public repo reveals your stack: CI/CD tooling, systemd setup, sudoers policy, port numbers
   - An attacker can tailor reconnaissance knowing your patterns
   - Note: This is "security through obscurity" — not a strong defense, but adds friction

2. **Operational privacy**
   - If you prefer not to publicly link your GitHub account to a running service
   - If you want to keep your infrastructure setup confidential

3. **Fork-specific customizations**
   - If your fork includes server-specific details (IP ranges, internal hostnames, custom firewall rules)
   - If you modify the scripts for your infrastructure

### Example: When to Make a Fork Private

```bash
# KEEP PUBLIC: Generic deployment scripts
# ✓ Git clone, run deploy.sh, done

# MAKE PRIVATE: If you add to your fork
# ✗ IP allowlists hardcoded in scripts
# ✗ Internal hostname/FQDN references
# ✗ Custom firewall rules specific to your network
# ✗ Server-specific directory paths
# ✗ Credentials in gitignored files but occasionally leaked
```

## Recommendations by Use Case

### Individual Deployment (Your Own VPS)
**Recommendation: Public**

You're using the repo as-is without modifications. Making it public:
- Helps others deploying OpenClaw
- Allows community to spot issues
- Adds no security risk since no secrets are stored

### Organization/Team Deployment
**Recommendation: Private (or public with gitignored customizations)**

If your fork includes:
- Server names, IP ranges, or internal hostnames
- Custom monitoring/alerting setup
- Org-specific environment variables

Keep the fork private and manage customizations in:
- `.env` files (already gitignored)
- Separate configuration branches
- Environment-specific overlays

### Open-Source Project
**Recommendation: Public**

If you're publishing a deployment project for the community:
- Public repo is expected and beneficial
- Ensure no secrets in code (use `.env` and `.gitignore`)
- Document security practices in README and SECURITY.md

## Protecting Sensitive Information

Regardless of public/private status, follow these practices:

### 1. Use `.gitignore` for Secrets
```bash
# Already excluded:
.env
.env.local
.env.*.local
node_modules/
.DS_Store
```

Never commit:
- API keys or tokens
- SSH private keys
- Credentials or passwords
- Personal information

### 2. Code Review Before Push
```bash
git diff origin/main..HEAD
```

Ensure no secrets are in staging before pushing.

### 3. Check Git History
```bash
# Search for common secret patterns
git log -p --all -S 'sk-ant-' -- '*.env'
git log -p --all -S 'ANTHROPIC_API_KEY' -- '*.env'
```

### 4. Credential Scanning Tools
Use pre-commit hooks to scan before commits:

```bash
# Install git-secrets (macOS/Linux)
brew install git-secrets
git secrets --install
git secrets --register-aws
```

Or use GitHub's native secret scanning (public repos only).

## GitHub Secret Scanning

**Public repositories only**: GitHub automatically scans for leaked credentials.

If you accidentally commit a secret to a public repo:
1. GitHub will alert you
2. The credential is likely compromised — rotate it immediately
3. Remove the secret and force-push (carefully):
   ```bash
   git filter-branch --tree-filter 'rm -rf .env' HEAD
   git push --force-with-lease
   ```

## Making a Private Repo Public

If you're currently private and want to go public:

1. **Audit the entire history** for secrets:
   ```bash
   # Search for common patterns
   git log -p --all -S 'ANTHROPIC_API_KEY'
   git log -p --all -S 'sk-ant-'
   git log -p --all -S 'sk-'  # OpenAI keys
   ```

2. **Clean secrets if found**:
   - If a secret was committed, you must rotate it
   - Use `git filter-branch` or `git-filter-repo` to rewrite history
   - Force-push with team coordination

3. **Document security practices** in SECURITY.md

4. **Enable GitHub Secret Scanning** (public repos automatically get this)

## Making a Public Repo Private

If you're currently public and want to go private:

1. Change visibility in `Settings > General > Danger Zone`
2. No cleanup needed (private repos don't use secret scanning)
3. Update any external links or references

## Trade-Offs Summary

| Aspect | Public | Private |
|--------|--------|---------|
| **Community benefit** | High | Low |
| **Security risk** | Low (if no secrets) | None |
| **Obscurity** | None | Adds friction |
| **Maintenance** | Easier (community PRs) | More work |
| **Visibility** | Everyone can see | Only team can see |
| **Secret safety** | Must be careful | More forgiving but still important |

## Related Documentation

- [Security Hardening Guide](./SECURITY.md) — Best practices for production
- [Quick Start](./QUICK_START.md) — Getting started
- [Contributing Guidelines](../CONTRIBUTING.md) — How to contribute

## Questions?

For security concerns, see the [Security Guide](./SECURITY.md) or contact the OpenClaw maintainers on [GitHub Discussions](https://github.com/openclaw/openclaw/discussions).
