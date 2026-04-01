<#
.SYNOPSIS
    Profile component 26 - Event And Log Helpers
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 26 (EVENT AND LOG HELPERS) for modular dot-sourced loading.
#>

#region 26 - EVENT AND LOG HELPERS
#==============================================================================
<#
.SYNOPSIS
    Windows Event Log query helpers with filters, paging, and export.
.DESCRIPTION
    Provides safe, read-only wrappers around Get-WinEvent with structured output.
.EXAMPLE
    Get-RecentEvents -LogName System -Level Error -MaxEvents 20
    Export-EventLogToJson -LogName Application -Hours 24 -OutputPath .\events.json
#>

function Get-RecentEvents {
    <#
    .SYNOPSIS
        Retrieves recent Windows Event Log entries with filtering.
    .PARAMETER LogName
        Event log name (System, Application, Security, etc.).
    .PARAMETER Level
        Filter by level: Critical, Error, Warning, Information.
    .PARAMETER MaxEvents
        Maximum events to return (default: 50).
    .PARAMETER Hours
        Look back this many hours (default: 24).
    .PARAMETER Source
        Filter by event source/provider.
    .EXAMPLE
        Get-RecentEvents -LogName System -Level Error -MaxEvents 20
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateSet('System','Application','Security','Setup','ForwardedEvents')]
        [string]$LogName = 'System',
        [ValidateSet('Critical','Error','Warning','Information','All')]
        [string]$Level = 'All',
        [ValidateRange(1, 5000)][int]$MaxEvents = 50,
        [ValidateRange(1, 8760)][int]$Hours = 24,
        [string]$Source
    )

    if (-not $Global:IsWindows) {
        Write-ProfileLog "Get-RecentEvents is Windows-only" -Level WARN -Component "EventLog"
        return @()
    }

    try {
        $levelMap = @{ Critical = 1; Error = 2; Warning = 3; Information = 4 }
        $startTime = (Get-Date).AddHours(-$Hours)

        $filter = @{ LogName = $LogName; StartTime = $startTime }
        if ($Level -ne 'All') { $filter.Level = $levelMap[$Level] }
        if ($Source) { $filter.ProviderName = $Source }

        Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName,
                @{N='Message';E={$_.Message -replace '\r?\n',' ' | ForEach-Object { if ($_.Length -gt 200) { $_.Substring(0,200) + '...' } else { $_ } }}}
    } catch {
        Write-CaughtException -Context "Get-RecentEvents $LogName" -ErrorRecord $_ -Component "EventLog" -Level WARN
        return @()
    }
}

function Export-EventLogToJson {
    <#
    .SYNOPSIS
        Exports event log entries to a JSON file.
    .PARAMETER LogName
        Event log name.
    .PARAMETER Hours
        Look back this many hours.
    .PARAMETER MaxEvents
        Maximum events.
    .PARAMETER OutputPath
        Output JSON file path.
    .EXAMPLE
        Export-EventLogToJson -LogName Application -Hours 24 -OutputPath .\events.json
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('System','Application','Security')]
        [string]$LogName = 'System',
        [ValidateRange(1, 8760)][int]$Hours = 24,
        [ValidateRange(1, 10000)][int]$MaxEvents = 500,
        [Parameter(Mandatory)][string]$OutputPath
    )

    if ($PSCmdlet.ShouldProcess($OutputPath, "Export $LogName events")) {
        try {
            $events = Get-RecentEvents -LogName $LogName -Hours $Hours -MaxEvents $MaxEvents
            $events | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8 -Force
            Write-ProfileLog "Exported $($events.Count) events to $OutputPath" -Level INFO -Component "EventLog"
            return $true
        } catch {
            Write-CaughtException -Context "Export-EventLogToJson" -ErrorRecord $_ -Component "EventLog" -Level WARN
            return $false
        }
    }
}

function Get-EventLogSummary {
    <#
    .SYNOPSIS
        Returns a summary of recent event log activity.
    .PARAMETER Hours
        Look back this many hours (default: 24).
    .EXAMPLE
        Get-EventLogSummary -Hours 48 | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param([ValidateRange(1, 8760)][int]$Hours = 24)

    if (-not $Global:IsWindows) { return @() }

    $logs = @('System', 'Application', 'Security')
    $results = @()
    foreach ($log in $logs) {
        try {
            $startTime = (Get-Date).AddHours(-$Hours)
            $events = Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $startTime } -ErrorAction SilentlyContinue
            $grouped = $events | Group-Object LevelDisplayName
            $results += [PSCustomObject]@{
                LogName   = $log
                Total     = $events.Count
                Critical  = ($grouped | Where-Object Name -eq 'Critical').Count
                Error     = ($grouped | Where-Object Name -eq 'Error').Count
                Warning   = ($grouped | Where-Object Name -eq 'Warning').Count
                Info      = ($grouped | Where-Object Name -eq 'Information').Count
                Hours     = $Hours
            }
        } catch {
            $results += [PSCustomObject]@{
                LogName = $log; Total = 0; Critical = 0; Error = 0; Warning = 0; Info = 0; Hours = $Hours
            }
        }
    }
    return $results
}

#endregion ADDED: EVENT AND LOG HELPERS
