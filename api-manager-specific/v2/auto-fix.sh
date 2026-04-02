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

# Helper: run claude -p with real-time streaming to log file
# Uses stream-json + include-partial-messages for token-level streaming,
# then extracts human-readable text (tool calls + assistant text) in real-time.
# Usage: run_claude_streaming <log_file> <prompt>
run_claude_streaming() {
  local log_file="$1"
  shift
  local prompt="$*"

  export LOG_FILE="$log_file"
  claude -p "$prompt" \
    --output-format stream-json --verbose --include-partial-messages \
    --dangerously-skip-permissions 2>&1 \
  | python3 -u -c "
import sys, json, os

log_file = os.environ.get('LOG_FILE', '/dev/null')
f = open(log_file, 'w')

def out(text, end='\n'):
    sys.stdout.write(text + end)
    sys.stdout.flush()
    f.write(text + end)
    f.flush()

def out_partial(text):
    sys.stdout.write(text)
    sys.stdout.flush()
    f.write(text)
    f.flush()

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        msg_type = obj.get('type', '')

        if msg_type == 'stream_event':
            event = obj.get('event', {})
            event_type = event.get('type', '')
            delta = event.get('delta', {})

            # Token-level text streaming
            if delta.get('type') == 'text_delta':
                out_partial(delta.get('text', ''))

            # Tool use block start
            elif event_type == 'content_block_start':
                cb = event.get('content_block', {})
                if cb.get('type') == 'tool_use':
                    out_partial('\n[tool] ' + cb.get('name', ''))

        elif msg_type == 'assistant':
            message = obj.get('message', {})
            for block in message.get('content', []):
                if block.get('type') == 'tool_use':
                    name = block.get('name', '')
                    inp = block.get('input', {})
                    if name == 'Bash':
                        detail = inp.get('description', inp.get('command', ''))
                    elif name in ('Read', 'Write', 'Edit', 'Glob', 'Grep'):
                        detail = inp.get('file_path', inp.get('pattern', ''))
                    elif name == 'Agent':
                        detail = inp.get('description', '')
                    else:
                        detail = ''
                    if detail:
                        out(': ' + detail)
                    else:
                        out('')

        elif msg_type == 'result':
            result = obj.get('result', '')
            if result:
                out('\n' + result)

    except (json.JSONDecodeError, KeyError):
        pass

f.close()
"
}

echo "=== Auto Fix Pipeline ==="
echo "Issue: $ISSUE_URL (#$ISSUE_NUMBER)"
echo "Logs: $LOG_DIR/issue-${ISSUE_NUMBER}-*.log"
echo ""

# Step 1: Reproduce
STEP1_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-1-reproduce-${TIMESTAMP}.log"
echo "=== [1/4] Reproducing issue... ==="
echo "  Log: $STEP1_LOG"
run_claude_streaming "$STEP1_LOG" "/reproduce $ISSUE_URL"
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
run_claude_streaming "$STEP2_LOG" "/plan-fix $ISSUE_NUMBER"
echo ""
echo "=== Fix implemented ==="
echo ""

# Step 3: Verify fix
STEP3_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-3-verify-fix-${TIMESTAMP}.log"
echo "=== [3/4] Verifying fix... ==="
echo "  Log: $STEP3_LOG"
run_claude_streaming "$STEP3_LOG" "/verify-fix $ISSUE_URL"
echo ""
echo "=== Verification complete ==="
echo ""

# Step 4: Submit fix
STEP4_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-4-submit-fix-${TIMESTAMP}.log"
echo "=== [4/4] Submitting PRs... ==="
echo "  Log: $STEP4_LOG"
run_claude_streaming "$STEP4_LOG" "/submit-fix $ISSUE_NUMBER"
echo ""
echo "=== PRs submitted ==="
echo ""

echo "=== Pipeline complete ==="
echo "Check .ai/issue-analysis-${ISSUE_NUMBER}.md for reproduction details"
echo "Check .ai/fix-report-${ISSUE_NUMBER}.md for PR links"
echo "Logs saved in $LOG_DIR/issue-${ISSUE_NUMBER}-*-${TIMESTAMP}.log"
