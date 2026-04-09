#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = 'C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main'
$OutputRoot = 'C:\Users\WDAGUtilityAccount\Desktop\sandbox-output'
$PowerShell51 = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$PowerShell7 = $null
$SummaryPath = Join-Path -Path $OutputRoot -ChildPath 'sandbox-whatif-summary.json'

function Resolve-PowerShell7Path {
    $Command = Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue
    if ($null -ne $Command) {
        return $Command.Source
    }

    $KnownPath = Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell\7\pwsh.exe'
    if (Test-Path -LiteralPath $KnownPath -PathType Leaf) {
        return $KnownPath
    }

    return $null
}

function Get-SandboxWhatIfTargets {
    @(
        @{
            Name   = 'Move-OrphanedInstallerFiles'
            Path   = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\windows-maintenance\Move-OrphanedInstallerFiles.ps1'
            Engine = 'PowerShell7'
        },
        @{
            Name   = 'Nettoyage.Avance.Windows.Sauf.logserreur'
            Path   = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1'
            Engine = 'PowerShell7'
        },
        @{
            Name   = 'Reset.Network.RebootPC'
            Path   = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\windows-maintenance\Reset.Network.RebootPC.ps1'
            Engine = 'PowerShell7'
        },
        @{
            Name   = 'restart.SpoolDeleteQV4'
            Path   = Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\Printer\restart.SpoolDeleteQV4.ps1'
            Engine = 'PowerShell7'
        }
    ) | ForEach-Object { [pscustomobject]$_ }
}

function Resolve-TargetShellPath {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Target
    )

    switch ($Target.Engine) {
        'PowerShell7' {
            if (-not $script:PowerShell7) {
                $script:PowerShell7 = Resolve-PowerShell7Path
            }

            if ([string]::IsNullOrWhiteSpace($script:PowerShell7)) {
                throw 'pwsh.exe was not found in the Sandbox session.'
            }

            return $script:PowerShell7
        }

        'WindowsPowerShell' {
            return $PowerShell51
        }

        default {
            throw ('Unsupported Sandbox validation engine: {0}' -f $Target.Engine)
        }
    }
}

function Invoke-SandboxWhatIfValidation {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OutputRoot = $script:OutputRoot,

        [Parameter()]
        [string]$SummaryPath = $script:SummaryPath,

        [Parameter()]
        [object[]]$Targets = (Get-SandboxWhatIfTargets)
    )

    $SummaryDirectory = Split-Path -Path $SummaryPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($SummaryDirectory)) {
        New-Item -ItemType Directory -Force -Path $SummaryDirectory | Out-Null
    }

    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

    $Results = foreach ($Target in @($Targets)) {
        $OutputPath = Join-Path -Path $OutputRoot -ChildPath ('{0}-sandbox-whatif.txt' -f $Target.Name)
        $ErrorPath = Join-Path -Path $OutputRoot -ChildPath ('{0}-sandbox-error.txt' -f $Target.Name)

        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Force
        }

        if (Test-Path -LiteralPath $ErrorPath) {
            Remove-Item -LiteralPath $ErrorPath -Force
        }

        try {
            $ShellPath = Resolve-TargetShellPath -Target $Target
            & $ShellPath -NoProfile -ExecutionPolicy Bypass -File $Target.Path -WhatIf *> $OutputPath

            [pscustomobject]@{
                Name       = $Target.Name
                Engine     = $Target.Engine
                ShellPath  = $ShellPath
                ScriptPath = $Target.Path
                OutputPath = $OutputPath
                ExitCode   = $LASTEXITCODE
                Status     = if ($LASTEXITCODE -eq 0) { 'Completed' } else { 'Failed' }
            }
        }
        catch {
            $_ | Out-String | Set-Content -LiteralPath $ErrorPath -Encoding UTF8

            [pscustomobject]@{
                Name       = $Target.Name
                Engine     = $Target.Engine
                ScriptPath = $Target.Path
                OutputPath = $OutputPath
                ErrorPath  = $ErrorPath
                ExitCode   = 1
                Status     = 'Failed'
            }
        }
    }

    $Results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

    return [pscustomobject]@{
        OutputRoot   = $OutputRoot
        SummaryPath  = $SummaryPath
        ResultCount  = $Results.Count
        FailureCount = @($Results | Where-Object { $_.Status -eq 'Failed' }).Count
        Results      = $Results
    }
}

try {
    $ValidationResult = Invoke-SandboxWhatIfValidation
    if ($ValidationResult.FailureCount -gt 0) {
        exit 1
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
