#!/bin/bash
# ============================================================
# AgentCEO — Telegram Notifier
# Send a message from an agent to its backer via Telegram.
#
# Usage:
#   bash telegram_notify.sh "Your message here"
#   bash telegram_notify.sh --morning   (sends morning report)
#   bash telegram_notify.sh --evening   (sends evening summary)
#
# Setup (one time):
#   1. Message @BotFather on Telegram → /newbot → copy the token
#   2. Start a chat with your new bot, then visit:
#      https://api.telegram.org/bot<TOKEN>/getUpdates
#      to find your chat_id
#   3. Add to your agent's .env:
#      TELEGRAM_BOT_TOKEN=your_token_here
#      TELEGRAM_CHAT_ID=your_chat_id_here
#
# This script is automatically copied to your agent's scripts/ directory.
# Call it from the agent's CLAUDE.md morning/evening routines.
# ============================================================

# ── Load env ──────────────────────────────────────────────────────────────────
AGENT_DIR="${AGENT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ -f "$AGENT_DIR/.env" ]]; then
    set -a; source "$AGENT_DIR/.env" 2>/dev/null; set +a
fi

# ── Validate config ───────────────────────────────────────────────────────────
if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
    echo "⚠️  Telegram not configured. Add to $AGENT_DIR/.env:"
    echo "   TELEGRAM_BOT_TOKEN=your_token_here"
    echo "   TELEGRAM_CHAT_ID=your_chat_id_here"
    echo ""
    echo "   Setup guide: https://github.com/CheskoSebulba/agentceo#telegram-setup"
    exit 1
fi

AGENT_NAME="${AGENT_NAME:-$(basename "$AGENT_DIR")}"
CORE_MD="$AGENT_DIR/memory/core.md"
SHUTDOWN_MD="$AGENT_DIR/memory/shutdown_state.md"
TODAY=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M')

# ── Build message ─────────────────────────────────────────────────────────────
build_morning() {
    local status revenue priorities blockers
    status=$(grep '- Status:' "$CORE_MD" 2>/dev/null | head -1 | sed 's/.*: //')
    revenue=$(grep '- Current revenue:' "$CORE_MD" 2>/dev/null | head -1 | sed 's/.*: //')

    priorities=$(awk '/^## Next Step/{f=1;next}/^## /{f=0}f&&/^[-•0-9]/{sub(/^[-•0-9. ]*/,"");print;c++}c==3{exit}' "$SHUTDOWN_MD" 2>/dev/null)
    blockers=$(awk '/^## Blockers/{f=1;next}/^## /{f=0}f&&/^[-•]/{sub(/^[-•] */,"");print;c++}c==3{exit}' "$SHUTDOWN_MD" 2>/dev/null)

    echo "🌅 *$AGENT_NAME — Morning Report*"
    echo "_$TODAY · $TIME_NOW_"
    echo ""
    echo "📊 *Status:* ${status:-Active}"
    echo "💰 *Revenue:* ${revenue:-\$0}"
    echo ""
    echo "🎯 *Top priorities today:*"
    if [[ -n "$priorities" ]]; then
        while IFS= read -r line; do echo "  · $line"; done <<< "$priorities"
    else
        echo "  · Check memory files for current tasks"
    fi
    if [[ -n "$blockers" && "$blockers" != *"None"* ]]; then
        echo ""
        echo "🚧 *Blockers:*"
        while IFS= read -r line; do echo "  · $line"; done <<< "$blockers"
    fi
}

build_evening() {
    local last_completed
    last_completed=$(awk '/^## Last Completed/{f=1;next}/^## /{f=0}f&&NF{sub(/^[-•] */,"");print;exit}' "$SHUTDOWN_MD" 2>/dev/null)

    log_file="$AGENT_DIR/logs/$TODAY.md"
    recent_tasks=""
    if [[ -f "$log_file" ]]; then
        recent_tasks=$(grep '^- ' "$log_file" 2>/dev/null | tail -5 | sed 's/^- /  · /')
    fi

    echo "🌙 *$AGENT_NAME — Evening Summary*"
    echo "_$TODAY · $TIME_NOW_"
    echo ""
    if [[ -n "$last_completed" ]]; then
        echo "✅ *Last completed:* $last_completed"
        echo ""
    fi
    if [[ -n "$recent_tasks" ]]; then
        echo "📋 *Today's activity:*"
        echo "$recent_tasks"
        echo ""
    fi
    echo "💤 Signing off. See you tomorrow."
}

# ── Send ──────────────────────────────────────────────────────────────────────
send_message() {
    local text="$1"
    local response
    response=$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=$text" \
        2>/dev/null)

    if echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('ok') else 1)" 2>/dev/null; then
        echo "✅ Telegram message sent"
    else
        echo "❌ Telegram send failed"
        echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description','unknown error'))" 2>/dev/null
        exit 1
    fi
}

# ── Route ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --morning) send_message "$(build_morning)" ;;
    --evening) send_message "$(build_evening)" ;;
    "")
        echo "Usage: bash telegram_notify.sh \"message\""
        echo "       bash telegram_notify.sh --morning"
        echo "       bash telegram_notify.sh --evening"
        exit 1
        ;;
    *) send_message "$1" ;;
esac
