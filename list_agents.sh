#!/bin/bash
# ============================================================
# AgentCEO — List Agents
# Shows all AgentCEO agents installed on this machine.
# Usage: bash list_agents.sh [--upgrade-check]
# ============================================================

BASE_DIR="${AGENTCEO_BASE:-$HOME}"
CHECK_UPGRADES=false
[[ "$1" == "--upgrade-check" ]] && CHECK_UPGRADES=true

CURRENT_VERSION="1.6.0"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Find agents ───────────────────────────────────────────────────────────────
agents=()
for claude_md in "$BASE_DIR"/*/CLAUDE.md; do
    [[ -f "$claude_md" ]] || continue
    agent_dir=$(dirname "$claude_md")
    agent_name=$(basename "$agent_dir")
    # Confirm it looks like an AgentCEO agent
    grep -q "autonomous AI CEO" "$claude_md" 2>/dev/null || continue
    agents+=("$agent_dir")
done

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              AgentCEO — Agent Fleet                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ ${#agents[@]} -eq 0 ]]; then
    echo -e "  ${DIM}No agents found under $BASE_DIR${NC}"
    echo ""
    echo -e "  Create one: ${CYAN}bash create_agent.sh${NC}"
    echo ""
    exit 0
fi

echo -e "  ${DIM}Found ${#agents[@]} agent(s) in $BASE_DIR${NC}"
echo ""

# ── Parse helpers ─────────────────────────────────────────────────────────────
get_core_field() {
    local file="$1" pattern="$2"
    grep "$pattern" "$file" 2>/dev/null | head -1 | sed 's/.*: //' | xargs
}

get_section_first_line() {
    local file="$1" header="$2"
    awk "/^## $header/{f=1; next} /^## /{f=0} f && /^[-•]/ && NF{sub(/^[-•] */,\"\"); print; exit}" "$file" 2>/dev/null
}

server_status() {
    local host="$1"
    [[ -z "$host" || "$host" == "not-configured" || "$host" == "not yet configured" ]] && echo "—" && return
    if curl -s --connect-timeout 2 "http://$host" &>/dev/null 2>&1 || ping -c1 -W2 "$host" &>/dev/null 2>&1 || ping -c1 -t2 "$host" &>/dev/null 2>&1; then
        echo -e "${GREEN}●${NC} online"
    else
        echo -e "${RED}●${NC} offline"
    fi
}

launcher_version() {
    local launcher="$1"
    grep -o 'AgentCEO v[0-9.]*' "$launcher" 2>/dev/null | head -1 | grep -o '[0-9.]*'
}

# ── Print each agent ──────────────────────────────────────────────────────────
for agent_dir in "${agents[@]}"; do
    name=$(basename "$agent_dir")
    core="$agent_dir/memory/core.md"
    shutdown="$agent_dir/memory/shutdown_state.md"
    launcher="$agent_dir/start_${name}.sh"

    company=$(get_core_field "$core" "- Company:")
    status=$(get_core_field "$core" "- Status:")
    revenue=$(get_core_field "$core" "- Current revenue:")
    server=$(get_core_field "$core" "- Staging:")
    # Strip extra info after dash
    server=$(echo "$server" | cut -d' ' -f1)

    current_task=$(get_section_first_line "$shutdown" "Current Task")
    [[ -z "$current_task" ]] && current_task=$(get_section_first_line "$shutdown" "Next Step")
    [[ -z "$current_task" ]] && current_task="—"

    # Last active from logs
    last_log=$(ls -t "$agent_dir/logs/"*.md 2>/dev/null | grep -v test_ | head -1)
    if [[ -n "$last_log" ]]; then
        last_active=$(basename "$last_log" .md)
    else
        last_active="never"
    fi

    echo -e "  ${BOLD}${CYAN}$name${NC}${BOLD} · $company${NC}"
    echo -e "  ${DIM}Status:${NC}      $status"
    echo -e "  ${DIM}Revenue:${NC}     ${revenue:-—}"
    echo -e "  ${DIM}Last active:${NC} $last_active"
    echo -e "  ${DIM}Server:${NC}      $(server_status "$server") ${DIM}($server)${NC}"
    echo -e "  ${DIM}Current task:${NC} $current_task"

    if [[ "$CHECK_UPGRADES" == true ]] && [[ -f "$launcher" ]]; then
        agent_ver=$(launcher_version "$launcher")
        if [[ -n "$agent_ver" && "$agent_ver" != "$CURRENT_VERSION" ]]; then
            echo -e "  ${YELLOW}⚠  Upgrade available: $agent_ver → $CURRENT_VERSION${NC}"
            echo -e "  ${DIM}   Run: bash upgrade_agent.sh $name${NC}"
        elif [[ -n "$agent_ver" ]]; then
            echo -e "  ${GREEN}✔  Up to date (v$agent_ver)${NC}"
        fi
    fi

    echo ""
done

echo -e "  ${DIM}Tip: bash list_agents.sh --upgrade-check  to check versions${NC}"
echo ""
