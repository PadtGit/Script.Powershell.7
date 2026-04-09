. (Resolve-Path (Join-Path $PSScriptRoot '..\..\TestHelpers.ps1')).Path

Describe 'Sandbox WhatIf validation helper' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\..\TestHelpers.ps1')).Path
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'artifacts\validation\Invoke-SandboxWhatIfValidation.ps1'
        $script:TempRoot = Join-Path $env:TEMP ('sandbox-whatif-tests-{0}' -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null

        $script:SuccessShell = Join-Path $script:TempRoot 'success.cmd'
        Set-Content -LiteralPath $script:SuccessShell -Encoding ASCII -Value @(
            '@echo off'
            'exit /b 0'
        )

        $script:FailureShell = Join-Path $script:TempRoot 'failure.cmd'
        Set-Content -LiteralPath $script:FailureShell -Encoding ASCII -Value @(
            '@echo off'
            'exit /b 9'
        )
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }

        if (-not [string]::IsNullOrWhiteSpace($script:TempRoot) -and (Test-Path -LiteralPath $script:TempRoot)) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns a failure count and writes a summary when any target fails' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($tempRoot, $successShell, $failureShell)

            $null = $successShell, $failureShell

            $outputRoot = Join-Path $tempRoot 'output'
            $summaryPath = Join-Path $outputRoot 'sandbox-whatif-summary.json'
            $targets = @(
                [pscustomobject]@{
                    Name   = 'SuccessTarget'
                    Engine = 'PowerShell7'
                    Path   = 'C:\Sandbox\success.ps1'
                },
                [pscustomobject]@{
                    Name   = 'FailureTarget'
                    Engine = 'PowerShell7'
                    Path   = 'C:\Sandbox\failure.ps1'
                }
            )

            Mock Resolve-TargetShellPath {
                if ($Target.Name -eq 'SuccessTarget') {
                    return $successShell
                }

                return $failureShell
            }

            $result = Invoke-SandboxWhatIfValidation -OutputRoot $outputRoot -SummaryPath $summaryPath -Targets $targets
            $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

            $result.ResultCount | Should -Be 2
            $result.FailureCount | Should -Be 1
            $summary.Count | Should -Be 2
            ($summary | Where-Object { $_.Name -eq 'SuccessTarget' }).Status | Should -Be 'Completed'
            ($summary | Where-Object { $_.Name -eq 'FailureTarget' }).Status | Should -Be 'Failed'
            Test-Path -LiteralPath (Join-Path $outputRoot 'SuccessTarget-sandbox-whatif.txt') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $outputRoot 'FailureTarget-sandbox-whatif.txt') | Should -BeTrue
        } -Parameters @{
            tempRoot     = $script:TempRoot
            successShell = $script:SuccessShell
            failureShell = $script:FailureShell
        }
    }
}
