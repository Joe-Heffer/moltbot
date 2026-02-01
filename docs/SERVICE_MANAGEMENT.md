# Service Management

Start, stop, monitor, and troubleshoot the OpenClaw gateway service.

## Service Commands

### Start the Service

```bash
sudo systemctl start moltbot-gateway
```

### Stop the Service

```bash
sudo systemctl stop moltbot-gateway
```

### Restart the Service

```bash
sudo systemctl restart moltbot-gateway
```

After changing configuration files (`.env`, fallbacks), always restart:

```bash
# Edit config
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env

# Restart to apply changes
sudo systemctl restart moltbot-gateway
```

### Enable Auto-Start on Boot

```bash
sudo systemctl enable moltbot-gateway
```

Disable auto-start:

```bash
sudo systemctl disable moltbot-gateway
```

### Check Service Status

```bash
sudo systemctl status moltbot-gateway
```

Shows:
- Current status (running, stopped, failed)
- Process ID (PID)
- Memory and CPU usage
- Recent log output

## Viewing Logs

### Live Logs (Follow Mode)

```bash
sudo journalctl -u moltbot-gateway -f
```

Streams logs in real time. Press `Ctrl+C` to exit.

### Recent Logs

```bash
# Last 50 lines
sudo journalctl -u moltbot-gateway -n 50

# Last 100 lines
sudo journalctl -u moltbot-gateway -n 100
```

### Logs Since a Specific Time

```bash
# Last 10 minutes
sudo journalctl -u moltbot-gateway --since "10 minutes ago"

# Last 1 hour
sudo journalctl -u moltbot-gateway --since "1 hour ago"

# Since a specific date/time
sudo journalctl -u moltbot-gateway --since "2025-02-01 10:00:00"
```

### Verbose Logs

```bash
# All log levels including debug
sudo journalctl -u moltbot-gateway -p debug -n 50

# Only errors
sudo journalctl -u moltbot-gateway -p err -n 50
```

## Common Status Checks

### Verify Service is Running

```bash
sudo systemctl is-active moltbot-gateway
```

Output: `active` or `inactive`

### Check Gateway Port

```bash
# Is port 18789 listening?
sudo netstat -tlnp | grep 18789
# or
sudo ss -tlnp | grep 18789
```

### Test Gateway Response

```bash
# Quick health check
curl -s http://localhost:18789/health | jq .

# Or without jq
curl -s http://localhost:18789/health
```

### Monitor Resource Usage

```bash
# Real-time system monitor
top -p $(pgrep -f 'moltbot-gateway')

# Or use htop for better formatting
htop -p $(pgrep -f 'moltbot-gateway')
```

## Troubleshooting

### Service Won't Start

Check the logs:

```bash
sudo journalctl -u moltbot-gateway -n 50
```

Common causes:
- **Port already in use**: Check if another process is listening on 18789
  ```bash
  sudo lsof -i :18789
  ```
- **Permission denied**: Ensure the `moltbot` user owns config files:
  ```bash
  sudo chown -R moltbot:moltbot /home/moltbot/.config
  ```
- **Out of memory**: See [Low-Memory VPS](./LOW_MEMORY_VPS.md)
- **Config file errors**: Validate JSON in `/home/moltbot/.config/moltbot/.env`

### Service Crashes Repeatedly

1. Check logs for the error:
   ```bash
   sudo journalctl -u moltbot-gateway -n 100
   ```

2. Run diagnostics:
   ```bash
   sudo -u moltbot -i moltbot doctor
   ```

3. Try repair mode:
   ```bash
   sudo -u moltbot -i moltbot doctor --repair
   ```

4. Check available RAM:
   ```bash
   free -h
   ```

### High Memory Usage

Each active channel (Telegram, WhatsApp, Discord, Slack) consumes memory. To reduce:

1. Disable unused channels in `.env`
2. Increase swap space (see [Low-Memory VPS](./LOW_MEMORY_VPS.md))
3. Monitor with:
   ```bash
   watch -n 1 'free -h && ps aux | grep moltbot'
   ```

### Service Running But Gateway Unreachable

1. Verify port is listening:
   ```bash
   sudo ss -tlnp | grep 18789
   ```

2. Check firewall rules:
   ```bash
   sudo ufw status
   ```

3. Test localhost access:
   ```bash
   curl -v http://localhost:18789
   ```

4. Check for reverse proxy issues:
   ```bash
   # If using nginx/Tailscale, verify X-Forwarded-For headers
   sudo tail -f /var/log/nginx/access.log  # or relevant proxy logs
   ```

## Advanced: Manual Service Configuration

The systemd service is generated from `/home/user/moltbot/deploy/moltbot-gateway.service` and deployed by `deploy.sh`. To modify the service:

1. Edit the template: `/home/moltbot/deploy/moltbot-gateway.service`
2. Re-run deployment: `sudo ./deploy/deploy.sh`

Or manually edit and reload:

```bash
sudo systemctl edit --full moltbot-gateway
sudo systemctl daemon-reload
sudo systemctl restart moltbot-gateway
```

## Monitoring and Metrics

### Watch Service Health

```bash
while true; do
  echo "=== $(date) ==="
  sudo systemctl status moltbot-gateway | grep -E "Active|memory"
  echo ""
  sleep 10
done
```

### System Resource Limits

The service is configured with memory limits based on your RAM:

```bash
# View current limits
sudo systemctl show moltbot-gateway -p MemoryMax

# View all service properties
sudo systemctl show moltbot-gateway
```

### Performance Tuning

The deployment script automatically configures `MemoryMax` and Node.js heap size:

| RAM | MemoryMax | Node.js Heap |
|-----|-----------|--------------|
| 2 GB | 1536M | 1024 MB |
| 4 GB+ | 2G | 1536 MB |

To manually adjust:

```bash
# Edit the service environment
sudo nano /etc/systemd/system/moltbot-gateway.service.d/override.conf

# Set custom memory limit
[Service]
MemoryMax=2G

# Then reload and restart
sudo systemctl daemon-reload
sudo systemctl restart moltbot-gateway
```

## Updates and Restarts

### Update OpenClaw

```bash
# Pull the latest deployment scripts
cd /path/to/moltbot
git pull origin main

# Run the idempotent deployment (updates npm package, restarts service)
sudo ./deploy/deploy.sh
```

### Zero-Downtime Restarts

Graceful restart (allows in-flight requests to complete):

```bash
sudo systemctl reload moltbot-gateway
```

Or forceful restart:

```bash
sudo systemctl restart moltbot-gateway
```

## Related Documentation

- [Quick Start](./QUICK_START.md) — Initial setup
- [Configuration Guide](./CONFIGURATION.md) — Environment variables and API keys
- [Troubleshooting](./TROUBLESHOOTING.md) — Common issues and solutions
- [Low-Memory VPS](./LOW_MEMORY_VPS.md) — Memory management on limited hardware
