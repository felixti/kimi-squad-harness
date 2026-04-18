#!/bin/bash
# Kimi Squad Harness — Automated Setup
# Usage: ./setup.sh

set -e

REPO_URL="https://github.com/felixti/kimi-squad-harness.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIMI_DIR="$HOME/.kimi"
AGENTS_DIR="$KIMI_DIR/agents/squad"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        Kimi Squad Harness — Automated Setup                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# STEP 0: Check Dependencies
# ============================================================
echo "📋 Checking dependencies..."

MISSING_DEPS=()

if ! command -v kimi &> /dev/null; then
    MISSING_DEPS+=("kimi-cli")
fi

if ! command -v npx &> /dev/null; then
    MISSING_DEPS+=("Node.js + npm")
fi

if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo ""
    echo "❌ Missing dependencies:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "   - $dep"
    done
    echo ""
    echo "Please install missing dependencies first:"
    echo ""
    echo "   Kimi CLI:   pip install kimi-cli"
    echo "   Node.js:    https://nodejs.org/"
    echo "   Git:        https://git-scm.com/"
    echo ""
    exit 1
fi

echo "   ✅ All dependencies found"

# ============================================================
# STEP 1: Verify We're in the Repo
# ============================================================
echo ""
echo "📦 Verifying harness files..."

if [ ! -f "$SCRIPT_DIR/squad/squad.yaml" ]; then
    echo "❌ Error: squad.yaml not found in $SCRIPT_DIR/squad/"
    echo "   Please run this script from the cloned repository."
    echo ""
    echo "   git clone $REPO_URL"
    echo "   cd kimi-squad-harness"
    echo "   ./setup.sh"
    echo ""
    exit 1
fi

echo "   ✅ Harness files verified"

# ============================================================
# STEP 2: Create Directory Structure
# ============================================================
echo ""
echo "📁 Creating directory structure..."

mkdir -p "$AGENTS_DIR"
mkdir -p "$KIMI_DIR"
mkdir -p "$HOME/.agents/skills"

echo "   ✅ Directories created"

# ============================================================
# STEP 3: Copy Squad Agents
# ============================================================
echo ""
echo "🤖 Installing squad agents..."

cp "$SCRIPT_DIR/squad/"*.yaml "$AGENTS_DIR/"
cp "$SCRIPT_DIR/squad/"*.md "$AGENTS_DIR/"
cp "$SCRIPT_DIR/squad/test-harness.sh" "$AGENTS_DIR/"
chmod +x "$AGENTS_DIR/test-harness.sh"

echo "   ✅ Agents installed to $AGENTS_DIR"

# ============================================================
# STEP 4: Install Skills
# ============================================================
echo ""
echo "📚 Installing skills (this may take a few minutes)..."
echo ""

SKILLS=(
    "addyosmani/web-quality-skills@best-practices"
    "skillcreatorai/ai-agent-skills@backend-development"
    "manutej/luxor-claude-marketplace@nodejs-development"
    "pluginagentmarketplace/custom-plugin-nodejs@express-rest-api"
    "b-open-io/prompts@frontend-performance"
    "daffy0208/ai-dev-standards@accessibility-engineer"
    "vercel-labs/json-render@react"
    "travisjneuman/.claude@database-expert"
    "1mangesh1/dev-skills-collection@docker-helper"
    "thebushidocollective/han@playwright-page-object-model"
    "manutej/luxor-claude-marketplace@frontend-architecture"
    "vercel-labs/json-render@next"
    "addyosmani/web-quality-skills@verification-before-completion"
    "softaworks/agent-toolkit@writing-plans"
    # Additional skills referenced by prompts but not auto-installed:
    # brainstorming, dispatching-parallel-agents, find-docs, find-skills,
    # subagent-driven-development, test-driven-development
    # Install manually with: ctx7 skills install <source>@<skill-name>
)

INSTALLED=0
FAILED=0

for skill in "${SKILLS[@]}"; do
    SKILL_NAME=$(echo "$skill" | cut -d'@' -f2)
    if [ -d "$HOME/.agents/skills/$SKILL_NAME" ]; then
        echo "   ⏭️  $SKILL_NAME (already installed)"
        INSTALLED=$((INSTALLED + 1))
    else
        echo -n "   📥 $SKILL_NAME ... "
        if npx skills add "$skill" -g -y > /tmp/skill-install.log 2>&1; then
            echo "✅"
            INSTALLED=$((INSTALLED + 1))
        else
            echo "❌"
            FAILED=$((FAILED + 1))
            echo "      (check /tmp/skill-install.log for details)"
        fi
    fi
done

echo ""
echo "   Skills: $INSTALLED installed, $FAILED failed"

# ============================================================
# STEP 5: Configure MCP
# ============================================================
echo ""
echo "🔌 Setting up MCP configuration..."

MCP_CONFIG="$KIMI_DIR/mcp.json"

if [ -f "$MCP_CONFIG" ]; then
    echo ""
    read -p "   MCP config already exists. Overwrite? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$SCRIPT_DIR/mcp/mcp.json.example" "$MCP_CONFIG"
        echo "   ✅ MCP config overwritten"
    else
        echo "   ⏭️  Keeping existing MCP config"
    fi
else
    cp "$SCRIPT_DIR/mcp/mcp.json.example" "$MCP_CONFIG"
    echo "   ✅ MCP config created at $MCP_CONFIG"
fi

# Check if API key is still placeholder
if grep -q "YOUR_BRAVE_API_KEY_HERE" "$MCP_CONFIG" 2>/dev/null; then
    echo ""
    echo "   ⚠️  WARNING: Brave Search API key is still a placeholder!"
    echo ""
    echo "   Get your free API key at: https://api.search.brave.com/app/keys"
    echo "   Then edit: $MCP_CONFIG"
    echo ""
fi

# ============================================================
# STEP 6: Add Shell Aliases
# ============================================================
echo ""
echo "🐚 Adding shell aliases..."

SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    echo "   ⚠️  No .zshrc or .bashrc found. Skipping alias setup."
    echo "      Add these manually to your shell config:"
    echo ""
    echo "      alias kimi-squad='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 10'"
    echo "      alias kimi-squad-quick='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 1 --yolo'"
    echo "      alias squad-test='~/.kimi/agents/squad/test-harness.sh'"
    echo ""
fi

if [ -n "$SHELL_RC" ]; then
    # Check if aliases already exist
    if grep -q "alias kimi-squad=" "$SHELL_RC" 2>/dev/null; then
        echo "   ⏭️  Aliases already exist in $SHELL_RC"
    else
        cat >> "$SHELL_RC" << 'EOF'

# Kimi Squad Aliases
alias kimi-squad='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 10'
alias kimi-squad-quick='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 1 --yolo'
alias squad-test='~/.kimi/agents/squad/test-harness.sh'
EOF
        echo "   ✅ Aliases added to $SHELL_RC"
        echo "   🔄 Run: source $SHELL_RC"
    fi
fi

# ============================================================
# STEP 7: Run Test Harness
# ============================================================
echo ""
echo "🧪 Running validation tests..."
echo ""

if "$AGENTS_DIR/test-harness.sh"; then
    echo ""
    echo "✅ All validation tests passed!"
else
    echo ""
    echo "⚠️  Some tests failed. Check output above."
fi

# ============================================================
# STEP 8: Set Up Memory System
# ============================================================
echo ""
echo "🧠 Setting up memory system..."

if [ -d ".context" ]; then
    echo "   ⏭️  .context/ already exists"
else
    mkdir -p .context/{docs,agents,plans,skills}
    cp "$SCRIPT_DIR/dotfiles/.context/docs/"*.example .context/docs/ 2>/dev/null || true
    cp "$SCRIPT_DIR/dotfiles/.context/agents/"*.example .context/agents/ 2>/dev/null || true
    cp "$SCRIPT_DIR/dotfiles/.context/plans/"*.example .context/plans/ 2>/dev/null || true
    
    # Rename .example files
    for f in .context/docs/*.example .context/agents/*.example .context/plans/*.example; do
        [ -f "$f" ] && mv "$f" "${f%.example}"
    done
    
    echo "   ✅ Memory system created at ./.context/"
fi

# ============================================================
# STEP 9: Summary
# ============================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  Setup Complete! 🎉                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "What's installed:"
echo "   🤖 Squad agents       → $AGENTS_DIR"
echo "   📚 Skills             → ~/.agents/skills/ ($(ls ~/.agents/skills/ 2>/dev/null | wc -l) skills)"
echo "   🔌 MCP config         → $MCP_CONFIG"
echo "   🐚 Shell aliases      → $SHELL_RC"
echo "   🧠 Memory system      → ./.context/"
echo ""
echo "Quick start:"
echo "   1. Get Brave API key: https://api.search.brave.com/app/keys"
echo "   2. Edit: $MCP_CONFIG"
echo "   3. Reload shell: source $SHELL_RC"
echo "   4. Launch squad: kimi-squad"
echo ""
echo "Commands:"
echo "   kimi-squad        → Interactive mode (with approvals)"
echo "   kimi-squad-quick  → Quick mode (auto-approve, 1 iteration)"
echo "   squad-test        → Run validation harness"
echo ""
echo "Project config template:"
echo "   cp $SCRIPT_DIR/dotfiles/.kimi/AGENTS.md.example ./.kimi/AGENTS.md"
echo ""
echo "Memory system:"
echo "   The squad will automatically read/write ./.context/ for persistent memory"
echo ""
echo "Happy coding! 🚀"
echo ""
