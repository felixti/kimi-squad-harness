#!/bin/bash
# Squad Prompt Regression Suite
# Ensures prompt changes don't alter core behavioral contracts
# Run after ANY prompt edit to catch regressions
set -e

echo "🧪 Squad Prompt Regression Suite"
echo "================================="

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

# Verify each class has the expected gates
EXPECTED_CLASSES=("Trivial" "Small" "Medium" "Large")
for cls in "${EXPECTED_CLASSES[@]}"; do
    if grep -q "\*\*$cls\*\*" ~/.kimi/agents/squad/tech-lead.md; then
        echo "  ✅ PASS: Class '$cls' defined"
    else
        echo "  ❌ FAIL: Class '$cls' missing"
        ISSUES=$((ISSUES + 1))
    fi
done

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
    
    # Each subagent YAML must have extend: default
    if grep -q "extend: default" "$yaml"; then
        echo "  ✅ PASS: $BASENAME has extend: default"
    else
        echo "  ❌ FAIL: $BASENAME missing extend: default"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Each subagent YAML must have system_prompt_path
    if grep -q "system_prompt_path:" "$yaml"; then
        echo "  ✅ PASS: $BASENAME has system_prompt_path"
    else
        echo "  ❌ FAIL: $BASENAME missing system_prompt_path"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Each subagent must reference ReadFile
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
    
    # Each subagent must mention memory system
    if grep -qi "memory system\|\.context" "$md"; then
        echo "  ✅ PASS: $BASENAME references memory"
    else
        echo "  ❌ FAIL: $BASENAME missing memory reference"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Each subagent must have skills section
    if grep -qi "skills" "$md"; then
        echo "  ✅ PASS: $BASENAME has skills section"
    else
        echo "  ❌ FAIL: $BASENAME missing skills section"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Each subagent must have self-check or output format
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
echo "TEST 7: Behavioral Feature Regression (10/10 Additions)"

FEATURES=(
    "Convergence Detection:convergence"
    "Checkpoint Compression:\[CHECKPOINT\]"
    "Failure Recovery:Failure Recovery"
    "Session Metrics:Session Metrics"
    "Atomic Writes:atomic"
    "JSON Schema:response-schema.json"
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
# SUMMARY
# ============================================================
echo ""
echo "========================================"
echo "REGRESSION SUITE RESULTS:"
echo "  Issues Found: $ISSUES"
echo "  Status: $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS ✅' || echo 'REGRESSIONS DETECTED ⚠️')"
echo "========================================"

[ $ISSUES -eq 0 ] || exit 1
