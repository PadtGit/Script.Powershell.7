#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$ResultPath = '',

    [string]$PowerShell7Path = '',

    [string]$WindowsPowerShellPath = ''
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$BasePath = Join-Path -Path $PSScriptRoot -ChildPath 'PowerShell Script'

try {
    $CurrentPowerShellPath = (Get-Process -Id $PID -ErrorAction Stop).Path
}
catch {
    $CurrentPowerShellPath = 'pwsh'
}

if ([string]::IsNullOrWhiteSpace($PowerShell7Path)) {
    $PowerShell7Path = $CurrentPowerShellPath
}

if ([string]::IsNullOrWhiteSpace($WindowsPowerShellPath)) {
    $WindowsPowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
}

if ([string]::IsNullOrWhiteSpace($ResultPath)) {
    $ResultPath = Join-Path -Path $PSScriptRoot -ChildPath 'artifacts\validation\whatif-validation.txt'
}

$ResultDirectory = Split-Path -Path $ResultPath -Parent
if (-not [string]::IsNullOrWhiteSpace($ResultDirectory) -and -not (Test-Path -LiteralPath $ResultDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $ResultDirectory -Force | Out-Null
}

function Get-WhatIfValidationTargetCatalog {
    @(
        @{ RelativePath = 'Adobe\Install.AdobeAcrobat.Clean.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'Printer\Delete.all.offline.printer.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'Printer\Deleter.NamePrinter.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'Printer\Export.printer.list.BASIC.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'Printer\Export.printer.list.FULL.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'Printer\Restart.spool.delete.printerQ.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'V7\Printer\Restart.Spool.DeletePrinterQSimple.ps1'; Engine = 'PowerShell7' }
        @{ RelativePath = 'V7\Printer\restart.SpoolDeleteQV4.ps1'; Engine = 'PowerShell7' }
        @{ RelativePath = 'V7\windows-maintenance\Move-OrphanedInstallerFiles.ps1'; Engine = 'PowerShell7' }
        @{ RelativePath = 'V7\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1'; Engine = 'PowerShell7' }
        @{ RelativePath = 'windows-maintenance\Nettoyage.Complet.Caches.Windows.ps1'; Engine = 'WindowsPowerShell' }
        @{ RelativePath = 'V7\windows-maintenance\Reset.Network.RebootPC.ps1'; Engine = 'PowerShell7' }
        @{ RelativePath = 'WindowsServer\FichierOphelin.ps1'; Engine = 'WindowsPowerShell' }
    ) | ForEach-Object {
        [pscustomobject]@{
            RelativePath = $_.RelativePath
            ScriptPath   = Join-Path -Path $BasePath -ChildPath $_.RelativePath
            Engine       = $_.Engine
        }
    }
}

function Resolve-WhatIfShellPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Target
    )

    switch ($Target.Engine) {
        'PowerShell7' {
            return $PowerShell7Path
        }

        'WindowsPowerShell' {
            return $WindowsPowerShellPath
        }

        default {
            throw ('Unknown validation engine: {0}' -f $Target.Engine)
        }
    }
}

function Invoke-WhatIfValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Targets,

        [Parameter(Mandatory = $true)]
        [string]$ResultPath
    )

    $Results = @()
    $FailureCount = 0

    foreach ($Target in $Targets) {
        if (-not (Test-Path -LiteralPath $Target.ScriptPath -PathType Leaf)) {
            $Results += [pscustomobject]@{
                RelativePath = $Target.RelativePath
                ScriptPath   = $Target.ScriptPath
                Engine       = $Target.Engine
                ExitCode     = 1
                Success      = $false
                Output       = 'Script not found.'
            }
            $FailureCount++
            continue
        }

        $ShellPath = Resolve-WhatIfShellPath -Target $Target
        $CurrentErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        try {
            $OutputLines = @(
                & $ShellPath -NoProfile -ExecutionPolicy Bypass -File $Target.ScriptPath -WhatIf 2>&1 |
                    ForEach-Object { $_.ToString() }
            )
            $ExitCode = $LASTEXITCODE
        }
        catch {
            $OutputLines = @($_.Exception.Message)
            $ExitCode = 1
        }
        finally {
            $ErrorActionPreference = $CurrentErrorActionPreference
        }

        $Results += [pscustomobject]@{
            RelativePath = $Target.RelativePath
            ScriptPath   = $Target.ScriptPath
            Engine       = $Target.Engine
            ShellPath    = $ShellPath
            ExitCode     = $ExitCode
            Success      = ($ExitCode -eq 0)
            Output       = ($OutputLines -join [Environment]::NewLine)
        }

        if ($ExitCode -ne 0) {
            $FailureCount++
        }
    }

    $Results |
        Sort-Object -Property ScriptPath |
        Format-List |
        Out-String |
        Set-Content -LiteralPath $ResultPath -Encoding UTF8

    $Results

    if ($FailureCount -gt 0) {
        exit 1
    }
}

Invoke-WhatIfValidation -Targets (Get-WhatIfValidationTargetCatalog) -ResultPath $ResultPath
