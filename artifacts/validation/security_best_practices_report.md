# Security Best Practices Review

## Executive Summary

This repo is in materially better shape than the stale root-level report suggests. The current `PowerShell Script/` implementations consistently preserve `Set-StrictMode`, `$ErrorActionPreference = 'Stop'`, and `SupportsShouldProcess`, and the higher-risk scripts now include trusted-root checks, reparse-point guards, unique output names, and package signature validation.

The remaining meaningful issues are narrower and mostly local-host focused:

1. Several elevated scripts trust pre-existing `C:\ProgramData\sysadmin-main\...` directories without verifying the owner or DACL before writing logs or quarantined files there.
2. The Adobe installer flow accepts any valid Authenticode signature whose publisher fields match the broad wildcard `Adobe*`, which is weaker than pinning the expected signer identity for an elevated installer path.

This review is a PowerShell fallback review. The `security-best-practices` skill does not currently ship PowerShell-specific reference material, so the findings below are grounded in the live repo code plus host validation of the current Windows ACL behavior.

## Medium Severity

### SEC-001: ProgramData-based secure roots are trusted if they already exist

Impact: a low-privilege local user can pre-create `C:\ProgramData\sysadmin-main\...` with permissive ACLs and then receive admin-generated logs or quarantined installer payloads when an elevated script runs.

Evidence:

- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:15-16` places logs under `CommonApplicationData\sysadmin-main\Logs\AdobeAcrobat`.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:147-160` only applies `Set-RestrictedDirectoryAcl` when the target directory is newly created.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:278` then uses that directory for install and uninstall logs.
- `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1:13-15` places quarantine output under `CommonApplicationData\sysadmin-main\Quarantine\InstallerOrphans`.
- `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1:125-138` likewise trusts an existing directory if it is not a reparse point.
- `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1:208-228` then moves orphaned MSI/MSP files into that location.
- `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1:13-18` places spooler transcripts under `CommonApplicationData\sysadmin-main\Logs\Printer`.
- `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1:128-141` has the same "only harden on create" behavior.
- `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1:199-210` then starts a transcript in the resulting directory.
- `PowerShell Script/WindowsServer/FichierOphelin.ps1:13-15` and `PowerShell Script/WindowsServer/FichierOphelin.ps1:208-228` repeat the same quarantine pattern.

Why this matters:

- On the current host, `icacls C:\ProgramData` shows `BUILTIN\Users:(CI)(WD,AD,WEA,WA)`, which means standard users can create child folders there by default.
- The scripts do reject reparse points, which is good, but they do not reject or repair a pre-existing directory tree with a weak ACL.
- The affected outputs are not harmless: they include privileged maintenance transcripts, inventory exports, and quarantined installer payloads.

Recommended fixes:

1. Materialize and harden `$StorageRoot` itself before using any child path, rather than only protecting the final leaf directory.
2. For every existing output/quarantine directory, verify owner and DACL explicitly and refuse to proceed if they are not restricted to `SYSTEM`, `Administrators`, and the current admin SID.
3. Consider storing a marker file or expected ACL fingerprint under `sysadmin-main` so later runs can detect tampering instead of silently trusting an existing tree.

### SEC-002: Adobe installer trust is based on a broad wildcard publisher match

Impact: the elevated installer path will accept any valid signature whose simple name, subject, or issuer matches `Adobe*`, which is weaker than pinning the exact signer identity expected for this workflow.

Evidence:

- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:17-19` configures `$TrustedPublisherPatterns = @('Adobe*')`.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:165-196` accepts a signature when any publisher candidate matches a wildcard pattern with `-like`.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:182-185` includes the certificate simple name, subject, and issuer as match candidates.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:262-275` gates installation on that check and then runs `msiexec.exe` with administrative privileges.

Why this matters:

- Signature validation is already a strong improvement over the prior state, but the trust decision is still broader than the deployment needs.
- Matching against issuer text is especially loose; it is not the same as pinning the expected signer certificate or certificate chain.
- This script exists to run a privileged MSI from a fixed staging path, which is exactly the kind of workflow where signer identity should be tight rather than flexible.

Recommended fixes:

1. Replace the wildcard allowlist with exact expected subject names or, better, certificate thumbprints/public-key pins.
2. Do not treat `Issuer` text as sufficient proof of publisher identity.
3. Optionally allow an explicit SHA-256 hash parameter for the staged installer so the deployment pipeline can pin both signer and artifact.

## Low Severity / Hardening Opportunities

### SEC-003: Security regression coverage does not yet lock in the two trust boundaries above

The current tests are useful and catch several past regressions, but they do not yet cover the remaining trust assumptions:

- `tests/Adobe/Install.AdobeAcrobat.Clean.Tests.ps1` verifies that unsigned packages are rejected and that `WhatIf` suppresses `Start-Process`, but it does not assert exact signer identity or a pinned certificate.
- `tests/windows-maintenance/Move-OrphanedInstallerFiles.Tests.ps1` verifies reparse-point skipping and rename-on-collision, but it does not assert that an existing `ProgramData\sysadmin-main` tree is rejected when it has a weak ACL.
- I did not find tests that simulate a pre-created `CommonApplicationData\sysadmin-main\...` directory with attacker-controlled permissions for the Adobe, quarantine, or spooler transcript flows.

Recommended follow-up:

1. Add Pester coverage around existing-directory owner/DACL validation for the `CommonApplicationData`-based scripts.
2. Add tests for exact signer pinning in `Install.AdobeAcrobat.Clean.ps1`.

## Positive Security Notes

- I did not find `Invoke-Expression`, `iex`, `DownloadString`, or download-and-run behavior in the PowerShell script tree.
- The privileged scripts consistently keep `SupportsShouldProcess`, which preserves previewability and reduces accidental destructive runs.
- The higher-risk cleanup and quarantine scripts now skip reparse points and constrain output roots to expected directory trees.
- The printer export and transcript scripts no longer default to `C:\Temp`; they use app-specific directories and unique filenames.

## Recommended Fix Order

1. Harden and validate the existing `CommonApplicationData\sysadmin-main` directory tree before any privileged write.
2. Tighten Adobe signer trust from `Adobe*` wildcard matching to explicit signer identity.
3. Add focused Pester regression coverage for those two boundaries.
