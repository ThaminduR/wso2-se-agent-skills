# AI-Assisted Bug Fix Pipeline — Skills Specification

## 1. Executive Summary

**Goal:** Equip developers in WSO2 monorepo products with a deterministic, AI-driven workflow to go from a raw GitHub issue to a merged pull request — safely, consistently, and with full traceability.

**Core Problem:** Developers waste significant time on repetitive bug-fix mechanics — reproducing issues, navigating large codebases, writing boilerplate tests, and assembling PRs. An AI agent with the right product context can handle this scaffolding while keeping the developer in control of every critical decision.

**Approach:** Six sequential skills (commands), each producing a versioned artifact that feeds the next. The entire chain is anchored by an `agents.md` file in each monorepo that gives the AI deep product context.

```
┌──────────┐    ┌───────────┐    ┌──────────────┐    ┌────────────┐    ┌──────────────┐    ┌──────────┐
│/reproduce │───▶│ /plan-fix  │───▶│ /review-plan │───▶│ /implement │───▶│ /code-review │───▶│ /send-pr │
│           │    │            │    │              │    │            │    │              │    │          │
│ issue-    │    │ implement- │    │ plan-review- │    │ code +     │    │ review       │    │ PR       │
│ analysis  │    │ plan.md    │    │ report.md    │    │ tests      │    │ report.md    │    │ created  │
│ .md       │    │            │    │              │    │            │    │              │    │          │
└──────────┘    └───────────┘    └──────────────┘    └────────────┘    └──────────────┘    └──────────┘
```

**Key Principles:**

- **Human-in-the-loop at every gate.** The AI never merges, never pushes without approval, and explicitly pauses for clarification on ambiguity.
- **Artifacts over memory.** Every skill produces a Markdown artifact. If you lose the conversation, the artifacts let you (or a different agent) resume.
- **Minimal blast radius.** Code changes are scoped to the smallest set of files that fix the issue. The AI is instructed to resist broad refactors.
- **Product context via `agents.md`.** The AI doesn't guess at architecture — it reads a maintained reference doc in the repo.

---

## 2. `agents.md` — The Product Context Layer

Every monorepo **must** contain an `agents.md` at the repository root. This is the single source of truth the AI reads before executing any skill. Without it, skills will hallucinate product structure.

### 2.1 Required Structure

```markdown
# agents.md — [Product Name]

## Product Overview
Brief description of what this product does, who uses it, and its primary value proposition.

## Architecture
### System Architecture
High-level architecture (monolith, microservices, modular, etc.), key runtime components,
and how they interact.

### Module/Component Map
| Module               | Path                          | Responsibility                     |
|----------------------|-------------------------------|-------------------------------------|
| identity-service     | /components/identity/...      | AuthN, AuthZ, session management   |
| api-gateway          | /components/gateway/...       | Request routing, rate limiting     |
| ...                  | ...                           | ...                                |

### Key Abstractions & Patterns
Design patterns used (e.g., OSGi bundles, extension points, SPI), naming conventions,
and component lifecycle.

### Inter-Component Communication
How modules talk to each other (REST, gRPC, events, OSGi services, direct calls).

## Feature Inventory
| Feature              | Entry Point(s)                 | Related Components                 |
|----------------------|--------------------------------|-------------------------------------|
| OAuth2 Token Issuance| /components/oauth/...          | identity-service, token-store      |
| API Publishing       | /components/publisher/...      | api-gateway, registry              |
| ...                  | ...                            | ...                                |

## Deployment
### Prerequisites
Runtime requirements (JDK version, DB, external services).

### Build & Run
Step-by-step commands to build from source and start the product locally.

### Configuration
Key config files, environment variables, and default ports.

### Health Check
How to verify the product started successfully (URLs, CLI commands, log markers).

## Testing
### Test Framework & Conventions
Which frameworks are used (JUnit, TestNG, etc.), test naming conventions,
where tests live relative to source.

### Running Tests
Commands to run unit tests, integration tests, and full test suites.
Include module-scoped test commands.

### Test Infrastructure
Any test containers, mock services, or fixtures required.

## Coding Conventions
### Style & Formatting
Linter/formatter config, import ordering, naming conventions.

### Commit Message Format
Expected format (e.g., Conventional Commits, issue-linked).

### Branch Naming
Pattern for feature/fix branches.

## Contribution Guidelines
### PR Process
Required reviewers, CI checks that must pass, labels to apply.

### PR Template Location
Path to `.github/PULL_REQUEST_TEMPLATE.md` or equivalent.

### Labels & Categories
Available labels and when to use each.

## References
Links to external docs, wikis, API specs, or design docs that skills may need.
```

### 2.2 Maintenance Rules

- **Ownership:** Each team that owns a monorepo owns its `agents.md`. Updates are part of the definition of done for architectural changes.
- **Validation:** A CI check should verify `agents.md` contains all required sections (a simple heading-level linter).
- **Versioning:** `agents.md` is version-controlled alongside the code. Skills read it at HEAD.

---

## 3. Skills Specification

### 3.1 Shared Conventions (Apply to All Skills)

**Context Loading:** Every skill begins by reading `agents.md` from the repo root. If it doesn't exist or is missing required sections, the skill stops and tells the developer what's missing.

**Artifact Naming:** All output artifacts are written to a `.ai/` directory at the repo root (gitignored). This keeps them discoverable but out of version control.

```
.ai/
├── issue-analysis.md
├── implementation-plan.md
├── plan-review-report.md
└── code-review-report.md
```

**Error Handling:** If any skill encounters an ambiguity it cannot resolve from available documents, it **must** stop and ask the developer. It must not guess and proceed.

**Scope Boundary:** Skills operate on a single issue at a time. If an issue bundles multiple bugs, the skill should ask the developer to split it.

---

### 3.2 `/reproduce`

> **Purpose:** Determine if the issue is a valid, reproducible bug and produce a structured analysis.

**Input:** GitHub Issue URL or ID

**Preconditions:**
- `agents.md` exists with Deployment and Feature Inventory sections populated
- Developer's machine meets prerequisites listed in `agents.md > Deployment > Prerequisites`

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Classify the issue** | Read the issue title, body, labels, and comments. Determine: Is this a bug, feature request, question, or enhancement? If not a bug, stop and report classification. |
| 2 | **Determine reproducibility need** | Some bugs are obvious from code inspection (e.g., typo in config key, null-pointer from missing null-check). If the root cause is clear without running the product, skip to step 6. |
| 3 | **Environment setup** | Using `agents.md > Deployment`, build the product from the relevant branch. Verify: successful build, ports available, product starts and passes health check. If setup fails, report the failure — don't proceed with a broken environment. |
| 4 | **Reproduce the bug** | Using `agents.md > Feature Inventory`, locate the feature referenced in the issue. Follow the reproduction steps from the issue (or infer reasonable steps if not provided). Capture all logs, error output, and HTTP responses. |
| 5 | **Locate related tests** | Search for existing unit and integration tests covering the affected code path. Note: which tests exist, which pass/fail, and which paths have *no* test coverage at all. |
| 6 | **Cleanup** | Stop any servers started. Revert any temporary config or data changes. The working tree should be clean after this step. |

**Output:** `.ai/issue-analysis.md`

```markdown
# Issue Analysis — [Issue #ID]: [Issue Title]

## Classification
- **Type:** Bug / Not a Bug (with explanation)
- **Severity Assessment:** Critical / High / Medium / Low
- **Affected Component(s):** [from agents.md module map]
- **Affected Feature(s):** [from agents.md feature inventory]

## Reproducibility
- **Reproducible:** Yes / No / Not Attempted (with reason)
- **Environment:** [branch, JDK version, OS, relevant config]
- **Steps Executed:**
  1. [step]
  2. [step]
- **Expected Behavior:** [what should happen]
- **Actual Behavior:** [what actually happened]
- **Logs/Evidence:** [attached or inline]

## Root Cause Hypothesis
Brief analysis of what is likely causing the bug based on code inspection
and reproduction results.

## Test Coverage Assessment
- **Existing tests covering this path:** [list with pass/fail status]
- **Coverage gaps identified:** [paths with no tests]
- **Proposed test plan:**
  - Unit test: [description]
  - Integration test: [description]
  - Negative/edge cases: [description]
```

**Exit Criteria:** The developer reviews `issue-analysis.md` and confirms the analysis before proceeding to `/plan-fix`.

---

### 3.3 `/plan-fix`

> **Purpose:** Produce a detailed, reviewable implementation plan before any code is written.

**Input:** `.ai/issue-analysis.md`

**Preconditions:**
- `issue-analysis.md` exists and classifies the issue as a bug
- `agents.md` exists with Architecture and Feature Inventory sections populated

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Ingest analysis** | Read `issue-analysis.md`. Verify the issue is classified as a bug. If not, stop. |
| 2 | **Map the affected code** | Using `agents.md > Architecture`, identify the exact modules, classes, and methods involved. Read the source code for these components. Trace the execution path from entry point to the point of failure. |
| 3 | **Identify the fix** | Determine the minimal code change that addresses the root cause. Prefer fixes that align with existing patterns in the codebase (refer to `agents.md > Key Abstractions & Patterns`). |
| 4 | **Assess blast radius** | List all components and features that could be affected by this change. Cross-reference with `agents.md > Feature Inventory`. |
| 5 | **Clarify ambiguities** | If there are multiple valid approaches, or if the fix might change observable behavior beyond the bug, **stop and ask the developer** before proceeding. Present the trade-offs clearly. |
| 6 | **Design the test plan** | Specify exact tests to write: what each test asserts, which category (unit/integration), and where it lives. Include negative and boundary cases. |
| 7 | **Document breaking changes** | If the fix changes any public API, config format, wire protocol, or default behavior, explicitly flag it. |

**Output:** `.ai/implementation-plan.md`

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

**Exit Criteria:** Developer reviews the plan. If `Open Questions` is non-empty, those must be answered before proceeding. The plan is then passed to `/review-plan`.

---

### 3.4 `/review-plan`

> **Purpose:** Independent validation of the implementation plan before code is written. Acts as a quality gate.

**Input:** `.ai/implementation-plan.md`, `.ai/issue-analysis.md`

**Preconditions:**
- Both input artifacts exist
- `implementation-plan.md` has no unresolved open questions

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Completeness check** | Does the plan actually address the root cause from `issue-analysis.md`? Is there a logical chain from root cause → code change → fix? |
| 2 | **Approach review** | Are the correct modules being modified? Are changes minimal and scoped? Does the approach follow existing codebase patterns (verify against `agents.md > Architecture`)? Are there simpler alternatives? |
| 3 | **Test coverage review** | Does the test plan cover: the exact bug scenario, edge cases, boundary conditions, negative inputs, and regression paths? Are both unit and integration tests planned where appropriate? |
| 4 | **Security review** | Does the fix touch input validation, authentication, authorization, session handling, data serialization, or crypto? If yes, flag for additional human review. Check for injection risks, privilege escalation, and data exposure. |
| 5 | **Regression risk assessment** | Which existing features could break? Is the existing test suite for affected components being run? Are there any implicit dependencies that might not be caught by tests? |
| 6 | **Breaking change review** | If breaking changes are declared, is the migration path clear? If none are declared, verify this is actually true. |

**Output:** `.ai/plan-review-report.md`

```markdown
# Plan Review Report — [Issue #ID]: [Issue Title]

## Verdict: ✅ Approved / ⚠️ Revisions Required

## Implementation Plan Assessment
- **Completeness:** [Does it fully address the root cause?]
- **Correctness:** [Is the proposed logic sound?]
- **Approach:** [Appropriate scope? Follows conventions?]

## Test Coverage Evaluation
- **Bug scenario covered:** Yes / No
- **Edge cases covered:** Yes / No — [gaps identified]
- **Negative tests included:** Yes / No
- **Regression tests planned:** Yes / No

## Security Findings
- **Risk level:** None / Low / Medium / High
- **Details:** [specific findings, if any]
- **Recommendation:** [proceed / require security review]

## Regression Risk
- **Risk level:** Low / Medium / High
- **Affected features:** [list]
- **Mitigation:** [what tests/checks cover this]

## Required Revisions (if any)
1. [Specific, actionable revision with rationale]
2. ...

## Notes for Implementation
[Any additional guidance for the /implement phase]
```

**Exit Criteria:** If verdict is "Revisions Required," the developer sends the report back to `/plan-fix` for a revised plan. Only "Approved" plans proceed to `/implement`.

---

### 3.5 `/implement`

> **Purpose:** Execute the approved implementation plan — write the fix, write the tests, verify everything works.

**Input:** `.ai/implementation-plan.md`, `.ai/issue-analysis.md`

**Preconditions:**
- `plan-review-report.md` shows "Approved"
- `agents.md` exists with Deployment, Testing, and Coding Conventions sections

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Apply code changes** | Follow `implementation-plan.md > Implementation Steps` exactly. Adhere to coding conventions from `agents.md > Coding Conventions`. Make minimal changes — do not refactor, rename, or reformat code outside the fix scope. |
| 2 | **Write tests** | Implement all tests specified in the test plan. Follow test conventions from `agents.md > Testing`. |
| 3 | **Run affected test suite** | Execute existing tests for all affected components using commands from `agents.md > Testing > Running Tests`. All must pass. |
| 4 | **Dev-test the fix** | Set up the product using `agents.md > Deployment`. Reproduce the original bug using steps from `issue-analysis.md`. Verify the bug is fixed. Verify no obvious regressions in related features. |
| 5 | **Iterate if needed** | If dev testing reveals issues, fix them and return to step 3. **Never finalize without a passing dev test.** |
| 6 | **Cleanup** | Stop servers. Ensure working tree contains only intentional changes. Remove any debug logging or temporary code. |

**Clarification Protocol:** If implementation reveals that the plan is insufficient (e.g., an edge case not considered, an API that doesn't behave as expected), the AI **must stop and ask the developer** rather than improvise a solution.

**Output:** Code changes + tests on the working branch, plus a deviation report if anything changed from the plan.

```markdown
# Implementation Report — [Issue #ID]: [Issue Title]

## Changes Made
| File | Change Summary |
|------|---------------|
| path/to/File.java | [what was changed] |
| ... | ... |

## Tests Written
| Test | Type | Status |
|------|------|--------|
| testX | Unit | ✅ Pass |
| ... | ... | ... |

## Existing Test Suite Results
- **Suite:** [name] — ✅ All pass / ❌ [N] failures (details below)

## Dev Test Results
- **Bug reproduction before fix:** [confirmed reproducible]
- **Bug status after fix:** [resolved]
- **Related features tested:** [list with pass/fail]

## Deviations from Plan
- None / [describe what changed and why]
```

**Exit Criteria:** All tests pass, dev test confirms the fix, and the developer approves the changes before proceeding to `/code-review`.

---

### 3.6 `/code-review`

> **Purpose:** Automated code review of the implemented changes before PR submission.

**Input:** The diff of all changes on the current branch vs. the base branch

**Preconditions:**
- `/implement` is complete and all tests pass

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Diff analysis** | Read the full diff. Verify every changed line maps back to the implementation plan. Flag any unplanned changes. |
| 2 | **Code quality check** | Review for: naming consistency, error handling completeness, resource cleanup (try-with-resources, null checks), logging appropriateness, and adherence to `agents.md > Coding Conventions`. |
| 3 | **Test quality check** | Review test code for: meaningful assertions (not just "no exception thrown"), proper setup/teardown, test isolation, and clear naming that describes the scenario. |
| 4 | **Security scan** | Check for: hardcoded credentials, SQL injection, XSS, improper input validation, insecure deserialization, and overly permissive access controls. |
| 5 | **Performance check** | Flag any obvious performance concerns: N+1 queries, unbounded loops, missing pagination, large object allocation in hot paths. |
| 6 | **Documentation check** | Are Javadoc/comments updated where behavior changed? Are any public API changes reflected in documentation? |

**Output:** `.ai/code-review-report.md`

```markdown
# Code Review Report — [Issue #ID]: [Issue Title]

## Verdict: ✅ Ready for PR / ⚠️ Changes Requested

## Summary
[One-paragraph assessment]

## Findings

### Critical (must fix before PR)
- [ ] [finding with file:line reference and suggestion]

### Recommended (should fix)
- [ ] [finding with file:line reference and suggestion]

### Informational (nice to have)
- [ ] [finding with file:line reference and suggestion]

## Checklist
- [ ] All changes map to the implementation plan
- [ ] Coding conventions followed
- [ ] Error handling is complete
- [ ] Tests are meaningful and isolated
- [ ] No security issues found
- [ ] No performance concerns
- [ ] Documentation updated where needed
```

**Exit Criteria:** All critical findings are resolved. The developer approves the review before proceeding to `/send-pr`.

---

### 3.7 `/send-pr`

> **Purpose:** Assemble and submit a pull request with proper metadata, description, and labels.

**Input:** All `.ai/` artifacts, the code diff, `.github/PULL_REQUEST_TEMPLATE.md`

**Preconditions:**
- `code-review-report.md` shows "Ready for PR"
- `agents.md > Contribution Guidelines` is populated
- Changes are committed on a properly named branch (per `agents.md > Branch Naming`)

**Procedure:**

| Step | Action | Details |
|------|--------|---------|
| 1 | **Read PR template** | Load the PR template from `.github/PULL_REQUEST_TEMPLATE.md`. |
| 2 | **Populate PR description** | Fill in each section of the template using content from the `.ai/` artifacts. Include: the issue reference, root cause summary, fix description, test plan, and breaking change notes. |
| 3 | **Apply labels** | Using `agents.md > Contribution Guidelines > Labels & Categories`, select the appropriate labels (e.g., `bug`, `component/identity`, severity label). |
| 4 | **Set metadata** | Link the issue, assign reviewers if specified in guidelines, and set the milestone if applicable. |
| 5 | **Create the PR** | Submit the PR. Include a final summary comment linking to all `.ai/` artifacts for reviewer context. |

**Output:** A submitted pull request with proper template, labels, and linked artifacts.

---

## 4. Workflow Rules & Safeguards

### 4.1 Skill Dependencies (Enforced)

Skills **must** be run in order. Each skill checks for the existence and validity of its required input artifacts.

| Skill | Required Input Artifacts | Blocking Condition |
|-------|-------------------------|--------------------|
| `/reproduce` | GitHub Issue | None |
| `/plan-fix` | `issue-analysis.md` | Issue not classified as bug |
| `/review-plan` | `implementation-plan.md` + `issue-analysis.md` | Open questions in plan |
| `/implement` | `implementation-plan.md` + `issue-analysis.md` | Plan not approved |
| `/code-review` | Code diff | Tests not passing |
| `/send-pr` | All artifacts + code diff | Code review not passed |

### 4.2 Human Checkpoints

The AI **pauses and waits for developer confirmation** at these points:

1. After `/reproduce` — before planning begins
2. During `/plan-fix` — if there are multiple valid approaches or any ambiguity
3. After `/review-plan` — if revisions are required
4. During `/implement` — if the plan proves insufficient at execution time
5. After `/code-review` — before the PR is submitted
6. After `/send-pr` — the developer reviews the PR before requesting reviews

### 4.3 Failure Modes

| Scenario | Behavior |
|----------|----------|
| `agents.md` missing or incomplete | Skill stops, reports which sections are needed |
| Issue is not a bug | `/reproduce` reports classification, workflow ends |
| Cannot reproduce | `/reproduce` reports failure with logs, developer decides next step |
| Environment won't start | `/reproduce` reports setup failure, does not proceed |
| Ambiguous requirements | Skill stops and asks developer, does not guess |
| Plan has open questions | `/implement` refuses to start |
| Tests fail after implementation | `/implement` loops (fix → test → verify) up to 3 iterations, then asks developer |
| Code review finds critical issues | `/send-pr` refuses to start |
| PR template not found | `/send-pr` uses a sensible default but warns the developer |

---

## 5. Rollout Plan

### Phase 1 — Foundation
- [ ] Define and ship `agents.md` for one pilot monorepo
- [ ] Implement `/reproduce` and `/plan-fix` skills
- [ ] Internal testing with 5 real bug issues
- [ ] Collect feedback, iterate on artifact formats

### Phase 2 — Full Pipeline
- [ ] Implement `/review-plan`, `/implement`, `/code-review`, `/send-pr`
- [ ] End-to-end testing: 10 bugs through the full pipeline
- [ ] Refine human checkpoint UX (what prompts does the AI show? how does the developer approve?)

### Phase 3 — Scale
- [ ] Roll `agents.md` out to all monorepos
- [ ] Create `agents.md` CI linter to enforce required sections
- [ ] Establish metrics: time-to-fix, plan revision rate, code review pass rate
- [ ] Iterate on skills based on metrics

---

## 6. Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Bug-fix cycle time | 40% reduction vs. manual | Time from issue triage to PR merge |
| Plan approval rate (first pass) | > 70% | `/review-plan` approvals without revisions |
| Code review pass rate (first pass) | > 80% | `/code-review` passes without changes requested |
| Regression rate | < 5% | Post-merge regressions traced to AI-assisted fixes |
| Developer satisfaction | > 4/5 | Post-fix survey |
| `agents.md` freshness | < 2 weeks stale | CI check on last-modified date of `agents.md` |

---

## 7. Open Questions & Decisions Needed

1. **Artifact storage:** Should `.ai/` artifacts be committed to a separate branch, stored in the issue comments, or kept local-only? Trade-off: traceability vs. repo noise.
2. **Multi-issue scope:** Should skills support fixing multiple related issues in one pass, or strictly one-issue-at-a-time?
3. **CI integration:** Should `/code-review` also run CI checks (linting, static analysis) as part of its review, or rely on the existing CI pipeline post-PR?
4. **Skill composition:** Should developers be able to run `/reproduce` through `/send-pr` as a single command (`/fix`), or always step through individually?
5. **Rollback protocol:** If a merged fix causes regressions, should there be a `/rollback` skill?