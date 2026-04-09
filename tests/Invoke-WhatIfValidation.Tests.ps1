. (Resolve-Path (Join-Path $PSScriptRoot 'TestHelpers.ps1')).Path

Describe 'Invoke-WhatIfValidation helper' {

    BeforeAll {
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'Invoke-WhatIfValidation.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'resolves pwsh explicitly when the current host is Windows PowerShell' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Get-Process {
                [pscustomobject]@{
                    Path = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
                }
            }
            Mock Get-Command {
                [pscustomobject]@{
                    Source = 'C:\Program Files\PowerShell\7\pwsh.exe'
                }
            } -ParameterFilter { $Name -eq 'pwsh.exe' }
            Mock Test-Path { $false }

            $resolvedPath = Resolve-PowerShell7Path

            $resolvedPath | Should -Be 'C:\Program Files\PowerShell\7\pwsh.exe'
            Assert-MockCalled Get-Command -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'pwsh.exe' }
        }
    }
}
