#!/bin/bash
# Squad Metrics Consumer
# Reads .context/metrics/sessions.jsonl and produces human-readable summaries
# Usage: ./metrics-consumer.sh [project-dir]

PROJECT_DIR="${1:-.}"
METRICS_FILE="$PROJECT_DIR/.context/metrics/sessions.jsonl"

if [ ! -f "$METRICS_FILE" ]; then
    echo "No metrics found at $METRICS_FILE"
    echo "Run a squad task first to generate metrics."
    exit 1
fi

echo "📊 Squad Metrics Report"
echo "======================="
echo ""

# Count sessions
SESSIONS=$(wc -l < "$METRICS_FILE" | tr -d ' ')
echo "Total sessions: $SESSIONS"
echo ""

# Task class distribution
echo "Task Classes:"
python3 -c "
import json, sys
from collections import Counter
classes = Counter()
bugs = 0
revisions = 0
completed = 0
escalated = 0
failed = 0

with open('$METRICS_FILE') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            obj = json.loads(line)
            classes[obj.get('task_class', 'unknown')] += 1
            bugs += obj.get('bugs_found', 0)
            revisions += obj.get('revisions_required', 0)
            status = obj.get('status', '')
            if status == 'completed': completed += 1
            elif status == 'escalated': escalated += 1
            elif status == 'failed': failed += 1
        except json.JSONDecodeError:
            pass

for cls, count in sorted(classes.items()):
    print(f'  {cls}: {count}')
print()
print(f'Bugs found: {bugs}')
print(f'Revisions required: {revisions}')
print(f'Sessions completed: {completed}')
print(f'Sessions escalated: {escalated}')
print(f'Sessions failed: {failed}')
" 2>/dev/null || echo "  (python3 with json support required for detailed stats)"

echo ""
echo "Recent sessions:"
tail -5 "$METRICS_FILE" | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo "Full log: $METRICS_FILE"
