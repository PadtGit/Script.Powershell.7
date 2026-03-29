# Security Ownership Summary

## Scope

- Repo: `C:\Users\Bob\Documents\Script.Powershell.7`
- Source of truth: git history analyzed by `security-ownership-map`
- Sensitivity profile: `artifacts/validation/security-ownership-sensitive.csv`

## Key Results

- The repo history is currently very thin: `2` commits, `1` contributor, and `50` tracked files in the ownership graph.
- The single observed maintainer, `System Admin <it.gat.templeton@gmail.com>`, controls `100%` of every tagged sensitive category in the custom profile:
  - `supply_chain`
  - `privileged_admin`
  - `service_control`
  - `validation_tooling`
- Every tagged sensitive file currently has bus factor `1`.

## Highest-Risk Ownership Hotspots

- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1` (`supply_chain`, bus factor `1`)
- `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/windows-maintenance/Nettoyage.Complet.Caches.Windows.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/windows-maintenance/Reset.Network.RebootPC.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/V7/windows-maintenance/Reset.Network.RebootPC.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/WindowsServer/FichierOphelin.ps1` (`privileged_admin`, bus factor `1`)
- `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1` and related printer-maintenance scripts (`service_control`, bus factor `1`)
- `Invoke-WhatIfValidation.ps1` and `tools/Invoke-PSScriptAnalyzer.ps1` (`validation_tooling`, bus factor `1`)

## Interpretation

- This is primarily an operational ownership risk, not proof of a code vulnerability by itself.
- Because the repo was effectively rebuilt recently, the current bus-factor result is directionally useful but low-confidence for long-term maintainership.
- The important takeaway is still actionable: every privileged script and every validation guardrail currently depends on one maintainer.

## Recommended Follow-up

1. Add at least one additional reviewer for `PowerShell Script/Adobe/`, `PowerShell Script/windows-maintenance/`, `PowerShell Script/WindowsServer/`, and `tools/`.
2. Re-run the ownership map after more history accumulates and compare against any future CODEOWNERS or review policy.
3. Keep the custom sensitivity config under `artifacts/validation/security-ownership-sensitive.csv` or promote it into a stable security-analysis location if this becomes part of the regular maintenance loop.

## Artifact Locations

- Summary JSON: `artifacts/validation/ownership-map-out/summary.json`
- People CSV: `artifacts/validation/ownership-map-out/people.csv`
- Files CSV: `artifacts/validation/ownership-map-out/files.csv`
- Ownership edges: `artifacts/validation/ownership-map-out/edges.csv`
- Co-change graph: `artifacts/validation/ownership-map-out/cochange.graph.json`
- Communities: `artifacts/validation/ownership-map-out/communities.json`
