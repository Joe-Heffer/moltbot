# Cost Expectations

OpenClaw itself is free and open source (MIT license). The primary ongoing cost is LLM API usage.

## Monthly Cost Estimates

| Usage Level | Monthly Estimate | Typical Profile |
|-------------|-----------------|-----------------|
| Light | $5 -- $15 | Occasional queries, budget models |
| Moderate | $15 -- $50 | Daily use, multi-channel, mixed models |
| Heavy | $50 -- $150 | Continuous operation, premium models |

Costs depend heavily on **which model you choose**. Using a budget model like Gemini 2.5 Flash or DeepSeek R1 can reduce costs by 10--50x compared to premium models like Claude Opus 4.5. VPS hosting adds $4 -- $24/month depending on provider and RAM. Cloudflare Workers deployment runs at approximately $5/month.

## Model Pricing Comparison

Approximate pricing per 1M tokens (as of early 2026):

| Model | Provider | Input | Output | Notes |
|-------|----------|------:|-------:|-------|
| Claude Opus 4.5 | Anthropic | $15.00 | $75.00 | Best quality, highest cost |
| Claude Sonnet 4.5 | Anthropic | $3.00 | $15.00 | Strong quality, 5x cheaper than Opus |
| GPT-4.1 | OpenAI | $2.00 | $8.00 | Competitive with Sonnet |
| GPT-4.1 Mini | OpenAI | $0.40 | $1.60 | Good budget option |
| Gemini 2.5 Pro | Google | $1.25 | $10.00 | Strong reasoning |
| **Gemini 2.5 Flash** | Google | **$0.15** | **$0.60** | **Best value for most tasks** |
| Gemini 2.0 Flash | Google | $0.10 | $0.40 | Ultra-cheap, slightly less capable |
| DeepSeek R1 | DeepSeek | $0.55 | $2.19 | Strong open-source reasoning |
| Kimi K2 | Moonshot AI | Free* | Free* | Free via OpenRouter (rate-limited) |
| GLM-4 | Zhipu AI | $0.14 | $0.14 | Very affordable via OpenRouter |

*\* Free-tier models on OpenRouter have rate limits and may have queue delays.*

## Cost Optimization Strategies

### 1. Use Claude Sonnet 4.5 instead of Opus 4.5

The default configuration now uses **Claude Sonnet 4.5** as the primary model. It is 5x cheaper than Opus 4.5 on input tokens and 5x cheaper on output tokens, while remaining highly capable for the vast majority of OpenClaw tasks (chat, tool use, planning, coding). This single change can reduce your Anthropic bill by ~80%.

You can switch your primary model via the Gateway UI or CLI:

```bash
sudo -u moltbot -i openclaw config set agents.defaults.model anthropic/claude-sonnet-4.5
```

### 2. Use Gemini Flash for routine tasks

Google's **Gemini 2.5 Flash** costs $0.15/$0.60 per 1M tokens — roughly **20--100x cheaper** than Claude Opus 4.5. It handles straightforward queries, summaries, and simple tool calls well. Add it as a fallback or set it as the primary for cost-sensitive deployments:

```bash
# Set as primary (cheapest option)
sudo -u moltbot -i openclaw config set agents.defaults.model google/gemini-2.5-flash

# Or add as fallback (used when primary is unavailable)
sudo -u moltbot -i openclaw models fallbacks add google/gemini-2.5-flash
```

Google also offers a **free tier** with up to 1,000 requests/day.

### 3. Use OpenRouter for access to cheap and free models

[OpenRouter](https://openrouter.ai/) is an API aggregator that gives you access to 400+ models with a single API key. Benefits:

- **Free models**: Several capable models (Kimi K2, some Llama variants) are available at no cost with rate limits.
- **One API key**: Instead of managing separate keys for DeepSeek, Moonshot, Zhipu, etc., use one OpenRouter key.
- **Auto-routing**: OpenRouter can automatically pick the cheapest provider for a given model.
- **Model scanning**: OpenClaw can discover available models: `openclaw models scan`

To set up OpenRouter:

1. Get an API key at [openrouter.ai/keys](https://openrouter.ai/keys)
2. Add `OPENROUTER_API_KEY=sk-or-...` to your `.env` file
3. Use models with the `openrouter/` prefix:

```bash
# DeepSeek R1 via OpenRouter
sudo -u moltbot -i openclaw models fallbacks add openrouter/deepseek/deepseek-r1

# Kimi K2 via OpenRouter (often free)
sudo -u moltbot -i openclaw models fallbacks add openrouter/moonshotai/kimi-k2

# Scan for free models with tool-use support
sudo -u moltbot -i openclaw models scan
```

### 4. Use Google Gemini directly (free tier)

Google offers a generous free tier for Gemini API access. For light usage, you may not need to pay anything:

- **Free tier**: Up to 1,000 requests/day across Flash models
- **Batch API**: 50% discount for non-urgent async processing
- **Context caching**: Up to 75% savings for repeated large prompts

Get a free API key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey).

### 5. Anthropic Pro/Max subscriptions

Anthropic offers flat-rate subscription plans that include API access. If you are already paying for Claude Pro ($20/mo) or Max ($100/mo), you may be able to use those credits instead of per-token billing. Check [Anthropic's pricing page](https://www.anthropic.com/pricing) for current plan details.

## Recommended Configurations

### Budget-conscious (< $10/month LLM costs)

Use Gemini Flash as primary with free OpenRouter models as fallbacks:

```bash
sudo -u moltbot -i openclaw config set agents.defaults.model google/gemini-2.5-flash
sudo -u moltbot -i openclaw models fallbacks add openrouter/moonshotai/kimi-k2
```

### Balanced (~ $15--$40/month)

Use Claude Sonnet 4.5 as primary with Gemini Flash as fallback:

```bash
sudo -u moltbot -i openclaw config set agents.defaults.model anthropic/claude-sonnet-4.5
sudo -u moltbot -i openclaw models fallbacks add google/gemini-2.5-flash
sudo -u moltbot -i openclaw models fallbacks add openrouter/deepseek/deepseek-r1
```

### Quality-first (~ $50--$150/month)

Use Claude Opus 4.5 as primary with Sonnet as fallback:

```bash
sudo -u moltbot -i openclaw config set agents.defaults.model anthropic/claude-opus-4.5
sudo -u moltbot -i openclaw models fallbacks add anthropic/claude-sonnet-4.5
sudo -u moltbot -i openclaw models fallbacks add google/gemini-2.5-pro
```

## Provider Quick Reference

| Provider | Sign Up | Key Env Var | Strengths |
|----------|---------|-------------|-----------|
| [Anthropic](https://console.anthropic.com/) | Console | `ANTHROPIC_API_KEY` | Best quality (Claude family) |
| [OpenAI](https://platform.openai.com/) | Platform | `OPENAI_API_KEY` | Wide ecosystem, image gen |
| [Google Gemini](https://aistudio.google.com/) | AI Studio | `GEMINI_API_KEY` | Free tier, cheap Flash models |
| [OpenRouter](https://openrouter.ai/) | Dashboard | `OPENROUTER_API_KEY` | 400+ models, free options |

## Further Reading

- [OpenClaw Models Documentation](https://docs.openclaw.ai/concepts/models) — Full model configuration reference
- [OpenRouter Integration Guide](https://openrouter.ai/docs/guides/guides/openclaw-integration) — Detailed OpenRouter setup
- [OpenRouter Pricing](https://openrouter.ai/pricing) — Live model pricing comparison
