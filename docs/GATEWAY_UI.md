# Gateway UI Setup

The Moltbot Gateway includes a built-in web interface for managing your bot, monitoring activity, and configuring channels. This guide explains how to access and set up the Gateway UI after installation.

## Prerequisites

- Moltbot installed and running (see [Deployment Guide](./DEPLOYMENT.md))
- The `moltbot-gateway` systemd service started
- Network access to your VM on port 18789

## Starting the Gateway

If you followed the [Quick Start](../README.md#quick-start) instructions, the gateway service should already be running. Verify with:

```bash
sudo systemctl status moltbot-gateway
```

If the service is not running, start and enable it:

```bash
sudo systemctl start moltbot-gateway
sudo systemctl enable moltbot-gateway
```

## Accessing the Gateway UI

Open a browser and navigate to:

```
http://<your-vm-ip>:18789
```

Replace `<your-vm-ip>` with the public IP address of your VPS. For example, if your server IP is `203.0.113.50`, visit `http://203.0.113.50:18789`.

If you are running Moltbot locally, use:

```
http://localhost:18789
```

## Configuration

### Port and Bind Address

The gateway port and bind address are configured in your environment file at `/home/moltbot/.config/moltbot/.env`:

```bash
# Port for the Gateway to listen on (default: 18789)
MOLTBOT_PORT=18789

# Bind address
# 0.0.0.0 = accept connections from any network interface (required for remote access)
# 127.0.0.1 = local connections only
MOLTBOT_HOST=0.0.0.0
```

After changing these values, restart the service:

```bash
sudo systemctl restart moltbot-gateway
```

### Firewall

The installer opens port 18789 automatically when firewalld is active. If you use a different firewall (e.g. `ufw`), allow the port manually:

```bash
# ufw
sudo ufw allow 18789/tcp

# firewalld (if not already opened by the installer)
sudo firewall-cmd --permanent --add-port=18789/tcp
sudo firewall-cmd --reload
```

If your VPS provider has a cloud firewall or security group, ensure port 18789 is allowed for inbound TCP traffic.

## Secure Remote Access

Exposing the gateway port directly to the internet is not recommended for production use. Instead, use one of the following approaches:

### Tailscale Serve / Funnel (Recommended)

[Tailscale](https://tailscale.com/) provides encrypted access to your gateway without opening ports publicly. Moltbot has built-in Tailscale support:

```bash
# In your .env file
TAILSCALE_ENABLED=true
TAILSCALE_MODE=serve    # "serve" for tailnet-only, "funnel" for public HTTPS
```

See the official documentation for details: [Tailscale integration](https://docs.molt.bot/gateway/tailscale).

### SSH Tunnel

For quick access without installing additional software, use an SSH tunnel:

```bash
ssh -L 18789:127.0.0.1:18789 user@your-vm-ip
```

Then visit `http://localhost:18789` in your browser. The gateway traffic is encrypted through the SSH connection.

### Reverse Proxy

Place the gateway behind a reverse proxy (nginx, Caddy) with TLS termination for HTTPS access. See the official documentation for configuration examples: [Gateway security](https://docs.molt.bot/gateway/security).

## Troubleshooting

### Cannot reach the Gateway UI

1. Verify the service is running:
   ```bash
   sudo systemctl status moltbot-gateway
   ```

2. Check the gateway is listening on the expected port:
   ```bash
   sudo ss -tlnp | grep 18789
   ```

3. Check the logs for errors:
   ```bash
   sudo journalctl -u moltbot-gateway -n 50
   ```

4. Confirm the firewall allows traffic on port 18789 (see [Firewall](#firewall) above).

5. If using a cloud provider, verify the security group or network firewall rules allow inbound TCP on port 18789.

### Gateway starts but UI is blank

Run diagnostics to check for configuration issues:

```bash
sudo -u moltbot -i moltbot doctor
```

## Further Reading

- [Official Moltbot Documentation](https://docs.molt.bot)
- [Gateway Overview](https://docs.molt.bot/gateway)
- [Gateway Security](https://docs.molt.bot/gateway/security)
- [Tailscale Integration](https://docs.molt.bot/gateway/tailscale)
- [Channels Configuration](https://docs.molt.bot/channels)
