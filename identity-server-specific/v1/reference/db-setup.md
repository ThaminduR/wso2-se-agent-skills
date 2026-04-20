# Database Setup

| Database | TOML Key | Scripts |
|---|---|---|
| Identity DB | `[database.identity_db]` | `dbscripts/identity/<db>.sql` then `dbscripts/consent/<db>.sql` |
| Shared DB | `[database.shared_db]` | `dbscripts/<db>.sql` |
| Agent Identity DB | `[datasource.AgentIdentity]` | `dbscripts/identity/agent/<db>.sql` (optional) |

**Critical gotchas:**
- Use `&amp;` not `&` in TOML JDBC URLs (value gets templated into XML)
- MySQL: tables use `latin1` charset intentionally
- JDBC driver not bundled — download and copy to `repository/components/lib/`
- Config changes apply on next restart

Stored procedures for cleanup jobs: `dbscripts/identity/stored-procedures/<db>/`
