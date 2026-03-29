#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceRoot = 'C:\Users\Bob\Documents\SandboxValidationOutput\Script.Powershell.7'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$DestinationRoot = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation\sandbox-whatif-output'

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw ('Sandbox output source not found: {0}' -f $SourceRoot)
}

New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null

$CopiedFiles = @()

foreach ($Item in Get-ChildItem -LiteralPath $SourceRoot -File -ErrorAction Stop) {
    $DestinationPath = Join-Path -Path $DestinationRoot -ChildPath $Item.Name
    Copy-Item -LiteralPath $Item.FullName -Destination $DestinationPath -Force
    $CopiedFiles += $DestinationPath
}

[pscustomobject]@{
    SourceRoot      = $SourceRoot
    DestinationRoot = $DestinationRoot
    FileCount       = $CopiedFiles.Count
    Files           = $CopiedFiles
}
