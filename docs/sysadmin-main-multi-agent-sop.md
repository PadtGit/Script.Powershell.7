# Script.Powershell.7 Maintenance SOP

## Why This Shape

- Keep the repo self-describing. This checkout includes `.github/workflows/powershell-validation.yml` for CI validation but still does not use the older `.agents/` or `.codex/agents/` surfaces that some earlier docs referenced.
- Use a repo-local maintenance loop: inspect, implement, test, validate locally, and sync docs.
- Keep this SOP, `AGENTS.md`, `PLANS.md`, `plan.md`, `SKILL.md`, `README.md`, `docs/windows-sandbox-validation.md`, and `sandbox/sysadmin-main-validation.wsb` aligned whenever command or workflow wording changes.

## Repo Ground Rules

- Canonical scripts live under `PowerShell Script/`.
- `PLANS.md` is the standing repo-local ExecPlan rules file, and `plan.md` is the current worked example.
- `PowerShell Script/V7/` is the preferred maintained surface for migrated high-risk scripts.
- `Invoke-WhatIfValidation.ps1` is the repo-level validator entrypoint.
- Generated validation output belongs under `artifacts/validation/`.
- `pwsh` 7 is the default validation engine, while remaining legacy scripts stay on Windows PowerShell 5.1 until they are migrated.
- Preserve each file's existing strict-mode, `$ErrorActionPreference`, and `SupportsShouldProcess` behavior.
- Prefer safe `-WhatIf` preview behavior over hard admin-only preview blocks where the script can truthfully support preview without elevation.
- Keep result objects compact and structured. Avoid noisy transcript-style output by default.
- Runtime paths may still use `sysadmin-main`; that label is stable even though the repo name is `Script.Powershell.7`.

## Current High-Risk Areas

- Service-control scripts that stop and restart `Spooler` or `wuauserv`
- Network reset or reboot scripts
- Broad Windows cleanup scripts
- Installer orphan move scripts

## Maintenance Loop

1. Explore
   - Inspect the exact file, helper, and doc surfaces involved before editing.
   - Use Git history for recent-change analysis instead of file timestamps.
2. Implement
   - Make the smallest reversible patch that preserves current contracts unless the task explicitly changes them.
3. Extend tests when behavior changes
   - Prefer behavioral Pester coverage over brittle string-output assertions.
   - Update tests when `-WhatIf`, result objects, path trust, or service-control behavior changes.
4. Validate locally
   - Run the repo-wide analyzer helper.
   - Run the CI-style Pester configuration that writes to `artifacts/validation/pester-results.xml`.
   - Run trusted smoke checks and `Invoke-WhatIfValidation.ps1` as appropriate.
5. Use Windows Sandbox for risky manual checks
   - Launch `sandbox/sysadmin-main-validation.wsb` for disposable non-`WhatIf` testing of risky scripts.
   - Keep the host mapping read-only.
   - For repeatable `-WhatIf` capture of risky scripts, launch `artifacts/validation/sandbox-whatif-validation.wsb` and then sync the mapped outputs back with `artifacts/validation/Copy-SandboxWhatIfOutput.ps1`.
6. Close with doc sync
   - Re-read the entrypoint docs after workflow wording changes.
   - Remove stale repo, branch, workflow, or filesystem references before finishing.

## Validation Surface

- Use the repo-wide recursive analyzer command with `tools\Invoke-PSScriptAnalyzer.ps1`, `tools\PSScriptAnalyzerSettings.psd1`, `-EnableExit`, and `-ExitCodeMode AllDiagnostics`.
- Use the CI-style Pester configuration that writes results to `artifacts/validation/pester-results.xml`.
- Use `Invoke-WhatIfValidation.ps1` for the engine-aware fixed-list preview validator.
- Use `tools\Invoke-CIValidation.ps1` under `pwsh` when you want the repo-local workflow entrypoint that the GitHub Actions job also runs.
- Keep smoke checks focused on the trusted V7 `-WhatIf` commands documented in `AGENTS.md`.
- Use `sandbox/sysadmin-main-validation.wsb` as the disposable validation shell for risky scripts. The profile maps `C:\Users\Bob\Documents\Script.Powershell.7` read-only into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`, disables networking and vGPU, and opens PowerShell there.
- Use `artifacts/validation/sandbox-whatif-validation.wsb` when you want the Sandbox to run the current high-risk `-WhatIf` targets automatically and emit raw output into the writable host-mapped folder that `artifacts/validation/Copy-SandboxWhatIfOutput.ps1` syncs into `artifacts/validation/sandbox-whatif-output/`.
- Inspect validation and test artifacts under `artifacts/validation/`.
- `.github/workflows/powershell-validation.yml` runs the shared validation flow on future `push`, `pull_request`, and `workflow_dispatch` events once the change is pushed.
