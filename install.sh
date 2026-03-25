#!/bin/bash
# ============================================================
# AgentCEO — One-Line Installer
# curl -sSL https://raw.githubusercontent.com/CheskoSebulba/agentceo/main/install.sh | bash
# Version: 1.0.0
# ============================================================

set -e

REPO_URL="https://github.com/CheskoSebulba/agentceo.git"
RAW_URL="https://raw.githubusercontent.com/CheskoSebulba/agentceo/main"
INSTALL_DIR="$HOME/agentceo"
BIN_DIR="$HOME/.local/bin"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌  $1${NC}"; exit 1; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          AgentCEO Installer v1.0         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Detect OS ─────────────────────────────────────────────────────────────────
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then echo "debian"
        elif command -v dnf &>/dev/null;  then echo "fedora"
        elif command -v pacman &>/dev/null; then echo "arch"
        else echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    else echo "unknown"
    fi
}

OS=$(detect_os)
info "Detected OS: $OS"

# ── Check Claude Code ──────────────────────────────────────────────────────────
check_claude() {
    if command -v claude &>/dev/null; then
        CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
        ok "Claude Code found: $CLAUDE_VERSION"
        return 0
    fi

    # Common install locations
    for p in "$HOME/.npm-global/bin/claude" "$HOME/.local/bin/claude" "/usr/local/bin/claude"; do
        if [[ -x "$p" ]]; then
            ok "Claude Code found at $p"
            # Ensure it's in PATH
            mkdir -p "$BIN_DIR"
            ln -sf "$p" "$BIN_DIR/claude" 2>/dev/null || true
            return 0
        fi
    done

    warn "Claude Code not found in PATH."
    echo ""
    echo "  Install Claude Code first:"
    echo "  https://claude.ai/code"
    echo ""
    read -rp "Continue anyway? (y/n): " ans
    [[ "$ans" == "y" ]] || fail "Install cancelled — install Claude Code first."
}

check_claude

# ── Check git ─────────────────────────────────────────────────────────────────
command -v git &>/dev/null || fail "git is required. Install it and try again."
ok "git found"

# ── Clone or update AgentCEO ──────────────────────────────────────────────────
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "AgentCEO already installed at $INSTALL_DIR — updating..."
    git -C "$INSTALL_DIR" pull --quiet
    ok "Updated to latest"
else
    info "Cloning AgentCEO to $INSTALL_DIR..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    ok "Cloned"
fi

chmod +x "$INSTALL_DIR/create_agent.sh"

# ── Add newagent alias ────────────────────────────────────────────────────────
SHELL_RC=""
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

ALIAS_LINE="alias newagent='bash $INSTALL_DIR/create_agent.sh'"

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "alias newagent=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# AgentCEO" >> "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        ok "Added 'newagent' alias to $SHELL_RC"
    else
        ok "'newagent' alias already in $SHELL_RC"
    fi
else
    warn "Could not detect shell config file. Add this manually:"
    echo "  $ALIAS_LINE"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       ✅ AgentCEO is installed!          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
if [[ -n "$SHELL_RC" ]]; then
    echo "  Start a new terminal (or run: source $SHELL_RC)"
else
    echo "  Start a new terminal"
fi
echo "  Then type:  newagent"
echo ""
echo "  Docs: https://github.com/CheskoSebulba/agentceo"
echo ""
