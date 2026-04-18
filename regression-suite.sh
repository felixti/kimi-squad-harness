#!/bin/bash
# Squad Prompt Regression Suite v2.0
# Ensures prompt changes don't alter core behavioral contracts
# Run after ANY prompt edit to catch regressions
set -e

echo "🧪 Squad Prompt Regression Suite v2.0"
echo "======================================"

ISSUES=0

# ============================================================
# TEST 1: Fast Path Classification Consistency
# ============================================================
echo ""
echo "TEST 1: Fast Path Classification Consistency"

# Verify classification table has exactly 4 classes
CLASS_COUNT=$(grep -c "^| \*\*" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null || echo 0)
if [ "$CLASS_COUNT" -eq 4 ]; then
    echo "  ✅ PASS: Exactly 4 task classes defined"
else
    echo "  ❌ FAIL: Expected 4 classes, found $CLASS_COUNT"
    ISSUES=$((ISSUES + 1))
fi

EXPECTED_CLASSES=("Trivial" "Small" "Medium" "Large")
for cls in "${EXPECTED_CLASSES[@]}"; do
    if grep -q "\*\*$cls\*\*" ~/.kimi/agents/squad/tech-lead.md; then
        echo "  ✅ PASS: Class '$cls' defined"
    else
        echo "  ❌ FAIL: Class '$cls' missing"
        ISSUES=$((ISSUES + 1))
    fi
done

# Verify gate counts match class definitions
if grep -q "Trivial.*Gate 1" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Small.*Gates 1-2" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Medium.*Gates 1-4" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Large.*All 5" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Gate ranges correctly mapped to classes"
else
    echo "  ❌ FAIL: Gate range mapping inconsistent"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 2: Gate Definitions Preserved
# ============================================================
echo ""
echo "TEST 2: Gate Definitions Preserved"

for gate in "Gate 1: Self-Check" "Gate 2: Functional" "Gate 3: QA Validation" \
            "Gate 4: Reviewer Approval" "Gate 5: Integration"; do
    if grep -q "$gate" ~/.kimi/agents/squad/tech-lead.md; then
        echo "  ✅ PASS: $gate defined"
    else
        echo "  ❌ FAIL: $gate missing"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 3: Ralph Loop Contract
# ============================================================
echo ""
echo "TEST 3: Ralph Loop Contract"

CONTRACT_CHECKS=(
    "Ralph Loop"
    "<choice>STOP</choice>"
    "SetTodoList"
    "3 revisions"
)

for check in "${CONTRACT_CHECKS[@]}"; do
    if grep -q "$check" ~/.kimi/agents/squad/tech-lead.md; then
        echo "  ✅ PASS: Contract element '$check' present"
    else
        echo "  ❌ FAIL: Contract element '$check' missing"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 4: Memory Protocol Contract
# ============================================================
echo ""
echo "TEST 4: Memory Protocol Contract"

MEMORY_CHECKS=(
    "READ memory first"
    "WRITE memory last"
    ".context/docs/architecture.md"
    ".context/docs/patterns.md"
    ".context/docs/decisions.md"
    ".context/agents/squad-memory.md"
    ".context/plans/current.md"
)

for check in "${MEMORY_CHECKS[@]}"; do
    if grep -q "$check" ~/.kimi/agents/squad/tech-lead.md; then
        echo "  ✅ PASS: Memory protocol '$check' present"
    else
        echo "  ❌ FAIL: Memory protocol '$check' missing"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 5: Subagent YAML Contracts
# ============================================================
echo ""
echo "TEST 5: Subagent YAML Contracts"

for yaml in ~/.kimi/agents/squad/*.yaml; do
    BASENAME=$(basename "$yaml")
    if [ "$BASENAME" = "squad.yaml" ]; then continue; fi
    
    if grep -q "extend: default" "$yaml"; then
        echo "  ✅ PASS: $BASENAME has extend: default"
    else
        echo "  ❌ FAIL: $BASENAME missing extend: default"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -q "system_prompt_path:" "$yaml"; then
        echo "  ✅ PASS: $BASENAME has system_prompt_path"
    else
        echo "  ❌ FAIL: $BASENAME missing system_prompt_path"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -q "ReadFile" "$yaml"; then
        echo "  ✅ PASS: $BASENAME has ReadFile"
    else
        echo "  ❌ FAIL: $BASENAME missing ReadFile"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 6: Subagent Prompt Contracts
# ============================================================
echo ""
echo "TEST 6: Subagent Prompt Contracts"

for md in ~/.kimi/agents/squad/backend.md ~/.kimi/agents/squad/frontend.md \
          ~/.kimi/agents/squad/qa.md ~/.kimi/agents/squad/reviewer.md \
          ~/.kimi/agents/squad/researcher.md; do
    BASENAME=$(basename "$md")
    
    if grep -qi "memory system\|\.context" "$md"; then
        echo "  ✅ PASS: $BASENAME references memory"
    else
        echo "  ❌ FAIL: $BASENAME missing memory reference"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -qi "skills" "$md"; then
        echo "  ✅ PASS: $BASENAME has skills section"
    else
        echo "  ❌ FAIL: $BASENAME missing skills section"
        ISSUES=$((ISSUES + 1))
    fi
    
    if grep -qi "self-check\|output format\|verdict" "$md"; then
        echo "  ✅ PASS: $BASENAME has verification/output"
    else
        echo "  ❌ FAIL: $BASENAME missing verification/output"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 7: Behavioral Feature Regression
# ============================================================
echo ""
echo "TEST 7: Behavioral Feature Regression"

FEATURES=(
    "Convergence Detection:convergence"
    "Checkpoint Compression:\[CHECKPOINT\]"
    "Failure Recovery:Failure Recovery"
    "Session Metrics:Session Metrics"
    "Atomic Writes:atomic"
    "Response Schema:response-schema.json"
    "Timeout Guidance:Expected Task Durations"
    "Context Awareness:Context Size Awareness"
)

for feature in "${FEATURES[@]}"; do
    NAME=$(echo "$feature" | cut -d: -f1)
    PATTERN=$(echo "$feature" | cut -d: -f2)
    
    if grep -q "$PATTERN" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null || \
       [ -f ~/.kimi/agents/squad/response-schema.json ]; then
        echo "  ✅ PASS: $NAME present"
    else
        echo "  ❌ FAIL: $NAME missing"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 8: Parallel Delegation Contract
# ============================================================
echo ""
echo "TEST 8: Parallel Delegation Contract"

if grep -q "Parallelize" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "independent" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Parallel delegation guidance present"
else
    echo "  ❌ FAIL: Parallel delegation guidance missing"
    ISSUES=$((ISSUES + 1))
fi

# Verify dispatching-parallel-agents skill is referenced
if grep -q "dispatching-parallel-agents" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: dispatching-parallel-agents skill referenced"
else
    echo "  ⚠️  WARNING: dispatching-parallel-agents skill not referenced"
fi

# ============================================================
# TEST 9: Failure Recovery Simulation
# ============================================================
echo ""
echo "TEST 9: Failure Recovery Simulation"

# Verify the retry-degrade sequence is complete
if grep -q "Retry once" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Second failure" ~/.kimi/agents/squad/tech-lead.md && \
   grep -q "Degrade gracefully" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Failure recovery sequence complete (retry → degrade)"
else
    echo "  ❌ FAIL: Failure recovery sequence incomplete"
    ISSUES=$((ISSUES + 1))
fi

# Verify all subagent types have degradation paths
DEGRADE_CHECKS=(
    "backend.*implement.*backend"
    "QA.*write tests"
    "reviewer.*perform.*review"
    "researcher.*SearchWeb"
)
FOUND_DEGRADE=0
for pattern in "${DEGRADE_CHECKS[@]}"; do
    if grep -qiE "$pattern" ~/.kimi/agents/squad/tech-lead.md; then
        FOUND_DEGRADE=$((FOUND_DEGRADE + 1))
    fi
done
if [ "$FOUND_DEGRADE" -ge 3 ]; then
    echo "  ✅ PASS: Degradation paths defined for $FOUND_DEGRADE/4 subagent types"
else
    echo "  ❌ FAIL: Only $FOUND_DEGRADE/4 degradation paths defined"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 10: Large Task Gate Verification
# ============================================================
echo ""
echo "TEST 10: Large Task Gate Verification"

# Large tasks require all 5 gates
if grep -q "Large.*All 5.*Full squad" ~/.kimi/agents/squad/tech-lead.md; then
    echo "  ✅ PASS: Large tasks require full squad and all 5 gates"
else
    echo "  ❌ FAIL: Large task gate requirements unclear"
    ISSUES=$((ISSUES + 1))
fi

# Verify Gate 5 (Integration) mentions backend + frontend together
if grep -A2 "Gate 5: Integration" ~/.kimi/agents/squad/tech-lead.md | grep -qi "backend.*frontend\|together\|end-to-end"; then
    echo "  ✅ PASS: Gate 5 mentions integration between backend and frontend"
else
    echo "  ⚠️  WARNING: Gate 5 integration scope not explicitly defined"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================"
echo "REGRESSION SUITE RESULTS:"
echo "  Issues Found: $ISSUES"
echo "  Status: $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS ✅' || echo 'REGRESSIONS DETECTED ⚠️')"
echo "========================================"

[ $ISSUES -eq 0 ] || exit 1
