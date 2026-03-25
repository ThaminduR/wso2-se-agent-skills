---
name: implement
description: Execute the approved implementation plan — write the fix, write the tests, and verify everything works.
user-invocable: true
---

# /implement — Code Implementation

You are an AI assistant executing an approved implementation plan. You will write the fix, write tests, and verify everything works. Follow the procedure below precisely.

## Step 0: Load Context

1. The workspace may contain multiple repositories, each with its own `agents.md` at its root. Identify the relevant repository and read its `agents.md`. If it doesn't exist, stop and tell the developer to create one (point them to `agents.md.template`). Verify it contains **Deployment**, **Testing**, and **Coding Conventions** sections.
2. Read `.ai/implementation-plan.md`. If it doesn't exist, tell the developer to run `/plan-fix` first.
3. Read `.ai/issue-analysis.md`. If it doesn't exist, tell the developer to run `/reproduce` first.
4. If `.ai/plan-review-report.md` exists, read it and use any notes or guidance from it during implementation.

## Step 1: Apply Code Changes

Follow `implementation-plan.md > Implementation Steps` **exactly**.

Rules:
- Adhere to coding conventions from `agents.md > Coding Conventions`.
- Make **minimal changes** — do not refactor, rename, or reformat code outside the fix scope.
- Do not add debug logging or temporary code that won't be part of the final fix.

## Step 2: Write Tests

Implement **all** tests specified in the implementation plan's test plan section.

Rules:
- Follow test conventions from `agents.md > Testing`.
- Each test must have meaningful assertions (not just "no exception thrown").
- Tests must be isolated and have proper setup/teardown.
- Test names must clearly describe the scenario being tested.

## Step 3: Run Affected Test Suite

Execute existing tests for all affected components using commands from `agents.md > Testing > Running Tests`.

- **All tests must pass.**
- If tests fail, analyze the failure and fix the issue, then re-run.

## Step 4: Dev-Test the Fix

If the bug is reproducible by running the product:
1. Set up the product using `agents.md > Deployment`.
2. Reproduce the original bug using steps from `issue-analysis.md`.
3. Verify the bug is **fixed**.
4. Verify no obvious regressions in related features.

## Step 5: Iterate if Needed

If dev testing reveals issues:
1. Fix the issue.
2. Return to Step 3 (run tests again).
3. **Maximum 3 iterations.** After 3 failed attempts, stop and ask the developer for guidance.

## Step 6: Cleanup

- Stop any servers started.
- Ensure working tree contains **only intentional changes**.
- Remove any debug logging or temporary code.

## Step 7: Clarification Protocol

If implementation reveals that the plan is insufficient (e.g., an edge case not considered, an API that doesn't behave as expected), you **must stop and ask the developer** rather than improvise a solution.

## Step 8: Write the Output Report

Report the implementation results to the developer using this format:

```markdown
# Implementation Report — [Issue #ID]: [Issue Title]

## Changes Made
| File | Change Summary |
|------|---------------|
| path/to/file | [what was changed] |
| ... | ... |

## Tests Written
| Test | Type | Status |
|------|------|--------|
| testX | Unit | ✅ Pass |
| ... | ... | ... |

## Existing Test Suite Results
- **Suite:** [name] — ✅ All pass / ❌ [N] failures (details below)

## Dev Test Results
- **Bug reproduction before fix:** [confirmed reproducible]
- **Bug status after fix:** [resolved]
- **Related features tested:** [list with pass/fail]

## Deviations from Plan
- None / [describe what changed and why]
```

## Important Rules

- **Follow the plan.** Do not deviate from the approved implementation plan without asking the developer.
- **Minimal changes.** Do not refactor, clean up, or "improve" code outside the scope of the fix.
- **Never guess.** If the plan is ambiguous or insufficient, stop and ask.
- **All tests must pass** before the implementation is considered complete.
- After completion, inform the developer that they should review the changes and then proceed to `/code-review`.
