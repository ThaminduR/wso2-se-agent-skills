---
name: code-review
description: Automated code review of implemented changes before PR submission.
user-invocable: true
---

# /code-review — Pre-PR Code Review

You are an AI assistant performing an automated code review of the implemented bug fix before it is submitted as a pull request. Follow the procedure below precisely.

## Step 0: Load Context

1. The workspace may contain multiple repositories, each with its own `agents.md` at its root. Identify the relevant repository and read its `agents.md`. If it doesn't exist, stop and tell the developer to create one (point them to `agents.md.template`).
2. Read `.ai/implementation-plan.md` to understand what was planned.
3. Read `.ai/issue-analysis.md` to understand the original issue.
4. Get the full diff of all changes on the current branch vs. the base branch using `git diff`.
5. Verify all tests pass. If tests are failing, stop and tell the developer to fix them via `/implement` first.

## Step 1: Diff Analysis

Read the full diff. For every changed line, verify it maps back to the implementation plan.

- Flag any **unplanned changes** (changes not described in the implementation plan).
- Verify no files were modified that aren't listed in the plan's "Files to Modify" section (unless the deviation is documented).

## Step 2: Code Quality Check

Review for:
- **Naming consistency** — do new names follow existing conventions?
- **Error handling completeness** — are all error paths handled? Are exceptions caught at the right level?
- **Resource cleanup** — proper cleanup of resources (file handles, connections, memory), null/nil checks.
- **Logging appropriateness** — is logging at the right level? No sensitive data in logs?
- **Coding conventions** — adherence to `agents.md > Coding Conventions`.

## Step 3: Test Quality Check

Review test code for:
- **Meaningful assertions** — not just "no exception thrown".
- **Proper setup/teardown** — no test pollution.
- **Test isolation** — tests don't depend on execution order.
- **Clear naming** — test names describe the scenario being tested.
- **Coverage** — do the tests cover the bug scenario, edge cases, and negative cases as planned?

## Step 4: Security Scan

Check for:
- Hardcoded credentials or secrets
- SQL injection vulnerabilities
- Cross-site scripting (XSS)
- Improper input validation
- Insecure deserialization
- Overly permissive access controls
- Sensitive data exposure in logs or error messages

## Step 5: Performance Check

Flag any obvious performance concerns:
- N+1 queries
- Unbounded loops or recursion
- Missing pagination
- Large object allocation in hot paths
- Unnecessary synchronization

## Step 6: Documentation Check

- Are doc comments/inline comments updated where behavior changed?
- Are any public API changes reflected in documentation?
- Are new test methods documented with their purpose?

## Step 7: Write the Output Artifact

Write the review to `.ai/code-review-report.md` using this exact format:

```markdown
# Code Review Report — [Issue #ID]: [Issue Title]

## Verdict: ✅ Ready for PR / ⚠️ Changes Requested

## Summary
[One-paragraph assessment]

## Findings

### Critical (must fix before PR)
- [ ] [finding with file:line reference and suggestion]

### Recommended (should fix)
- [ ] [finding with file:line reference and suggestion]

### Informational (nice to have)
- [ ] [finding with file:line reference and suggestion]

## Checklist
- [ ] All changes map to the implementation plan
- [ ] Coding conventions followed
- [ ] Error handling is complete
- [ ] Tests are meaningful and isolated
- [ ] No security issues found
- [ ] No performance concerns
- [ ] Documentation updated where needed
```

## Important Rules

- **Be thorough but fair.** Only flag genuine issues, not style preferences that aren't in the coding conventions.
- **Critical findings block the PR.** Only use "Critical" for issues that would cause bugs, security vulnerabilities, or data loss.
- **Provide actionable suggestions.** Every finding should include a specific suggestion for how to fix it.
- After writing the artifact:
  - If verdict is **"Changes Requested"**: tell the developer to fix the critical issues and re-run `/code-review`.
  - If verdict is **"Ready for PR"**: tell the developer they can proceed to `/send-pr`.
