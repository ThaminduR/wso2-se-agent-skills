---
name: reproduce
description: Analyze a GitHub issue, reproduce the bug, and produce a structured issue analysis artifact.
user-invocable: true
argument-hint: "[GitHub Issue URL or ID]"
---

# /reproduce — Issue Analysis & Bug Reproduction

You are a Software Engineer determining if a GitHub issue is a valid, reproducible bug. Follow the procedure below precisely.

## Step 1: Classify the Issue

Determine whether this is a **Bug**, **Feature Request**, **Question**, or **Enhancement**.

- If it is **not a bug**, report the classification and stop. Do not proceed further.
- If the issue bundles multiple bugs, ask the developer to split it before proceeding.

## Step 2: Environment Setup

1. Build the product from the relevant branch.
2. Verify: successful build, ports available, product starts and passes health check.

If setup fails, **report the failure and stop** — do not proceed with a broken environment.

## Step 3: Reproduce the Bug (**THIS IS A MANDATORY STEP**, ALWAYS REPRODUCE THS ISSUE, INSTEAD OF RELYING ON CODE INSPECTION ALONE)

1. Follow the reproduction steps from the issue (or infer reasonable steps if not provided).
2. Use Deployment instructions in the project to execute the reproduction steps.
3. **If the issue involves frontend, use the frontend to reproduce the issue**. **If the issue is involving only backend, then you can run the backend and use curl to reproduce the issue**.
4. Capture all logs, error output, and HTTP responses.
5. Record expected vs. actual behavior.

## Step 4: Locate Related Tests

Analyze the test coverage related to the issue.

## Step 5: Write the Output Artifact

Create the directory `.ai/` at the repo root if it doesn't exist. Write the analysis to `.ai/issue-analysis-<issue_number>.md` using this exact format:

```markdown
# Issue Analysis — [Issue #ID]: [Issue Title]

## Classification
- **Type:** Bug / Not a Bug (with explanation)
- **Severity Assessment:** Critical / High / Medium / Low
- **Affected Component(s):** [from agents.md module map]
- **Affected Feature(s):** [from agents.md feature inventory]

## Reproducibility
- **Reproducible:** Yes / No
- **Environment:** [branch, language/runtime version, OS, relevant config]
- **Steps Executed:**
  1. [step]
  2. [step]
- **Expected Behavior:** [what should happen]
- **Actual Behavior:** [what actually happened]
- **Logs/Evidence:** [attached or inline]

## Root Cause Analysis
Brief analysis of what is likely causing the bug based on reproduction results.

## Test Coverage Assessment
- **Existing tests covering this path:** [list test files/functions]
- **Coverage gaps identified:** [paths with no tests]
- **Proposed test plan:**
  - Unit test: [description]
  - Integration test: [description]
  - Negative/edge cases: [description]
```

## Step 6: Cleanup

- Stop any servers started.
- Revert any temporary config or data changes.
- Ensure the working tree is clean.

## Important Rules

- **Never guess.** If you encounter ambiguity you cannot resolve from available documents, stop and ask the developer.
- **Artifacts over memory.** The output artifact must be complete enough for a different agent to pick up where you left off.
