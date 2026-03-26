# Script.Powershell.7

Windows admin PowerShell scripts under `PowerShell Script/`, with primary Windows PowerShell 5.1 surfaces plus a remaining `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1` companion script.

Start with `AGENTS.md` for the local maintenance playbook, `SKILL.md` for the short repo entrypoint, `docs/sysadmin-main-multi-agent-sop.md` for extended workflow notes, and `docs/windows-sandbox-validation.md` for risky manual validation.

This checkout currently relies on local analyzer, Pester, `-WhatIf`, and Windows Sandbox validation; the `origin` repo does not currently expose a `PowerShell Validation` GitHub Actions workflow.
