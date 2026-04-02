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

# ANSI colors
C_RESET = '\033[0m'
C_TOOL = '\033[1;36m'       # Bold Cyan for [tool]
C_THINKING = '\033[1;35m'   # Bold Magenta for [thinking]
C_TEXT = '\033[0;37m'        # White for assistant text
C_CMD = '\033[0;33m'         # Yellow for commands
C_READ = '\033[0;32m'        # Green for file reads
C_SEARCH = '\033[0;34m'      # Blue for search (Grep/Glob)
C_EDIT = '\033[0;31m'        # Red for edits/writes
C_AGENT = '\033[1;33m'       # Bold Yellow for agents
C_RESULT = '\033[0;32m'      # Green for results

TOOL_COLORS = {
    'Bash': C_CMD,
    'Read': C_READ,
    'Write': C_EDIT,
    'Edit': C_EDIT,
    'Glob': C_SEARCH,
    'Grep': C_SEARCH,
    'Agent': C_AGENT,
}

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

in_thinking = False

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

            # Track thinking state (don't print yet — wait for full assistant message)
            elif delta.get('type') == 'thinking_delta':
                in_thinking = True

            # Content block start
            elif event_type == 'content_block_start':
                cb = event.get('content_block', {})
                if cb.get('type') == 'tool_use':
                    in_thinking = False
                    name = cb.get('name', '')
                    color = TOOL_COLORS.get(name, C_TOOL)
                    out_partial('\n' + color + '[tool] ' + name + C_RESET)
                elif cb.get('type') == 'thinking':
                    in_thinking = False

            # Content block stop
            elif event_type == 'content_block_stop':
                in_thinking = False

        elif msg_type == 'assistant':
            message = obj.get('message', {})
            for block in message.get('content', []):
                if block.get('type') == 'tool_use':
                    name = block.get('name', '')
                    inp = block.get('input', {})
                    color = TOOL_COLORS.get(name, C_TOOL)
                    if name == 'Bash':
                        desc = inp.get('description', '')
                        cmd = inp.get('command', '')
                        if desc:
                            out(': ' + desc)
                        if cmd:
                            out('  ' + C_CMD + '$ ' + cmd + C_RESET)
                    elif name in ('Read', 'Write', 'Edit'):
                        fpath = inp.get('file_path', '')
                        if fpath:
                            out(': ' + fpath)
                    elif name in ('Glob', 'Grep'):
                        pattern = inp.get('pattern', '')
                        if pattern:
                            out(': ' + pattern)
                    elif name == 'Agent':
                        desc = inp.get('description', '')
                        if desc:
                            out(': ' + desc)
                    elif name == 'WebSearch':
                        query = inp.get('query', '')
                        if query:
                            out(': ' + query)
                    elif name == 'WebFetch':
                        url = inp.get('url', '')
                        if url:
                            out(': ' + url)
                    elif name == 'Skill':
                        skill = inp.get('skill', '')
                        if skill:
                            out(': /' + skill)
                    else:
                        out('')

                elif block.get('type') == 'thinking':
                    # Show thinking summary — first meaningful line, truncated
                    thinking_text = block.get('thinking', '').strip()
                    if thinking_text:
                        # Pick first non-empty line
                        for tline in thinking_text.split('\n'):
                            tline = tline.strip()
                            if tline:
                                summary = tline[:150]
                                if len(tline) > 150:
                                    summary += '...'
                                out(C_THINKING + '[thinking] ' + summary + C_RESET)
                                break

        elif msg_type == 'result':
            result = obj.get('result', '')
            if result:
                out('\n' + C_RESULT + result + C_RESET)

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
