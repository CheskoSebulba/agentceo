# AgentCEO

> A bash framework for spinning up autonomous AI CEO agents on Claude Code.

Each agent gets its own identity, persistent memory, session resumption, SSH server access, Telegram reporting, and startup/shutdown protocols — so they can run real businesses autonomously and report back to their human backer.

---

## Quick Start

### Prerequisites

- Linux (any distro)
- [Claude Code](https://claude.ai/code) installed and authenticated

### Install

```bash
git clone https://github.com/CheskoSebulba/agentceo.git
cd agentceo
bash create_agent.sh
```

Follow the prompts. Then launch your agent by typing its name:

```bash
aria
```

---

## What `create_agent.sh` Does

One command creates a fully configured autonomous agent:

```
Agent name (lowercase, no spaces) e.g. walter: aria
Display name e.g. Walter: Aria
Company name e.g. Acme Corp: Acme Store
Mission (Enter for TBD): Build and sell digital products
Staging server hostname e.g. aria.local (Enter to skip): aria.local
Staging server SSH username: deploy
Launch emoji (Enter for 🤖): 🦾
```

It then creates:

```
/home/youruser/aria/
├── CLAUDE.md                        # Agent identity + mandatory protocols
├── .env                             # Credentials (chmod 600, never committed)
├── start_aria.sh                    # Launcher with session resume
├── memory/
│   ├── core.md                      # Business state
│   ├── shutdown_state.md            # Live task tracker
│   ├── crash_recovery.md            # Recovery playbook
│   └── agent_onboarding_template.md # Full operating protocols
├── logs/
│   └── YYYY-MM-DD.md                # Daily activity log
├── scripts/
├── skills/
└── templates/
```

And adds a shell alias so `aria` launches the agent instantly.

---

## How Agents Work

### Startup Protocol

Every time an agent launches, it automatically — without being asked:

1. Reads all memory files fresh from disk
2. Checks all configured servers are reachable
3. Announces who it is and exactly where it left off
4. Lists the top 3 priorities right now
5. Resumes work

No "what should I work on?" — it figures that out from the files.

### Session Persistence

The launcher script saves the Claude Code session ID on exit and resumes it on next launch via `--resume`. If no prior session exists, `--continue` picks up the most recent conversation. The agent never loses context.

The launcher also automatically passes `"[Agent], execute your startup routine now."` as the first message on every launch — both resume and fresh paths — so the agent reads its memory files and announces status without any manual prompting.

> **Note:** When using `--resume`, the prior session context loads before the startup message fires. This is expected. Wait for the agent to complete its startup routine before typing anything.

### Memory System

| File | Updated | Purpose |
|------|---------|---------|
| `core.md` | On major changes | Revenue, products, infrastructure, key decisions |
| `shutdown_state.md` | After every action | Exact current task — enables mid-task crash recovery |
| `crash_recovery.md` | On infra changes | How to SSH in, restart services, redeploy |
| `session_context.md` | Every session | What was agreed with the backer |
| `logs/YYYY-MM-DD.md` | After every task | Full audit trail |

### Boundaries

Each agent is scoped to its own directory and staging server. It will never read, write, or touch another agent's files, credentials, or infrastructure.

### Human Escalation

Agents only escalate to their backer when:
- A credential or API key is needed
- About to spend money
- Stuck after 2 attempts
- A major strategic decision needs approval
- Something has gone wrong that affects a live product

Everything else they handle autonomously.

---

## Included Files

| File | Purpose |
|------|---------|
| `create_agent.sh` | Main creator — run once per agent |
| `start_agent_template.sh` | Reference launcher template |
| `agent_onboarding_template.md` | Full operating protocols injected into each agent's memory |

---

## Configuration

`create_agent.sh` detects the `claude` binary automatically:

```bash
CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude")
```

The GitHub username used in generated files is set at the top of `create_agent.sh`:

```bash
AGENTCEO_GITHUB_USER="${AGENTCEO_GITHUB_USER:-CheskoSebulba}"
```

Override it without editing the file:

```bash
AGENTCEO_GITHUB_USER=your-username bash create_agent.sh
```

---

## Security

- All credentials live in `$AGENT_DIR/.env` — never in logs, memory, or git
- `.env` is created with `chmod 600`
- `.env` is added to `.gitignore` by convention
- SSH keys are stored in `$HOME/.ssh/` — never committed
- The onboarding protocol explicitly prohibits logging any credential

---

## Real Agents Running This Framework

This framework was built by running it. The agents below operate on this codebase in production:

| Agent | Company | Role |
|-------|---------|------|
| aria | Acme Store | E-commerce, product, marketing |
| lexi | Example Agency | Consulting, web presence |
| nova | Example SaaS | Email product |
| sam | AgentCEO | This repo — framework maintenance |

---

## Contributing

Issues and pull requests welcome.

If you've built an agent with this framework and want it listed above, open a PR.

---

## License

MIT
