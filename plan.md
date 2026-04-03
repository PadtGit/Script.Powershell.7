# Add repo-local ExecPlan docs and entrypoints

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository now has `PLANS.md` at the repository root. This document must be maintained in accordance with `PLANS.md`.

## Purpose / Big Picture

Before this change, the repository had strong maintenance notes, validation commands, and sandbox guidance, but it did not have a repo-local ExecPlan rules file or a concrete worked plan that a first-time contributor could copy. After this change, someone new to `Script.Powershell.7` can open `PLANS.md` to see exactly how plans must be written here, then open `plan.md` to see a finished example grounded in the real PowerShell paths, validation commands, and documentation sync rules used by this repo.

The result is visible without guessing. From the repository root, a reader can inspect `PLANS.md` and `plan.md`, then confirm that `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md` all point to the new planning entrypoints. That gives future changes a consistent starting place instead of relying on generic planning guidance outside the repo.

## Progress

- [x] (2026-04-02 17:19Z) Confirmed the repo did not already contain `PLANS.md` or `plan.md`.
- [x] (2026-04-02 17:19Z) Read `AGENTS.md`, `SKILL.md`, `README.md`, `docs/sysadmin-main-multi-agent-sop.md`, `docs/windows-sandbox-validation.md`, and `.github/workflows/powershell-validation.yml` so the new planning docs match the current repo workflow.
- [x] (2026-04-02 17:21Z) Added `PLANS.md` with repo-local ExecPlan rules that preserve the repo's PowerShell safety invariants, validation commands, and documentation sync expectations.
- [x] (2026-04-02 17:21Z) Wrote this `plan.md` as a concrete, self-contained example plan for introducing the workflow instead of leaving behind a placeholder-only skeleton.
- [x] (2026-04-02 17:22Z) Updated `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md` so the new planning docs are discoverable from the repo's existing entrypoints.
- [x] (2026-04-02 17:22Z) Reviewed the changed Markdown for consistency and checked the doc-only status with `git status --short`. No PowerShell scripts, tests, workflows, or sandbox profiles changed, so runtime validation was not required for this documentation-only milestone.

## Surprises & Discoveries

- Observation: The repository already had detailed maintenance and validation guidance, but it had no plan documents at all.
  Evidence:
    PS> Get-ChildItem -Recurse -File -Include PLANS.md,plan.md,*plan*.md,*PLAN*.md | Select-Object -ExpandProperty FullName
    <no output before this change>

- Observation: The existing docs were already precise enough to ground a repo-local planning workflow without inventing new commands or changing runtime behavior.
  Evidence:
    `AGENTS.md` already listed the maintained V7 scripts, analyzer command, CI-style Pester setup, fixed-list `-WhatIf` validation, trusted smoke checks, and Sandbox launch commands.

## Decision Log

- Decision: Add both `PLANS.md` and `plan.md` instead of only one file.
  Rationale: The generic ExecPlan rules refer to a standing `PLANS.md` file, and separating standing rules from the current worked example keeps future plans shorter and easier to keep accurate.
  Date/Author: 2026-04-02 / Codex

- Decision: Make `plan.md` a concrete worked example for introducing the planning workflow instead of a blank template.
  Rationale: A finished example shows a novice exactly how the required sections, prose style, milestones, and repo-specific validation details fit together. That better satisfies the self-contained requirement than a placeholder file would.
  Date/Author: 2026-04-02 / Codex

- Decision: Update the repo entrypoint docs in the same change set.
  Rationale: `AGENTS.md` explicitly asks for entrypoint docs to stay aligned when workflow wording changes, and a new planning workflow is only useful if readers can find it from the files the repo already sends them to first.
  Date/Author: 2026-04-02 / Codex

## Outcomes & Retrospective

This milestone succeeded. The repository now has a standing planning rules file in `PLANS.md`, a concrete example plan in `plan.md`, and cross-links from the usual entrypoint docs so a new contributor can discover the workflow quickly. The change stayed intentionally small and did not disturb PowerShell scripts, tests, validation tooling, GitHub Actions, or Windows Sandbox assets.

The main lesson is that this repository already had most of the hard-earned operational knowledge needed for ExecPlans; the gap was packaging that knowledge into a planning surface that future contributors can follow without prior context. Future plans should continue to reuse the validation commands and safety invariants recorded here instead of restating them loosely from memory.

## Context and Orientation

`Script.Powershell.7` is a Windows administration PowerShell repository whose canonical scripts live under `PowerShell Script/`. The maintained high-risk scripts also have preferred PowerShell 7 surfaces under `PowerShell Script/V7/`. The repo validates changes with several layers: a PSScriptAnalyzer run through `tools/Invoke-PSScriptAnalyzer.ps1`, Pester tests under `tests/`, an engine-aware fixed-list preview validator in `Invoke-WhatIfValidation.ps1`, trusted V7 `-WhatIf` smoke checks, and optional local Windows Sandbox validation for risky scripts. Generated validation artifacts belong under `artifacts/validation/`.

In this repository, `-WhatIf` means a dry run that reports what a script would do without actually doing it. That behavior matters because many scripts here can restart services, clean Windows data, move installer files, or reset networking. The docs therefore preserve strict rules around `SupportsShouldProcess`, `Set-StrictMode`, `$ErrorActionPreference`, truthful version requirements, and safe preview behavior.

Before this milestone, the repo entrypoints were `AGENTS.md`, `SKILL.md`, `README.md`, `docs/sysadmin-main-multi-agent-sop.md`, and `docs/windows-sandbox-validation.md`. They explained how to work in the repo, but none of them defined a repo-local ExecPlan format. This change adds two root docs to close that gap: `PLANS.md`, which is the standing rules file for future ExecPlans, and `plan.md`, which is the current concrete example.

## Milestones

### Milestone 1: Establish standing planning rules for the repo

Create `PLANS.md` at the repository root and fill it with the rules future ExecPlans must follow in this repository. The file must explain what an ExecPlan is, name the mandatory sections, restate the repo's PowerShell-specific safety invariants, and include the exact validation commands already used by this repo. Acceptance for this milestone is simple and observable: opening `PLANS.md` from the repo root should show a complete rule set that mentions `PowerShell Script/`, `PowerShell Script/V7/`, `tests/`, `Invoke-WhatIfValidation.ps1`, `tools/Invoke-PSScriptAnalyzer.ps1`, `tools/Invoke-CIValidation.ps1`, `artifacts/validation/`, and the local Windows Sandbox launchers.

### Milestone 2: Leave behind a worked example and surface it from the normal entrypoints

Create `plan.md` at the repository root as a complete example that tells the story of introducing the planning workflow itself. Then update the usual entrypoint docs so a novice can discover both plan files without hunting. Acceptance for this milestone is visible by reading `plan.md` and then running a targeted search that shows `PLANS.md` and `plan.md` referenced from `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md`.

## Plan of Work

The work begins at the repository root. First, add `PLANS.md` and populate it with the standing rules future contributors must follow. That file should not invent a new workflow; it should translate the repo's existing PowerShell maintenance rules into planning language. The file therefore needs to mention the canonical script tree, the preferred V7 maintenance surface, the standard validation entrypoints, the sandbox commands, the artifact location, and the rule that entrypoint docs stay aligned when workflow wording changes.

Next, add `plan.md` as the current worked example. Because the plan is about introducing ExecPlans themselves, it can describe the documentation change that creates `PLANS.md`, updates `plan.md`, and threads the new entrypoints into the existing docs. The plan must use the required living sections, include narrative milestones, and record the actual design decisions that shaped the change.

Finally, update the repo entrypoint docs that already orient new contributors. `AGENTS.md` should list the two new planning files in its canonical layout and mention them in the exploration workflow. `SKILL.md` and `README.md` should point readers to the new planning docs near the top. `docs/sysadmin-main-multi-agent-sop.md` should mention the planning docs as part of the repo-local workflow and alignment set.

## Concrete Steps

Use `C:\Users\Bob\Documents\Script.Powershell.7` as the working directory for every command below.

1. Confirm the starting state before creating any new planning docs.

    Get-ChildItem -Recurse -File -Include PLANS.md,plan.md,*plan*.md,*PLAN*.md | Select-Object -ExpandProperty FullName

   Expected result before the change: no output.

2. Read the current repo entrypoints and workflow notes so the plan stays truthful.

    Get-Content -Raw '.\AGENTS.md'
    Get-Content -Raw '.\SKILL.md'
    Get-Content -Raw '.\README.md'
    Get-Content -Raw '.\docs\sysadmin-main-multi-agent-sop.md'
    Get-Content -Raw '.\docs\windows-sandbox-validation.md'
    Get-Content -Raw '.\.github\workflows\powershell-validation.yml'

3. Create or update the planning docs and the aligned entrypoint docs.

    Edit '.\PLANS.md'
    Edit '.\plan.md'
    Edit '.\AGENTS.md'
    Edit '.\SKILL.md'
    Edit '.\README.md'
    Edit '.\docs\sysadmin-main-multi-agent-sop.md'

4. Verify that the new planning entrypoints are discoverable from the main docs.

    Select-String -Path '.\AGENTS.md','.\SKILL.md','.\README.md','.\docs\sysadmin-main-multi-agent-sop.md' -Pattern 'PLANS.md','plan.md'

   Expected result after the change: each file reports at least one match.

5. Review the scope of the documentation-only change.

    git status --short

   Expected result after the change: only Markdown documentation files appear, with modified (`M`) or untracked (`??`) status.

6. Optionally review the tracked diff summary.

    git diff --stat

   Expected result after the change: only tracked Markdown documentation files are listed.

## Validation and Acceptance

Acceptance is behavioral and visible from the repository root.

Opening `PLANS.md` must show repo-local ExecPlan rules that are specific to this PowerShell repo rather than generic software-project advice. The file must mention the canonical script tree, the maintained V7 scripts, validation entrypoints, artifact folder, and PowerShell safety rules.

Opening `plan.md` must show a complete worked example with all required living sections filled in. The file must tell a novice why the planning workflow matters here, what files changed, how to inspect the result, and how to recognize success.

Running the targeted search command from the previous section must show that `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md` all reference the new planning docs. That proves a newcomer can discover the workflow from the repo's normal entrypoints.

Running `git status --short` must show exactly the documentation files touched by this milestone: modified entrypoint docs plus the new `PLANS.md` and `plan.md` files. That is the clearest proof that this is a documentation-only change.

No analyzer, Pester, `-WhatIf`, smoke-check, or Sandbox commands are required for this milestone because no runtime PowerShell behavior changed. Future ExecPlans that change scripts, validation tooling, workflows, or sandbox behavior must embed and run those commands as appropriate.

## Idempotence and Recovery

This change is safe to repeat because it only adds and updates Markdown documentation. Re-running the discovery and search commands is safe and should converge on the same result. If a future contributor decides to rename or relocate the active plan file, they must update `PLANS.md`, `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md` together so the workflow does not become inconsistent.

If the planning docs ever drift from the actual validation workflow, recover by rereading `AGENTS.md`, `SKILL.md`, `README.md`, `docs/sysadmin-main-multi-agent-sop.md`, `docs/windows-sandbox-validation.md`, and `.github/workflows/powershell-validation.yml`, then updating the planning docs in the same change set. Because no code or generated artifacts are involved here, rollback is simply a matter of reverting the Markdown edits.

## Artifacts and Notes

Initial discovery before the change:

    PS> Get-ChildItem -Recurse -File -Include PLANS.md,plan.md,*plan*.md,*PLAN*.md | Select-Object -ExpandProperty FullName
    <no output>

Files that must exist or be updated at the end of this milestone:

    PLANS.md
    plan.md
    AGENTS.md
    SKILL.md
    README.md
    docs/sysadmin-main-multi-agent-sop.md

Status snapshot after the change:

    M AGENTS.md
    M README.md
    M SKILL.md
    M docs/sysadmin-main-multi-agent-sop.md
    ?? PLANS.md
    ?? plan.md

## Interfaces and Dependencies

This milestone introduces two root-level documentation interfaces.

- `PLANS.md` is the standing rules file for ExecPlans in this repository.
- `plan.md` is the current concrete ExecPlan example that future contributors can copy or replace for their next substantial task.

The change also depends on the repo's existing entrypoint docs continuing to describe the same workflow:

- `AGENTS.md`
- `SKILL.md`
- `README.md`
- `docs/sysadmin-main-multi-agent-sop.md`

No PowerShell modules, .NET dependencies, GitHub Actions steps, Pester tests, or Sandbox assets change in this milestone. Existing validation interfaces remain `Invoke-WhatIfValidation.ps1`, `tools/Invoke-PSScriptAnalyzer.ps1`, `tools/Invoke-CIValidation.ps1`, the `tests/` tree, and the Windows Sandbox launchers documented elsewhere.

Revision Note (2026-04-02, Codex): Created the initial repo-local ExecPlan example while introducing `PLANS.md` so future contributors have both standing planning rules and a concrete worked plan to follow.
