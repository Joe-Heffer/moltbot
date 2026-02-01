# Low-Memory VPS Setup

Guide for running OpenClaw on VPS with limited RAM (2–4 GB).

## System Requirements

**Minimum**: 2 GB RAM (see [official system requirements](https://docs.openclaw.ai/help/faq))

**Recommended**: 4 GB RAM for comfortable headroom

**Not supported**: 1 GB RAM — OOM killer will terminate the service under normal operation.

## Automatic Resource Tuning

The deployment script automatically detects available RAM and configures limits:

| RAM | MemoryMax | Node.js Heap | Swap Needed? |
|-----|-----------|-------------|---|
| 2 GB | 1536M | 1024 MB | Yes (recommended) |
| 4 GB+ | 2G | 1536 MB | No (optional) |

These limits prevent memory from consuming the entire system and allow proper functioning of other OS services.

## Adding Swap Space (Recommended for 2 GB RAM)

Swap prevents OOM killer from terminating OpenClaw during memory spikes.

### Create a 2 GB Swap File

```bash
# Create the swap file
sudo fallocate -l 2G /swapfile

# Set permissions
sudo chmod 600 /swapfile

# Format as swap
sudo mkswap /swapfile

# Enable swap
sudo swapon /swapfile
```

### Make Swap Permanent

```bash
# Add to fstab so it persists across reboots
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Verify:

```bash
sudo swapon --show
```

### Optimize Swap Behavior

By default, Linux uses swap aggressively. Reduce this to only use swap under pressure:

```bash
# Set swappiness to 10 (use swap only when necessary)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Apply immediately
sudo sysctl -p
```

Verify:

```bash
cat /proc/sys/vm/swappiness
# Should output: 10
```

### Monitor Swap Usage

```bash
# Check current swap usage
free -h

# Watch in real time
watch -n 1 'free -h'
```

Example output:

```
               total       used       free     shared  buff/cache available
Mem:           1.9G       1.2G       300M        20M       400M       600M
Swap:          2.0G       150M       1.8G
```

If swap usage is consistently high (>50%), consider:
- Disabling unused messaging channels
- Upgrading to 4+ GB RAM
- Running fewer concurrent skills

## Reducing Memory Overhead

Each messaging channel (Telegram, WhatsApp, Discord, Slack) maintains a persistent connection that consumes ~50-100 MB of RAM.

### Disable Unused Channels

Edit your environment configuration:

```bash
sudo -u openclaw nano /home/openclaw/.config/openclaw/.env
```

Comment out or remove the tokens for channels you don't use:

```bash
# Keep only the channels you need
TELEGRAM_BOT_TOKEN=...         # Keep this
# WHATSAPP_WEBHOOK_URL=...     # Disable (comment out)
# DISCORD_TOKEN=...             # Disable (comment out)
SLACK_BOT_TOKEN=...            # Keep this
```

Restart the service:

```bash
sudo systemctl restart openclaw-gateway
```

### Monitor Channel Memory Usage

Check memory consumption before and after disabling channels:

```bash
# Before disabling
sudo systemctl restart openclaw-gateway
sleep 5
ps aux | grep openclaw-gateway | grep -v grep

# Disable a channel, restart
sudo systemctl restart openclaw-gateway
sleep 5
ps aux | grep openclaw-gateway | grep -v grep
```

Compare the `%MEM` or `RES` columns (resident memory).

## OOM Killer Prevention

If you see "Out of memory" errors in logs, the OOM killer is terminating the service.

### Check OOM Kill Log

```bash
sudo grep -i "out of memory" /var/log/syslog
# or
sudo dmesg | grep -i "out of memory"
```

### Increase Memory Limit

If you're consistently hitting OOM:

1. **Add more swap** (see section above)
2. **Disable channels** you're not actively using
3. **Upgrade to 4+ GB RAM**
4. **Reduce Node.js heap** (only if you know what you're doing):
   ```bash
   # Edit service override
   sudo systemctl edit --full openclaw-gateway

   # Find NODE_MAX_OLD_SPACE_SIZE and reduce it
   # WARNING: Too low will crash the service
   ```

## Disk Space Considerations

OpenClaw stores logs, cache, and state files in `/home/openclaw/`. Monitor disk usage:

```bash
# Check disk space
df -h /home/openclaw

# Check directory size
du -sh /home/openclaw/
```

If running low on disk:

1. Clean old logs:
   ```bash
   sudo journalctl --disk-usage
   sudo journalctl --vacuum-time=7d  # Keep only 7 days of logs
   ```

2. Clear cache (safe to do while running):
   ```bash
   sudo -u openclaw rm -rf /home/openclaw/.cache/*
   ```

## Performance Tips for Low-Memory Systems

### 1. Monitor Regularly

```bash
# Watch in real time
watch -n 2 'free -h && echo "---" && ps aux | grep moltbot | grep -v grep'
```

### 2. Graceful Restarts

Instead of abrupt restarts, allow the service to finish in-flight requests:

```bash
sudo systemctl reload openclaw-gateway
```

### 3. Tune Swap Aggressiveness

If swap is being used too often:

```bash
# Reduce swappiness further (more aggressive)
echo 'vm.swappiness=5' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

If swappiness is too low and swap isn't being used:

```bash
# Increase swappiness (less aggressive)
echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 4. Limit Concurrent Skills

Some community skills are memory-heavy. Limit concurrent execution in your config:

```bash
# In /home/openclaw/.config/openclaw/.env
SKILL_CONCURRENCY_LIMIT=2
```

## Deployment on 2 GB VPS

If deploying to a fresh 2 GB VPS:

1. **Run setup script** (as usual):
   ```bash
   sudo ./deploy/deploy.sh
   ```

2. **Add swap immediately** (before first run):
   ```bash
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

3. **Disable unnecessary channels** during onboarding:
   ```bash
   sudo -u openclaw -i openclaw onboard
   ```
   Only enable channels you need.

4. **Monitor after setup**:
   ```bash
   watch -n 2 'free -h'
   ```

## Troubleshooting

### "Cannot allocate memory" errors

```bash
sudo journalctl -u openclaw-gateway -n 50 | grep -i memory
```

Solutions:
- Add more swap space
- Disable unused channels
- Upgrade RAM
- Check for memory leaks: `sudo -u openclaw -i openclaw doctor`

### Service crashes shortly after restart

1. Check available memory:
   ```bash
   free -h
   ```

2. View crash logs:
   ```bash
   sudo journalctl -u openclaw-gateway -n 100
   ```

3. Increase memory limits (if possible) or disable channels

### High swap usage (>50%)

This indicates insufficient RAM for your workload:

```bash
# Check what's using memory
ps aux --sort=-%mem | head -10
```

Options:
- Disable channels
- Upgrade to 4+ GB RAM
- Run fewer concurrent skills

## Related Documentation

- [Quick Start](./QUICK_START.md) — Initial setup
- [Service Management](./SERVICE_MANAGEMENT.md) — Monitor and troubleshoot
- [Configuration Guide](./CONFIGURATION.md) — Disable channels
- [Official System Requirements](https://docs.openclaw.ai/help/faq)
