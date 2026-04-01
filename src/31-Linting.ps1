<#
.SYNOPSIS
    Profile component 31 - Testing And Linting Integration
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 31 (TESTING AND LINTING INTEGRATION) for modular dot-sourced loading.
#>

#region 31 - TESTING AND LINTING INTEGRATION
#==============================================================================
<#
.SYNOPSIS
    PSScriptAnalyzer and Pester integration for profile validation.
.DESCRIPTION
    Provides functions to lint the profile script and run smoke tests.
    PSScriptAnalyzer is used best-effort; Pester tests are in a companion file.
.EXAMPLE
    Test-ProfileScript
    Invoke-ProfileLint
#>

function Invoke-ProfileLint {
    <#
    .SYNOPSIS
        Runs PSScriptAnalyzer on the profile script.
    .PARAMETER Severity
        Minimum severity to report.
    .PARAMETER Fix
        Attempt automatic fixes (non-destructive, writes to a new file).
    .EXAMPLE
        Invoke-ProfileLint -Severity Warning
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateSet('Information','Warning','Error')]
        [string[]]$Severity = @('Error','Warning'),
        [switch]$Fix
    )

    if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction Ignore)) {
        try {
            Import-Module PSScriptAnalyzer -ErrorAction Stop
        } catch {
            Write-Host "PSScriptAnalyzer not available. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor Yellow
            return @()
        }
    }

    # Resolve profile path: prefer AllHosts, fall back to CurrentHost, then PSCommandPath
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath -or -not (Test-Path $profilePath)) {
        $profilePath = $PROFILE.CurrentUserCurrentHost
    }
    if (-not $profilePath -or -not (Test-Path $profilePath)) {
        # Final fallback: the script file that defined this function
        $profileRootVar = Get-Variable -Scope Script -Name ProfileRoot -ErrorAction Ignore
        $profileRoot = if ($profileRootVar -and $profileRootVar.Value) { $profileRootVar.Value } else { Split-Path -Parent $PSScriptRoot }
        $profilePath = Join-Path $profileRoot 'Microsoft.PowerShell_profile.ps1'
    }
    if (-not (Test-Path $profilePath)) {
        Write-Host "Profile script not found at expected path." -ForegroundColor Yellow
        return @()
    }

    try {
        $analyzerParams = @{
            Path     = $profilePath
            Severity = $Severity
        }
        # Use settings file if available
        $settingsPath = Join-Path (Split-Path $profilePath) 'PSScriptAnalyzerSettings.psd1'
        if (Test-Path $settingsPath) { $analyzerParams.Settings = $settingsPath }

        $results = Invoke-ScriptAnalyzer @analyzerParams
        if ($results) {
            Write-Host "`nPSScriptAnalyzer Results ($($results.Count) findings):" -ForegroundColor Yellow
            $results | Format-Table RuleName, Severity, Line, Message -AutoSize
        } else {
            Write-Host "No issues found by PSScriptAnalyzer." -ForegroundColor Green
        }

        if ($Fix) {
            $fixedPath = $profilePath -replace '\.ps1$', '_fixed.ps1'
            $fixedContent = Invoke-ScriptAnalyzer -Path $profilePath -Fix -ErrorAction SilentlyContinue
            if ($fixedContent) {
                $fixedContent | Set-Content -Path $fixedPath -Encoding UTF8
            }
            Write-Host "Fixed version saved to: $fixedPath" -ForegroundColor Cyan
        }

        return $results
    } catch {
        Write-CaughtException -Context "Invoke-ProfileLint" -ErrorRecord $_ -Component "Linting" -Level WARN
        return @()
    }
}

function Test-ProfileScript {
    <#
    .SYNOPSIS
        Validates the profile script parses without errors.
    .DESCRIPTION
        Uses the PowerShell parser to check for syntax errors without executing.
    .EXAMPLE
        Test-ProfileScript
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath -or -not (Test-Path $profilePath)) { $profilePath = $PROFILE.CurrentUserCurrentHost }
    if (-not $profilePath -or -not (Test-Path $profilePath)) {
        $profileRootVar = Get-Variable -Scope Script -Name ProfileRoot -ErrorAction Ignore
        $profileRoot = if ($profileRootVar -and $profileRootVar.Value) { $profileRootVar.Value } else { Split-Path -Parent $PSScriptRoot }
        $profilePath = Join-Path $profileRoot 'Microsoft.PowerShell_profile.ps1'
    }
    if (-not (Test-Path $profilePath)) {
        return [PSCustomObject]@{ Valid = $false; Errors = @('Profile script not found'); Path = $profilePath }
    }

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$errors) | Out-Null

    $result = [PSCustomObject]@{
        Valid      = ($errors.Count -eq 0)
        ErrorCount = $errors.Count
        Errors     = $errors | ForEach-Object { [PSCustomObject]@{ Line=$_.Extent.StartLineNumber; Message=$_.Message } }
        Path       = $profilePath
        Timestamp  = (Get-Date).ToString('o')
    }

    if ($result.Valid) {
        Write-Host "Profile script is syntactically valid." -ForegroundColor Green
    } else {
        Write-Host "Profile script has $($result.ErrorCount) parse error(s):" -ForegroundColor Red
        foreach ($e in $result.Errors) {
            Write-Host "  Line $($e.Line): $($e.Message)" -ForegroundColor Red
        }
    }
    return $result
}

function Invoke-ProfilePesterTests {
    <#
    .SYNOPSIS
        Runs Pester smoke tests for the profile.
    .DESCRIPTION
        Looks for a companion test file and invokes Pester.
    .EXAMPLE
        Invoke-ProfilePesterTests
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command Invoke-Pester -ErrorAction Ignore)) {
        try {
            Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
        } catch {
            Write-Host "Pester 5+ not available. Install with: Install-Module Pester -Scope CurrentUser" -ForegroundColor Yellow
            return
        }
    }

    $testFile = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Microsoft.PowerShell_profile.Tests.ps1'
    if (-not (Test-Path $testFile)) {
        Write-Host "Test file not found: $testFile" -ForegroundColor Yellow
        Write-Host "Create it with Pester Describe/It blocks." -ForegroundColor DarkGray
        return
    }

    Invoke-Pester -Path $testFile -Output Detailed
}

#endregion ADDED: TESTING AND LINTING INTEGRATION
