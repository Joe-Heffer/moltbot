# Agent Memory Backup

This guide explains how to configure automated backups of your OpenClaw agent's memory and configuration files to prevent data loss.

## Overview

OpenClaw agents learn from interactions and store memories, conversation history, and configuration in several directories:

- `/home/openclaw/clawd` - Legacy agent data
- `/home/openclaw/clawd/memory` - Current agent memory files
- `/home/openclaw/.config/openclaw` - Configuration files
- `/home/openclaw/.local/share/openclaw` - Persistent application data

These files contain valuable context about your preferences, ongoing conversations, and learned information. Backing them up regularly ensures you can restore your agent's memory if the VM is reset or fails.

## Privacy Considerations

**IMPORTANT:** Agent memory files may contain personal information from your conversations. Always use:

- **Private repositories** for Git backups
- **Encrypted storage** for cloud backups
- **Secure access controls** on backup locations

The backup script automatically excludes:
- `.env` files (API keys and secrets)
- `*.log` files
- `*.tmp` files
- `node_modules` directories

## Backup Methods

The backup system supports two methods:

1. **Git Repository** - Backs up to GitHub, GitLab, or any Git server (recommended for version history)
2. **Cloud Storage** - Backs up to any cloud provider via rclone (Google Drive, Dropbox, S3, etc.)

## Setup Instructions

### Option 1: Git Repository Backup (Recommended)

#### 1. Create a Private Repository

Create a **private** repository on GitHub, GitLab, or your preferred Git hosting service:

```bash
# Example: GitHub CLI
gh repo create openclaw-backup --private

# Or create manually at https://github.com/new (ensure it's marked Private)
```

#### 2. Generate SSH Key for Backup Access

Generate an SSH key for the openclaw user:

```bash
sudo -u openclaw ssh-keygen -t ed25519 -C "openclaw-backup" -f /home/openclaw/.ssh/id_ed25519_backup
```

Display the public key:

```bash
sudo -u openclaw cat /home/openclaw/.ssh/id_ed25519_backup.pub
```

#### 3. Add Deploy Key to Repository

Add the public key to your repository's deploy keys with **write access**:

- **GitHub**: `Settings` > `Deploy keys` > `Add deploy key`
- **GitLab**: `Settings` > `Repository` > `Deploy Keys`

Check "Allow write access" when adding the key.

#### 4. Configure SSH for Backup Key

Create SSH config to use the backup key:

```bash
sudo -u openclaw tee -a /home/openclaw/.ssh/config > /dev/null <<'EOF'
Host github.com-backup
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_backup
    IdentitiesOnly yes
EOF

sudo chown openclaw:openclaw /home/openclaw/.ssh/config
sudo chmod 600 /home/openclaw/.ssh/config
```

#### 5. Configure Backup Settings

Copy and edit the backup configuration template:

```bash
sudo cp /home/openclaw/.config/openclaw/backup.conf.template /home/openclaw/.config/openclaw/backup.conf
sudo nano /home/openclaw/.config/openclaw/backup.conf
```

Set the following values:

```bash
# Backup method
BACKUP_METHOD=git

# Git repository URL (using SSH config host)
BACKUP_GIT_REPO=git@github.com-backup:yourusername/openclaw-backup.git

# Branch to use
BACKUP_GIT_BRANCH=main
```

#### 6. Test the Backup

Run a manual backup to verify configuration:

```bash
sudo /opt/openclaw-deployment/deploy/backup-agent-memory.sh
```

Check the output for errors. Verify the backup appears in your Git repository.

#### 7. Enable Automated Backups

Enable the systemd timer to run daily backups at 3:00 AM:

```bash
sudo systemctl enable --now openclaw-backup.timer
```

Check timer status:

```bash
systemctl status openclaw-backup.timer
```

View upcoming backup schedule:

```bash
systemctl list-timers openclaw-backup.timer
```

### Option 2: Cloud Storage Backup (rclone)

#### 1. Install rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

#### 2. Configure Cloud Storage Remote

Run the rclone configuration wizard:

```bash
sudo rclone config
```

Follow the prompts to configure your cloud provider (Google Drive, Dropbox, S3, etc.). Name the remote something like `gdrive` or `dropbox`.

#### 3. Configure Backup Settings

Copy and edit the backup configuration template:

```bash
sudo cp /home/openclaw/.config/openclaw/backup.conf.template /home/openclaw/.config/openclaw/backup.conf
sudo nano /home/openclaw/.config/openclaw/backup.conf
```

Set the following values:

```bash
# Backup method
BACKUP_METHOD=rclone

# Remote and path (format: remote:path)
BACKUP_RCLONE_REMOTE=gdrive:openclaw-backup

# Retention (days to keep old backups)
BACKUP_RETENTION_DAYS=30
```

#### 4. Test the Backup

```bash
sudo /opt/openclaw-deployment/deploy/backup-agent-memory.sh
```

Verify the backup appears in your cloud storage.

#### 5. Enable Automated Backups

```bash
sudo systemctl enable --now openclaw-backup.timer
```

## Managing Backups

### Manual Backup

Trigger an immediate backup:

```bash
sudo systemctl start openclaw-backup.service
```

### Check Backup Logs

View recent backup logs:

```bash
sudo journalctl -u openclaw-backup.service -n 50
```

Follow backup logs in real-time:

```bash
sudo journalctl -u openclaw-backup.service -f
```

### Disable Automated Backups

```bash
sudo systemctl disable --now openclaw-backup.timer
```

### Change Backup Schedule

Edit the timer configuration:

```bash
sudo systemctl edit --full openclaw-backup.timer
```

Modify the `OnCalendar` directive. Examples:

```ini
# Every 6 hours
OnCalendar=00/6:00:00

# Twice daily (3 AM and 3 PM)
OnCalendar=*-*-* 03,15:00:00

# Weekly on Sundays at 2 AM
OnCalendar=Sun *-*-* 02:00:00
```

Reload systemd after changes:

```bash
sudo systemctl daemon-reload
```

## Restoring from Backup

### Git Repository Restore

```bash
# Stop the service
sudo systemctl stop openclaw-gateway

# Clone the backup repository
sudo -u openclaw git clone YOUR_BACKUP_REPO_URL /tmp/restore

# Restore files (example for memory directory)
sudo -u openclaw rsync -av /tmp/restore/clawd/memory/ /home/openclaw/clawd/memory/
sudo -u openclaw rsync -av /tmp/restore/.openclaw/ /home/openclaw/clawd/
sudo -u openclaw rsync -av /tmp/restore/.config/openclaw/ /home/openclaw/.config/openclaw/

# Clean up
sudo rm -rf /tmp/restore

# Start the service
sudo systemctl start openclaw-gateway
```

### Cloud Storage Restore

```bash
# Stop the service
sudo systemctl stop openclaw-gateway

# Download latest backup (adjust remote path as needed)
sudo rclone sync gdrive:openclaw-backup/latest /tmp/restore

# Restore files
sudo -u openclaw rsync -av /tmp/restore/clawd/memory/ /home/openclaw/clawd/memory/
sudo -u openclaw rsync -av /tmp/restore/.openclaw/ /home/openclaw/clawd/
sudo -u openclaw rsync -av /tmp/restore/.config/openclaw/ /home/openclaw/.config/openclaw/

# Clean up
sudo rm -rf /tmp/restore

# Start the service
sudo systemctl start openclaw-gateway
```

## Troubleshooting

### "Backup configuration not found" Error

**Cause:** The `backup.conf` file hasn't been created.

**Fix:** Copy and configure the template:

```bash
sudo cp /home/openclaw/.config/openclaw/backup.conf.template /home/openclaw/.config/openclaw/backup.conf
sudo nano /home/openclaw/.config/openclaw/backup.conf
```

### Git Push Permission Denied

**Cause:** SSH key not added to repository or wrong permissions.

**Fix:**

1. Verify the public key is added as a deploy key with write access
2. Test SSH connection:
   ```bash
   sudo -u openclaw ssh -T git@github.com-backup
   ```

### Rclone Command Not Found

**Cause:** rclone not installed.

**Fix:**

```bash
curl https://rclone.org/install.sh | sudo bash
```

### Backup Service Fails to Start

Check the service logs:

```bash
sudo journalctl -u openclaw-backup.service -n 50 --no-pager
```

Common issues:
- Missing `backup.conf` file
- Invalid Git URL or SSH key
- rclone remote not configured

## Security Best Practices

1. **Use Private Repositories**: Never use public repositories for backups
2. **Encrypt Sensitive Data**: Consider using git-crypt or encrypted rclone remotes
3. **Rotate SSH Keys**: Periodically regenerate deploy keys
4. **Review Backup Contents**: Verify no unintended files are included
5. **Access Control**: Limit who has access to backup repositories/storage
6. **Monitor Backup Logs**: Regularly check that backups are succeeding

## Related Documentation

- [Deployment Guide](DEPLOYMENT.md)
- [Security Hardening](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
