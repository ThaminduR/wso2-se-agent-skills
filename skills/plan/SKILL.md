---
name: plan
description: Produce an implementation plan for a GitHub issue by fetching the issue, its comments, and referenced issues/PRs. Does not require a prior reproduction.
user-invocable: true
argument-hint: "[GitHub Issue URL or ID] [--version <product-version>]"
---

# /plan — Plan a Fix from a GitHub Issue

You are a Software Engineer producing a detailed implementation plan for a GitHub issue. This skill can be run **without** a prior `/reproduce` step — the plan is based on what the issue and its linked context say.

## Input

- **Required:** A GitHub issue URL or number (passed as the argument).
- **Optional:** If `.ai/ia-<issue_number>.md` exists (from a prior `/reproduce`), read it and incorporate the reproduction evidence and root cause analysis into the plan. If it does not exist, that's fine — proceed using the issue context alone.

## wso2-support patch check

After fetching the issue (Step 1 below), if its labels include `Type/Patch` or `patch` (case-insensitive), it is a wso2-support patch-meta issue: the fix lands on a `wso2-support/<repo>` branch rather than `wso2/<repo>` master. The `--version` argument is required. Follow the product-specific wso2-support patch guide for this.

## Step 1: Gather Issue Context

Fetch the full context of the issue. Use `gh` for everything.

1. **Fetch the issue itself** (body, title, labels, state, author):
   ```
   gh issue view <issue_number> --repo <owner>/<repo> --json number,title,body,labels,state,author,url
   ```

2. **Fetch all comments** on the issue:
   ```
   gh issue view <issue_number> --repo <owner>/<repo> --comments
   ```

3. **Identify referenced issues and PRs.** Scan the issue body AND every comment for:
   - `#<number>` references
   - Full GitHub URLs to issues or PRs (`https://github.com/.../issues/<n>` or `.../pull/<n>`)
   - "Fixes #", "Closes #", "Related to #", "See #" mentions
   - Cross-repo references (`owner/repo#number`)

4. **Fetch each referenced item.** For every referenced issue or PR (including cross-repo ones):
   - Issue: `gh issue view <n> --repo <owner>/<repo> --comments`
   - PR: `gh pr view <n> --repo <owner>/<repo> --comments` and `gh pr diff <n> --repo <owner>/<repo>`
   - Capture: title, body, state (open/closed/merged), and — for PRs — the diff. The diff of a related PR is especially valuable (it shows what was already tried or what the fix shape looks like).

5. **Recurse one level.** If a referenced PR/issue itself links to another issue or PR that looks directly relevant (e.g., a parent tracking issue or the PR that introduced the bug), fetch that too. Do not go deeper than one additional level — stop if the chain is getting noisy.

If `gh` returns an error (auth, rate limit, not found), stop and report the error clearly. Do not guess issue content.

## Step 2: Classify and Decide Whether to Plan

- If the issue is clearly **not a bug** (feature request, question, discussion) — report the classification and stop. Do not produce a fix plan.
- If a prior `.ai/ia-<issue_number>.md` exists and says the issue is **already fixed** or **not reproducible** — report and stop. Do not produce a fix plan.
- Otherwise, proceed.

## Step 3: Identify the Target Repo(s) and Source Version(s)

A bug may require coordinated edits across multiple repos (e.g. a backend repo + a portal-UI repo). List every repo whose code must change. Referenced PRs are the strongest signal.

For each target repo:

1. Identify the **affected module(s)**.
2. Identify the **version to target**. Follow the "Checkout the matching source version" instructions in CLAUDE.md:
   - Find the jar version in the product pack's `plugins/` directory for the affected module.
   - Find the matching git tag in the source repo.
   - Record the exact tag the fix should be based off of. Do NOT check it out yet — that's the `/fix` skill's job.

## Step 4: Analyze Root Cause

- If `.ai/ia-<issue_number>.md` exists, use its root cause analysis as the starting point.
- Otherwise, derive the likely root cause from the issue description, comments, and the code referenced in related PRs.
- If the root cause is unclear from the available context, say so in the plan — do not invent one. Flag that `/reproduce` should be run first.

Read the relevant source files in the target repo(s) to confirm the root cause hypothesis. Keep this focused — you're trying to pinpoint the change, not refactor the module.

## Step 5: Write the Plan

Create `.ai/` if it doesn't exist. Write the plan to `.ai/plan-<issue_number>.md` using this exact format:

```markdown
# Fix Plan — Issue #<issue_number>: <title>

## Issue Summary
<1–3 sentences summarizing what the bug is and its impact.>

## Context Sources
- **Issue:** <url>
- **Comments reviewed:** <count>
- **Referenced issues:** <list of #N — title, state>
- **Referenced PRs:** <list of #N — title, state, one-line takeaway from the diff>
- **Prior reproduction artifact:** `.ai/ia-<issue_number>.md` (yes / no — if yes, cite key findings)

## Target
One row per affected repo:

| Repo | Module(s) | Version tag to base the fix on |
|------|-----------|--------------------------------|
| <owner/repo> | <module paths> | <tag, e.g. v9.33.65> |

- **Working branch name (for /fix):** `fix/issue-<issue_number>`

## Root Cause
<What's actually broken and why. Cite file paths and line numbers where relevant.>

## Proposed Change
<Minimal change needed to fix it. Describe the behavior change, then list the concrete edits. Every repo in the Target table must have at least one edit row below — otherwise drop it from Target.>

| Repo | File | Change |
|------|------|--------|
| <owner/repo> | <path> | <what to change and why> |

## Risks & Side Effects
<What could this break? Any backward-compatibility concerns? Config migration? Data migration? Leave empty if none.>

## Dev Test Plan
<How to verify the fix at runtime — the exact steps /fix should run. For frontend: Playwright steps. For backend: curl sequence (reference CLAUDE.md's API Lifecycle Flow).>

## Open Questions
<Anything unclear that the developer should confirm before /fix runs. Leave empty if none.>
```

## Important Rules

- **No code changes.** This skill plans only. It does not checkout branches, edit source, build, or start the product. `/fix` does all of that.
- **Cite the sources.** Every claim in the plan should be traceable to the issue, a comment, a referenced PR diff, or a source file you read. Don't speculate.
- **Keep the change minimal.** Propose the smallest change that fixes the bug. Don't bundle refactors.
- **Stop if you're guessing.** If the root cause isn't clear from the available context, say so — recommend `/reproduce` and stop.
