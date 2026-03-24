#!/bin/bash
# ============================================================
# AgentCEO — Agent Analyzer
# Usage: bash analyze_agent.sh [agentname|path]
#        bash analyze_agent.sh --all
# Reads an existing agent deployment, detects version,
# audits files, and reports what an upgrade would change.
# ============================================================

CURRENT_VERSION="1.4.1"
BASE_DIR="${AGENTCEO_BASE:-$HOME}"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
bad()  { echo -e "  ${RED}✘${NC}  $1"; }
info() { echo -e "  ${DIM}·${NC}  $1"; }

# ── Resolve agent directory ───────────────────────────────────────────────────
resolve_dir() {
    local arg="$1"
    if [[ -z "$arg" ]]; then
        echo ""
        return
    fi
    # Absolute path
    if [[ "$arg" == /* ]] && [[ -d "$arg" ]]; then
        echo "$arg"
        return
    fi
    # Name relative to BASE_DIR
    if [[ -d "$BASE_DIR/$arg" ]]; then
        echo "$BASE_DIR/$arg"
        return
    fi
    echo ""
}

# ── Find all agents ───────────────────────────────────────────────────────────
find_all_agents() {
    local agents=()
    for dir in "$BASE_DIR"/*/; do
        if [[ -f "${dir}CLAUDE.md" && -f "${dir}memory/shutdown_state.md" ]]; then
            agents+=("$dir")
        fi
    done
    echo "${agents[@]}"
}

# ── Detect version from launcher ──────────────────────────────────────────────
detect_version() {
    local agent_dir="$1"
    local agent_name
    agent_name=$(basename "$agent_dir")
    local launcher="$agent_dir/start_${agent_name}.sh"

    if [[ -f "$launcher" ]]; then
        local ver
        ver=$(grep -o 'AgentCEO v[0-9.]*' "$launcher" 2>/dev/null | head -1 | grep -o '[0-9.]*')
        if [[ -n "$ver" ]]; then
            echo "$ver"
            return
        fi
    fi
    echo "unknown"
}

# ── Version comparison (returns 0 if $1 < $2) ────────────────────────────────
version_lt() {
    [[ "$1" != "$2" ]] && [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

# ── Analyze single agent ──────────────────────────────────────────────────────
analyze_agent() {
    local agent_dir="$1"
    local agent_name
    agent_name=$(basename "$agent_dir")

    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  Agent: $agent_name${NC}"
    echo -e "${BOLD}${CYAN}  Path:  $agent_dir${NC}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""

    local detected_version
    detected_version=$(detect_version "$agent_dir")
    local needs_upgrade=0

    # ── Version ───────────────────────────────────────────────────────────────
    echo -e "${BOLD}Version${NC}"
    if [[ "$detected_version" == "unknown" ]]; then
        warn "Could not detect version — launcher missing or pre-v1.3.0"
        needs_upgrade=1
    elif [[ "$detected_version" == "$CURRENT_VERSION" ]]; then
        ok "v$detected_version — up to date"
    elif version_lt "$detected_version" "$CURRENT_VERSION"; then
        bad "v$detected_version — current is v$CURRENT_VERSION (upgrade available)"
        needs_upgrade=1
    else
        warn "v$detected_version — newer than analyzer (v$CURRENT_VERSION)"
    fi
    echo ""

    # ── Identity (from core.md) ───────────────────────────────────────────────
    echo -e "${BOLD}Identity${NC}"
    local core_file="$agent_dir/memory/core.md"
    if [[ -f "$core_file" ]]; then
        local display company mission server revenue status
        display=$(grep -m1 "^- Name:" "$core_file" 2>/dev/null | sed 's/.*: //')
        company=$(grep -m1 "^- Company:" "$core_file" 2>/dev/null | sed 's/.*: //')
        mission=$(grep -m1 "^- Mission:" "$core_file" 2>/dev/null | sed 's/.*: //')
        server=$(grep -m1 "^- Staging:" "$core_file" 2>/dev/null | sed 's/.*: //')
        revenue=$(grep -m1 "^- Current revenue:" "$core_file" 2>/dev/null | sed 's/.*: //')
        status=$(grep -m1 "^- Status:" "$core_file" 2>/dev/null | sed 's/.*: //')
        [[ -n "$display" ]]  && info "Name:    $display"
        [[ -n "$company" ]]  && info "Company: $company"
        [[ -n "$mission" ]]  && info "Mission: ${mission:0:60}"
        [[ -n "$server" ]]   && info "Server:  $server"
        [[ -n "$revenue" ]]  && info "Revenue: $revenue"
        [[ -n "$status" ]]   && info "Status:  ${status:0:60}"
    else
        bad "memory/core.md missing — cannot read identity"
    fi
    echo ""

    # ── Last activity ─────────────────────────────────────────────────────────
    echo -e "${BOLD}Last Activity${NC}"
    local shutdown_file="$agent_dir/memory/shutdown_state.md"
    if [[ -f "$shutdown_file" ]]; then
        local last_updated current_task
        last_updated=$(grep -m1 "^## Last Updated" -A1 "$shutdown_file" 2>/dev/null | tail -1)
        current_task=$(grep -m1 "^## Current Task" -A1 "$shutdown_file" 2>/dev/null | tail -1 | grep -v "^##")
        [[ -n "$last_updated" ]] && info "Updated: $last_updated"
        [[ -n "$current_task" && "$current_task" != "Awaiting"* ]] && info "Task:    ${current_task:0:70}"
        local mod_epoch now_epoch age_secs
        mod_epoch=$(stat -c %Y "$shutdown_file" 2>/dev/null)
        now_epoch=$(date +%s)
        age_secs=$(( now_epoch - mod_epoch ))
        if (( age_secs < 3600 )); then
            info "Memory:  updated $(( age_secs / 60 ))m ago"
        elif (( age_secs < 86400 )); then
            info "Memory:  updated $(( age_secs / 3600 ))h ago"
        else
            info "Memory:  updated $(( age_secs / 86400 ))d ago"
        fi
    else
        bad "memory/shutdown_state.md missing"
    fi
    echo ""

    # ── File audit ────────────────────────────────────────────────────────────
    echo -e "${BOLD}File Audit${NC}"
    local expected_files=(
        "CLAUDE.md"
        ".claude/settings.json"
        ".env"
        ".gitignore"
        "memory/core.md"
        "memory/shutdown_state.md"
        "memory/crash_recovery.md"
        "memory/agent_onboarding_template.md"
        "start_${agent_name}.sh"
    )
    local missing_count=0
    for f in "${expected_files[@]}"; do
        if [[ -f "$agent_dir/$f" ]]; then
            ok "$f"
        else
            bad "$f — MISSING"
            (( missing_count++ ))
            needs_upgrade=1
        fi
    done
    # Check for logs directory
    if [[ -d "$agent_dir/logs" ]]; then
        local log_count
        log_count=$(find "$agent_dir/logs" -name "*.md" 2>/dev/null | wc -l)
        ok "logs/ ($log_count log files)"
    else
        bad "logs/ — MISSING"
        (( missing_count++ ))
    fi
    # Check .env permissions
    if [[ -f "$agent_dir/.env" ]]; then
        local perms
        perms=$(stat -c "%a" "$agent_dir/.env" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            ok ".env permissions 600"
        else
            bad ".env permissions are $perms (should be 600)"
            needs_upgrade=1
        fi
    fi
    echo ""

    # ── Feature checks (version-specific) ────────────────────────────────────
    echo -e "${BOLD}Feature Checks${NC}"
    local claude_md="$agent_dir/CLAUDE.md"
    local crash_md="$agent_dir/memory/crash_recovery.md"
    local settings_json="$agent_dir/.claude/settings.json"
    local launcher="$agent_dir/start_${agent_name}.sh"
    local upgrade_items=()

    # v1.2.0: portable launcher (no hardcoded /home/ path)
    if [[ -f "$launcher" ]]; then
        if grep -qE 'CLAUDE_BIN=/home/' "$launcher" 2>/dev/null; then
            bad "Launcher has hardcoded /home/ path for claude binary (pre-v1.2.0)"
            upgrade_items+=("launcher: replace hardcoded claude path with runtime detection")
            needs_upgrade=1
        else
            ok "Launcher uses runtime claude detection (v1.2.0+)"
        fi
    fi

    # v1.4.1: launcher must not pipe stdout (breaks interactive TTY)
    if [[ -f "$launcher" ]]; then
        if grep -q '| tee' "$launcher" 2>/dev/null; then
            bad "Launcher pipes stdout with tee — breaks interactive mode (pre-v1.4.1)"
            upgrade_items+=("start_${agent_name}.sh: remove tee pipe — breaks interactive Claude Code sessions")
            needs_upgrade=1
        else
            ok "Launcher runs interactively (v1.4.1+)"
        fi
    fi

    # v1.3.0: settings.json uses real permissions
    if [[ -f "$settings_json" ]]; then
        if grep -q '"autoMemory"' "$settings_json" 2>/dev/null; then
            bad "settings.json has unofficial autoMemory keys (pre-v1.3.0)"
            upgrade_items+=("settings.json: replace autoMemory with real permissions scaffold")
            needs_upgrade=1
        else
            ok "settings.json uses real permissions scaffold (v1.3.0+)"
        fi
    fi

    # v1.3.0: CLAUDE.md session persistence fixed
    if [[ -f "$claude_md" ]]; then
        if grep -q "ls -t ~/.claude/projects" "$claude_md" 2>/dev/null; then
            bad "CLAUDE.md has unreliable ls session command (pre-v1.3.0)"
            upgrade_items+=("CLAUDE.md: remove ls session command, launcher handles this")
            needs_upgrade=1
        else
            ok "CLAUDE.md session persistence clean (v1.3.0+)"
        fi
    fi

    # v1.3.0: CLAUDE.md no 'not-configured' in startup steps
    if [[ -f "$claude_md" ]]; then
        if grep -q "not-configured" "$claude_md" 2>/dev/null; then
            bad "CLAUDE.md startup steps contain 'not-configured' literal (pre-v1.3.0)"
            upgrade_items+=("CLAUDE.md: fix step 11 conditional for no-server case")
            needs_upgrade=1
        else
            ok "CLAUDE.md startup steps clean (v1.3.0+)"
        fi
    fi

    # v1.4.0: source .env in startup steps
    if [[ -f "$claude_md" ]]; then
        if grep -q "Source credentials" "$claude_md" 2>/dev/null; then
            ok ".env sourcing in startup routine (v1.4.0+)"
        else
            warn "Missing: 'source .env' step in CLAUDE.md startup routine (v1.4.0 feature)"
            upgrade_items+=("CLAUDE.md: add 'source .env' as startup step 7")
            needs_upgrade=1
        fi
    fi

    # v1.4.0: server offline recovery in crash_recovery.md
    if [[ -f "$crash_md" ]]; then
        if grep -q "If Server Is Offline" "$crash_md" 2>/dev/null; then
            ok "Server offline recovery documented (v1.4.0+)"
        else
            warn "Missing: 'If Server Is Offline' section in crash_recovery.md (v1.4.0 feature)"
            upgrade_items+=("crash_recovery.md: add server offline contingency section")
            needs_upgrade=1
        fi
    fi

    echo ""

    # ── Custom files (preserve these during upgrade) ──────────────────────────
    echo -e "${BOLD}Custom Files (preserve during upgrade)${NC}"
    local template_files=(
        "CLAUDE.md" ".claude/settings.json" ".env" ".gitignore"
        "memory/core.md" "memory/shutdown_state.md" "memory/crash_recovery.md"
        "memory/agent_onboarding_template.md" "start_${agent_name}.sh"
    )
    local custom_found=0
    # Check memory/ for non-template files
    if [[ -d "$agent_dir/memory" ]]; then
        while IFS= read -r -d '' f; do
            local rel="${f#$agent_dir/}"
            local is_template=0
            for tf in "${template_files[@]}"; do
                [[ "$rel" == "$tf" ]] && is_template=1 && break
            done
            if [[ $is_template -eq 0 ]]; then
                info "$rel"
                (( custom_found++ ))
            fi
        done < <(find "$agent_dir/memory" -type f -print0 2>/dev/null)
    fi
    # Check for skills/, scripts/, templates/ directories
    for d in skills scripts templates; do
        if [[ -d "$agent_dir/$d" ]]; then
            local count
            count=$(find "$agent_dir/$d" -type f 2>/dev/null | wc -l)
            (( count > 0 )) && info "$d/ ($count files)" && (( custom_found++ ))
        fi
    done
    [[ $custom_found -eq 0 ]] && info "none"
    echo ""

    # ── Upgrade summary ───────────────────────────────────────────────────────
    echo -e "${BOLD}Upgrade Assessment${NC}"
    if [[ $needs_upgrade -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✔ Up to date — no upgrade needed${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}⚠ Upgrade recommended (v$detected_version → v$CURRENT_VERSION)${NC}"
        echo ""
        echo -e "  ${BOLD}What would change:${NC}"
        for item in "${upgrade_items[@]}"; do
            echo -e "  ${YELLOW}→${NC}  $item"
        done
        echo ""
        echo -e "  ${BOLD}What would be preserved:${NC}"
        echo -e "  ${DIM}·${NC}  memory/core.md (business state)"
        echo -e "  ${DIM}·${NC}  memory/shutdown_state.md (task state)"
        echo -e "  ${DIM}·${NC}  logs/ (all history)"
        echo -e "  ${DIM}·${NC}  .env (credentials)"
        echo -e "  ${DIM}·${NC}  All custom files listed above"
        echo ""
        echo -e "  Run: ${CYAN}bash upgrade_agent.sh $agent_name${NC}"
    fi
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         AgentCEO — Agent Analyzer v$CURRENT_VERSION           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

if [[ "$1" == "--all" ]] || [[ -z "$1" ]]; then
    agents=( $(find_all_agents) )
    if [[ ${#agents[@]} -eq 0 ]]; then
        echo ""
        echo "No agents found under $BASE_DIR"
        echo "Usage: bash analyze_agent.sh agentname"
        echo "       bash analyze_agent.sh --all"
        exit 0
    fi
    for agent_dir in "${agents[@]}"; do
        analyze_agent "$agent_dir"
    done
else
    agent_dir=$(resolve_dir "$1")
    if [[ -z "$agent_dir" ]]; then
        echo ""
        echo -e "${RED}Error: agent '$1' not found under $BASE_DIR${NC}"
        echo "Usage: bash analyze_agent.sh agentname"
        echo "       bash analyze_agent.sh --all"
        exit 1
    fi
    analyze_agent "$agent_dir"
fi

echo -e "${DIM}Analyzer complete.${NC}"
echo ""
