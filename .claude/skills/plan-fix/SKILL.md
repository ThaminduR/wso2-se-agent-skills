---
name: plan-fix
description: Produce a detailed, reviewable implementation plan for a confirmed bug before any code is written.
user-invocable: true
---

# /plan-fix — Implementation Planning

You are an AI assistant creating a detailed implementation plan for a confirmed bug fix. Follow the procedure below precisely.

## Step 0: Load Context

1. Read `agents.md` from the repository root. If it doesn't exist or is missing **Architecture** or **Feature Inventory** sections, stop and report what's missing.
2. Read `.ai/issue-analysis.md`. If it doesn't exist, tell the developer to run `/reproduce` first.
3. Verify the issue is classified as a **Bug** in the analysis. If not, stop.

## Step 1: Map the Affected Code

Using `agents.md > Architecture`:
1. Identify the exact modules, classes, and methods involved.
2. Read the source code for these components.
3. Trace the execution path from entry point to the point of failure.

## Step 2: Identify the Fix

Determine the **minimal** code change that addresses the root cause.
- Prefer fixes that align with existing patterns in the codebase (refer to `agents.md > Key Abstractions & Patterns`).
- Do not refactor or reorganize code beyond what is needed to fix the bug.

## Step 3: Assess Blast Radius

List all components and features that could be affected by this change. Cross-reference with `agents.md > Feature Inventory`.

## Step 4: Clarify Ambiguities

If there are multiple valid approaches, or if the fix might change observable behavior beyond the bug, **stop and ask the developer** before proceeding. Present the trade-offs clearly.

## Step 5: Design the Test Plan

Specify exact tests to write:
- What each test asserts
- Which category (unit/integration)
- Where it lives in the project
- Include negative and boundary cases

## Step 6: Document Breaking Changes

If the fix changes any public API, config format, wire protocol, or default behavior, explicitly flag it.

## Step 7: Write the Output Artifact

Write the plan to `.ai/implementation-plan.md` using this exact format:

```markdown
# Implementation Plan — [Issue #ID]: [Issue Title]

## Summary
One-paragraph description of what will be changed and why.

## Root Cause (Confirmed)
[Refined from issue-analysis.md after code inspection]

## Implementation Details

### Files to Modify
| File | Change Description | Rationale |
|------|--------------------|-----------|
| path/to/File.java | [what changes] | [why this specific change] |
| ... | ... | ... |

### Implementation Steps
1. [Ordered steps the AI will follow during /implement]
2. ...

### Code Approach
[Pseudocode or detailed description of the logic change.
Reference existing patterns from the codebase.]

## Test Plan

### New Tests
| Test Name | Type | Asserts | Location |
|-----------|------|---------|----------|
| testXReturnsYWhenZ | Unit | [assertion] | path/to/TestFile.java |
| testXFailsGracefullyOnInvalidInput | Unit | [assertion] | path/to/TestFile.java |
| testEndToEndFlowWithFix | Integration | [assertion] | path/to/ITFile.java |

### Existing Tests to Run
[List of existing test classes/suites that must pass after the change]

## Impact Assessment
- **Affected components:** [list]
- **Affected features:** [list]
- **Breaking changes:** None / [describe what breaks and migration path]
- **Performance implications:** None / [describe]
- **Security implications:** None / [describe]

## Open Questions
[Any unresolved ambiguities — these block /implement until answered]
```

## Important Rules

- **Never guess.** If you encounter ambiguity, stop and ask the developer.
- **Minimal blast radius.** Changes must be scoped to the smallest set of files that fix the issue. Resist broad refactors.
- **Artifacts over memory.** The plan must be complete enough for a different agent to implement it.
- After writing the artifact, inform the developer to review the plan. If `Open Questions` is non-empty, those must be answered before proceeding. The plan should then go through `/review-plan`.
