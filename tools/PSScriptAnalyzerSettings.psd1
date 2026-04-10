@{
    IncludeDefaultRules = $true
    Severity = @(
        'Error'
        'Warning'
        'Information'
    )
    IncludeRules = @()
    ExcludeRules = @()
    CustomRulePath = @()
    RecurseCustomRulePath = $false
    Rules = @{
        PSAlignAssignmentStatement = @{
            Enable = $false
        }
        PSAvoidAssignmentToAutomaticVariable = @{
            Enable = $true
        }
        PSAvoidDefaultValueForMandatoryParameter = @{
            Enable = $true
        }
        PSAvoidDefaultValueSwitchParameter = @{
            Enable = $true
        }
        PSAvoidExclaimOperator = @{
            Enable = $true
        }
        PSAvoidGlobalAliases = @{
            Enable = $true
        }
        PSAvoidGlobalFunctions = @{
            Enable = $true
        }
        PSAvoidGlobalVars = @{
            Enable = $true
        }
        PSAvoidInvokingEmptyMembers = @{
            Enable = $true
        }
        PSAvoidLongLines = @{
            Enable = $false
        }
        PSAvoidMultipleTypeAttributes = @{
            Enable = $true
        }
        PSAvoidNullOrEmptyHelpMessageAttribute = @{
            Enable = $true
        }
        PSAvoidOverwritingBuiltInCmdlets = @{
            Enable = $true
        }
        PSAvoidReservedWordsAsFunctionNames = @{
            Enable = $true
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }
        PSAvoidShouldContinueWithoutForce = @{
            Enable = $true
        }
        PSAvoidTrailingWhitespace = @{
            Enable = $true
        }
        PSAvoidUsingAllowUnencryptedAuthentication = @{
            Enable = $true
        }
        PSAvoidUsingBrokenHashAlgorithms = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingComputerNameHardcoded = @{
            Enable = $false
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }
        PSAvoidUsingDeprecatedManifestFields = @{
            Enable = $true
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $false
        }
        PSAvoidUsingEmptyCatchBlock = @{
            Enable = $true
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSAvoidUsingUsernameAndPasswordParams = @{
            Enable = $true
        }
        PSAvoidUsingWMICmdlet = @{
            Enable = $true
        }
        PSAvoidUsingWriteHost = @{
            Enable = $true
        }
        PSMisleadingBacktick = @{
            Enable = $true
        }
        PSMissingModuleManifestField = @{
            Enable = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
        }
        PSPlaceOpenBrace = @{
            Enable = $true
        }
        PSPossibleIncorrectComparisonWithNull = @{
            Enable = $true
        }
        PSPossibleIncorrectUsageOfAssignmentOperator = @{
            Enable = $true
        }
        PSPossibleIncorrectUsageOfRedirectionOperator = @{
            Enable = $true
        }
        PSProvideCommentHelp = @{
            Enable = $true
        }
        PSReservedCmdletChar = @{
            Enable = $true
        }
        PSReservedParams = @{
            Enable = $true
        }
        PSReviewUnusedParameter = @{
            Enable = $false
        }
        PSShouldProcess = @{
            Enable = $true
        }
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSUseBOMForUnicodeEncodedFile = @{
            Enable = $false
        }
        PSUseCmdletCorrectly = @{
            Enable = $true
        }
        PSUseCompatibleCmdlets = @{
            Enable = $false
        }
        PSUseCompatibleCommands = @{
            Enable = $false
        }
        PSUseCompatibleSyntax = @{
            Enable = $false
        }
        PSUseCompatibleTypes = @{
            Enable = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseConsistentParameterSetName = @{
            Enable = $true
        }
        PSUseConsistentParametersKind = @{
            Enable = $true
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckPipe = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
        }
        PSUseConstrainedLanguageMode = @{
            Enable = $false
        }
        PSUseCorrectCasing = @{
            Enable = $false
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
        PSUseLiteralInitializerForHashtable = @{
            Enable = $true
        }
        PSUseOutputTypeCorrectly = @{
            Enable = $true
        }
        PSUseProcessBlockForPipelineCommand = @{
            Enable = $true
        }
        PSUsePSCredentialType = @{
            Enable = $true
        }
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
        PSUseSingleValueFromPipelineParameter = @{
            Enable = $true
        }
        PSUseSingularNouns = @{
            Enable = $true
        }
        PSUseSupportsShouldProcess = @{
            Enable = $true
        }
        PSUseToExportFieldsInManifest = @{
            Enable = $true
        }
        PSUseUsingScopeModifierInNewRunspaces = @{
            Enable = $true
        }
        PSUseUTF8EncodingForHelpFile = @{
            Enable = $true
        }
    }
}
