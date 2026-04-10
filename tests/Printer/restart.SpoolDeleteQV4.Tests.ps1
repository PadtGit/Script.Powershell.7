. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V7 logged spool cleanup behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
        try {
            Add-Type -AssemblyName 'System.ServiceProcess' -ErrorAction Stop
        }
        catch {
            Add-Type -AssemblyName 'System.ServiceProcess.ServiceController' -ErrorAction Stop
        }
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\V7\Printer\restart.SpoolDeleteQV4.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns structured WhatIf output under direct script preview' {
        $result = Invoke-WhatIfScriptObject -RelativeScriptPath 'PowerShell Script\V7\Printer\restart.SpoolDeleteQV4.ps1'

        $result.Object | Should -Not -BeNullOrEmpty
        $result.Object.Status | Should -Be 'WhatIf'
        $result.Object.DeletedCount | Should -Be 0
        $result.Object.WhatIfRun | Should -BeTrue
    }

    It 'honors AllowedExtensions when selecting spool files' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($serviceName, $spoolDirectory, $logDirectory, $storageRoot, $logPath)

            $script:StorageRoot = $storageRoot
            $null = $logPath

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }
            $splFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job1.spl'))
            $shdFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job2.shd'))

            Mock Resolve-SecureDirectory { $Path }
            Mock Get-UniqueChildPath { $logPath }
            Mock Get-Service { $service }
            Mock Get-ChildItem { @($splFile, $shdFile) } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Start-Transcript {}
            Mock Stop-Transcript {}
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Remove-Item {}

            $result = Invoke-LoggedPrintQueueCleanup `
                -RequireAdmin $false `
                -IsAdministrator $false `
                -ServiceName $serviceName `
                -SpoolDirectory $spoolDirectory `
                -TimeoutSeconds 30 `
                -LogDirectory $logDirectory `
                -LogFilePrefix 'print-queue' `
                -AllowedExtensions @('.shd') `
                -TemporaryFilePattern '' `
                -Confirm:$false

            $result.FileCount | Should -Be 1
            $result.DeletedCount | Should -Be 1

            Assert-MockCalled Remove-Item -Times 1 -Exactly -Scope It -ParameterFilter {
                $LiteralPath -eq $shdFile.FullName
            }
        } -Parameters @{
            serviceName = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot = 'C:\ProgramData\sysadmin-main'
            logPath = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-20250102.log'
        }
    }

    It 'resolves a secure log path and suppresses transcript, service, and file mutations during WhatIf preview' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($serviceName, $spoolDirectory, $logDirectory, $storageRoot, $logPath)

            $script:StorageRoot = $storageRoot

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Running
            }
            $spoolFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job1.spl'))

            Mock Resolve-SecureDirectory { $Path }
            Mock Get-UniqueChildPath { $logPath }
            Mock Get-Service { $service }
            Mock Get-ChildItem { @($spoolFile) } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Start-Transcript {}
            Mock Stop-Transcript {}
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Remove-Item {}

            $invokeParams = @{
                RequireAdmin = $true
                IsAdministrator = $false
                ServiceName = $serviceName
                SpoolDirectory = $spoolDirectory
                TimeoutSeconds = 30
                LogDirectory = $logDirectory
                LogFilePrefix = 'print-queue'
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('AllowedExtensions')) {
                $invokeParams.AllowedExtensions = @('.spl', '.shd')
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('TemporaryFilePattern')) {
                $invokeParams.TemporaryFilePattern = 'FP*.tmp'
            }

            $result = Invoke-LoggedPrintQueueCleanup @invokeParams -WhatIf

            $result.LogPath | Should -Be $logPath
            if ($result.PSObject.Properties.Name -contains 'Status') {
                $result.Status | Should -Be 'WhatIf'
            }
            if ($result.PSObject.Properties.Name -contains 'DeletedCount') {
                $result.DeletedCount | Should -Be 0
            }
            if ($result.PSObject.Properties.Name -contains 'DeletedFiles') {
                $result.DeletedFiles | Should -Be 0
            }
            if ($result.PSObject.Properties.Name -contains 'WhatIfRun') {
                $result.WhatIfRun | Should -BeTrue
            }
            if ($result.PSObject.Properties.Name -contains 'ServiceWasUp') {
                $result.ServiceWasUp | Should -BeTrue
            }
            if ($result.PSObject.Properties.Name -contains 'Service') {
                $result.Service | Should -Be $serviceName
            }
            if ($result.PSObject.Properties.Name -contains 'ServiceName') {
                $result.ServiceName | Should -Be $serviceName
            }

            Assert-MockCalled Resolve-SecureDirectory -Times 1 -Exactly -Scope It -ParameterFilter {
                $Path -eq $logDirectory -and $AllowedRoots[0] -eq $storageRoot
            }
            Assert-MockCalled Get-UniqueChildPath -Times 1 -Exactly -Scope It -ParameterFilter {
                $Directory -eq $logDirectory -and $FileNamePrefix -eq 'print-queue' -and $Extension -eq '.log'
            }
            Assert-MockCalled Start-Transcript -Times 0 -Exactly -Scope It
            Assert-MockCalled Stop-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
            Assert-MockCalled Start-Service -Times 0 -Exactly -Scope It
        } -Parameters @{
            serviceName = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot = 'C:\ProgramData\sysadmin-main'
            logPath = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-20250102.log'
        }
    }

    It 'matches AllowedExtensions case-insensitively' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($serviceName, $spoolDirectory, $logDirectory, $storageRoot, $logPath)

            $script:StorageRoot = $storageRoot
            $null = $logPath

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }
            $customFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job1.foo'))
            $defaultFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job2.spl'))

            Mock Resolve-SecureDirectory { $Path }
            Mock Get-UniqueChildPath { $logPath }
            Mock Get-Service { $service }
            Mock Get-ChildItem { @($customFile, $defaultFile) } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Start-Transcript {}
            Mock Stop-Transcript {}
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Remove-Item {}

            $result = Invoke-LoggedPrintQueueCleanup `
                -RequireAdmin $false `
                -IsAdministrator $false `
                -ServiceName $serviceName `
                -SpoolDirectory $spoolDirectory `
                -TimeoutSeconds 30 `
                -LogDirectory $logDirectory `
                -LogFilePrefix 'print-queue' `
                -AllowedExtensions @('.FOO') `
                -TemporaryFilePattern 'FP*.tmp' `
                -Confirm:$false

            $result.FileCount | Should -Be 1
            $result.DeletedCount | Should -Be 1

            Assert-MockCalled Stop-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Start-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Remove-Item -Times 1 -Exactly -Scope It -ParameterFilter {
                $LiteralPath -eq $customFile.FullName
            }
        } -Parameters @{
            serviceName = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot = 'C:\ProgramData\sysadmin-main'
            logPath = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-custom.log'
        }
    }

    It 'does not restart the service when this invocation never stopped it' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($serviceName, $spoolDirectory, $logDirectory, $storageRoot, $logPath)

            $script:StorageRoot = $storageRoot
            $null = $logPath

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }

            Mock Resolve-SecureDirectory { $Path }
            Mock Get-UniqueChildPath { $logPath }
            Mock Get-Service { $service }
            Mock Get-ChildItem { @() } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Start-Transcript {}
            Mock Stop-Transcript {}
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Remove-Item {}

            $WhatIfPreference = $false

            $invokeParams = @{
                RequireAdmin = $false
                IsAdministrator = $false
                ServiceName = $serviceName
                SpoolDirectory = $spoolDirectory
                TimeoutSeconds = 30
                LogDirectory = $logDirectory
                LogFilePrefix = 'print-queue'
                Confirm = $false
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('AllowedExtensions')) {
                $invokeParams.AllowedExtensions = @('.spl', '.shd')
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('TemporaryFilePattern')) {
                $invokeParams.TemporaryFilePattern = 'FP*.tmp'
            }

            $result = Invoke-LoggedPrintQueueCleanup @invokeParams

            if ($result.PSObject.Properties.Name -contains 'ServiceWasUp') {
                $result.ServiceWasUp | Should -BeFalse
            }
            if ($result.PSObject.Properties.Name -contains 'DeletedCount') {
                $result.DeletedCount | Should -Be 0
            }
            if ($result.PSObject.Properties.Name -contains 'DeletedFiles') {
                $result.DeletedFiles | Should -Be 0
            }
            if ($result.PSObject.Properties.Name -contains 'Status') {
                $result.Status | Should -Be 'Completed'
            }

            Assert-MockCalled Start-Transcript -Times 1 -Exactly -Scope It
            Assert-MockCalled Stop-Transcript -Times 1 -Exactly -Scope It
            Assert-MockCalled Stop-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Start-Service -Times 0 -Exactly -Scope It
        } -Parameters @{
            serviceName = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot = 'C:\ProgramData\sysadmin-main'
            logPath = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-20250102.log'
        }
    }

    It 'restarts the service only when it was running and carries the FP temp cleanup rule' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($serviceName, $spoolDirectory, $logDirectory, $storageRoot, $logPath, $scriptPath)

            $script:StorageRoot = $storageRoot
            $null = $logPath

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Running
            }
            Add-Member -InputObject $service -MemberType ScriptMethod -Name WaitForStatus -Value {
                param($Status, $Timeout)
                $null = $Status, $Timeout
            } -Force
            Add-Member -InputObject $service -MemberType ScriptMethod -Name Refresh -Value { } -Force

            $scriptContent = Get-Content -LiteralPath $scriptPath -Raw

            Mock Resolve-SecureDirectory { $Path }
            Mock Get-UniqueChildPath { $logPath }
            Mock Get-Service { $service }
            Mock Get-ChildItem { @() } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Start-Transcript {}
            Mock Stop-Transcript {}
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Remove-Item {}

            $invokeParams = @{
                RequireAdmin = $false
                IsAdministrator = $false
                ServiceName = $serviceName
                SpoolDirectory = $spoolDirectory
                TimeoutSeconds = 30
                LogDirectory = $logDirectory
                LogFilePrefix = 'print-queue'
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('AllowedExtensions')) {
                $invokeParams.AllowedExtensions = @('.spl', '.shd')
            }
            if ((Get-Command Invoke-LoggedPrintQueueCleanup).Parameters.ContainsKey('TemporaryFilePattern')) {
                $invokeParams.TemporaryFilePattern = 'FP*.tmp'
            }

            $result = Invoke-LoggedPrintQueueCleanup @invokeParams

            if ($result.PSObject.Properties.Name -contains 'Success') {
                $result.Success | Should -BeTrue
            }
            if ($result.PSObject.Properties.Name -contains 'Status') {
                $result.Status | Should -Be 'Completed'
            }
            $scriptContent | Should -Match 'FP\*\.tmp'

            Assert-MockCalled Stop-Service -Times 1 -Exactly -Scope It
            Assert-MockCalled Start-Service -Times 1 -Exactly -Scope It
            Assert-MockCalled Get-ChildItem -Times 1 -Exactly -Scope It
            Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
        } -Parameters @{
            serviceName = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot = 'C:\ProgramData\sysadmin-main'
            logPath = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-20250102.log'
            scriptPath = (Join-Path (Get-SysadminMainRepoRoot) 'PowerShell Script\V7\Printer\restart.SpoolDeleteQV4.ps1')
        }
    }
}

