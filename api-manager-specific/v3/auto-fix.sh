#!/bin/bash
set -e

usage() {
  echo "Usage: ./auto-fix.sh [options] <github-issue-url>"
  echo ""
  echo "Automated pipeline to reproduce, fix, verify, and submit PRs for GitHub issues."
  echo ""
  echo "Steps:"
  echo "  1. reproduce    Analyze the issue, reproduce the bug, generate issue-analysis artifact"
  echo "  2. plan-fix     Plan and implement a code fix based on the analysis"
  echo "  3. verify-fix   Build, patch the product, and verify the fix resolves the issue"
  echo "  4. submit-fix   Create PRs for the fix and generate a fix report"
  echo ""
  echo "Options:"
  echo "  --steps <steps>   Comma-separated steps to run (default: all)"
  echo "                    Accepts names or numbers: reproduce,plan-fix or 1,2"
  echo "  --from <step>     Start from this step onwards (runs all subsequent steps)"
  echo "  --only <step>     Run only this single step"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  # Run full pipeline"
  echo "  ./auto-fix.sh https://github.com/wso2/product-apim/issues/12345"
  echo ""
  echo "  # Only reproduce the issue"
  echo "  ./auto-fix.sh --only reproduce https://github.com/wso2/product-apim/issues/12345"
  echo ""
  echo "  # Re-run from verify onwards (after manual code changes)"
  echo "  ./auto-fix.sh --from verify-fix https://github.com/wso2/product-apim/issues/12345"
  echo ""
  echo "  # Run specific steps"
  echo "  ./auto-fix.sh --steps 1,2 https://github.com/wso2/product-apim/issues/12345"
  echo "  ./auto-fix.sh --steps reproduce,plan-fix https://github.com/wso2/product-apim/issues/12345"
  echo ""
  echo "Logs are saved to .ai/logs/ (processed + raw)."
  echo "Artifacts: .ai/issue-analysis-<number>.md, .ai/fix-report-<number>.md"
  exit 1
}

# Parse arguments
STEPS=""
FROM_STEP=""
ISSUE_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --steps) STEPS="$2"; shift 2 ;;
    --from)  FROM_STEP="$2"; shift 2 ;;
    --only)  STEPS="$2"; shift 2 ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $1"; usage ;;
    *)  ISSUE_URL="$1"; shift ;;
  esac
done

if [ -z "$ISSUE_URL" ]; then
  usage
fi

# Extract issue number from URL
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
if [ -z "$ISSUE_NUMBER" ]; then
  echo "Error: Could not extract issue number from URL"
  exit 1
fi

# Normalize step names (support both names and numbers)
normalize_step() {
  case "$1" in
    1|reproduce)   echo "reproduce" ;;
    2|plan-fix)    echo "plan-fix" ;;
    3|verify-fix)  echo "verify-fix" ;;
    4|submit-fix)  echo "submit-fix" ;;
    *) echo "Error: Unknown step '$1'. Valid: reproduce, plan-fix, verify-fix, submit-fix (or 1-4)"; exit 1 ;;
  esac
}

ALL_STEPS="reproduce plan-fix verify-fix submit-fix"

# Determine which steps to run
if [ -n "$FROM_STEP" ]; then
  FROM_STEP=$(normalize_step "$FROM_STEP")
  RUN_STEPS=""
  found=false
  for s in $ALL_STEPS; do
    if [ "$s" = "$FROM_STEP" ]; then found=true; fi
    if $found; then RUN_STEPS="$RUN_STEPS $s"; fi
  done
elif [ -n "$STEPS" ]; then
  RUN_STEPS=""
  IFS=',' read -ra PARTS <<< "$STEPS"
  for part in "${PARTS[@]}"; do
    RUN_STEPS="$RUN_STEPS $(normalize_step "$(echo "$part" | xargs)")"
  done
else
  RUN_STEPS="$ALL_STEPS"
fi

should_run() {
  echo "$RUN_STEPS" | grep -qw "$1"
}

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

  local raw_log_file="${log_file%.log}-raw.log"
  export LOG_FILE="$log_file"
  export RAW_LOG_FILE="$raw_log_file"
  claude -p "$prompt" \
    --output-format stream-json --verbose --include-partial-messages \
    --dangerously-skip-permissions 2>&1 \
  | python3 -u -c "
import sys, json, os

log_file = os.environ.get('LOG_FILE', '/dev/null')
raw_log_file = os.environ.get('RAW_LOG_FILE', '/dev/null')
f = open(log_file, 'w')
raw_f = open(raw_log_file, 'w')

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
    # Write raw unprocessed line to raw log
    raw_f.write(line)
    raw_f.flush()
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
                                out(C_THINKING + '[thinking] ' + tline + C_RESET)
                                break

        elif msg_type == 'result':
            result = obj.get('result', '')
            if result:
                out('\n' + C_RESULT + result + C_RESET)

    except (json.JSONDecodeError, KeyError):
        pass

f.close()
raw_f.close()
"
}

# Pre-flight checks
preflight_check() {
  local failed=false
  for cmd in claude gh python3 curl java mvn; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: '$cmd' not found in PATH"
      failed=true
    fi
  done
  if ! ls wso2am-*.zip &>/dev/null; then
    echo "Error: No product pack zip (wso2am-*.zip) found in workspace"
    failed=true
  fi
  if $failed; then
    echo "Pre-flight checks failed. Aborting."
    exit 1
  fi
}

# Clean environment: stop any running WSO2 servers and delete extracted packs.
# Called before every step to guarantee a clean slate.
# All commands are guarded to be safe when no pack/server exists.
clean_environment() {
  echo "  Cleaning environment..."

  # Graceful stop via --stop for any pack that has a PID file
  for PACK_DIR in wso2am-*/; do
    [ -d "$PACK_DIR" ] || continue
    if [ -f "$PACK_DIR/wso2carbon.pid" ]; then
      (cd "$PACK_DIR/bin" && sh api-manager.sh --stop 2>/dev/null) || true
    fi
  done

  # Wait for graceful shutdown (up to 30s)
  for PID_FILE in wso2am-*/wso2carbon.pid; do
    [ -f "$PID_FILE" ] || continue
    PID=$(cat "$PID_FILE" 2>/dev/null) || continue
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      WAIT=0
      while kill -0 "$PID" 2>/dev/null && [ $WAIT -lt 30 ]; do
        sleep 2; WAIT=$((WAIT+2))
      done
      kill -9 "$PID" 2>/dev/null || true
    fi
  done

  # Kill any orphaned WSO2 java processes
  for PID in $(ps aux | grep 'org.wso2.carbon.bootstrap.Bootstrap' | grep -v grep | awk '{print $2}'); do
    kill "$PID" 2>/dev/null || true
    sleep 3
    kill -9 "$PID" 2>/dev/null || true
  done

  # Verify critical ports are free
  for PORT in 9443 9763 8280 8243 5672; do
    PORT_PID=$(lsof -ti :$PORT 2>/dev/null) || true
    if [ -n "$PORT_PID" ]; then
      kill -9 "$PORT_PID" 2>/dev/null || true
      sleep 1
    fi
  done

  # Delete extracted pack directories (keep the .zip)
  rm -rf wso2am-*/ 2>/dev/null || true

  echo "  Environment clean."
}

preflight_check

echo "=== Auto Fix Pipeline ==="
echo "Issue: $ISSUE_URL (#$ISSUE_NUMBER)"
echo "Steps: $RUN_STEPS"
echo "Logs: $LOG_DIR/issue-${ISSUE_NUMBER}-*.log"
echo ""

# Step 1: Reproduce
if should_run "reproduce"; then
  STEP1_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-1-reproduce-${TIMESTAMP}.log"
  echo "=== [1/4] Reproducing issue... ==="
  STEP_START=$(date +%s)
  clean_environment
  echo "  Log: $STEP1_LOG"
  run_claude_streaming "$STEP1_LOG" "/reproduce $ISSUE_URL"
  STEP_END=$(date +%s)
  echo "  Duration: $(( STEP_END - STEP_START ))s"
  if [ ! -f ".ai/issue-analysis-${ISSUE_NUMBER}.md" ]; then
    echo "Error: Reproduction failed — no issue analysis artifact found."
    exit 1
  fi
  echo ""
  echo "=== Reproduction complete ==="
  echo ""
fi

# Step 2: Plan and fix
if should_run "plan-fix"; then
  STEP2_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-2-plan-fix-${TIMESTAMP}.log"
  echo "=== [2/4] Planning and implementing fix... ==="
  STEP_START=$(date +%s)
  clean_environment
  echo "  Log: $STEP2_LOG"
  run_claude_streaming "$STEP2_LOG" "/plan-fix $ISSUE_NUMBER"
  STEP_END=$(date +%s)
  echo "  Duration: $(( STEP_END - STEP_START ))s"
  echo ""
  echo "=== Fix implemented ==="
  echo ""
fi

# Step 3: Verify fix
if should_run "verify-fix"; then
  STEP3_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-3-verify-fix-${TIMESTAMP}.log"
  echo "=== [3/4] Verifying fix... ==="
  STEP_START=$(date +%s)
  clean_environment
  echo "  Log: $STEP3_LOG"
  run_claude_streaming "$STEP3_LOG" "/verify-fix $ISSUE_URL"
  STEP_END=$(date +%s)
  echo "  Duration: $(( STEP_END - STEP_START ))s"
  echo ""
  echo "=== Verification complete ==="
  echo ""
fi

# Step 4: Submit fix
if should_run "submit-fix"; then
  STEP4_LOG="$LOG_DIR/issue-${ISSUE_NUMBER}-4-submit-fix-${TIMESTAMP}.log"
  echo "=== [4/4] Submitting PRs... ==="
  STEP_START=$(date +%s)
  clean_environment
  echo "  Log: $STEP4_LOG"
  run_claude_streaming "$STEP4_LOG" "/submit-fix $ISSUE_NUMBER"
  STEP_END=$(date +%s)
  echo "  Duration: $(( STEP_END - STEP_START ))s"
  echo ""
  echo "=== PRs submitted ==="
  echo ""
fi

echo "=== Pipeline complete ==="
echo "Logs saved in $LOG_DIR/issue-${ISSUE_NUMBER}-*-${TIMESTAMP}.log"
