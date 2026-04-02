---
name: submit-fix
description: Create PRs for the fix across all changed repos and track everything in a local fix report.
user-invocable: true
argument-hint: "[Issue number]"
---

# /submit-fix — Submit Fix PRs and Track

## Input

Read `.ai/issue-analysis-<issue_number>.md` for the issue context.

## Steps

1. **Identify all repos with changes.** Check each repo directory in the workspace for uncommitted or staged changes related to the fix.
2. **For each changed repo:**
   - Create a branch named `fix/<issue_number>` (or similar).
   - Commit the changes with a message referencing the issue.
   - Push the branch and create a PR to the repo's main branch using `gh pr create`.
3. **Write the fix report** to `.ai/fix-report-<issue_number>.md`:

```markdown
# Fix Report — Issue #<issue_number>

## Issue
- **Link:** <GitHub issue URL>
- **Title:** <issue title>

## Pull Requests
| Repo | PR | Status |
|------|-----|--------|
| <repo-name> | <PR URL> | Open |

## Summary of Changes
- **<repo-name>:** <brief description of what was changed>
```
