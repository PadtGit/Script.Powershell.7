# Script.Powershell.7

Windows admin PowerShell scripts under `PowerShell Script/`, with `pwsh` 7 as the default validation engine and the maintained high-risk scripts now mirrored under `PowerShell Script/V7/`.

Start with `AGENTS.md` for the local maintenance playbook, `SKILL.md` for the short repo entrypoint, `docs/sysadmin-main-multi-agent-sop.md` for extended workflow notes, and `docs/windows-sandbox-validation.md` for risky manual validation plus the automated Sandbox `-WhatIf` capture flow.

This checkout relies on analyzer, Pester, engine-aware fixed `-WhatIf`, trusted V7 smoke checks, and Windows Sandbox validation. Generated validation artifacts and optional sandbox-capture helpers live under `artifacts/validation/`. GitHub Actions uses `.github/workflows/powershell-validation.yml`, which runs `tools/Invoke-CIValidation.ps1` under `pwsh` on Windows runners and uploads the validation artifacts.
