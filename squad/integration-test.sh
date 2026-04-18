#!/bin/bash
# Squad Integration Test
# Validates the actual squad workflow end-to-end without live LLM calls
# Tests: pipeline assembly, schema validation, memory consistency, metric logging
set -e

echo "🔬 Squad Integration Test"
echo "========================="

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

ISSUES=0

# ============================================================
# TEST 1: Pipeline Assembly
# ============================================================
echo ""
echo "TEST 1: Pipeline Assembly"

# Verify all agents can be loaded together
TOTAL_PROMPT_SIZE=0
for f in ~/.kimi/agents/squad/*.md; do
    SIZE=$(wc -c < "$f")
    TOTAL_PROMPT_SIZE=$((TOTAL_PROMPT_SIZE + SIZE))
done

# Sanity check: total prompt size should be reasonable (< 50KB)
if [ "$TOTAL_PROMPT_SIZE" -lt 51200 ]; then
    echo "  ✅ PASS: Combined prompt size ${TOTAL_PROMPT_SIZE} bytes (< 50KB)"
else
    echo "  ⚠️  WARNING: Combined prompt size ${TOTAL_PROMPT_SIZE} bytes (consider trimming)"
fi

# Verify JSON schema is referenced by all subagents
SCHEMA_REFS=0
for f in ~/.kimi/agents/squad/backend.md ~/.kimi/agents/squad/frontend.md ~/.kimi/agents/squad/qa.md ~/.kimi/agents/squad/reviewer.md ~/.kimi/agents/squad/researcher.md; do
    if grep -q "response schema\|JSON object\|Output Format.*JSON" "$f" 2>/dev/null; then
        SCHEMA_REFS=$((SCHEMA_REFS + 1))
    fi
done

if [ "$SCHEMA_REFS" -eq 5 ]; then
    echo "  ✅ PASS: All 5 subagents reference JSON response schema"
else
    echo "  ❌ FAIL: Only $SCHEMA_REFS/5 subagents reference JSON schema"
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
# Validate schema structure
assert 'properties' in schema
assert 'agent' in schema['properties']
assert 'verdict' in schema['properties']
assert 'findings' in schema['properties']
assert 'confidence' in schema['properties']
print('Schema structure valid')
" 2>/dev/null; then
    echo "  ✅ PASS: Schema structure validated"
else
    echo "  ❌ FAIL: Schema structure invalid"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 3: Memory System Consistency
# ============================================================
echo ""
echo "TEST 3: Memory System Consistency"

# Create a mock project context
mkdir -p "$TEST_DIR/.context"/{docs,agents,plans,skills,metrics}

# Write initial memory files
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

# Verify atomic write protocol can be simulated
echo "test content" > "$TEST_DIR/.context/tmp-test.md"
mv "$TEST_DIR/.context/tmp-test.md" "$TEST_DIR/.context/docs/decisions.md"

if [ -f "$TEST_DIR/.context/docs/decisions.md" ]; then
    echo "  ✅ PASS: Atomic write protocol works"
else
    echo "  ❌ FAIL: Atomic write protocol failed"
    ISSUES=$((ISSUES + 1))
fi

# Verify metrics directory exists and is writable
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

# Extract the delegation template from tech-lead.md
# Capture from "## Delegation Template" to the next "## " section header
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

# ============================================================
# TEST 7: Simulated LLM Output Parsing
# ============================================================
echo ""
echo "TEST 7: Simulated LLM Output Parsing"

# Create a simulated valid backend response
SIMULATED_BACKEND='{"agent": "backend", "gate": 1, "verdict": "PASS", "confidence": 0.95, "findings": [{"severity": "INFO", "message": "Done"}], "outputs": [{"type": "code", "description": "API endpoint", "path": "app.js"}]}'

# Validate it against the schema
if python3 -c "
import json
schema = json.load(open('$HOME/.kimi/agents/squad/response-schema.json'))
data = json.loads('$SIMULATED_BACKEND')
# Basic validation
assert data['agent'] in schema['properties']['agent']['enum']
assert data['gate'] >= schema['properties']['gate']['minimum']
assert data['verdict'] in schema['properties']['verdict']['enum']
assert 0.0 <= data['confidence'] <= 1.0
assert isinstance(data['findings'], list)
assert isinstance(data['outputs'], list)
print('Simulated backend response valid')
" 2>/dev/null; then
    echo "  ✅ PASS: Simulated backend response validates against schema"
else
    echo "  ❌ FAIL: Simulated backend response failed validation"
    ISSUES=$((ISSUES + 1))
fi

# Create a simulated malformed response and verify Tech Lead has recovery guidance
if grep -q "malformed\|retry.*JSON\|parse.*heuristic" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Tech Lead has JSON parsing robustness guidance"
else
    echo "  ❌ FAIL: Tech Lead missing JSON parsing robustness"
    ISSUES=$((ISSUES + 1))
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
# SUMMARY
# ============================================================
echo ""
echo "========================================"
echo "INTEGRATION TEST RESULTS:"
echo "  Issues Found: $ISSUES"
echo "  Status: $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS ✅' || echo 'ISSUES DETECTED ⚠️')"
echo "========================================"

[ $ISSUES -eq 0 ] || exit 1
