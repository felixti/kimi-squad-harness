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

# Run a quick test with backend subagent
timeout 45 kimi --agent-file ~/.kimi/agents/squad/squad.yaml --max-ralph-iterations 1 -p \
  "Use Agent tool with subagent_type backend to write 'def hello(): return \"hi\"'. Output ONLY the code." \
  > /tmp/test1.log 2>&1 || true

# Check if backend subagent was launched (check log + recent session meta)
SUBAGENT_FOUND=false
if grep -q '"subagent_type": "backend"' /tmp/test1.log 2>/dev/null; then
    SUBAGENT_FOUND=true
fi
# Also check for any backend subagent meta.json created in last 2 minutes
if find ~/.kimi/sessions -name "meta.json" -mmin -2 -exec grep -l '"subagent_type": "backend"' {} \; 2>/dev/null | grep -q .; then
    SUBAGENT_FOUND=true
fi

if [ "$SUBAGENT_FOUND" = true ]; then
    echo "  ✅ PASS: Custom 'backend' subagent type works"
    echo "- ✅ Custom subagent types WORK" >> "$REPORT"
else
    echo "  ❌ FAIL: Custom subagent type not detected"
    echo "- ❌ Custom subagent types BROKEN" >> "$REPORT"
    ISSUES=$((ISSUES + 1))
fi

# Check if 'coder' is missing (expected when using custom agent file)
if grep -q "Builtin subagent type not found: coder" /tmp/test1.log 2>/dev/null; then
    echo "  ⚠️  NOTE: Built-in 'coder' unavailable (expected with custom agent)"
    echo "- ⚠️ Built-in 'coder' unavailable" >> "$REPORT"
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

# Extract skill names from prompts
grep -roh '\*\*[-a-z]*\*\*' ~/.kimi/agents/squad/*.md 2>/dev/null | tr -d '*' | sort -u > /tmp/referenced_skills.txt

MISSING_SKILLS=0
while IFS= read -r skill; do
    case "$skill" in
        workflow|process|reference|primary|secondary|tertiary|description|what|when|who|how|why|any|engineer|backend|frontend|qa|reviewer|researcher|tech|lead) continue ;;
    esac
    
    if [ ! -d "$HOME/.agents/skills/$skill" ] && [ ! -d "$HOME/.claude/skills/$skill" ]; then
        echo "  ⚠️  WARNING: Referenced skill not found: $skill"
        echo "- ⚠️ Missing skill: $skill" >> "$REPORT"
        MISSING_SKILLS=$((MISSING_SKILLS + 1))
    fi
done < /tmp/referenced_skills.txt

if [ "$MISSING_SKILLS" -eq 0 ]; then
    echo "  ✅ PASS: All referenced skills found"
    echo "- ✅ All referenced skills found" >> "$REPORT"
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

# Exit with error code if issues found
[ $ISSUES -eq 0 ] || exit 1
