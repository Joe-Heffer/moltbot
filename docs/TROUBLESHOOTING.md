# Troubleshooting

Common issues when running OpenClaw on a Linux VPS and how to resolve them.

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

### "access not configured" reply on Telegram

**Symptom:** You message the bot on Telegram and it replies:

```
OpenClaw: access not configured.

Your Telegram user id: 123456789

Pairing code: abc123

Ask the bot owner to approve with:
moltbot pairing approve telegram <code>
```

**Cause:** The default `DM_POLICY=pairing` setting requires the bot owner to approve every new contact before they can use the bot.

**Fix:** Approve the pairing code via the CLI:

```bash
sudo -u moltbot -i moltbot pairing approve <channel> <code>
```

Replace `<channel>` and `<code>` with the values from the bot's message. After approval, the user can chat normally. See the [Telegram Setup Guide](./TELEGRAM_SETUP.md#step-5-approve-the-pairing-request) for details.

> If the command fails, see the next section.

### Pairing CLI does not recognise Telegram channel

**Symptom:** You run the approve command and get one of:

```
Error: Channel telegram does not support pairing
```

```
Error: Channel required. Use --channel <channel> or pass it as the first argument (expected one of: )
```

The `(expected one of: )` list is empty — no channels are registered for pairing.

**Cause:** This is a known bug in OpenClaw v2026.1.27-beta.1. The Telegram bot sends a pairing prompt, but the `moltbot pairing` CLI does not register Telegram as a supported pairing channel, so there is no way to approve the code.

**Workaround:** Set `DM_POLICY=open` to bypass pairing entirely:

```bash
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Set or add:

```
DM_POLICY=open
```

Then restart:

```bash
sudo systemctl restart moltbot-gateway
```

The bot will now respond to all Telegram messages without requiring approval. Switch back to `DM_POLICY=pairing` once a fixed version is released. See the [Telegram Setup Guide](./TELEGRAM_SETUP.md#workaround-set-dm_policyopen) for details.

### "Unsupported schema node" error in Gateway UI for Telegram

**Symptom:** When configuring Telegram settings in the Gateway UI web interface, you see an error message:

```
Accounts / Unsupported schema node. Use Raw mode.
```

**Cause:** This is a bug in the Gateway UI's schema-based form rendering system (tracked in [issue #57](https://github.com/Joe-Heffer/moltbot/issues/57)). The UI encounters a schema node type it doesn't know how to render for Telegram account configuration.

**Workaround:** Configure Telegram directly via the environment file instead of using the Gateway UI:

1. SSH into your server and edit the environment file:
   ```bash
   sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
   ```

2. Add or uncomment the Telegram configuration:
   ```bash
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```

3. Restart the service to apply changes:
   ```bash
   sudo systemctl restart moltbot-gateway
   ```

See the [Telegram Setup Guide](./TELEGRAM_SETUP.md) for detailed instructions on obtaining a bot token from @BotFather and configuring security settings.

Alternatively, if the Gateway UI offers a "Raw mode" option for the Telegram configuration, you can click that to edit the configuration as JSON directly instead of using the form-based interface.

### "Unknown target" phone number error on Telegram

**Symptom:** OpenClaw returns an error when trying to send a Telegram message:

```json
{
  "status": "error",
  "tool": "message",
  "error": "Unknown target \"+44790...\" for Telegram. Hint: <chatId>"
}
```

**Cause:** Telegram bots identify users by numeric **chat ID**, not by phone number. Phone numbers cannot be used as a target for the Telegram Bot API. If you configured a contact or allowlist entry using a phone number (e.g., `+447901234567`), Telegram will not be able to resolve it.

**Fix:** Use the numeric Telegram chat ID instead of a phone number. To find your chat ID:

1. Open your bot in Telegram and send it any message.
2. The bot replies with a pairing prompt that includes your **Telegram user id** (e.g., `123456789`).
3. Use that numeric ID wherever a Telegram target is required (e.g., in `DM_ALLOWLIST` or tool calls).

If you already have a conversation with the bot, you can also find your chat ID by checking the service logs:

```bash
sudo journalctl -u moltbot-gateway -n 50 --no-pager | grep -i "chat"
```

### "No API key found for provider 'openai-codex'" crash

**Symptom:** The service crashes with an error in the journal:

```
No API key found for provider 'openai-codex'. Auth store: /home/moltbot/.clawdbot/agents/main/agent/auth-profiles.json
```

The agent crashes instead of gracefully handling the missing API key.

**Cause:** OpenClaw is attempting to use the "openai-codex" provider (OpenAI's Codex API for code generation) but cannot find authentication credentials. This is an upstream bug in OpenClaw - it should gracefully fall back to another provider or skip the operation instead of crashing.

**Important Notes:**
- "openai-codex" is different from the regular "openai" provider
- Codex is OpenAI's specialized code-generation API (used by GitHub Copilot)
- Codex has been deprecated/limited access since 2023
- Our deployment scripts don't configure codex by default

**Workaround:** The OpenAI API key can be used for both standard OpenAI models and Codex access. Configure your OpenAI API key in the environment file:

```bash
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Ensure `OPENAI_API_KEY` is set:

```bash
OPENAI_API_KEY=sk-...your_key_here...
```

Then configure the agent's auth profile to use the same key for codex:

```bash
# Run onboarding if not already done
sudo -u moltbot -i moltbot onboard

# Or manually configure the OpenAI provider
sudo -u moltbot -i moltbot config set providers.openai.apiKey "$OPENAI_API_KEY"
```

Finally, restart the service:

```bash
sudo systemctl restart moltbot-gateway
```

**Note:** If you don't have an OpenAI API key and don't need code generation features, this is a bug that should be reported to the OpenClaw project. The agent should not crash when optional providers are unavailable.

**Related Issue:** [#91](https://github.com/Joe-Heffer/moltbot/issues/91)

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

**Symptom:** `deploy.sh` reports:

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

**Symptom:** The deploy script shows repeated warnings:

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

**Symptom:** Running `sudo bash deploy.sh` prints:

```
bash: line 1: export: `-g': not a valid identifier
bash: line 1: export: `moltbot@beta': not a valid identifier
```

**Cause:** An older version of the deploy script passed the npm install arguments incorrectly. This was fixed in [PR #34](https://github.com/Joe-Heffer/moltbot/pull/34).

**Fix:** Pull the latest version of the deploy scripts:

```bash
cd ~/moltbot && git pull
sudo bash deploy/deploy.sh
```

### OOM kill during npm install

**Symptom:** `npm install -g openclaw` is killed during the update, or the script hangs and then fails.

**Cause:** The VPS has less than 4 GB RAM and npm exhausts available memory during installation.

**Fix:** The deploy script automatically creates temporary swap on low-memory systems (< 2 GB RAM + swap). If this still fails:

```bash
# Manually add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Then retry the deployment
sudo bash deploy/deploy.sh

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

| Command                                                                 | Purpose                        |
| ----------------------------------------------------------------------- | ------------------------------ |
| `sudo journalctl -u moltbot-gateway -n 50`                              | Last 50 log lines              |
| `sudo journalctl -u moltbot-gateway -f`                                 | Follow logs in real time       |
| `sudo systemctl status moltbot-gateway`                                 | Service status and recent logs |
| `sudo -u moltbot -i moltbot --version`                                  | Installed moltbot version      |
| `sudo -u moltbot -i moltbot doctor`                                     | Built-in diagnostic check      |
| `sudo ss -tlnp \| grep 18789`                                           | Check if port is in use        |
| `sudo dmesg \| grep -i oom`                                             | Check for OOM kills            |
| `systemctl show moltbot-gateway -p MainPID,ActiveState,SubState,Result` | Detailed service state         |
