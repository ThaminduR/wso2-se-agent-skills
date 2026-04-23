---
name: verify-fix
description: Verify whether a GitHub issue is fixed in the local codebase. User provides a GitHub issue URL, the skill fetches it, extracts reproduction steps, builds the product from source, runs the reproduction steps, and reports whether the issue still exists or not.
argument-hint: "[GitHub Issue URL or ID]"
---

# /verify-fix — Bug Fix Verification through Reproduction

**Hard rule: verification must be done against an actual running instance of the product, with the fix deployed.** Re-running the original reproduction steps against a real, started server is the only thing that counts. Unit tests of the patched method, test-harness simulations, in-memory mocks, dry runs, code-diff inspection, and "the build succeeded" are NOT verification — they only show the code compiles or behaves a certain way in isolation, not that the bug is gone in the running product.

## Steps

1. **Fetch the issue** — get the issue details and understand the expected behavior.

2. **Check the fix artifacts** — Read `.ai/plan-<issue_number>.md` (from `/plan`) and `.ai/fix-<issue_number>.md` (from `/fix`) if they exist. Together they tell you:
   - The intended change and the "Dev Test Plan" to run (from the plan artifact)
   - Whether the dev test passed or failed during `/fix`
   - What changes were made and in which files
   - Any known issues, limitations, or deviations from the plan
   If the dev test status is FAILED, pay special attention to the "Known Issues" and "Deviations From Plan" sections — the fix may be incomplete.

3. **Build and deploy the fix on a real server** — Build the changed module(s), apply patches per CLAUDE.md, start the product/server, and confirm it reached the documented readiness signal. The reproduction in step 4 must run against THIS started instance — not a unit-test runner, not a mock, not an embedded harness. If the server fails to start with the patch applied, stop and report; the fix is not verified.

4. **Verify at runtime against the running server** — Re-run the reproduction from `.ai/ia-<issue_number>.md` (or the issue's reproduction steps) against the started server. The bug behavior must no longer occur, observed via the same channel that originally exhibited it (browser, HTTP request, log output).

   **For frontend bugs:** Use Playwright — follow the "Interacting with the Frontend (Playwright)" section in CLAUDE.md.
   - If a reproduction script exists from the reproduce step (`.ai/reproduce-<issue_number>.mjs`), run it — the bug behavior should no longer occur.
   - If no script exists, write one following the Playwright guidelines in CLAUDE.md.
   - Save verification screenshots to `.ai/screenshots-<issue_number>/verify/`.
   - The screenshots must show the **correct behavior** (e.g., an element that was hidden is now visible).

   **For backend bugs:** Use curl or REST API calls against the running server.
   - **After deploying APIs/products, immediately check the server log for errors** before attempting invocation — follow the "Troubleshooting / Log Analysis" section in CLAUDE.md for the exact command and filtering rules.
   - If deployment errors are found, report them immediately — do not proceed to invocation.
   - If deployment is clean, proceed with invocation and compare results.

   **What does NOT count as verification:**
   - ❌ "The compiled bundle contains the fix logic" — grepping minified JS is not verification
   - ❌ "The build succeeded" — a successful build only means the code compiles
   - ❌ "The admin portal loads (HTTP 200)" — this only means the server is running
   - ❌ "A unit/integration test of the patched method passes" — that exercises the code in isolation, not the bug in the running product
   - ❌ "The fix logic was simulated in a script / harness / REPL" — a simulation is not the running product
   - ❌ "The fix is correct by inspection of the diff" — code review is not runtime verification
   - ✅ Playwright screenshots showing the correct UI behavior after the fix, captured against the started server
   - ✅ curl response from the started server showing the correct HTTP status/body after the fix
   - ✅ Server logs from the started server showing no errors where there were errors before

5. **Report** — Create `.ai/verify-<issue_number>.md`:

```markdown
# Fix Verification Report

**Issue**: <url>
**Verdict**: FIXED | NOT FIXED
**Verification method**: Playwright / curl / server logs

## Reproduction Steps Executed
<what you did — must be runtime steps, not code analysis>

## Result
<what happened — describe observed runtime behavior>

## Evidence
<screenshots in .ai/screenshots-<issue_number>/verify/, curl output, or server log excerpts — MUST be from runtime>
```

## Important Rules

- **Server startup:** The start command and the log polling loop MUST be in the same Bash tool call with `timeout: 200000`. Do not split them into separate calls.
- **Playwright best practices:** Wait for elements rather than using fixed sleeps (`page.waitForSelector()`, `page.locator().waitFor()`). Log assertions clearly — print expected vs actual so the output is useful in artifacts.
