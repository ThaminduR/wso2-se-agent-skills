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

echo "=== Auto Fix Pipeline ==="
echo "Issue: $ISSUE_URL (#$ISSUE_NUMBER)"
echo ""

# Step 1: Reproduce
echo "=== [1/4] Reproducing issue... ==="
claude -p "/reproduce $ISSUE_URL" --dangerously-skip-permissions
if [ ! -f ".ai/issue-analysis-${ISSUE_NUMBER}.md" ]; then
  echo "Error: Reproduction failed — no issue analysis artifact found."
  exit 1
fi
echo "=== Reproduction complete ==="
echo ""

# Step 2: Plan and fix
echo "=== [2/4] Planning and implementing fix... ==="
claude -p "/plan-fix $ISSUE_NUMBER" --dangerously-skip-permissions
echo "=== Fix implemented ==="
echo ""

# Step 3: Verify fix
echo "=== [3/4] Verifying fix... ==="
claude -p "/verify-fix $ISSUE_URL" --dangerously-skip-permissions
echo "=== Verification complete ==="
echo ""

# Step 4: Submit fix
echo "=== [4/4] Submitting PRs... ==="
claude -p "/submit-fix $ISSUE_NUMBER" --dangerously-skip-permissions
echo "=== PRs submitted ==="
echo ""

echo "=== Pipeline complete ==="
echo "Check .ai/issue-analysis-${ISSUE_NUMBER}.md for reproduction details"
echo "Check .ai/fix-report-${ISSUE_NUMBER}.md for PR links"
