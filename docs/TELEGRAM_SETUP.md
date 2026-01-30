# Telegram Setup

Connect Moltbot to Telegram so you can chat with your assistant from any Telegram client.

> **Official guide:** <https://docs.openclaw.ai/channels/telegram>
> — covers features, group chat options, and advanced configuration.

## Prerequisites

- A working Moltbot deployment (see [Deployment Guide](./DEPLOYMENT.md))
- A Telegram account

## Step 1: Create a Bot with BotFather

1. Open Telegram and search for **@BotFather** (or visit <https://t.me/botfather>).
2. Send `/newbot` and follow the prompts to choose a display name and username.
3. BotFather will reply with a **bot token** — a string like `123456789:ABCdefGhIjKlMnOpQrStUvWxYz`. Copy it.

> **Keep this token secret.** Anyone with the token can control your bot.

## Step 2: Configure the Token on Your Server

SSH into your VPS and edit the Moltbot environment file:

```bash
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Uncomment and set the Telegram line:

```
TELEGRAM_BOT_TOKEN=123456789:ABCdefGhIjKlMnOpQrStUvWxYz
```

The env file is loaded by the systemd service via the `EnvironmentFile` directive in `moltbot-gateway.service`. It should already have `chmod 600` permissions (set by the installer), so the token is readable only by the `moltbot` user.

## Step 3: Restart the Service

```bash
sudo systemctl restart moltbot-gateway
```

Verify it started cleanly:

```bash
sudo systemctl status moltbot-gateway
sudo journalctl -u moltbot-gateway -n 20 --no-pager
```

## Step 4: Test the Connection

Open your new bot in Telegram and send a message. Moltbot should respond within a few seconds.

If it does not, check the journal logs above for errors — the most common issue is a mistyped token.

## Security Notes

- The `.env` file lives at `/home/moltbot/.config/moltbot/.env` with `600` permissions, so only the `moltbot` system user can read it.
- The systemd unit runs with `ProtectHome=read-only` and `NoNewPrivileges=yes` (see [Security Guide](./SECURITY.md) for the full hardening profile).
- The token is **not** managed through CI/CD — it stays on the server and persists across deploys.

## Further Reading

- [Official Telegram channel docs](https://docs.openclaw.ai/channels/telegram) — full feature reference and advanced options
- [Telegram Bot API documentation](https://core.telegram.org/bots/api)
- [Environment template](../deploy/moltbot.env.template) — all available environment variables
