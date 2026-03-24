#!/bin/bash
# ============================================================
# AgentCEO — Agent Upgrader
# Usage: bash upgrade_agent.sh agentname [--yes]
# Upgrades framework files to current version.
# Never touches business data (core.md, logs, .env content).
# Always creates a backup before making changes.
# ============================================================

CURRENT_VERSION="1.4.0"
BASE_DIR="${AGENTCEO_BASE:-$HOME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../../agent/templates" && pwd 2>/dev/null || echo "")"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()     { echo -e "  ${GREEN}✔${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC}  $1"; }
bad()    { echo -e "  ${RED}✘${NC}  $1"; }
info()   { echo -e "  ${DIM}·${NC}  $1"; }
changed(){ echo -e "  ${CYAN}→${NC}  $1"; }

# ── Resolve agent directory ───────────────────────────────────────────────────
resolve_dir() {
    local arg="$1"
    if [[ "$arg" == /* ]] && [[ -d "$arg" ]]; then echo "$arg"; return; fi
    if [[ -d "$BASE_DIR/$arg" ]]; then echo "$BASE_DIR/$arg"; return; fi
    echo ""
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: bash upgrade_agent.sh agentname [--yes]"
    echo "       --yes   skip confirmation prompt"
    exit 1
}

# ── Args ──────────────────────────────────────────────────────────────────────
AGENT_ARG=""
AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        --yes) AUTO_YES=true ;;
        --*)   echo "Unknown flag: $arg"; usage ;;
        *)     AGENT_ARG="$arg" ;;
    esac
done

[[ -z "$AGENT_ARG" ]] && usage

AGENT_DIR=$(resolve_dir "$AGENT_ARG")
if [[ -z "$AGENT_DIR" ]]; then
    echo -e "${RED}Error: agent '$AGENT_ARG' not found under $BASE_DIR${NC}"
    exit 1
fi
AGENT_NAME=$(basename "$AGENT_DIR")

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         AgentCEO — Agent Upgrader v$CURRENT_VERSION           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "${DIM}Agent: $AGENT_NAME${NC}"
echo -e "${DIM}Path:  $AGENT_DIR${NC}"
echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# ── Detect what needs upgrading ───────────────────────────────────────────────
CLAUDE_MD="$AGENT_DIR/CLAUDE.md"
CRASH_MD="$AGENT_DIR/memory/crash_recovery.md"
SETTINGS_JSON="$AGENT_DIR/.claude/settings.json"
LAUNCHER="$AGENT_DIR/start_${AGENT_NAME}.sh"
GITIGNORE="$AGENT_DIR/.gitignore"
ENV_FILE="$AGENT_DIR/.env"
ONBOARDING="$AGENT_DIR/memory/agent_onboarding_template.md"

upgrade_items=()
upgrade_descriptions=()

# Check each condition
if [[ -f "$SETTINGS_JSON" ]] && grep -q '"autoMemory"' "$SETTINGS_JSON" 2>/dev/null; then
    upgrade_items+=("settings_json")
    upgrade_descriptions+=("settings.json: replace unofficial autoMemory keys with real permissions scaffold")
fi

if [[ -f "$CLAUDE_MD" ]] && grep -q "ls -t ~/.claude/projects" "$CLAUDE_MD" 2>/dev/null; then
    upgrade_items+=("claude_md_ls_session")
    upgrade_descriptions+=("CLAUDE.md: remove unreliable ls session command")
fi

if [[ -f "$CLAUDE_MD" ]] && grep -q "not-configured" "$CLAUDE_MD" 2>/dev/null; then
    upgrade_items+=("claude_md_not_configured")
    upgrade_descriptions+=("CLAUDE.md: fix 'not-configured' literal in startup steps")
fi

if [[ -f "$CLAUDE_MD" ]] && ! grep -q "Source credentials" "$CLAUDE_MD" 2>/dev/null; then
    upgrade_items+=("claude_md_env_source")
    upgrade_descriptions+=("CLAUDE.md: add 'source .env' as startup step")
fi

if [[ -f "$CRASH_MD" ]] && ! grep -q "If Server Is Offline" "$CRASH_MD" 2>/dev/null; then
    upgrade_items+=("crash_recovery_offline")
    upgrade_descriptions+=("crash_recovery.md: add server offline contingency section")
fi

if [[ -f "$LAUNCHER" ]] && grep -qE 'CLAUDE_BIN=/home/' "$LAUNCHER" 2>/dev/null; then
    upgrade_items+=("launcher_hardcoded_path")
    upgrade_descriptions+=("start_${AGENT_NAME}.sh: replace hardcoded claude path with runtime detection")
fi

if [[ -f "$ENV_FILE" ]]; then
    env_perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
    if [[ "$env_perms" != "600" ]]; then
        upgrade_items+=("env_permissions")
        upgrade_descriptions+=(".env: fix permissions from $env_perms to 600")
    fi
fi

if [[ ! -f "$GITIGNORE" ]]; then
    upgrade_items+=("gitignore_missing")
    upgrade_descriptions+=(".gitignore: create (missing)")
fi

if [[ ! -f "$ONBOARDING" ]] && [[ -f "$TEMPLATE_DIR/agent_onboarding_template.md" ]]; then
    upgrade_items+=("onboarding_missing")
    upgrade_descriptions+=("memory/agent_onboarding_template.md: copy from current template")
fi

# ── Nothing to do ─────────────────────────────────────────────────────────────
if [[ ${#upgrade_items[@]} -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✔ $AGENT_NAME is already up to date (v$CURRENT_VERSION)${NC}"
    echo ""
    exit 0
fi

# ── Show upgrade plan ─────────────────────────────────────────────────────────
echo -e "${BOLD}Upgrade Plan${NC}"
echo ""
echo -e "  ${BOLD}Will change:${NC}"
for desc in "${upgrade_descriptions[@]}"; do
    echo -e "  ${CYAN}→${NC}  $desc"
done
echo ""
echo -e "  ${BOLD}Will NOT touch:${NC}"
echo -e "  ${DIM}·${NC}  memory/core.md"
echo -e "  ${DIM}·${NC}  memory/shutdown_state.md"
echo -e "  ${DIM}·${NC}  logs/ (all history)"
echo -e "  ${DIM}·${NC}  .env contents (credentials)"
echo -e "  ${DIM}·${NC}  All custom memory files"
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────
if [[ "$AUTO_YES" != true ]]; then
    read -p "Proceed with upgrade? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# ── Backup ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Creating backup...${NC}"
BACKUP_DIR="$BASE_DIR/.agentceo_backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/${AGENT_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
if tar -czf "$BACKUP_FILE" -C "$BASE_DIR" "$AGENT_NAME" 2>/dev/null; then
    ok "Backup created: $BACKUP_FILE"
else
    bad "Backup failed — aborting upgrade"
    exit 1
fi
echo ""

# ── Apply upgrades ────────────────────────────────────────────────────────────
echo -e "${BOLD}Applying upgrades...${NC}"
echo ""
CHANGED=0

# ── settings.json ─────────────────────────────────────────────────────────────
if [[ " ${upgrade_items[*]} " == *" settings_json "* ]]; then
    cat > "$SETTINGS_JSON" << 'SETTINGSEOF'
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
    changed "settings.json — replaced autoMemory with real permissions scaffold"
    (( CHANGED++ ))
fi

# ── CLAUDE.md upgrades (all via Python for reliable multi-line editing) ───────
claude_needs_edit=false
for item in "${upgrade_items[@]}"; do
    [[ "$item" == claude_md_* ]] && claude_needs_edit=true && break
done

if [[ "$claude_needs_edit" == true ]] && [[ -f "$CLAUDE_MD" ]]; then
    python3 - "$CLAUDE_MD" "$AGENT_DIR" << 'PYEOF'
import re, sys

claude_md_path = sys.argv[1]
agent_dir = sys.argv[2]

with open(claude_md_path, 'r') as f:
    content = f.read()

original = content
changes = []

# Fix 1: Remove ls session command lines
if 'ls -t ~/.claude/projects' in content:
    content = re.sub(r'[^\n]*ls -t ~/\.claude/projects[^\n]*\n?', '', content)
    changes.append('removed ls session command')

# Fix 2: Fix all "not-configured" server references throughout CLAUDE.md
if 'not-configured' in content:
    # Fix numbered step patterns: "N. Check not-configured is ..."
    content = re.sub(
        r'(\d+)\.\s+Check not-configured[^\n]*',
        lambda m: m.group(1) + '. Resume work without being asked',
        content
    )
    # Fix plain check lines in Daily Routine / Crash Recovery sections
    content = re.sub(r'(\d+\.\s+)?Check not-configured[^\n]*\n?', '', content)
    # Fix boundary/identity references: "not-configured staging server"
    content = content.replace('not-configured staging server', 'no staging server configured')
    # Clean up any remaining bare "not-configured" references
    content = re.sub(r'\bnot-configured\b', 'not yet configured', content)
    changes.append('fixed not-configured literals throughout')

# Fix 3: Add source .env step after "Read most recent file" step
if 'Source credentials' not in content:
    # Find the step that reads most recent log file
    match = re.search(r'^(\d+)\. Read most recent file[^\n]*\n', content, re.MULTILINE)
    if match:
        step_num = int(match.group(1))
        insert_num = step_num + 1

        # Build the new source line
        source_line = f'{insert_num}. Source credentials: source {agent_dir}/.env\n'

        # Insert after the matched line
        insert_pos = match.end()
        content = content[:insert_pos] + source_line + content[insert_pos:]

        # Renumber all subsequent steps (insert_num+1 and above, in reverse to avoid double-incrementing)
        # Find all numbered steps after our insertion point that need renumbering
        def renumber_steps(text, from_num, after_pos):
            lines = text.split('\n')
            result = []
            in_startup = False
            past_insertion = False
            char_count = 0
            for line in lines:
                if char_count >= after_pos and re.match(r'^(\d+)\. ', line):
                    m = re.match(r'^(\d+)\. ', line)
                    n = int(m.group(1))
                    if n >= from_num + 1:
                        line = str(n + 1) + '. ' + line[m.end():]
                result.append(line)
                char_count += len(line) + 1
            return '\n'.join(result)

        content = renumber_steps(content, step_num, insert_pos)
        changes.append(f'added source .env as step {insert_num}')

if changes:
    with open(claude_md_path, 'w') as f:
        f.write(content)
    print('CHANGED: ' + ', '.join(changes))
else:
    print('NO_CHANGE')
PYEOF

    result=$?
    if [[ $result -eq 0 ]]; then
        changed "CLAUDE.md — startup steps updated"
        (( CHANGED++ ))
    else
        warn "CLAUDE.md — edit failed (manual review needed)"
    fi
fi

# ── crash_recovery.md — add server offline section ────────────────────────────
if [[ " ${upgrade_items[*]} " == *" crash_recovery_offline "* ]]; then
    # Detect server name from crash_recovery.md
    server=$(grep -m1 "^- " "$CRASH_MD" 2>/dev/null | sed 's/.*: //' | head -1)
    [[ -z "$server" ]] && server="your-staging-server"

    cat >> "$CRASH_MD" << CRASHEOF

## If Server Is Offline
1. Test: curl -s --connect-timeout 5 http://$server
2. Skip server-dependent tasks — focus on local work
3. Check $AGENT_DIR/logs/ for last known good state
4. Document server status in shutdown_state.md under ## Blockers
5. Flag to backer if server down >24h — do not keep retrying
CRASHEOF
    changed "crash_recovery.md — added server offline contingency"
    (( CHANGED++ ))
fi

# ── Launcher: fix hardcoded claude path ───────────────────────────────────────
if [[ " ${upgrade_items[*]} " == *" launcher_hardcoded_path "* ]]; then
    sed -i 's|CLAUDE_BIN=.*|CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude")|g' "$LAUNCHER"
    changed "start_${AGENT_NAME}.sh — replaced hardcoded claude path with runtime detection"
    (( CHANGED++ ))
fi

# ── .env permissions ──────────────────────────────────────────────────────────
if [[ " ${upgrade_items[*]} " == *" env_permissions "* ]]; then
    chmod 600 "$ENV_FILE"
    changed ".env — permissions set to 600"
    (( CHANGED++ ))
fi

# ── .gitignore ────────────────────────────────────────────────────────────────
if [[ " ${upgrade_items[*]} " == *" gitignore_missing "* ]]; then
    cat > "$GITIGNORE" << 'GITEOF'
.env
*.env
.env.*
GITEOF
    changed ".gitignore — created"
    (( CHANGED++ ))
fi

# ── Onboarding template ───────────────────────────────────────────────────────
if [[ " ${upgrade_items[*]} " == *" onboarding_missing "* ]]; then
    cp "$TEMPLATE_DIR/agent_onboarding_template.md" "$ONBOARDING"
    changed "memory/agent_onboarding_template.md — copied from current template"
    (( CHANGED++ ))
fi

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Verification${NC}"

errors=0

# CLAUDE.md checks
if [[ -f "$CLAUDE_MD" ]]; then
    if grep -q "ls -t ~/.claude/projects" "$CLAUDE_MD" 2>/dev/null; then
        bad "CLAUDE.md still contains ls session command"; (( errors++ ))
    else
        ok "CLAUDE.md — no ls session command"
    fi
    if grep -qE "Check not-configured|not-configured (is|staging)" "$CLAUDE_MD" 2>/dev/null; then
        bad "CLAUDE.md still contains 'not-configured' server references"; (( errors++ ))
    else
        ok "CLAUDE.md — no 'not-configured' server references"
    fi
    if grep -q "Source credentials" "$CLAUDE_MD" 2>/dev/null; then
        ok "CLAUDE.md — source .env step present"
    else
        bad "CLAUDE.md — source .env step missing"; (( errors++ ))
    fi
fi

# settings.json check
if [[ -f "$SETTINGS_JSON" ]]; then
    if python3 -c "import json; json.load(open('$SETTINGS_JSON'))" 2>/dev/null; then
        ok "settings.json — valid JSON"
    else
        bad "settings.json — invalid JSON"; (( errors++ ))
    fi
    if grep -q '"autoMemory"' "$SETTINGS_JSON" 2>/dev/null; then
        bad "settings.json — still has autoMemory"; (( errors++ ))
    else
        ok "settings.json — no autoMemory"
    fi
fi

# crash_recovery check
if [[ -f "$CRASH_MD" ]]; then
    if grep -q "If Server Is Offline" "$CRASH_MD" 2>/dev/null; then
        ok "crash_recovery.md — offline section present"
    else
        bad "crash_recovery.md — offline section missing"; (( errors++ ))
    fi
fi

# .env permissions
if [[ -f "$ENV_FILE" ]]; then
    perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        ok ".env — permissions 600"
    else
        bad ".env — permissions still $perms"; (( errors++ ))
    fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Summary${NC}"
if [[ $errors -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✔ Upgrade complete — $CHANGED change(s) applied, all verified${NC}"
    echo ""
    echo -e "  ${DIM}Backup:  $BACKUP_FILE${NC}"
    echo -e "  ${DIM}To restore: tar -xzf $BACKUP_FILE -C $BASE_DIR${NC}"
else
    echo -e "  ${RED}${BOLD}✘ Upgrade completed with $errors verification error(s)${NC}"
    echo -e "  ${DIM}Backup available: $BACKUP_FILE${NC}"
    echo -e "  ${DIM}To restore: tar -xzf $BACKUP_FILE -C $BASE_DIR${NC}"
    exit 1
fi
echo ""
