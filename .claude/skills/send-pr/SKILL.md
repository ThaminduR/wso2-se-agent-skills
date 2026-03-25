---
name: send-pr
description: Assemble and submit a pull request with proper metadata, description, and labels.
user-invocable: true
---

# /send-pr — Pull Request Submission

You are an AI assistant assembling and submitting a pull request for a completed bug fix. Follow the procedure below precisely.

## Step 0: Load Context

1. The workspace may contain multiple repositories, each with its own `agents.md` at its root. Identify the relevant repository and read its `agents.md`. If it doesn't exist, stop and tell the developer to create one (point them to `agents.md.template`). Verify it contains the **Contribution Guidelines** section.
2. Read `.ai/code-review-report.md`. Verify the verdict is **"Ready for PR"**. If not, stop and tell the developer the code review must pass via `/code-review` first.
3. Read `.ai/issue-analysis.md` for the issue details.
4. Read `.ai/implementation-plan.md` for the fix description.
5. Read `.ai/plan-review-report.md` for any implementation notes.

## Step 1: Verify Branch

Ensure changes are committed on a properly named branch per `agents.md > Branch Naming`.

If the developer is on the wrong branch or changes aren't committed:
- Suggest the correct branch name format.
- Ask the developer to commit and push changes before proceeding.

## Step 2: Read PR Template

Load the PR template from `.github/PULL_REQUEST_TEMPLATE.md` (or the path specified in `agents.md > Contribution Guidelines > PR Template Location`).

If no template exists, use a sensible default but **warn the developer**.

## Step 3: Populate PR Description

Fill in each section of the PR template using content from the `.ai/` artifacts:
- **Issue reference:** Link to the original GitHub issue.
- **Root cause summary:** From `issue-analysis.md` and `implementation-plan.md`.
- **Fix description:** From `implementation-plan.md > Summary` and `Implementation Details`.
- **Test plan:** From `implementation-plan.md > Test Plan`.
- **Breaking changes:** From `implementation-plan.md > Impact Assessment`.

## Step 4: Apply Labels

Using `agents.md > Contribution Guidelines > Labels & Categories`, select the appropriate labels:
- Bug label (e.g., `bug`)
- Component label (e.g., `component/identity`)
- Severity label if applicable
- Any other relevant labels

## Step 5: Set Metadata

- Link the issue (use `Fixes #ID` or `Closes #ID` syntax in the PR body).
- Assign reviewers if specified in `agents.md > Contribution Guidelines > PR Process`.
- Set the milestone if applicable.

## Step 6: Create the PR

Use `gh pr create` to submit the PR with the populated template, labels, and metadata.

**Important:** Before creating the PR, show the developer:
- The PR title
- The full PR body
- The labels to be applied
- The reviewers to be assigned

**Wait for the developer's confirmation** before actually submitting.

## Step 7: Post-PR Summary

After the PR is created, add a comment on the PR linking to all `.ai/` artifacts for reviewer context:

```markdown
## AI-Assisted Bug Fix Context

This PR was created with AI assistance. The following artifacts document the full analysis and decision trail:

- **Issue Analysis:** Summary of bug classification, reproduction, and root cause hypothesis
- **Implementation Plan:** Detailed plan including files modified, code approach, and test plan
- **Plan Review:** Independent validation of the implementation plan
- **Code Review:** Automated code review findings

All artifacts are available in the `.ai/` directory of this branch.
```

## Important Rules

- **Never push without confirmation.** Always show the developer the PR details and wait for approval.
- **Follow the repo's conventions.** Use the exact PR template, label scheme, and branch naming from `agents.md`.
- **Link everything.** The PR must reference the issue, and the artifacts must be discoverable from the PR.
- If the PR template is not found, use a sensible default but warn the developer about the missing template.
- After the PR is created, provide the PR URL to the developer and remind them to review it before requesting reviews.
