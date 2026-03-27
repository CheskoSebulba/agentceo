# Changelog

## v1.8.2 — 2026-03-27

### Fixed
- **`telegram_notify.sh` never copied**: path was `$SCRIPT_DIR/../telegram_notify.sh` (goes up from repo root — file doesn't exist there); corrected to `$SCRIPT_DIR/telegram_notify.sh` — every new agent now gets `scripts/telegram_notify.sh`
- **Interrupt trap destroys existing agent on overwrite**: `rm -rf "$AGENT_DIR"` on INT/TERM would delete all data (logs, `.env`, `core.md`) if setup was interrupted during an overwrite; trap now only cleans up on fresh installs
- **Confirm block shows full mission text for kit users**: now shows `Kit: saas/content/ecommerce`; long mission paragraph only shown for custom agents
- **Stale version comment**: header comment updated from `1.6.0` to current version

---

## v1.8.1 — 2026-03-27

### Fixed
- **First launch crash**: removed `--continue` from fresh session path in generated launcher and `start_agent_template.sh` — `--continue` requires a prior conversation to exist and errors with `Input must be provided through stdin or as a prompt argument when using --print` on machines with no prior Claude Code sessions
- **Manual source required**: `create_agent.sh` now offers to launch the agent immediately after setup (`Launch [Name] now? (y/n)`), bypassing the need to `source ~/.bashrc` before first use

---

## v1.8.0 — 2026-03-27

### Added
- **Starter kits** — three pre-configured business models replace `Mission: TBD`
  - `kits/saas.md` — subscription product, MRR tracking, churn, revenue goal
  - `kits/content.md` — blog/newsletter, subscriber count, sponsorship/affiliate revenue
  - `kits/ecommerce.md` — product sales, order tracking, AOV, refund rate
- Kit selection menu in `create_agent.sh` (1=SaaS, 2=Content, 3=E-commerce, 4=Custom)
- Kit populates `core.md` with business-model-specific memory structure
- Kit injects first task into onboarding prompt so agent starts working immediately
- Custom path preserves all existing behaviour — no breaking change

### Fixed
- `SCRIPT_DIR` moved to top of `create_agent.sh` — kit paths now resolve correctly during prompts

### Tests
- T17–T20 added: kit selection, core.md population, custom fallback (44/44 passing)

---

## v1.7.2 — 2026-03-26

### Fixed
- **Critical:** removed `ls -t ~/.claude/projects/ | head -1` session ID capture from all templates
  - This command captures the most recently active Claude project across ALL agents on the machine
  - On multi-agent machines it caused agents to overwrite each other's `last_session.txt`, leading to launch failures and wrong-session resumes
  - Session IDs must be written by the agent itself during its session
- README troubleshooting section updated with symptom, cause, immediate fix, and prevention

---

## v1.7.1 — 2026-03-25

### Fixed
- `upgrade_agent.sh`, `create_agent.sh`: portable `stat` for `.env` permission checks (Linux + macOS)
- `upgrade_agent.sh`: portable `sed -i` via `sedi()` helper (macOS requires empty backup suffix)
- `upgrade_agent.sh`: sed delimiter conflict — `|` in launcher path fix clashed with `||` in replacement string; changed to `#`
- `list_agents.sh`: `ping -W` not supported on macOS/BSD — now tries `curl` first, then `-W2` (Linux), then `-t2` (macOS)
- `telegram_notify.sh`: removed undeclared `python3` dependency — Telegram response now parsed with `grep`/`sed`
- `install.sh`: guard against empty `SHELL_RC` producing broken `source` instruction
- `weekly_summary.sh`: guard against empty `logs/` directory causing glob expansion crash
- `agent_onboarding_template.md`: `USER@` placeholder corrected to `[SSH_USER]@`

---

## v1.7.0 — 2026-03-25

### Added
- `list_agents.sh` — lists all AgentCEO agents on the machine
  - Shows company, status, revenue, last active date, current task
  - Server reachability check (ping/curl)
  - `--upgrade-check` flag compares launcher version vs current
- `telegram_notify.sh` — Telegram Bot API wrapper for backer notifications
  - `--morning`: structured morning report from `core.md` + `shutdown_state.md`
  - `--evening`: evening summary from today's log
  - Self-configures `AGENT_DIR` from script location
  - Prints setup instructions if `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` missing
  - Copied into each new agent's `scripts/` directory by `create_agent.sh`
- `weekly_summary.sh` — 7-day activity digest
  - Shows days active, task count, per-day breakdown
  - `--telegram` sends condensed version and saves full report
  - `--output` writes to file
- Post-install validation in `create_agent.sh` — 8 checks run automatically before first launch

---

## v1.6.0 — 2026-03-25

### Security
- SSH password no longer echoed to terminal (`read -s`)
- SSH password no longer visible in process table (switched from `sshpass -p` to `sshpass -e`)
- Removed `StrictHostKeyChecking=no` from `ssh-copy-id` — prevents MITM during key deployment
- `umask 0077` before all file creation — memory and log files now created 600 (owner-only)
- `sudo` now prompts for confirmation before installing packages
- `trap` cleanup on interruption — no partial agent directories left behind
- Session ID validated as UUID format before passing to `--resume`
- User inputs (display name, company, mission) sanitized — shell metacharacters stripped

### Fixes
- `start_agent_template.sh` fully repaired: was missing `.env` sourcing, `--continue` flag, startup message on fresh path, and empty-file guard on session ID
- Onboarding template placeholders (`[AGENT_NAME]`, `[AGENT_DIR]`, `[PRIMARY_SERVER]`) now substituted at copy time
- `.gitignore` now includes `memory/` and `logs/` — prevents infrastructure data from being committed
- `interaction_history.md` and `pending_backer_actions.md` scaffold files now created on setup
- `upgrade_agent.sh` and `run_tests.sh`: portable `stat` — works on macOS and Linux
- `run_tests.sh`: all paths now derived from script location — no hardcoded `/home/username` paths
- Agent name minimum 2 characters enforced
- Prompt before overwriting existing agent directory

### Added
- `CHANGELOG.md`
- `SECURITY.md`

---

## v1.5.0 — 2026-03-25

### Added
- macOS support — detects `uname Darwin`, uses `brew install sshpass` on macOS
- Test results wired to forge dashboard — `run_tests.sh` writes `test_results.json`
- `upgrade_agent.sh`: three new launcher checks (`launcher_env_source`, `launcher_startup_message`, `launcher_fresh_continue`)
- All launcher fixes consolidated into single rewrite block in upgrader

---

## v1.4.2 — 2026-03-25

### Fixed
- Generated launcher now sources `.env` on startup (`set -a / source / set +a`)
- Generated launcher passes startup message on both resume and fresh paths
- Fresh session path uses `--continue` (not bare `claude`)

---

## v1.4.1 — 2026-03-24

### Fixed
- Startup message (`execute your startup routine now`) added to both launcher paths
- `--continue` added to fresh session path

---

## v1.3.0 — 2026-03-24

### Added
- GitHub auto-reply monitor (`github_monitor.py`) with smart issue templates
- Forge dashboard (`forge.local`) with live ops data
- `upgrade_agent.sh` — upgrade framework files without touching business data
- `analyze_agent.sh` — health check for existing agents
- Portable launcher path detection (`CLAUDE_BIN` via `which claude`)
- Shell-aware alias (`.bashrc` vs `.zshrc`)
- Server offline recovery section in `crash_recovery.md` template

### Fixed
- Removed `ls -t ~/.claude/projects` unreliable session command from CLAUDE.md
- Fixed `not-configured` literal appearing in startup steps
- Fixed `autoMemory` keys in `settings.json` (unofficial, silently ignored)
- Fixed hardcoded claude binary path in generated launcher
- Fixed `| tee` pipe breaking interactive Claude Code sessions
