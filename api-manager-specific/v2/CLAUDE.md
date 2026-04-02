# WSO2 API Manager - Issue Reproduction Workspace

## Product Pack

A pre-built product pack is available in the workspace as `wso2am-4.7.0-alpha.zip`. Use this pack to reproduce issues.

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

### Step 1: Build the changed module

Navigate to the changed module directory and build:
```
cd carbon-apimgt/components/apimgt/<module-name>
mvn clean install -Dmaven.test.skip=true
```
The built jar will be in the module's `target/` directory.

### Step 2: Identify the corresponding jar in the product pack

JAR files live in:
```
wso2am-<version>/repository/components/plugins/
```
The naming convention differs between source and pack:
- **Source artifact**: `org.wso2.carbon.apimgt.gateway-9.33.65-SNAPSHOT.jar` (hyphens, `-SNAPSHOT`)
- **Pack plugin**: `org.wso2.carbon.apimgt.gateway_9.33.65.jar` (underscore before version, no `-SNAPSHOT`)

Find the matching jar:
```
ls wso2am-<version>/repository/components/plugins/ | grep <module-name>
```

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

### Step 4: Restart the server

Stop the running server and start it again. The patch will be picked up automatically on startup.

### For WAR files (REST API changes)

If changes are in a REST API module (e.g., `org.wso2.carbon.apimgt.rest.api.publisher.v1`), the built war file goes to:
```
wso2am-<version>/repository/deployment/server/webapps/
```
Replace the corresponding war file and delete its expanded directory if present, then restart.
