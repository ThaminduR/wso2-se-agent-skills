# identity-apps Local Development

```bash
git clone https://github.com/wso2/identity-apps.git && cd identity-apps
corepack prepare pnpm@8.7.4 --activate && pnpm install
```

| App | Command | Port |
|---|---|---|
| Console | `cd apps/console && pnpm start` | 9001 |
| My Account | `cd apps/myaccount && pnpm start` | 9000 |

**IS-side config required:** Add dev origins to CORS and callback URLs in `deployment.toml`:
```toml
[cors]
allowed_origins = ["https://localhost:9000", "https://localhost:9001"]
supported_methods = ["GET","POST","HEAD","OPTIONS","PUT","PATCH","DELETE"]
exposed_headers = ["Location"]
```
Full `[console]` and `[myaccount]` callback URL regexps are in the [identity-apps repo docs](https://github.com/wso2/identity-apps).

**Monorepo:** `apps/` (React SPAs) | `features/` (80+ packages) | `modules/` (shared libs) | `identity-apps-core/` (JSP portals)

**Build:** `pnpm build` (full) | `pnpm build:apps` | `pnpm test` | `pnpm lint` | `pnpm typecheck`

**Fixing agent:** Clone → install → apply fix → `pnpm build` → confirm pass. No dev server needed.

**Verification agent — Console / My Account:** IS must be running + CORS configured → `pnpm start` → test in browser. The IS zip does NOT contain local changes, so dev mode is the only way to verify.

**Verification agent — JSP portals (login, recovery, etc.):** Build the WAR via `cd identity-apps-core && mvn clean install`, then deploy to `<IS_HOME>/repository/deployment/server/webapps/` and restart IS. Dev mode is not applicable for these — they must be patched into the running IS.

# identity-apps Changesets

Every identity-apps PR must include a changeset. Create manually (interactive `pnpm changeset` won't work for agents).

## Format

Create `.changeset/<short-kebab-description>.md`:

```markdown
---
"@wso2is/<package>": patch
---

One-line summary.
```

Bump types: `patch` (default/bug fix) | `minor` (new feature) | `major` (breaking).
