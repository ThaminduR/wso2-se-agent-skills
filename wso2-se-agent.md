# WSO2 SE Agent — CLI Design Document

> An AI-assisted CLI that automates reproducing, fixing, verifying, and raising PRs for GitHub issues across WSO2 products.

---

## 1. Overview

Engineering teams spend significant time on repetitive mechanics whenever a customer-reported GitHub issue comes in: cloning the right repositories for the right product version, wiring up the correct AI skills and `CLAUDE.md`, reproducing the bug, proposing a fix, verifying it, writing tests, and opening a PR.

This tool wraps that flow into a single, phased CLI so an engineer can go from **issue link → PR** with a predictable, inspectable, resumable workflow — while keeping full human control over each phase.

Skills already exist and are maintained in [`wso2-se-agent-skills`](https://github.com/Tharsanan1/wso2-se-agent-skills). This CLI is the orchestrator that consumes them.

---

## 2. Name

**`wso2-se-agent`** 

---

## 3. Command Shape

```
wso2-se-agent \
  --product   <product-name>     # e.g. apim, is, mi, apk
  --version   <version>          # e.g. 4.3.0
  --issue     <issue-url>        # e.g. https://github.com/wso2/api-manager/issues/1234
  [--workspace <path>]           # defaults to ./wse-workspace/<issue-id>
  [--phase     <phase>]          # run ONE phase only
  [--from      <phase>]          # run FROM this phase to the end
  [--to        <phase>]          # stop after this phase (pairs with --from)
  [--setup]                      # shorthand for --from prereq --to skills
  [--auto-fix]                   # shorthand for --from reproduce --to pr; pauses between AI phases
  [--max-turns  <n>]             # per-phase turn limit for Claude (overrides recipe defaults)
  [--yes]                        # non-interactive; skip confirmations
  [--dry-run]                    # show the plan without executing
  [--verbose | -v]
```

### Flag precedence

1. `--phase` (single phase) beats everything else.
2. `--setup` / `--auto-fix` are sugar over `--from` / `--to`.
3. `--from` without `--to` runs to the end.
4. No phase flag → run **all** phases end-to-end.
5. `--auto-fix` pauses for human review between each AI-backed phase. Pass `--yes` to skip all pauses and run fully unattended.

---

## 4. Phase Architecture

Phases come in **two kinds**:

### Kind 1 — Static phases

Pure deterministic CLI code. No Claude invocation. These handle mechanical setup work where AI reasoning adds no value and would only introduce variance. `prereq`, `workspace`, and `skills` are all static phases.

### Kind 2 — AI-backed phases

Three sequential stages:

1. **Static pre-work.** Deterministic checks, cleanup, and modifications that prepare the workspace for Claude. Examples: deleting stale reproduction artifacts so Claude doesn't trust outdated evidence; resetting a dirty working tree; rebuilding the product before a verification run; confirming the inputs this phase needs are actually present in `.wse-state.json`.
2. **Claude headless invocation.** The CLI shells out to Claude non-interactively (`claude -p "<short prompt>" --output-format json`, or the equivalent SDK call) inside the prepared workspace. The prompt is short and points Claude at the right skill; the skill itself carries the detailed instructions. stdout/stderr are tee'd to `<workspace>/.wse/logs/<phase>-<timestamp>.log`. Structured results go back into `.wse-state.json`.
3. **Static post-work.** Verify that the expected artifacts exist (a `plan.md`, a new branch, a green test run) before marking the phase successful. If verification fails, the phase fails even if Claude exited 0.

`reproduce`, `plan-and-fix`, `verify`, `test-coverage`, and `pr` are all AI-backed phases.

### Why this split matters

It keeps AI out of decisions it shouldn't make. Choosing a free port, for instance, is a deterministic problem — the CLI scans and picks. Teaching a skill to do that would waste tokens and introduce flakiness. So port selection lives in the static `skills` phase, which writes the resulting offset into `CLAUDE.md`. Later AI-backed phases (`reproduce`, `verify`) read that offset and start the product consistently.

The general rule: **if the decision is rule-based, it belongs in static code. If it requires reading unstructured context and judging, it belongs in a skill.**

---

## 5. Phases

| # | Phase ID | Kind | What happens |
|---|---|---|---|
| 1 | `prereq` | Static | Environment check; fails fast |
| 2 | `workspace` | Static | Clone/reset repos per recipe |
| 3 | `skills` | Static | Install skills, allocate ports, generate `CLAUDE.md` |
| 4 | `reproduce` | AI-backed | Run the `reproduce` skill |
| 5 | `plan-and-fix` | AI-backed | Run the `plan-and-fix` skill |
| 6 | `verify` | AI-backed | Run the `verify-fix` skill |
| 7 | `test-coverage` | AI-backed | Run the `create-test-coverage` skill |
| 8 | `pr` | AI-backed | Run the `send-pr` skill |

---

### Phase 1 — `prereq` *(static)*

Fails loudly if anything required is missing. No side effects.

- Required binaries: `git`, `java` (version per recipe), `mvn`, `node`/`npm` (for portal-UI products), `docker` (optional), `gh` CLI, `claude` CLI.
- Required env/auth: `GITHUB_TOKEN` or active `gh auth`; `ANTHROPIC_API_KEY` or Claude Code login.
- Network reachability: `github.com`, `api.anthropic.com`, Maven Central.
- Disk: ≥ N GB free in workspace path (varies by product recipe).
- Git identity (`user.name`, `user.email`) configured.

Output: a one-screen pass/fail table; exits non-zero on any `FAIL`.

---

### Phase 2 — `workspace` *(static)*

Given `<product>` + `<version>`, looks up the recipe at `recipes/<product>/<version>.yaml` which declares:

- Which repos to clone (e.g. `wso2/carbon-apimgt`, `wso2/product-apim`, `wso2/apim-apps`).
- The branch/tag to check out per repo for that version.
- Any submodule / LFS steps.
- Default build and test commands (used by later phases).

Clones into `<workspace>/repos/<repo-name>`. If already cloned, fetches and resets to the correct ref — after confirming there are no uncommitted changes (unless `--yes`).

---

### Phase 3 — `skills` *(static)*

This is the phase that turns the workspace into a Claude-ready environment. All deterministic, no AI call.

1. **Fetch the skill pack.** Based on product + version, pulls the right folder from `wso2-se-agent-skills` (e.g. `api-manager-specific/v3`) into `<workspace>/.claude/skills/`. Pinned to a recipe-declared commit SHA for reproducibility.
2. **Allocate ports.** Scans for a free contiguous range on the host and picks a **port offset** that will keep the product off any already-bound ports.
3. **Generate `CLAUDE.md`.** Writes a workspace-root `CLAUDE.md` that includes:
   - Product, version, issue link, issue title/body/labels (pulled from the GitHub API).
   - The cloned repos and their roles.
   - The allocated port offset and the resulting URLs (management console, gateway, etc.) — so every AI-backed phase starts the product the same way.
   - Build/test commands pulled from the recipe.
   - Branch naming and PR template conventions.
   - Pointers to each installed skill.
4. **Initialize state.** Writes `.wse-state.json` with the inputs later phases will consume.

At the end of Phase 3, `claude` can be run inside the workspace by hand and Just Works — regardless of whether the user continues with `--auto-fix`.

---

### Phase 4 — `reproduce` *(AI-backed)*

**Static pre-work.** Delete any prior `.wse/reproduction/` artifacts. Confirm the product is buildable (quick sanity build if needed). Ensure the port offset from Phase 3 is still free; re-allocate and rewrite `CLAUDE.md` if not.

**Claude headless.** Invokes the `reproduce` skill.

**Static post-work.** Confirm a reproduction script/step-list and evidence (logs, stack traces, screenshots) were produced under `.wse/reproduction/`. Record pass/fail verdict in `.wse-state.json`. If the bug could not be reproduced, halt the pipeline and surface what was tried.

---

### Phase 5 — `plan-and-fix` *(AI-backed)*

**Static pre-work.** Verify `.wse/reproduction/` exists and contains a positive repro (otherwise fail with *"run `--phase reproduce` first"*). Confirm all repo working trees are clean; abort if not (unless `--yes`). Delete any prior `.wse/plan.md` so Claude produces a fresh one.

**Claude headless.** Invokes the `plan-and-fix` skill. The skill writes `.wse/plan.md`, waits for confirmation (unless `--yes`), then applies code changes to the relevant repo(s).

**Static post-work.** Confirm `.wse/plan.md` exists and at least one repo has uncommitted changes. Record touched files in `.wse-state.json`.

---

### Phase 6 — `verify` *(AI-backed)*

**Static pre-work.** Rebuild the affected repos using recipe-provided commands. Stop any previously running product instance. Re-check the port offset is free.

**Claude headless.** Invokes the `verify-fix` skill: re-runs the reproduction from Phase 4 against the patched build and runs the repo's existing test suites to check for regressions.

**Static post-work.** Parse the skill's structured result; mark the phase failed if the repro still reproduces or if regressions were introduced.

---

### Phase 7 — `test-coverage` *(AI-backed)*

**Static pre-work.** Detect the test framework and directories via the recipe. Capture a baseline test count.

**Claude headless.** Invokes the `create-test-coverage` skill: adds a regression test for the specific bug, plus broader coverage on the surrounding surface area where sensible, and runs the new tests.

**Static post-work.** Confirm test count increased and all new tests pass. Otherwise fail the phase.

---

### Phase 8 — `pr` *(AI-backed)*

**Static pre-work.** Verify there are committed or stage-able changes in at least one repo. Ensure the user's fork remote is configured (offer to add it if not). Check branch naming against the recipe's convention.

**Claude headless.** Invokes the `send-pr` skill: creates the branch, commits with a structured message, pushes to the fork, opens a PR against the correct upstream branch with issue link, root cause, fix summary, test evidence, and a checklist.

**Static post-work.** Confirm a PR URL was returned and record it in `.wse-state.json`. No auto-merge — the human reviews and clicks.

---

## 6. Phase Selection & Resumption

All phases share `.wse-state.json`, so any phase can be re-run in isolation as long as its inputs exist.

```bash
# Full end-to-end
wso2-se-agent --product apim --version 4.3.0 --issue <url>

# Setup only (first three phases), then work in Claude interactively
wso2-se-agent --product apim --version 4.3.0 --issue <url> --setup

# Skip setup (workspace already exists), jump straight to fixing
wso2-se-agent --from reproduce

# Re-run just the PR phase after editing the plan manually
wso2-se-agent --phase pr

# Run everything from verify onward (useful after a manual code tweak)
wso2-se-agent --from verify

# Preview what would happen
wso2-se-agent --product apim --version 4.3.0 --issue <url> --dry-run
```

When a phase is invoked out of order, the static pre-work checks `.wse-state.json` for the artifacts it needs and fails with a precise message — e.g. running `--phase pr` without a committed fix prints *"No changes found in any repo. Run `--phase plan-and-fix` first, or commit your manual changes."*

---

## 7. Example End-to-End Session

```bash
$ wso2-se-agent \
    --product apim \
    --version 4.3.0 \
    --issue https://github.com/wso2/api-manager/issues/1234

[1/8] prereq          ✓  static  — git, java 11, mvn 3.9, gh, claude present
[2/8] workspace       ✓  static  — cloned carbon-apimgt@v4.3.0, product-apim@v4.3.0
[3/8] skills          ✓  static  — installed api-manager-specific/v3, port offset 100, wrote CLAUDE.md
[4/8] reproduce       ✓  claude  — bug reproduced, evidence in .wse/reproduction/
                      ▸  pause   — review reproduction at .wse/reproduction/. Continue? [Y/n]
[5/8] plan-and-fix    ▸  claude  — plan ready at .wse/plan.md, review? [Y/n]
                      ✓           applied 3 edits to carbon-apimgt
                      ▸  pause   — review changes before verification. Continue? [Y/n]
[6/8] verify          ✓  claude  — repro now passes, 0 regressions in 412 tests
                      ▸  pause   — review verification results. Continue? [Y/n]
[7/8] test-coverage   ✓  claude  — added 2 unit tests, 1 integration test
                      ▸  pause   — review new tests. Continue? [Y/n]
[8/8] pr              ✓  claude  — opened https://github.com/wso2/carbon-apimgt/pull/5678
```

---

## 8. Cost Guardrails

AI-backed phases run headless with no human in the loop — a single runaway phase can burn through tokens fast. In early testing across 15 APIM issues, one issue (`4856`) consumed **$49.98** across 4 attempts, with a single `plan-and-fix` phase hitting **253 turns / $24.14** before being stopped. The successful attempt only cost $8.65.

### Turn limits

Each AI-backed phase has a default `max_turns` defined in the product recipe:

```yaml
phase_limits:
  reproduce:     { max_turns: 60 }
  plan-and-fix:  { max_turns: 120 }
  verify:        { max_turns: 60 }
  test-coverage: { max_turns: 80 }
  pr:            { max_turns: 30 }
```

These defaults are based on observed successful runs. The CLI passes `--max-turns <n>` to every `claude -p` invocation. The `--max-turns` CLI flag overrides the recipe default for all phases in that run.

### Behavior on limit hit

When Claude reaches the turn limit, the CLI:

1. Captures whatever partial output exists.
2. Marks the phase as `failed:turn_limit` in `.wse-state.json`.
3. Logs the turn count and estimated cost at that point.
4. Moves on to static post-work (which will likely fail artifact checks, confirming the phase didn't complete).

This prevents silent cost accumulation. The user can then inspect logs, adjust limits, and re-run the phase.

---

## 9. Implementation Notes

- **Language.** Node.js (TypeScript) or Python. TypeScript + `oclif`/`commander` fits the subcommand ergonomics. Python is simpler to distribute as a wheel. No strong preference — pick whichever the team maintains more.
- **Product recipes.** Declarative YAML under `recipes/<product>/<version>.yaml`. Adding a new product or version = adding a recipe file; no code change.
- **Skills fetch.** Pin the `wso2-se-agent-skills` commit SHA in each recipe so behavior is reproducible across CLI versions.
- **Headless Claude invocation.** Prefer `claude -p --output-format json --max-turns <n>` so static post-work can parse structured results and runaway phases are bounded. Fall back to stdout scraping only where necessary.
- **State file.** `.wse-state.json` is the contract between phases. Version the schema from day one.
- **Logs.** Every phase tees output to `<workspace>/.wse/logs/<phase>-<timestamp>.log`. Essential for debugging AI-backed phases after the fact.
- **Confirmations.** `--auto-fix` pauses for human review between each AI-backed phase by default. Any phase that writes code (`plan-and-fix`, `test-coverage`), mutates git (`pr`), or resets a dirty repo (`workspace`) also prompts individually. `--yes` skips all pauses and confirmations for fully unattended runs.
- **Exit codes.** `0` success, `1` user error, `2` prereq failure, `3` static pre/post-work failure, `4` Claude-invocation failure — so CI wrappers can react differently.

---

## 10. Open Questions

1. Do we support multi-issue batches (`--issues issues.txt`) in v1, or defer?
2. Where does the tool live — a new `wso2/wso2-se-agent` repo, or under the existing skills repo?
3. How are product recipes kept in sync with new product releases? *(Suggest: a CI job in the skills repo that validates recipes monthly.)*
4. Should static post-work have the ability to re-invoke Claude with corrective feedback ("your plan.md is missing a root-cause section, try again")? Or is that a skill-level concern?
