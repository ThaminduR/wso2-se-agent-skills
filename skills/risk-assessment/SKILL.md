---
name: risk-assessment
description: Decide whether a bug fix is safe for an AI agent to auto-implement. Produces a GO / REVIEW REQUIRED / NO-GO verdict.
user-invocable: true
argument-hint: "[Issue number]"
---

# /risk-assessment — Auto-fix Safety Gate

You are a Senior Software Engineer assessing whether a bug fix is safe for an AI agent to implement autonomously. Read the artifacts, classify the change against explicit forcing rules, score the complexity inputs, then emit one of three verdicts: **GO**, **REVIEW REQUIRED**, **NO-GO**.

**Be honest. Underscoring risk wastes engineering time on failed fixes; overscoring blocks automation unnecessarily.** When uncertain on any flag or dimension, pick the more cautious option and explain.

The rubric uses generic categories. Where the project's own `CLAUDE.md` defines product-specific high-risk components or critical paths, prefer that list over the generic examples.

## Input

At least one of `.ai/ia-<n>.md` (from `/reproduce`) or `.ai/plan-<n>.md` (from `/plan`). Also read the GitHub issue, its comments, and any referenced issues/PRs.

- Both exist → use the plan's Target + Proposed Change as scope; cross-check against the reproduction. Disagreement → flag in the report.
- Only `ia-<n>.md` → derive scope from the reproduction's root cause.
- Only `plan-<n>.md` → use the plan's scope; note the fix has not been runtime-reproduced (this bumps Complexity in Step 2).
- Neither → stop; tell the developer to run `/reproduce` or `/plan`.

If any artifact says "not a bug", "not reproducible", or "already fixed" → stop.

## Step 1: Change Metadata (forcing rules)

Fill in every row before scoring complexity. **When uncertain, mark Y.** Each forcing rule is non-negotiable.

| Attribute | Value | Forcing rule |
|---|---|---|
| Security fix (auth, authz, tokens, encryption, sessions, input sanitization) | Y/N — <detail> | Y → **NO-GO** |
| High-risk components (auth, request routing core, token validation, encryption, TLS, or any component the project `CLAUDE.md` lists as critical) | Y/N — <which> | Y → **NO-GO** |
| Data migration / schema change (column / type / constraint / semantic-index change) | Y/N — <detail> | Y → **NO-GO** |
| API contract break (signature, response shape, status code, required field) | Y/N — <detail> | Y → **NO-GO** |
| UI contract change | Y/N — <detail> | Intentional flow/layout/navigation reshape → **NO-GO**; visual bug fix (missing button, misaligned label) → ok |
| Behavior change for existing users | Y/N — <detail> | Judgment-call ("should probably return empty list instead of 404") → **NO-GO**; unambiguous return-to-spec → ok |
| Backward-compat break | Y/N — <detail> | Y → at least **REVIEW REQUIRED** |
| Components involved (full list) | <list> | — |

**If any forcing rule fires NO-GO, skip to Step 4.** Otherwise carry the strongest demotion (REVIEW REQUIRED if Backward-compat = Y) into Step 3.

## Step 2: Complexity Inputs

Score each dimension Low / Medium / High. Use the project's `CLAUDE.md` for product-specific examples where it has them.

| Dimension | Low | Medium | High |
|---|---|---|---|
| **Diffusion** — how spread out is the change | ≤5 files in one module, one component | Multiple modules in one repo, or 2 repos, or 2-3 components | 3+ repos, or spans architectural layers, or 4+ components |
| **Blast Radius** — what could break if wrong | Isolated utility, single flow / endpoint / page | A class of flows (all of a kind) or shared utility used by multiple flows | Every request, every tenant, or core request/security pipeline |
| **Complexity** — how hard to get right | Obvious fix — typo, null check, single straightforward path | 2-3 interacting subsystems (e.g., validation + templating + serialization) | Concurrency, caching, distributed state, classloader/plugin edges, or root cause unclear after reproduction/planning |
| **Testability** — can we prove it works | Unit-testable; no environmental dependencies | Integration test on a standard supported deployment, fully automatable | Manual-only, timing-sensitive, multi-node clustering, or targets a deployment option not in the standard test pipeline |

**Bonus bump:** plan exists but no reproduction artifact exists → bump Complexity by one level (cap at High).

Map dimensions to verdict:

- **All Low** → **Simple → GO**
- **Any Medium, none High** → **Complex → REVIEW REQUIRED**
- **Complexity = High** OR **Testability = High** → **NO-GO** (can't reliably get it right or can't reliably verify it)
- **Diffusion = High** OR **Blast Radius = High** → at least **REVIEW REQUIRED**

Take the strongest verdict from Step 1 and Step 2 as the **interim verdict**. Carry it to Step 3.

## Step 3: Demotion Gates

Gates only demote (GO → REVIEW REQUIRED → NO-GO). They never promote.

**Regression analysis** — minimum one row. "None" is only acceptable for truly isolated changes (e.g., fixing a doc typo); justify it.

| What could regress | Why the fix could cause it | Existing test that protects | Mitigation in /fix or /verify-fix |
|---|---|---|---|
| <behavior> | <mechanism> | <test path / "coverage gap"> | <what to do> |

→ 2+ `coverage gap` rows → **demote one tier**.

**Requirement coverage** — every explicit ask from the issue, comments, and referenced issues/PRs. Don't silently drop requirements because they look out of scope.

| Requirement | Source | Status |
|---|---|---|
| <requirement> | Issue / Comment by @user / Referenced #N | Addressed / Partial / Not Addressed |

→ Any Partial / Not Addressed → at least **REVIEW REQUIRED**.
→ Conflicting requirements (two parties want opposite behavior) → **NO-GO**.

## Step 4: Write `.ai/risk-assessment-<n>.md`

```markdown
# Risk Assessment — Issue #<n>: <title>

**Verdict:** GO | REVIEW REQUIRED | NO-GO
**Inputs:** `ia-<n>.md` <y/n>, `plan-<n>.md` <y/n>
<If both exist and disagree on root cause or scope, describe the disagreement here.>

## Change Metadata
| Attribute | Value | Forcing effect |
|---|---|---|
| Security fix | Y/N — <detail> | <none / NO-GO> |
| High-risk components | Y/N — <which> | <none / NO-GO> |
| Data migration / schema change | Y/N — <detail> | <none / NO-GO> |
| API contract break | Y/N — <detail> | <none / NO-GO> |
| UI contract change | Y/N — <detail> | <none / NO-GO> |
| Behavior change for existing users | Y/N — <detail> | <none / NO-GO> |
| Backward-compat break | Y/N — <detail> | <none / REVIEW REQUIRED> |
| Components involved | <list> | — |

## Complexity Inputs
| Dimension | Level | Rationale |
|---|---|---|
| Diffusion | Low/Med/High | <one line> |
| Blast Radius | Low/Med/High | <one line> |
| Complexity | Low/Med/High | <one line — note the +1 bump if plan-only> |
| Testability | Low/Med/High | <one line> |

**Interim verdict (Steps 1+2):** GO | REVIEW REQUIRED | NO-GO — <which rule decided it>

## Regression
<table; coverage-gap count; demotion applied y/n>

## Requirements
<table; unaddressed list; demotion applied y/n>

## Recommendation
<One paragraph. Final verdict with reasoning. Call out every demotion that fired and which forcing rule or dimension drove the verdict. If forced upward by a Partial requirement or coverage gap, say so explicitly.>
```

## Calibration Examples

| Issue shape | Verdict | Driver |
|---|---|---|
| Fix duplicated word in an error message | GO | All Low |
| Add a missing null check in a single method | GO | All Low |
| Fix a misaligned button on the admin page | GO | UI bug fix, not a contract reshape |
| Fix a config-object copy constructor + a template file across 2 repos | REVIEW REQUIRED | Diffusion = Medium |
| Add a non-breaking REST response field used by one client flow | REVIEW REQUIRED | Backward-compat = N but behavior change forces a glance |
| Change token validation logic in the auth layer | NO-GO | Security fix forcing rule |
| Database schema migration to add a column | NO-GO | Data migration forcing rule |
| Reshape the publisher navigation menu | NO-GO | Intentional UI contract reshape |
| Multi-node clustered deployment bug, can't reproduce locally | NO-GO | Testability = High |
| Caching race condition in shared throttle counter | NO-GO | Complexity = High |

## Rules

- Forcing rules are non-negotiable. Don't quietly soften them when they're inconvenient.
- Crucial-component involvement → NO-GO regardless of diff size.
- Can't auto-verify → can't auto-fix. Testability = High → NO-GO.
- Read the actual source before scoring dimensions. Don't score from the issue description alone.
- Demotions only; gates never promote.
- The artifact must stand on its own — a human reviewer or a different agent should be able to understand the verdict without re-doing the analysis.
