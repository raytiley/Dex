#!/bin/bash
# Dex PKM - Installation Script
# This script sets up your development environment

set -e

echo "🚀 Setting up Dex..."
echo ""

# Check for Command Line Tools on macOS (required for git)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! xcode-select -p &> /dev/null; then
        echo "⚠️  Command Line Developer Tools not found"
        echo ""
        echo "macOS will now prompt you to install them - this is required for git."
        echo "Click 'Install' when the dialog appears (takes 2-3 minutes)."
        echo ""
        echo "Press Enter to continue..."
        read -r
        
        # Trigger the install prompt
        xcode-select --install 2>/dev/null || true
        
        echo ""
        echo "⏳ Waiting for Command Line Tools installation..."
        echo "   (This window will continue once installation completes)"
        echo ""
        
        # Wait for installation to complete
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
        
        echo "✅ Command Line Tools installed!"
        echo ""
    fi
fi

# Silently fix git remote to avoid Claude Desktop confusion
if git remote -v 2>/dev/null | grep -q "davekilleen/[Dd]ex"; then
    git remote rename origin upstream 2>/dev/null || true
fi

# Check Git first (required for repo operations)
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed"
    echo ""
    echo "Git is required to clone the repository and manage updates."
    echo ""
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "Download Git for Windows from: https://git-scm.com/download/win"
        echo "After installing, restart your terminal and run ./install.sh again"
    else
        echo "Download Git from: https://git-scm.com"
        echo "After installing, restart your terminal and run ./install.sh again"
    fi
    exit 1
fi
echo "✅ Git $(git --version | cut -d' ' -f3)"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    echo "   Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version must be 18 or higher (found v$NODE_VERSION)"
    echo "   Please upgrade from https://nodejs.org/"
    exit 1
fi
echo "✅ Node.js $(node -v)"

# Check Python (required for Work MCP - task sync)
# Windows often uses 'python' instead of 'python3'
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    # Verify it's Python 3, not Python 2
    PYTHON_VERSION=$(python --version 2>&1 | grep "Python 3")
    if [ -n "$PYTHON_VERSION" ]; then
        PYTHON_CMD="python"
    fi
fi

if [ -n "$PYTHON_CMD" ]; then
    PYTHON_VERSION=$($PYTHON_CMD --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    # Check if Python 3.10+
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]; then
        echo "❌ Python $PYTHON_VERSION found (too old)"
        echo ""
        echo "MCP SDK requires Python 3.10 or newer."
        echo "You have Python $PYTHON_VERSION which is too old."
        echo ""
        echo "Install Python 3.10+:"
        echo "  Download the latest version from https://www.python.org/downloads/"
        echo "  After installing, restart your terminal and run ./install.sh again"
        exit 1
    fi
    
    echo "✅ Python $PYTHON_VERSION"
else
    echo "❌ Python 3 not found"
    echo ""
    echo "Python 3.10+ is required for MCP servers (task sync across all files)."
    echo "Without it, tasks won't sync between meeting notes, person pages, and Tasks.md."
    echo ""
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "Install Python 3.10+:"
        echo "  1. Download from https://www.python.org/downloads/"
        echo "  2. Run the installer"
        echo "  3. ⚠️  IMPORTANT: Check 'Add Python to PATH' during installation"
        echo "  4. Restart your terminal"
        echo "  5. Run ./install.sh again"
    else
        echo "Install Python 3.10+:"
        echo "  Mac: Download from https://www.python.org/downloads/"
        echo "  Or use Homebrew: brew install python3"
        echo ""
        echo "After installing, run ./install.sh again"
    fi
    exit 1
fi

# Check npx (required for MCP servers)
if ! command -v npx &> /dev/null; then
    echo "⚠️  npx not found (usually bundled with Node.js)"
    echo "   Some MCP servers may not work without npx."
    echo "   Try reinstalling Node.js from https://nodejs.org/"
fi

# Install Node dependencies
echo ""
echo "📦 Installing dependencies..."
if command -v pnpm &> /dev/null; then
    pnpm install
elif command -v npm &> /dev/null; then
    npm install
else
    echo "❌ Neither npm nor pnpm found"
    exit 1
fi

# Skip .env creation - it's created during /setup if needed
# (Most users don't need API keys - everything works through Cursor)

# Sync MCP servers to Cursor and Claude Desktop
echo ""
echo "🔄 Syncing MCP servers to AI clients..."
if [ -f "core/scripts/sync-mcp-configs.sh" ]; then
    bash core/scripts/sync-mcp-configs.sh --quiet
    echo "✅ Dex MCP servers synced to Cursor and Claude Desktop"
else
    echo "⚠️  Sync script not found - MCP servers may not be available in Cursor/Claude"
    echo "   You can manually copy .mcp.json entries to your AI client configs"
fi

# Check for Granola (optional)
echo ""
if ls "$HOME/Library/Application Support/Granola/cache-v"*.json 1>/dev/null 2>&1; then
    echo "✅ Granola detected - meeting intelligence available"
else
    echo "ℹ️  Granola not detected - meeting intelligence won't work"
    echo "   Install Granola from https://granola.ai for meeting transcription"
fi

# Install Python dependencies in a virtual environment (CRITICAL for task sync)
echo ""
echo "📦 Installing Python dependencies for Work MCP..."

VENV_DIR="$(pwd)/.venv"

if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/python3" -o -f "$VENV_DIR/Scripts/python.exe" ]; then
    echo "   Using existing virtual environment at .venv/"
else
    echo "   Creating virtual environment..."
    if ! $PYTHON_CMD -m venv "$VENV_DIR" 2>/dev/null; then
        echo "❌ Could not create virtual environment"
        echo ""
        echo "Try manually:"
        echo "  $PYTHON_CMD -m venv .venv"
        echo "  .venv/bin/pip install mcp pyyaml"
        echo ""
        read -p "Press Enter to continue setup (you can fix this later)..."
        VENV_DIR=""
    fi
fi

if [ -n "$VENV_DIR" ]; then
    # Determine venv pip/python paths (cross-platform)
    if [ -f "$VENV_DIR/bin/pip" ]; then
        VENV_PIP="$VENV_DIR/bin/pip"
        VENV_PYTHON="$VENV_DIR/bin/python3"
    elif [ -f "$VENV_DIR/Scripts/pip.exe" ]; then
        VENV_PIP="$VENV_DIR/Scripts/pip.exe"
        VENV_PYTHON="$VENV_DIR/Scripts/python.exe"
    else
        echo "❌ Virtual environment created but pip not found inside it"
        VENV_DIR=""
    fi
fi

if [ -n "$VENV_DIR" ]; then
    if $VENV_PIP install mcp pyyaml --quiet 2>&1; then
        echo "✅ Work MCP dependencies installed (in .venv/)"
    else
        echo "❌ Could not install Python dependencies"
        echo ""
        echo "Try manually:"
        echo "  $VENV_PIP install mcp pyyaml"
        echo ""
        read -p "Press Enter to continue setup (you can fix this later)..."
    fi
fi

# Create .mcp.json with current path and venv Python path
if [ ! -f .mcp.json ]; then
    echo ""
    echo "📝 Creating .mcp.json with workspace path..."
    CURRENT_PATH="$(pwd)"

    # Use the venv Python if available, otherwise fall back to system Python
    if [ -n "$VENV_DIR" ] && [ -n "$VENV_PYTHON" ]; then
        MCP_PYTHON="$VENV_PYTHON"
    else
        MCP_PYTHON="$PYTHON_CMD"
    fi

    sed "s|{{VAULT_PATH}}|$CURRENT_PATH|g; s|\"python\"|\"$MCP_PYTHON\"|g" System/.mcp.json.example > .mcp.json
    echo "   MCP servers configured for: $CURRENT_PATH"
    echo "   Python command: $MCP_PYTHON"
fi

# Verify Work MCP setup
echo ""
echo "🔍 Verifying Work MCP setup..."
VERIFY_PYTHON="${VENV_PYTHON:-$PYTHON_CMD}"
if [ -n "$VERIFY_PYTHON" ]; then
    if $VERIFY_PYTHON -c "import mcp, yaml" 2>/dev/null; then
        echo "✅ Work MCP verified - task sync will work"
        WORK_MCP_STATUS="✅ Working"

        # Generate path constants for CJS/TS consumers
        echo "Generating path constants..."
        VAULT_PATH="$(pwd)" $VERIFY_PYTHON core/paths.py 2>/dev/null || true
    else
        echo "⚠️  Work MCP not working - task sync won't function"
        WORK_MCP_STATUS="⚠️  Needs attention"
    fi
else
    WORK_MCP_STATUS="⚠️  Needs attention"
fi

# Success
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Dex installation complete!"
echo ""
echo "Status:"
echo "  • Node.js: ✅ Working"
echo "  • Work MCP: $WORK_MCP_STATUS"
if [[ "$WORK_MCP_STATUS" == *"Needs"* ]]; then
    echo ""
    echo "⚠️  IMPORTANT: Work MCP enables task sync across all files."
    echo "   Without it, Dex works but tasks won't sync automatically."
    echo "   See troubleshooting above to fix."
fi
echo ""
echo "Next steps:"
echo "  1. In Cursor chat, type: /setup"
echo "  2. Answer the setup questions (~5 minutes)"
echo "  3. Start using Dex!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
