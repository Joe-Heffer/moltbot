# VPS Backup Checklist

**Before wiping your VPS**, back up these files to preserve your OpenClaw/Moltbot deployment configuration and data.

## Critical Priority: Agent Memory & Data

These contain your agent's learned context and conversation history:

- **`/home/moltbot/.clawdbot/`** - Legacy agent memory and data
- **`/home/moltbot/clawd/memory/`** - Current agent memory files (MOST IMPORTANT)
- **`/home/moltbot/.local/share/moltbot/`** - Persistent application data

## High Priority: Configuration & Secrets

⚠️ **Security Note**: Contains API keys and tokens. Store securely with encryption.

- **`/home/moltbot/.config/moltbot/.env`** - All API keys and channel tokens (mode 600)
  - ANTHROPIC_API_KEY
  - OPENAI_API_KEY
  - GEMINI_API_KEY
  - OPENROUTER_API_KEY
  - Channel tokens (TELEGRAM_BOT_TOKEN, DISCORD_TOKEN, SLACK_BOT_TOKEN, etc.)
  - Gateway auth token
- **`/home/moltbot/.config/moltbot/backup.conf`** - Backup configuration (if exists)
- **`/home/moltbot/.config/moltbot/moltbot.fallbacks.json`** - Custom AI provider fallback config (if modified)
- **`/home/moltbot/.moltbot/moltbot.json`** - Gateway auth token and application state

## Medium Priority: User Environment

Shell configuration and SSH keys:

- **`/home/moltbot/.bashrc`** - Shell aliases and npm PATH
- **`/home/moltbot/.profile`** - Login shell config and npm PATH
- **`/home/moltbot/.npmrc`** - npm prefix configuration
- **`/home/moltbot/.ssh/`** - SSH keys and config (if using Git backups)
  - `/home/moltbot/.ssh/id_ed25519_backup` - Private key for backup repository (CRITICAL)
  - `/home/moltbot/.ssh/id_ed25519_backup.pub` - Public key
  - `/home/moltbot/.ssh/config` - SSH config

## Optional: System Configuration

- **`/etc/systemd/system/moltbot-gateway.service`** - Main service file
- **`/etc/systemd/system/moltbot-backup.service`** - Backup service (if installed)
- **`/etc/systemd/system/moltbot-backup.timer`** - Backup timer (if installed)
- **`/opt/moltbot-version`** - Deployed version tracking

## Optional: Cache & Logs

- **`/home/moltbot/.moltbot-backup-repo/`** - Backup repository cache (speeds up future backups)
- **Service logs** (export recent history):

```bash
sudo journalctl -u moltbot-gateway --since "30 days ago" > moltbot-gateway.log
sudo journalctl -u moltbot-backup.service --since "30 days ago" > moltbot-backup.log
```

## Quick Backup Command

Create a complete backup archive:

```bash
sudo tar -czf vps-moltbot-backup-$(date +%Y%m%d).tar.gz \
  /home/moltbot/.clawdbot \
  /home/moltbot/clawd/memory \
  /home/moltbot/.config/moltbot/ \
  /home/moltbot/.local/share/moltbot/ \
  /home/moltbot/.moltbot/ \
  /home/moltbot/.ssh/ \
  /home/moltbot/.npmrc \
  /home/moltbot/.bashrc \
  /home/moltbot/.profile \
  /etc/systemd/system/moltbot-gateway.service \
  /etc/systemd/system/moltbot-backup.* \
  /opt/moltbot-version \
  2>/dev/null

# Download to your local machine
scp user@your-vps:/path/to/vps-moltbot-backup-*.tar.gz ./
```

## What NOT to Backup

These can be reinstalled or recreated:

- `/home/moltbot/.npm-global/node_modules/` - Large, reinstalled via npm
- `/home/linuxbrew/` - Very large, can be reinstalled
- `/var/tmp/moltbot-install.swap` - Temporary swap file
- Systemd journal logs - Recreated automatically

## Important Restoration Notes

### File Permissions

When restoring, maintain these permissions:

```bash
# Ownership
sudo chown -R moltbot:moltbot /home/moltbot/

# Critical permissions
sudo chmod 700 /home/moltbot/.clawdbot
sudo chmod 700 /home/moltbot/clawd
sudo chmod 700 /home/moltbot/.ssh
sudo chmod 600 /home/moltbot/.config/moltbot/.env
sudo chmod 600 /home/moltbot/.ssh/id_ed25519_backup
```

### Directory Requirements

For security, these MUST be real directories (not symlinks):

- `/home/moltbot/.clawdbot/`
- `/home/moltbot/clawd/`

### After Restoration

1. Deploy OpenClaw using the scripts in this repository
2. Stop the service: `sudo systemctl stop moltbot-gateway`
3. Restore backed-up files to their original locations
4. Fix permissions (see above)
5. Start the service: `sudo systemctl start moltbot-gateway`
6. Verify: `sudo systemctl status moltbot-gateway`

## Automated Backups (Recommended)

Before wiping, check if automated backups are configured:

```bash
# Check if backup timer is enabled
sudo systemctl status moltbot-backup.timer

# Check last backup
ls -lh /home/moltbot/.moltbot-backup-repo/

# Manual backup run
sudo systemctl start moltbot-backup.service
```

If you have Git-based backups configured, your agent memory may already be safely backed up to a remote repository.
