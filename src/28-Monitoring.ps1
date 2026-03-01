<#
.SYNOPSIS
    Profile component 28 - Monitoring And Alerting Hooks
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 28 (MONITORING AND ALERTING HOOKS) for modular dot-sourced loading.
#>

#region 28 - MONITORING AND ALERTING HOOKS
#==============================================================================
<#
.SYNOPSIS
    Local structured logging (JSON) and threshold-based alerting.
.DESCRIPTION
    Writes structured JSON events to a local log sink and raises console/toast
    alerts when configurable thresholds are exceeded. No external telemetry.
.EXAMPLE
    Write-MonitorEvent -EventName 'DiskLow' -Severity Warning -Data @{Drive='C';FreeGB=5}
    Test-ThresholdAlerts
#>

# Alert thresholds (configurable)
if (-not $Global:ProfileConfig.Contains('AlertThresholds')) {
    $Global:ProfileConfig.AlertThresholds = @{
        DiskFreePercentMin = 10
        MemoryUsedPercentMax = 90
        CPUPercentMax = 95
    }
}

function Write-MonitorEvent {
    <#
    .SYNOPSIS
        Writes a structured JSON event to the monitor log.
    .PARAMETER EventName
        Short event identifier.
    .PARAMETER Severity
        Info, Warning, Error, Critical.
    .PARAMETER Data
        Hashtable of event data.
    .EXAMPLE
        Write-MonitorEvent -EventName 'HighCPU' -Severity Warning -Data @{Percent=98}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EventName,
        [ValidateSet('Info','Warning','Error','Critical')][string]$Severity = 'Info',
        [hashtable]$Data = @{}
    )

    try {
        $logDir = Join-Path $Global:ProfileConfig.LogPath 'monitor'
        if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

        $monitorEntry = [ordered]@{
            Timestamp = (Get-Date).ToString('o')
            EventName = $EventName
            Severity  = $Severity
            Computer  = $env:COMPUTERNAME
            User      = $env:USERNAME
            Data      = $Data
        }

        $logFile = Join-Path $logDir ("monitor_$(Get-Date -Format 'yyyyMMdd').jsonl")
        ($monitorEntry | ConvertTo-Json -Compress) | Add-Content -Path $logFile -Encoding UTF8

        # Console alert for Warning+
        if ($Severity -in @('Warning','Error','Critical')) {
            $color = switch ($Severity) { 'Warning' {'Yellow'}; 'Error' {'Red'}; 'Critical' {'Magenta'} }
            Write-Host "[ALERT] $EventName ($Severity): $($Data | ConvertTo-Json -Compress)" -ForegroundColor $color
        }
    } catch {
        Write-ProfileLog "Write-MonitorEvent failed: $($_.Exception.Message)" -Level DEBUG -Component "Monitor"
    }
}

function Test-ThresholdAlerts {
    <#
    .SYNOPSIS
        Checks system metrics against configured thresholds and raises alerts.
    .EXAMPLE
        Test-ThresholdAlerts
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $alerts = @()
    $thresholds = $Global:ProfileConfig.AlertThresholds

    try {
        # Disk check
        $disks = Get-DiskInfo
        foreach ($d in $disks) {
            if ($d.PercentFree -lt $thresholds.DiskFreePercentMin) {
                $alerts += [PSCustomObject]@{ Check='DiskFree'; Status='ALERT'; Detail="$($d.Drive) $($d.PercentFree)% free" }
                Write-MonitorEvent -EventName 'DiskLow' -Severity Warning -Data @{ Drive=$d.Drive; FreePercent=$d.PercentFree }
            }
        }

        # Memory check
        $mem = Get-MemoryInfo
        if ($mem -and $mem.PercentUsed -gt $thresholds.MemoryUsedPercentMax) {
            $alerts += [PSCustomObject]@{ Check='MemoryUsed'; Status='ALERT'; Detail="$($mem.PercentUsed)% used" }
            Write-MonitorEvent -EventName 'HighMemory' -Severity Warning -Data @{ PercentUsed=$mem.PercentUsed }
        }

        # CPU check (quick sample)
        try {
            $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
            $cpuPct = [math]::Round($cpuCounter.CounterSamples.CookedValue, 2)
            if ($cpuPct -gt $thresholds.CPUPercentMax) {
                $alerts += [PSCustomObject]@{ Check='CPULoad'; Status='ALERT'; Detail="$cpuPct%" }
                Write-MonitorEvent -EventName 'HighCPU' -Severity Warning -Data @{ Percent=$cpuPct }
            }
        } catch {
            Write-ProfileLog "CPU counter check failed: $($_.Exception.Message)" -Level DEBUG -Component "Monitor"
        }

        if ($alerts.Count -eq 0) {
            Write-Host "All thresholds OK." -ForegroundColor Green
        }
    } catch {
        Write-CaughtException -Context "Test-ThresholdAlerts" -ErrorRecord $_ -Component "Monitor" -Level WARN
    }
    return $alerts
}

function Get-MonitorLog {
    <#
    .SYNOPSIS
        Reads recent monitor events from the structured JSON log.
    .PARAMETER Days
        Number of days to look back (default: 1).
    .PARAMETER Severity
        Filter by severity.
    .EXAMPLE
        Get-MonitorLog -Days 7 -Severity Warning | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateRange(1, 365)][int]$Days = 1,
        [ValidateSet('Info','Warning','Error','Critical','All')]
        [string]$Severity = 'All'
    )

    $logDir = Join-Path $Global:ProfileConfig.LogPath 'monitor'
    if (-not (Test-Path $logDir)) { return @() }

    try {
        $cutoff = (Get-Date).AddDays(-$Days)
        $files = Get-ChildItem -Path $logDir -Filter 'monitor_*.jsonl' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $cutoff }

        $events = @()
        foreach ($f in $files) {
            $lines = Get-Content -Path $f.FullName -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                try {
                    $obj = $line | ConvertFrom-Json
                    if ($Severity -eq 'All' -or $obj.Severity -eq $Severity) {
                        $events += $obj
                    }
                } catch { continue }
            }
        }
        return $events | Sort-Object Timestamp -Descending
    } catch {
        Write-CaughtException -Context "Get-MonitorLog" -ErrorRecord $_ -Component "Monitor" -Level WARN
        return @()
    }
}

#endregion ADDED: MONITORING AND ALERTING HOOKS
