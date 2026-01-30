# Telegram Setup

Connect Moltbot to Telegram so you can chat with your assistant from any Telegram client.

> **Official guide:** <https://docs.molt.bot/channels/telegram>
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

Open your new bot in Telegram and send a message. If this is the first time
you are messaging the bot, you will see a **pairing prompt** instead of a
normal reply:

```
Moltbot: access not configured.

Your Telegram user id: 123456789

Pairing code: abc123

Ask the bot owner to approve with:
moltbot pairing approve telegram <code>
```

This is expected — see Step 5 below.

If you do not receive any reply at all, check the journal logs for errors:

```bash
sudo journalctl -u moltbot-gateway -n 20 --no-pager
```

The most common cause is a mistyped bot token.

## Step 5: Approve the Pairing Request

Moltbot ships with `DM_POLICY=pairing` enabled by default (see
[Security Guide](./SECURITY.md)). Every new contact must be approved before
the bot will respond to them. This prevents strangers from using your bot if
they discover its Telegram username.

When someone messages the bot for the first time, the bot replies with a
**pairing code**. To approve access, SSH into your server and run:

```bash
sudo -u moltbot -i moltbot pairing approve telegram <code>
```

Replace `<code>` with the pairing code shown in Telegram. The user can now
chat with the bot normally.

### Managing paired contacts

List all approved contacts:

```bash
sudo -u moltbot -i moltbot pairing list
```

Revoke a previously approved contact:

```bash
sudo -u moltbot -i moltbot pairing revoke telegram <user-id>
```

### Skipping pairing (not recommended)

If you want any Telegram user to be able to message the bot without approval,
set `DM_POLICY=open` in the environment file:

```bash
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

```
DM_POLICY=open
```

Then restart the service:

```bash
sudo systemctl restart moltbot-gateway
```

> **Warning:** Setting `DM_POLICY=open` allows anyone who finds your bot to
> interact with it. Only use this for testing or bots that are intentionally
> public.

## Security Notes

- The `.env` file lives at `/home/moltbot/.config/moltbot/.env` with `600` permissions, so only the `moltbot` system user can read it.
- The systemd unit runs with `ProtectHome=read-only` and `NoNewPrivileges=yes` (see [Security Guide](./SECURITY.md) for the full hardening profile).
- The token is **not** managed through CI/CD — it stays on the server and persists across deploys.

## Further Reading

- [Official Telegram channel docs](https://docs.molt.bot/channels/telegram) — full feature reference and advanced options
- [Telegram Bot API documentation](https://core.telegram.org/bots/api)
- [Environment template](../deploy/moltbot.env.template) — all available environment variables
