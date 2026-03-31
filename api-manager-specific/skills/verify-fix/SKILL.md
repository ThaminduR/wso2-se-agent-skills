---
name: verify-fix
description: Verify whether a GitHub issue is fixed in the local codebase. User provides a GitHub issue URL, the skill fetches it, extracts reproduction steps, builds the product from source, runs the reproduction steps, and reports whether the issue still exists or not.
argument-hint: "[GitHub Issue URL or ID]"
---

# /verify-fix — Bug Fix Verification through Reproduction

## Steps

1. Fetch the issue
2. Build only the affected component(s):
   a. **Identify** which component(s) the fix touches (e.g., `carbon-apimgt`, `apim-apps`, or both) by inspecting the local code changes or the issue description.
   b. **Build only those component(s)** locally with `-DskipTests` (see CLAUDE.md "Build Order").
   c. **Update product-apim POM dependencies** to point to the locally built SNAPSHOT artifacts (see CLAUDE.md "Build with Local Dependencies"). Only update the properties for the component(s) you actually built.
   d. **Build only the all-in-one profile** using the fast build command (see CLAUDE.md "Fast product-apim Build") — do NOT build the full product-apim from root.
3. Reproduce
4. Report — Create `/.ai/fix-verification-report.md`:

```markdown
# Fix Verification Report

**Issue**: <url>
**Verdict**: ✅ FIXED | ❌ NOT FIXED

## Reproduction Steps Executed
<what you did>

## Result
<what happened>

## Evidence
<logs, errors, or output>
```
