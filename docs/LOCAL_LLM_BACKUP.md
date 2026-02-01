# Local LLM Backup Options

This guide addresses the question: **"Can I use a local LLM on my VPS as a backup if API credits run out?"**

The short answer: **Technically yes, but not recommended for CPU-only VPS with limited RAM.** There are better free alternatives.

## Table of Contents

- [OpenClaw's Ollama Support](#openclaws-ollama-support)
- [Resource Requirements](#resource-requirements)
- [Why CPU-Only VPS Isn't Recommended](#why-cpu-only-vps-isnt-recommended)
- [Better Backup Alternatives](#better-backup-alternatives)
- [When Local LLMs Make Sense](#when-local-llms-make-sense)
- [Configuration Examples](#configuration-examples)
- [Performance Comparison](#performance-comparison)

---

## OpenClaw's Ollama Support

OpenClaw has **native support for local LLMs** via [Ollama](https://ollama.com/), which provides an OpenAI-compatible API endpoint. As of early 2026, Ollama is a first-class provider with auto-discovery capabilities.

**Key features:**
- OpenAI-compatible `/v1` endpoint
- Auto-discovery of locally installed models
- Tool-calling support (limited on smaller models)
- Can be run on separate hardware and accessed remotely

**Official documentation:**
- [OpenClaw Ollama Provider Guide](https://docs.openclaw.ai/providers/ollama)
- [GitHub Discussion #2936](https://github.com/openclaw/openclaw/discussions/2936)
- [Feature Request #2838](https://github.com/openclaw/openclaw/issues/2838)

---

## Resource Requirements

### Minimum Requirements for Ollama

| Model Size | RAM Required | Storage | CPU Performance (no GPU) |
|-----------|--------------|---------|--------------------------|
| 1-3B params | 8 GB | 2-6 GB | 2-5 tokens/sec |
| 7B params | 16 GB | 4-14 GB | 5-12 tokens/sec |
| 13B params | 32 GB | 8-26 GB | 3-8 tokens/sec |
| 30B+ params | 64+ GB | 20-60 GB | 1-4 tokens/sec |

*Performance estimates based on CPU-only inference on modern x86 processors (2023-2026).*

**Critical factors:**
- **Memory bandwidth**: Most important for CPU-only inference
- **Quantization**: Q4_0 models use ~4 bits/parameter (smaller, faster, less accurate)
- **Context length**: Longer contexts require exponentially more RAM

### OpenClaw Memory Footprint (from `deploy/lib.sh`)

On your VPS, OpenClaw itself consumes:

| VPS RAM | Node.js Heap | MemoryMax | Available for Ollama |
|---------|--------------|-----------|---------------------|
| 2 GB | 1024 MB | 1536 MB | **~500 MB** |
| 4 GB | 1536 MB | 2048 MB | **~2 GB** |
| 8 GB | 1536 MB | 2048 MB | **~6 GB** |

Formula (from `deploy/lib.sh:119-149`):
- V8 heap = 65% of RAM (floor 256 MB, cap 1536 MB)
- MemoryMax = heap + 512 MB overhead (floor 512 MB, cap 2 GB, max 90% total RAM)

---

## Why CPU-Only VPS Isn't Recommended

### 1. Insufficient RAM

**Your typical VPS** (2-4 GB RAM):
- OpenClaw uses: 1.5-2 GB
- System overhead: 300-500 MB
- **Remaining for Ollama: 500 MB - 2 GB**

**Smallest useful models** (3B params, Q4_0 quantization):
- Require: 2-4 GB RAM minimum
- **Result**: High risk of out-of-memory (OOM) errors

### 2. Extremely Slow Inference

CPU-only performance benchmarks (from community testing):
- **Intel Core i7-1355U** (10 cores, 2023): ~7.5 tokens/sec (7B model)
- **AMD Ryzen 5 4600G** (6 cores, 2020): ~12.3 tokens/sec (7B model)
- **Raspberry Pi 5** (8GB RAM): ~2.3 tokens/sec (Phi-4 14B)

**Shared VPS CPU** (1-2 vCPUs):
- Expected: **<5 tokens/sec** (likely 1-3 tok/sec)
- For comparison: Claude API responds in **<1 second** with full answers
- Local LLM would take **10-60 seconds** for similar responses

### 3. Resource Contention

Running both OpenClaw and Ollama on limited VPS resources:
- **CPU starvation**: Ollama inference blocks OpenClaw requests
- **Memory pressure**: Linux OOM killer may terminate processes
- **No swap**: VPS typically has no swap (except temporary during install)
- **Disk I/O**: Model loading (2-14 GB) saturates shared storage

### 4. Model Limitations

Small models that *might* fit in 2-4 GB RAM:
- **Phi-4 (3.8B)**: Basic reasoning, limited tool-calling
- **Qwen-0.5B**: Very limited capabilities
- **TinyLlama (1.1B)**: Minimal utility for agentic tasks

**Problem**: OpenClaw requires strong tool-calling, memory, and multi-step reasoning—capabilities that small models lack.

---

## Better Backup Alternatives

### Option 1: Free API Tiers (Already Configured!)

Your deployment already includes these in the fallback chain (`moltbot.fallbacks.json`):

#### **Google Gemini 2.5 Flash** (Recommended)
- **Free tier**: 1,000 requests/day
- **Paid tier**: $0.15/0.60 per 1M tokens (20-100x cheaper than Claude Opus)
- **Performance**: Excellent for routine tasks, summaries, simple tool use
- **Response time**: <1 second

**Setup**:
```bash
# Get free API key at https://aistudio.google.com/apikey
echo "GEMINI_API_KEY=your_key_here" >> /opt/moltbot/.env
sudo systemctl restart moltbot-gateway
```

#### **OpenRouter Free Models**
- **Kimi K2** (Moonshot AI): Free tier with rate limits
- **GLM-4-Flash** (Zhipu AI): Free tier available
- **Llama 3.3 70B**: Free on select providers
- Access to **400+ models** via single API key

**Setup**:
```bash
# Get API key at https://openrouter.ai/keys
echo "OPENROUTER_API_KEY=sk-or-..." >> /opt/moltbot/.env
sudo systemctl restart moltbot-gateway
```

### Option 2: Ultra-Budget API Models

Already in your fallback chain:

| Model | Cost (input/output per 1M tokens) | Quality vs Claude |
|-------|-----------------------------------|------------------|
| **DeepSeek R1** | $0.55 / $2.19 | ~85% |
| **GPT-4.1 Mini** | $0.40 / $1.60 | ~80% |
| **Gemini 2.0 Flash** | $0.10 / $0.40 | ~75% |

**Monthly cost at moderate usage** (10M input, 2M output tokens):
- DeepSeek: $5.50 + $4.38 = **~$10/month**
- GPT-4.1 Mini: $4 + $3.20 = **~$7/month**
- Gemini 2.0 Flash: $1 + $0.80 = **~$2/month**

For comparison, Claude Opus 4.5 would cost **$150 + $150 = $300/month** for the same usage.

### Option 3: Verify Your Fallback Configuration

Check if backups are active:

```bash
# SSH to your VPS
cd /opt/moltbot

# View configured fallbacks
sudo -u moltbot openclaw models fallbacks list

# Check which API keys are set
sudo -u moltbot cat .env | grep -E '(GEMINI|OPENROUTER|OPENAI)_API_KEY'
```

**If fallbacks aren't configured**, run:

```bash
sudo /root/moltbot-deployment/deploy/configure-fallbacks.sh
```

This script auto-detects your API keys and configures appropriate fallbacks.

---

## When Local LLMs Make Sense

### Scenario 1: Dedicated Hardware

If you have **separate hardware** with 8GB+ RAM:
- **Home server** (Intel NUC, Mac Mini, old desktop)
- **Raspberry Pi 5** (8GB model)
- **NAS** (Synology, QNAP with 8GB+ RAM)

**Benefits**:
- No resource contention with OpenClaw
- Can use GPU if available
- No API costs for backup scenarios
- Useful for offline/airgapped environments

**Setup**: Run Ollama on separate machine, configure OpenClaw to connect remotely.

### Scenario 2: Upgraded VPS

If you upgrade to **8GB+ RAM VPS**:
- Typical cost: +$10-20/month
- Can run 7B models (Llama 3, Mistral 7B, Qwen)
- Still slow (5-12 tok/sec), but viable for non-urgent queries

**Compare costs**:
- **8GB VPS upgrade**: +$15/month, unlimited queries (slow)
- **Gemini free tier**: $0/month, 1,000 queries/day (fast)
- **Budget APIs**: ~$5-10/month, unlimited queries (fast)

### Scenario 3: Privacy/Compliance Requirements

If you have **strict data residency** requirements:
- Healthcare (HIPAA)
- Finance (PCI-DSS, SOC2)
- Government/defense
- Trade secrets

**In these cases**, local LLM on dedicated hardware may be worth the performance trade-off.

---

## Configuration Examples

### Example 1: Ollama on Same VPS (Not Recommended)

**Only attempt if you have 8GB+ RAM.**

1. **Install Ollama**:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

2. **Pull a model**:
```bash
# Small model (3.8B params, ~2.3 GB)
ollama pull phi4

# Medium model (7B params, ~4.7 GB) - requires 16GB RAM
# ollama pull llama3.3
```

3. **Configure OpenClaw**:

Edit `/opt/moltbot/.env` or use the CLI:

```bash
sudo -u moltbot openclaw models add ollama/phi4 \
  --provider ollama \
  --base-url http://localhost:11434/v1 \
  --api-key ollama-local

# Add as last-resort fallback
sudo -u moltbot openclaw models fallbacks add ollama/phi4
```

4. **Test**:
```bash
# Stop primary providers temporarily to test fallback
sudo -u moltbot openclaw chat "What is 2+2?"
```

### Example 2: Ollama on Separate Hardware (Recommended)

**On your home server** (8GB+ RAM):

1. **Install Ollama**:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

2. **Configure remote access**:
```bash
# Allow connections from VPS
export OLLAMA_HOST=0.0.0.0:11434
systemctl restart ollama
```

3. **Pull models**:
```bash
# Recommended models (7B, good quality/speed balance)
ollama pull llama3.3
ollama pull qwen2.5-coder

# For tool calling (better agentic performance)
ollama pull qwen2.5:14b
```

**On your VPS**:

4. **Configure OpenClaw to use remote Ollama**:
```bash
# Replace YOUR_HOME_IP with your home server's public IP or domain
sudo -u moltbot openclaw models add ollama/llama3.3 \
  --provider ollama \
  --base-url http://YOUR_HOME_IP:11434/v1 \
  --api-key ollama-local

sudo -u moltbot openclaw models fallbacks add ollama/llama3.3
```

5. **Secure the connection** (recommended):
```bash
# Use SSH tunnel to encrypt traffic
ssh -L 11434:localhost:11434 user@YOUR_HOME_IP -N -f

# Then use localhost in config
--base-url http://localhost:11434/v1
```

### Example 3: OpenClaw Config File (Advanced)

For direct configuration, edit OpenClaw's config JSON:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://localhost:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions"
      }
    },
    "fallbacks": [
      "google/gemini-2.5-flash",
      "openrouter/deepseek/deepseek-r1",
      "openrouter/moonshotai/kimi-k2",
      "ollama/llama3.3"
    ]
  }
}
```

**Community tips** (from GitHub Discussion #2936):
- **Disable reasoning parameter**: Most local models don't support the `"reasoning": true` flag
- **Reduce temperature**: Use 0.3-0.7 for agentic tasks (not 0.8+ default)
- **Limit concurrency**: Set `"maxConcurrent": 1` to avoid overwhelming CPU
- **Increase context**: Set `OLLAMA_CONTEXT_LENGTH=8192` minimum

---

## Performance Comparison

### Response Time Benchmarks

| Solution | Setup Time | Response Time | Reliability | Cost/Month |
|----------|-----------|---------------|-------------|-----------|
| **Claude Opus 4.5** (primary) | 0 min | <1 sec | Very High | $50-150 |
| **Claude Sonnet 4.5** (optimized) | 0 min | <1 sec | Very High | $10-30 |
| **Gemini Flash** (free tier) | 5 min | <1 sec | High | $0 (1K/day) |
| **OpenRouter free** (Kimi K2) | 5 min | 1-3 sec | Medium | $0 (rate limits) |
| **Budget APIs** (DeepSeek, GPT-4.1 Mini) | 0 min | <1 sec | High | $5-10 |
| **Ollama on VPS** (2-4GB, CPU-only) | 30-60 min | **10-60 sec** | **Low (OOM risk)** | $0 |
| **Ollama on VPS** (8GB+, CPU-only) | 30-60 min | 5-15 sec | Medium | $0 |
| **Ollama on separate HW** (8GB+, GPU) | 60 min | 2-5 sec | Medium | $0 |

### Quality Comparison (Relative to Claude Opus 4.5 = 100%)

| Model | Reasoning | Tool Use | Multi-step | Memory | Overall |
|-------|-----------|----------|------------|--------|---------|
| Claude Opus 4.5 | 100% | 100% | 100% | 100% | 100% |
| Claude Sonnet 4.5 | 95% | 95% | 95% | 95% | 95% |
| Gemini 2.5 Flash | 80% | 85% | 75% | 70% | 78% |
| DeepSeek R1 | 85% | 80% | 85% | 75% | 81% |
| GPT-4.1 Mini | 75% | 80% | 70% | 75% | 75% |
| **Llama 3.3 70B** (via API) | 75% | 70% | 65% | 60% | 68% |
| **Llama 3.3 7B** (local, Ollama) | 60% | 50% | 45% | 40% | 49% |
| **Phi-4 3.8B** (local, Ollama) | 50% | 40% | 35% | 30% | 39% |

**Key takeaway**: Free/cheap APIs consistently outperform local small models on CPU-only hardware.

---

## Recommendations

### For 2-4 GB VPS (Typical Deployment)

**DO:**
- ✅ Use Gemini free tier (1,000 req/day)
- ✅ Configure OpenRouter free models (Kimi K2, GLM-4-Flash)
- ✅ Add budget API fallbacks (DeepSeek R1, GPT-4.1 Mini)
- ✅ Set up billing alerts on cloud providers
- ✅ Monitor usage via OpenClaw dashboard

**DON'T:**
- ❌ Run Ollama on the same 2-4 GB VPS
- ❌ Attempt to run models <8 GB RAM
- ❌ Expect local 3B models to match GPT-4/Claude quality

### For 8+ GB VPS

**Consider Ollama if**:
- You have consistent >8 GB RAM available
- You're okay with 5-15 sec response times
- You have offline/privacy requirements
- API costs are genuinely prohibitive (unusual given free tiers)

**But still prefer**:
- Free API tiers first (faster, higher quality)
- Budget APIs second (cheapest per-query at scale)
- Local LLM as true last resort

### For Separate Hardware

**Strongly recommended if**:
- You have spare hardware (8GB+ RAM, ideally GPU)
- You want true offline capability
- You have data residency requirements
- You're experimenting/learning about local LLMs

**Best models for local deployment** (7-14B):
- **Llama 3.3 8B/70B**: Best general-purpose
- **Qwen 2.5 Coder 14B**: Best for code/technical tasks
- **Mistral 7B**: Fast, good quality
- **DeepSeek Coder 6.7B**: Specialized for code

---

## Troubleshooting

### Out of Memory (OOM) Errors

**Symptoms**:
- Ollama crashes with "killed" message
- OpenClaw Gateway becomes unresponsive
- System logs show OOM killer activity

**Solution**:
```bash
# Check memory usage
free -h
htop

# If Ollama is using too much RAM, use smaller model
ollama pull phi4  # 3.8B instead of 7B

# Or switch to API fallback
sudo -u moltbot openclaw config set agents.defaults.model google/gemini-2.5-flash
```

### Slow Response Times

**Symptoms**:
- Local LLM taking >30 seconds per response
- Chat interface timing out

**Solutions**:
1. **Reduce context length**:
```bash
export OLLAMA_CONTEXT_LENGTH=4096  # Down from 8192
```

2. **Use smaller/faster model**:
```bash
ollama pull gemma2:2b  # 2B params, very fast
```

3. **Switch to API temporarily**:
```bash
# Temporarily move Ollama to end of fallback list
sudo -u moltbot openclaw models fallbacks remove ollama/llama3.3
sudo -u moltbot openclaw models fallbacks add ollama/llama3.3  # Re-adds at end
```

### Tool Calling Failures

**Symptoms**:
- Model doesn't execute tools/commands
- Returns text instead of JSON function calls

**Solution**:
- Most small models (<13B) have poor tool-calling
- Use API models for agentic tasks requiring tools
- Or upgrade to 14B+ local model (requires 32GB+ RAM)

---

## Conclusion

**For 99% of users**: Use free/cheap API fallbacks instead of local LLMs on VPS.

**Reality check**:
- **Gemini Flash free tier** = 1,000 queries/day, <1 sec response, 80% quality
- **Ollama on 2GB VPS** = High crash risk, 10-60 sec response, 40% quality

**When to use local LLM**:
- You have **separate hardware** (8GB+ RAM, ideally GPU)
- You need **offline capability** or strict privacy
- You're **learning/experimenting** with local AI

**When NOT to use local LLM**:
- Your VPS has <8 GB RAM
- You care about response speed
- Free API tiers meet your needs (they probably do)

See also:
- [COST_EXPECTATIONS.md](./COST_EXPECTATIONS.md) - API pricing and optimization
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common deployment issues

---

## Additional Resources

**Official Documentation**:
- [OpenClaw Ollama Guide](https://docs.openclaw.ai/providers/ollama)
- [OpenClaw Configuration Reference](https://docs.openclaw.ai/)

**Community Discussions**:
- [How to use Ollama in moltbot?](https://github.com/openclaw/openclaw/discussions/2936)
- [Local LLM discussion](https://github.com/openclaw/openclaw/discussions/1794)
- [vLLM and Ollama as first-class providers](https://github.com/openclaw/openclaw/issues/2838)

**Ollama Resources**:
- [Ollama Installation](https://ollama.com/)
- [Ollama OpenAI Compatibility](https://ollama.com/blog/openai-compatibility)
- [Ollama Model Library](https://ollama.com/library)

**Performance Benchmarks**:
- [Ollama Hardware Guide](https://www.arsturn.com/blog/ollama-hardware-guide-what-you-need-to-run-llms-locally)
- [Ollama VRAM Requirements Guide](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)
- [CPU Performance Data](https://forum.level1techs.com/t/ollama-on-cpu-performance-some-data-and-a-request-for-more/214896)
