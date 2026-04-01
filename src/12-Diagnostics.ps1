<#
.SYNOPSIS
    Profile component 12 - Self-Diagnostics And Troubleshooting
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 12 (SELF-DIAGNOSTICS AND TROUBLESHOOTING) for modular dot-sourced loading.
#>

#region 12 - SELF-DIAGNOSTICS AND TROUBLESHOOTING
#==============================================================================
<#
.SYNOPSIS
    Self-diagnostics and troubleshooting functions
.DESCRIPTION
    Provides comprehensive diagnostics for the PowerShell profile and system.
#>

function Test-ProfileHealth {
    <#
    .SYNOPSIS
        Tests profile health and reports issues.
    .DESCRIPTION
        Runs diagnostics on profile configuration, modules, and environment.
    .PARAMETER Repair
        Attempt to repair issues automatically.
    #>
    [CmdletBinding()]
    param([switch]$Repair)

    $report = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
        Tests = @()
        Issues = @()
        Recommendations = @()
    }

    # Test 1: PowerShell version
    $verOk = $PSVersionTable.PSVersion.Major -ge 7
    $report.Tests += [pscustomobject]@{ Test = 'PowerShell Version'; Status = if ($verOk) { 'PASS' } else { 'FAIL' }; Details = $PSVersionTable.PSVersion }
    if (-not $verOk) { $report.Issues += 'PowerShell version is below 7.0' }

    # Test 2: Execution policy
    $execPol = Get-ExecutionPolicy
    $execOk = $execPol -in @('RemoteSigned', 'Unrestricted', 'Bypass')
    $report.Tests += [pscustomobject]@{ Test = 'Execution Policy'; Status = if ($execOk) { 'PASS' } else { 'WARN' }; Details = $execPol }
    if (-not $execOk) { $report.Recommendations += "Consider: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" }

    # Test 3: Required directories
    $paths = @($Global:ProfileConfig.LogPath, $Global:ProfileConfig.CachePath)
    foreach ($p in $paths) {
        $pathOk = Test-Path $p
        $report.Tests += [pscustomobject]@{ Test = "Path: $(Split-Path $p -Leaf)"; Status = if ($pathOk) { 'PASS' } else { 'FAIL' }; Details = $p }
        if (-not $pathOk -and $Repair) {
            try {
                New-Item -Path $p -ItemType Directory -Force | Out-Null
                $report.Recommendations += "Repaired missing path: $p"
            } catch {
                $report.Issues += "Failed to repair path: $p"
                Write-CaughtException -Context "Test-ProfileHealth repair path '$p'" -ErrorRecord $_ -Component "Diagnostics" -Level DEBUG
            }
        }
    }

    # Test 4: Module availability
    $essentialModules = @('PSReadLine')
    foreach ($m in $essentialModules) {
        $modOk = Test-ModuleAvailable -Name $m
        $report.Tests += [pscustomobject]@{ Test = "Module: $m"; Status = if ($modOk) { 'PASS' } else { 'WARN' }; Details = if ($modOk) { 'Available' } else { 'Not installed' } }
    }

    # Test 5: PSReadLine configuration
    $psrlOk = $null -ne (Get-Command Get-PSReadLineOption -ErrorAction Ignore)
    $report.Tests += [pscustomobject]@{ Test = 'PSReadLine Config'; Status = if ($psrlOk) { 'PASS' } else { 'WARN' }; Details = if ($psrlOk) { 'Configured' } else { 'Not configured' } }

    # Test 6: Deferred modules
    if ($Global:DeferredModulesStatus.Completed) {
        $report.Tests += [pscustomobject]@{ Test = 'Deferred Modules'; Status = 'PASS'; Details = 'Completed' }
    } else {
        $report.Tests += [pscustomobject]@{ Test = 'Deferred Modules'; Status = 'PENDING'; Details = 'Not completed' }
    }

    return [PSCustomObject]$report
}

function Show-ProfileDiagnostics {
    <#
    .SYNOPSIS
        Displays profile diagnostics report.
    .DESCRIPTION
        Shows comprehensive profile diagnostics in a formatted display.
    .PARAMETER Detailed
        Show detailed information.
    #>
    [CmdletBinding()]
    param([switch]$Detailed)

    $report = Test-ProfileHealth

    Write-Host "`n=== Profile Diagnostics ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $($report.Timestamp)" -ForegroundColor DarkGray

    Write-Host "`nTest Results:" -ForegroundColor Yellow
    foreach ($t in $report.Tests) {
        $color = switch ($t.Status) {
            'PASS' { 'Green' }
            'FAIL' { 'Red' }
            'WARN' { 'Yellow' }
            default { 'Gray' }
        }
        Write-Host "  [$($t.Status)] $($t.Test)" -NoNewline -ForegroundColor $color
        Write-Host " - $($t.Details)" -ForegroundColor DarkGray
    }

    if ($report.Issues.Count -gt 0) {
        Write-Host "`nIssues Found:" -ForegroundColor Red
        foreach ($i in $report.Issues) {
            Write-Host "  - $i" -ForegroundColor Red
        }
    }

    if ($report.Recommendations.Count -gt 0) {
        Write-Host "`nRecommendations:" -ForegroundColor Cyan
        foreach ($r in $report.Recommendations) {
            Write-Host "  - $r" -ForegroundColor Yellow
        }
    }

    if ($Detailed) {
        Write-Host "`nProfile State:" -ForegroundColor Yellow
        $Global:ProfileState | Format-List | Out-String | Write-Host -ForegroundColor DarkGray

        Write-Host "`nProfile Stats:" -ForegroundColor Yellow
        $Global:ProfileStats | Format-List | Out-String | Write-Host -ForegroundColor DarkGray
    }

    Write-Host ""
}

function Repair-Profile {
    <#
    .SYNOPSIS
        Repairs common profile issues.
    .DESCRIPTION
        Attempts to repair profile configuration and recreate required directories.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess('Profile', 'Repair')) {
        Write-Host "Repairing profile..." -ForegroundColor Cyan

        # Recreate directories
        $paths = @($Global:ProfileConfig.LogPath, $Global:ProfileConfig.TranscriptPath,
                   $Global:ProfileConfig.CachePath, $Global:ProfileConfig.ThemesPath)
        foreach ($p in $paths) {
            if (-not (Test-Path $p)) {
                try {
                    New-Item -Path $p -ItemType Directory -Force | Out-Null
                    Write-Host "  Created: $p" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed: $p" -ForegroundColor Red
                }
            }
        }

        # Refresh module cache
        Update-InstalledModulesCache -Force | Out-Null
        Write-Host "  Module cache refreshed" -ForegroundColor Green

        # Reinitialize PSReadLine
        Initialize-PSReadLine | Out-Null
        Write-Host "  PSReadLine reinitialized" -ForegroundColor Green

        Write-Host "Profile repair completed." -ForegroundColor Cyan
    }
}

function Reset-ProfileToDefaults {
    <#
    .SYNOPSIS
        Resets profile to default state.
    .DESCRIPTION
        Clears caches and resets configuration to defaults.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    if ($PSCmdlet.ShouldProcess('Profile configuration', 'Reset to defaults')) {
        # Clear caches
        try {
            Remove-Item -Path (Join-Path $Global:ProfileConfig.CachePath '*') -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cache cleared." -ForegroundColor Green
        } catch {
            Write-CaughtException -Context "Reset-ProfileToDefaults cache cleanup" -ErrorRecord $_ -Component "Diagnostics" -Level WARN
        }

        # Clear logs (keep current month)
        try {
            Get-ChildItem -Path $Global:ProfileConfig.LogPath -Filter "profile_*.log" |
                Where-Object { $_.Name -ne "profile_$(Get-Date -Format 'yyyyMM').log" } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Old logs cleared." -ForegroundColor Green
        } catch {
            Write-CaughtException -Context "Reset-ProfileToDefaults log cleanup" -ErrorRecord $_ -Component "Diagnostics" -Level WARN
        }

        # Reset deferred modules
        $Global:DeferredModulesStatus = [ordered]@{
            Started = $false
            Completed = $false
            StartedAt = $null
            CompletedAt = $null
            Modules = @{}
            Jobs = @{}
        }

        Write-Host "Profile reset completed. Restart PowerShell to reload." -ForegroundColor Cyan
    }
}

#endregion SELF-DIAGNOSTICS AND TROUBLESHOOTING
