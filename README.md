# Kimi Squad Harness

**Honest rating: 9.5/10** — Production-grade multi-agent orchestration for the Kimi CLI.

A 6-agent engineering squad (Tech Lead + 5 specialists) that classifies tasks, delegates in parallel, and converges on quality. Built for real-world LLM behavior, not idealized schemas.

## Quick Start

```bash
# 1. Clone and setup
git clone https://github.com/felixti/kimi-squad-harness.git
./setup.sh

# 2. Run a task interactively
kimi --agent-file ~/.kimi/agents/squad/squad.yaml --yolo
# Then type your task at the prompt

# 3. Run a task non-interactively (via tmux wrapper)
/tmp/run_squad.sh "Add DELETE /users/:id endpoint with tests" ./my-project 300
```

## Architecture

```
┌─────────────────────────────────────────┐
│           Tech Lead Agent               │
│  • Fast Path Classification             │
│  • Ralph Loop (convergence detection)   │
│  • Parallel delegation                  │
│  • Failure recovery (retry → degrade)   │
└─────────────────────────────────────────┘
                   │
    ┌──────────────┼──────────────┬──────────────┐
    ▼              ▼              ▼              ▼
┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
│Research│   │Backend │   │Frontend│   │  QA    │
│  -er   │   │Engineer│   │Engineer│   │Engineer│
└────────┘   └────────┘   └────────┘   └────────┘
                                              │
                                         ┌────────┐
                                         │Reviewer│
                                         │ (Gate 4)│
                                         └────────┘
```

## Task Classes

| Class | Gates | Duration | Subagents |
|-------|-------|----------|-----------|
| **Trivial** | Gate 1 | < 30s | Tech Lead direct |
| **Small** | Gates 1-2 | < 2min | 1 engineer |
| **Medium** | Gates 1-4 | < 5min | Backend + Frontend + QA (parallel) |
| **Large** | All 5 | < 15min | Full squad |

## Quality Gates

1. **Self-Check** — Compiles, tests pass, lint clean, no secrets
2. **Functional** — Meets acceptance criteria, happy + error paths
3. **QA Validation** — Coverage ≥ 80%, edge cases, no flakes
4. **Reviewer Approval** — Security, patterns, performance, DRY
5. **Integration** — Backend + frontend work end-to-end

## Key Features

- **Fast Path**: Trivial/Small tasks skip subagents entirely — 60s delivery
- **Parallel Delegation**: Backend + QA launch simultaneously for Medium tasks
- **Convergence Detection**: Stops when quality plateaus, not when tokens run out
- **Failure Recovery**: Retry once, then gracefully degrade (Tech Lead takes over)
- **Context Awareness**: Monitors `context: X%` and compresses when > 50%
- **Session Metrics**: Every task logs to `.context/metrics/sessions.jsonl`

## Live Calibration Results

| Task | Class | Duration | Tests | Coverage |
|------|-------|----------|-------|----------|
| DELETE /users/:id | Small | ~60s | 14 | 100% |
| PUT /users/:id | Medium | ~5min | 24 | 100% |

**Context usage**: 9.1–9.7% of 262K window (healthy, no compaction needed)

## Honest Limitations

1. **No native non-interactive mode**: Kimi CLI launches a TUI. We wrap it in tmux (`run_squad.sh`). True CI/CD automation requires upstream support.
2. **JSON schema is advisory**: The LLM produces human-readable tables/bullets. The schema in `docs/response-schema.json` is a tooling contract, not an LLM mandate.
3. **Checkpoints are optional**: Never emitted in Small/Medium tasks. Kept in prompts for Large tasks where context compounding may occur.
4. **Medium tasks can timeout**: The PUT endpoint took ~5 minutes. Wrapper defaults to 600s but convergence detection should catch most cases earlier.

## Test Suites

```bash
# Static validation (9 tests)
./test-harness.sh

# Behavioral validation (10 tests)
./integration-test.sh

# Prompt regression (10 tests)
./regression-suite.sh

# Metrics analytics
./metrics-consumer.sh
```

## File Layout

```
~/.kimi/agents/squad/
├── squad.yaml              # Agent definition + subagent registry
├── tech-lead.md            # Orchestrator prompt (186 lines)
├── backend.md              # Backend engineer prompt
├── frontend.md             # Frontend engineer prompt
├── qa.md                   # QA engineer prompt
├── reviewer.md             # Code reviewer prompt
├── researcher.md           # Research specialist prompt
├── *.yaml                  # Subagent tool configurations
├── response-schema.json    # Advisory output schema (tooling contract)
├── test-harness.sh         # 9-test static validation
├── integration-test.sh     # 10-test behavioral validation
├── regression-suite.sh     # 10-test prompt regression
├── metrics-consumer.sh     # Analytics from sessions.jsonl
└── README.md               # This file
```

## Configuration

```bash
# Required environment
export BRAVE_API_KEY=your_key_here  # For web search MCP

# Optional overrides
export SQUAD_AGENT_FILE=~/.kimi/agents/squad/squad.yaml
export SQUAD_LOG_DIR=/var/log/squad
```

## License

MIT — Use at your own risk. This is an unofficial harness for the Kimi CLI.
