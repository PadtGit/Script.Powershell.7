#Requires -Version 5.1

<#
.SYNOPSIS
Runs PSScriptAnalyzer against one or more paths and writes text, JSON, and SARIF reports.

.DESCRIPTION
Resolves input paths, loads a validated PSScriptAnalyzer settings file, runs analysis in batch
with a per-file fallback, and writes artifacts for interactive review and CI systems.

.PARAMETER Path
One or more files or directories to analyze. Defaults to the current directory.

.PARAMETER SettingsPath
Path to the PSScriptAnalyzerSettings.psd1 file. Defaults to the file in the same directory
as this script.

.PARAMETER Recurse
Recursively scan input directories.

.PARAMETER IncludePath
Wildcard patterns. Only matching full paths are analyzed.

.PARAMETER ExcludePath
Wildcard patterns. Matching full paths are skipped.

.PARAMETER IncludeRule
Rule names to include at runtime.

.PARAMETER ExcludeRule
Rule names to exclude at runtime.

.PARAMETER CustomRulePath
One or more custom rule module paths.

.PARAMETER RecurseCustomRulePath
Search custom rule paths recursively.

.PARAMETER IncludeDefaultRules
Force enable default built-in rules at runtime.

.PARAMETER OutTxtPath
Destination path for the plain text report.

.PARAMETER OutJsonPath
Destination path for the JSON report.

.PARAMETER OutSarifPath
Destination path for the SARIF report.

.PARAMETER EnableExit
Exit with a non-zero code based on ExitCodeMode.

.PARAMETER ExitCodeMode
AllDiagnostics returns the total findings count up to 255.
ErrorsOnly returns the error findings count up to 255.
AnyError returns 1 when at least one error exists.

.PARAMETER AutoInstallModule
Install PSScriptAnalyzer automatically if it is not available.

.PARAMETER RequiredPSScriptAnalyzerVersion
Required PSScriptAnalyzer version.

.PARAMETER PSScriptAnalyzerModulePath
Optional explicit module manifest path for PSScriptAnalyzer.

.EXAMPLE
.\Invoke-PSScriptAnalyzer.ps1 -Path . -Recurse -EnableExit

.EXAMPLE
.\Invoke-PSScriptAnalyzer.ps1 -Path . -Recurse -ExitCodeMode AnyError -EnableExit
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Path = @('.'),
    [string]$SettingsPath = '',
    [switch]$Recurse,
    [string[]]$IncludePath,
    [string[]]$ExcludePath,
    [string[]]$IncludeRule,
    [string[]]$ExcludeRule,
    [string[]]$CustomRulePath,
    [switch]$RecurseCustomRulePath,
    [switch]$IncludeDefaultRules,
    [string]$OutTxtPath = '',
    [string]$OutJsonPath = '',
    [string]$OutSarifPath = '',
    [switch]$EnableExit,
    [ValidateSet('AllDiagnostics', 'ErrorsOnly', 'AnyError')]
    [string]$ExitCodeMode = 'ErrorsOnly',
    [switch]$AutoInstallModule,
    [Alias('MinimumPSScriptAnalyzerVersion')]
    [version]$RequiredPSScriptAnalyzerVersion = [version]'1.25.0',
    [string]$PSScriptAnalyzerModulePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Success', 'Error')]
        [string]$Level = 'Info'
    )

    $Prefix = switch ($Level) {
        'Warning' { '[WARN ]' }
        'Success' { '[ OK  ]' }
        'Error' { '[FAIL ]' }
        default { '[INFO ]' }
    }

    Write-Information -MessageData ('{0} {1}' -f $Prefix, $Message) -InformationAction Continue
}

function Install-AnalyzerModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$RequiredVersion
    )

    if (-not $AutoInstallModule) {
        throw "PSScriptAnalyzer version $RequiredVersion is required. Use -AutoInstallModule or preinstall the module."
    }

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

    Install-Module -Name 'PSScriptAnalyzer' -RequiredVersion $RequiredVersion -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
}

function Import-AnalyzerModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$RequiredVersion,
        [string]$ModulePath = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($ModulePath)) {
        if (-not (Test-Path -LiteralPath $ModulePath -PathType Leaf)) {
            throw "PSScriptAnalyzerModulePath not found: $ModulePath"
        }

        Import-Module -Name $ModulePath -Force -ErrorAction Stop | Out-Null
        $LoadedModule = Get-Module -Name 'PSScriptAnalyzer' | Sort-Object -Property Version -Descending | Select-Object -First 1
        if (-not $LoadedModule -or $LoadedModule.Version -ne $RequiredVersion) {
            throw "Loaded PSScriptAnalyzer version does not match required version $RequiredVersion."
        }

        return $LoadedModule
    }

    $AvailableModule = Get-Module -ListAvailable -Name 'PSScriptAnalyzer' |
        Where-Object { $_.Version -eq $RequiredVersion } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if (-not $AvailableModule) {
        Install-AnalyzerModule -RequiredVersion $RequiredVersion
        $AvailableModule = Get-Module -ListAvailable -Name 'PSScriptAnalyzer' |
            Where-Object { $_.Version -eq $RequiredVersion } |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
    }

    if (-not $AvailableModule) {
        throw "PSScriptAnalyzer version $RequiredVersion could not be resolved."
    }

    Import-Module -Name $AvailableModule.Path -Force -ErrorAction Stop | Out-Null
    return Get-Module -Name 'PSScriptAnalyzer' | Sort-Object -Property Version -Descending | Select-Object -First 1
}

function Get-ResolvedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    try {
        return (Resolve-Path -LiteralPath $InputPath -ErrorAction Stop).ProviderPath
    }
    catch {
        throw "Path not found: $InputPath"
    }
}

function Get-AnalyzerSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFilePath
    )

    if (-not (Test-Path -LiteralPath $SettingsFilePath -PathType Leaf)) {
        throw "Settings file not found: $SettingsFilePath"
    }

    try {
        $SettingsObject = Import-PowerShellDataFile -LiteralPath $SettingsFilePath -ErrorAction Stop
    }
    catch {
        throw "Failed to parse settings file '$SettingsFilePath'. $($_.Exception.Message)"
    }

    if (-not $SettingsObject) {
        throw "Settings file '$SettingsFilePath' returned no data."
    }

    foreach ($PropertyName in @('IncludeRules', 'ExcludeRules', 'CustomRulePath', 'Severity')) {
        if ($SettingsObject.ContainsKey($PropertyName) -and $null -eq $SettingsObject[$PropertyName]) {
            $SettingsObject[$PropertyName] = @()
        }
    }

    if ($SettingsObject.ContainsKey('Rules') -and $SettingsObject.Rules) {
        foreach ($RuleName in @($SettingsObject.Rules.Keys)) {
            if (-not ($SettingsObject.Rules[$RuleName] -is [hashtable])) {
                throw "Rule '$RuleName' in settings must be a hashtable."
            }
        }
    }

    return $SettingsObject
}

function Test-PathMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [string[]]$Patterns
    )

    foreach ($Pattern in @($Patterns)) {
        if (-not [string]::IsNullOrWhiteSpace($Pattern) -and $PathValue -like $Pattern) {
            return $true
        }
    }

    return $false
}

function Get-NormalizedStringArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Values
    )

    [string[]]$NormalizedValues = @(
        @($Values) |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    return $NormalizedValues
}

function Get-TargetFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputPaths,
        [switch]$DoRecurse,
        [string[]]$IncludePatterns,
        [string[]]$ExcludePatterns
    )

    $Extensions = @('.ps1', '.psm1', '.psd1')
    $Result = New-Object 'System.Collections.Generic.List[string]'
    $NormalizedIncludePatterns = @(Get-NormalizedStringArray -Values $IncludePatterns)
    $NormalizedExcludePatterns = @(Get-NormalizedStringArray -Values $ExcludePatterns)
    $HasIncludePatterns = $NormalizedIncludePatterns.Count -gt 0

    foreach ($InputPath in @($InputPaths)) {
        $ResolvedPath = Get-ResolvedPath -InputPath $InputPath
        $Item = Get-Item -LiteralPath $ResolvedPath -ErrorAction Stop

        if ($Item.PSIsContainer) {
            $ChildItems = Get-ChildItem -LiteralPath $ResolvedPath -File -Recurse:$DoRecurse -ErrorAction Stop
            foreach ($ChildItem in $ChildItems) {
                if ($Extensions -notcontains $ChildItem.Extension) {
                    continue
                }

                $FullPath = $ChildItem.FullName

                if ($HasIncludePatterns -and -not (Test-PathMatch -PathValue $FullPath -Patterns $NormalizedIncludePatterns)) {
                    continue
                }

                if (Test-PathMatch -PathValue $FullPath -Patterns $NormalizedExcludePatterns) {
                    continue
                }

                if (-not $Result.Contains($FullPath)) {
                    $Result.Add($FullPath)
                }
            }
        }
        else {
            if ($Extensions -notcontains $Item.Extension) {
                continue
            }

            $FullPath = $Item.FullName

            if ($HasIncludePatterns -and -not (Test-PathMatch -PathValue $FullPath -Patterns $NormalizedIncludePatterns)) {
                continue
            }

            if (Test-PathMatch -PathValue $FullPath -Patterns $NormalizedExcludePatterns) {
                continue
            }

            if (-not $Result.Contains($FullPath)) {
                $Result.Add($FullPath)
            }
        }
    }

    return @($Result | Sort-Object)
}

function Get-SarifLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic,
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $PhysicalLocation = @{
        artifactLocation = @{
            uri = ($Diagnostic.ScriptPath -replace '\\', '/')
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectRoot) -and
        $Diagnostic.ScriptPath -like ($ProjectRoot.TrimEnd('\', '/') + '*')) {
        $RelativePath = $Diagnostic.ScriptPath.Substring($ProjectRoot.TrimEnd('\', '/').Length).TrimStart('\', '/')
        if (-not [string]::IsNullOrWhiteSpace($RelativePath)) {
            $PhysicalLocation.artifactLocation.uri = ($RelativePath -replace '\\', '/')
        }
    }

    if ($Diagnostic.Line -and $Diagnostic.Column) {
        $PhysicalLocation.region = @{
            startLine = [int]$Diagnostic.Line
            startColumn = [int]$Diagnostic.Column
        }
    }
    elseif ($Diagnostic.Line) {
        $PhysicalLocation.region = @{
            startLine = [int]$Diagnostic.Line
        }
    }

    return @{
        physicalLocation = $PhysicalLocation
    }
}

function ConvertTo-SarifObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Diagnostics,
        [Parameter(Mandatory = $true)]
        [string]$ToolVersion,
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $RuleTable = @{}
    foreach ($Diagnostic in @($Diagnostics)) {
        if ($null -eq $Diagnostic -or [string]::IsNullOrWhiteSpace([string]$Diagnostic.RuleName)) {
            continue
        }

        if (-not $RuleTable.ContainsKey($Diagnostic.RuleName)) {
            $RuleTable[$Diagnostic.RuleName] = @{
                id = [string]$Diagnostic.RuleName
                name = [string]$Diagnostic.RuleName
                shortDescription = @{ text = [string]$Diagnostic.RuleName }
                fullDescription = @{ text = [string]$Diagnostic.Message }
                defaultConfiguration = @{ level = ([string]$Diagnostic.Severity).ToLowerInvariant() }
            }
        }
    }

    $Results = @()
    foreach ($Diagnostic in @($Diagnostics)) {
        if ($null -eq $Diagnostic) {
            continue
        }

        $ResultItem = @{
            ruleId = [string]$Diagnostic.RuleName
            level = ([string]$Diagnostic.Severity).ToLowerInvariant()
            message = @{
                text = [string]$Diagnostic.Message
            }
            locations = @(
                Get-SarifLocation -Diagnostic $Diagnostic -ProjectRoot $ProjectRoot
            )
        }

        $Results += $ResultItem
    }

    return [ordered]@{
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        version = '2.1.0'
        runs = @(
            @{
                tool = @{
                    driver = @{
                        name = 'PSScriptAnalyzer'
                        semanticVersion = $ToolVersion
                        rules = @($RuleTable.Values | Sort-Object -Property id)
                    }
                }
                results = $Results
            }
        )
    }
}

function Get-AnalyzerErrorRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return [pscustomobject]@{
        Message = $Message
        RuleName = 'PSScriptAnalyzerInvocationFailure'
        Severity = 'Error'
        ScriptName = [System.IO.Path]::GetFileName($FilePath)
        ScriptPath = $FilePath
        Line = $null
        Column = $null
    }
}

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $ScriptRoot = $PWD.Path
}
else {
    $ScriptRoot = $PSScriptRoot
}

$RepoRoot = Split-Path -Path $ScriptRoot -Parent

if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
    $SettingsPath = Join-Path -Path $ScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
}

if ([string]::IsNullOrWhiteSpace($OutTxtPath)) {
    $OutTxtPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts/validation/psscriptanalyzer.txt'
}

if ([string]::IsNullOrWhiteSpace($OutJsonPath)) {
    $OutJsonPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts/validation/psscriptanalyzer.json'
}

if ([string]::IsNullOrWhiteSpace($OutSarifPath)) {
    $OutSarifPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts/validation/psscriptanalyzer.sarif'
}

foreach ($OutputPath in @($OutTxtPath, $OutJsonPath, $OutSarifPath)) {
    $OutputDirectory = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -and
        -not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
}

$LoadedModule = Import-AnalyzerModule -RequiredVersion $RequiredPSScriptAnalyzerVersion -ModulePath $PSScriptAnalyzerModulePath
Write-Status -Message ("Using PSScriptAnalyzer version {0}." -f $LoadedModule.Version) -Level Success

$Settings = Get-AnalyzerSettings -SettingsFilePath $SettingsPath
$NormalizedSettingsIncludeRules = @(Get-NormalizedStringArray -Values $Settings.IncludeRules)
$NormalizedSettingsExcludeRules = @(Get-NormalizedStringArray -Values $Settings.ExcludeRules)
$NormalizedSettingsCustomRulePath = @(Get-NormalizedStringArray -Values $Settings.CustomRulePath)
$NormalizedIncludeRule = @(Get-NormalizedStringArray -Values $IncludeRule)
$NormalizedExcludeRule = @(Get-NormalizedStringArray -Values $ExcludeRule)
$NormalizedCustomRulePath = @(Get-NormalizedStringArray -Values $CustomRulePath)

try {
    $KnownRules = Get-ScriptAnalyzerRule | Select-Object -ExpandProperty RuleName
}
catch {
    $KnownRules = @()
    Write-Status -Message ("Rule inventory could not be loaded. {0}" -f $_.Exception.Message) -Level Warning
}

$ReferencedRules = @()
$ReferencedRules += $NormalizedSettingsIncludeRules
$ReferencedRules += $NormalizedSettingsExcludeRules
$ReferencedRules += $NormalizedIncludeRule
$ReferencedRules += $NormalizedExcludeRule

if ($Settings.ContainsKey('Rules') -and $Settings.Rules) {
    $ReferencedRules += @($Settings.Rules.Keys)
}

$UnknownRules = @(
    $ReferencedRules |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $KnownRules -notcontains $_ } |
        Sort-Object -Unique
)

if (@($UnknownRules).Count -gt 0) {
    Write-Status -Message ("Unknown rule names detected: {0}" -f ($UnknownRules -join ', ')) -Level Warning
}

$DefaultExcludePath = @(
    '*\.git\*',
    '*/.git/*',
    '*\artifacts\*',
    '*/artifacts/*'
)

$EffectiveExcludePath = @($ExcludePath) + $DefaultExcludePath

$TargetFiles = Get-TargetFiles -InputPaths $Path -DoRecurse:$Recurse -IncludePatterns $IncludePath -ExcludePatterns $EffectiveExcludePath

if (@($TargetFiles).Count -eq 0) {
    $NoFindingsMessage = 'No PowerShell files found for analysis.'
    Write-Status -Message $NoFindingsMessage -Level Warning
    Set-Content -LiteralPath $OutTxtPath -Value $NoFindingsMessage -Encoding UTF8
    '[]' | Set-Content -LiteralPath $OutJsonPath -Encoding UTF8

    $EmptySarif = ConvertTo-SarifObject -Diagnostics @() -ToolVersion $LoadedModule.Version.ToString() -ProjectRoot $RepoRoot
    $EmptySarif | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutSarifPath -Encoding UTF8

    if ($EnableExit) {
        exit 0
    }

    return @()
}

$AnalyzerSettings = @{}
foreach ($PropertyName in @($Settings.Keys)) {
    $Value = $Settings[$PropertyName]

    switch ($PropertyName) {
        'IncludeRules' {
            if ($NormalizedSettingsIncludeRules.Count -gt 0) {
                $AnalyzerSettings[$PropertyName] = $NormalizedSettingsIncludeRules
            }
            continue
        }
        'ExcludeRules' {
            if ($NormalizedSettingsExcludeRules.Count -gt 0) {
                $AnalyzerSettings[$PropertyName] = $NormalizedSettingsExcludeRules
            }
            continue
        }
        'CustomRulePath' {
            if ($NormalizedSettingsCustomRulePath.Count -gt 0) {
                $AnalyzerSettings[$PropertyName] = $NormalizedSettingsCustomRulePath
            }
            continue
        }
    }

    $AnalyzerSettings[$PropertyName] = $Value
}

if ($NormalizedIncludeRule.Count -gt 0) {
    $AnalyzerSettings.IncludeRules = $NormalizedIncludeRule
}

if ($NormalizedExcludeRule.Count -gt 0) {
    $AnalyzerSettings.ExcludeRules = $NormalizedExcludeRule
}

if ($NormalizedCustomRulePath.Count -gt 0) {
    $ResolvedCustomRulePath = @()
    foreach ($RulePath in $NormalizedCustomRulePath) {
        $ResolvedCustomRulePath += (Get-ResolvedPath -InputPath $RulePath)
    }

    $AnalyzerSettings.CustomRulePath = $ResolvedCustomRulePath
}

if ($PSBoundParameters.ContainsKey('RecurseCustomRulePath')) {
    $AnalyzerSettings.RecurseCustomRulePath = [bool]$RecurseCustomRulePath
}

if ($PSBoundParameters.ContainsKey('IncludeDefaultRules')) {
    $AnalyzerSettings.IncludeDefaultRules = [bool]$IncludeDefaultRules
}

Write-Status -Message ("Running analysis against {0} file(s)." -f @($TargetFiles).Count)

$AllResults = New-Object 'System.Collections.Generic.List[object]'

try {
    $BatchResults = @(
        $TargetFiles |
            Invoke-ScriptAnalyzer -Settings $AnalyzerSettings -ErrorAction Stop
    )
    foreach ($Item in @($BatchResults)) {
        if ($null -ne $Item) {
            $AllResults.Add($Item)
        }
    }
}
catch {
    Write-Status -Message ("Batch analysis failed. Falling back to per-file mode. {0}" -f $_.Exception.Message) -Level Warning

    foreach ($FilePath in @($TargetFiles)) {
        try {
            $PerFileResults = Invoke-ScriptAnalyzer -Path $FilePath -Settings $AnalyzerSettings -ErrorAction Stop
            foreach ($Item in @($PerFileResults)) {
                if ($null -ne $Item) {
                    $AllResults.Add($Item)
                }
            }
        }
        catch {
            $AllResults.Add((Get-AnalyzerErrorRecord -FilePath $FilePath -Message $_.Exception.Message))
        }
    }
}

$SeverityOrder = @{
    Error = 0
    Warning = 1
    Information = 2
    ParseError = 0
}

$Results = @(
    $AllResults |
        Sort-Object -Property @(
            { $SeverityOrder[[string]$_.Severity] },
            { [string]$_.RuleName },
            { [string]$_.ScriptPath },
            { [int]$_.Line }
        )
)

$ErrorCount = @($Results | Where-Object { $_.Severity -eq 'Error' }).Count
$WarningCount = @($Results | Where-Object { $_.Severity -eq 'Warning' }).Count
$InformationCount = @($Results | Where-Object { $_.Severity -eq 'Information' }).Count
$TotalCount = @($Results).Count

$ReportLines = New-Object 'System.Collections.Generic.List[string]'
$ReportLines.Add('PSScriptAnalyzer Report')
$ReportLines.Add(('Generated  : {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$ReportLines.Add(('Settings   : {0}' -f $SettingsPath))
$ReportLines.Add(('Module     : PSScriptAnalyzer v{0}' -f $LoadedModule.Version))
$ReportLines.Add(('RepoRoot   : {0}' -f $RepoRoot))
$ReportLines.Add('')
$ReportLines.Add('Summary')
$ReportLines.Add(('Error       : {0}' -f $ErrorCount))
$ReportLines.Add(('Warning     : {0}' -f $WarningCount))
$ReportLines.Add(('Information : {0}' -f $InformationCount))
$ReportLines.Add(('Total       : {0}' -f $TotalCount))
$ReportLines.Add('')
$ReportLines.Add('Findings')

if ($TotalCount -eq 0) {
    $ReportLines.Add('No findings.')
}
else {
    foreach ($Finding in @($Results)) {
        $ReportLines.Add(('[{0}] {1} | {2}:{3} | {4}' -f
                $Finding.Severity,
                $Finding.RuleName,
                $Finding.ScriptName,
                $Finding.Line,
                $Finding.Message))
    }
}

Set-Content -LiteralPath $OutTxtPath -Value $ReportLines -Encoding UTF8
if ($TotalCount -eq 0) {
    '[]' | Set-Content -LiteralPath $OutJsonPath -Encoding UTF8
}
else {
    $Results | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutJsonPath -Encoding UTF8
}

$Sarif = ConvertTo-SarifObject -Diagnostics $Results -ToolVersion $LoadedModule.Version.ToString() -ProjectRoot $RepoRoot
$Sarif | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutSarifPath -Encoding UTF8

Write-Status -Message ("Errors      : {0}" -f $ErrorCount)
Write-Status -Message ("Warnings    : {0}" -f $WarningCount)
Write-Status -Message ("Information : {0}" -f $InformationCount)
Write-Status -Message ("Total       : {0}" -f $TotalCount)
Write-Status -Message ("TXT report  : {0}" -f $OutTxtPath)
Write-Status -Message ("JSON report : {0}" -f $OutJsonPath)
Write-Status -Message ("SARIF report: {0}" -f $OutSarifPath)

if ($TotalCount -eq 0) {
    Write-Status -Message 'No findings. All checks passed.' -Level Success
}

if ($EnableExit) {
    $ExitCode = switch ($ExitCodeMode) {
        'AllDiagnostics' { [Math]::Min($TotalCount, 255) }
        'AnyError' {
            if ($ErrorCount -gt 0) {
                1
            }
            else {
                0
            }
        }
        default { [Math]::Min($ErrorCount, 255) }
    }

    if ($ExitCode -ne 0) {
        Write-Status -Message ("Exiting with code {0} using mode {1}." -f $ExitCode, $ExitCodeMode) -Level Error
    }

    exit $ExitCode
}

$Results
