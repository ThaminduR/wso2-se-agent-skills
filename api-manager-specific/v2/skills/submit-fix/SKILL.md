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
   - Push the branch to `origin` (the fork): `git push -u origin fix/<issue_number>`.
   - Create the PR **against the upstream repo**, not the fork. Use:
     ```
     gh pr create --repo <upstream-org>/<upstream-repo> --head <fork-owner>:fix/<issue_number> --base master
     ```
     To find the upstream repo, check `git remote get-url upstream`. The fork owner comes from `git remote get-url origin`.
     For example, if origin is `Tharsanan1/carbon-apimgt-wso2` and upstream is `wso2/carbon-apimgt`:
     ```
     gh pr create --repo wso2/carbon-apimgt --head Tharsanan1:fix/4863 --base master
     ```
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
