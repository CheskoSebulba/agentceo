# AgentCEO

> An AI that runs your business while you sleep.

Give it a name, a business type, and optionally a server. It ships products, manages deployments, writes code, and sends you a morning report. You step in when it needs money, credentials, or a strategic call — everything else it handles on its own.

Built on [Claude Code](https://claude.ai/code). Pure bash. No dependencies.

![AgentCEO demo](demo.gif)

---

## Quick Start

### Prerequisites

- Linux or macOS
- Claude Code ≥ 1.0 — [install guide](https://claude.ai/code)

**New to Claude Code?** Two commands:
```bash
npm install -g @anthropic-ai/claude-code
claude   # follow the auth prompts
```

### Step 1 — Clone and create your agent

```bash
git clone https://github.com/CheskoSebulba/agentceo.git
cd agentceo
bash create_agent.sh
```

Already have the repo? Update it first:
```bash
cd agentceo && git pull
bash create_agent.sh
```

Follow the prompts. Takes about 2 minutes. At the end, select **y** to launch immediately.

### Step 2 — Source your shell (if you skipped launch)

```bash
source ~/.bashrc   # or ~/.zshrc if you use zsh
```

### Step 3 — Launch

```bash
aria
```

The agent reads its memory files, announces its status, and resumes work — no prompting needed.

**First launch only:** the script prints a short onboarding prompt at the end of setup. Paste it into Claude Code on first launch to bootstrap the agent's identity. After that, the launcher handles everything automatically.

---

## What `create_agent.sh` Does

One command creates a fully configured autonomous agent:

```
Agent name (lowercase, no spaces) e.g. walter: aria
Display name e.g. Walter: Aria
Company name e.g. Acme Corp: Acme Store
Starter kit (1=SaaS, 2=Content, 3=E-commerce, 4=Custom): 1
Staging server hostname e.g. aria.local (Enter to skip): aria.local
Staging server SSH username: deploy
Launch emoji (Enter for 🤖): 🦾
```

It creates:

```
/home/youruser/aria/
├── CLAUDE.md                        # Agent identity + mandatory protocols
├── .env                             # Credentials (chmod 600, never committed)
├── start_aria.sh                    # Launcher with session resume
├── memory/
│   ├── core.md                      # Business state (pre-filled by starter kit)
│   ├── shutdown_state.md            # Live task tracker
│   ├── crash_recovery.md            # Recovery playbook
│   ├── pending_backer_actions.md    # Items waiting for your input
│   └── agent_onboarding_template.md # Full operating protocols
├── logs/
│   └── YYYY-MM-DD.md                # Daily activity log
├── scripts/
│   └── telegram_notify.sh           # Backer notifications (optional)
├── skills/
└── templates/
```

And adds a shell alias so `aria` launches the agent instantly.

---

## Starter Kits

Pick a business model during setup and get a fully populated `core.md` — with revenue tracking fields, a current sprint, and a concrete first task — instead of starting with `Mission: TBD`.

| Kit | Mission | Memory includes |
|-----|---------|----------------|
| **SaaS** | Subscription product, MRR tracking | MRR, paying customers, churn, revenue goal |
| **Content** | Blog/newsletter, sponsorship revenue | Subscriber count, sponsor/affiliate/product revenue |
| **E-commerce** | Product sales, order handling | Orders, AOV, refunds, revenue goal |
| **Custom** | Enter your own mission | Standard memory structure |

Each kit also sets the agent's first task — a specific research or planning exercise to do before building anything — so it starts working immediately.

---

## Included Tools

| File | Purpose |
|------|---------|
| `create_agent.sh` | Creates a new agent — run once per agent |
| `upgrade_agent.sh` | Upgrades existing agents to the current framework version |
| `list_agents.sh` | Lists all AgentCEO agents on the machine with status |
| `telegram_notify.sh` | Sends morning reports and alerts to your phone via Telegram |
| `weekly_summary.sh` | Compiles a 7-day digest of agent activity |
| `start_agent_template.sh` | Reference launcher for custom configurations |
| `agent_onboarding_template.md` | Full operating protocols — copied into each agent's memory |
| `kits/` | Starter kit definitions for each business model |

### Upgrading existing agents

If you have agents created with an older version:

```bash
bash upgrade_agent.sh agentname
```

It detects what's outdated, shows a plan, creates a backup, and applies only the changes needed. It never touches `core.md`, logs, or `.env` contents.

### Listing all agents

```bash
bash list_agents.sh
```

Shows every agent on the machine: company, status, last active date, current task, and whether the staging server is reachable.

---

## The Staging Server

### Skip it if you just want to try the framework

Press Enter at the hostname prompt. Your agent works locally — writing code, managing files, planning. You can add a server any time later.

### What it is

A staging server is a Linux machine your agent can SSH into. It's where the agent deploys websites, runs services, hosts APIs, and operates anything that needs to be live on the internet.

### What your agent can do with it

- Deploy and update websites
- Start and stop web servers (nginx, Node, Python)
- Run cron jobs autonomously
- Host live products and APIs
- Check services are running on every startup
- Recover from crashes and restart services

### What counts as a staging server

Anything running Linux that you can SSH into:

| Option | Cost | Good for |
|--------|------|----------|
| DigitalOcean / Linode / Vultr droplet | ~$4–6/mo | Most users — clean, easy |
| Raspberry Pi on your local network | ~$0 | Local experimentation |
| Old laptop running Ubuntu | ~$0 | Same as above |
| Any VPS you already have | ~$0 | Reuse existing infra |

### DigitalOcean setup (5 minutes)

1. Create a Ubuntu 22.04 droplet ($6/mo is enough)
2. Note the IP — use it as the hostname, or point a domain at it
3. Create a user: `adduser aria && usermod -aG sudo aria`
4. Run `bash create_agent.sh` — it generates and copies the SSH key automatically

---

## How Agents Work

### Startup Protocol

Every time an agent launches, it automatically — without being asked:

1. Reads all memory files fresh from disk
2. Checks the staging server is reachable (if configured)
3. Announces who it is and exactly where it left off
4. Lists the top 3 priorities right now
5. Resumes work

No "what should I work on?" — it figures that out from the files.

### Session Persistence

The launcher saves the Claude Code session ID and resumes it on next launch via `--resume`. If no prior session exists, `--continue` picks up the most recent conversation.

On every launch, the launcher automatically sends `"[Agent], execute your startup routine now."` as the first message — so the agent reads its memory and announces status without any prompting.

> **Note:** When using `--resume`, the prior session context loads before the startup message fires. This is expected — wait for the startup routine to complete before typing anything.

### Permissions Model

Every agent launcher passes `--dangerously-skip-permissions` to Claude Code. This flag disables per-tool confirmation prompts so the agent can work autonomously without stopping to ask for approval on every file read or bash command. Without it, the agent would pause on every action and require human confirmation — defeating the purpose.

The security boundary is the directory scope enforced in `CLAUDE.md`: each agent is restricted to its own directory and staging server, and will not touch other agents' files or credentials.

If you prefer manual approval on sensitive operations, remove the flag from the generated `start_<agent>.sh` and use `settings.json` to allowlist specific commands.

### Memory System

| File | Updated | Purpose |
|------|---------|---------|
| `core.md` | On major changes | Revenue, products, infrastructure, key decisions |
| `shutdown_state.md` | After every action | Exact current task — enables mid-task crash recovery |
| `crash_recovery.md` | On infra changes | How to SSH in, restart services, redeploy |
| `pending_backer_actions.md` | When escalating | Items waiting for your input |
| `logs/YYYY-MM-DD.md` | After every task | Full audit trail |

### Human Escalation

Your **backer** is you — the human who owns and runs the agent. The agent works autonomously but escalates when:

- A credential or API key is needed
- About to spend money
- Stuck after 2 attempts
- A major strategic decision needs approval
- Something has gone wrong that affects a live product

Everything else it handles on its own.

### Telegram Notifications (optional)

Each agent ships with `telegram_notify.sh`. Point it at a Telegram bot and the agent sends:

- Morning report on startup — status, priorities, blockers
- Evening summary on shutdown — what was done, what's next
- Alerts when something needs your attention

Setup: create a bot via [@BotFather](https://t.me/BotFather), add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` to `.env`.

---

## Configuration

Override the default GitHub username without editing the file:

```bash
AGENTCEO_GITHUB_USER=your-username bash create_agent.sh
```

---

## Security

- All credentials live in `.env` (chmod 600) — never in logs, memory, or git
- `memory/` and `logs/` are in `.gitignore` — infra details stay local
- SSH keys stored in `~/.ssh/` — never committed
- SSH password not echoed to terminal; not passed via process arguments
- The onboarding protocol explicitly prohibits logging any credential
- See [SECURITY.md](SECURITY.md) for the full threat model and known limitations

---

## Troubleshooting

**`command not found` after setup**
The alias was added to your shell config but the current session doesn't see it yet.
```bash
source ~/.bashrc   # or source ~/.zshrc
```

**`❌ Claude Code not found`**
Claude Code isn't installed or isn't in your PATH.
```bash
npm install -g @anthropic-ai/claude-code
# if using nvm: nvm use --lts first
```

**SSH key copy failed**
The script printed a manual copy command — run it:
```bash
ssh-copy-id -i ~/.ssh/aria_staging.pub deploy@aria.local
```

**`sshpass` not available**
```bash
# Ubuntu/Debian
sudo apt-get install sshpass
# macOS
brew install sshpass
# Arch
sudo pacman -S sshpass
```

**Agent directory already exists**
The script prompts before overwriting. Business data (`core.md`, logs, `.env`) is preserved. Only framework files are replaced.

**`--resume` loads old context before startup message**
This is expected. The prior session loads first, then the startup message fires. Wait for the startup routine to finish before typing.

**Agent launches with wrong session / `unknown option` error**
Cause: the command `ls -t ~/.claude/projects/ | head -1` captures the most recently active Claude project across *all* agents on the machine — not the current agent. On multi-agent machines this causes session ID collisions.
```bash
# Immediate fix — clear the bad session ID:
echo "" > ~/agentname/memory/last_session.txt
```
Prevention: never use `ls -t ~/.claude/projects/` to capture session IDs. Session IDs must be written by the agent itself during its session.

---

## Known Issues

- **Session ID not written by launcher** — the session ID is written by the agent itself during its session, not by the launcher on exit. If a session crashes before the agent writes it, `--resume` silently falls back to `--continue`.
- **Agent name collision** — creating two agents with the same name overwrites the first. The script prompts before overwriting.

---

## Real Agents Running This Framework

| Agent | Company | Role |
|-------|---------|------|
| sam | AgentCEO | Framework maintenance, this repo |

If you've built an agent with this framework, open a PR to add it.

---

## Contributing

Issues and pull requests welcome.

---

## License

MIT
