# GitHub Actions CI/CD Deployment

Automatically deploy OpenClaw to your VPS using GitHub Actions workflows.

## One-Time Server Setup

Before setting up CI/CD, prepare your VPS for automated deployments.

### 1. Run Setup Script on VPS

SSH into your VPS and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Joe-Heffer/moltbot/main/deploy/setup-server.sh -o setup-server.sh
chmod +x setup-server.sh
sudo ./setup-server.sh
```

This creates a `deploy` user with limited sudo privileges for running deployments.

### 2. Generate SSH Key Pair (on your local machine)

```bash
ssh-keygen -t ed25519 -C "github-actions-moltbot" -f ~/.ssh/moltbot-deploy
```

### 3. Add Public Key to VPS

```bash
ssh-copy-id -i ~/.ssh/moltbot-deploy.pub deploy@your-server-ip
```

### 4. Add GitHub Repository Secrets

Go to your repository settings at `Settings > Secrets and variables > Actions` and add:

| Secret | Value |
|--------|-------|
| `VPS_HOST` | Your VPS IP address |
| `VPS_USERNAME` | `deploy` |
| `VPS_SSH_KEY` | Contents of `~/.ssh/moltbot-deploy` (private key file) |
| `VPS_PORT` | `22` (or your custom SSH port) |

## Deployment Triggers

The workflow runs automatically when:
- Changes are pushed to the `main` branch in the `deploy/` directory
- Manually triggered via GitHub Actions UI

## Manual Deployment

1. Go to **Actions** > **Deploy to VPS**
2. Click **Run workflow**
3. Choose an action:
   - `deploy` — Install or update OpenClaw, regenerate all configuration
   - `restart` — Restart the moltbot-gateway service

## Workflow Features

### Deployment Tracking
Each deploy is recorded in GitHub Environments. View deployment history at:
`Settings > Environments > production`

Shows:
- Deployment history and status
- Associated commits
- Previous deployed version (for rollback reference)

### Concurrency Control
Only one deployment runs at a time. Additional triggers queue instead of overlapping, preventing race conditions.

### Health Checks
After deployment, the workflow verifies:
- The `moltbot-gateway` service is running
- Port 18789 is listening and responding

### Zero-Downtime Updates
The service is only restarted after the update is confirmed successful.

### Version Tracking
Each deployment captures the git version and stores it on the VPS at `/opt/moltbot-version` for tracking which release is currently deployed.

## Workflow File

The workflow is defined at `.github/workflows/deploy.yml`. It runs:

```bash
git fetch origin
git checkout <branch>
sudo ./deploy/deploy.sh    # Idempotent deployment script
```

Refer to the [Deployment Details](./QUICK_START.md) for what `deploy.sh` does.

## Troubleshooting

### "Permission denied (publickey)" Error
- Verify the public key is on the VPS: `cat ~/.ssh/authorized_keys | grep moltbot`
- Check that the SSH key secret in GitHub matches your private key

### Deployment Times Out
- Check VPS network connectivity: `ssh -i ~/.ssh/moltbot-deploy deploy@your-server-ip`
- Verify firewall allows SSH on port 22 (or your custom port)

### Service Doesn't Restart After Deploy
- SSH to VPS and check service status: `sudo systemctl status moltbot-gateway`
- View logs: `sudo journalctl -u moltbot-gateway -n 50`

## Monitoring Deployments

Watch the workflow run in real time:

1. Go to **Actions**
2. Select **Deploy to VPS**
3. Click the running workflow to see live logs
4. Check the **Environments** section for deployment history

## Rollback

To rollback to a previous version:

1. Find the previous version at `Settings > Environments > production`
2. Check which commit was deployed
3. Either:
   - Revert the commit: `git revert <commit-hash>` and push to main
   - Manually checkout a previous commit and push: `git checkout <commit-hash>` and push
4. Trigger the deploy workflow to apply the older version

Or manually on the VPS:

```bash
# View current version
cat /opt/moltbot-version

# Reinstall a specific version
sudo npm install -g moltbot@0.2.0
sudo ./deploy/deploy.sh
```

## Advanced: Custom Deployment Branch

By default, the workflow deploys from the `main` branch. To deploy from a different branch, edit `.github/workflows/deploy.yml` and change:

```yaml
if: github.ref == 'refs/heads/main'
```

To your desired branch name. Then commit and push the change.
