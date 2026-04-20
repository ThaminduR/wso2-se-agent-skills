# Console UI — Playwright Automation

Use `npx playwright` with headless Chromium. Always set `ignoreHTTPSErrors: true` (self-signed cert).

## Login (two-step form — username and password on separate screens)

```javascript
await page.goto('https://localhost:9443/console', { waitUntil: 'networkidle' });
await page.fill('input[name="usernameUserInput"]', 'admin');
await page.click('button[type="submit"]');
await page.fill('input[name="password"]', 'admin');
await page.click('button[type="submit"]');
await page.waitForURL('**/console/**', { timeout: 15000 });
```

## Key URL patterns

- Root tenant: `/t/carbon.super/console/{users|organizations|applications|connections|getting-started}`
- Sub-org: `/t/carbon.super/o/<org-id>/console/{users|...}`

## Organization switching

**Preferred:** Direct URL navigation to `/t/carbon.super/o/<org-id>/console/...`
**Pitfall:** Clicking org name goes to details page, NOT org context. Must then click "Go to Organization". Else use switcher icon.

## Key selectors

Username: `input[name="usernameUserInput"]` | Password: `input[name="password"]` | Submit: `button[type="submit"]` | Table rows: `table tbody tr` | Confirm dialog: `[data-componentid="confirmation-modal-confirm-button"]`

The Console is a React SPA with `data-componentid` attributes. Use `page.screenshot()` when selectors don't match.
