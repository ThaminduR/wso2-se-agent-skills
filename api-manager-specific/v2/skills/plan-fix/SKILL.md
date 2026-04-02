---
name: plan-fix
description: Plan and implement a fix for a reproduced issue using its issue analysis artifact.
user-invocable: true
argument-hint: "[Issue number]"
---

# /plan-fix — Plan and Implement a Fix

## Input

Read `.ai/issue-analysis-<issue_number>.md` for the root cause analysis and reproduction details.

## Steps

1. **Identify the target repo** from the issue analysis. If the repo is not already cloned in the current workspace, clone it here.
2. **Plan the fix** based on the root cause analysis. Keep the change minimal.
3. **Implement the fix** in the identified repo.
4. **Build the changed module** to verify it compiles.
5. **Patch and verify** — follow the patching instructions in CLAUDE.md to apply the fix to the product pack and verify the fix resolves the issue.
