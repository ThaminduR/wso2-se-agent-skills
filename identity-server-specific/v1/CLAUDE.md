# WSO2 Identity Server — Agent Guide

## Rules

1. Use provided zip for testing. If none, clone & build `product-is` from master.
2. Clone component repos fresh into working dir (`ref/component-repos.md`). Never reuse clones.
3. Never guess request bodies or scopes — look up from OpenAPI specs and scope config files.
4. Default to Basic auth (`admin:admin` / `Basic YWRtaW46YWRtaW4=`). OAuth only for `/o/` APIs.
5. Before starting server, check for running instances. Poll log for `"WSO2 Carbon started"`. Check for startup errors.
6. Never read/edit outside working directory.

## Product Quick Reference

Port: **9443** (HTTPS) | Config: `<IS_HOME>/repository/conf/deployment.toml` | Logs: `<IS_HOME>/repository/logs/wso2carbon.log` | Start/Stop: `bash <IS_HOME>/bin/wso2server.sh start|stop` | DB scripts: `<IS_HOME>/dbscripts/` | JDBC drivers: `<IS_HOME>/repository/components/lib/` | DBs: H2 (default), MySQL, PostgreSQL, Oracle, MSSQL, DB2

### Config: deployment.toml → XML generation

**Never edit XML config files directly** — they are regenerated from `deployment.toml` via Jinja2 templates on every server start. Changes will be silently overwritten.

To find the correct `deployment.toml` property for an XML setting:
1. Find the Jinja2 template: `grep -r "the.xml.property.name" <IS_HOME>/repository/resources/conf/templates/`
2. The template placeholder (e.g. `{{output_adapter.email.enable_authentication}}`) maps directly to the TOML key path: `[output_adapter.email]` → `enable_authentication`

## Reference Files — Do NOT preload. Read only when the task requires it.

| File | Load when |
|---|---|
| `ref/docs-discovery.md` | Documentation, OpenAPI specs, guides, source code search |
| `ref/oauth-testing-recipes.md` | OAuth apps, tokens, org-switch, `/o/` APIs |
| `ref/db-setup.md` | External DB setup, DB errors, DDL scripts |
| `ref/component-repos.md` | Finding owning repo or POM version properties |
| `ref/console-ui-patterns.md` | Frontend bug reproduction/verification with Playwright |
| `ref/identity-apps-local-dev.md` | Running Console/My Account locally, identity-apps monorepo, changesets |
| `ref/patching.md` | Patching IS with built JARs from component repos, version matching, patch directory layout |
