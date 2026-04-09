. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 complete cleanup hardening' {

    BeforeAll {
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\windows-maintenance\Nettoyage.Complet.Caches.Windows.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses trusted cleanup specs and reparse-point guards' {
        $scriptPath = Join-Path (Get-SysadminMainRepoRoot) 'PowerShell Script\windows-maintenance\Nettoyage.Complet.Caches.Windows.ps1'
        $content = Get-Content -LiteralPath $scriptPath -Raw

        $content | Should -Match 'CleanupSpecs'
        $content | Should -Match 'Resolve-TrustedDirectoryPath'
        $content | Should -Match 'Test-IsReparsePoint'
        $content | Should -Not -Match '\$env:TEMP'
    }

    It 'counts only successful removals across update and cache cleanup loops' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($updateCachePath, $cleanupPath, $systemRoot)

            $updateItem = [pscustomobject]@{ FullName = (Join-Path $updateCachePath 'ok.bin') }
            $cleanupItem = [pscustomobject]@{ FullName = (Join-Path $cleanupPath 'locked.tmp') }
            $service = New-Object psobject -Property @{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }

            $script:RemovedPaths = @()

            Mock Get-Service { $service }
            Mock Resolve-TrustedDirectoryPath { $Path }
            Mock Get-SafeChildItem {
                param($Path)

                if ($Path -eq $updateCachePath) { return @($updateItem) }
                if ($Path -eq $cleanupPath) { return @($cleanupItem) }

                return @()
            }
            Mock Remove-Item {
                $script:RemovedPaths += $LiteralPath
                if ($LiteralPath -eq $cleanupItem.FullName) {
                    throw 'simulated remove failure'
                }
            }
            Mock Start-Service {}
            Mock Stop-Service {}
            Mock Clear-RecycleBin {}

            $result = Invoke-WindowsCacheCleanup `
                -RequireAdmin $false `
                -IsAdministrator $true `
                -CleanupSpecs @(
                    @{ Path = $cleanupPath; AllowedRoots = @($systemRoot) }
                ) `
                -UpdateServiceName 'wuauserv' `
                -UpdateCachePath $updateCachePath `
                -ServiceTimeoutSeconds 30 `
                -FlushDns $false `
                -ClearRecycleBin $false `
                -IpConfigPath 'C:\Windows\System32\ipconfig.exe'

            $result.CleanupPathCount | Should -Be 1
            $result.RemovedCount | Should -Be 1
            $result.FlushDns | Should -BeFalse
            $result.ClearRecycleBin | Should -BeFalse
            $result.Status | Should -Be 'Completed'

            $script:RemovedPaths.Count | Should -Be 2
            ($script:RemovedPaths -contains $updateItem.FullName) | Should -BeTrue
            ($script:RemovedPaths -contains $cleanupItem.FullName) | Should -BeTrue
            Assert-MockCalled Start-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Stop-Service -Times 0 -Exactly -Scope It
            Assert-MockCalled Clear-RecycleBin -Times 0 -Exactly -Scope It
        } -Parameters @{
            updateCachePath = 'C:\Windows\SoftwareDistribution\Download'
            cleanupPath     = 'C:\Windows\Temp'
            systemRoot      = 'C:\Windows'
        }
    }
}
