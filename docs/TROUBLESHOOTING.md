# Troubleshooting

## Custom Subagents Not Working

**Symptom:** `Builtin subagent type not found: coder`

**Cause:** When using a custom agent file, built-in subagent types (`coder`, `explore`, `plan`) are replaced by your custom definitions.

**Fix:** Use your custom subagent names (`backend`, `frontend`, `qa`, `reviewer`, `researcher`) instead of `coder`.

## Tasks Timeout Without Output

**Symptom:** Task hangs and exits with code 124

**Cause:** Tool approvals are required by default. In non-interactive mode, approvals hang forever.

**Fix:** Use `--yolo` flag for automated execution:
```bash
kimi-squad --yolo -p "Your task"
```

## MCP Servers Fail to Start

**Symptom:** `BRAVE_API_KEY environment variable is required`

**Cause:** MCP config not copied or API key not set.

**Fix:**
```bash
cp mcp/mcp.json.example ~/.kimi/mcp.json
# Edit and add your real API key
```

## Context Compaction in Ralph Loop

**Symptom:** Agent forgets earlier gate decisions mid-task

**Cause:** Context window exceeded, triggering auto-compaction.

**Fix:**
- Use Fast Path for small tasks (fewer iterations)
- Reduce `--max-ralph-iterations` (default 10)
- The agent uses `SetTodoList` to persist gate status

## Skill Not Found

**Symptom:** `Referenced skill not found: X`

**Cause:** Skill referenced in prompt but not installed.

**Fix:**
```bash
# Install missing skill
npx skills add <owner/repo@skill> -g -y

# Or remove reference from prompt
```

## Test Harness Failures

**Symptom:** `❌ Custom subagent types BROKEN`

**Cause:** Subagent meta.json not found (may be in different session directory).

**Fix:** Run the harness again. If persistent, verify:
```bash
ls ~/.kimi/agents/squad/
# Should show: squad.yaml, *.md, *.yaml, test-harness.sh
```

## Wrong MCP Tool Names

**Symptom:** Agent tries to call non-existent MCP tools

**Fix:** Verify actual tool names:
```bash
kimi-squad --yolo -p "List all available MCP tools"
```

Then update prompts in `squad/tech-lead.md` and `squad/researcher.md`.

## Approval Prompts in Interactive Mode

**Symptom:** Every tool call asks "Approve [Y/n]?"

**Cause:** Normal behavior for security. Each Shell command and file write requires approval.

**Options:**
1. Press `Y` + Enter for each approval
2. Use `--yolo` to auto-approve all (use with caution)
3. Set `default_yolo = true` in `~/.kimi/config.toml` (not recommended for production)
