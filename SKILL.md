# Script.Powershell.7 Skill Entry

Use the canonical script tree under `PowerShell Script/`.

## Core Rules

- This checkout tracks `origin` `PadtGit/Script.Powershell.7` on branch `main`.
- `PowerShell Script/*` is the primary implementation surface.
- `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1` remains tracked and should be considered when work touches network-reset behavior.
- Keep existing `Set-StrictMode`, `$ErrorActionPreference`, and `SupportsShouldProcess` behavior intact unless the task explicitly changes them.
- Preserve usable `-WhatIf` behavior wherever a script already supports safe preview without elevation.
- Write generated validation output to `artifacts/validation/`, not tracked repo files.
- Treat `sysadmin-main` in runtime paths as a stable storage label, not a repo name.

## Validation Entry Points

- Root validator: `Invoke-WhatIfValidation.ps1`
- Pester tests: `tests/`
- Analyzer runner: `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PSScriptAnalyzer.ps1' -Path . -Recurse -SettingsPath '.\tools\PSScriptAnalyzerSettings.psd1' -EnableExit -ExitCodeMode AllDiagnostics`
- Sandbox launcher: `Start-Process '.\sandbox\sysadmin-main-validation.wsb'`
- Automated sandbox `-WhatIf` launcher: `Start-Process '.\artifacts\validation\sandbox-whatif-validation.wsb'`
- Sandbox output sync: `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\artifacts\validation\Copy-SandboxWhatIfOutput.ps1'`

## Detailed Workflow

Use `AGENTS.md` for the repo-local maintenance flow and `docs/sysadmin-main-multi-agent-sop.md` for extended notes. Use `docs/windows-sandbox-validation.md` for both the disposable manual Sandbox shell and the optional automated `-WhatIf` capture wrapper. This checkout does not currently include a deeper repo-local skill file or a GitHub Actions workflow surface to keep in sync.
