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
**pairing code** and a suggested CLI command. To approve access, SSH into
your server and run:

```bash
sudo -u moltbot -i moltbot pairing approve <channel> <code>
```

Replace `<channel>` with the channel identifier and `<code>` with the
pairing code shown in Telegram.

> **Known issue (v2026.1.27-beta.1):** The `moltbot pairing` CLI does not
> currently register Telegram as a pairing channel. Running the command
> produces `Channel telegram does not support pairing` or
> `expected one of: ` (empty list). Until a fix is released, use
> `DM_POLICY=open` as a workaround — see
> [Workaround: set DM_POLICY=open](#workaround-set-dm_policyopen) below
> and the [Troubleshooting Guide](./TROUBLESHOOTING.md#pairing-cli-does-not-recognise-telegram-channel).

### Managing paired contacts

Once the pairing CLI supports Telegram, you can manage contacts with:

```bash
sudo -u moltbot -i moltbot pairing list
sudo -u moltbot -i moltbot pairing approve <channel> <code>
```

To see all available pairing subcommands and options:

```bash
sudo -u moltbot -i moltbot pairing --help
```

### Workaround: set DM_POLICY=open

Until the pairing CLI supports Telegram, set `DM_POLICY=open` so the bot
responds to all incoming messages without approval:

```bash
sudo -u moltbot nano /home/moltbot/.config/moltbot/.env
```

Set or add:

```
DM_POLICY=open
```

Then restart the service:

```bash
sudo systemctl restart moltbot-gateway
```

Message your bot on Telegram again — it should now respond normally.

> **Warning:** `DM_POLICY=open` allows anyone who discovers your bot's
> Telegram username to interact with it. Switch back to `pairing` once a
> fixed version of Moltbot is released.

## Telegram Uses Chat IDs, Not Phone Numbers

Telegram bots identify users by a numeric **chat ID** (e.g., `123456789`), not
by phone number. If you pass a phone number like `+447901234567` as a Telegram
target, you will get an error:

```
Unknown target "+44790..." for Telegram. Hint: <chatId>
```

To find your chat ID, send any message to your bot — the pairing prompt
includes your Telegram user id. Use that numeric id wherever a Telegram target
is required (e.g., in `DM_ALLOWLIST` or when calling the `message` tool).

See the [Troubleshooting Guide](./TROUBLESHOOTING.md#unknown-target-phone-number-error-on-telegram)
for details.

## Security Notes

- The `.env` file lives at `/home/moltbot/.config/moltbot/.env` with `600` permissions, so only the `moltbot` system user can read it.
- The systemd unit runs with `ProtectHome=read-only` and `NoNewPrivileges=yes` (see [Security Guide](./SECURITY.md) for the full hardening profile).
- The token is **not** managed through CI/CD — it stays on the server and persists across deploys.

## Further Reading

- [Official Telegram channel docs](https://docs.molt.bot/channels/telegram) — full feature reference and advanced options
- [Telegram Bot API documentation](https://core.telegram.org/bots/api)
- [Environment template](../deploy/moltbot.env.template) — all available environment variables
