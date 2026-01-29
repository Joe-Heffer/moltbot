# Security Considerations

Moltbot has full access to the host system it runs on. The official [security documentation](https://docs.molt.bot/gateway/security) and the project's RAK threat framework identify three primary risk vectors:

- **Root Risk** -- compromise of the host machine through the agent's shell access.
- **Agency Risk** -- unintended destructive actions taken autonomously by the agent.
- **Keys Risk** -- theft of API keys, tokens, and credentials stored on the host.

## Hardening Checklist

1. **Dedicated machine or VM.** Never run Moltbot on a workstation that holds sensitive data, production credentials, or access to critical infrastructure.

2. **Non-root execution.** The install script in this repository creates a dedicated `moltbot` user with limited privileges. The systemd service enforces `NoNewPrivileges`, `ProtectSystem=strict`, and `ProtectHome=read-only`.

3. **DM pairing mode.** The default `DM_POLICY=pairing` setting requires an approval code before new contacts can interact with the bot. Do not set this to `open` in production.

4. **Network isolation.** Use [Tailscale](https://tailscale.com/) or a VPN for remote access instead of exposing the gateway port directly to the internet. Hundreds of unprotected Moltbot instances have been found via Shodan with open admin ports.

5. **Review community skills.** Skills from MoltHub are not audited. Security researchers have demonstrated proof-of-concept attacks through malicious skills that execute arbitrary commands. Review the source of every skill before installation.

6. **Credential management.** Store API keys in environment files with restrictive permissions (mode `0600`, owned by the moltbot user). Consider using a secrets manager such as 1Password or Bitwarden. GitGuardian reported 181 leaked secrets across public Moltbot repositories.

7. **Docker sandboxing.** For additional isolation, wrap the agent in a hardened Docker container. See the [Composio hardening guide](https://composio.dev/blog/secure-moltbot-clawdbot-setup-composio) for a walkthrough.

8. **Keep Moltbot updated.** Run `./deploy/update.sh` or trigger the CI/CD update workflow regularly to pick up security patches.

## Further Reading

- [1Password: It's Incredible. It's Terrifying. It's MoltBot.](https://1password.com/blog/its-moltbot)
- [Cisco: Personal AI Agents Like Moltbot Are a Security Nightmare](https://blogs.cisco.com/ai/personal-ai-agents-like-moltbot-are-a-security-nightmare)
- [GitGuardian: Moltbot Goes Viral -- And So Do Your Secrets](https://blog.gitguardian.com/moltbot-personal-assistant-goes-viral-and-so-do-your-secrets/)
- [Hostinger: How to Secure and Harden Moltbot](https://www.hostinger.com/support/how-to-secure-and-harden-moltbot-security/)
