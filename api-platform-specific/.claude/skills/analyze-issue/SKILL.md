---
name: reproduce-issue
description: Use this skill when the user provides a GitHub issue URL and wants it reproduced, validated, or analyzed. Triggers include phrases like "reproduce this issue", "is this a real bug", "validate this bug", "check this GitHub issue", or any time a GitHub issue link is shared with the intent of determining whether it's a true or false positive. Also use when the user wants reproduction steps, root cause analysis, or a fix plan for a reported product issue.
---

# Reproduce Issue

Validate reported GitHub issues, confirm them against a running product, and produce root cause analysis with fix plans when the issue is real.

## Workflow

### Step 0: Validate the Issue

1. Fetch the issue from the provided GitHub URL.
2. Read the issue description, reproduction steps, and any linked context.
3. Independently determine whether this is a **true positive** (real bug) or **false positive** (not a bug).
   - Do NOT assume the reporter's suggested solution is correct.
   - Verify claims against the actual codebase and relevant product/library/technical documentation.

### Step 1: Confirm Against the Running Product

1. Set up and run the product locally (or use an existing running instance).
2. Follow the reported reproduction steps and independently verify the behavior.
3. Document evidence clearly: commands run, logs, screenshots, observed vs expected behavior.
4. **If false positive**: generate the analysis report (see Output below), notify the user, and **stop here**.

### Step 2: Root Cause & Fix Plan (true positive only)

1. **Root cause**: Trace the bug to the specific code path. Identify the offending logic.
2. **Potential solutions**: List all viable fix approaches. For each, note trade-offs (complexity, risk, scope of change).
3. **Test plan**: Outline both unit tests and integration tests that cover the fix and prevent regression.

## Output

Generate an analysis `.md` file containing:

- **Issue**: Link and summary
- **Verdict**: True positive or false positive
- **Evidence**: Reproduction steps and results (or invalidation steps)
- **Root cause** *(true positive only)*: Code path and explanation
- **Proposed fixes** *(true positive only)*: All viable approaches with trade-offs
- **Test plan** *(true positive only)*: Unit and integration test outlines