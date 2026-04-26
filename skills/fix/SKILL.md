---
name: fix
description: Implement the fix described in a plan artifact — checkout the matching source version, make the code change, build, patch the product, and dev-test at runtime.
user-invocable: true
argument-hint: "[Issue number]"
---

# /fix — Implement and Dev-Test a Planned Fix

## Input

- **Required:** `.ai/plan-<issue_number>.md` (produced by `/plan`). If this file does not exist, stop and tell the developer to run `/plan <issue>` first.
- **Optional:** `.ai/ia-<issue_number>.md` (from `/reproduce`), for additional reproduction context.

If the plan says the issue is not a bug, already fixed, or has unresolved open questions blocking implementation — stop and report. Do not proceed.

## wso2-support patch check

If the plan indicates this is a wso2-support patch fix (not to be confused with applying a JAR patch to a pack — which is the standard build/dev-test step in step 5), the target repo, branch, and pack handling differ from a regular GA fix. Follow the product-specific wso2-support patch guide for this.

## Steps

1. **Clone the target repo** (from the plan's "Target" section) into the current workspace if it's not already present.

2. **Checkout the matching source version.** Follow the "Checkout the matching source version" instructions in CLAUDE.md using the tag and working branch name recorded in the plan:
   ```
   git checkout <tag> -b fix/issue-<issue_number>
   ```
   Confirm the tag exists and matches the jar version in the product pack's `plugins/` directory. If they don't match, stop — the plan targeted the wrong version.

3. **Implement the fix** exactly as described in the plan's "Proposed Change" section. Keep the change minimal. If during implementation you discover the plan is wrong or incomplete, stop and report — do not improvise a different fix silently.

4. **Build the changed module(s)** to verify they compile:
   ```
   mvn clean install -Dmaven.test.skip=true
   ```
   Confirm the built jar version matches the version in the pack (e.g., `9.33.65-SNAPSHOT` source → `9.33.65` pack). If they don't match, you checked out the wrong tag — stop and fix.

5. **Dev-test the fix.** Patch the product pack and verify the fix works at runtime. Follow the patching instructions in CLAUDE.md (extract fresh pack, apply JAR/WAR patches, start server). The start command and the log polling loop MUST be in the same Bash tool call with `timeout: 200000`. Run the "Dev Test Plan" steps from the plan artifact.
   - If the test **passes**: proceed to step 6.
   - If the test **fails**: analyze the failure, adjust the code (within the scope of the plan), rebuild, and test again. Each iteration must make **forward progress** — if you find yourself retrying the same failure without a clear new change, stop and report.

6. **Write the fix report** to `.ai/fix-<issue_number>.md`:

```markdown
# Fix Report — Issue #<issue_number>

## Dev Test Result
- **Status:** PASSED | FAILED
- **What was tested:** <brief description of the dev-test performed>
- **Result:** <what happened — include key log lines, curl output, or screenshot paths>

## Changes Made
| Repo | File | Change |
|------|------|--------|
| <repo> | <file> | <brief description> |

## Deviations From Plan
<If you had to diverge from `.ai/plan-<issue_number>.md`, say what and why. Leave empty if the plan was followed as-is.>

## Known Issues
<Any remaining issues, limitations, or things that still need fixing. Leave empty if dev test passed cleanly.>
```

## Important Rules

- **No planning here.** Do not re-analyze root cause or redesign the fix. If the plan looks wrong, stop and ask for the plan to be updated — don't silently deviate.
- **Server startup:** The start command and the log polling loop MUST be in the same Bash tool call with `timeout: 200000`. Do not split them into separate calls.
- **Polling discipline.** When you write a Bash loop that waits on something — a sentinel string in a log, a process to exit, a file to appear — remember the failure mode: if that something never arrives, the loop runs forever and deadlocks the whole phase. Decide up front how long you're willing to wait, enforce it inside the loop, and plan what to do if the cap trips (inspect the actual state, fail the phase cleanly, or try a different approach).
- **Fresh pack only.** Never restart an in-place server. Always kill, delete, re-extract, patch, and start fresh per CLAUDE.md.
- **Runtime evidence only.** "The build succeeded" or "the diff looks correct" is NOT a dev-test pass. The fix report's PASSED status must be backed by observed runtime behavior (Playwright screenshot, curl response, server log excerpt).
