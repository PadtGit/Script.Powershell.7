. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'Invoke-PSScriptAnalyzer helper' {

    BeforeAll {
        $script:RepoRoot = Get-SysadminMainRepoRoot
        $script:ToolPath = Join-Path $script:RepoRoot 'tools\Invoke-PSScriptAnalyzer.ps1'
        $script:SettingsPath = Join-Path $script:RepoRoot 'tools\PSScriptAnalyzerSettings.psd1'
        try {
            $script:PowerShellPath = (Get-Process -Id $PID -ErrorAction Stop).Path
        }
        catch {
            $script:PowerShellPath = 'pwsh'
        }
    }

    It 'fails validation when analyzer invocation crashes and records the failure in JSON output' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $sampleScriptPath = Join-Path $tempRoot 'Sample.ps1'
            $ruleModulePath = Join-Path $tempRoot 'ThrowingRule.psm1'
            $txtPath = Join-Path $tempRoot 'psscriptanalyzer.txt'
            $jsonPath = Join-Path $tempRoot 'psscriptanalyzer.json'
            $sarifPath = Join-Path $tempRoot 'psscriptanalyzer.sarif'

            Set-Content -LiteralPath $sampleScriptPath -Encoding UTF8 -Value "Write-Output 'hi'"
            Set-Content -LiteralPath $ruleModulePath -Encoding UTF8 -Value @'
function Measure-ThrowingRule {
    [CmdletBinding()]
    param(
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst,
        [string]$FileName
    )

    throw 'Synthetic analyzer failure'
}
'@

            $outputLines = @(
                & $script:PowerShellPath `
                    -NoProfile `
                    -ExecutionPolicy Bypass `
                    -File $script:ToolPath `
                    -Path $sampleScriptPath `
                    -SettingsPath $script:SettingsPath `
                    -CustomRulePath $ruleModulePath `
                    -IncludeRule 'Measure-ThrowingRule' `
                    -OutTxtPath $txtPath `
                    -OutJsonPath $jsonPath `
                    -OutSarifPath $sarifPath `
                    -EnableExit `
                    -ExitCodeMode AnyError 2>&1 |
                    ForEach-Object { $_.ToString() }
            )
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 1
            ($outputLines -join [Environment]::NewLine) | Should -Match 'Batch analysis failed\. Falling back to per-file mode\.'

            $jsonText = Get-Content -LiteralPath $jsonPath -Raw
            $diagnostics = $jsonText | ConvertFrom-Json

            @($diagnostics).Count | Should -Be 1
            $diagnostics[0].RuleName | Should -Be 'PSScriptAnalyzerInvocationFailure'
            $diagnostics[0].Severity | Should -Be 'Error'
            $diagnostics[0].Message | Should -Match 'Synthetic analyzer failure'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'overwrites the JSON artifact with an empty array when no findings are returned' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $sampleScriptPath = Join-Path $tempRoot 'Clean.ps1'
            $txtPath = Join-Path $tempRoot 'psscriptanalyzer.txt'
            $jsonPath = Join-Path $tempRoot 'psscriptanalyzer.json'
            $sarifPath = Join-Path $tempRoot 'psscriptanalyzer.sarif'

            Set-Content -LiteralPath $sampleScriptPath -Encoding UTF8 -Value "Write-Output 'clean'"
            Set-Content -LiteralPath $jsonPath -Encoding UTF8 -Value '[{"RuleName":"StaleFinding"}]'

            $outputLines = @(
                & $script:PowerShellPath `
                    -NoProfile `
                    -ExecutionPolicy Bypass `
                    -File $script:ToolPath `
                    -Path $sampleScriptPath `
                    -SettingsPath $script:SettingsPath `
                    -OutTxtPath $txtPath `
                    -OutJsonPath $jsonPath `
                    -OutSarifPath $sarifPath 2>&1 |
                    ForEach-Object { $_.ToString() }
            )
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0
            ($outputLines -join [Environment]::NewLine) | Should -Match 'No findings\. All checks passed\.'
            ((Get-Content -LiteralPath $jsonPath -Raw).Trim()) | Should -Be '[]'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns clean empty artifacts when no PowerShell files are present' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $txtPath = Join-Path $tempRoot 'psscriptanalyzer.txt'
            $jsonPath = Join-Path $tempRoot 'psscriptanalyzer.json'
            $sarifPath = Join-Path $tempRoot 'psscriptanalyzer.sarif'
            Set-Content -LiteralPath (Join-Path $tempRoot 'notes.txt') -Encoding UTF8 -Value 'not a PowerShell file'

            $outputLines = @(
                & $script:PowerShellPath `
                    -NoProfile `
                    -ExecutionPolicy Bypass `
                    -File $script:ToolPath `
                    -Path $tempRoot `
                    -Recurse `
                    -SettingsPath $script:SettingsPath `
                    -OutTxtPath $txtPath `
                    -OutJsonPath $jsonPath `
                    -OutSarifPath $sarifPath `
                    -EnableExit `
                    -ExitCodeMode AllDiagnostics 2>&1 |
                    ForEach-Object { $_.ToString() }
            )
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0
            ($outputLines -join [Environment]::NewLine) | Should -Match 'No PowerShell files found for analysis\.'
            ((Get-Content -LiteralPath $jsonPath -Raw).Trim()) | Should -Be '[]'
            ((Get-Content -LiteralPath $sarifPath -Raw) | ConvertFrom-Json).runs[0].results.Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'analyzes multiple files in one batch invocation' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $firstScriptPath = Join-Path $tempRoot 'AliasOne.ps1'
            $secondScriptPath = Join-Path $tempRoot 'AliasTwo.ps1'
            $txtPath = Join-Path $tempRoot 'psscriptanalyzer.txt'
            $jsonPath = Join-Path $tempRoot 'psscriptanalyzer.json'
            $sarifPath = Join-Path $tempRoot 'psscriptanalyzer.sarif'

            Set-Content -LiteralPath $firstScriptPath -Encoding UTF8 -Value 'gci .'
            Set-Content -LiteralPath $secondScriptPath -Encoding UTF8 -Value 'ls .'

            $results = @(
                & $script:ToolPath `
                    -Path @($firstScriptPath, $secondScriptPath) `
                    -SettingsPath $script:SettingsPath `
                    -OutTxtPath $txtPath `
                    -OutJsonPath $jsonPath `
                    -OutSarifPath $sarifPath 2>&1
            )

            $jsonText = Get-Content -LiteralPath $jsonPath -Raw
            $diagnostics = @($jsonText | ConvertFrom-Json)
            $resultWarnings = @($results | Where-Object { $_.RuleName -eq 'PSAvoidUsingCmdletAliases' })
            $aliasWarnings = @($diagnostics | Where-Object { $_.RuleName -eq 'PSAvoidUsingCmdletAliases' })

            $resultWarnings.Count | Should -Be 2
            $aliasWarnings.Count | Should -Be 2
            $jsonText | Should -Match ([regex]::Escape('AliasOne.ps1'))
            $jsonText | Should -Match ([regex]::Escape('AliasTwo.ps1'))
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not surface analyzer invocation failures for the previously crashing repo files' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $txtPath = Join-Path $tempRoot 'psscriptanalyzer.txt'
            $jsonPath = Join-Path $tempRoot 'psscriptanalyzer.json'
            $sarifPath = Join-Path $tempRoot 'psscriptanalyzer.sarif'
            $targetPaths = @(
                Join-Path $script:RepoRoot 'PowerShell Script\Printer\Restart.spool.delete.printerQ.ps1'
                Join-Path $script:RepoRoot 'PowerShell Script\V7\windows-maintenance\Reset.Network.RebootPC.ps1'
            )

            $results = @(
                & $script:ToolPath `
                    -Path $targetPaths `
                    -SettingsPath $script:SettingsPath `
                    -OutTxtPath $txtPath `
                    -OutJsonPath $jsonPath `
                    -OutSarifPath $sarifPath 2>&1
            )

            $jsonText = Get-Content -LiteralPath $jsonPath -Raw
            $diagnostics = @($jsonText | ConvertFrom-Json)

            @($results | Where-Object { $_.RuleName -eq 'PSScriptAnalyzerInvocationFailure' }).Count | Should -Be 0
            @($diagnostics | Where-Object { $_.RuleName -eq 'PSScriptAnalyzerInvocationFailure' }).Count | Should -Be 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
