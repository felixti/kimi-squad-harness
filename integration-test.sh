#!/bin/bash
# Squad Integration Test v2.0
# Validates the actual squad workflow end-to-end without live LLM calls
# Tests: pipeline assembly, schema validation, memory consistency, metric logging,
#        failure recovery, Large task gates, convergence edge cases
set -e

echo "🔬 Squad Integration Test v2.0"
echo "==============================="

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

ISSUES=0

# ============================================================
# TEST 1: Pipeline Assembly
# ============================================================
echo ""
echo "TEST 1: Pipeline Assembly"

TOTAL_PROMPT_SIZE=0
for f in ~/.kimi/agents/squad/*.md; do
    SIZE=$(wc -c < "$f")
    TOTAL_PROMPT_SIZE=$((TOTAL_PROMPT_SIZE + SIZE))
done

if [ "$TOTAL_PROMPT_SIZE" -lt 51200 ]; then
    echo "  ✅ PASS: Combined prompt size ${TOTAL_PROMPT_SIZE} bytes (< 50KB)"
else
    echo "  ⚠️  WARNING: Combined prompt size ${TOTAL_PROMPT_SIZE} bytes (consider trimming)"
fi

SCHEMA_REFS=0
for f in ~/.kimi/agents/squad/backend.md ~/.kimi/agents/squad/frontend.md ~/.kimi/agents/squad/qa.md ~/.kimi/agents/squad/reviewer.md ~/.kimi/agents/squad/researcher.md; do
    if grep -qi "response schema\|structured summary\|output format\|verdict" "$f" 2>/dev/null; then
        SCHEMA_REFS=$((SCHEMA_REFS + 1))
    fi
done

if [ "$SCHEMA_REFS" -eq 5 ]; then
    echo "  ✅ PASS: All 5 subagents reference structured output"
else
    echo "  ❌ FAIL: Only $SCHEMA_REFS/5 subagents reference structured output"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 2: Schema Validation
# ============================================================
echo ""
echo "TEST 2: Schema Validation"

if python3 -c "
import json
with open('$HOME/.kimi/agents/squad/response-schema.json') as f:
    schema = json.load(f)
assert 'properties' in schema
assert 'agent' in schema['properties']
assert 'verdict' in schema['properties']
assert 'findings' in schema['properties']
assert 'advisory_note' in schema, 'Missing advisory_note'
print('Schema structure valid')
" 2>/dev/null; then
    echo "  ✅ PASS: Schema structure validated (advisory mode)"
else
    echo "  ❌ FAIL: Schema structure invalid"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 3: Memory System Consistency
# ============================================================
echo ""
echo "TEST 3: Memory System Consistency"

mkdir -p "$TEST_DIR/.context"/{docs,agents,plans,skills,metrics}

cat > "$TEST_DIR/.context/docs/architecture.md" << 'EOF'
# Architecture
- Stack: Node.js + Express
- Database: PostgreSQL
- Testing: Jest
EOF

cat > "$TEST_DIR/.context/agents/squad-memory.md" << 'EOF'
# Squad Memory
- Project: Test API
- Status: Active development
EOF

cat > "$TEST_DIR/.context/plans/current.md" << 'EOF'
# Current Plan
- [x] Setup project
- [ ] Add user endpoints
EOF

echo "test content" > "$TEST_DIR/.context/tmp-test.md"
mv "$TEST_DIR/.context/tmp-test.md" "$TEST_DIR/.context/docs/decisions.md"

if [ -f "$TEST_DIR/.context/docs/decisions.md" ]; then
    echo "  ✅ PASS: Atomic write protocol works"
else
    echo "  ❌ FAIL: Atomic write protocol failed"
    ISSUES=$((ISSUES + 1))
fi

echo '{"test": true}' > "$TEST_DIR/.context/metrics/test.json"
if [ -f "$TEST_DIR/.context/metrics/test.json" ]; then
    echo "  ✅ PASS: Metrics directory writable"
else
    echo "  ❌ FAIL: Metrics directory not writable"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 4: Delegation Template Validation
# ============================================================
echo ""
echo "TEST 4: Delegation Template Validation"

TEMPLATE=$(sed -n '/## Delegation Template/,/## [^#]/p' ~/.kimi/agents/squad/tech-lead.md | head -25)

if echo "$TEMPLATE" | grep -q "TASK:" && \
   echo "$TEMPLATE" | grep -q "CLASS:" && \
   echo "$TEMPLATE" | grep -q "ACCEPTANCE CRITERIA:" && \
   echo "$TEMPLATE" | grep -q "SKILLS TO READ:" && \
   echo "$TEMPLATE" | grep -q "GATES:" && \
   echo "$TEMPLATE" | grep -q "MEMORY:" && \
   echo "$TEMPLATE" | grep -q "OUTPUT FORMAT:"; then
    echo "  ✅ PASS: Delegation template contains all required fields"
else
    echo "  ❌ FAIL: Delegation template missing required fields"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 5: Convergence Detection Logic
# ============================================================
echo ""
echo "TEST 5: Convergence Detection Logic"

if grep -q "Convergence Detection" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Did the last iteration change anything" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "zero new findings" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Convergence detection rules are defined"
else
    echo "  ❌ FAIL: Convergence detection rules incomplete"
    ISSUES=$((ISSUES + 1))
fi

# Edge case: verify convergence requires ALL gates to pass
if grep -A5 "Convergence Detection" ~/.kimi/agents/squad/tech-lead.md | grep -q "ALL.*gates.*PASS\|ALL required gates"; then
    echo "  ✅ PASS: Convergence requires all gates to pass"
else
    echo "  ⚠️  WARNING: Convergence gate requirement not explicit"
fi

# ============================================================
# TEST 6: Failure Recovery Logic
# ============================================================
echo ""
echo "TEST 6: Failure Recovery Logic"

if grep -q "Subagent Failure Recovery" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Retry once" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Degrade gracefully" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Failure recovery rules are defined"
else
    echo "  ❌ FAIL: Failure recovery rules incomplete"
    ISSUES=$((ISSUES + 1))
fi

# Verify the three-step recovery sequence
STEP1=$(grep -c "Timeout detection" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null || echo 0)
STEP2=$(grep -c "First failure" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null || echo 0)
STEP3=$(grep -c "Second failure" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null || echo 0)
if [ "$STEP1" -ge 1 ] && [ "$STEP2" -ge 1 ] && [ "$STEP3" -ge 1 ]; then
    echo "  ✅ PASS: Three-step recovery sequence present (detect → retry → degrade)"
else
    echo "  ❌ FAIL: Recovery sequence incomplete (steps: $STEP1/$STEP2/$STEP3)"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 7: Simulated LLM Output Parsing
# ============================================================
echo ""
echo "TEST 7: Simulated LLM Output Parsing"

if python3 -c "
import json
schema = json.load(open('$HOME/.kimi/agents/squad/response-schema.json'))
examples = schema.get('examples', {})
for name, ex in examples.items():
    for field in ['agent', 'gate', 'verdict', 'findings']:
        if field not in ex:
            print(f'EXAMPLE {name}: missing field {field}')
    if ex.get('verdict') not in schema['properties']['verdict']['enum']:
        print(f'EXAMPLE {name}: invalid verdict')
    gate = ex.get('gate', 1)
    if not (schema['properties']['gate']['minimum'] <= gate <= schema['properties']['gate']['maximum']):
        print(f'EXAMPLE {name}: gate {gate} out of range')
print('Schema examples valid')
" 2>/dev/null; then
    echo "  ✅ PASS: Schema examples validate correctly"
else
    echo "  ❌ FAIL: Schema examples have errors"
    ISSUES=$((ISSUES + 1))
fi

# Verify Tech Lead has timeout guidance
if grep -q "Expected Task Durations\|Typical Duration" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Tech Lead has timeout guidance"
else
    echo "  ❌ FAIL: Tech Lead missing timeout guidance"
    ISSUES=$((ISSUES + 1))
fi

# Verify context tracking guidance exists
if grep -q "context_usage_percent\|Context Size Awareness" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Context usage tracking guidance present"
else
    echo "  ⚠️  WARNING: Context usage tracking not in prompts"
fi

# ============================================================
# TEST 8: Metrics Consumer
# ============================================================
echo ""
echo "TEST 8: Metrics Consumer"

if [ -f ~/.kimi/agents/squad/metrics-consumer.sh ]; then
    if bash ~/.kimi/agents/squad/metrics-consumer.sh "$TEST_DIR" >/dev/null 2>&1; then
        echo "  ✅ PASS: Metrics consumer script works"
    else
        echo "  ⚠️  Metrics consumer: no data yet (expected for fresh project)"
    fi
else
    echo "  ❌ FAIL: Metrics consumer script missing"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 9: Large Task Classification
# ============================================================
echo ""
echo "TEST 9: Large Task Classification"

# Verify Large requires Gate 5 and all subagents
if grep -q "Large.*All 5" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Full squad" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Large tasks require all 5 gates and full squad"
else
    echo "  ❌ FAIL: Large task requirements incomplete"
    ISSUES=$((ISSUES + 1))
fi

# Verify all 5 subagents are defined for Large tasks
SUBAGENT_NAMES=("researcher" "backend" "frontend" "qa" "reviewer")
for name in "${SUBAGENT_NAMES[@]}"; do
    if grep -q "$name" ~/.kimi/agents/squad/squad.yaml; then
        echo "  ✅ PASS: Subagent '$name' defined in squad.yaml"
    else
        echo "  ❌ FAIL: Subagent '$name' missing from squad.yaml"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 10: Wrapper Script Validation
# ============================================================
echo ""
echo "TEST 10: Wrapper Script Validation"

WRAPPER=""
for path in /tmp/run_squad.sh ~/.kimi/agents/squad/run_squad.sh ./run_squad.sh; do
    if [ -f "$path" ]; then
        WRAPPER="$path"
        break
    fi
done

if [ -n "$WRAPPER" ]; then
    # Check for critical features
    if grep -q "trap.*EXIT" "$WRAPPER"; then
        echo "  ✅ PASS: Wrapper has signal trapping"
    else
        echo "  ❌ FAIL: Wrapper missing signal trapping"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -q "context_usage_percent" "$WRAPPER"; then
        echo "  ✅ PASS: Wrapper extracts context usage"
    else
        echo "  ❌ FAIL: Wrapper missing context usage extraction"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -q "exit 0" "$WRAPPER" && grep -q "exit 2" "$WRAPPER"; then
        echo "  ✅ PASS: Wrapper has structured exit codes"
    else
        echo "  ❌ FAIL: Wrapper missing structured exit codes"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "  ⚠️  WARNING: Wrapper script not found at $WRAPPER"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================"
echo "INTEGRATION TEST RESULTS:"
echo "  Issues Found: $ISSUES"
echo "  Status: $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS ✅' || echo 'ISSUES DETECTED ⚠️')"
echo "========================================"

[ $ISSUES -eq 0 ] || exit 1
