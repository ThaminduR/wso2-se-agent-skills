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

## Interacting with the Product via REST APIs

### Authentication

- **For Publisher, DevPortal, and Admin REST APIs**, use Basic auth with admin credentials. It's simpler and doesn't expire:
  ```
  -H "Authorization: Basic YWRtaW46YWRtaW4="
  ```
  (`YWRtaW46YWRtaW4=` is base64 for `admin:admin`)

- **For Gateway invocation** (calling deployed APIs), you need an OAuth token from a subscribed application. Create an application, subscribe it to the API, generate keys, and use the resulting token.

### API Lifecycle Flow

The standard flow to create, deploy, and invoke an API via REST APIs:

1. **Create API**: `POST /api/am/publisher/v4/apis`
2. **Publish API**: `POST /api/am/publisher/v4/apis/change-lifecycle?apiId={id}&action=Publish`
3. **Create Revision**: `POST /api/am/publisher/v4/apis/{id}/revisions`
4. **Deploy Revision**: `POST /api/am/publisher/v4/apis/{id}/deploy-revision?revisionId={revId}` with body `[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]`
5. **Create Application**: `POST /api/am/devportal/v3/applications`
6. **Subscribe**: `POST /api/am/devportal/v3/subscriptions`
7. **Generate Keys**: `POST /api/am/devportal/v3/applications/{appId}/generate-keys`
8. **Get Token**: `POST /oauth2/token` with client credentials
9. **Invoke**: Call the gateway endpoint (`https://localhost:8243/{context}/{version}/...`) with `Authorization: Bearer {token}`

For API Products, the flow is the same but use `/api/am/publisher/v4/api-products` endpoints.

### REST API Reference

- **Postman collections** with complete example payloads: `docs-apim/en/docs/assets/attachments/reference/` (quick-start, publisher-v4.4, devportal-v3.4, admin-v4.4)
- **OpenAPI specs**: `docs-apim/en/docs/reference/product-apis/publisher-apis/publisher-v4/publisher-v4.yaml`
- **Product documentation**: `docs-apim/en/docs/` (covers API creation, AI APIs, API Products, subscriptions, etc.)

## Interacting with the Frontend (Playwright)

For any task that requires interacting with the product's web UI (reproducing frontend bugs, verifying frontend fixes, testing UI behavior), use **Playwright** to automate browser interactions. Do NOT rely on code analysis or curl alone for frontend issues — you must actually drive the browser.

### Setup

If Playwright browsers are not installed, run this first:
```bash
npx playwright install chromium
```

### Writing a Playwright Script

Write standalone Node.js scripts (`.mjs` files) that automate the browser interaction:

```javascript
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

try {
    // Login to admin portal (example)
    await page.goto('https://localhost:9443/admin');
    // ... wait for redirects, fill login form, etc.

    // Perform steps
    await page.screenshot({ path: '.ai/screenshots/step-1.png' });

    // Assert behavior
    const element = await page.locator('selector');
    const isVisible = await element.isVisible();
    console.log('Element visible:', isVisible);

    await page.screenshot({ path: '.ai/screenshots/step-2.png' });
} finally {
    await browser.close();
}
```

### Important Rules

- **Always use `headless: true`** — there is no display available.
- **Always set `ignoreHTTPSErrors: true`** — the product uses self-signed certificates.
- **Save screenshots** to `.ai/screenshots/` (create the directory with `mkdir -p .ai/screenshots` first). Take screenshots at each key step — they serve as evidence for reproduction and verification.
- **Login handling:** The portals (admin, publisher, devportal) redirect to an SSO login page. After `page.goto(portalUrl)`, wait for the login form, fill in `admin`/`admin`, and submit. Then wait for the redirect back to the portal.

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
# 1. Stop ALL running WSO2 server instances
# Step A: Use the built-in --stop command (graceful shutdown via PID file)
for PACK_DIR in wso2am-*/; do
  if [ -f "$PACK_DIR/wso2carbon.pid" ]; then
    echo "Stopping server in $PACK_DIR using --stop..."
    cd "$PACK_DIR/bin" && sh api-manager.sh --stop 2>/dev/null; cd - > /dev/null
  fi
done

# Step B: Wait for the process to actually die (--stop sends SIGTERM but doesn't wait)
for PID in $(cat wso2am-*/wso2carbon.pid 2>/dev/null); do
  if kill -0 "$PID" 2>/dev/null; then
    echo "Waiting for PID $PID to exit..."
    WAIT=0
    while kill -0 "$PID" 2>/dev/null && [ $WAIT -lt 30 ]; do
      sleep 2; WAIT=$((WAIT+2))
    done
    # Force kill if still alive after 30s
    if kill -0 "$PID" 2>/dev/null; then
      echo "Force killing PID $PID..."
      kill -9 "$PID" 2>/dev/null
    fi
  fi
done

# Step C: Catch any orphaned WSO2 java processes (stale PID file, missing PID file, etc.)
for PID in $(ps aux | grep 'org.wso2.carbon.bootstrap.Bootstrap' | grep -v grep | awk '{print $2}'); do
  echo "Killing orphaned WSO2 process $PID..."
  kill "$PID" 2>/dev/null
  sleep 3
  kill -9 "$PID" 2>/dev/null 2>&1
done

# Step D: Verify critical ports are free (accounting for port offset)
# Read offset from any existing pack's deployment.toml, default to 0
OFFSET=0
for TOML in wso2am-*/repository/conf/deployment.toml; do
  if [ -f "$TOML" ]; then
    FOUND_OFFSET=$(grep -A1 '^\[server\]' "$TOML" | grep 'offset' | grep -oE '[0-9]+')
    if [ -n "$FOUND_OFFSET" ]; then OFFSET=$FOUND_OFFSET; fi
    break
  fi
done
echo "Using port offset: $OFFSET"
for BASE_PORT in 9443 9763 8280 8243 5672; do
  PORT=$((BASE_PORT + OFFSET))
  PORT_PID=$(lsof -ti :$PORT 2>/dev/null)
  if [ -n "$PORT_PID" ]; then
    echo "WARNING: Port $PORT still in use by PID $PORT_PID — force killing."
    kill -9 "$PORT_PID" 2>/dev/null
    sleep 1
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

### For WAR files (REST API changes)

If changes are in a REST API module (e.g., `org.wso2.carbon.apimgt.rest.api.publisher.v1`), the built war file goes to:
```
wso2am-<version>/repository/deployment/server/webapps/
```
Include the WAR copy in step 5 above when starting from a fresh pack.

## Troubleshooting / Log Analysis

### Checking Server Logs for Errors

After deploying APIs, products, or patches, check the server log for errors before attempting invocation:

```
grep -i "error\|exception" wso2am-*/repository/logs/wso2carbon.log | grep -v "JMS\|Siddhi" | tail -10
```

**Noise filtering:** `JMS` and `Siddhi` errors are benign background noise in the default APIM configuration — exclude them from error checks.

If deployment errors are found (e.g., Velocity errors, template exceptions), investigate immediately — do not proceed to API invocation until the log is clean.

## Database-Specific Issue Reproduction

APIM supports multiple databases. SQL scripts are located at:
```
carbon-apimgt/features/apimgt/org.wso2.carbon.apimgt.core.feature/src/main/resources/sql/
```

### Databases with Docker support

| Database | Docker Image | arm64 (Apple Silicon) | amd64 (Linux/Intel) |
|----------|-------------|----------------------|---------------------|
| **H2** | Built into APIM (default) | Works | Works |
| **MySQL** | `mysql:8` | Works | Works |
| **PostgreSQL** | `postgres:16` | Works | Works |
| **MSSQL** | `mcr.microsoft.com/mssql/server:2022-latest` | Works | Works |
| **Oracle** | `gvenzl/oracle-xe` / `gvenzl/oracle-free` | No native image — emulation is slow/unreliable | Works |
| **DB2** | `ibmcom/db2` | No native image — emulation is slow/unreliable | Works |

**Check the "System Info" section at the bottom of this file** to determine which architecture you are on. If the architecture is `arm64`/`aarch64`, do NOT attempt to run Oracle or DB2 via Docker — it will waste time and likely fail.

### What to do when a database cannot be run locally

**If the issue is specific to a database you cannot run (e.g., Oracle on arm64), do NOT spend time on Docker emulation.** Instead:

1. **Analyze the SQL scripts in the source code** — compare the problematic query against the database-specific SQL file to identify syntax issues, type mismatches, or missing columns.
2. **Cross-reference with a database you CAN run** — if the issue is about a query, run it against MySQL or PostgreSQL to verify the logic, then analyze the Oracle/DB2-specific SQL for differences.
3. **Clearly state in your analysis** that the issue requires a specific database environment that cannot be reproduced locally. For example:
   > **Human intervention required:** This issue is specific to Oracle 19c and cannot be reproduced locally (Oracle Docker images are not available for this architecture). Based on code analysis of `oracle.sql`, the root cause appears to be [explanation]. A fix has been proposed based on code analysis, but it should be verified against a real Oracle 19c instance before merging.
4. **Still propose a fix** based on code analysis — but mark it as requiring human verification on the target database.
