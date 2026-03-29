# Script.Powershell.7

Windows admin PowerShell scripts under `PowerShell Script/`, with primary Windows PowerShell 5.1 surfaces plus a remaining `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1` companion script.

Start with `AGENTS.md` for the local maintenance playbook, `SKILL.md` for the short repo entrypoint, `docs/sysadmin-main-multi-agent-sop.md` for extended workflow notes, and `docs/windows-sandbox-validation.md` for risky manual validation plus the optional automated Sandbox `-WhatIf` capture flow.

This checkout currently relies on local analyzer, Pester, `-WhatIf`, and Windows Sandbox validation; generated validation artifacts and optional sandbox-capture helpers live under `artifacts/validation/`. The `origin` repo does not currently expose a `PowerShell Validation` GitHub Actions workflow.
