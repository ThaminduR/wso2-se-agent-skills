# OAuth & Auth Testing Recipes

## Quick: Basic Auth

```bash
AUTH="Authorization: Basic YWRtaW46YWRtaW4="
curl -sk -H "$AUTH" "https://localhost:9443/scim2/Users"
```

Basic auth does NOT work for: `/o/` APIs.

## OAuth Flow (when Basic auth isn't enough)

1. **Create app:** `POST /api/server/v1/applications` with `grantTypes: ["client_credentials", "organization_switch"]`
2. **Get credentials:** `GET /api/server/v1/applications/$APP_ID/inbound-protocols/oidc` → `clientId`, `clientSecret`
3. **Discover scopes:** `GET /api/server/v1/api-resources?filter=name+co+KEYWORD` → get resource ID → `GET /api/server/v1/api-resources/<id>` → use exact scope names
4. **Authorize scopes:** `POST /api/server/v1/applications/$APP_ID/authorized-apis` with `policyIdentifier: "RBAC"` (only valid policy for system APIs)
5. **Get token:** `POST /oauth2/token` with `grant_type=client_credentials&scope=SCOPE1 SCOPE2`

## Organization Switch Token

Prerequisites: app has `organization_switch` grant + app shared with sub-org.

1. Share app: `POST /api/server/v1/applications/$APP_ID/share` with `sharedOrganizations: ["<SUB_ORG_ID>"]`
2. Get parent token via `client_credentials` with the scopes you need in the sub-org
3. Switch: `POST /oauth2/token` with `grant_type=organization_switch&token=$PARENT_TOKEN&switching_organization=<SUB_ORG_ID>&scope=<internal_org_scopes>` (scope param is required — omitting it yields a token with zero scopes)
4. Use with `/o/` APIs: `Authorization: Bearer $ORG_TOKEN`

## Managing Sub-Org Resources

Basic auth does NOT work for `/o/` APIs. You need an org-switch token from a properly configured app.

**Scope mapping matters.** API resources come in pairs — org-management scopes (`internal_org_*`, `console:org:*`) and direct scopes (`internal_*`, `console:*`). When you org-switch:
- Request `internal_org_*` scopes on the **parent** token (`client_credentials`)
- These map to `internal_*` scopes in the **switched** token
- If you authorize the wrong set, the switched token gets zero scopes

**Full setup:**

```bash
AUTH="Authorization: Basic YWRtaW46YWRtaW4="
BASE="https://localhost:9443"

# 1. Create app
APP_ID=$(curl -sk -X POST "$BASE/api/server/v1/applications" -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"name":"SubOrgMgmt","inboundProtocolConfiguration":{"oidc":{"grantTypes":["client_credentials","organization_switch"],"callbackURLs":["https://localhost/callback"]}}}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# 2. Get credentials
OIDC=$(curl -sk "$BASE/api/server/v1/applications/$APP_ID/inbound-protocols/oidc" -H "$AUTH")
CLIENT_ID=$(echo "$OIDC" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])")
CLIENT_SECRET=$(echo "$OIDC" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")

# 3. Discover org-management API resources (the ones with internal_org_* scopes)
#    Search by keyword, then pick the resource that has internal_org_* scopes
curl -sk "$BASE/api/server/v1/api-resources?filter=name+co+SCIM2+Users" -H "$AUTH"
#    -> find the resource ID whose scopes start with internal_org_

# 4. Authorize the org-management scoped APIs on the app
curl -sk -X POST "$BASE/api/server/v1/applications/$APP_ID/authorized-apis" -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"id":"<api-resource-id>","policyIdentifier":"RBAC","scopes":["internal_org_user_mgt_create","internal_org_user_mgt_view"]}'

# 5. Share app with sub-org
curl -sk -X POST "$BASE/api/server/v1/applications/$APP_ID/share" -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"shareWithAllChildren": true}'

# 6. Get parent token with org-management scopes
PARENT_TOKEN=$(curl -sk -X POST "$BASE/oauth2/token" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=internal_org_user_mgt_create internal_org_user_mgt_view" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 7. Org-switch (MUST pass scope explicitly or token gets zero scopes)
ORG_TOKEN=$(curl -sk -X POST "$BASE/oauth2/token" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d "grant_type=organization_switch&token=$PARENT_TOKEN&switching_organization=$SUB_ORG_ID&scope=internal_org_user_mgt_create internal_org_user_mgt_view" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 8. Use on /o/ APIs
curl -sk -H "Authorization: Bearer $ORG_TOKEN" "$BASE/o/scim2/Users"
```

**Key `/o/` API paths:**
- `/o/scim2/Users` — SCIM2 user management
- `/o/api/server/v1/applications` — list/manage apps
- `/o/api/server/v1/branding-preference` — branding
- `/o/api/server/v1/email/template-types/{typeId}/templates/{locale}` — email templates

## Gotchas

- **Org-switch token gets zero scopes**: You MUST pass `&scope=internal_org_...` explicitly in the `organization_switch` token request. Without it, the switched token is issued with no scopes even though the parent token carries them. Example:
  ```
  grant_type=organization_switch&token=$PARENT_TOKEN&switching_organization=$SUB_ORG_ID&scope=internal_org_application_mgt_create internal_org_application_mgt_view
  ```
  The scopes in the switch request should be `internal_org_*` (not `internal_*`). Confirmed on IS 7.3.0.
- **App role required for org-switch scopes (RBAC)**: In IS 7.x, the shared app in the sub-org needs an application-audience role with the relevant permissions. Create the role via `POST /scim2/v2/Roles` with `audience.type: "application"` and `audience.value: "<APP_ID>"`. The role auto-propagates to sub-orgs when the app is shared. Without this, even explicit scope requests may fail.
- `password` grant ignores `internal_*` scopes — use `client_credentials`
- `No Policy` rejected for system APIs — must use `RBAC`
- `clientId` required in OIDC PUT body or you get "Invalid ClientID"
- IS may return cached tokens — revoke first if you need fresh scopes
- v1 scopes (e.g. `internal_user_share`) differ from v2 (e.g. `internal_org_user_share`) — always discover
