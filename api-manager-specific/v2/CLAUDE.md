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
# 1. Kill any running server
PID=$(cat wso2am-<version>/wso2carbon.pid 2>/dev/null || ps aux | grep 'wso2carbon' | grep -v grep | awk '{print $2}')
if [ -n "$PID" ]; then
  kill "$PID" 2>/dev/null
  while kill -0 "$PID" 2>/dev/null; do sleep 2; done
  echo "Server stopped."
fi

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

# 7. Poll the log for startup (up to 3 minutes)
LOG_FILE="wso2am-<version>/repository/logs/wso2carbon.log"
for i in $(seq 1 36); do
  if grep -q "Mgt Console URL" "$LOG_FILE" 2>/dev/null; then
    echo "Server started!"
    grep "Mgt Console URL" "$LOG_FILE"
    break
  fi
  sleep 5
done
```

**Rules:**
- NEVER try to restart a running server — always kill, delete, re-extract, patch, and start fresh.
- NEVER redirect server output to `/dev/null` — let it write to the log file naturally.
- NEVER count occurrences of "WSO2 Carbon started" — just grep a fresh log for `"Mgt Console URL"`.
- If the loop finishes without finding the line, check `tail -30 "$LOG_FILE"` for errors.

### For WAR files (REST API changes)

If changes are in a REST API module (e.g., `org.wso2.carbon.apimgt.rest.api.publisher.v1`), the built war file goes to:
```
wso2am-<version>/repository/deployment/server/webapps/
```
Include the WAR copy in step 5 above when starting from a fresh pack.
