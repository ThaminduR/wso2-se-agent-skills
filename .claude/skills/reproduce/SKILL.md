---
name: reproduce
description: Analyze a GitHub issue, reproduce the bug, and write a structured analysis to .ai/issue-analysis.md.
user-invocable: true
argument-hint: "[GitHub Issue URL or ID]"
---

# /reproduce — Bug Reproduction & Analysis

Analyze the given GitHub issue, attempt to reproduce it, and write a structured artifact.

## Procedure

### 1. Classify
Read the issue (title, body, labels, comments). Determine if it's a **Bug**, **Feature Request**, **Question**, or **Enhancement**.
- If not a bug → report classification and stop.
- If multiple bugs are bundled → ask the developer to split before proceeding.

Once found, verify it contains the **Deployment** and **Feature Inventory** sections. If either is missing, stop and tell the developer exactly which sections are needed.

## Step 1: Classify the Issue

Fetch the GitHub issue using the `gh` CLI. The developer will provide either a full URL (e.g., `https://github.com/org/repo/issues/123`) or a repo and issue number.

```bash
# If given a full URL
gh issue view <URL>

# If given a repo and number
gh issue view <number> --repo <owner/repo>

# To also read comments
gh issue view <number> --repo <owner/repo> --comments
```

Read the issue title, body, labels, and comments from the output.

**Handling attachments:** The `gh` output will contain attachment URLs as markdown links. Issues may include images, log files, config files, JSON payloads, etc. Download and inspect any attachments that are relevant to understanding the bug:

```bash
# Download an attachment to a temp file
curl -sL "<attachment-url>" -o /tmp/<filename>
```

Then inspect the downloaded file based on its type:
- **Images** (`.png`, `.jpg`, `.gif`): Read the file to display it visually.
- **Text files** (`.log`, `.txt`, `.json`, `.yaml`, `.xml`, `.csv`, etc.): Read the file to view content directly.
- **Archives** (`.zip`, `.tar.gz`, `.gz`): Extract first, then inspect the contents:
  ```bash
  unzip /tmp/<filename>.zip -d /tmp/issue-attachments/
  # or: tar -xzf /tmp/<filename>.tar.gz -C /tmp/issue-attachments/
  ```
  List the extracted files and read the relevant ones.

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

### 3. Write Artifact
Create `.ai/` at repo root if absent. Write `.ai/issue-analysis.md`:
```markdown
# Issue Analysis — [#ID]: [Title]

## Classification
- **Type:** Bug | Not a Bug — [brief reason]
- **Severity:** Critical | High | Medium | Low
- **Affected Component(s):**
- **Affected Feature(s):**

## Reproducibility
- **Reproducible:** Yes | No | Not Attempted — [reason]
- **Environment:** [branch, runtime, OS, config]
- **Steps Executed:**
  1.
- **Expected:** [what should happen]
- **Actual:** [what happened]
- **Evidence:** [logs or inline output]

## Root Cause Hypothesis
[Code-informed analysis of the likely cause]

## Test Coverage
- **Existing tests on this path:** [list + pass/fail]
- **Gaps:** [untested paths]
- **Proposed tests:** unit / integration / edge cases
```

### 4. Cleanup
Stop any started servers. Revert temp config or data changes. Leave the working tree clean.

## Rules
- **Never guess** — if anything is ambiguous, stop and ask.
- **Artifact must be self-contained** — sufficient for another agent to continue.