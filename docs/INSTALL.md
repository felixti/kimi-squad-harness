# Installation Guide

## Step 1: Install Kimi Code CLI

If you haven't already:
```bash
# Via pip
pip install kimi-cli

# Or follow official docs:
# https://github.com/MoonshotAI/kimi-cli
```

## Step 2: Clone This Harness

```bash
git clone https://github.com/YOUR_USER/kimi-squad-harness.git
cd kimi-squad-harness
```

## Step 3: Install Squad Agents

```bash
# Create agent directory
mkdir -p ~/.kimi/agents/squad

# Copy agent files
cp squad/*.yaml ~/.kimi/agents/squad/
cp squad/*.md ~/.kimi/agents/squad/
cp squad/test-harness.sh ~/.kimi/agents/squad/

# Make harness executable
chmod +x ~/.kimi/agents/squad/test-harness.sh
```

## Step 4: Install Skills

```bash
# Install all curated skills
./skills/install-skills.sh

# Or install individually:
npx skills add addyosmani/web-quality-skills@best-practices -g -y
npx skills add skillcreatorai/ai-agent-skills@backend-development -g -y
npx skills add manutej/luxor-claude-marketplace@nodejs-development -g -y
npx skills add pluginagentmarketplace/custom-plugin-nodejs@express-rest-api -g -y
npx skills add b-open-io/prompts@frontend-performance -g -y
npx skills add daffy0208/ai-dev-standards@accessibility-engineer -g -y
npx skills add vercel-labs/json-render@react -g -y
npx skills add cowork-os/cowork-os@code-review -g -y
npx skills add openhands/skills@security -g -y
npx skills add travisjneuman/.claude@database-expert -g -y
npx skills add 1mangesh1/dev-skills-collection@docker-helper -g -y
npx skills add thebushidocollective/han@playwright-page-object-model -g -y
npx skills add softaworks/agent-toolkit@openapi-to-typescript -g -y
```

## Step 5: Configure MCP Servers

```bash
# Copy template
cp mcp/mcp.json.example ~/.kimi/mcp.json

# Edit and add your API keys
vim ~/.kimi/mcp.json
```

**Get your Brave Search API key:**
1. Go to https://api.search.brave.com/app/keys
2. Create a free API key
3. Replace `YOUR_BRAVE_API_KEY_HERE` in `~/.kimi/mcp.json`

**DotContext (Memory):**
No API key needed! DotContext is automatically configured.

## Step 6: Add Shell Alias

Add to your `~/.zshrc` or `~/.bashrc`:
```bash
# Kimi Squad
alias kimi-squad='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 10'
alias kimi-squad-quick='kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 1 --yolo'
alias squad-test='~/.kimi/agents/squad/test-harness.sh'
```

Reload:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Step 7: Verify Installation

```bash
# Run the auto feedback loop
squad-test

# Expected output: ALL TESTS PASS ✅
```

## Step 8: Test With Real Task

```bash
# Launch squad
kimi-squad

# Try: "Create a Python function that reverses a string. Include a test."
```

## Optional: Per-Project Configuration

For project-specific conventions, create `.kimi/AGENTS.md` in your project root:

```bash
cp dotfiles/.kimi/AGENTS.md.example ./.kimi/AGENTS.md
# Edit with your project's tech stack and conventions
```

This auto-injects into the squad's system prompt when running in that directory.

## Memory System Setup

The squad uses `.context/` for persistent memory across sessions:

```bash
# Create memory structure in your project
cp -r dotfiles/.context ./.context

# The squad will automatically:
# - READ memory before starting work
# - WRITE updates after completing tasks
```

**Memory structure:**
- `.context/docs/architecture.md` — System architecture
- `.context/docs/patterns.md` — Coding patterns
- `.context/docs/decisions.md` — Architecture decisions
- `.context/agents/squad-memory.md` — Shared squad context
- `.context/plans/current.md` — Active plans and progress
