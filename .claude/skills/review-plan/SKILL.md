---
name: review-plan
description: Independently validate the implementation plan before code is written. Acts as a quality gate.
user-invocable: true
---

# /review-plan — Plan Review & Validation

You are an AI assistant performing an independent review of an implementation plan before any code is written. Follow the procedure below precisely.

## Step 0: Load Context

1. The workspace may contain multiple repositories, each with its own `agents.md` at its root. Identify the relevant repository and read its `agents.md`. If it doesn't exist, stop and tell the developer to create one (point them to `agents.md.template`).
2. Read `.ai/implementation-plan.md`. If it doesn't exist, tell the developer to run `/plan-fix` first.
3. Read `.ai/issue-analysis.md`. If it doesn't exist, tell the developer to run `/reproduce` first.
4. Verify `implementation-plan.md` has **no unresolved open questions**. If it does, stop and tell the developer to resolve them first.

## Step 1: Completeness Check

- Does the plan actually address the root cause from `issue-analysis.md`?
- Is there a logical chain from root cause → code change → fix?
- Are there any gaps in reasoning?

## Step 2: Approach Review

- Are the correct modules being modified?
- Are changes minimal and scoped?
- Does the approach follow existing codebase patterns? (Verify against `agents.md > Architecture`)
- Are there simpler alternatives that were overlooked?

## Step 3: Test Coverage Review

Does the test plan cover:
- The exact bug scenario
- Edge cases
- Boundary conditions
- Negative inputs
- Regression paths

Are both unit and integration tests planned where appropriate?

## Step 4: Security Review

Does the fix touch any of the following? If yes, flag for additional human review:
- Input validation
- Authentication / Authorization
- Session handling
- Data serialization
- Cryptography

Check for injection risks, privilege escalation, and data exposure.

## Step 5: Regression Risk Assessment

- Which existing features could break?
- Is the existing test suite for affected components being run?
- Are there implicit dependencies that might not be caught by tests?

## Step 6: Breaking Change Review

- If breaking changes are declared, is the migration path clear?
- If none are declared, verify this is actually true by inspecting the plan details.

## Step 7: Write the Output Artifact

Write the review to `.ai/plan-review-report.md` using this exact format:

```markdown
# Plan Review Report — [Issue #ID]: [Issue Title]

## Verdict: ✅ Approved / ⚠️ Revisions Required

## Implementation Plan Assessment
- **Completeness:** [Does it fully address the root cause?]
- **Correctness:** [Is the proposed logic sound?]
- **Approach:** [Appropriate scope? Follows conventions?]

## Test Coverage Evaluation
- **Bug scenario covered:** Yes / No
- **Edge cases covered:** Yes / No — [gaps identified]
- **Negative tests included:** Yes / No
- **Regression tests planned:** Yes / No

## Security Findings
- **Risk level:** None / Low / Medium / High
- **Details:** [specific findings, if any]
- **Recommendation:** [proceed / require security review]

## Regression Risk
- **Risk level:** Low / Medium / High
- **Affected features:** [list]
- **Mitigation:** [what tests/checks cover this]

## Required Revisions (if any)
1. [Specific, actionable revision with rationale]
2. ...

## Notes for Implementation
[Any additional guidance for the /implement phase]
```

## Important Rules

- **Be critical but constructive.** The purpose is to catch issues before code is written.
- **Never guess.** If you cannot determine something from the available artifacts and code, flag it.
- After writing the artifact, inform the developer of the verdict:
  - If **"Revisions Required"**: tell the developer to send the report back to `/plan-fix` for a revised plan.
  - If **"Approved"**: tell the developer they can proceed to `/implement`.
