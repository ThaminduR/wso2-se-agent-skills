# WSO2 API Manager - Issue Reproduction Workspace

## Product Pack

A pre-built product pack is available in the workspace as `wso2am-<version>.zip`. Use this pack to reproduce issues.

## Starting the Product

1. Extract the pack: `unzip wso2am-<version>.zip`
2. **Before the first start**, check if the default port (9443) is available:
   ```
   lsof -i :9443
   ```
   - If the port is in use, set a port offset in `wso2am-<version>/repository/conf/deployment.toml` **before starting the server for the first time**. Add or update:
     ```toml
     [server]
     offset = <chosen_offset>
     ```
   - Pick an offset where the port (9443 + offset) is free. For example, offset=10 means the server uses port 9453.
   - **CRITICAL**: The offset must be set before the very first start. Once the server starts, it creates internal artifacts bound to the configured ports. Changing the offset after the first start will break the server — you would need to re-extract a fresh pack.
3. Navigate to the bin directory: `cd wso2am-<version>/bin`
4. Start the server: `sh api-manager.sh`
5. **Verifying server startup**: The server takes time to start (up to 2-3 minutes). To check if the server is ready, look for the following line in the startup log or in `wso2am-<version>/repository/logs/wso2carbon.log`:
   ```
   WSO2 Carbon started in XX sec
   ```
   and
   ```
   Mgt Console URL  : https://localhost:<port>/carbon/
   ```
   Poll the log file for these lines instead of blindly curling endpoints with sleep. Do NOT kill and restart the server if it doesn't respond immediately — just wait for the log to confirm startup. Only consider it failed if the log shows an error or the process has exited.

## Patching the Product (Verify Fix)

When code changes have been made in `carbon-apimgt` (or similar source repos), you need to build the changed module and patch the running product pack. Do NOT rebuild the entire product.

### Step 1: Checkout the matching source version

**CRITICAL**: Before making any code changes, you MUST checkout the source repo to the exact version that matches the jar in the product pack. If the versions don't match, the patched jar will be incompatible and the server will fail.

1. Find the version of the jar in the pack:
   ```bash
   ls wso2am-<version>/repository/components/plugins/ | grep <module-name>
   # Example output: org.wso2.carbon.apimgt.impl_9.33.65.jar
   # The version is 9.33.65
   ```

2. Find the matching tag in the source repo:
   ```bash
   cd carbon-apimgt
   git tag | grep "9.33.65"
   # Example output: v9.33.65
   ```

3. Checkout that tag and create a working branch:
   ```bash
   git checkout v9.33.65 -b fix/issue-<number>
   ```

4. Now make your code changes on this branch.

### Step 2: Build the changed module

Navigate to the changed module directory and build:
```
cd carbon-apimgt/components/apimgt/<module-name>
mvn clean install -Dmaven.test.skip=true
```
The built jar will be in the module's `target/` directory. The version in the built jar (e.g., `9.33.65-SNAPSHOT`) must match the version in the pack (e.g., `9.33.65`). If they don't match, you checked out the wrong tag — go back to Step 1.

### Step 3: Identify the corresponding jar in the product pack

JAR files live in:
```
wso2am-<version>/repository/components/plugins/
```
The naming convention differs between source and pack:
- **Source artifact**: `org.wso2.carbon.apimgt.gateway-9.33.65-SNAPSHOT.jar` (hyphens, `-SNAPSHOT`)
- **Pack plugin**: `org.wso2.carbon.apimgt.gateway_9.33.65.jar` (underscore before version, no `-SNAPSHOT`)

### Step 3: Create a patch directory and copy the jar

1. Create the patch directory:
   ```
   mkdir -p wso2am-<version>/repository/components/patches/patch9999/
   ```
2. Copy the built jar into the patch directory, **renaming it to match the pack's naming convention**:
   - Replace the hyphen before the version number with an underscore (`-9.33.65` -> `_9.33.65`)
   - Remove `-SNAPSHOT` from the version
   - The version **must match** the version of the existing jar in the plugins folder

   Example:
   ```
   cp target/org.wso2.carbon.apimgt.impl-9.33.65-SNAPSHOT.jar \
      wso2am-<version>/repository/components/patches/patch9999/org.wso2.carbon.apimgt.impl_9.33.65.jar
   ```

### Step 4: Fresh start with patches

**ALWAYS start from a fresh pack.** Do NOT try to restart a running server in-place. Kill the old server, delete the extracted pack, re-extract, apply patches, and start fresh.

```bash
# 1. Kill ALL running WSO2 server processes (not just the one from the PID file)
# The PID file may be stale or missing — always check for actual java processes too.
for PID in $(cat wso2am-*/wso2carbon.pid 2>/dev/null; ps aux | grep 'org.wso2.carbon.bootstrap.Bootstrap' | grep -v grep | awk '{print $2}'); do
  if kill -0 "$PID" 2>/dev/null; then
    echo "Killing WSO2 server process $PID..."
    kill "$PID" 2>/dev/null
    while kill -0 "$PID" 2>/dev/null; do sleep 2; done
  fi
done
# Verify critical ports are free (9443+offset, 9763+offset, 8280+offset, 8243+offset, 5672)
for PORT in 9443 9763 8280 8243 5672; do
  PORT_PID=$(lsof -ti :$PORT 2>/dev/null)
  if [ -n "$PORT_PID" ]; then
    echo "WARNING: Port $PORT still in use by PID $PORT_PID — killing it."
    kill "$PORT_PID" 2>/dev/null
    sleep 2
  fi
done
echo "All servers stopped and ports free."

# 2. Delete old extracted pack and re-extract
rm -rf wso2am-<version>
unzip -q wso2am-<version>.zip

# 3. Re-apply port offset if needed (check with: lsof -i :9443)
# Edit wso2am-<version>/repository/conf/deployment.toml BEFORE first start

# 4. Apply JAR patches
mkdir -p wso2am-<version>/repository/components/patches/patch9999/
cp target/<module>_<version>.jar wso2am-<version>/repository/components/patches/patch9999/

# 5. Apply WAR patches (if any REST API changes)
# cp target/<war-file>.war wso2am-<version>/repository/deployment/server/webapps/

# 6. Start from the bin directory (you MUST cd into bin/)
cd wso2am-<version>/bin && sh api-manager.sh &

# 7. Poll the log for startup (up to 3 minutes), with failure detection
LOG_FILE="wso2am-<version>/repository/logs/wso2carbon.log"
SERVER_PID=$!
for i in $(seq 1 36); do
  # Check if server process is still alive
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: Server process died. Check log for errors:"
    grep -i "BindException\|Address already in use\|Shutdown complete\|Halting JVM\|FATAL\|Could not bind" "$LOG_FILE" | tail -5
    exit 1
  fi
  # Check for successful startup
  if grep -q "Mgt Console URL" "$LOG_FILE" 2>/dev/null; then
    echo "Server started!"
    grep "Mgt Console URL" "$LOG_FILE"
    break
  fi
  # Check for known fatal errors in the log (server may still be shutting down)
  if grep -q "Halting JVM\|Shutdown complete" "$LOG_FILE" 2>/dev/null; then
    echo "ERROR: Server failed to start. Check log for errors:"
    grep -i "BindException\|Address already in use\|Could not bind\|FATAL\|Exception" "$LOG_FILE" | tail -10
    exit 1
  fi
  sleep 5
done
```

**Rules:**
- NEVER try to restart a running server — always kill, delete, re-extract, patch, and start fresh.
- NEVER redirect server output to `/dev/null` — let it write to the log file naturally.
- NEVER count occurrences of "WSO2 Carbon started" — just grep a fresh log for `"Mgt Console URL"`.
- ALWAYS check if the server process is still alive during polling — if it died, check the log for errors and exit immediately. Common failures: `Address already in use`, `BindException`, `Could not bind`.
- If a port conflict is detected, find what's using the port (`lsof -i :<port>`) and either kill it or increase the port offset.
- **IMPORTANT: The start command (step 6) and the poll loop (step 7) MUST be in the SAME Bash tool call.** If you split them into separate Bash calls, `$!` won't capture the server PID. Also set `timeout: 200000` on the Bash tool call so it doesn't time out before the server starts.
- **NEVER poll for startup in a separate Bash call from the start command.** The server start and the polling loop must always be a single Bash invocation.

### For WAR files (REST API changes)

If changes are in a REST API module (e.g., `org.wso2.carbon.apimgt.rest.api.publisher.v1`), the built war file goes to:
```
wso2am-<version>/repository/deployment/server/webapps/
```
Include the WAR copy in step 5 above when starting from a fresh pack.
