# Use Cases

Moltbot is a self-hosted, open-source personal AI assistant that connects to messaging platforms and executes real tasks on your machine. Unlike traditional chatbots that only produce text, Moltbot runs shell commands, manages files, browses the web, and automates workflows autonomously. It is powered by LLMs (Anthropic Claude recommended, OpenAI supported) and communicates through WhatsApp, Telegram, Slack, Discord, Signal, and many other channels.

## Personal Productivity

Moltbot excels as a general-purpose assistant that stays available 24/7 across your preferred messaging apps. Typical productivity use cases include:

- **Calendar and scheduling** -- managing appointments, setting reminders, and coordinating across time zones. Community skills integrate with Google Calendar, CalDAV, and iCloud Calendar.
- **Email triage** -- screening incoming mail, drafting replies, and surfacing important threads. Gmail Pub/Sub integration enables real-time notifications.
- **Task management** -- creating and updating items in Notion, Todoist, Linear, or Jira through natural language commands.
- **File organization** -- sorting downloads, renaming batches of files, and classifying documents into folder structures.
- **Document processing** -- extracting data from receipts, invoices, or images and structuring it into spreadsheets or databases.

The official documentation describes Moltbot as an assistant that can "perform tasks, manage your calendar, browse the web, organize files, and run terminal commands" ([docs.molt.bot](https://docs.molt.bot/start/getting-started)).

## Developer and DevOps Workflows

Moltbot has deep integration with development tools:

- **Remote server management** -- monitor services, tail logs, restart processes, and deploy code on remote machines via messaging apps.
- **CI/CD orchestration** -- trigger builds, check pipeline status, and receive notifications on failures.
- **Git workflows** -- create branches, review diffs, manage pull requests, and enforce conventional commits through community skills.
- **Code generation and refactoring** -- leverage the underlying LLM to generate boilerplate, write tests, or refactor existing code.
- **Database operations** -- query databases, run migrations, and generate reports using DuckDB or other CLI tools.

The [MoltHub skills directory](https://docs.molt.bot/tools/skills) lists 40+ DevOps and cloud skills covering Azure CLI, Docker, Kubernetes, Cloudflare, Vercel, and more.

## Home Automation and IoT

The community has built 30+ skills for smart home control:

- **Home Assistant integration** -- control lights, thermostats, locks, and cameras through conversational commands.
- **Tesla vehicle management** -- lock/unlock, adjust climate, monitor charge status, and locate the vehicle.
- **3D printer management** -- monitor print jobs, adjust temperatures, and receive completion notifications.
- **Proactive monitoring** -- Moltbot can watch directories, sensor readings, or system metrics and reach out when thresholds are exceeded, without being prompted.

## Media and Content Management

- **Music and streaming** -- control Spotify, Plex, or YouTube playback.
- **Image and video generation** -- invoke ComfyUI, DALL-E, or Figma through conversational commands.
- **Transcription and speech** -- process audio with Whisper, generate voice responses with ElevenLabs, and take voice commands on macOS/iOS.
- **Podcast and video workflows** -- download, transcribe, summarize, and tag media files.

## Finance and Tracking

- **Budget management** -- track expenses, categorize transactions, and generate spending reports.
- **Cryptocurrency monitoring** -- watch portfolio balances and receive alerts on price movements.
- **Invoice processing** -- extract line items from invoices and reconcile against records.

## Research and Knowledge Management

- **Web research** -- browse the web, extract information, and compile summaries using a dedicated Chromium instance.
- **Personal knowledge bases** -- integrate with Obsidian, Logseq, Bear, or Apple Notes for storing and retrieving information.
- **Academic research** -- search papers, extract citations, and organize references.

The skills marketplace lists search integrations with Brave Search, Exa AI, Kagi, and Tavily.
