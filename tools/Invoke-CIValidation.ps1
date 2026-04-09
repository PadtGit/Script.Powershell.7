#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipModuleInstall,
    [version]$RequiredPSScriptAnalyzerVersion = [version]'1.25.0',
    [version]$MinimumPesterVersion = [version]'5.7.1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

$ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$RepoRoot = Split-Path -Path $ScriptRoot -Parent
$ValidationRoot = Join-Path -Path $RepoRoot -ChildPath 'artifacts/validation'
$PesterResultPath = Join-Path -Path $ValidationRoot -ChildPath 'pester-results.xml'
$WindowsPowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32/WindowsPowerShell/v1.0/powershell.exe'

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Success')]
        [string]$Level = 'Info'
    )

    $Prefix = switch ($Level) {
        'Warning' { '[WARN ]' }
        'Success' { '[ OK  ]' }
        default { '[INFO ]' }
    }

    Write-Information -MessageData ('{0} {1}' -f $Prefix, $Message) -InformationAction Continue
}

function Invoke-ExternalStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    if (-not (Get-Command -Name $FilePath -ErrorAction SilentlyContinue) -and
        -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Required executable or script not found: $FilePath"
    }

    & $FilePath @ArgumentList
    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
        throw '{0} ExitCode={1}.' -f $FailureMessage, $ExitCode
    }
}

function Initialize-PowerShellGet {
    [CmdletBinding()]
    param()

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    if (Get-Command -Name Get-PackageProvider -ErrorAction SilentlyContinue) {
        $NuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $NuGetProvider -or $NuGetProvider.Version -lt [version]'2.8.5.201') {
            Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Scope CurrentUser -Force | Out-Null
        }
    }

    if (Get-Command -Name Get-PSRepository -ErrorAction SilentlyContinue) {
        $Gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        if (-not $Gallery -and (Get-Command -Name Register-PSRepository -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default
            $Gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        }

        if ($Gallery -and $Gallery.InstallationPolicy -ne 'Trusted') {
            Write-Status -Message 'Setting PSGallery to Trusted for non-interactive module installation.' -Level Warning
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }
    }
}

function Install-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [version]$RequiredVersion,
        [version]$MinimumVersion
    )

    $AvailableModule = $null

    if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
        $AvailableModule = Get-Module -ListAvailable -Name $Name |
            Where-Object { $_.Version -eq $RequiredVersion } |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
    }
    elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
        $AvailableModule = Get-Module -ListAvailable -Name $Name |
            Where-Object { $_.Version -ge $MinimumVersion } |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
    }
    else {
        $AvailableModule = Get-Module -ListAvailable -Name $Name |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
    }

    if (-not $AvailableModule) {
        if ($SkipModuleInstall) {
            throw "Required module '$Name' is not installed and -SkipModuleInstall was specified."
        }

        Initialize-PowerShellGet

        $InstallSplat = @{
            Name = $Name
            Scope = 'CurrentUser'
            Force = $true
            AllowClobber = $true
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
            $InstallSplat.RequiredVersion = $RequiredVersion
        }
        elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
            $InstallSplat.MinimumVersion = $MinimumVersion
        }

        Write-Status -Message ("Installing module '{0}'." -f $Name)
        Install-Module @InstallSplat

        if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
            $AvailableModule = Get-Module -ListAvailable -Name $Name |
                Where-Object { $_.Version -eq $RequiredVersion } |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
        }
        elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
            $AvailableModule = Get-Module -ListAvailable -Name $Name |
                Where-Object { $_.Version -ge $MinimumVersion } |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
        }
        else {
            $AvailableModule = Get-Module -ListAvailable -Name $Name |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
        }
    }

    if (-not $AvailableModule) {
        throw "Module '$Name' could not be resolved after installation."
    }

    if ($Name -eq 'Pester') {
        Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
    }

    $ImportSplat = @{
        Name = $Name
        Force = $true
        ErrorAction = 'Stop'
    }

    if ($PSBoundParameters.ContainsKey('RequiredVersion')) {
        $ImportSplat.RequiredVersion = $RequiredVersion
    }
    elseif ($PSBoundParameters.ContainsKey('MinimumVersion')) {
        $ImportSplat.MinimumVersion = $MinimumVersion
    }

    Import-Module @ImportSplat | Out-Null

    Write-Status -Message ("Using module '{0}' version {1}." -f $Name, $AvailableModule.Version) -Level Success
}

function Invoke-OptionalScriptStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,
        [string[]]$ArgumentList = @()
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        Write-Status -Message ("Optional step skipped because file was not found: {0}" -f $ScriptPath) -Level Warning
        return
    }

    Invoke-ExternalStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $ScriptPath
    ) + $ArgumentList -FailureMessage $FailureMessage
}

try {
    if ($SkipModuleInstall) {
        Write-Status -Message 'Automatic module installation is disabled for this run.' -Level Warning
    }

    try {
        $CurrentPowerShellPath = (Get-Process -Id $PID -ErrorAction Stop).Path
    }
    catch {
        $CurrentPowerShellPath = 'pwsh'
    }

    if (-not (Test-Path -LiteralPath $ValidationRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $ValidationRoot -Force | Out-Null
    }

    Push-Location -Path $RepoRoot

    Write-Status -Message 'Starting CI validation.'
    Install-RequiredModule -Name 'PSScriptAnalyzer' -RequiredVersion $RequiredPSScriptAnalyzerVersion
    Install-RequiredModule -Name 'Pester' -MinimumVersion $MinimumPesterVersion

    $AnalyzerScriptPath = Join-Path -Path $ScriptRoot -ChildPath 'Invoke-PSScriptAnalyzer.ps1'
    $AnalyzerSettingsPath = Join-Path -Path $ScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'

    Write-Status -Message 'Running PSScriptAnalyzer.'
    Invoke-ExternalStep -FilePath $CurrentPowerShellPath -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $AnalyzerScriptPath,
        '-Path', $RepoRoot,
        '-Recurse',
        '-SettingsPath', $AnalyzerSettingsPath,
        '-EnableExit',
        '-ExitCodeMode', 'AllDiagnostics'
    ) -FailureMessage 'PSScriptAnalyzer validation failed.'

    $TestsPath = Join-Path -Path $RepoRoot -ChildPath 'tests'
    if (Test-Path -LiteralPath $TestsPath -PathType Container) {
        Write-Status -Message 'Running Pester tests.'
        $Configuration = New-PesterConfiguration
        $Configuration.Run.Path = $TestsPath
        $Configuration.Run.PassThru = $true
        $Configuration.Output.Verbosity = 'Detailed'
        $Configuration.TestResult.Enabled = $true
        $Configuration.TestResult.OutputPath = $PesterResultPath
        $Configuration.TestResult.OutputFormat = 'NUnitXml'

        $PesterResult = Invoke-Pester -Configuration $Configuration
        if (-not $PesterResult -or $PesterResult.Result -ne 'Passed') {
            throw "Pester validation failed with result '$($PesterResult.Result)'."
        }

        Write-Status -Message 'Pester tests passed.' -Level Success
    }
    else {
        Write-Status -Message 'Pester step skipped because tests folder was not found.' -Level Warning
    }

    Invoke-OptionalScriptStep -ScriptPath (Join-Path -Path $RepoRoot -ChildPath 'Invoke-WhatIfValidation.ps1') -FailureMessage 'Fixed WhatIf validation failed.' -ArgumentList @(
        '-PowerShell7Path', $CurrentPowerShellPath,
        '-WindowsPowerShellPath', $WindowsPowerShellPath
    )

    Invoke-OptionalScriptStep -ScriptPath (Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script/V7/Printer/Restart.Spool.DeletePrinterQSimple.ps1') -FailureMessage 'V7 printer smoke check failed.' -ArgumentList @('-WhatIf')

    Invoke-OptionalScriptStep -ScriptPath (Join-Path -Path $RepoRoot -ChildPath 'PowerShell Script/V7/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1') -FailureMessage 'V7 cleanup smoke check failed.' -ArgumentList @('-WhatIf')

    Write-Status -Message 'All CI validation steps passed.' -Level Success
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
}

