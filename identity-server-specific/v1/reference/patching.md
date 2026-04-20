# Patching IS with JARs

Auto-discover changed modules via git diff in each repo, build if needed, patch IS.

1. **Discover:** Find git repos in working folder → `git diff --name-only` → map changed files to Maven modules (`pom.xml` → `<artifactId>`) → find/build JARs in `target/`. Confirm with user.
2. **Version check:** Verify the source repo is checked out to the tag matching the pack's JAR version. If not:
   - Find existing JAR version in pack: `ls <IS_HOME>/repository/components | grep <module-name>`
   - Find matching tag: `git tag | grep "7.5.22"` → `v7.5.22`. Fetch if not present.
   - Checkout and branch: `git checkout v7.5.22 -b fix/issue-<number>`
   - Apply changes on this branch, then build. **The built JAR version MUST match the pack version.** If they differ, the wrong tag was checked out.
3. **Patch IS**:
   a. **Patch plugins** — use `patches/patch9999/` directory. Do NOT replace JARs in `plugins/` directly.
      ```
      mkdir -p <IS_HOME>/repository/components/patches/patch9999/
      ```
      Copy built JAR into patch dir,
      - Version **must match** the existing JAR in plugins

   b. **Lib/dropin JARs** — replace directly, no rename.
   c. **J2 Template changes** — apply to `<IS_HOME>/repository/resources/conf/templates` or other relevant dirs.
   d. **WAR files** — build as WAR, patch into `<IS_HOME>/repository/deployment/server/webapps/`, and restart server
