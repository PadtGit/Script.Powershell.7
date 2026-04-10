. (Resolve-Path (Join-Path $PSScriptRoot '..\..\TestHelpers.ps1')).Path

Describe 'Sandbox WhatIf output sync helper' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\..\TestHelpers.ps1')).Path
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'artifacts\validation\Copy-SandboxWhatIfOutput.ps1'
        $script:TempRoot = Join-Path $env:TEMP ('sandbox-copy-tests-{0}' -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }

        if (-not [string]::IsNullOrWhiteSpace($script:TempRoot) -and (Test-Path -LiteralPath $script:TempRoot)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'removes stale files that are absent from the current source output' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($tempRoot)

            $sourceRoot = Join-Path $tempRoot 'source'
            $destinationRoot = Join-Path $tempRoot 'destination'
            New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

            Set-Content -LiteralPath (Join-Path $sourceRoot 'current.txt') -Value 'latest' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $destinationRoot 'current.txt') -Value 'stale-copy' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $destinationRoot 'old.txt') -Value 'remove-me' -Encoding UTF8

            $result = Copy-SandboxWhatIfOutput -SourceRoot $sourceRoot -DestinationRoot $destinationRoot

            $result.FileCount | Should -Be 1
            $result.RemovedCount | Should -Be 1
            Test-Path -LiteralPath (Join-Path $destinationRoot 'current.txt') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $destinationRoot 'old.txt') | Should -BeFalse
            (Get-Content -LiteralPath (Join-Path $destinationRoot 'current.txt') -Raw).TrimEnd("`r", "`n") | Should -Be 'latest'
        } -Parameters @{
            tempRoot = $script:TempRoot
        }
    }
}
