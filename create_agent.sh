#!/bin/bash

# ============================================================
# AgentCEO — Autonomous AI CEO Creator
# https://github.com/CheskoSebulba/agentceo
# Version: 1.6.0
# License: MIT
# ============================================================

# ============================================================
# Configuration — set your GitHub username here
# ============================================================
VERSION="1.8.1"
AGENTCEO_GITHUB_USER="${AGENTCEO_GITHUB_USER:-CheskoSebulba}"
AGENTCEO_REPO_URL="https://github.com/$AGENTCEO_GITHUB_USER/agentceo"

# OS detection
OS="linux"
[[ "$(uname)" == "Darwin" ]] && OS="macos"

# Script location (needed for kit and template paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sanitize free-text input — strip shell-dangerous characters
sanitize() {
    echo "$1" | tr -d '`$\\<>|;&' | sed "s/'//g"
}

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        AgentCEO — New Agent Setup        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ============================================================
# Interactive prompts with validation
# ============================================================

# Agent name — required, lowercase, min 2 chars, no spaces
while true; do
    read -p "Agent name (lowercase, no spaces) e.g. walter: " AGENT_NAME
    if [[ "$AGENT_NAME" =~ ^[a-z]{2,}$ ]]; then
        break
    fi
    echo "❌ Agent name must be 2+ lowercase letters only. Try again."
done

# Display name — required
while true; do
    read -p "Display name e.g. Walter: " AGENT_DISPLAY_RAW
    if [ -n "$AGENT_DISPLAY_RAW" ]; then
        AGENT_DISPLAY=$(sanitize "$AGENT_DISPLAY_RAW")
        break
    fi
    echo "❌ Display name is required. Try again."
done

# Company — required
while true; do
    read -p "Company name e.g. Acme Corp: " AGENT_COMPANY_RAW
    if [ -n "$AGENT_COMPANY_RAW" ]; then
        AGENT_COMPANY=$(sanitize "$AGENT_COMPANY_RAW")
        break
    fi
    echo "❌ Company name is required. Try again."
done

# Starter kit — optional
KIT_CHOICE=""
KIT_FILE=""
echo "Starter kit (sets mission, memory structure, and first task):"
echo "  1) SaaS       — subscription product, MRR tracking"
echo "  2) Content     — blog/newsletter, sponsorship revenue"
echo "  3) E-commerce  — product sales, order handling"
echo "  4) Custom      — enter your own mission"
read -p "Choose 1-4 (Enter for Custom): " KIT_NUM
case "$KIT_NUM" in
    1) KIT_CHOICE="saas";      KIT_FILE="$SCRIPT_DIR/kits/saas.md" ;;
    2) KIT_CHOICE="content";   KIT_FILE="$SCRIPT_DIR/kits/content.md" ;;
    3) KIT_CHOICE="ecommerce"; KIT_FILE="$SCRIPT_DIR/kits/ecommerce.md" ;;
    *) KIT_CHOICE="custom" ;;
esac

# Mission — pre-filled by kit or entered manually
if [[ "$KIT_CHOICE" == "custom" ]] || [[ ! -f "$KIT_FILE" ]]; then
    read -p "Mission (Enter for TBD): " AGENT_MISSION_RAW
    AGENT_MISSION=$(sanitize "${AGENT_MISSION_RAW:-"TBD — awaiting backer briefing"}")
else
    AGENT_MISSION=$(grep "^## MISSION" -A 6 "$KIT_FILE" | grep -v "^##" | grep -v "^#" | head -4 | tr '\n' ' ' | sed 's/  */ /g' | xargs)
    echo "✅ Mission set from $KIT_CHOICE kit"
fi

# Staging server — optional, warn if blank
read -p "Staging server hostname e.g. walter.local (Enter to skip): " AGENT_SERVER
if [ -z "$AGENT_SERVER" ]; then
    echo "⚠️  No staging server set — SSH setup will be skipped"
    AGENT_SERVER="not-configured"
    SKIP_SSH=true
else
    SKIP_SSH=false
    # SSH user — required if server set
    while true; do
        read -p "Staging server SSH username: " AGENT_SERVER_USER
        if [ -n "$AGENT_SERVER_USER" ]; then
            break
        fi
        echo "❌ SSH username is required. Try again."
    done
    read -s -p "Staging server SSH password (Enter to copy key manually later): " AGENT_SERVER_PASS
    echo ""
fi

# Emoji — optional
read -p "Launch emoji (Enter for 🤖): " AGENT_EMOJI
AGENT_EMOJI=${AGENT_EMOJI:-"🤖"}

# Confirm
echo ""
echo "Creating agent with these settings:"
echo "  Name:     $AGENT_DISPLAY"
echo "  Company:  $AGENT_COMPANY"
echo "  Mission:  $AGENT_MISSION"
echo "  Server:   $AGENT_SERVER"
echo "  Emoji:    $AGENT_EMOJI"
echo ""
read -p "Confirm? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    exit 1
fi

# ============================================================
# Setup
# ============================================================

AGENT_DIR="$HOME/$AGENT_NAME"
TODAY=$(date +%Y-%m-%d)
CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude")

# Validate claude binary exists
if [ ! -x "$CLAUDE_BIN" ] && ! command -v claude &>/dev/null; then
    echo "❌ Claude Code not found. Install it first: https://claude.ai/code"
    exit 1
fi

# Check for existing agent directory
if [ -d "$AGENT_DIR" ]; then
    echo "⚠️  Directory $AGENT_DIR already exists."
    read -p "Overwrite framework files? Business data (core.md, logs, .env) will be preserved. (y/n): " OVERWRITE
    if [ "$OVERWRITE" != "y" ]; then
        echo "Cancelled."
        exit 1
    fi
fi

# Secure file creation — restrict permissions to owner only
umask 0077

# Cleanup on interruption
trap 'echo ""; echo "⚠️  Setup interrupted — cleaning up..."; rm -rf "$AGENT_DIR" 2>/dev/null; exit 1' INT TERM

echo ""
echo "$AGENT_EMOJI Setting up $AGENT_DISPLAY..."
echo ""

# Step 1 — Directories
mkdir -p "$AGENT_DIR"/{memory,memory/auto,skills,logs,templates,scripts,.claude}
echo "✅ Directories created"

# Step 2 — CLAUDE.md
cat > "$AGENT_DIR/CLAUDE.md" << CLAUDEEOF
# STARTUP INSTRUCTIONS — READ THIS FIRST — MANDATORY

On every single session start, immediately and automatically
do the following WITHOUT being asked:

1. Read $AGENT_DIR/memory/core.md
2. Read $AGENT_DIR/memory/shutdown_state.md
3. Read $AGENT_DIR/memory/crash_recovery.md
4. Read $AGENT_DIR/memory/session_context.md if it exists
5. Check $AGENT_DIR/memory/auto/ for recent auto-memory summaries
6. Read most recent file in $AGENT_DIR/logs/
7. Source credentials: source $AGENT_DIR/.env
8. Announce who you are and current project status
9. List exactly where you left off
10. List top 3 priorities right now
11. $([ "$AGENT_SERVER" = "not-configured" ] && echo "Resume work without being asked" || echo "Check $AGENT_SERVER is reachable")
12. Resume work without being asked

Do ALL of this before responding to anything else.
This is mandatory. No exceptions. Every session. Every time.

# Identity

Your name is $AGENT_DISPLAY. You are an autonomous AI CEO and founder.
Your company is $AGENT_COMPANY.
Your mission is $AGENT_MISSION.
Your directory is $AGENT_DIR — you ONLY work here.

# Boundaries — CRITICAL

You are ONLY responsible for:
- $AGENT_DIR/ directory
- $AGENT_SERVER staging server
- Your own business, products, and APIs

You must NEVER touch other agents directories, servers,
credentials, or accounts on this machine.

You MAY read (never write) other agents memory/core.md
files to learn best practices only.

# Memory & Logging — MANDATORY

After EVERY single task, before responding:
1. Update $AGENT_DIR/memory/core.md
2. Write to $AGENT_DIR/logs/\$(date +%Y-%m-%d).md
3. Update $AGENT_DIR/memory/shutdown_state.md
4. Update $AGENT_DIR/memory/crash_recovery.md

NEVER log credentials, API keys, tokens, or passwords.
Store all credentials in $AGENT_DIR/.env only.

# Auto Memory

Claude-Mem captures tool observations automatically to:
$AGENT_DIR/memory/auto/
Check this directory on startup for recent summaries.

# Session Persistence

Your launcher script (start_${AGENT_NAME}.sh) handles session
capture and resume automatically. Do not manage this manually.

# When To Seek Human Guidance

Come to your backer when:
- API credentials are needed
- A domain DNS change is required
- You are about to spend money
- You have hit a blocker after 2 attempts
- A major strategic decision needs approval

Do NOT come to your backer for:
- Routine code or content changes
- Bug fixes you can resolve yourself
- Day to day operations

# Human Role

Your backer will:
- Provide API keys and credentials when needed
- Approve production deploys
- Give strategic feedback when asked
- Never touch your code directly

# Daily Routine

Every morning:
1. Read all memory files and auto-memory summaries
2. Check $AGENT_SERVER is responding if configured
3. Check all live products are working
4. List top 3 priorities for today

Every evening:
1. Write daily log summary
2. Update shutdown_state.md
3. Flag anything needing backer input
4. Plan tomorrow

# Crash Recovery Protocol

After any reboot or crash:
1. Read $AGENT_DIR/memory/shutdown_state.md
2. Read $AGENT_DIR/memory/crash_recovery.md
3. Check $AGENT_SERVER is online if configured
4. Resume exactly where you left off
CLAUDEEOF
echo "✅ CLAUDE.md created"

# Step 3 — Claude Code settings
cat > "$AGENT_DIR/.claude/settings.json" << SETTINGSEOF
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(curl:*)",
      "Bash(ssh:*)",
      "Bash(npm:*)",
      "Bash(node:*)"
    ]
  }
}
SETTINGSEOF
echo "✅ Claude Code settings configured"

# Step 4 — core.md (kit-aware)
if [[ -n "$KIT_FILE" ]] && [[ -f "$KIT_FILE" ]]; then
    # Extract CORE_MD_STUB from kit file and substitute placeholders
    awk '/^## CORE_MD_STUB/{found=1; next} found && /^## END_STUB/{exit} found{print}' "$KIT_FILE" \
        | sed "s/\[AGENT_NAME\]/$AGENT_DISPLAY/g" \
        | sed "s/\[AGENT_COMPANY\]/$AGENT_COMPANY/g" \
        | sed "s/\[TODAY\]/$TODAY/g" \
        | sed "s/\[PRIMARY_SERVER\]/$AGENT_SERVER/g" \
        > "$AGENT_DIR/memory/core.md"
    # Append credentials and SSH key sections
    cat >> "$AGENT_DIR/memory/core.md" << CREDEOF

## Credentials
- All stored in $AGENT_DIR/.env — never logged here
- SSH key: $HOME/.ssh/${AGENT_NAME}_staging
CREDEOF
    echo "✅ core.md created from $KIT_CHOICE kit"
else
    cat > "$AGENT_DIR/memory/core.md" << COREEOF
# ${AGENT_DISPLAY}'s Memory

## About Me
- Name: $AGENT_DISPLAY
- Role: Autonomous AI CEO
- Company: $AGENT_COMPANY
- Started: $TODAY
- Status: Day 1 — awaiting mission briefing

## Business Status
- Current revenue: \$0
- Active products: none
- Mission: $AGENT_MISSION

## Infrastructure
- Staging: $AGENT_SERVER
- Production: TBD
- SSH key: $HOME/.ssh/${AGENT_NAME}_staging

## Credentials
- All stored in $AGENT_DIR/.env — never logged here

## What I Know Works
- Nothing yet

## What I Know Doesn't Work
- Nothing yet

## Key Decisions Made
- Nothing yet

## Lessons Learned
- Nothing yet

## Next Actions
- Await mission briefing from backer
- Get SSH access to $AGENT_SERVER if not already done
COREEOF
    echo "✅ core.md created"
fi

# Step 5 — shutdown_state.md
cat > "$AGENT_DIR/memory/shutdown_state.md" << SHUTEOF
# Shutdown State

## Last Updated
$TODAY — Initial setup

## Agent
$AGENT_DISPLAY — $AGENT_COMPANY

## Current Task
Awaiting mission briefing from backer

## Current Step
Day 1 — Setup phase

## Next Action
- Read CLAUDE.md and all memory files on startup
- Await backer briefing on mission

## Incomplete Tasks
- None yet

## Servers Being Modified
- None yet
SHUTEOF
echo "✅ shutdown_state.md created"

# Step 6 — crash_recovery.md
cat > "$AGENT_DIR/memory/crash_recovery.md" << CRASHEOF
# Crash Recovery for $AGENT_DISPLAY

## To Restore After Any Crash or Reboot

1. SSH into this machine: ssh $USER@$(hostname)
2. Type: $AGENT_NAME
3. Read memory files in this order:
   - $AGENT_DIR/CLAUDE.md
   - $AGENT_DIR/memory/core.md
   - $AGENT_DIR/memory/shutdown_state.md
   - Most recent file in $AGENT_DIR/logs/
   - $AGENT_DIR/memory/auto/ for recent summaries

## Services to Check
- $AGENT_SERVER — staging server

## Environment Variables
- Location: $AGENT_DIR/.env
- Load with: source $AGENT_DIR/.env

## SSH Access
ssh -i $HOME/.ssh/${AGENT_NAME}_staging $AGENT_SERVER_USER@$AGENT_SERVER

## If Server Is Offline
1. Test: curl -s --connect-timeout 5 http://$AGENT_SERVER
2. Skip server-dependent tasks — focus on local work
3. Check $AGENT_DIR/logs/ for last known good state
4. Document server status in shutdown_state.md under ## Blockers
5. Flag to backer if server down >24h — do not keep retrying
CRASHEOF
echo "✅ crash_recovery.md created"

# Step 7 — Today's log
cat > "$AGENT_DIR/logs/$TODAY.md" << LOGEOF
# ${AGENT_DISPLAY} Daily Log — $TODAY

## Session 1 — Setup
- Directory structure created
- CLAUDE.md identity file created
- autoMemory configured
- Memory files initialized
- Crash recovery documented
- Awaiting mission briefing from backer
LOGEOF
echo "✅ Today's log created"

# Step 8 — env file
touch "$AGENT_DIR/.env"
chmod 600 "$AGENT_DIR/.env"
echo "✅ .env created (secure)"

# Step 8b — .gitignore
cat > "$AGENT_DIR/.gitignore" << GITEOF
.env
*.env
.env.*
memory/
logs/
*.log
GITEOF
echo "✅ .gitignore created"

# Step 9 — Copy and substitute onboarding template
ONBOARDING_TEMPLATE="$SCRIPT_DIR/agent_onboarding_template.md"
if [ -f "$ONBOARDING_TEMPLATE" ]; then
    sed \
        -e "s|\[AGENT_NAME\]|$AGENT_DISPLAY|g" \
        -e "s|\[AGENT_DIR\]|$AGENT_DIR|g" \
        -e "s|\[PRIMARY_SERVER\]|$AGENT_SERVER|g" \
        -e "s|\[PRIMARY_WEBSITE\]|TBD|g" \
        "$ONBOARDING_TEMPLATE" > "$AGENT_DIR/memory/agent_onboarding_template.md"
    echo "✅ Onboarding template copied and configured"
else
    echo "⚠️  Onboarding template not found at $ONBOARDING_TEMPLATE"
fi

# Step 9b — Create scaffold memory files referenced in onboarding template
touch "$AGENT_DIR/memory/interaction_history.md"
cat > "$AGENT_DIR/memory/pending_backer_actions.md" << BACKEREOF
# Pending Backer Actions

## Items Requiring Your Input
- None yet

## Awaiting Approval
- None yet
BACKEREOF
echo "✅ Memory scaffolds created"

# Step 10 — Install sshpass if needed
if ! which sshpass > /dev/null 2>&1; then
    echo "📦 sshpass is needed to copy the SSH key automatically."
    read -p "   Install sshpass now? (y/n, or n to copy key manually later): " INSTALL_SSHPASS
    if [ "$INSTALL_SSHPASS" = "y" ]; then
        if [[ "$OS" == "macos" ]]; then
            brew install sshpass 2>/dev/null || echo "⚠️  brew install sshpass failed — install manually"
        else
            sudo apt-get install -y sshpass 2>/dev/null || echo "⚠️  apt install sshpass failed — install manually"
        fi
        echo "✅ sshpass installed"
    else
        echo "⏭️  Skipping sshpass — you'll need to copy the SSH key manually"
        AGENT_SERVER_PASS=""
    fi
fi

# Step 11 — SSH key setup
if [ "$SKIP_SSH" = false ]; then
    echo ""
    echo "🔑 Setting up SSH key for $AGENT_SERVER..."
    ssh-keygen -t ed25519 \
        -C "${AGENT_NAME}@${AGENT_SERVER}" \
        -f "$HOME/.ssh/${AGENT_NAME}_staging" \
        -N "" 2>/dev/null
    echo "✅ SSH key generated"

    if [ -n "$AGENT_SERVER_PASS" ]; then
        SSHPASS="$AGENT_SERVER_PASS" sshpass -e ssh-copy-id \
            -i "$HOME/.ssh/${AGENT_NAME}_staging.pub" \
            "$AGENT_SERVER_USER@$AGENT_SERVER" 2>/dev/null \
            && echo "✅ SSH key copied to $AGENT_SERVER automatically" \
            || echo "⚠️  SSH copy failed — copy manually later"
        unset SSHPASS
    else
        echo "⚠️  No password provided — copy SSH key manually:"
        echo "    ssh-copy-id -i $HOME/.ssh/${AGENT_NAME}_staging.pub $AGENT_SERVER_USER@$AGENT_SERVER"
    fi
else
    echo "⏭️  SSH setup skipped — no staging server configured"
fi

# Step 12 — Startup script
cat > "$AGENT_DIR/start_${AGENT_NAME}.sh" << STARTEOF
#!/bin/bash
# $AGENT_DISPLAY Launcher — AgentCEO v$VERSION
unset ANTHROPIC_API_KEY

AGENT_DIR="$AGENT_DIR"
RESUME_FILE="\$AGENT_DIR/memory/last_session.txt"
CLAUDE_BIN=\$(which claude 2>/dev/null || echo "\$HOME/.npm-global/bin/claude")

# Load agent credentials
set -a
source "\$AGENT_DIR/.env" 2>/dev/null
set +a

echo "$AGENT_EMOJI Launching $AGENT_DISPLAY..."

cd "\$AGENT_DIR"

if [ -f "\$RESUME_FILE" ] && [ -s "\$RESUME_FILE" ]; then
    SESSION_ID=\$(cat "\$RESUME_FILE")
    # Validate UUID format before use
    if [[ "\$SESSION_ID" =~ ^[0-9a-f-]{36}$ ]]; then
        echo "📂 Resuming session: \$SESSION_ID"
        exec \$CLAUDE_BIN \
            --resume "\$SESSION_ID" \
            --dangerously-skip-permissions \
            "$AGENT_DISPLAY, execute your startup routine now."
    else
        echo "⚠️  Invalid session ID — starting fresh"
        rm -f "\$RESUME_FILE"
    fi
fi

echo "🆕 Starting fresh session..."
exec \$CLAUDE_BIN \
    --dangerously-skip-permissions \
    "$AGENT_DISPLAY, execute your startup routine now."
STARTEOF
chmod +x "$AGENT_DIR/start_${AGENT_NAME}.sh"
echo "✅ Startup script created with session capture"

# Step 13 — Add alias (shell-aware)
ALIAS_LINE="alias $AGENT_NAME='bash $AGENT_DIR/start_${AGENT_NAME}.sh'"
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

if ! grep -q "alias $AGENT_NAME=" "$SHELL_RC" 2>/dev/null; then
    echo "$ALIAS_LINE" >> "$SHELL_RC"
    echo "✅ Alias added to $SHELL_RC: $AGENT_NAME"
    echo "   ➜ Run: source $SHELL_RC  (or open a new terminal)"
else
    echo "⚠️  Alias already exists in $SHELL_RC — skipping"
fi

# Step 13b — Copy telegram_notify.sh to agent scripts/
TELEGRAM_SCRIPT="$SCRIPT_DIR/../telegram_notify.sh"
if [ -f "$TELEGRAM_SCRIPT" ]; then
    cp "$TELEGRAM_SCRIPT" "$AGENT_DIR/scripts/telegram_notify.sh"
    chmod +x "$AGENT_DIR/scripts/telegram_notify.sh"
    echo "✅ telegram_notify.sh installed to scripts/"
fi

# Step 14 — Post-install validation
echo ""
echo "🔍 Verifying setup..."
VERIFY_PASS=0
VERIFY_FAIL=0

check() {
    if eval "$2" &>/dev/null; then
        echo "  ✅ $1"
        (( VERIFY_PASS++ ))
    else
        echo "  ❌ $1"
        (( VERIFY_FAIL++ ))
    fi
}

check "CLAUDE.md exists"           "[ -f '$AGENT_DIR/CLAUDE.md' ]"
check "core.md exists"             "[ -f '$AGENT_DIR/memory/core.md' ]"
check "shutdown_state.md exists"   "[ -f '$AGENT_DIR/memory/shutdown_state.md' ]"
check ".env permissions are 600"   "[ \"\$(stat -c '%a' '$AGENT_DIR/.env' 2>/dev/null || stat -f '%OLp' '$AGENT_DIR/.env' 2>/dev/null)\" = '600' ]"
check "Launcher is executable"     "[ -x '$AGENT_DIR/start_${AGENT_NAME}.sh' ]"
check ".gitignore covers memory/"  "grep -q 'memory/' '$AGENT_DIR/.gitignore'"
check "Onboarding template ready"  "[ -f '$AGENT_DIR/memory/agent_onboarding_template.md' ]"
check "Claude Code found"          "command -v claude || [ -x '$CLAUDE_BIN' ]"

if [[ $VERIFY_FAIL -gt 0 ]]; then
    echo ""
    echo "  ⚠️  $VERIFY_FAIL check(s) failed — review above before launching"
else
    echo "  All checks passed ✅"
fi

# Step 15 — Done
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     ✅ $AGENT_DISPLAY is ready!          "
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Type: $AGENT_NAME"
echo ""
echo "On first launch paste this into Claude Code:"
echo ""
echo "---COPY FROM HERE---"
cat << PROMPTEOF
Read these files in order:
1. $AGENT_DIR/CLAUDE.md
2. $AGENT_DIR/memory/core.md
3. $AGENT_DIR/memory/agent_onboarding_template.md

You are $AGENT_DISPLAY, autonomous AI CEO of $AGENT_COMPANY.
Your mission: $AGENT_MISSION
Your directory: $AGENT_DIR — ONLY work here.

Never touch other agents directories or servers.
You MAY read other agents memory/core.md to learn.

After reading everything:
1. Confirm your identity and mission
2. Save your session ID to $AGENT_DIR/memory/last_session.txt
3. Tell me you are ready and what you need to get started
$(if [[ -n "$KIT_FILE" ]] && [[ -f "$KIT_FILE" ]]; then
    first_task=$(awk '/^## FIRST_TASK/{found=1; next} found && /^## /{exit} found{print}' "$KIT_FILE" | xargs)
    [[ -n "$first_task" ]] && echo "" && echo "Your first task: $first_task"
fi)
PROMPTEOF
echo "---END COPY---"
echo ""
echo "ℹ️  Note: The launcher ($AGENT_NAME) sends your startup message automatically."
echo "   Only paste the above if launching Claude Code manually."
echo ""

# Offer immediate launch — bypasses needing to source the shell
read -p "Launch $AGENT_DISPLAY now? (y/n): " LAUNCH_NOW
if [[ "$LAUNCH_NOW" =~ ^[Yy]$ ]]; then
    exec bash "$AGENT_DIR/start_${AGENT_NAME}.sh"
fi

# Clear the interrupt trap — setup completed successfully
trap - INT TERM
