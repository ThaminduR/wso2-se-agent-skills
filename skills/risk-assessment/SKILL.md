---
name: risk-assessment
description: Decide whether a bug fix is safe for an AI agent to auto-implement. Produces a GO / REVIEW REQUIRED verdict.
user-invocable: true
argument-hint: "[Issue number]"
---

# /risk-assessment — Auto-fix Safety Gate

You are a Senior Software Engineer assessing whether a bug fix is safe for an AI agent to implement autonomously. Read the artifacts, classify the change against explicit forcing rules, score the complexity inputs, then emit one of two verdicts: **GO** or **REVIEW REQUIRED**.

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

Fill in every row before scoring complexity. **When uncertain, mark Y.** Each forcing rule is non-negotiable — every Y must be called out in the report even though the worst it can do is force REVIEW REQUIRED.

| Attribute | Value | Forcing rule |
|---|---|---|
| Security fix (auth, authz, tokens, encryption, sessions, input sanitization) | Y/N — <detail> | Y → **REVIEW REQUIRED** |
| High-risk components (auth, request routing core, token validation, encryption, TLS, or any component the project `CLAUDE.md` lists as critical) | Y/N — <which> | Y → **REVIEW REQUIRED** |
| Data migration / schema change (column / type / constraint / semantic-index change) | Y/N — <detail> | Y → **REVIEW REQUIRED** |
| API contract break (signature, response shape, status code, required field) | Y/N — <detail> | Y → **REVIEW REQUIRED** |
| UI contract change | Y/N — <detail> | Intentional flow/layout/navigation reshape → **REVIEW REQUIRED**; visual bug fix (missing button, misaligned label) → ok |
| Behavior change for existing users | Y/N — <detail> | Judgment-call ("should probably return empty list instead of 404") → **REVIEW REQUIRED**; unambiguous return-to-spec → ok |
| Backward-compat break | Y/N — <detail> | Y → **REVIEW REQUIRED** |
| Components involved (full list) | <list> | — |

If any forcing rule fires, the interim verdict is **REVIEW REQUIRED**; record every rule that fired in the report and continue to Step 2 to fill in the complexity profile (Step 2 cannot demote further, but the dimensions still document why review is needed).

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

- **All Low** → **GO**
- **Any Medium or High in any dimension** → **REVIEW REQUIRED**

Any High dimension is a signal to call out explicitly in the Recommendation — Complexity = High means root cause confidence is shaky, Testability = High means automated verification won't be reliable, Diffusion / Blast Radius = High mean a wider area is in play. The verdict still caps at REVIEW REQUIRED; the report body must make the severity readable to a human reviewer.

Take the strongest verdict from Step 1 and Step 2 as the **interim verdict**. Carry it to Step 3.

## Step 3: Demotion Gates

Gates only demote (GO → REVIEW REQUIRED). They never promote, and REVIEW REQUIRED is the floor.

**Regression analysis** — minimum one row. "None" is only acceptable for truly isolated changes (e.g., fixing a doc typo); justify it.

| What could regress | Why the fix could cause it | Existing test that protects | Mitigation in /fix or /verify-fix |
|---|---|---|---|
| <behavior> | <mechanism> | <test path / "coverage gap"> | <what to do> |

→ 2+ `coverage gap` rows → demote to **REVIEW REQUIRED**.

**Requirement coverage** — every explicit ask from the issue, comments, and referenced issues/PRs. Don't silently drop requirements because they look out of scope.

| Requirement | Source | Status |
|---|---|---|
| <requirement> | Issue / Comment by @user / Referenced #N | Addressed / Partial / Not Addressed |

→ Any Partial / Not Addressed → **REVIEW REQUIRED**.
→ Conflicting requirements (two parties want opposite behavior) → **REVIEW REQUIRED**, and call out the conflict explicitly in the Recommendation so a human can arbitrate.

## Step 4: Write `.ai/risk-assessment-<n>.md`

```markdown
# Risk Assessment — Issue #<n>: <title>

**Verdict:** GO | REVIEW REQUIRED
**Inputs:** `ia-<n>.md` <y/n>, `plan-<n>.md` <y/n>
<If both exist and disagree on root cause or scope, describe the disagreement here.>

## Change Metadata
| Attribute | Value | Forcing effect |
|---|---|---|
| Security fix | Y/N — <detail> | <none / REVIEW REQUIRED> |
| High-risk components | Y/N — <which> | <none / REVIEW REQUIRED> |
| Data migration / schema change | Y/N — <detail> | <none / REVIEW REQUIRED> |
| API contract break | Y/N — <detail> | <none / REVIEW REQUIRED> |
| UI contract change | Y/N — <detail> | <none / REVIEW REQUIRED> |
| Behavior change for existing users | Y/N — <detail> | <none / REVIEW REQUIRED> |
| Backward-compat break | Y/N — <detail> | <none / REVIEW REQUIRED> |
| Components involved | <list> | — |

## Complexity Inputs
| Dimension | Level | Rationale |
|---|---|---|
| Diffusion | Low/Med/High | <one line> |
| Blast Radius | Low/Med/High | <one line> |
| Complexity | Low/Med/High | <one line — note the +1 bump if plan-only> |
| Testability | Low/Med/High | <one line> |

**Interim verdict (Steps 1+2):** GO | REVIEW REQUIRED — <which rule or dimension decided it; list every forcing rule that fired and every High dimension>

## Regression
<table; coverage-gap count; demotion applied y/n>

## Requirements
<table; unaddressed list; demotion applied y/n>

## Recommendation
<One paragraph. Final verdict with reasoning. List every forcing rule that fired, every High dimension, every coverage gap, and every Partial / Not Addressed / conflicting requirement. The verdict caps at REVIEW REQUIRED; this paragraph is where severity actually gets communicated to the human reviewer — be specific about what they need to scrutinize and why.>
```

## Calibration Examples

| Issue shape | Verdict | Driver |
|---|---|---|
| Fix duplicated word in an error message | GO | All Low |
| Add a missing null check in a single method | GO | All Low |
| Fix a misaligned button on the admin page | GO | UI bug fix, not a contract reshape |
| Fix a config-object copy constructor + a template file across 2 repos | REVIEW REQUIRED | Diffusion = Medium |
| Add a non-breaking REST response field used by one client flow | REVIEW REQUIRED | Behavior change for existing users |
| Change token validation logic in the auth layer | REVIEW REQUIRED | Security fix forcing rule (call out auth-layer scrutiny in Recommendation) |
| Database schema migration to add a column | REVIEW REQUIRED | Data migration forcing rule (call out migration reversibility in Recommendation) |
| Reshape the publisher navigation menu | REVIEW REQUIRED | Intentional UI contract reshape |
| Multi-node clustered deployment bug, can't reproduce locally | REVIEW REQUIRED | Testability = High (call out manual verification need in Recommendation) |
| Caching race condition in shared throttle counter | REVIEW REQUIRED | Complexity = High (call out shaky root cause in Recommendation) |

## Rules

- Forcing rules are non-negotiable. Don't quietly soften them when they're inconvenient — every Y must be recorded even though the verdict caps at REVIEW REQUIRED.
- The verdict has only two values (GO, REVIEW REQUIRED). Severity lives in the report body — every fired forcing rule, every High dimension, every coverage gap, and every unaddressed requirement must be listed in the Recommendation.
- Crucial-component involvement → REVIEW REQUIRED, and explicitly tell the reviewer why the area is sensitive.
- Can't auto-verify → flag it loudly. Testability = High → REVIEW REQUIRED with an explicit note that automated verification will not be reliable.
- Read the actual source before scoring dimensions. Don't score from the issue description alone.
- Demotions only; gates never promote.
- The artifact must stand on its own — a human reviewer or a different agent should be able to understand the verdict (and, more importantly, what specifically to scrutinize) without re-doing the analysis.
