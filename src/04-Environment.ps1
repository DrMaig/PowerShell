<#
.SYNOPSIS
    Profile component 04 - Environment Validation And Utility Functions
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 4 (ENVIRONMENT VALIDATION AND UTILITY FUNCTIONS) for modular dot-sourced loading.
#>

#region 4 - ENVIRONMENT VALIDATION AND UTILITY FUNCTIONS
#==============================================================================
<#
.SYNOPSIS
    Environment validation and core utility functions
.DESCRIPTION
    Provides functions for testing admin privileges, interactive mode,
    and comprehensive environment validation.
#>

function Test-Admin {
    <#
    .SYNOPSIS
        Tests if the current session has administrator privileges.
    .DESCRIPTION
        Returns $true if running as Administrator (Windows) or root (Unix).
    .EXAMPLE
        if (Test-Admin) { Write-Host "Running as admin" }
    #>
    [CmdletBinding()]
    param()

    try {
        if ($Global:IsWindows) {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } else {
            return ($null -ne $env:SUDO_UID) -or ($env:USERNAME -eq 'root')
        }
    } catch {
        return $false
    }
}

function Test-ProfileInteractive {
    <#
    .SYNOPSIS
        Tests if the current host is interactive.
    .DESCRIPTION
        Returns $true if the host supports interactive features.
    #>
    [CmdletBinding()]
    param()

    try {
        return ($Host -and $Host.UI -and $Host.UI.RawUI)
    } catch {
        return $false
    }
}

function Test-Environment {
    <#
    .SYNOPSIS
        Performs comprehensive environment validation.
    .DESCRIPTION
        Tests platform, admin status, network connectivity, and available commands.
    .PARAMETER SkipNetworkCheck
        Skip network connectivity test.
    #>
    [CmdletBinding()]
    param([switch]$SkipNetworkCheck)

    # Platform detection
    $Global:ProfileState.IsWindows = $Global:IsWindows
    $Global:ProfileState.IsLinux = $Global:IsLinux
    $Global:ProfileState.IsMacOS = $Global:IsMacOS
    $Global:ProfileState.PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    # Admin check
    try {
        $Global:ProfileState.IsAdmin = Test-Admin
    } catch {
        $Global:ProfileState.IsAdmin = $false
        $Global:ProfileState.Notes += "Admin check failed"
    }

    # Command availability check
    $commandsToCheck = @('git', 'winget', 'choco', 'scoop', 'oh-my-posh', 'code', 'python', 'node', 'npm')
    $missing = @()
    foreach ($c in $commandsToCheck) {
        if (-not (Get-Command $c -ErrorAction Ignore)) {
            $missing += $c
        }
    }
    $Global:ProfileState.MissingCommands = $missing

    # Network check
    if ($SkipNetworkCheck) {
        $Global:ProfileState.HasNetwork = $null
    } else {
        try {
            $networkProbeTarget = if ($Global:ProfileConfig.UtilityDefaults.NetworkProbeHost) {
                $Global:ProfileConfig.UtilityDefaults.NetworkProbeHost
            } else {
                '8.8.8.8'
            }

            if ($Global:IsWindows) {
                $test = Test-Connection -ComputerName $networkProbeTarget -Count 1 -Quiet -TimeoutSeconds 2
                $Global:ProfileState.HasNetwork = $test
            } else {
                $sock = $null
                $async = $null
                try {
                    $sock = [System.Net.Sockets.TcpClient]::new()
                    $async = $sock.BeginConnect($networkProbeTarget, 53, $null, $null)
                    $ok = $async.AsyncWaitHandle.WaitOne(3000)
                    if ($ok) {
                        $sock.EndConnect($async)
                        $Global:ProfileState.HasNetwork = $true
                    } else {
                        $Global:ProfileState.HasNetwork = $false
                    }
                } finally {
                    if ($async -and $async.AsyncWaitHandle) {
                        try { $async.AsyncWaitHandle.Dispose() } catch { Write-ProfileLog "AsyncWaitHandle cleanup failed: $($_.Exception.Message)" -Level DEBUG -Component "Environment" }
                    }
                    if ($sock) {
                        try { $sock.Dispose() } catch { Write-ProfileLog "Socket cleanup failed: $($_.Exception.Message)" -Level DEBUG -Component "Environment" }
                    }
                }
            }
        } catch {
            $Global:ProfileState.HasNetwork = $false
            $Global:ProfileState.Notes += "Network probe failed: $($_.Exception.Message)"
            Write-CaughtException -Context "Test-Environment network probe" -ErrorRecord $_ -Component "Environment" -Level DEBUG
        }
    }

    $Global:ProfileState.LastChecked = (Get-Date).ToString('o')
    return $Global:ProfileState
}

function Show-EnvironmentReport {
    <#
    .SYNOPSIS
        Displays a comprehensive environment report.
    .DESCRIPTION
        Shows platform, version, admin status, network, and missing commands.
    .PARAMETER VerboseReport
        Include additional notes and details.
    #>
    [CmdletBinding()]
    param([switch]$VerboseReport)

    if (-not $Global:ProfileState.LastChecked) {
        Test-Environment | Out-Null
    }

    Write-Host "`n=== Environment Report ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: " -NoNewline
    Write-Host $Global:ProfileState.PowerShellVersion -ForegroundColor Yellow

    Write-Host "Platform: " -NoNewline
    $plat = if ($Global:ProfileState.IsWindows) { 'Windows' }
            elseif ($Global:ProfileState.IsLinux) { 'Linux' }
            elseif ($Global:ProfileState.IsMacOS) { 'macOS' }
            else { 'Unknown' }
    Write-Host $plat -ForegroundColor Yellow

    Write-Host "Is Admin: " -NoNewline
    Write-Host $Global:ProfileState.IsAdmin -ForegroundColor $(if ($Global:ProfileState.IsAdmin) { 'Green' } else { 'Yellow' })

    $netStatus = if ($null -eq $Global:ProfileState.HasNetwork) { 'Skipped' } else { $Global:ProfileState.HasNetwork }
    Write-Host "Has Network: " -NoNewline
    Write-Host $netStatus -ForegroundColor $(if ($netStatus -eq $true) { 'Green' } elseif ($netStatus -eq $false) { 'Red' } else { 'Gray' })

    if ($Global:ProfileState.MissingCommands.Count -gt 0) {
        Write-Host "`nMissing Commands:" -ForegroundColor Yellow
        Write-Host ($Global:ProfileState.MissingCommands -join ', ') -ForegroundColor DarkYellow
    }

    if ($VerboseReport -and $Global:ProfileState.Notes.Count -gt 0) {
        Write-Host "`nNotes:" -ForegroundColor Gray
        foreach ($n in $Global:ProfileState.Notes) {
            Write-Host "  - $n" -ForegroundColor DarkGray
        }
    }

    Write-Host "`nLast Checked: $($Global:ProfileState.LastChecked)" -ForegroundColor DarkGray
    Write-Host ""
}

# Initialize environment on load
try {
    Test-Environment -SkipNetworkCheck | Out-Null
    Write-ProfileLog "Environment validated successfully" -Level DEBUG -Component "Environment"
} catch {
    Write-ProfileLog "Environment validation error: $_" -Level WARN -Component "Environment"
}

#endregion ENVIRONMENT VALIDATION AND UTILITY FUNCTIONS
