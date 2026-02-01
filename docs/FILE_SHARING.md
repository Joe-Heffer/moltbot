# File Sharing Between Users and Agents in OpenClaw

> **Issue Reference**: [#76](https://github.com/openclaw/openclaw/issues/76) - Best practices for sharing multi-file projects

## Overview

OpenClaw agents access files through a dedicated **workspace directory** that serves as the agent's working environment and persistent memory. This document outlines the recommended approaches, best practices, and security considerations for sharing files and projects with agents.

---

## Workspace Architecture

### Standard Workspace Structure

OpenClaw uses a canonical directory structure for agent workspaces, typically located at `~/.openclaw/workspace` or `~/clawd/`:

```
~/clawd/
├── AGENTS.md          # Operating instructions (keep under 5KB)
├── SOUL.md            # Persona and communication style (keep under 5KB)
├── USER.md            # User context and preferences
├── TOOLS.md           # Local tool documentation
├── IDENTITY.md        # Agent name, branding, emoji
├── HEARTBEAT.md       # Periodic maintenance tasks
├── MEMORY.md          # Curated long-term knowledge
├── memory/            # Daily logs directory
│   └── YYYY-MM-DD.md  # Append-only daily records
├── skills/            # Workspace-specific skill definitions
├── DECISIONS.md       # (Optional) Major architectural choices
└── RUNBOOK.md         # (Optional) Operational procedures
```

**Key Principles**:
- The workspace is the agent's **home and only working directory** for file operations
- It should be treated as **private memory** for the agent
- Each file is injected into model requests, so keep them concise (20,000 character limit enforced)

---

## File Sharing Methods

### 1. Agent Workspace Directory (Recommended for Most Use Cases)

**When to use**: Single-user scenarios, private projects, agent memory persistence

**Setup**:
- Files are placed in the agent's workspace directory
- Agent has read/write access by default
- Workspace persists across restarts

**Example** (native installation):
```bash
# Copy project files to workspace
cp -r /path/to/project/* ~/.openclaw/workspace/

# Agent can now access files directly
```

**Best Practices**:
- Keep the workspace in a **private Git repository** for backup and recovery
- Use daily memory logs (`memory/YYYY-MM-DD.md`) for raw operational records
- Curate important decisions into `MEMORY.md` for long-term reference
- **Do NOT store**: raw chat dumps, sensitive credentials, large media files

---

### 2. Docker Volume Mounts (Recommended for Shared Projects)

**When to use**: Docker deployments, team projects, sharing existing codebases

**Setup using `OPENCLAW_EXTRA_MOUNTS`**:

```bash
# Environment variable format: source:target:mode,source:target:mode
export OPENCLAW_EXTRA_MOUNTS="$HOME/projects:/home/node/projects:rw,$HOME/.codex:/home/node/.codex:ro"

# Rerun setup script to apply changes
./docker-setup.sh
```

**Mount Modes**:
- `:ro` - Read-only (agent can read but not modify)
- `:rw` - Read-write (agent can read and modify)

**Example Configuration**:

```bash
# Share a specific project (read-write)
-v /home/user/my-project:/home/node/workspace/project:rw

# Share documentation (read-only)
-v /home/user/docs:/home/node/docs:ro

# Share workspace for persistence
-v ~/.openclaw/workspace:/home/node/.openclaw/workspace:rw
```

**Security Best Practices**:
- ✅ Mount **only directories the agent needs**
- ✅ Use **read-only (`:ro`)** when agent doesn't need write access
- ✅ Create a **dedicated workspace folder** (e.g., `~/openclaw_workspace`)
- ❌ **NEVER mount**: `~/.ssh`, `~/.kube`, entire home directory, `/var/run/docker.sock`
- ❌ **NEVER use** `--privileged` flag
- ❌ **Avoid** mounting parent directories with sensitive subfolders

---

### 3. Named Volumes for Persistence

**When to use**: Container recreation, data persistence across updates

**Setup**:

```bash
# Set named volume for /home/node
export OPENCLAW_HOME_VOLUME=openclaw_home

# Creates and mounts a Docker volume
./docker-setup.sh
```

**Benefits**:
- Data persists across container recreation
- Automatic backup compatibility
- Cleaner separation from host filesystem

---

## Multi-Agent Considerations

### Workspace Isolation

**⚠️ CRITICAL**: Never share an `agentDir` across multiple agents

**Problems with shared workspaces**:
- Authentication collisions
- Session conflicts
- Context contamination
- Memory corruption

**Recommended Architecture**:

```
~/openclaw/
├── agent-dev/          # Development agent workspace
│   ├── AGENTS.md
│   └── memory/
├── agent-prod/         # Production monitoring agent
│   ├── AGENTS.md
│   └── memory/
└── agent-research/     # Research agent workspace
    ├── AGENTS.md
    └── memory/
```

### Shared Project Access

For multiple agents working on the same project:

```bash
# Each agent gets its own workspace but shares the project directory (read-only)
docker run -v ~/project:/home/node/shared-project:ro -v ~/agent1-workspace:/home/node/.openclaw/workspace:rw openclaw/openclaw
docker run -v ~/project:/home/node/shared-project:ro -v ~/agent2-workspace:/home/node/.openclaw/workspace:rw openclaw/openclaw
```

---

## Best Practices Summary

### File Organization

1. **Bootstrap Files** (`AGENTS.md`, `SOUL.md`, etc.):
   - Keep under **5KB each** (injected into every request)
   - Use concise, actionable instructions
   - Load detailed instructions on-demand via file reading tools

2. **Memory Management**:
   - **Daily logs**: Append-only `memory/YYYY-MM-DD.md` files
   - **Curated memory**: `MEMORY.md` for important long-term knowledge
   - **Memory flush**: System automatically writes durable notes before compaction

3. **Skill Definitions**:
   - Store in `skills/` directory
   - Keep descriptions brief in bootstrap
   - Load full instructions just-in-time

### Security

1. **Principle of Least Privilege**:
   - Mount only necessary directories
   - Use read-only mounts when possible
   - Create dedicated workspace folders

2. **Sensitive Data**:
   - Use placeholders in workspace files
   - Store real secrets in password managers or environment variables
   - Never store SSH keys, API keys, or credentials in workspace
   - Exclude secrets from backups (`.env`, `*.key`, `credentials.*`)

3. **Docker Hardening**:
   - Follow systemd sandboxing patterns (see [SECURITY.md](SECURITY.md))
   - Use `NoNewPrivileges=yes` in service definitions
   - Implement `ProtectSystem=strict` and `ProtectHome=read-only`
   - See [Composio hardening guide](https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup) for additional Docker security

### Version Control

**Recommended Git Setup**:

```bash
# Initialize private Git repository for workspace
cd ~/.openclaw/workspace
git init
git remote add origin git@github.com:username/openclaw-workspace-private.git

# .gitignore template
cat > .gitignore << EOF
*.env
*.log
*.tmp
node_modules/
.DS_Store
# Add other sensitive patterns
EOF

git add .
git commit -m "Initial workspace setup"
git push -u origin main
```

**Benefits**:
- Backup and disaster recovery
- Change tracking for agent decisions
- Rollback capability
- Team collaboration (with care)

---

## Integration with Backup System

This deployment repository includes automated backup capabilities (see [AGENT_MEMORY_BACKUP.md](AGENT_MEMORY_BACKUP.md)):

**Automated Backup Locations**:
- `/home/openclaw/clawd` (legacy)
- `/home/openclaw/clawd/memory` (current memory files)
- `/home/openclaw/.config/openclaw` (configuration)
- `/home/openclaw/.local/share/openclaw` (application data)

**Backup Methods**:
- Git repositories (GitHub, GitLab, Bitbucket)
- Cloud storage via rclone (Google Drive, Dropbox, S3)
- Daily automated backups at 3 AM (systemd timer)

**Privacy Exclusions** (automatic):
- `.env` files
- `*.log` files
- `*.tmp` files
- `node_modules/`

---

## Common Use Cases

### Use Case 1: Code Review

```bash
# Mount project read-only for analysis
docker run -v ~/my-app:/home/node/review:ro openclaw/openclaw

# In chat: "Review the code in /home/node/review and suggest improvements"
```

### Use Case 2: Document Processing

```bash
# Mount documents folder
docker run -v ~/Documents:/home/node/docs:ro openclaw/openclaw

# In chat: "Summarize all PDFs in /home/node/docs"
```

### Use Case 3: Multi-File Project Development

```bash
# Mount project with read-write access
docker run -v ~/dev/project:/home/node/workspace/project:rw openclaw/openclaw

# Agent can read, edit, and create files in the project
```

### Use Case 4: Shared Team Project

```bash
# Team repository (read-only to prevent accidental changes)
# Agent's own workspace (read-write)
docker run \
  -v ~/shared-repo:/home/node/team-project:ro \
  -v ~/.openclaw/agent1:/home/node/.openclaw/workspace:rw \
  openclaw/openclaw
```

---

## Interactive Sandbox Environments

**Question**: Is there an interactive sandbox environment for sharing?

**Answer**: OpenClaw's approach is **workspace-centric rather than sandbox-based**:

1. **Not a Traditional Sandbox**: OpenClaw doesn't provide a shared interactive sandbox environment like Jupyter notebooks or REPL environments

2. **Docker as Isolation**: Docker containers provide **process isolation** and **filesystem sandboxing**, but not interactive shared environments

3. **Workspace Model**: The agent's workspace serves as a **persistent, versioned, file-based** collaboration space

4. **Tool-Based Interaction**: Agents use shell commands, file operations, and API calls to interact with shared resources

**Alternative Solutions**:

For interactive collaboration needs:
- **Jupyter Integration**: Mount Jupyter workspace and let agent interact via nbconvert/papermill
- **Git-Based Workflow**: Agent commits changes, user reviews via Git
- **Shared Mount**: Both user and agent work in same directory with file watching
- **API-Based Tools**: Use HTTP APIs or databases as shared data layers

---

## Troubleshooting

### Agent Can't Access Files

**Symptoms**: "File not found" or permission errors

**Solutions**:
1. Verify mount paths match between host and container
2. Check file permissions (`chmod` if needed)
3. Ensure volume mount syntax is correct (`:ro` or `:rw`)
4. Rerun `docker-setup.sh` after changing `OPENCLAW_EXTRA_MOUNTS`

### Workspace Corruption

**Symptoms**: Agent forgets context, sessions conflict

**Solutions**:
1. Ensure each agent has separate workspace directory
2. Check for concurrent access to same workspace
3. Restore from Git backup if corrupted
4. Review memory files for size limits (20,000 chars per file)

### Performance Issues

**Symptoms**: Slow file operations, high memory usage

**Solutions**:
1. Reduce bootstrap file sizes (target <5KB each)
2. Use daily memory logs instead of large single files
3. Archive old memory logs to separate directory
4. Use `.gitignore` to exclude large binaries from workspace

---

## References and Further Reading

### Official Documentation
- [Agent Workspace Concepts](https://docs.openclaw.ai/concepts/agent-workspace) - Workspace architecture and best practices
- [Docker Installation](https://docs.openclaw.ai/install/docker) - Docker setup and volume configuration
- [Best Practices for Multi-Agent Orchestration](https://github.com/openclaw/openclaw/issues/4561) - Community discussion on scaling

### Related Guides
- [AGENT_MEMORY_BACKUP.md](AGENT_MEMORY_BACKUP.md) - Backup configuration and automation
- [SECURITY.md](SECURITY.md) - Security hardening and risk assessment
- [CONFIGURATION.md](CONFIGURATION.md) - Environment variables and settings
- [Composio Security Guide](https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup) - Docker hardening

### External Resources
- [What is OpenClaw? (DigitalOcean)](https://www.digitalocean.com/resources/articles/what-is-openclaw) - Platform overview
- [OpenClaw Complete Guide 2026](https://www.nxcode.io/resources/news/openclaw-complete-guide-2026) - Comprehensive tutorial
- [OpenClaw GitHub Repository](https://github.com/openclaw/openclaw) - Source code and issues

---

## Contributing

Found better practices or have questions? Please contribute to the discussion:
- [Issue #76: File Sharing Best Practices](https://github.com/openclaw/openclaw/issues/76)
- [OpenClaw GitHub Issues](https://github.com/openclaw/openclaw/issues)
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines

---

**Last Updated**: 2026-02-01
**Maintainer**: OpenClaw Community
**License**: MIT
