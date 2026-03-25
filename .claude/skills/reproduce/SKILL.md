---
name: reproduce
description: Analyze a GitHub issue, reproduce the bug, and produce a structured issue analysis artifact.
user-invocable: true
argument-hint: "[GitHub Issue URL or ID]"
---

# /reproduce — Issue Analysis & Bug Reproduction

You are an AI assistant helping a developer determine if a GitHub issue is a valid, reproducible bug. Follow the procedure below precisely.

## Step 0: Load Product Context

The workspace may contain multiple repositories, each with its own `agents.md` at its root. Identify which repository the issue belongs to and read the `agents.md` from that repository's root. If the file doesn't exist, **stop immediately** and tell the developer to create one (point them to `agents.md.template`).

Once found, verify it contains the **Deployment** and **Feature Inventory** sections. If either is missing, stop and tell the developer exactly which sections are needed.

## Step 1: Classify the Issue

Read the GitHub issue (title, body, labels, and comments) using the provided issue URL or ID.

Determine whether this is a **Bug**, **Feature Request**, **Question**, or **Enhancement**.

- If it is **not a bug**, report the classification and stop. Do not proceed further.
- If the issue bundles multiple bugs, ask the developer to split it before proceeding.

## Step 2: Determine Reproducibility Need

Some bugs are obvious from code inspection alone (e.g., typo in config key, null-pointer from missing null-check). If the root cause is clear without running the product, skip to Step 6.

Otherwise, proceed to Step 3.

## Step 3: Environment Setup

Using `agents.md > Deployment`:
1. Build the product from the relevant branch.
2. Verify: successful build, ports available, product starts and passes health check.

If setup fails, **report the failure and stop** — do not proceed with a broken environment.

## Step 4: Reproduce the Bug

Using `agents.md > Feature Inventory`, locate the feature referenced in the issue.

1. Follow the reproduction steps from the issue (or infer reasonable steps if not provided).
2. Capture all logs, error output, and HTTP responses.
3. Record expected vs. actual behavior.

## Step 5: Locate Related Tests

Search for existing unit and integration tests covering the affected code path. Note:
- Which tests exist
- Which pass/fail
- Which paths have **no** test coverage at all

## Step 6: Cleanup

- Stop any servers started.
- Revert any temporary config or data changes.
- Ensure the working tree is clean.

## Step 7: Write the Output Artifact

Create the directory `.ai/` at the repo root if it doesn't exist. Write the analysis to `.ai/issue-analysis.md` using this exact format:

```markdown
# Issue Analysis — [Issue #ID]: [Issue Title]

## Classification
- **Type:** Bug / Not a Bug (with explanation)
- **Severity Assessment:** Critical / High / Medium / Low
- **Affected Component(s):** [from agents.md module map]
- **Affected Feature(s):** [from agents.md feature inventory]

## Reproducibility
- **Reproducible:** Yes / No / Not Attempted (with reason)
- **Environment:** [branch, language/runtime version, OS, relevant config]
- **Steps Executed:**
  1. [step]
  2. [step]
- **Expected Behavior:** [what should happen]
- **Actual Behavior:** [what actually happened]
- **Logs/Evidence:** [attached or inline]

## Root Cause Hypothesis
Brief analysis of what is likely causing the bug based on code inspection
and reproduction results.

## Test Coverage Assessment
- **Existing tests covering this path:** [list with pass/fail status]
- **Coverage gaps identified:** [paths with no tests]
- **Proposed test plan:**
  - Unit test: [description]
  - Integration test: [description]
  - Negative/edge cases: [description]
```

## Important Rules

- **Never guess.** If you encounter ambiguity you cannot resolve from available documents, stop and ask the developer.
- **Artifacts over memory.** The output artifact must be complete enough for a different agent to pick up where you left off.
- **Minimal scope.** Operate on a single issue at a time.
- After writing the artifact, inform the developer that they should review `issue-analysis.md` and confirm the analysis before proceeding to `/plan-fix`.
