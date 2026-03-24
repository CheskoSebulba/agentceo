#!/bin/bash
# [AGENT_NAME] Launcher
unset ANTHROPIC_API_KEY

AGENT_DIR="$HOME/[AGENT_DIR]"
RESUME_FILE="$AGENT_DIR/memory/last_session.txt"

echo "🤖 Launching [AGENT_NAME]..."

cd "$AGENT_DIR"

if [ -f "$RESUME_FILE" ]; then
    SESSION_ID=$(cat "$RESUME_FILE")
    echo "📂 Resuming session: $SESSION_ID"
    exec $(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude") \
        --resume "$SESSION_ID" \
        --dangerously-skip-permissions \
        "[AGENT_NAME], execute your startup routine now."
else
    echo "🆕 Starting fresh session..."
    exec $(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude") \
        --dangerously-skip-permissions
fi
