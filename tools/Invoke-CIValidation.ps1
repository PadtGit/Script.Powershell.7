#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipModuleInstall,

    [version]$RequiredPSScriptAnalyzerVersion = [version]'1.25.0',

    [version]$MinimumPesterVersion = [version]'5.0.0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$RepoRoot = Split-Path -Path $ScriptRoot -Parent
$ValidationRoot = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation'
$PesterResultPath = Join-Path -Path $ValidationRoot -ChildPath 'pester-results.xml'
$WindowsPowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'

try {
    $CurrentPowerShellPath = (Get-Process -Id $PID -ErrorAction Stop).Path
}
catch {
    $CurrentPowerShellPath = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { $WindowsPowerShellPath }
}

function Write-Section {
    param([string]$Title)

    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}

function Invoke-NativeStep {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory)]
        [string]$FailureMessage
    )

    & $FilePath @ArgumentList
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        throw "$FailureMessage ExitCode=$ExitCode."
    }
}

function Initialize-PowerShellGallery {
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    if (Get-Command -Name Get-PSRepository -ErrorAction SilentlyContinue) {
        $Gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $Gallery -and (Get-Command -Name Register-PSRepository -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default
            $Gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        }

        if ($Gallery -and $Gallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
    }

    if (Get-Command -Name Install-PackageProvider -ErrorAction SilentlyContinue) {
        $NuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $NuGetProvider -or $NuGetProvider.Version -lt [version]'2.8.5.201') {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }
    }
}

function Ensure-ModuleInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [version]$RequiredVersion,

        [version]$MinimumVersion
    )

    $AvailableModules = @(Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending)
    $SelectedModule = $null

    if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
        $SelectedModule = $AvailableModules |
            Where-Object { $_.Version -eq $RequiredVersion } |
            Select-Object -First 1
    }
    elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
        $SelectedModule = $AvailableModules |
            Where-Object { $_.Version -ge $MinimumVersion } |
            Select-Object -First 1
    }
    else {
        $SelectedModule = $AvailableModules | Select-Object -First 1
    }

    if (-not $SelectedModule) {
        if ($SkipModuleInstall) {
            throw "Required module '$Name' is not available and -SkipModuleInstall was specified."
        }

        Write-Host "Installing module '$Name'..." -ForegroundColor DarkGray
        Initialize-PowerShellGallery

        $InstallSplat = @{
            Name               = $Name
            Scope              = 'CurrentUser'
            Force              = $true
            AllowClobber       = $true
            SkipPublisherCheck = $true
            ErrorAction        = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
            $InstallSplat.RequiredVersion = $RequiredVersion
        }
        elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
            $InstallSplat.MinimumVersion = $MinimumVersion
        }

        Install-Module @InstallSplat

        $AvailableModules = @(Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending)
        if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
            $SelectedModule = $AvailableModules |
                Where-Object { $_.Version -eq $RequiredVersion } |
                Select-Object -First 1
        }
        elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
            $SelectedModule = $AvailableModules |
                Where-Object { $_.Version -ge $MinimumVersion } |
                Select-Object -First 1
        }
        else {
            $SelectedModule = $AvailableModules | Select-Object -First 1
        }
    }

    if (-not $SelectedModule) {
        throw "Module '$Name' could not be resolved after installation."
    }

    if ($Name -eq 'Pester') {
        Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
    }

    if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
        Import-Module -Name $Name -RequiredVersion $RequiredVersion -Force -ErrorAction Stop | Out-Null
    }
    elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
        Import-Module -Name $Name -MinimumVersion $MinimumVersion -Force -ErrorAction Stop | Out-Null
    }
    else {
        Import-Module -Name $Name -Force -ErrorAction Stop | Out-Null
    }
}

function Ensure-WindowsPowerShellModuleInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [version]$RequiredVersion,

        [version]$MinimumVersion
    )

    if (-not (Test-Path -LiteralPath $WindowsPowerShellPath -PathType Leaf)) {
        return
    }

    $RequiredVersionText = if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
        $RequiredVersion.ToString()
    }
    else {
        ''
    }

    $MinimumVersionText = if ($PSBoundParameters.ContainsKey('MinimumVersion')) {
        $MinimumVersion.ToString()
    }
    else {
        ''
    }

    $AllowInstall = if ($SkipModuleInstall) { '$false' } else { '$true' }

    $CommandText = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Get-TargetModule {
    param(
        [string]`$Name,
        [string]`$RequiredVersion,
        [string]`$MinimumVersion
    )

    `$AvailableModules = @(Get-Module -ListAvailable -Name `$Name | Sort-Object Version -Descending)

    if (-not [string]::IsNullOrWhiteSpace(`$RequiredVersion)) {
        return `$AvailableModules |
            Where-Object { `$_.Version -eq [version]`$RequiredVersion } |
            Select-Object -First 1
    }

    if (-not [string]::IsNullOrWhiteSpace(`$MinimumVersion)) {
        return `$AvailableModules |
            Where-Object { `$_.Version -ge [version]`$MinimumVersion } |
            Select-Object -First 1
    }

    return `$AvailableModules | Select-Object -First 1
}

`$Module = Get-TargetModule -Name '$Name' -RequiredVersion '$RequiredVersionText' -MinimumVersion '$MinimumVersionText'
if (-not `$Module) {
    if (-not $AllowInstall) {
        throw "Required module '$Name' is not available in Windows PowerShell and -SkipModuleInstall was specified."
    }

    if (Get-Command -Name Get-PSRepository -ErrorAction SilentlyContinue) {
        `$Gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not `$Gallery -and (Get-Command -Name Register-PSRepository -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default
            `$Gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        }

        if (`$Gallery -and `$Gallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
    }

    if (Get-Command -Name Install-PackageProvider -ErrorAction SilentlyContinue) {
        `$NuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not `$NuGetProvider -or `$NuGetProvider.Version -lt [version]'2.8.5.201') {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }
    }

    `$InstallSplat = @{
        Name               = '$Name'
        Scope              = 'CurrentUser'
        Force              = `$true
        AllowClobber       = `$true
        SkipPublisherCheck = `$true
        ErrorAction        = 'Stop'
    }

    if (-not [string]::IsNullOrWhiteSpace('$RequiredVersionText')) {
        `$InstallSplat.RequiredVersion = [version]'$RequiredVersionText'
    }
    elseif (-not [string]::IsNullOrWhiteSpace('$MinimumVersionText')) {
        `$InstallSplat.MinimumVersion = [version]'$MinimumVersionText'
    }

    Install-Module @InstallSplat
    `$Module = Get-TargetModule -Name '$Name' -RequiredVersion '$RequiredVersionText' -MinimumVersion '$MinimumVersionText'
}

if (-not `$Module) {
    throw "Module '$Name' could not be resolved in Windows PowerShell after installation."
}
"@

    Invoke-NativeStep -FilePath $WindowsPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command', $CommandText
    ) -FailureMessage "Failed to provision Windows PowerShell module '$Name'."
}

New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null

Push-Location -Path $RepoRoot
try {
    Write-Section 'Module Setup'
    Ensure-ModuleInstalled -Name PSScriptAnalyzer -RequiredVersion $RequiredPSScriptAnalyzerVersion
    Ensure-ModuleInstalled -Name Pester -MinimumVersion $MinimumPesterVersion

    Write-Section 'PSScriptAnalyzer'
    Invoke-NativeStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path -Path $ScriptRoot -ChildPath 'Invoke-PSScriptAnalyzer.ps1'),
        '-Path', $RepoRoot,
        '-Recurse',
        '-SettingsPath', (Join-Path -Path $ScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'),
        '-EnableExit',
        '-ExitCodeMode', 'AllDiagnostics'
    ) -FailureMessage 'PSScriptAnalyzer validation failed.'

    Write-Section 'Pester'
    $Configuration = New-PesterConfiguration
    $Configuration.Run.Path = Join-Path -Path $RepoRoot -ChildPath 'tests'
    $Configuration.Run.PassThru = $true
    $Configuration.Output.Verbosity = 'Detailed'
    $Configuration.TestResult.Enabled = $true
    $Configuration.TestResult.OutputPath = $PesterResultPath
    $Configuration.TestResult.OutputFormat = 'NUnitXml'
    $PesterResult = Invoke-Pester -Configuration $Configuration

    if (-not $PesterResult -or $PesterResult.Result -ne 'Passed') {
        throw "Pester validation failed with result '$($PesterResult.Result)'."
    }

    Write-Section 'Fixed WhatIf Validation'
    Invoke-NativeStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path -Path $RepoRoot -ChildPath 'Invoke-WhatIfValidation.ps1'),
        '-PowerShell7Path', $CurrentPowerShellPath,
        '-WindowsPowerShellPath', $WindowsPowerShellPath
    ) -FailureMessage 'Fixed WhatIf validation failed.'

    Write-Section 'Trusted V7 Smoke Checks'
    Invoke-NativeStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\Printer\Restart.Spool.DeletePrinterQSimple.ps1'),
        '-WhatIf'
    ) -FailureMessage 'V7 printer smoke check failed.'

    Invoke-NativeStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script\V7\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1'),
        '-WhatIf'
    ) -FailureMessage 'V7 cleanup smoke check failed.'

    Write-Section 'Validation Complete'
    Write-Host 'All CI validation steps passed.' -ForegroundColor Green
}
finally {
    Pop-Location
}
