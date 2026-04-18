#!/bin/bash
# Squad Harness Setup Script
# Idempotent setup for the Kimi Squad Harness
set -e

SQUAD_DIR="${SQUAD_DIR:-$HOME/.kimi/agents/squad}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONTEXT_DIR="${CONTEXT_DIR:-.}"

echo "🚀 Squad Harness Setup"
echo "======================"

# =============================================================================
# PREREQUISITES
# =============================================================================
echo ""
echo "Checking prerequisites..."

MISSING=()

if ! command -v kimi >/dev/null 2>&1; then
    MISSING+=("kimi CLI")
fi

if ! command -v tmux >/dev/null 2>&1; then
    MISSING+=("tmux")
fi

if ! command -v python3 >/dev/null 2>&1; then
    MISSING+=("python3")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "❌ Missing prerequisites: ${MISSING[*]}"
    echo ""
    echo "Install instructions:"
    echo "  kimi CLI:  https://github.com/felixti/kimi-cli (or your package manager)"
    echo "  tmux:      sudo apt install tmux  /  brew install tmux"
    echo "  python3:   sudo apt install python3"
    exit 1
fi

echo "✅ All prerequisites met"

# =============================================================================
# SQUAD AGENTS
# =============================================================================
echo ""
echo "Installing squad agents to $SQUAD_DIR..."

mkdir -p "$SQUAD_DIR"

# Copy all files from repo to squad directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in "$SCRIPT_DIR"/*.md "$SCRIPT_DIR"/*.yaml "$SCRIPT_DIR"/*.json "$SCRIPT_DIR"/*.sh; do
    [ -f "$f" ] || continue
    cp "$f" "$SQUAD_DIR/"
done

chmod +x "$SQUAD_DIR"/*.sh 2>/dev/null || true

echo "✅ Squad agents installed"

# =============================================================================
# WRAPPER SCRIPT
# =============================================================================
echo ""
echo "Installing wrapper script..."

if [ -f "$SCRIPT_DIR/run_squad.sh" ]; then
    cp "$SCRIPT_DIR/run_squad.sh" /tmp/run_squad.sh
    chmod +x /tmp/run_squad.sh
    echo "✅ Wrapper installed at /tmp/run_squad.sh"
else
    echo "⚠️  Wrapper script not found in repo (expected at $SCRIPT_DIR/run_squad.sh)"
    echo "    The harness will still work for interactive use."
fi

# =============================================================================
# CONTEXT DIRECTORY
# =============================================================================
echo ""
echo "Setting up context directory at $CONTEXT_DIR/.context/..."

mkdir -p "$CONTEXT_DIR/.context"/{docs,agents,plans,skills,metrics}

if [ ! -f "$CONTEXT_DIR/.context/docs/architecture.md" ]; then
    cat > "$CONTEXT_DIR/.context/docs/architecture.md" << 'EOF'
# Architecture
# Add your system architecture and tech stack here.
# This file is read by all squad agents before starting work.
EOF
fi

if [ ! -f "$CONTEXT_DIR/.context/docs/patterns.md" ]; then
    cat > "$CONTEXT_DIR/.context/docs/patterns.md" << 'EOF'
# Patterns
# Add coding patterns, conventions, and style guides here.
EOF
fi

if [ ! -f "$CONTEXT_DIR/.context/docs/decisions.md" ]; then
    cat > "$CONTEXT_DIR/.context/docs/decisions.md" << 'EOF'
# Architecture Decision Record
# Document significant decisions with date and rationale.
EOF
fi

if [ ! -f "$CONTEXT_DIR/.context/agents/squad-memory.md" ]; then
    cat > "$CONTEXT_DIR/.context/agents/squad-memory.md" << 'EOF'
# Squad Memory
# Shared context across sessions. Updated by agents after completing work.
EOF
fi

if [ ! -f "$CONTEXT_DIR/.context/plans/current.md" ]; then
    cat > "$CONTEXT_DIR/.context/plans/current.md" << 'EOF'
# Current Plan
# Active tasks and progress. Updated by the Tech Lead.
EOF
fi

echo "✅ Context directory ready"

# =============================================================================
# MCP CONFIGURATION
# =============================================================================
echo ""
echo "Checking MCP configuration..."

MCP_CONFIG="$HOME/.kimi/mcp.json"
if [ -f "$MCP_CONFIG" ]; then
    if grep -q "brave-search" "$MCP_CONFIG" 2>/dev/null; then
        echo "✅ Brave Search MCP configured"
    else
        echo "⚠️  Brave Search MCP not found in $MCP_CONFIG"
        echo "    Add: npx -y @modelcontextprotocol/server-brave-search"
    fi
    
    if grep -q "dotcontext" "$MCP_CONFIG" 2>/dev/null; then
        echo "✅ dotcontext MCP configured"
    else
        echo "⚠️  dotcontext MCP not found in $MCP_CONFIG"
        echo "    Add: npx -y @modelcontextprotocol/server-dotcontext"
    fi
else
    echo "⚠️  MCP config not found at $MCP_CONFIG"
    echo "    Create it with your MCP server definitions."
fi

if [ -z "${BRAVE_API_KEY:-}" ]; then
    echo ""
    echo "⚠️  BRAVE_API_KEY not set"
    echo "    Set it with: export BRAVE_API_KEY=your_key_here"
    echo "    Get a key at: https://brave.com/search/api/"
fi

# =============================================================================
# SKILLS
# =============================================================================
echo ""
echo "Checking skills..."

REQUIRED_SKILLS=(
    "brainstorming"
    "writing-plans"
    "dispatching-parallel-agents"
    "subagent-driven-development"
    "best-practices"
    "backend-development"
    "nodejs-development"
    "express-rest-api"
    "test-driven-development"
    "find-docs"
)

MISSING_SKILLS=()
for skill in "${REQUIRED_SKILLS[@]}"; do
    FOUND=false
    for dir in "$SKILLS_DIR" "$HOME/.claude/skills"; do
        if [ -d "$dir/$skill" ]; then
            FOUND=true
            break
        fi
    done
    if [ "$FOUND" = false ]; then
        MISSING_SKILLS+=("$skill")
    fi
done

if [ ${#MISSING_SKILLS[@]} -eq 0 ]; then
    echo "✅ All referenced skills available"
else
    echo "⚠️  Missing skills (optional but recommended): ${MISSING_SKILLS[*]}"
    echo "    Install via: ctx7 add <skill-name>  or  clone into $SKILLS_DIR"
fi

# =============================================================================
# VALIDATION
# =============================================================================
echo ""
echo "Running validation..."

cd "$SQUAD_DIR"

if ./test-harness.sh >/dev/null 2>&1; then
    echo "✅ Test harness passed"
else
    echo "❌ Test harness failed — check ./test-harness.sh for details"
    exit 1
fi

if ./integration-test.sh >/dev/null 2>&1; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed — check ./integration-test.sh for details"
    exit 1
fi

if ./regression-suite.sh >/dev/null 2>&1; then
    echo "✅ Regression suite passed"
else
    echo "❌ Regression suite failed — check ./regression-suite.sh for details"
    exit 1
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "========================================"
echo "🎉 Squad Harness Setup Complete!"
echo "========================================"
echo ""
echo "Interactive mode:"
echo "  kimi --agent-file $SQUAD_DIR/squad.yaml --yolo"
echo ""
echo "Non-interactive mode:"
echo "  /tmp/run_squad.sh 'Your task here' $CONTEXT_DIR 300"
echo ""
echo "Run tests:"
echo "  cd $SQUAD_DIR && ./test-harness.sh"
echo ""
