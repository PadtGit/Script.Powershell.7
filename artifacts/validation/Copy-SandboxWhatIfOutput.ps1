#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceRoot = 'C:\Users\Bob\Documents\SandboxValidationOutput\Script.Powershell.7',

    [Parameter()]
    [string]$DestinationRoot = (Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'artifacts\validation\sandbox-whatif-output')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Copy-SandboxWhatIfOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw ('Sandbox output source not found: {0}' -f $SourceRoot)
    }

    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null

    $SourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -File -ErrorAction Stop)
    $SourceFileNames = @{}
    $CopiedFiles = @()
    $RemovedFiles = @()

    foreach ($Item in $SourceFiles) {
        $SourceFileNames[$Item.Name] = $true
    }

    foreach ($DestinationItem in @(Get-ChildItem -LiteralPath $DestinationRoot -File -ErrorAction Stop)) {
        if (-not $SourceFileNames.ContainsKey($DestinationItem.Name)) {
            Remove-Item -LiteralPath $DestinationItem.FullName -Force -ErrorAction Stop
            $RemovedFiles += $DestinationItem.FullName
        }
    }

    foreach ($Item in $SourceFiles) {
        $DestinationPath = Join-Path -Path $DestinationRoot -ChildPath $Item.Name
        Copy-Item -LiteralPath $Item.FullName -Destination $DestinationPath -Force
        $CopiedFiles += $DestinationPath
    }

    [pscustomobject]@{
        SourceRoot = $SourceRoot
        DestinationRoot = $DestinationRoot
        FileCount = $CopiedFiles.Count
        Files = $CopiedFiles
        RemovedCount = $RemovedFiles.Count
        RemovedFiles = $RemovedFiles
    }
}

try {
    Copy-SandboxWhatIfOutput -SourceRoot $SourceRoot -DestinationRoot $DestinationRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

