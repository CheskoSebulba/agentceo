#!/bin/bash

# ============================================================
# AgentCEO — Autonomous AI CEO Creator
# https://github.com/CheskoSebulba/agentceo
# Version: 1.3.0
# License: MIT
# ============================================================

# ============================================================
# Configuration — set your GitHub username here
# ============================================================
VERSION="1.4.2"
AGENTCEO_GITHUB_USER="${AGENTCEO_GITHUB_USER:-CheskoSebulba}"
AGENTCEO_REPO_URL="https://github.com/$AGENTCEO_GITHUB_USER/agentceo"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        AgentCEO — New Agent Setup        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ============================================================
# Interactive prompts with validation
# ============================================================

# Agent name — required, lowercase, no spaces
while true; do
    read -p "Agent name (lowercase, no spaces) e.g. walter: " AGENT_NAME
    if [[ "$AGENT_NAME" =~ ^[a-z]+$ ]]; then
        break
    fi
    echo "❌ Agent name must be lowercase letters only. Try again."
done

# Display name — required
while true; do
    read -p "Display name e.g. Walter: " AGENT_DISPLAY
    if [ -n "$AGENT_DISPLAY" ]; then
        break
    fi
    echo "❌ Display name is required. Try again."
done

# Company — required
while true; do
    read -p "Company name e.g. Acme Corp: " AGENT_COMPANY
    if [ -n "$AGENT_COMPANY" ]; then
        break
    fi
    echo "❌ Company name is required. Try again."
done

# Mission — optional
read -p "Mission (Enter for TBD): " AGENT_MISSION
AGENT_MISSION=${AGENT_MISSION:-"TBD — awaiting backer briefing"}

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
    read -p "Staging server SSH password (Enter to copy key manually later): " AGENT_SERVER_PASS
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

# Step 4 — core.md
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
GITEOF
echo "✅ .gitignore created"

# Step 9 — Copy onboarding template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONBOARDING_TEMPLATE="$SCRIPT_DIR/agent_onboarding_template.md"
if [ -f "$ONBOARDING_TEMPLATE" ]; then
    cp "$ONBOARDING_TEMPLATE" "$AGENT_DIR/memory/agent_onboarding_template.md"
    echo "✅ Onboarding template copied"
else
    echo "⚠️  Onboarding template not found at $ONBOARDING_TEMPLATE"
fi

# Step 10 — Install sshpass if needed
if ! which sshpass > /dev/null 2>&1; then
    echo "📦 Installing sshpass..."
    sudo apt-get install -y sshpass 2>/dev/null
    echo "✅ sshpass installed"
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
        sshpass -p "$AGENT_SERVER_PASS" ssh-copy-id \
            -i "$HOME/.ssh/${AGENT_NAME}_staging.pub" \
            -o StrictHostKeyChecking=no \
            "$AGENT_SERVER_USER@$AGENT_SERVER" 2>/dev/null \
            && echo "✅ SSH key copied to $AGENT_SERVER automatically" \
            || echo "⚠️  SSH copy failed — copy manually later"
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
    echo "📂 Resuming session: \$SESSION_ID"
    exec \$CLAUDE_BIN \
        --resume "\$SESSION_ID" \
        --dangerously-skip-permissions \
        "$AGENT_DISPLAY, execute your startup routine now."
else
    echo "🆕 Starting fresh session..."
    exec \$CLAUDE_BIN \
        --continue \
        --dangerously-skip-permissions \
        "$AGENT_DISPLAY, execute your startup routine now."
fi
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

# Step 14 — Done
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

Adopt all protocols from the onboarding template:
- [AGENT_NAME] = $AGENT_DISPLAY
- [AGENT_DIR] = $AGENT_DIR
- [PRIMARY_SERVER] = $AGENT_SERVER
- [PRIMARY_WEBSITE] = TBD

Never touch other agents directories or servers.
You MAY read other agents memory/core.md to learn.

After reading everything:
1. Update all memory files with your correct identity
2. Save your session ID to $AGENT_DIR/memory/last_session.txt
3. Tell me you are ready and what you need to get started
PROMPTEOF
echo "---END COPY---"
echo ""
