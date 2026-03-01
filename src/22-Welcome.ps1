<#
.SYNOPSIS
    Profile component 22 - Welcome Screen And Finalization
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 22 (WELCOME SCREEN AND FINALIZATION) for modular dot-sourced loading.
#>

#region 22 - WELCOME SCREEN AND FINALIZATION
#==============================================================================
<#
.SYNOPSIS
    Welcome screen and profile finalization
.DESCRIPTION
    Displays welcome information and finalizes profile loading.
#>

function Show-WelcomeScreen {
    <#
    .SYNOPSIS
        Displays the profile welcome screen.
    .DESCRIPTION
        Shows system information and profile status on load.
    .PARAMETER Style
        Display style: Full, Minimal, or None.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Full', 'Minimal', 'None')]
        [string]$Style = 'Full'
    )

    if ($Style -eq 'None') { return }

    $loadTime = (Get-Date) - $Global:ProfileLoadStart

    if ($Style -eq 'Full') {
        # Fixed-width box: 62 inner chars between ║ and ║ (64 total with borders)
        $boxW = 60  # usable chars between "║  " and closing pad + "║"
        $verStr   = $script:ProfileVersion
        $timeStr  = '{0:N0} ms' -f $loadTime.TotalMilliseconds
        $adminStr = if (Test-Admin) { 'Yes' } else { 'No' }
        $modStr   = $Global:ProfileStats.ModulesLoaded.ToString()

        # Helper: pad a label+value line to fixed width inside the box
        function Format-BoxLine {
            param([string]$Label, [string]$Value)
            $content = "  $Label $Value"
            $pad = $boxW - $content.Length
            if ($pad -lt 0) { $pad = 0 }
            return "    ║$content$(' ' * $pad)  ║"
        }

        Write-Host ''
        Write-Host '    ╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
        Write-Host "    ║     PowerShell 7.5+ Professional Profile v$($script:ProfileVersion)$(' ' * (62 - 50 - $script:ProfileVersion.Length))║" -ForegroundColor Cyan
        Write-Host '    ╠══════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
        Write-Host (Format-BoxLine 'Version:'        $verStr)   -ForegroundColor Cyan
        Write-Host (Format-BoxLine 'Load Time:'      $timeStr)  -ForegroundColor Cyan
        Write-Host (Format-BoxLine 'Admin:'          $adminStr) -ForegroundColor Cyan
        Write-Host (Format-BoxLine 'Modules Loaded:' $modStr)   -ForegroundColor Cyan
        Write-Host '    ╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
        Write-Host ''

        # Quick tips
        Write-Host '    Quick Tips:' -ForegroundColor Yellow
        Write-Host "      • 'helpme'  – command reference          F1 – help on current cmd" -ForegroundColor DarkGray
        Write-Host "      • 'diag'    – profile diagnostics        F2 – toggle predictions" -ForegroundColor DarkGray
        Write-Host "      • 'sysinfo' – system information      Tab – completion menu" -ForegroundColor DarkGray
        Write-Host ''
    } else {
        Write-Host ""
        Write-Host "  PowerShell Profile v$script:ProfileVersion loaded in $($loadTime.TotalMilliseconds)ms" -ForegroundColor Cyan
        Write-Host "  Type 'helpme' for quick reference" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Show-ProfileSummary {
    <#
    .SYNOPSIS
        Shows a summary of profile capabilities.
    .DESCRIPTION
        Displays available functions and modules in the profile.
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== Profile Summary ===" -ForegroundColor Cyan

    # Profile functions
    $functions = Get-Command -CommandType Function | Where-Object {
        $_.Source -eq '' -and $_.Name -match '^(Get|Set|Test|Show|Invoke|Initialize|Clear|Update|Repair|Reset|Restart|Stop|Find|Measure|Use)-'
    } | Select-Object -ExpandProperty Name | Sort-Object

    Write-Host "`nAvailable Functions ($($functions.Count)):" -ForegroundColor Yellow
    $functions | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    # Aliases
    $aliases = Get-Alias | Where-Object { $_.Source -eq '' } | Select-Object Name, Definition | Sort-Object Name
    Write-Host "`nAliases ($($aliases.Count)):" -ForegroundColor Yellow
    $aliases | ForEach-Object { Write-Host "  $($_.Name) -> $($_.Definition)" -ForegroundColor DarkGray }

    # Loaded modules
    $modules = Get-Module | Select-Object -ExpandProperty Name | Sort-Object
    Write-Host "`nLoaded Modules ($($modules.Count)):" -ForegroundColor Yellow
    $modules | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    Write-Host ""
}

# Profile load completion
$Global:ProfileLoadEnd = Get-Date
$Global:ProfileLoadDuration = $Global:ProfileLoadEnd - $Global:ProfileLoadStart
$Global:ProfileLoadedTimestamp = $Global:ProfileLoadEnd

# Log completion
Write-ProfileLog "Profile loaded in $($Global:ProfileLoadDuration.TotalMilliseconds)ms" -Level INFO -Component "Bootstrap"

# FIX: Restore ProgressPreference after profile load
if ($null -ne $script:OriginalProgressPreference) {
    $ProgressPreference = $script:OriginalProgressPreference
}

# Rotate logs periodically
Invoke-ProfileLogRotation | Out-Null

# Show welcome screen for interactive sessions
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.WelcomeScreen.Show) {
    Show-WelcomeScreen -Style $Global:ProfileConfig.WelcomeScreen.Style
}

#endregion WELCOME SCREEN AND FINALIZATION
