# Troubleshooting

Common issues when running Moltbot on a Linux VPS and how to resolve them.

## Checking Logs

Always start by checking the service journal:

```bash
sudo journalctl -u moltbot-gateway -n 50 --no-pager
```

Follow logs in real time:

```bash
sudo journalctl -u moltbot-gateway -f
```

Check service status:

```bash
sudo systemctl status moltbot-gateway
```

## Common Issues

### "Missing config" crash loop

**Symptom:** The service starts, runs for ~15 seconds, then exits. The journal shows:

```
Missing config. Run `moltbot config`...
moltbot-gateway.service: Main process exited, code=exited, status=1/FAILURE
```

The service enters a restart loop because `Restart=always` is set in the systemd unit.

**Cause:** Moltbot has no configuration file. The `moltbot gateway` process requires configuration (API keys, channel settings) before it can run.

**Fix:** Run the interactive configuration wizard as the `moltbot` system user:

```bash
sudo -u moltbot -i moltbot config
```

This creates `/home/moltbot/.config/moltbot/.env` with your settings. Then restart the service:

```bash
sudo systemctl restart moltbot-gateway
```

Alternatively, you can copy and edit the environment template directly:

```bash
sudo cp /home/moltbot/.config/moltbot/moltbot.env.template /home/moltbot/.config/moltbot/.env
sudo chown moltbot:moltbot /home/moltbot/.config/moltbot/.env
sudo chmod 600 /home/moltbot/.config/moltbot/.env
sudo nano /home/moltbot/.config/moltbot/.env   # add your API keys
sudo systemctl restart moltbot-gateway
```

### Service fails health check after update

**Symptom:** `update.sh` reports:

```
[ERROR] Service failed to become healthy after 120 seconds
[ERROR] Update completed but service may not be healthy
```

**Cause:** The service is not listening on port 18789 within the timeout. This can happen for several reasons:

1. **Missing config** — see the section above.
2. **Port conflict** — another process is already using port 18789.
3. **Out of memory** — the process is being OOM-killed.

**Diagnosis:**

```bash
# Check journal for the actual error
sudo journalctl -u moltbot-gateway -n 30 --no-pager

# Check if the port is in use by another process
sudo ss -tlnp | grep 18789

# Check for OOM kills
sudo dmesg | grep -i "oom\|killed process" | tail -5
```

### Service restart loop (PID keeps changing)

**Symptom:** The update script shows repeated warnings:

```
[WARN] Service restarted during health check (PID 35807 -> 35998, #1)
[WARN] Service restarted during health check (PID 35998 -> 36184, #2)
```

**Cause:** The service starts, crashes, and systemd restarts it (every 10 seconds by default). The health check detects the PID changing.

**Fix:** Check the journal for the underlying error — usually "Missing config" or an unhandled exception:

```bash
sudo journalctl -u moltbot-gateway --since "5 minutes ago" --no-pager
```

### `export: '-g' not a valid identifier`

**Symptom:** Running `sudo bash update.sh` prints:

```
bash: line 1: export: `-g': not a valid identifier
bash: line 1: export: `moltbot@beta': not a valid identifier
```

**Cause:** An older version of `update.sh` passed the npm install arguments incorrectly. This was fixed in [PR #34](https://github.com/Joe-Heffer/moltbot/pull/34).

**Fix:** Pull the latest version of the deploy scripts:

```bash
cd ~/moltbot && git pull
sudo bash deploy/update.sh
```

### OOM kill during npm install

**Symptom:** `npm install -g moltbot@beta` is killed during the update, or the script hangs and then fails.

**Cause:** The VPS has less than 4 GB RAM and npm exhausts available memory during installation.

**Fix:** The install and update scripts automatically create temporary swap on low-memory systems (< 2 GB RAM + swap). If this still fails:

```bash
# Manually add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Then retry the update
sudo bash deploy/update.sh

# Optionally remove swap afterward
sudo swapoff /swapfile
sudo rm /swapfile
```

### Service cannot write to config or data directories

**Symptom:** The journal shows permission errors writing to `/home/moltbot/.config/moltbot/` or `/home/moltbot/.local/share/moltbot/`.

**Cause:** The systemd unit uses `ProtectHome=read-only` and only allows writes to specific paths via `ReadWritePaths`. If the directories don't exist or have wrong ownership, writes fail.

**Fix:**

```bash
sudo mkdir -p /home/moltbot/.config/moltbot /home/moltbot/.local/share/moltbot
sudo chown -R moltbot:moltbot /home/moltbot/.config/moltbot /home/moltbot/.local/share/moltbot
sudo systemctl restart moltbot-gateway
```

## Diagnostic Commands

| Command | Purpose |
|---------|---------|
| `sudo journalctl -u moltbot-gateway -n 50` | Last 50 log lines |
| `sudo journalctl -u moltbot-gateway -f` | Follow logs in real time |
| `sudo systemctl status moltbot-gateway` | Service status and recent logs |
| `sudo -u moltbot -i moltbot --version` | Installed moltbot version |
| `sudo -u moltbot -i moltbot doctor` | Built-in diagnostic check |
| `sudo ss -tlnp \| grep 18789` | Check if port is in use |
| `sudo dmesg \| grep -i oom` | Check for OOM kills |
| `systemctl show moltbot-gateway -p MainPID,ActiveState,SubState,Result` | Detailed service state |
