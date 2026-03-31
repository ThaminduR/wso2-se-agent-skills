# WSO2 API Manager Workspace

## Prerequisites Check
```bash
java -version    # Requires JDK 21 (build and runtime)
mvn -version     # Requires Maven 3.x.x
node -v          # Requires Node.js 22.x+
npm -v           # Requires npm 10.x+
```


## Fix apim-apps lock files (needed on fresh clone)
Run `npm install` in each portal before Maven build, otherwise `npm ci` fails with lock file sync errors.
```bash
cd apim-apps/portals/publisher/src/main/webapp && npm install && cd -
cd apim-apps/portals/devportal/src/main/webapp && npm install && cd -
cd apim-apps/portals/admin/src/main/webapp && npm install && cd -
```

## Build Order
1. `cd carbon-apimgt && mvn clean install -DskipTests`  (~9 min)
2. `cd apim-apps && mvn clean install -DskipTests`  (~7 min)
3. `cd product-apim && mvn clean install -DskipTests`  (~15-25 min)

Built pack: `product-apim/all-in-one-apim/modules/distribution/product/target/wso2am-4.7.0-SNAPSHOT.zip`

## Fast product-apim Build (for local testing / reproducing issues)
IMPORTANT: For local testing, only the all-in-one profile is needed. Build from inside the `all-in-one-apim` directory. You MUST use both `-DskipTests` and `-Dmaven.test.skip=true` — `-DskipTests` alone does NOT prevent integration test modules from starting a full APIM instance:
```bash
cd product-apim/all-in-one-apim && mvn clean install -DskipTests -Dmaven.test.skip=true
```
This builds only the all-in-one distribution (~3 min). Use the full `product-apim` root build only when you need gateway/traffic-manager/api-control-plane profiles.

## Build with Local Dependencies
By default product-apim uses released versions, not local builds. To use locally built carbon-apimgt and apim-apps:

1. Get SNAPSHOT versions from local repos:
   - `carbon-apimgt/pom.xml` → `<version>` (e.g. 9.33.79-SNAPSHOT)
   - `apim-apps/pom.xml` → `<version>` (e.g. 9.3.159-SNAPSHOT)

2. Update these properties in **all 4** product-apim pom files:
   - `product-apim/all-in-one-apim/pom.xml`
   - `product-apim/gateway/pom.xml`
   - `product-apim/api-control-plane/pom.xml`
   - `product-apim/traffic-manager/pom.xml`

   Replace:
   - `<carbon.apimgt.version>X.X.X</carbon.apimgt.version>` → SNAPSHOT version from carbon-apimgt
   - `<carbon.apimgt.ui.version>X.X.X</carbon.apimgt.ui.version>` → SNAPSHOT version from apim-apps

3. Then rebuild product-apim

## Gotchas
- NEVER run concurrent builds of product-apim — P2 profile generation corrupts and fails
- README says JDK 11 but carbon.kernel 4.11.8 deps are compiled with Java 21, so JDK 21 is required
- All mvn commands must be prefixed with `export JAVA_HOME=...` in each shell invocation
