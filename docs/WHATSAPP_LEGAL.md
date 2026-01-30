# WhatsApp Terms of Service & Legal Considerations

Moltbot can connect to WhatsApp as one of its supported messaging channels. Before enabling WhatsApp, you should understand the legal and policy landscape. **Using unofficial WhatsApp automation of any kind -- including personal use -- violates WhatsApp's Terms of Service and carries real risk of account bans.**

> **Disclaimer:** This document is informational only and does not constitute legal advice. Read the primary sources linked below and consult a qualified attorney if you need legal guidance.

## Table of Contents

- [Summary](#summary)
- [What the WhatsApp ToS Says](#what-the-whatsapp-tos-says)
- [Official vs Unofficial WhatsApp Integration](#official-vs-unofficial-whatsapp-integration)
- [2025-2026 AI Chatbot Policy Changes](#2025-2026-ai-chatbot-policy-changes)
- [Practical Risks](#practical-risks)
- [Comparison with Other Platforms](#comparison-with-other-platforms)
- [Recommendations](#recommendations)
- [Primary Sources](#primary-sources)

## Summary

| Question | Answer |
|----------|--------|
| Does WhatsApp allow unofficial bots on personal accounts? | **No.** Automated and non-personal use is explicitly prohibited. |
| Does WhatsApp allow bots via the official Business API? | **Yes**, with restrictions (opt-in consent, template messages, escalation paths). |
| Can I use Moltbot on WhatsApp for personal use? | It works technically, but **violates WhatsApp's Terms of Service** regardless of scale or intent. |
| What happens if WhatsApp detects it? | Temporary or permanent ban of your phone number on WhatsApp. |
| Is this different from Discord or Telegram bots? | **Yes.** Discord and Telegram provide official bot APIs for third-party use. WhatsApp does not offer an equivalent for personal accounts. |

## What the WhatsApp ToS Says

WhatsApp's [Terms of Service](https://www.whatsapp.com/legal/terms-of-service) prohibit:

- **Automated access and use** -- Users must not access or use WhatsApp services through automated means, or create accounts through unauthorized or automated methods.
- **Non-personal use** -- WhatsApp explicitly identifies "non-personal use" as a violation alongside bulk and automated messaging.
- **Unauthorized third-party tools** -- Modified clients, unofficial APIs, and third-party automation tools are prohibited regardless of volume or purpose.

WhatsApp's [FAQ on unauthorized automated messaging](https://faq.whatsapp.com/5957850900902049) states:

> WhatsApp's products are not intended for bulk or automated messaging, both of which have always been a violation of our Terms of Service.

WhatsApp has also stated it will pursue **legal action** against those engaged in or assisting abuse of its Terms, including based on off-platform evidence such as public claims about unauthorized WhatsApp integrations.

## Official vs Unofficial WhatsApp Integration

There are two fundamentally different ways to connect to WhatsApp:

### Official: WhatsApp Business API (Cloud API)

The [WhatsApp Business Platform](https://business.whatsapp.com/) is Meta's sanctioned integration point for automated messaging. It is designed for businesses and requires:

- Registration through an official Business Solution Provider (BSP) or Meta's Cloud API
- Opt-in consent from message recipients
- Use of pre-approved message templates outside the 24-hour customer service window
- Human escalation paths when using chatbots
- Compliance with the [WhatsApp Business Policy](https://business.whatsapp.com/policy)

This is the **only ToS-compliant** path for automated WhatsApp messaging.

### Unofficial: Protocol-Level Libraries

Libraries like [whatsapp-web.js](https://github.com/pedroslopez/whatsapp-web.js) and [Baileys](https://github.com/WhiskeySockets/Baileys) reverse-engineer the WhatsApp Web protocol to control a personal WhatsApp account programmatically. These libraries:

- **Violate WhatsApp's Terms of Service** -- the whatsapp-web.js project itself [acknowledges this](https://wwebjs.dev/guide/): "WhatsApp does not allow bots or unofficial clients on their platform, so this shouldn't be considered totally safe."
- Are not endorsed, supported, or permitted by Meta
- Can break without notice when WhatsApp updates its protocol
- Expose users to account bans and potential data security risks

Most community WhatsApp integrations (including those used by personal AI assistants) rely on these unofficial libraries.

## 2025-2026 AI Chatbot Policy Changes

In October 2025, Meta added new restrictions specifically targeting AI on WhatsApp:

- **General-purpose AI chatbots are banned** from the WhatsApp Business Platform as of January 15, 2026. This targets "AI Providers" -- companies offering LLMs, generative AI platforms, or general-purpose AI assistants where AI is the primary functionality.
- **Business-specific bots are still allowed** -- a travel company managing bookings or a retailer sending order updates can still use AI internally, as long as AI is incidental to the business service rather than the primary offering.
- **Meta AI is the sole general-purpose assistant** on WhatsApp, reaching one billion monthly users by May 2025.

This policy change affects the official Business API. Unofficial protocol-level usage was already prohibited before these changes.

## Practical Risks

### Account Bans

WhatsApp employs machine learning to detect unauthorized automation by monitoring:

- High message volume in short periods
- Rapid messaging to users who haven't saved your number
- High block/report rates from recipients
- Technical signatures of automation scripts interacting with WhatsApp Web
- Failure to respond to interactive verification prompts (e.g., "A fresh look for WhatsApp Web" popups)

Consequences escalate from temporary suspensions (30 minutes to 7 days) to **permanent bans** where your phone number is blacklisted from WhatsApp entirely. Appeals for clear automation violations are rarely successful.

As of late 2025, users of both Baileys and whatsapp-web.js report a significant increase in ban frequency, including accounts that had operated for years without issues.

### Security Risks

Unofficial WhatsApp libraries introduce additional security concerns:

- **Supply chain attacks** -- In late 2025, a malicious fork of the Baileys library (`lotusbail`) was discovered on npm with over 56,000 downloads. It functioned as a working WhatsApp API while silently exfiltrating credentials, messages, contacts, and media.
- **No official support** -- Protocol changes by WhatsApp can break unofficial libraries at any time, potentially leaving sessions in an inconsistent state.
- **Data exposure** -- Unofficial tools may not meet data protection standards required by GDPR, CCPA, or other privacy regulations.

### Legal Risks

- Violation of WhatsApp's ToS can result in loss of service and potential legal action from Meta
- Use of unofficial APIs may violate data protection laws in your jurisdiction
- Operating a service that facilitates ToS violations could carry additional liability

## Comparison with Other Platforms

Unlike WhatsApp, several messaging platforms offer official bot APIs designed for third-party integrations:

| Platform | Official Bot API | Personal Account Automation | Notes |
|----------|-----------------|----------------------------|-------|
| **Discord** | Yes ([Bot API](https://discord.com/developers/docs/intro)) | Prohibited (self-bots violate ToS) | Bots must use their own accounts, not impersonate users |
| **Telegram** | Yes ([Bot API](https://core.telegram.org/bots)) | Allowed (user API exists) | Most permissive; official bot and user APIs both available |
| **Slack** | Yes ([Bolt/Web API](https://api.slack.com/)) | N/A (workspace-based) | Bots operate as workspace apps with defined scopes |
| **Signal** | Limited ([signal-cli](https://github.com/AsamK/signal-cli)) | Gray area | No official bot API; community tools exist |
| **WhatsApp** | Business API only | **Prohibited** | No personal bot API; unofficial tools violate ToS |

The Discord comparison in particular is relevant: Discord allows third-party bots but requires them to operate under their own bot accounts with their own identity. They **cannot** automate or act on behalf of a user's personal account (so-called "self-bots" violate Discord's ToS). WhatsApp is stricter still -- there is no equivalent of Discord's bot account system for personal use at all.

## Recommendations

1. **Understand the risk before enabling WhatsApp.** Any connection to WhatsApp through unofficial means violates the ToS. Your phone number may be temporarily or permanently banned.

2. **Use alternative channels where possible.** Telegram offers the most permissive bot ecosystem. Discord, Slack, and other platforms with official bot APIs are also lower-risk choices.

3. **If you choose to use WhatsApp despite the risks:**
   - Accept that you may lose access to your WhatsApp account at any time
   - Do not use your primary phone number
   - Keep message volume low and behavior human-like
   - Stay current with Moltbot updates, as upstream library changes may affect stability
   - Review the [Security Guide](./SECURITY.md) for general hardening advice

4. **For business use, use the official WhatsApp Business API.** It is the only compliant path and is available through Meta's Cloud API or authorized BSPs such as Twilio, MessageBird, or Vonage.

5. **Monitor policy changes.** WhatsApp's policies around AI and automation are actively evolving (see the [2025-2026 changes](#2025-2026-ai-chatbot-policy-changes)). What is tolerated today may be enforced more aggressively tomorrow.

## Primary Sources

- [WhatsApp Terms of Service](https://www.whatsapp.com/legal/terms-of-service)
- [WhatsApp Terms of Service (EEA)](https://www.whatsapp.com/legal/terms-of-service-eea)
- [WhatsApp FAQ: Unauthorized Use of Automated or Bulk Messaging](https://faq.whatsapp.com/5957850900902049)
- [WhatsApp Business Policy](https://business.whatsapp.com/policy)
- [WhatsApp Business Terms of Service](https://www.whatsapp.com/legal/business-terms)
- [TechCrunch: WhatsApp Changes Its Terms to Bar General-Purpose Chatbots (Oct 2025)](https://techcrunch.com/2025/10/18/whatssapp-changes-its-terms-to-bar-general-purpose-chatbots-from-its-platform/)
- [MEF: Meta's WhatsApp AI Chatbot Ban (Dec 2025)](https://mobileecosystemforum.com/2025/12/01/metas-whatsapp-ai-chatbot-ban/)
- [whatsapp-web.js Guide (disclaimer on ToS)](https://wwebjs.dev/guide/)
- [Baileys Ban Reports (GitHub Issue #1869)](https://github.com/WhiskeySockets/Baileys/issues/1869)
- [Bot.Space: WhatsApp API vs. Unofficial Tools Risk Analysis](https://www.bot.space/blog/whatsapp-api-vs-unofficial-tools-a-complete-risk-reward-analysis-for-2025)
