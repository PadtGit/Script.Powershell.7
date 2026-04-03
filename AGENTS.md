# Script.Powershell.7 Playbook

## Project Snapshot

- This checkout tracks `origin` `PadtGit/Script.Powershell.7` on branch `main`.
- Use `PowerShell Script/*` as the canonical script tree for this repo.
- `pwsh` 7 is the default validation engine for this repo, and the maintained high-risk scripts now have preferred V7 surfaces under `PowerShell Script/V7/`.
- Git metadata and `git.exe` are available in this workspace.
- `PLANS.md` is the standing repo-local ExecPlan rules file, and `plan.md` is the current worked example.
- Generated validation output belongs under `artifacts/validation/`, not tracked repo result files.
- Prefer small, reversible changes over bulk rewrites.
- Runtime storage roots and the sandbox working folder still use the label `sysadmin-main`; treat that as a stable runtime name, not the repo name.

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan from design through implementation. In this repository, ExecPlans are described in `PLANS.md` at the repository root.

## Canonical Layout

- `PowerShell Script/*`: primary script tree for this checkout.
- `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1`: V7 network reset and reboot script.
- `PowerShell Script/V7/windows-maintenance/Move-OrphanedInstallerFiles.ps1`: V7 installer orphan move script.
- `PowerShell Script/V7/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1`: V7 advanced cleanup script.
- `PowerShell Script/V7/Printer/Restart.Spool.DeletePrinterQSimple.ps1`: V7 simple spool cleanup script.
- `PowerShell Script/V7/Printer/restart.SpoolDeleteQV4.ps1`: V7 logged spool cleanup script.
- `tests/*`: Pester coverage for current scripts and tooling.
- `PLANS.md`: repo-local ExecPlan rules.
- `plan.md`: current worked ExecPlan example.
- `Invoke-WhatIfValidation.ps1`: fixed-list `-WhatIf` validator.
- `tools/Invoke-PSScriptAnalyzer.ps1`: analyzer helper that writes text, JSON, and SARIF artifacts.
- `tools/Invoke-CIValidation.ps1`: shared validation runner used by local CI-style checks and GitHub Actions.
- `tools/PSScriptAnalyzerSettings.psd1`: canonical analyzer settings.
- `.github/workflows/powershell-validation.yml`: Windows GitHub Actions workflow that runs the repo validation suite and uploads artifacts.
- `sandbox/sysadmin-main-validation.wsb`: local Windows Sandbox profile for risky manual validation.
- `artifacts/validation/Invoke-SandboxWhatIfValidation.ps1`: generated helper that runs the current high-risk `-WhatIf` set inside Windows Sandbox.
- `artifacts/validation/sandbox-whatif-validation.wsb`: generated Windows Sandbox profile for automated `-WhatIf` capture.
- `artifacts/validation/Copy-SandboxWhatIfOutput.ps1`: generated helper that copies the writable Sandbox output folder back into repo artifacts.
- `docs/windows-sandbox-validation.md`: manual sandbox flow.
- `docs/sysadmin-main-multi-agent-sop.md`: longer maintenance notes for this checkout.
- `SKILL.md`: repo entrypoint that summarizes the local maintenance workflow.
- `README.md`: brief repo overview and doc entrypoints.
- This checkout does not currently include local `.agents/` or `.codex/agents/` surfaces. Keep docs truthful to what exists in-tree, including `.github/workflows/powershell-validation.yml`.

## Safety Invariants

- Preserve truthful `#Requires -Version ...` declarations.
- Preserve `[CmdletBinding(SupportsShouldProcess = $true)]` on scripts that change system state.
- Preserve each file's existing strict-mode and `$ErrorActionPreference` intent unless the task explicitly changes it.
- Keep admin-only work gated so `-WhatIf` remains usable wherever a script already supports safe preview without elevation.
- Keep exit-code behavior and structured result objects stable unless the task explicitly changes contract.
- Prefer summary-style output and optional logging over noisy item-by-item transcript behavior by default.
- When workflow wording changes, keep `AGENTS.md`, `SKILL.md`, `README.md`, `docs/*`, and `sandbox/*` aligned in the same change set.

## Validation Commands

- Targeted preview:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'PowerShell Script\V7\<category>\<script>.ps1' -WhatIf
```

- Fixed-list validator:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File '.\Invoke-WhatIfValidation.ps1'
```

- Analyzer helper:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PSScriptAnalyzer.ps1' `
  -Path . `
  -Recurse `
  -SettingsPath '.\tools\PSScriptAnalyzerSettings.psd1' `
  -EnableExit `
  -ExitCodeMode AllDiagnostics
```

- Basic Pester helper:

```powershell
Invoke-Pester -Path .\tests
```

- CI-style Pester with NUnit XML output:

```powershell
$resultPath = Join-Path $PWD 'artifacts\validation\pester-results.xml'
New-Item -ItemType Directory -Force -Path (Split-Path -Path $resultPath -Parent) | Out-Null
$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = $resultPath
$config.TestResult.OutputFormat = 'NUnitXml'
Invoke-Pester -Configuration $config
```

- Shared CI validation runner:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-CIValidation.ps1'
```

- Trusted local smoke checks:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\V7\Printer\Restart.Spool.DeletePrinterQSimple.ps1' -WhatIf
pwsh -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\V7\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1' -WhatIf
```

- Windows Sandbox launch:

```powershell
Start-Process '.\sandbox\sysadmin-main-validation.wsb'
```

- Automated sandbox `-WhatIf` launch:

```powershell
Start-Process '.\artifacts\validation\sandbox-whatif-validation.wsb'
```

- Sandbox output sync:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\artifacts\validation\Copy-SandboxWhatIfOutput.ps1'
```

- Remote workflow note:
  This checkout now includes `.github/workflows/powershell-validation.yml`, which runs the shared validation suite on future `push`, `pull_request`, and `workflow_dispatch` events after the change is pushed. Keep the local commands above as the fallback path when Actions is unavailable.

## Maintenance Loop

1. Explore
   - Read this playbook and `PLANS.md` first.
   - If the task is substantial, create or update `plan.md` so the work has a living execution plan before implementation begins.
   - Inspect the exact script, test, tool, and doc surfaces you plan to touch.
   - Use Git history for change analysis; do not substitute file timestamps for commit windows.
2. Implement
   - Make the smallest defensible patch.
   - Keep runtime contracts, `-WhatIf` behavior, and storage-root conventions stable unless the task explicitly changes them.
3. Extend tests when behavior changes
   - Prefer behavioral Pester coverage over brittle string-output assertions.
   - Add or refresh tests when result objects, `-WhatIf` safety, path trust, or service-control behavior changes.
4. Validate locally
   - Run the repo-wide analyzer helper.
   - Run the CI-style Pester configuration that writes to `artifacts/validation/pester-results.xml`.
   - Run the trusted smoke checks and `Invoke-WhatIfValidation.ps1` as appropriate for the change.
5. Use Windows Sandbox for risky manual checks
   - Launch `sandbox/sysadmin-main-validation.wsb` for non-`WhatIf` validation of risky cleanup, installer, or network-reset scripts.
   - Launch `artifacts/validation/sandbox-whatif-validation.wsb` when you want the Sandbox to run the current high-risk `-WhatIf` set automatically.
   - Sync the writable Sandbox output folder back into `artifacts/validation/sandbox-whatif-output/` with `artifacts/validation/Copy-SandboxWhatIfOutput.ps1`.
   - Keep the host mapping read-only and treat the sandbox as disposable.
6. Sync docs
   - Re-read the entrypoint docs and sandbox instructions after workflow wording changes.
   - Remove stale repo, branch, or path references before closing the task.

## Known Pitfalls and Discoveries

- This repo origin is `PadtGit/Script.Powershell.7` on branch `main`; do not document `PadtGit/sysadmin` or `--ref Powershell.5` as the local workflow here.
- `.github/workflows/powershell-validation.yml` is the current GitHub Actions validation entrypoint for this checkout; keep it aligned with the local commands and `tools\Invoke-CIValidation.ps1`.
- Imported files may carry `Zone.Identifier`; validation commands should keep `-ExecutionPolicy Bypass` even after local MOTW cleanup.
- Generated validation logs belong in `artifacts/validation/`; do not reintroduce tracked root-level result files.
- The standard analyzer baseline is the repo-wide recursive command using `tools\Invoke-PSScriptAnalyzer.ps1` with `tools\PSScriptAnalyzerSettings.psd1`, `-EnableExit`, and `-ExitCodeMode AllDiagnostics`.
- Pin PSScriptAnalyzer to version `1.25.0`; do not float to newer versions without an intentional repo update.
- `tools\Invoke-PSScriptAnalyzer.ps1` writes to `artifacts/validation/psscriptanalyzer.txt`, `artifacts/validation/psscriptanalyzer.json`, and `artifacts/validation/psscriptanalyzer.sarif` by default.
- Pester 5 does not support combining `-CI` with `-Configuration`; use `New-PesterConfiguration` for CI-style NUnit XML output.
- `Invoke-WhatIfValidation.ps1` now dispatches V7 targets through `pwsh` and the remaining legacy targets through `powershell.exe`; keep new fixed-list entries honest about which engine they require.
- `sandbox\sysadmin-main-validation.wsb` should map `C:\Users\Bob\Documents\Script.Powershell.7` into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main` as read-only with networking and vGPU disabled.
- `artifacts\validation\sandbox-whatif-validation.wsb` currently uses `C:\Users\Bob\Documents\SandboxValidationOutput\Script.Powershell.7` as the writable host-mapped output folder for automated Sandbox `-WhatIf` capture.
- Automated Sandbox V7 capture depends on `pwsh.exe` being available inside the Sandbox session; the helper records per-target failures when PowerShell 7 is absent.
- Keep the in-sandbox working folder at `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`; scripts and docs still rely on the stable runtime label `sysadmin-main`.
- In service-control scripts, restart should depend on whether the current invocation actually stopped the service, not only on the initial service state.
- Security-sensitive scripts should keep trusted output-root and reparse-point protections intact when moving or deleting data.

## Improvement Notes

- 2026-03-20: Consolidated the repo around the `PowerShell Script/` tree and redirected generated validation output into `artifacts/validation/`.
- 2026-03-23: Standardized analyzer validation on the repo-wide recursive command with explicit settings and `AllDiagnostics` exit handling.
- 2026-03-25: Hardened analyzer crash handling and JSON artifact reset behavior, with dedicated tooling tests under `tests/tools/`.
- 2026-03-26: Refreshed the playbook, entrypoint docs, and Windows Sandbox profile so they describe the actual `Script.Powershell.7` checkout on `main` and the supported local validation workflow.
- 2026-03-28: Added an optional automated Windows Sandbox `-WhatIf` capture flow that writes raw output to a writable host-mapped folder and syncs it back into `artifacts/validation/sandbox-whatif-output/`.
- 2026-03-28: Added `tools\Invoke-CIValidation.ps1` and `.github/workflows/powershell-validation.yml` so future GitHub Actions runs execute analyzer, Pester, fixed-list `-WhatIf`, and trusted smoke-check validation with uploaded artifacts.
- 2026-03-30: Switched the repo to a V7-first validation flow, migrated the maintained high-risk scripts into `PowerShell Script\V7\`, and updated fixed-list validation, smoke checks, tests, and docs to prefer `pwsh`.
