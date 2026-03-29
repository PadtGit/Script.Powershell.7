# Windows Sandbox Validation

## Purpose

Use Windows Sandbox for manual validation of risky scripts such as:

- network reset or reboot
- installer orphan move
- broad cleanup scripts

## Repo Template

- Sandbox file: `sandbox/sysadmin-main-validation.wsb`
- Automated `-WhatIf` Sandbox file: `artifacts/validation/sandbox-whatif-validation.wsb`
- Automated `-WhatIf` Sandbox helper: `artifacts/validation/Invoke-SandboxWhatIfValidation.ps1`
- Automated `-WhatIf` output sync helper: `artifacts/validation/Copy-SandboxWhatIfOutput.ps1`
- Host repo path: `C:\Users\Bob\Documents\Script.Powershell.7`
- Sandbox repo path: `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`
- The host repo is mapped read-only into the Sandbox.
- The automated `-WhatIf` wrapper uses `C:\Users\Bob\Documents\SandboxValidationOutput\Script.Powershell.7` as a writable host-mapped output folder, then copies those files back into `artifacts/validation/sandbox-whatif-output/`.
- Keep the in-sandbox working folder at `sysadmin-main` so the documented validation commands and runtime conventions stay stable.
- Networking is disabled.
- vGPU is disabled.
- The logon command opens PowerShell and sets the working location to `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.

## Manual Validation Flow

1. Launch the `.wsb` file.
2. Confirm PowerShell opens in `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
3. Run the target script with `-WhatIf` first.
4. Inspect the result object and any generated output under `artifacts/validation/`.
5. Remember that the repo mapping is read-only; use the Sandbox only for disposable validation, not for writing changes back to the host repo.
6. Only perform non-`WhatIf` validation when you are intentionally testing in the disposable Sandbox environment.
7. If the host checkout path changes, update this document and `sandbox/sysadmin-main-validation.wsb` together.

## Automated `-WhatIf` Capture

Use this when you want the Sandbox to run the current high-risk preview set automatically and save the raw output back to the host:

1. Launch `artifacts/validation/sandbox-whatif-validation.wsb`.
2. Wait for the Sandbox run to finish writing the raw files into `C:\Users\Bob\Documents\SandboxValidationOutput\Script.Powershell.7`.
3. Sync those files back into the repo artifact folder:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\artifacts\validation\Copy-SandboxWhatIfOutput.ps1'
```

4. Inspect the copied outputs under `artifacts/validation/sandbox-whatif-output/`.

Current automated target set:

- `PowerShell Script\windows-maintenance\Move-OrphanedInstallerFiles.ps1`
- `PowerShell Script\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1`
- `PowerShell Script\windows-maintenance\Reset.Network.RebootPC.ps1`

If the repo path or host-side writable output path changes, update this document and `artifacts/validation/sandbox-whatif-validation.wsb` together.
