# Fetching Specs & Documentation

Use GitHub raw URLs. The docs website (is.docs.wso2.com) returns 403.

```bash
# OpenAPI specs
RAW="https://raw.githubusercontent.com/wso2/docs-is/master/en/identity-server/next/docs/apis/restapis"
curl -sL "$RAW/<spec-file>.yaml"

# Org-scoped API specs
ORG_RAW="https://raw.githubusercontent.com/wso2/docs-is/master/en/identity-server/next/docs/apis/organization-apis/restapis"

# Guides (markdown)
GUIDE_RAW="https://raw.githubusercontent.com/wso2/docs-is/master/en/identity-server/next/docs/guides"
# Categories: authentication/, users/, organization-management/, applications/, authorization/, branding/

# Blog posts (deep dives, tutorials)
https://github.com/wso2/iam-blogs

# Source code search (use ref/component-repos.md to find repo)
gh search code "className" --repo wso2-extensions/<repo-name>
## or
gh search code "className" --repo wso2/<repo-name>
```

**Search order:** OpenAPI spec > Guides > Source code > Blog posts > Running IS (last resort)
