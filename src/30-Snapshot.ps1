<#
.SYNOPSIS
    Profile component 30 - Diagnostics Automation
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 30 (DIAGNOSTICS AUTOMATION) for modular dot-sourced loading.
#>

#region 30 - DIAGNOSTICS AUTOMATION
#==============================================================================
<#
.SYNOPSIS
    Collect-SystemSnapshot gathers a safe, non-sensitive system snapshot.
.DESCRIPTION
    Creates a timestamped folder with system inventory, network config, event summaries,
    and health data. No secrets, passwords, or PII beyond hostname/username are collected.
.EXAMPLE
    Collect-SystemSnapshot -OutputPath "$HOME\Desktop\snapshot"
#>

function Collect-SystemSnapshot {
    <#
    .SYNOPSIS
        Gathers a comprehensive, non-sensitive system snapshot to a timestamped folder.
    .PARAMETER OutputPath
        Base output directory (a timestamped subfolder is created).
    .PARAMETER IncludeEventLogs
        Include recent event log summaries.
    .PARAMETER IncludeNetwork
        Include network diagnostics.
    .EXAMPLE
        Collect-SystemSnapshot
        Collect-SystemSnapshot -OutputPath 'C:\Snapshots' -IncludeEventLogs -IncludeNetwork
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$OutputPath = (Join-Path $Global:ProfileConfig.LogPath 'snapshots'),
        [switch]$IncludeEventLogs,
        [switch]$IncludeNetwork
    )

    if (-not $PSCmdlet.ShouldProcess('System', 'Collect diagnostic snapshot')) { return }

    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $snapDir = Join-Path $OutputPath "snapshot_$ts"

    try {
        New-Item -Path $snapDir -ItemType Directory -Force | Out-Null
        Write-Host "Collecting snapshot to: $snapDir" -ForegroundColor Cyan

        # System info
        try {
            $sysInfo = Get-SystemInfo
            $sysInfo | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'system_info.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: system_info failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Hardware summary
        try {
            $hw = Get-HardwareSummary
            $hw | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'hardware.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: hardware failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Disk health
        try {
            $disk = Get-SmartDiskHealth
            $disk | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'disk_health.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: disk_health failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Memory and CPU
        try {
            Get-MemoryInfo | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'memory.json') -Encoding UTF8
            Get-CPUInfo | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'cpu.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: mem/cpu failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Network (optional)
        if ($IncludeNetwork) {
            try {
                Get-NetworkSnapshot | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'network.json') -Encoding UTF8
                Get-DnsConfig | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'dns.json') -Encoding UTF8
            } catch { Write-ProfileLog "Snapshot: network failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }
        }

        # Event log summary (optional)
        if ($IncludeEventLogs) {
            try {
                Get-EventLogSummary -Hours 24 | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'event_summary.json') -Encoding UTF8
            } catch { Write-ProfileLog "Snapshot: events failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }
        }

        # Profile health
        try {
            Test-ProfileHealth | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $snapDir 'profile_health.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: profile_health failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Installed software list
        try {
            Get-InstalledSoftware | Select-Object Name, Version, Publisher |
                ConvertTo-Json -Depth 2 | Set-Content (Join-Path $snapDir 'installed_software.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: software failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Services
        try {
            Get-Service | Select-Object Name, Status, StartType |
                ConvertTo-Json -Depth 2 | Set-Content (Join-Path $snapDir 'services.json') -Encoding UTF8
        } catch { Write-ProfileLog "Snapshot: services failed: $($_.Exception.Message)" -Level DEBUG -Component "Snapshot" }

        # Manifest
        @{
            Timestamp    = (Get-Date).ToString('o')
            Computer     = $env:COMPUTERNAME
            PSVersion    = $PSVersionTable.PSVersion.ToString()
            ProfileVer   = $script:ProfileVersion
            Files        = (Get-ChildItem $snapDir -File | Select-Object -ExpandProperty Name)
        } | ConvertTo-Json -Depth 2 | Set-Content (Join-Path $snapDir 'manifest.json') -Encoding UTF8

        Write-Host "Snapshot complete: $snapDir" -ForegroundColor Green
        Write-ProfileLog "System snapshot saved to $snapDir" -Level INFO -Component "Snapshot"
        return $snapDir
    } catch {
        Write-CaughtException -Context "Collect-SystemSnapshot" -ErrorRecord $_ -Component "Snapshot" -Level WARN
        return $null
    }
}

#endregion ADDED: DIAGNOSTICS AUTOMATION
