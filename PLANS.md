# Script.Powershell.7 ExecPlan Rules

This repository uses execution plans, shortened here to "ExecPlans", for substantial changes. An ExecPlan is a single self-contained Markdown document that explains why the change matters, which files to edit, which commands to run, what outputs prove success, and how to recover if something goes wrong. The intended reader is a complete beginner who has only this checkout and the plan file in front of them.

If an ExecPlan is committed as a standalone Markdown file in this repository, do not wrap the whole file in triple backticks. If the same plan is shared in chat, wrap it in one fenced block labeled `md` and do not nest additional triple-backtick fences inside it. Indent commands, transcripts, and snippets instead.

## Non-Negotiable Rules

Every ExecPlan in this repository must be fully self-contained. Do not assume the reader remembers earlier plans, earlier conversations, or outside documentation. Define any non-obvious term in plain language the first time you use it. In this repository, that often includes PowerShell-specific terms such as `-WhatIf`, which is PowerShell's dry-run switch that reports intended changes without performing them.

Every ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the work proceeds. At every stopping point, update the plan so a new contributor can resume from the plan alone.

Every ExecPlan must aim at observable behavior, not only changed files. State what a person can do after the work that they could not do before, how to run or inspect it, and what success looks like.

Every ExecPlan must tell the reader exactly where to work. Name repository-relative paths, PowerShell scripts, helper tools, workflow files, tests, and documentation files explicitly.

## Required Sections

Each ExecPlan in this repo must contain these sections, in plain prose unless a list is clearly the best way to stay readable:

- `Purpose / Big Picture`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Outcomes & Retrospective`
- `Context and Orientation`
- `Milestones`
- `Plan of Work`
- `Concrete Steps`
- `Validation and Acceptance`
- `Idempotence and Recovery`
- `Artifacts and Notes`
- `Interfaces and Dependencies`

`Progress` must use checkboxes with timestamps. `Milestones` must be narrative and independently verifiable. The rest of the document should stay prose-first; avoid turning the whole plan into a checklist.

## Repository Facts Every Plan Must Repeat When Relevant

ExecPlans for this repo should restate the repository facts that matter to the planned work instead of assuming the reader will discover them elsewhere.

- The canonical script tree is `PowerShell Script/`.
- `PowerShell Script/V7/` is the preferred maintained surface for migrated high-risk scripts.
- Current maintained high-risk V7 scripts include:
  `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1`,
  `PowerShell Script/V7/windows-maintenance/Move-OrphanedInstallerFiles.ps1`,
  `PowerShell Script/V7/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1`,
  `PowerShell Script/V7/Printer/Restart.Spool.DeletePrinterQSimple.ps1`,
  and `PowerShell Script/V7/Printer/restart.SpoolDeleteQV4.ps1`.
- Tests live under `tests/`.
- The fixed-list preview validator is `Invoke-WhatIfValidation.ps1`.
- The analyzer helper is `tools/Invoke-PSScriptAnalyzer.ps1`.
- The shared local and GitHub Actions validation runner is `tools/Invoke-CIValidation.ps1`.
- Analyzer settings live in `tools/PSScriptAnalyzerSettings.psd1`.
- The Windows GitHub Actions workflow is `.github/workflows/powershell-validation.yml`.
- Generated validation output belongs under `artifacts/validation/`.
- The stable sandbox/runtime label remains `sysadmin-main` even though the repo name is `Script.Powershell.7`.

## Repository Safety Rules Every Plan Must Respect

Plans for script or tool changes must preserve truthful `#Requires -Version ...` declarations, preserve `[CmdletBinding(SupportsShouldProcess = $true)]` on scripts that change system state, and preserve each file's existing `Set-StrictMode` and `$ErrorActionPreference` intent unless the task explicitly changes those contracts.

Plans must preserve safe `-WhatIf` preview behavior wherever a script already supports it without elevation. Plans should also preserve stable exit-code behavior, compact result objects, trusted output-root protections, and reparse-point protections when moving or deleting data.

When a plan changes workflow wording or repo entrypoints, it must keep `AGENTS.md`, `SKILL.md`, `README.md`, and `docs/sysadmin-main-multi-agent-sop.md` aligned in the same change set. Update `docs/windows-sandbox-validation.md` as well when sandbox commands, host paths, or automated capture behavior change.

## Validation Expectations

Validation is mandatory for work that changes script, tool, or workflow behavior. Plans must embed the exact commands that fit the task. Use the repository root, `C:\Users\Bob\Documents\Script.Powershell.7`, as the working directory unless the plan explicitly says otherwise.

Use these commands when the change affects scripts, validation tooling, or workflow behavior:

    pwsh -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PSScriptAnalyzer.ps1' -Path . -Recurse -SettingsPath '.\tools\PSScriptAnalyzerSettings.psd1' -EnableExit -ExitCodeMode AllDiagnostics

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

    pwsh -NoProfile -ExecutionPolicy Bypass -File '.\Invoke-WhatIfValidation.ps1'

Trusted local smoke checks for maintained V7 scripts are:

    pwsh -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\V7\Printer\Restart.Spool.DeletePrinterQSimple.ps1' -WhatIf

    pwsh -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\V7\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1' -WhatIf

If the plan touches risky cleanup, installer, printer, network-reset, or reboot behavior and safe preview is not enough, include the local Windows Sandbox flow as part of validation:

    Start-Process '.\sandbox\sysadmin-main-validation.wsb'

For automated Sandbox `-WhatIf` capture, use:

    Start-Process '.\artifacts\validation\sandbox-whatif-validation.wsb'

    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\artifacts\validation\Copy-SandboxWhatIfOutput.ps1'

Documentation-only plans should still include an acceptance section, but they may validate by file inspection and targeted search instead of running analyzer, Pester, or Sandbox commands when no runtime behavior changed.

## Working Style For This Repo

Prefer the smallest reversible patch that proves the desired behavior. Use Git history for change analysis instead of file timestamps. Record why you chose one path over another in `Decision Log`, especially when dealing with service control, cleanup behavior, validation surface changes, or doc alignment tradeoffs.

When a design is uncertain, use milestones to de-risk it with small prototypes or focused experiments. Keep those experiments additive, explain how to run them, and record the evidence that justified keeping or discarding them.

## Current Repo-Local Planning Files

The standing planning rules live in `PLANS.md` at the repository root. The current worked example lives in `plan.md` at the repository root. Future contributors may replace `plan.md` with the active plan for the current task or create a task-specific plan file, but whichever plan is treated as current must still follow this file exactly.
