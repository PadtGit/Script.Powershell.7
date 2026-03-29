#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = 'C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main'
$OutputRoot = 'C:\Users\WDAGUtilityAccount\Desktop\sandbox-output'
$PowerShell51 = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$SummaryPath = Join-Path -Path $OutputRoot -ChildPath 'sandbox-whatif-summary.json'

$Targets = @(
    @{
        Name = 'Move-OrphanedInstallerFiles'
        Path = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\windows-maintenance\Move-OrphanedInstallerFiles.ps1'
    },
    @{
        Name = 'Nettoyage.Avance.Windows.Sauf.logserreur'
        Path = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1'
    },
    @{
        Name = 'Reset.Network.RebootPC'
        Path = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\windows-maintenance\Reset.Network.RebootPC.ps1'
    }
)

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$Results = foreach ($Target in $Targets) {
    $OutputPath = Join-Path -Path $OutputRoot -ChildPath ('{0}-sandbox-whatif.txt' -f $Target.Name)
    $ErrorPath = Join-Path -Path $OutputRoot -ChildPath ('{0}-sandbox-error.txt' -f $Target.Name)

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    if (Test-Path -LiteralPath $ErrorPath) {
        Remove-Item -LiteralPath $ErrorPath -Force
    }

    try {
        & $PowerShell51 -NoProfile -ExecutionPolicy Bypass -File $Target.Path -WhatIf *> $OutputPath

        [pscustomobject]@{
            Name      = $Target.Name
            ScriptPath = $Target.Path
            OutputPath = $OutputPath
            ExitCode  = $LASTEXITCODE
            Status    = if ($LASTEXITCODE -eq 0) { 'Completed' } else { 'Failed' }
        }
    }
    catch {
        $_ | Out-String | Set-Content -LiteralPath $ErrorPath -Encoding UTF8

        [pscustomobject]@{
            Name      = $Target.Name
            ScriptPath = $Target.Path
            OutputPath = $OutputPath
            ErrorPath = $ErrorPath
            ExitCode  = 1
            Status    = 'Failed'
        }
    }
}

$Results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8
