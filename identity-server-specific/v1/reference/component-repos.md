# Component-to-Repository Mapping

## Core

| Area | Repository | POM Property |
|---|---|---|
| Identity Framework | `wso2/carbon-identity-framework` | `carbon.identity.framework.version` |
| Server REST APIs | `wso2/identity-api-server` | `identity.server.api.version` |
| User REST APIs | `wso2/identity-api-user` | `identity.user.api.version` |
| Console & My Account | `wso2/identity-apps` | `identity.apps.console.version` |
| Product assembly + integration tests | `wso2/product-is` | — |

## Auth Protocols

| Area | Repository |
|---|---|
| OAuth2/OIDC | `wso2-extensions/identity-inbound-auth-oauth` |
| SAML SSO | `wso2-extensions/identity-inbound-auth-saml` |
| Org Switch Grant | `wso2-extensions/identity-oauth2-grant-organization-switch` |
| SCIM 2.0 | `wso2-extensions/identity-inbound-provisioning-scim2` |
| Charon (SCIM lib) | `wso2/charon` |

## Local Authenticators

BasicAuth → `identity-local-auth-basicauth` | FIDO2 → `identity-local-auth-fido` | Email OTP → `identity-local-auth-emailotp` | SMS OTP → `identity-local-auth-smsotp` | TOTP → `identity-outbound-auth-totp` | Magic Link → `identity-local-auth-magiclink`

All under `wso2-extensions/`.

## Federated Authenticators

OIDC → `identity-outbound-auth-oidc` | Google → `identity-outbound-auth-google` | Facebook → `identity-outbound-auth-facebook` | Apple → `identity-outbound-auth-apple` | GitHub → `identity-outbound-auth-github` | Microsoft → `identity-outbound-auth-office365`

## Other

| Area | Repository |
|---|---|
| Organization Management | `wso2-extensions/identity-organization-management` |
| Governance (recovery, self-signup, password policy) | `wso2-extensions/identity-governance` |
| Webhook Event Handlers | `wso2-extensions/identity-webhook-event-handlers` |
| Conditional Auth Functions | `wso2-extensions/identity-conditional-auth-functions` |
| Branding Preference | `wso2-extensions/identity-branding-preference-management` |
| Email/SMS Notifications | `wso2-extensions/identity-event-handler-notification` |
