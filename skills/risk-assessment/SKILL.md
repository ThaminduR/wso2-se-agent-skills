---
name: risk-assessment
description: Assess the risk and complexity of fixing an issue. Produces a 0-10 risk score, regression analysis, and requirement coverage check to gate automated fix pipelines.
user-invocable: true
argument-hint: "[Issue number]"
---

# /risk-assessment — Fix Risk & Complexity Assessment

You are a Senior Software Engineer assessing whether a bug fix is safe for an AI agent to implement autonomously. Your job is to evaluate the issue, any reproduction analysis, the proposed fix plan, and the affected codebase, then produce a calibrated risk score (0-10), a regression analysis, and a requirement coverage check.

This assessment gates the automated pipeline — a high score or unaddressed requirements halt execution and require human approval before any code is written. **Be honest and calibrated. Underscoring risk wastes engineering time on failed fixes. Overscoring blocks automation unnecessarily.**

## Input

Gather whatever context exists in `.ai/`:

- `.ai/ia-<issue_number>.md` — reproduction analysis (from `/reproduce`). Gives you runtime-verified root cause, affected components, and test coverage notes.
- `.ai/plan-<issue_number>.md` — fix plan (from `/plan`). Gives you the target repo/module, proposed change table, risks already flagged, and dev test plan.

Also read the original GitHub issue, its comments, and any referenced issues/PRs for full context.

**At least one of the two artifacts must exist.** If both are missing, stop and tell the developer to run `/reproduce` or `/plan` first — there is nothing concrete to assess.

Otherwise, proceed with whichever subset is available:

- **Both exist:** use the plan's Target + Proposed Change as the scope input; cross-check against the reproduction's root cause and evidence. If they disagree, flag it in the report.
- **Only `ia-<issue_number>.md` exists:** derive scope from the reproduction's root cause analysis and affected components (the agent will need to infer target files from the source).
- **Only `plan-<issue_number>.md` exists:** use the plan's Target and Proposed Change directly; note that the fix has not been runtime-reproduced, which itself raises Complexity risk.

If an existing artifact says the issue is **not a bug**, **not reproducible**, or **already fixed**, report that and stop — there is nothing to assess.

## Step 1: Classify the Change

Fill in the change metadata below before scoring anything. These flags are explicit inputs to the dimension scores — don't skip them and don't hand-wave the answers.

| Attribute | Value |
|-----------|-------|
| Security fix | Y / N |
| Backward-compatibility break | Y / N — <what breaks, for whom> |
| Behavior change for existing users | Y / N — <what changes> |
| API contract change (REST / WebSocket / gRPC / internal contract) | Y / N — <which> |
| UI contract change (breaking layout/flow users may have scripted around) | Y / N — <which> |
| Data migration / schema change required | Y / N — <what migration> |
| High-risk components involved (auth, Key Manager, gateway core, token validation, encryption, TLS) | Y / N — <which> |
| Components involved (full list) | <list> |

These flags drive the scoring in Step 3 and are non-negotiable:

- **Security fix = Y** → Criticality must be ≥ 2.
- **High-risk components involved = Y** → Criticality must be ≥ 2.
- **Backward-compat break = Y** → Compatibility must be ≥ 2.
- **API contract change = Y** or **UI contract change = Y** → Compatibility must be ≥ 2.
- **Data migration = Y** → Compatibility = 3 (non-negotiable).

If you can't decide a flag with confidence (e.g., you're unsure whether an internal method is exposed), mark it **Y** and explain — err toward more caution, not less.

## Step 2: Analyze Change Scope

Determine what the fix will likely require by examining:

1. **Affected files and modules.**
   - If `.ai/plan-<issue_number>.md` exists, use its **Target** and **Proposed Change** table directly — that's already the scoped file list. Do not re-derive from scratch.
   - If only `.ai/ia-<issue_number>.md` exists, trace the root cause from the reproduction artifact to the source files that need to change.
   - Either way, spot-check the source to confirm the list is complete (the plan could miss a caller, the reproduction could miss a template file).
2. **Number of repositories.** Will the fix span multiple repos (e.g., `carbon-apimgt` + `product-apim`)? The plan's Target section usually answers this; otherwise check if template files, config files, or build artifacts in other repos also need updating.
3. **Dependency graph.** Identify what depends on the code being changed — downstream callers, API consumers, template renderers, serialization paths.
4. **Change type.** Classify as one of:
   - **Cosmetic** — typo, log message, comment, docs
   - **Config** — property/config file change, feature toggle
   - **Logic** — behavioral change in a single method/class
   - **Structural** — new/renamed classes, changed method signatures, moved code
   - **Cross-cutting** — changes spanning multiple modules, layers, or repos
   - **Schema** — database migration, API contract change, wire format change

## Step 3: Score Each Risk Dimension

Evaluate each dimension independently on a 0-3 scale (0 = no risk, 1 = low, 2 = moderate, 3 = high). Use the rubrics below, and respect the forcing rules from Step 1.

### Dimension 1: Diffusion (how spread out is the change?)

| Score | Criteria |
|-------|----------|
| 0 | Single file in a single repo, one component |
| 1 | 2-5 files in a single repo, single module, one component |
| 2 | Multiple modules in a single repo, or 2 repos, or 2-3 components |
| 3 | 3+ repos, or changes span multiple architectural layers (gateway + key manager + publisher), or 4+ components |

### Dimension 2: Criticality (how sensitive is the affected area?)

| Score | Criteria |
|-------|----------|
| 0 | Docs, comments, log messages, test-only changes |
| 1 | Publisher/DevPortal UI, non-critical admin flows, error messages |
| 2 | Gateway request routing, throttling, mediation sequences, Velocity templates, API lifecycle logic |
| 3 | Authentication/authorization, Key Manager, token validation, security policies, OAuth flows, encryption/TLS, database schemas |

**Forcing rules:** `Security fix = Y` → at least 2. `High-risk components involved = Y` → at least 2.

### Dimension 3: Compatibility & Reversibility (does this break existing users, and how hard is it to undo?)

This dimension absorbs backward compatibility, behavior change, API/UI contract change, data migration, and reversibility — they're tightly coupled.

| Score | Criteria |
|-------|----------|
| 0 | Pure code change, no user-visible behavior change, no API/UI contract touched, easy to revert with a single commit |
| 1 | Minor behavior change (e.g., error message wording, log line), config/feature-toggle change that can be overridden, revert-friendly |
| 2 | Changes existing user-visible behavior, non-breaking REST response additions, UI flow change users may have scripted around, template change that requires redeploy |
| 3 | Breaking REST/UI API contract change, data migration / schema change, auth or token-semantics change, wire format change — cannot be reverted without a follow-up migration or breaking a different set of users |

**Forcing rules:** `Backward-compat break = Y` → at least 2. `API contract change = Y` or `UI contract change = Y` → at least 2. `Data migration = Y` → exactly 3.

### Dimension 4: Blast Radius (how many things could break?)

| Score | Criteria |
|-------|----------|
| 0 | Isolated utility method, no downstream callers beyond the immediate fix |
| 1 | Affects a single API flow (e.g., one specific endpoint or operation) |
| 2 | Affects all APIs of a certain type (e.g., all AI APIs, all API Products), or a shared utility used by multiple flows |
| 3 | Affects every API call through the gateway, or every tenant, or the core mediation/security pipeline |

### Dimension 5: Complexity (how hard is the fix to get right?)

| Score | Criteria |
|-------|----------|
| 0 | Obvious fix — typo, missing null check, wrong string literal |
| 1 | Straightforward logic change — clear root cause, clear fix, single code path |
| 2 | Multiple interacting components — fix requires understanding how 2-3 subsystems interact (e.g., endpoint security + template rendering + copy constructors) |
| 3 | Concurrency, caching, distributed state, OSGi classloading, or the root cause is unclear even after reproduction/planning |

**Bonus bump:** if the plan exists but no reproduction artifact exists, add +1 here (fix is untested at runtime so root-cause confidence is lower). Cap at 3.

### Dimension 6: Testability (can we prove the fix works?)

| Score | Criteria |
|-------|----------|
| 0 | Fully coverable by unit tests; no environmental dependencies |
| 1 | Needs an integration test on a standard supported deployment; all scenarios can be automated |
| 2 | Some fix scenarios are hard to automate (timing-sensitive, multi-node clustering, specific network conditions) or the target deployment option is not routinely covered by the test pipeline |
| 3 | Fix involves a user scenario that cannot be reliably test-automated, or targets a deployment option that is not supported in the standard test pipeline — verification will rely on manual testing only |

## Step 4: Compute the Risk Score

Calculate the weighted composite score:

```
raw = (Diffusion x 1.0)
    + (Criticality x 1.5)
    + (Compatibility x 1.5)
    + (Blast Radius x 1.0)
    + (Complexity x 1.0)
    + (Testability x 1.0)
max_possible = (3 x 1.0) + (3 x 1.5) + (3 x 1.5) + (3 x 1.0) + (3 x 1.0) + (3 x 1.0) = 21
risk_score = round((raw / max_possible) x 10)
```

Criticality and Compatibility are weighted 1.5x because security/high-risk components and backward-incompatible changes have outsized consequences.

**After computing, apply a sanity check.** Does the score match your gut feeling? If not, explain why in the report and adjust by at most 1 point with justification. The formula is a guide, not a prison.

### Score Interpretation

| Score | Level | Meaning |
|-------|-------|---------|
| 0-3 | Low | Safe for full automation. Typo fixes, log corrections, simple config changes. |
| 4-6 | Medium | Generally safe. Single-component logic fixes, null checks, straightforward behavioral changes. Worth a quick human glance after fix. |
| 7-8 | High | Human should review before the agent writes code. Multi-repo changes, API contracts, security-adjacent areas. |
| 9-10 | Critical | Must not auto-proceed. Database schemas, auth logic, breaking API changes, unclear root cause. Hand off to a human engineer. |

## Step 5: Identify Risk Factors

List specific risk factors that contribute to the score. For each factor, explain:
- **What** the risk is
- **Why** it matters for this specific issue
- **What could go wrong** if the fix is incorrect

Also list any **mitigating factors** that reduce risk (e.g., good test coverage exists, the change is additive-only, the affected code path is already well-understood from reproduction).

## Step 6: Regression Analysis

List the concrete regression risks of this fix — not generic "could break something", but specific behaviors that this code change could plausibly break. For each:

| What could regress | Why the fix could cause it | Existing test that protects | Dev-test / verify mitigation |
|--------------------|----------------------------|-----------------------------|------------------------------|
| <behavior/feature> | <the mechanism> | <test path, or "coverage gap"> | <what /fix or /verify-fix should do to catch it> |

**Rules:**
- At minimum one row. Writing "none" is only acceptable for truly isolated changes (e.g., fixing a doc typo) — justify it.
- If 2+ rows say "coverage gap", bump Complexity by +1 in the sanity adjustment and record it.
- Regressions flagged here must be addressed in the dev-test/verify-fix steps. Note them in the recommendation if they need human verification.

## Step 7: Requirement Coverage Check

Enumerate every implementation request from the issue, its comments, and any referenced issues/PRs. Mark whether the proposed fix (from the plan artifact or derived scope) addresses each one.

| Requirement | Source | Status |
|-------------|--------|--------|
| <requirement> | Issue body / Comment by @user / Referenced #N | Addressed / Partial / Not Addressed |

**Rules:**
- Every explicit ask in the issue thread must appear here. Don't silently drop requirements because they seem out of scope.
- If any row is **Not Addressed** or **Partial**, the recommendation must be **at least HUMAN REVIEW REQUIRED**, regardless of the computed risk score. A partial fix masquerading as a complete one is worse than no fix.
- If a request appears to conflict with another (e.g., two commenters want opposite behaviors), flag the conflict and force HUMAN REVIEW.

## Step 8: Estimate Fix Scope

Based on your analysis, estimate:
- Number of files likely to change
- Number of repos involved
- Whether a product rebuild is needed
- Whether the fix requires template/config changes alongside Java code
- Whether the fix requires data migration or schema changes
- Expected fix complexity (will the agent need many iterations or should it be straightforward?)

## Step 9: Write the Output Artifact

Create `.ai/risk-assessment-<issue_number>.md` using this exact format:

```markdown
# Risk Assessment — Issue #<issue_number>: <issue_title>

## Risk Score: <score>/10 (<level>)

## Inputs Used
- `.ai/ia-<issue_number>.md`: <yes / no>
- `.ai/plan-<issue_number>.md`: <yes / no>
- <If both exist and disagree on root cause or scope, describe the disagreement here.>

## Change Metadata

| Attribute | Value |
|-----------|-------|
| Security fix | Y / N |
| Backward-compatibility break | Y / N — <detail> |
| Behavior change for existing users | Y / N — <detail> |
| API contract change | Y / N — <detail> |
| UI contract change | Y / N — <detail> |
| Data migration / schema change | Y / N — <detail> |
| High-risk components involved | Y / N — <list> |
| Components involved | <list> |

## Dimension Scores

| Dimension | Score (0-3) | Rationale |
|-----------|-------------|-----------|
| Diffusion | <n> | <one-line explanation> |
| Criticality | <n> | <one-line explanation> |
| Compatibility & Reversibility | <n> | <one-line explanation> |
| Blast Radius | <n> | <one-line explanation> |
| Complexity | <n> | <one-line explanation> |
| Testability | <n> | <one-line explanation> |

**Weighted calculation:** (<diffusion> x 1.0) + (<criticality> x 1.5) + (<compat> x 1.5) + (<blast_radius> x 1.0) + (<complexity> x 1.0) + (<testability> x 1.0) = <raw> / 21 x 10 = <score>
**Sanity adjustment:** <none, or +/- N with justification>

## Risk Factors

- <factor 1>: <explanation of what could go wrong>
- <factor 2>: <explanation>
- ...

## Mitigating Factors

- <factor 1>: <explanation of why this reduces risk>
- ...

## Regression Analysis

| What could regress | Why | Existing test | Dev-test / verify mitigation |
|--------------------|-----|---------------|------------------------------|
| <behavior> | <mechanism> | <test path / "coverage gap"> | <mitigation> |

## Requirement Coverage Check

| Requirement | Source | Status |
|-------------|--------|--------|
| <requirement> | <issue / comment / referenced #N> | Addressed / Partial / Not Addressed |

**Unaddressed requirements:** <list any "Partial" or "Not Addressed" rows, or "none">

## Estimated Fix Scope

- **Files to change:** ~<n>
- **Repos involved:** <list>
- **Rebuild required:** Yes / No
- **Template/config changes:** Yes / No
- **Data migration / schema changes:** Yes / No
- **Expected iterations:** <low — should be straightforward / medium — may need 2-3 attempts / high — complex multi-step fix>

## Recommendation

<One of:>
- **PROCEED** — Low risk, suitable for automated fix.
- **PROCEED WITH CAUTION** — Medium risk, automated fix is reasonable but human should review the output closely.
- **HUMAN REVIEW REQUIRED** — High risk, unaddressed requirements, or regression coverage gaps. A human engineer should review the analysis and approve the fix approach before the agent proceeds.
- **HAND OFF** — Critical risk or unclear root cause. This issue should be fixed by a human engineer, not an automated agent.

<Brief explanation of why this recommendation was chosen. If forced upward by an unaddressed requirement or regression coverage gap, say so explicitly.>
```

## Important Rules

- **Never guess dimension scores.** If you cannot determine a dimension (e.g., you don't know what the affected code path touches), score it as the higher option and explain your uncertainty.
- **Read the actual source code.** Don't score based only on the issue description. Trace the root cause to the source files, check what calls the affected code, check if tests exist.
- **Honor the forcing rules.** Metadata flags drive score minima — don't quietly soften them.
- **Requirement coverage is a gate, not a suggestion.** Any "Not Addressed" or "Partial" row forces HUMAN REVIEW REQUIRED at minimum.
- **Regression coverage gaps are a gate.** 2+ "coverage gap" entries bump Complexity by +1 (sanity adjustment).
- **Calibration examples for reference:**
  - Fixing a duplicated word in an error message string → **1/10**
  - Adding a missing null check in a single method → **2/10**
  - Fixing endpoint security copy constructor + template file across 2 repos → **6/10**
  - Changing OAuth token validation logic in the Key Manager → **8/10**
  - Database schema migration to add a column used by the gateway → **9/10**
  - Fix for a multi-node clustered deployment scenario that can't be reproduced in the standard test pipeline → **8/10** (Testability drives it up)
- **Artifacts over memory.** The report must be complete enough for a human reviewer or a different agent to understand the risk without re-doing the analysis.
