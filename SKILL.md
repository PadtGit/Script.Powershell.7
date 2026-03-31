# Script.Powershell.7 Skill Entry

Use the canonical script tree under `PowerShell Script/`, with `PowerShell Script/V7/` as the preferred maintained surface for migrated scripts.

## Core Rules

- This checkout tracks `origin` `PadtGit/Script.Powershell.7` on branch `main`.
- `PowerShell Script/*` is the primary implementation surface, and `PowerShell Script/V7/*` is the default target for maintained high-risk scripts.
- Current V7 maintained scripts include:
  `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1`,
  `PowerShell Script/V7/windows-maintenance/Move-OrphanedInstallerFiles.ps1`,
  `PowerShell Script/V7/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1`,
  `PowerShell Script/V7/Printer/Restart.Spool.DeletePrinterQSimple.ps1`,
  and `PowerShell Script/V7/Printer/restart.SpoolDeleteQV4.ps1`.
- Preserve existing `Set-StrictMode`, `$ErrorActionPreference`, and `SupportsShouldProcess` behavior unless the task explicitly changes them.
- Preserve usable `-WhatIf` behavior wherever a script already supports safe preview without elevation.
- Write generated validation output to `artifacts/validation/`, not tracked repo files.
- Treat `sysadmin-main` in runtime paths as a stable storage label, not a repo name.

## Validation Entry Points

- Root validator: `Invoke-WhatIfValidation.ps1`
- Pester tests: `tests/`
- Analyzer runner: `pwsh -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PSScriptAnalyzer.ps1' -Path . -Recurse -SettingsPath '.\tools\PSScriptAnalyzerSettings.psd1' -EnableExit -ExitCodeMode AllDiagnostics`
- CI validation runner: `pwsh -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-CIValidation.ps1'`
- Sandbox launcher: `Start-Process '.\sandbox\sysadmin-main-validation.wsb'`
- Automated sandbox `-WhatIf` launcher: `Start-Process '.\artifacts\validation\sandbox-whatif-validation.wsb'`
- Sandbox output sync: `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\artifacts\validation\Copy-SandboxWhatIfOutput.ps1'`

## Detailed Workflow

Use `AGENTS.md` for the repo-local maintenance flow and `docs/sysadmin-main-multi-agent-sop.md` for extended notes. Use `docs/windows-sandbox-validation.md` for both the disposable manual Sandbox shell and the automated `-WhatIf` capture wrapper. Keep the repo-local entrypoints and `.github/workflows/powershell-validation.yml` aligned when the validation flow changes.
