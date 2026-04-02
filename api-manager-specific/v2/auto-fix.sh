#!/bin/bash
set -e

ISSUE_URL="$1"

if [ -z "$ISSUE_URL" ]; then
  echo "Usage: ./auto-fix.sh <github-issue-url>"
  echo "Example: ./auto-fix.sh https://github.com/wso2/product-apim/issues/12345"
  exit 1
fi

# Extract issue number from URL
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
if [ -z "$ISSUE_NUMBER" ]; then
  echo "Error: Could not extract issue number from URL"
  exit 1
fi

# Create logs directory
LOG_DIR=".ai/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Auto Fix Pipeline ==="
echo "Issue: $ISSUE_URL (#$ISSUE_NUMBER)"
echo "Logs: $LOG_DIR/issue-${ISSUE_NUMBER}-*.log"
echo ""

# Step 1: Reproduce
STEP1_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-1-reproduce-${TIMESTAMP}.log"
echo "=== [1/4] Reproducing issue... ==="
echo "  Log: $STEP1_LOG"
claude -p "/reproduce $ISSUE_URL" --verbose --dangerously-skip-permissions 2>&1 | tee "$STEP1_LOG"
if [ ! -f ".ai/issue-analysis-${ISSUE_NUMBER}.md" ]; then
  echo "Error: Reproduction failed — no issue analysis artifact found."
  exit 1
fi
echo ""
echo "=== Reproduction complete ==="
echo ""

# Step 2: Plan and fix
STEP2_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-2-plan-fix-${TIMESTAMP}.log"
echo "=== [2/4] Planning and implementing fix... ==="
echo "  Log: $STEP2_LOG"
claude -p "/plan-fix $ISSUE_NUMBER" --verbose --dangerously-skip-permissions 2>&1 | tee "$STEP2_LOG"
echo ""
echo "=== Fix implemented ==="
echo ""

# Step 3: Verify fix
STEP3_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-3-verify-fix-${TIMESTAMP}.log"
echo "=== [3/4] Verifying fix... ==="
echo "  Log: $STEP3_LOG"
claude -p "/verify-fix $ISSUE_URL" --verbose --dangerously-skip-permissions 2>&1 | tee "$STEP3_LOG"
echo ""
echo "=== Verification complete ==="
echo ""

# Step 4: Submit fix
STEP4_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-4-submit-fix-${TIMESTAMP}.log"
echo "=== [4/4] Submitting PRs... ==="
echo "  Log: $STEP4_LOG"
claude -p "/submit-fix $ISSUE_NUMBER" --verbose --dangerously-skip-permissions 2>&1 | tee "$STEP4_LOG"
echo ""
echo "=== PRs submitted ==="
echo ""

echo "=== Pipeline complete ==="
echo "Check .ai/issue-analysis-${ISSUE_NUMBER}.md for reproduction details"
echo "Check .ai/fix-report-${ISSUE_NUMBER}.md for PR links"
echo "Logs saved in $LOG_DIR/issue-${ISSUE_NUMBER}-*-${TIMESTAMP}.log"
