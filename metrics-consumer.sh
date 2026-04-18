#!/bin/bash
# Squad Metrics Consumer v2.0
# Reads .context/metrics/sessions.jsonl and produces actionable analytics
# Usage: ./metrics-consumer.sh [project-dir]

PROJECT_DIR="${1:-.}"
METRICS_FILE="$PROJECT_DIR/.context/metrics/sessions.jsonl"

if [ ! -f "$METRICS_FILE" ]; then
    echo "No metrics found at $METRICS_FILE"
    echo "Run a squad task first to generate metrics."
    exit 1
fi

echo "📊 Squad Metrics Report v2.0"
echo "============================"
echo ""

python3 -c "
import json
import sys
from collections import Counter
from statistics import mean, median, stdev

lines = []
with open('$METRICS_FILE') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            lines.append(obj)
        except json.JSONDecodeError as e:
            pass

if not lines:
    print('No valid metrics entries found.')
    sys.exit(0)

sessions = len(lines)
print(f'Total sessions: {sessions}')
print()

# Task class distribution
classes = Counter(obj.get('task_class', 'unknown') for obj in lines)
print('Task Classes:')
for cls, count in sorted(classes.items(), key=lambda x: -x[1]):
    pct = count / sessions * 100
    print(f'  {cls}: {count} ({pct:.1f}%)')
print()

# Status distribution
statuses = Counter(obj.get('status', 'unknown') for obj in lines)
print('Outcomes:')
for st, count in sorted(statuses.items(), key=lambda x: -x[1]):
    pct = count / sessions * 100
    emoji = {'completed': '✅', 'timeout': '⏱️', 'failed': '❌', 'escalated': '⚠️'}.get(st, '•')
    print(f'  {emoji} {st}: {count} ({pct:.1f}%)')
print()

# Duration analytics by class
print('Duration Analytics (seconds):')
print('  {:<12} {:>6} {:>6} {:>6} {:>6} {:>6}'.format('Class', 'Count', 'Min', 'P50', 'P90', 'Max'))
print('  ' + '-' * 50)
for cls in sorted(set(obj.get('task_class', 'unknown') for obj in lines)):
    durs = [obj['duration_seconds'] for obj in lines if obj.get('task_class') == cls and 'duration_seconds' in obj]
    if not durs:
        continue
    durs_sorted = sorted(durs)
    n = len(durs_sorted)
    p50 = durs_sorted[n // 2] if n % 2 == 1 else (durs_sorted[n // 2 - 1] + durs_sorted[n // 2]) / 2
    p90_idx = int(n * 0.9)
    p90 = durs_sorted[min(p90_idx, n - 1)]
    print('  {:<12} {:>6} {:>6.0f} {:>6.0f} {:>6.0f} {:>6.0f}'.format(
        cls, n, min(durs), p50, p90, max(durs)
    ))
print()

# Context usage
contexts = [obj.get('context_usage_percent', 0) for obj in lines if 'context_usage_percent' in obj]
if contexts:
    print(f'Context Usage: max {max(contexts):.1f}%, median {median(contexts):.1f}%')
    high_context = sum(1 for c in contexts if c > 50)
    if high_context:
        print(f'  ⚠️  {high_context} session(s) exceeded 50% context')
    print()

# Token cost estimation (approximate: ~4 chars per token)
# Log file sizes can proxy token usage for wrapper sessions
print('Token Cost Estimate (approximate):')
print('  Based on log size: ~4 chars/token, \$3/M tokens (Claude-3.5-Sonnet class)')
print('  Use with caution — actual token counts come from kimi CLI internals.')
print()

# Bugs and revisions
bugs = sum(obj.get('bugs_found', 0) for obj in lines)
revisions = sum(obj.get('revisions_required', 0) for obj in lines)
print(f'Quality: {bugs} bugs found, {revisions} revisions required')
print()

# Trend (last 5 vs first 5)
if sessions >= 10:
    early = lines[:5]
    late = lines[-5:]
    early_dur = mean(o.get('duration_seconds', 0) for o in early)
    late_dur = mean(o.get('duration_seconds', 0) for o in late)
    trend = '↓ improving' if late_dur < early_dur * 0.8 else '↑ slowing' if late_dur > early_dur * 1.2 else '→ stable'
    print(f'Trend (first 5 vs last 5 avg duration): {trend}')
    print(f'  Early avg: {early_dur:.0f}s  Late avg: {late_dur:.0f}s')
    print()

print('Recent sessions:')
for obj in lines[-5:]:
    ts = obj.get('timestamp', 'unknown')
    cls = obj.get('task_class', '?')
    dur = obj.get('duration_seconds', 0)
    status = obj.get('status', '?')
    ctx = obj.get('context_usage_percent', 0)
    print(f'  [{ts}] {cls:<8} {dur:>4}s {status:<12} ctx={ctx:.1f}%')

print()
print(f'Full log: $METRICS_FILE')
" 2>/dev/null || echo "  (python3 with json support required for detailed stats)"
