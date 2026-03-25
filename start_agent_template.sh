#!/bin/bash
# [AGENT_NAME] Launcher — AgentCEO
# Replace [AGENT_NAME], [AGENT_DIR], [AGENT_EMOJI], [AGENT_DISPLAY] with real values.
unset ANTHROPIC_API_KEY

AGENT_DIR="$HOME/[AGENT_DIR]"
RESUME_FILE="$AGENT_DIR/memory/last_session.txt"
CLAUDE_BIN=$(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude")

# Load agent credentials
set -a
source "$AGENT_DIR/.env" 2>/dev/null
set +a

echo "[AGENT_EMOJI] Launching [AGENT_DISPLAY]..."

cd "$AGENT_DIR"

if [ -f "$RESUME_FILE" ] && [ -s "$RESUME_FILE" ]; then
    SESSION_ID=$(cat "$RESUME_FILE")
    # Validate session ID format before use
    if [[ "$SESSION_ID" =~ ^[0-9a-f-]{36}$ ]]; then
        echo "📂 Resuming session: $SESSION_ID"
        exec $CLAUDE_BIN \
            --resume "$SESSION_ID" \
            --dangerously-skip-permissions \
            "[AGENT_DISPLAY], execute your startup routine now."
    else
        echo "⚠️  Invalid session ID — starting fresh"
        rm -f "$RESUME_FILE"
    fi
fi

echo "🆕 Starting fresh session..."
exec $CLAUDE_BIN \
    --continue \
    --dangerously-skip-permissions \
    "[AGENT_DISPLAY], execute your startup routine now."
