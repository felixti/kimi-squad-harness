#!/bin/bash
# Squad Auto Feedback Loop — Test & Fix Harness
# Run this after any prompt changes to validate the squad setup
set -e

REPORT="/tmp/squad_test_report.md"
echo "# Squad Test Report" > "$REPORT"
echo "Generated: $(date)" >> "$REPORT"
echo "" >> "$REPORT"

ISSUES=0
FIXES=0

echo "🧪 Running Squad Test Harness..."

# ============================================================
# TEST 1: Subagent Type Availability
# ============================================================
echo ""
echo "TEST 1: Subagent Type Availability"
echo "## TEST 1: Subagent Type Availability" >> "$REPORT"

# Validate subagent definitions in squad.yaml
SUBAGENT_COUNT=$(grep -c "^    [a-z]*:$" ~/.kimi/agents/squad/squad.yaml 2>/dev/null || echo 0)
if [ "$SUBAGENT_COUNT" -ge 5 ]; then
    echo "  ✅ PASS: $SUBAGENT_COUNT custom subagents defined in squad.yaml"
    echo "- ✅ $SUBAGENT_COUNT custom subagents defined" >> "$REPORT"
else
    echo "  ❌ FAIL: Only $SUBAGENT_COUNT subagents found (expected >= 5)"
    echo "- ❌ Insufficient subagents" >> "$REPORT"
    ISSUES=$((ISSUES + 1))
fi

# Verify each subagent YAML has 'extend: default' (required for custom types)
INVALID_SUBAGENTS=0
for yaml in ~/.kimi/agents/squad/*.yaml; do
    if [ "$yaml" = "$HOME/.kimi/agents/squad/squad.yaml" ]; then continue; fi
    if ! grep -q "extend: default" "$yaml" 2>/dev/null; then
        echo "  ❌ FAIL: $(basename $yaml) missing 'extend: default'"
        echo "- ❌ $(basename $yaml) missing 'extend: default'" >> "$REPORT"
        INVALID_SUBAGENTS=$((INVALID_SUBAGENTS + 1))
        ISSUES=$((ISSUES + 1))
    fi
done

if [ "$INVALID_SUBAGENTS" -eq 0 ] && [ "$SUBAGENT_COUNT" -ge 5 ]; then
    echo "  ✅ PASS: All subagent YAMLs properly configured"
    echo "- ✅ All subagent YAMLs properly configured" >> "$REPORT"
fi

# ============================================================
# TEST 2: MCP Server Startup
# ============================================================
echo ""
echo "TEST 2: MCP Server Startup"
echo "## TEST 2: MCP Server Startup" >> "$REPORT"

# Test Brave Search MCP with API key
BRAVE_TEST=$(BRAVE_API_KEY="BSA34di360vLHgPwlsBI9Dva0JEIwPi" timeout 5 npx -y @modelcontextprotocol/server-brave-search 2>&1 || true)
if echo "$BRAVE_TEST" | grep -q "BRAVE_API_KEY"; then
    echo "  ✅ PASS: Brave Search MCP starts with API key"
    echo "- ✅ Brave Search MCP starts" >> "$REPORT"
else
    echo "  ⚠️  Brave Search MCP: needs manual verification (requires MCP handshake)"
    echo "- ⚠️ Brave Search MCP: manual verification needed" >> "$REPORT"
fi

# Test Grep MCP connectivity
GREP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://mcp.grep.app/ 2>/dev/null || echo "000")
if [ "$GREP_STATUS" = "405" ]; then
    echo "  ✅ PASS: Grep MCP endpoint reachable (405 = expected, needs POST)"
    echo "- ✅ Grep MCP endpoint reachable" >> "$REPORT"
else
    echo "  ❌ FAIL: Grep MCP endpoint unreachable (status: $GREP_STATUS)"
    echo "- ❌ Grep MCP endpoint unreachable" >> "$REPORT"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 3: Prompt Syntax Validation
# ============================================================
echo ""
echo "TEST 3: Prompt Syntax Validation"
echo "## TEST 3: Prompt Syntax Validation" >> "$REPORT"

for f in ~/.kimi/agents/squad/*.md; do
    BASENAME=$(basename "$f")
    
    # Count code block markers
    CODE_BLOCKS=$(grep -c '```' "$f" 2>/dev/null || echo 0)
    # Strip potential newlines from grep output
    CODE_BLOCKS=$(echo "$CODE_BLOCKS" | tr -d '\n' | head -1)
    
    if [ "$CODE_BLOCKS" -gt 0 ] 2>/dev/null && [ $((CODE_BLOCKS % 2)) -ne 0 ] 2>/dev/null; then
        echo "  ❌ FAIL: $BASENAME has unclosed code blocks"
        echo "- ❌ $BASENAME: unclosed code blocks" >> "$REPORT"
        ISSUES=$((ISSUES + 1))
    else
        echo "  ✅ PASS: $BASENAME syntax OK"
    fi
done

# ============================================================
# TEST 4: YAML Validation
# ============================================================
echo ""
echo "TEST 4: YAML Validation"
echo "## TEST 4: YAML Validation" >> "$REPORT"

for f in ~/.kimi/agents/squad/*.yaml; do
    BASENAME=$(basename "$f")
    if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
        echo "  ✅ PASS: $BASENAME is valid YAML"
        echo "- ✅ $BASENAME: valid YAML" >> "$REPORT"
    else
        echo "  ❌ FAIL: $BASENAME has YAML errors"
        echo "- ❌ $BASENAME: YAML errors" >> "$REPORT"
        ISSUES=$((ISSUES + 1))
    fi
done

# ============================================================
# TEST 5: File References
# ============================================================
echo ""
echo "TEST 5: File Reference Integrity"
echo "## TEST 5: File Reference Integrity" >> "$REPORT"

cd ~/.kimi/agents/squad/
MISSING=0
for ref in $(grep 'path:' squad.yaml | awk '{print $2}'); do
    if [ ! -f "$ref" ]; then
        echo "  ❌ FAIL: squad.yaml references missing file: $ref"
        echo "- ❌ Missing file: $ref" >> "$REPORT"
        MISSING=$((MISSING + 1))
        ISSUES=$((ISSUES + 1))
    fi
done

if [ "$MISSING" -eq 0 ]; then
    echo "  ✅ PASS: All file references valid"
    echo "- ✅ All file references valid" >> "$REPORT"
fi

# ============================================================
# TEST 6: Skill References
# ============================================================
echo ""
echo "TEST 6: Skill Reference Integrity"
echo "## TEST 6: Skill Reference Integrity" >> "$REPORT"

# Extract skill names from prompts: match **skill-name** pattern
grep -rohE '\*\*[a-z0-9]+([-][a-z0-9]+)*\*\*' ~/.kimi/agents/squad/*.md 2>/dev/null | tr -d '*' | sort -u > /tmp/referenced_skills.txt

SKILL_ISSUES=0
while IFS= read -r skill; do
    # Skip common false positives (words that are bold but not skills)
    case "$skill" in
        workflow|process|reference|primary|secondary|tertiary|description|what|when|who|how|why|any|all|new|code|data|test|web|core|industry|general|structured|library|docs|examples|gate|gates|findings|summary|recommendation|sources|status|size|lines|bytes|dotcontext|mcp)
            continue ;;
    esac
    
    SKILL_DIR="$HOME/.agents/skills/$skill"
    if [ ! -d "$SKILL_DIR" ] && [ ! -d "$HOME/.claude/skills/$skill" ]; then
        echo "  ❌ FAIL: Referenced skill not found: $skill"
        echo "- ❌ Missing skill: $skill" >> "$REPORT"
        SKILL_ISSUES=$((SKILL_ISSUES + 1))
        ISSUES=$((ISSUES + 1))
        continue
    fi
    
    # Check SKILL.md exists and has meaningful content (>500 bytes)
    if [ -f "$SKILL_DIR/SKILL.md" ]; then
        SKILL_SIZE=$(wc -c < "$SKILL_DIR/SKILL.md" 2>/dev/null || echo 0)
        if [ "$SKILL_SIZE" -lt 500 ]; then
            echo "  ⚠️  WARNING: Skill '$skill' SKILL.md is only ${SKILL_SIZE} bytes (threshold: 500)"
            echo "- ⚠️ Skill '$skill' is too small (${SKILL_SIZE} bytes)" >> "$REPORT"
        fi
    else
        echo "  ❌ FAIL: Skill '$skill' directory exists but SKILL.md missing"
        echo "- ❌ Skill '$skill' missing SKILL.md" >> "$REPORT"
        SKILL_ISSUES=$((SKILL_ISSUES + 1))
        ISSUES=$((ISSUES + 1))
    fi
done < /tmp/referenced_skills.txt

if [ "$SKILL_ISSUES" -eq 0 ]; then
    echo "  ✅ PASS: All referenced skills found and valid"
    echo "- ✅ All referenced skills found and valid" >> "$REPORT"
fi

# ============================================================
# TEST 8: JSON Schema
# ============================================================
echo ""
echo "TEST 8: JSON Response Schema"
echo "## TEST 8: JSON Response Schema" >> "$REPORT"

if [ -f ~/.kimi/agents/squad/response-schema.json ]; then
    if python3 -c "import json; json.load(open('$HOME/.kimi/agents/squad/response-schema.json'))" 2>/dev/null; then
        echo "  ✅ PASS: response-schema.json exists and is valid JSON"
        echo "- ✅ JSON schema valid" >> "$REPORT"
    else
        echo "  ❌ FAIL: response-schema.json is invalid JSON"
        echo "- ❌ JSON schema invalid" >> "$REPORT"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "  ❌ FAIL: response-schema.json not found"
    echo "- ❌ JSON schema missing" >> "$REPORT"
    ISSUES=$((ISSUES + 1))
fi

# Check that all agent prompts reference JSON output format
JSON_PROMPTS=0
TOTAL_PROMPTS=0
for f in ~/.kimi/agents/squad/*.md; do
    if [ "$(basename $f)" = "tech-lead.md" ]; then continue; fi
    TOTAL_PROMPTS=$((TOTAL_PROMPTS + 1))
    if grep -q "Output Format.*JSON\|JSON object\|response schema" "$f" 2>/dev/null; then
        JSON_PROMPTS=$((JSON_PROMPTS + 1))
    fi
done

if [ "$JSON_PROMPTS" -eq "$TOTAL_PROMPTS" ]; then
    echo "  ✅ PASS: All $TOTAL_PROMPTS subagent prompts reference JSON output"
    echo "- ✅ All subagents use JSON schema ($JSON_PROMPTS/$TOTAL_PROMPTS)" >> "$REPORT"
else
    echo "  ❌ FAIL: Only $JSON_PROMPTS/$TOTAL_PROMPTS subagents reference JSON output"
    echo "- ❌ Subagent JSON compliance incomplete ($JSON_PROMPTS/$TOTAL_PROMPTS)" >> "$REPORT"
    ISSUES=$((ISSUES + 1))
fi

# ============================================================
# TEST 9: 10/10 Behavioral Features
# ============================================================
echo ""
echo "TEST 9: 10/10 Behavioral Features"
echo "## TEST 9: 10/10 Behavioral Features" >> "$REPORT"

FEATURES=0
TOTAL_FEATURES=0

check_feature() {
    TOTAL_FEATURES=$((TOTAL_FEATURES + 1))
    if grep -qi "$2" ~/.kimi/agents/squad/tech-lead.md 2>/dev/null; then
        echo "  ✅ PASS: $1"
        echo "- ✅ $1" >> "$REPORT"
        FEATURES=$((FEATURES + 1))
    else
        echo "  ❌ FAIL: $1 not found in tech-lead.md"
        echo "- ❌ $1 missing" >> "$REPORT"
        ISSUES=$((ISSUES + 1))
    fi
}

check_feature "Convergence Detection" "convergence"
check_feature "Context Checkpoint Compression" "checkpoint"
check_feature "Subagent Failure Recovery" "failure"
check_feature "Session Metrics Logging" "metrics"
check_feature "Atomic Memory Writes" "atomic"

if [ "$FEATURES" -eq "$TOTAL_FEATURES" ]; then
    echo "  ✅ PASS: All $TOTAL_FEATURES behavioral features present"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "## Summary" >> "$REPORT"
echo "- Total Issues Found: $ISSUES" >> "$REPORT"
echo "- Auto-Fixes Applied: $FIXES" >> "$REPORT"
echo "- Status: $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS' || echo 'ISSUES DETECTED')" >> "$REPORT"

echo ""
echo "========================================"
echo "RESULTS:"
echo "  Issues Found: $ISSUES"
echo "  Auto-Fixes:   $FIXES"
echo "  Status:       $([ $ISSUES -eq 0 ] && echo 'ALL TESTS PASS ✅' || echo 'ISSUES DETECTED ⚠️')"
echo "========================================"
echo ""
echo "Full report: $REPORT"

# ============================================================
# TEST 7: Memory System
# ============================================================
echo ""
echo "TEST 7: Memory System"
echo "## TEST 7: Memory System" >> "$REPORT"

if [ -d ".context" ]; then
    echo "  ✅ PASS: .context/ directory exists"
    echo "- ✅ .context/ directory exists" >> "$REPORT"
    
    CONTEXT_FILES=0
    for dir in docs agents plans skills; do
        if [ -d ".context/$dir" ]; then
            CONTEXT_FILES=$((CONTEXT_FILES + 1))
        fi
    done
    
    if [ "$CONTEXT_FILES" -eq 4 ]; then
        echo "  ✅ PASS: All .context/ subdirectories present"
        echo "- ✅ All .context/ subdirectories present" >> "$REPORT"
    else
        echo "  ⚠️  WARNING: Only $CONTEXT_FILES/4 .context/ subdirectories present"
        echo "- ⚠️ Only $CONTEXT_FILES/4 .context/ subdirectories present" >> "$REPORT"
    fi
else
    echo "  ⚠️  WARNING: .context/ directory not found (optional but recommended)"
    echo "- ⚠️ .context/ directory not found (optional)" >> "$REPORT"
fi

# Check MCP config for dotcontext
if grep -q "dotcontext" ~/.kimi/mcp.json 2>/dev/null; then
    echo "  ✅ PASS: dotcontext MCP configured"
    echo "- ✅ dotcontext MCP configured" >> "$REPORT"
else
    echo "  ⚠️  WARNING: dotcontext MCP not found in ~/.kimi/mcp.json"
    echo "- ⚠️ dotcontext MCP not configured" >> "$REPORT"
fi

# Exit with error code if issues found
[ $ISSUES -eq 0 ] || exit 1
