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

### 2. Reproduce
Set up the environment and follow the reported steps. Note: branch, runtime/language version, OS, and any relevant config.

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