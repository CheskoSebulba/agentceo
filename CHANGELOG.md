# Changelog

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
