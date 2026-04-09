. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 logged spool cleanup behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
        try {
            Add-Type -AssemblyName 'System.ServiceProcess' -ErrorAction Stop
        }
        catch {
            Add-Type -AssemblyName 'System.ServiceProcess.ServiceController' -ErrorAction Stop
        }
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Printer\restart.SpoolDeleteQV4.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
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
            serviceName    = 'Spooler'
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            logDirectory   = 'C:\ProgramData\sysadmin-main\Logs\Printer'
            storageRoot    = 'C:\ProgramData\sysadmin-main'
            logPath        = 'C:\ProgramData\sysadmin-main\Logs\Printer\print-queue-20250102.log'
        }
    }
}
