# Kimi Squad Harness

A **10/10 production-ready** multi-agent engineering squad for [Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli). Five specialized agents orchestrated by a Tech Lead with exhaustive quality gates, Ralph Loop iteration, skills integration, MCP tools, and live-calibrated behavioral features.

## 🎯 What This Is

This harness turns Kimi Code CLI into an **elite engineering team**:

- **Tech Lead** — Architect, decompose, delegate, evaluate
- **Backend Engineer** — APIs, databases, business logic
- **Frontend Engineer** — UI/UX, components, accessibility
- **QA Engineer** — Tests, coverage, shift-left quality
- **Code Reviewer** — Final gate before production

## 🚀 Quick Start

```bash
# 1. Clone this harness
git clone https://github.com/YOUR_USER/kimi-squad-harness.git

# 2. Run the installer
./install.sh

# 3. Launch your squad
kimi-squad
```

## 📋 Requirements

- [Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli) installed
- Node.js + npm (for MCP servers and skills)
- `gh` CLI (optional, for GitHub skill)

## 🏗️ Architecture

```
┌─────────────────┐
│   Tech Lead     │  ← Orchestrator, Ralph Loop, 5 Quality Gates
│  (Ralph Loop)   │
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┐
    ▼         ▼        ▼        ▼
Researcher  Backend  Frontend   QA
    │         │        │        │
    └─────────┴────────┴────────┘
              │
              ▼
         Reviewer (Final Gate)
              │
              ▼
         Delivery
```

## 🔧 Features

| Feature | Description |
|---------|-------------|
| **5 Quality Gates** | Self-Check → Functional → QA → Review → Integration |
| **Fast Path** | Trivial/Small tasks skip subagents for speed |
| **Ralph Loop** | Iterates until all gates pass (max 10 iterations) |
| **20 Curated Skills** | Domain knowledge for each specialist (dead skills purged) |
| **3 MCP Servers** | Brave Search + Grep + DotContext (memory) |
| **Persistent Memory** | `.context/` directory with atomic writes for cross-session knowledge |
| **3 Test Suites** | test-harness + integration-test + regression-suite (28 checks) |
| **Convergence Detection** | Smart stopping when quality plateaus (not token-limited) |
| **JSON Response Schema** | Standardized inter-agent communication format |
| **Session Metrics** | Automatic cost/quality telemetry logging |
| **Failure Recovery** | Retry + graceful degradation for subagent failures |

## 📁 Repository Structure

```
.
├── squad/                  # Agent definitions
│   ├── squad.yaml          # Tech Lead orchestrator
│   ├── tech-lead.md        # Tech Lead system prompt
│   ├── backend.{yaml,md}   # Backend engineer
│   ├── frontend.{yaml,md}  # Frontend engineer
│   ├── qa.{yaml,md}        # QA engineer
│   ├── reviewer.{yaml,md}  # Code reviewer
│   ├── researcher.{yaml,md}# Researcher
│   └── test-harness.sh     # Auto validation script
├── skills/                 # Skill management
│   └── install-skills.sh   # Install all curated skills
├── mcp/
│   └── mcp.json.example    # MCP config template (add your API keys)
├── dotfiles/
│   ├── .zshrc.example      # Shell aliases
│   ├── .kimi/AGENTS.md.example  # Per-project config template
│   └── .context/           # Memory system templates
│       ├── docs/           # Architecture, patterns, decisions
│       ├── agents/         # Squad memory
│       ├── plans/          # Current/completed work
│       └── skills/         # Project-specific skills
└── docs/
    ├── INSTALL.md          # Detailed installation guide
    ├── ARCHITECTURE.md     # How the squad works
    └── TROUBLESHOOTING.md  # Common issues
```

## 🛡️ Security Notice

**Never commit secrets.** This repository includes:
- `mcp/mcp.json.example` — Template (no hardcoded keys, uses env inheritance)
- `.gitignore` rules for sensitive files

Add your actual API keys after installation:
```bash
cp mcp/mcp.json.example ~/.kimi/mcp.json
export BRAVE_API_KEY=your_key_here
# Get a key at https://brave.com/search/api/
```

## 📜 License

MIT — Use, modify, and share freely.
