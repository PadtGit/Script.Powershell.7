. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V7 network reset and reboot behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\V7\windows-maintenance\Reset.Network.RebootPC.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns a preview-safe WhatIf summary' {
        $Result = Invoke-WhatIfScriptObject -RelativeScriptPath 'PowerShell Script\V7\windows-maintenance\Reset.Network.RebootPC.ps1'

        $Result.Object | Should -Not -BeNullOrEmpty
        $Result.Object.CommandCount | Should -Be 5
        $Result.Object.ExecutedCount | Should -Be 0
        $Result.Object.Status | Should -Be 'WhatIf'
        $Result.Object.Reason | Should -Be ''
    }

    It 'returns a skipped result in Windows Sandbox without running commands' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            $result = Invoke-ResetNetworkAndReboot `
                -RequireAdmin $false `
                -IsAdministrator $false `
                -IsWindowsSandbox $true `
                -Commands @(
                    @{
                        FilePath  = 'C:\DoesNotExist\netsh.exe'
                        Arguments = @('int', 'ip', 'reset')
                    }
                ) `
                -ShutdownPath 'C:\Windows\System32\shutdown.exe' `
                -RebootDelaySeconds 5

            $result.CommandCount | Should -Be 1
            $result.ExecutedCount | Should -Be 0
            $result.Status | Should -Be 'Skipped'
            $result.Reason | Should -Be 'NetworkResetUnsupportedInWindowsSandbox'
        }
    }

    It 'requires elevation for non-WhatIf runs' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            {
                Invoke-ResetNetworkAndReboot `
                    -RequireAdmin $true `
                    -IsAdministrator $false `
                    -IsWindowsSandbox $false `
                    -Commands @(
                        @{
                            FilePath  = 'C:\Windows\System32\netsh.exe'
                            Arguments = @('winsock', 'reset')
                        }
                    ) `
                    -ShutdownPath 'C:\Windows\System32\shutdown.exe' `
                    -RebootDelaySeconds 5 `
                    -Confirm:$false
            } | Should -Throw 'Run this script in an elevated PowerShell 7 session.'
        }
    }

    It 'fails when a native network command returns a non-zero exit code' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($commandPath)

            {
                Invoke-ResetNetworkAndReboot `
                    -RequireAdmin $false `
                    -IsAdministrator $true `
                    -IsWindowsSandbox $false `
                    -Commands @(
                        @{
                            FilePath  = $commandPath
                            Arguments = @('/c', 'exit', '23')
                        }
                    ) `
                    -ShutdownPath 'C:\Windows\System32\shutdown.exe' `
                    -RebootDelaySeconds 5 `
                    -Confirm:$false
            } | Should -Throw 'Command failed:*'
        } -Parameters @{
            commandPath = $env:ComSpec
        }
    }

    It 'fails when the reboot command returns a non-zero exit code' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($commandPath)

            {
                Invoke-ResetNetworkAndReboot `
                    -RequireAdmin $false `
                    -IsAdministrator $true `
                    -IsWindowsSandbox $false `
                    -Commands @(
                        @{
                            FilePath  = $commandPath
                            Arguments = @('/c', 'exit', '0')
                        }
                    ) `
                    -ShutdownPath $commandPath `
                    -RebootDelaySeconds 5 `
                    -Confirm:$false
            } | Should -Throw 'Command failed:*'
        } -Parameters @{
            commandPath = $env:ComSpec
        }
    }
}
