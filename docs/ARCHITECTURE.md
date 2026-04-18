# Squad Architecture

## Overview

The Kimi Squad is a multi-agent orchestration system built on Kimi Code CLI's custom agent and subagent capabilities. It uses Ralph Loop for iterative refinement and a 5-gate verification process for quality assurance.

## Agent Hierarchy

```
Root Agent (Tech Lead)
├── Subagent: researcher
├── Subagent: backend
├── Subagent: frontend
├── Subagent: qa
└── Subagent: reviewer
```

### Tech Lead (Orchestrator)

**Role:** Architect, planner, delegator, evaluator, synthesizer

**Tools:** All tools including `Agent` (to launch subagents)

**Key Behaviors:**
- Classifies tasks as Trivial/Small/Medium/Large before acting
- Uses Fast Path for Trivial/Small tasks (handles directly)
- Delegates Medium/Large tasks to specialists
- Tracks quality gate status with `SetTodoList`
- Only outputs `<choice>STOP</choice>` when all gates pass

### Subagents

Each subagent extends the built-in `default` agent with a specialized system prompt and tool set. They **cannot** launch nested subagents (enforced by Kimi CLI).

| Subagent | Tools | Focus |
|----------|-------|-------|
| **researcher** | Read, Search, Fetch | Technology research, docs, patterns |
| **backend** | Full coder set | APIs, databases, business logic |
| **frontend** | Full coder set | UI/UX, components, accessibility |
| **qa** | Full coder set | Tests, coverage, validation |
| **reviewer** | Read + StrReplaceFile | Code review, architecture |

## Task Classification (Fast Path)

| Class | Definition | Gates | Execution |
|-------|-----------|-------|-----------|
| **Trivial** | Typo, config tweak | Gate 1 | Tech Lead direct |
| **Small** | Single function/component | Gates 1-2 | One engineer |
| **Medium** | Feature (API + UI) | Gates 1-4 | Backend + Frontend + QA |
| **Large** | System, auth, payment | All 5 | Full squad |

## 5 Quality Gates

```
Gate 1: Self-Check      → Engineer verifies own output
Gate 2: Functional      → Tech Lead checks acceptance criteria
Gate 3: QA Validation   → Tests pass, coverage >= 80%
Gate 4: Reviewer        → Architecture, security, patterns
Gate 5: Integration     → Backend + frontend work together
```

**Iteration Limit:** 3 revisions per gate per task. Escalate to user after.

## Ralph Loop Integration

The Tech Lead runs with `--max-ralph-iterations 10`. After each response:

1. If all gates pass → output `<choice>STOP</choice>`
2. If gates pending → continue to next iteration
3. Context accumulates across iterations (watch for compaction)

**Mitigation:** Fast Path reduces iterations for small tasks.

## Skills Integration

Skills are discovered from `~/.agents/skills/` and injected into the system prompt. The agent decides which to read based on the task.

**Skill reference caps** (to prevent decision paralysis):
- Tech Lead: 8 max
- Backend/Frontend: 6 max
- QA/Reviewer: 4 max
- Researcher: 5 max

## MCP Integration

MCP servers provide real-time tools:

- **brave_web_search** — Web search via Brave API
- **brave_local_search** — Local business search
- **searchGitHub** — Code search across GitHub repos

## Context Flow

```
User Request
    ↓
Tech Lead Classifies Task
    ↓
[Fast Path] → Direct execution (Small tasks)
    ↓
[Delegation] → Agent tool launches subagent
    ↓
Subagent Executes + Self-Check (Gate 1)
    ↓
Tech Lead Evaluates (Gate 2)
    ↓
QA Validates (Gate 3)
    ↓
Reviewer Approves (Gate 4)
    ↓
Integration Check (Gate 5)
    ↓
Synthesize + Deliver
```
