<#
.SYNOPSIS
    Profile component 29 - Interactive Productivity Helpers
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 29 (INTERACTIVE PRODUCTIVITY HELPERS) for modular dot-sourced loading.
#>

#region 29 - INTERACTIVE PRODUCTIVITY HELPERS
#==============================================================================
<#
.SYNOPSIS
    Command palette, context-based suggestions, fuzzy alias search.
.DESCRIPTION
    Provides interactive helpers for discoverability and productivity.
.EXAMPLE
    Show-CommandPalette
    Find-ProfileCommand 'dns'
#>

function Show-CommandPalette {
    <#
    .SYNOPSIS
        Lists all profile commands grouped by category.
    .PARAMETER Category
        Filter by category (System, Network, Package, Diagnostic, etc.).
    .EXAMPLE
        Show-CommandPalette -Category Network
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('All','System','Network','Package','Diagnostic','Process','Disk','Security','Monitor')]
        [string]$Category = 'All'
    )

    $commands = @{
        System     = @('Get-SystemInfo','Get-CPUInfo','Get-MemoryInfo','Get-GPUInfo','Get-BIOSInfo','Get-Uptime','Get-SystemHealth','Get-HardwareSummary','Get-SmartDiskHealth','Get-BatteryHealth')
        Network    = @('Get-LocalIP','Get-PublicIP','Get-NetworkAdapters','Get-DnsConfig','Get-NetworkSnapshot','Test-Internet','Test-TcpPort','Test-DnsResolution','Invoke-Traceroute','Get-ArpTable','Invoke-PortScan','Get-NicStatistics','Get-LinkSpeed','Set-DnsProfile','Use-BestDns','Clear-DnsCache')
        Package    = @('Get-PackageManagerStatus','Install-DevPackage','Update-AllPackages','Get-WingetPackage','Get-ChocoPackage','Get-NpmPackage','Get-PipPackage','Get-DotnetInfo')
        Diagnostic = @('Show-ProfileDiagnostics','Test-ProfileHealth','Repair-Profile','Show-EnvironmentReport','Collect-SystemSnapshot','Test-ProfileScript','Invoke-ProfileLint','Invoke-ProfilePesterTests')
        Process    = @('Get-TopProcesses','Get-ProcessTree','Stop-ProcessByName','Get-ServiceHealth','Restart-ServiceByName','Get-ScheduledTasksSummary')
        Disk       = @('Get-DiskInfo','Get-DiskUsage','Find-LargeFiles','Clear-TempFiles','Invoke-DiskMaintenance')
        Security   = @('Test-Admin','Test-RemoteHost','Connect-RemoteHost','Invoke-RemoteCommand','Get-RemoteSessions','Remove-AllRemoteSessions')
        Monitor    = @('Get-PerfSnapshot','Measure-Benchmark','Test-ThresholdAlerts','Write-MonitorEvent','Get-MonitorLog','Get-RecentEvents','Get-EventLogSummary')
    }

    $categories = if ($Category -eq 'All') { $commands.Keys | Sort-Object } else { @($Category) }

    Write-Host "`n=== Profile Command Palette ===" -ForegroundColor Cyan
    foreach ($cat in $categories) {
        if (-not $commands.ContainsKey($cat)) { continue }
        Write-Host "`n  $cat" -ForegroundColor Yellow
        foreach ($cmd in $commands[$cat]) {
            $exists = $null -ne (Get-Command $cmd -ErrorAction Ignore)
            $indicator = if ($exists) { '[+]' } else { '[-]' }
            $color = if ($exists) { 'Green' } else { 'DarkGray' }
            Write-Host "    $indicator $cmd" -ForegroundColor $color
        }
    }
    Write-Host ""
}

function Find-ProfileCommand {
    <#
    .SYNOPSIS
        Fuzzy-searches profile functions and aliases by keyword.
    .PARAMETER Keyword
        Search term (matched against name and synopsis).
    .EXAMPLE
        Find-ProfileCommand 'dns'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param([Parameter(Mandatory)][string]$Keyword)

    try {
        $functions = Get-Command -CommandType Function -ErrorAction Ignore |
            Where-Object { $_.Source -eq '' -and ($_.Name -like "*$Keyword*") } |
            Select-Object Name, @{N='Type';E={'Function'}},
                @{N='Synopsis';E={try{(Get-Help $_.Name -ErrorAction SilentlyContinue).Synopsis}catch{''}}}

        $aliases = Get-Alias -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -eq '' -and ($_.Name -like "*$Keyword*" -or $_.Definition -like "*$Keyword*") } |
            Select-Object @{N='Name';E={$_.Name}}, @{N='Type';E={'Alias'}},
                @{N='Synopsis';E={"-> $($_.Definition)"}}

        $all = @($functions) + @($aliases) | Where-Object { $_ } | Sort-Object Name
        if ($all.Count -eq 0) {
            Write-Host "No commands found matching '$Keyword'" -ForegroundColor DarkGray
        }
        return $all
    } catch {
        Write-CaughtException -Context "Find-ProfileCommand" -ErrorRecord $_ -Component "Productivity" -Level DEBUG
        return @()
    }
}

function Get-ContextSuggestions {
    <#
    .SYNOPSIS
        Suggests commands based on current context (admin, network, directory).
    .EXAMPLE
        Get-ContextSuggestions
    #>
    [CmdletBinding()]
    param()

    $suggestions = @()
    if (Test-Admin) {
        $suggestions += 'You are admin - DNS/service/optimization commands available.'
    } else {
        $suggestions += 'Run "sudo" to open an elevated session for admin tasks.'
    }
    if ($Global:ProfileState.HasNetwork -eq $true) {
        $suggestions += 'Network is up - try: pubip, Test-DnsResolution, Invoke-Traceroute'
    } elseif ($Global:ProfileState.HasNetwork -eq $false) {
        $suggestions += 'Network appears down - try: Get-NetworkAdapters, Get-ArpTable'
    }
    if ((Get-Location).Path -match '\\\.git' -or (Test-Path '.git')) {
        $suggestions += 'Git repo detected - try: git status, git log --oneline'
    }
    $suggestions += 'Type "helpme" for full command reference, "Show-CommandPalette" for categories.'
    Write-Host "`n=== Context Suggestions ===" -ForegroundColor Cyan
    foreach ($s in $suggestions) { Write-Host "  - $s" -ForegroundColor DarkGray }
    Write-Host ""
}

#endregion ADDED: INTERACTIVE PRODUCTIVITY HELPERS
