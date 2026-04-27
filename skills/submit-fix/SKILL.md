---
name: submit-fix
description: Create PRs for the fix across all changed repos and track everything in a comprehensive fix report.
user-invocable: true
argument-hint: "[Issue number]"
---

# /submit-fix — Submit Fix PRs and Track

## Input

Read `.ai/ia-<issue_number>.md` for the issue context.
NOTE: If the analysis artifact say the issue is already fixed or not reproducible, do not proceed with the fix. Report and stop.

## Pre-checks — DO NOT SKIP

1. Read `.ai/verify-<issue_number>.md`. If the verdict is **NOT FIXED**, do NOT submit any PRs. Report that the fix has not been verified and stop.
2. If `.ai/verify-<issue_number>.md` does not exist, do NOT submit. Report that verification has not been run and stop.
3. Also check `.ai/fix-plan-<issue_number>.md` if it exists — if the dev test status is FAILED, do NOT submit.

Only proceed to create PRs if the verification report says **FIXED**.

## Steps

1. **Read all phase artifacts.** Before creating the PR, read the output from every prior phase so you can include a comprehensive summary in the fix report and PR description:
   - `.ai/ia-<issue_number>.md` — issue analysis from reproduce phase
   - `.ai/risk-assessment-<issue_number>.md` — risk score and factors (if exists)
   - `.ai/fix-plan-<issue_number>.md` — fix plan and dev test results
   - `.ai/verify-<issue_number>.md` — verification results
   - `.ai/test-<issue_number>.md` — test summary (if exists)

2. **Identify all repos with changes.** Check each repo directory in the workspace for uncommitted or staged changes related to the fix.

3. **For each changed repo:**
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
   - The PR description should include: issue link, root cause summary, what was changed, how it was verified, and test evidence — all extracted from the phase artifacts.

4. **Write the fix report** to `.ai/fix-report-<issue_number>.md`:

```markdown
# Fix Report — Issue #<issue_number>

## Issue
- **Link:** <GitHub issue URL>
- **Title:** <issue title>

## Pull Requests
| Repo | PR | Status |
|------|-----|--------|
| <repo-name> | <PR URL> | Open |

## Phase Summary

### Reproduction
<Summary from .ai/ia-<issue_number>.md>
- **Classification:** Bug / Not a Bug
- **Reproducible:** Yes / No
- **Root Cause:** <brief root cause from the analysis>

### Risk Assessment
<Summary from .ai/risk-assessment-<issue_number>.md, or "Skipped" if not run>
- **Verdict:** GO / REVIEW REQUIRED
- **Driver:** <forcing rule or dimension that decided it (e.g., "Security fix → REVIEW REQUIRED", "All Low → GO")>
- **Demotions applied:** <list any regression coverage-gap or unaddressed-requirement demotions, or "none">

### Fix Implementation
<Summary from .ai/fix-plan-<issue_number>.md>
- **Dev Test:** PASSED / FAILED
- **Files Changed:**

| Repo | File | Change |
|------|------|--------|
| <repo> | <file> | <brief description> |

### Verification
<Summary from .ai/verify-<issue_number>.md>
- **Verdict:** FIXED / NOT FIXED
- **How Verified:** <brief description of what was tested>

### Test Coverage
<Summary from .ai/test-<issue_number>.md, or "Skipped" if not run>
- **Tests Added:** <count and description>

## Summary of Changes
- **<repo-name>:** <brief description of what was changed and why>
```
