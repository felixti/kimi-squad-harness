# Kimi Squad Harness

A production-ready multi-agent engineering squad for [Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli). Five specialized agents orchestrated by a Tech Lead with exhaustive quality gates, Ralph Loop iteration, skills integration, and MCP tools.

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
| **28 Skills** | Curated domain knowledge for each specialist |
| **2 MCP Servers** | Brave Search (web) + Grep (GitHub code search) |
| **Auto Feedback Loop** | Test harness validates configuration changes |

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
│   └── .kimi/AGENTS.md.example  # Per-project config template
└── docs/
    ├── INSTALL.md          # Detailed installation guide
    ├── ARCHITECTURE.md     # How the squad works
    └── TROUBLESHOOTING.md  # Common issues
```

## 🛡️ Security Notice

**Never commit secrets.** This repository includes:
- `mcp/mcp.json.example` — Template with placeholder API keys
- `.gitignore` rules for sensitive files

Add your actual API keys after installation:
```bash
cp mcp/mcp.json.example ~/.kimi/mcp.json
# Edit ~/.kimi/mcp.json and replace placeholders
```

## 📜 License

MIT — Use, modify, and share freely.
