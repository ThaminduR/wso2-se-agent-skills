---
name: verify-fix
description: Verify whether a GitHub issue is fixed in the local codebase. User provides a GitHub issue URL, the skill fetches it, extracts reproduction steps, builds the product from source, runs the reproduction steps, and reports whether the issue still exists or not.
argument-hint: "[GitHub Issue URL or ID]"
---

# /verify-fix — Bug Fix Verification through Reproduction

## Steps

1. Fetch the issue
2. Build the product
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
