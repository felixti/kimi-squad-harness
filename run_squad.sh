#!/bin/bash
# Squad Non-Interactive Task Runner — Hardened Wrapper for Kimi CLI
# Version: 2.0
# Usage: run_squad.sh "TASK DESCRIPTION" [project-dir] [timeout-seconds]
#
# This script wraps the kimi TUI in tmux for automated/batch execution.
# It captures structured metrics, handles signals gracefully, and produces
# CI-friendly output with exit codes.
#
# EXIT CODES:
#   0 — STOP detected, task completed successfully
#   1 — Invalid arguments or missing prerequisites
#   2 — Timeout (task did not complete within max_wait)
#   3 — Session crashed or ended unexpectedly
#   4 — STOP not found (completed but convergence not signaled)

set -uo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
TASK="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"
MAX_WAIT="${3:-600}"      # Default 10 min (was 300s). Medium tasks need ~5min.
POLL_INTERVAL="${POLL_INTERVAL:-5}"
STOP_PATTERN="${STOP_PATTERN:-<choice>STOP</choice>}"
CONTEXT_PATTERN="${CONTEXT_PATTERN:-context: }"

SCRIPT_NAME="$(basename "$0")"
SESSION="squad-$(date +%s)-$$"
LOG_DIR="${SQUAD_LOG_DIR:-/tmp/squad-logs}"
LOG="$LOG_DIR/${SESSION}.log"
METRICS_FILE="$PROJECT_DIR/.context/metrics/sessions.jsonl"

# =============================================================================
# VALIDATION
# =============================================================================
if [ -z "$TASK" ]; then
    echo "Usage: $SCRIPT_NAME 'TASK DESCRIPTION' [project-dir] [timeout-seconds]" >&2
    echo "Example: $SCRIPT_NAME 'Add DELETE /users/:id endpoint' ./my-api 300" >&2
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "ERROR: tmux is required but not installed" >&2
    exit 1
fi

if ! command -v kimi >/dev/null 2>&1; then
    echo "ERROR: kimi CLI is required but not installed" >&2
    exit 1
fi

AGENT_FILE="${SQUAD_AGENT_FILE:-$HOME/.kimi/agents/squad/squad.yaml}"
if [ ! -f "$AGENT_FILE" ]; then
    echo "ERROR: Agent file not found: $AGENT_FILE" >&2
    echo "Set SQUAD_AGENT_FILE or run setup.sh" >&2
    exit 1
fi

# =============================================================================
# SETUP
# =============================================================================
mkdir -p "$LOG_DIR"
mkdir -p "$PROJECT_DIR/.context/metrics"

# =============================================================================
# CLEANUP HANDLER
# =============================================================================
cleanup() {
    local rc=$?
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux capture-pane -t "$SESSION" -p > "$LOG" 2>/dev/null || true
        tmux kill-session -t "$SESSION" 2>/dev/null || true
    fi
    # Append final metrics if not already done
    if [ -n "${METRICS_WRITTEN:-}" ]; then
        :
    fi
    exit $rc
}
trap cleanup EXIT INT TERM HUP

# =============================================================================
# METRICS HELPER (defined early for use in loop)
# =============================================================================
write_metrics() {
    local status="${1:-unknown}"
    local notes="${2:-}"
    local ts
    local dur
    ts=$(date -Iseconds)
    dur=$(( $(date +%s) - START_TIME ))

    cat >> "$METRICS_FILE" << EOF
{"timestamp":"$ts","task_class":"${TASK_CLASS:-unknown}","duration_seconds":$dur,"iterations":${ITERATIONS:-0},"gates_passed":${GATE_PASSES:-0},"subagents_called":${SUBAGENTS:-0},"context_usage_percent":${FINAL_CONTEXT:-0},"bugs_found":0,"revisions_required":0,"status":"$status","notes":"$notes"}
EOF
    METRICS_WRITTEN=1
}

# =============================================================================
# SESSION START
# =============================================================================
echo "🚀 Squad Task Runner v2.0"
echo "========================="
echo "Task:     $TASK"
echo "Project:  $PROJECT_DIR"
echo "Session:  $SESSION"
echo "Timeout:  ${MAX_WAIT}s"
echo "Agent:    $AGENT_FILE"
echo ""

START_TIME=$(date +%s)
STOP_FOUND=false
ITERATION=0
MAX_CONTEXT=0

# Create tmux session
tmux new-session -d -s "$SESSION" \
  "cd '$PROJECT_DIR' && export BRAVE_API_KEY=\${BRAVE_API_KEY:-dummy} && \
   kimi --agent-file '$AGENT_FILE' --max-ralph-iterations 10 --yolo"

sleep 3

# Send the task prompt
tmux send-keys -t "$SESSION" "$TASK" C-m

# =============================================================================
# WAIT LOOP
# =============================================================================
echo -n "Waiting"
while true; do
    sleep "$POLL_INTERVAL"
    ITERATION=$((ITERATION + 1))
    echo -n "."

    # Check session health
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        echo ""
        echo "⚠️  Session ended unexpectedly"
        tmux capture-pane -t "$SESSION" -p > "$LOG" 2>/dev/null || true
        write_metrics "failed" "session_crashed"
        exit 3
    fi

    # Capture current pane
    tmux capture-pane -t "$SESSION" -p > "$LOG" 2>/dev/null || true

    # Check for STOP
    if grep -q "$STOP_PATTERN" "$LOG" 2>/dev/null; then
        echo ""
        echo "✅ STOP detected"
        STOP_FOUND=true
        sleep 3
        break
    fi

    # Extract max context usage seen so far
    CURRENT_CONTEXT=$(grep -oE "context: [0-9]+\.[0-9]+" "$LOG" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ -n "$CURRENT_CONTEXT" ]; then
        # Bash float comparison via awk
        MAX_CONTEXT=$(awk "BEGIN {print ($CURRENT_CONTEXT > $MAX_CONTEXT) ? $CURRENT_CONTEXT : $MAX_CONTEXT}")
    fi

    # Check timeout
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        echo ""
        echo "⏱️  Timeout after ${MAX_WAIT}s"
        break
    fi
done

# Final capture
tmux capture-pane -t "$SESSION" -p > "$LOG" 2>/dev/null || true

# =============================================================================
# METRICS & CONTEXT EXTRACTION
# =============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Extract final context usage
FINAL_CONTEXT=$(grep -oE "context: [0-9]+\.[0-9]+" "$LOG" 2>/dev/null | tail -1 | awk '{print $2}')
FINAL_CONTEXT="${FINAL_CONTEXT:-$MAX_CONTEXT}"

# Count checkpoints, gate passes, subagent launches
CHECKPOINTS=$(grep -c '\[CHECKPOINT\]' "$LOG" 2>/dev/null || echo 0)
GATE_PASSES=$(grep -cE 'PASS|APPROVE' "$LOG" 2>/dev/null || echo 0)
# Subagent launches: look for "subagent" lines in tmux output
SUBAGENTS=$(grep -oE 'subagent (backend|frontend|qa|reviewer|researcher)' "$LOG" 2>/dev/null | sort -u | wc -l || echo 0)
# Iterations: look for Ralph Loop or todo list updates
ITERATIONS=$(grep -cE 'Ralph Loop|SetTodoList' "$LOG" 2>/dev/null || echo 0)

# Extract task class from log (if Tech Lead classified it)
TASK_CLASS=$(grep -oE 'Class: (Trivial|Small|Medium|Large)' "$LOG" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
TASK_CLASS="${TASK_CLASS:-unknown}"

# =============================================================================
# WRITE FINAL METRICS
# =============================================================================
if [ "$STOP_FOUND" = true ]; then
    write_metrics "completed" "STOP emitted, duration ${DURATION}s"
else
    if [ "$DURATION" -ge "$MAX_WAIT" ]; then
        write_metrics "timeout" "Exceeded ${MAX_WAIT}s timeout"
    else
        write_metrics "incomplete" "Session ended without STOP"
    fi
fi

# =============================================================================
# STRUCTURED OUTPUT
# =============================================================================
echo ""
echo "📊 SQUAD RESULTS"
echo "================"
echo "{"
echo "  \"session\": \"$SESSION\","
echo "  \"task\": \"$TASK\","
echo "  \"task_class\": \"$TASK_CLASS\","
echo "  \"status\": $([ "$STOP_FOUND" = true ] && echo '"completed"' || echo '"timeout_or_incomplete"'),"
echo "  \"duration_seconds\": $DURATION,"
echo "  \"timeout_seconds\": $MAX_WAIT,"
echo "  \"iterations\": $ITERATIONS,"
echo "  \"checkpoints\": $CHECKPOINTS,"
echo "  \"gate_passes\": $GATE_PASSES,"
echo "  \"subagents_launched\": $SUBAGENTS,"
echo "  \"context_usage_percent\": $FINAL_CONTEXT,"
echo "  \"log_file\": \"$LOG\","
echo "  \"metrics_file\": \"$METRICS_FILE\""
echo "}"

echo ""
echo "📄 Log: $LOG ($(wc -c < "$LOG" | tr -d ' ') bytes)"
echo "📈 Metrics: $METRICS_FILE"
echo ""

# =============================================================================
# EXIT CODE
# =============================================================================
if [ "$STOP_FOUND" = true ]; then
    echo "✅ Task completed successfully"
    exit 0
elif [ "$DURATION" -ge "$MAX_WAIT" ]; then
    echo "⏱️  Task timed out (code 2)"
    exit 2
else
    echo "⚠️  Task incomplete (code 4)"
    exit 4
fi
