@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidGlobalVars',
        'PSAvoidUsingWriteHost',
        'PSUseSingularNouns',
        'PSUseApprovedVerbs',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSReviewUnusedParameter',
        'PSUseBOMForUnicodeEncodedFile',
        'PSAvoidUsingInvokeExpression',
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
