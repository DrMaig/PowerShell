<#
.SYNOPSIS
    Profile component 13 - Process And Service Management
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 13 (PROCESS AND SERVICE MANAGEMENT) for modular dot-sourced loading.
#>

#region 13 - PROCESS AND SERVICE MANAGEMENT
#==============================================================================
<#
.SYNOPSIS
    Process and service management functions
.DESCRIPTION
    Provides functions for managing processes, services, and scheduled tasks.
#>

function Get-ServiceHealth {
    <#
    .SYNOPSIS
        Gets service health status.
    .DESCRIPTION
        Returns service status with optional filtering.
        Windows-only (uses Get-Service).
    .PARAMETER Filter
        Filter by status (Running, Stopped, All).
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Running', 'Stopped', 'All')]
        [string]$Filter = 'Running'
    )

    if (-not $IsWindows) {
        Write-Warning 'Get-ServiceHealth requires Windows (Get-Service).'
        return @()
    }

    try {
        $services = Get-Service -ErrorAction SilentlyContinue
        if ($Filter -ne 'All') {
            $services = $services | Where-Object Status -eq $Filter
        }
        return $services | Select-Object Name, DisplayName, Status, StartType
    } catch {
        Write-ProfileLog "Get-ServiceHealth failed: $_" -Level DEBUG -Component "Services"
        return @()
    }
}

function Restart-ServiceByName {
    <#
    .SYNOPSIS
        Restarts a service by name.
    .DESCRIPTION
        Safely restarts a Windows service.
    .PARAMETER Name
        Service name.
    .PARAMETER Force
        Force restart without confirmation.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )

    if (-not $Global:IsWindows) {
        Write-ProfileLog "Restart-ServiceByName is Windows-only" -Level WARN -Component "Services"
        return $false
    }

    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        if ($null -ne $svc -and $PSCmdlet.ShouldProcess($Name, 'Restart service')) {
            Restart-Service -Name $Name -Force:$Force -ErrorAction Stop
            Write-ProfileLog "Service '$Name' restarted" -Level INFO -Component "Services"
            return $true
        }
        return $false
    } catch {
        Write-ProfileLog "Restart-ServiceByName failed: $_" -Level WARN -Component "Services"
        return $false
    }
}

function Get-ScheduledTasksSummary {
    <#
    .SYNOPSIS
        Gets a summary of scheduled tasks.
    .DESCRIPTION
        Returns scheduled tasks with status information.
    .PARAMETER Filter
        Optional name filter.
    #>
    [CmdletBinding()]
    param([string]$Filter)

    if (-not $Global:IsWindows) { return @() }

    try {
        if (-not (Get-Command Get-ScheduledTask -ErrorAction Ignore)) { return @() }

        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        if ($Filter) { $tasks = $tasks | Where-Object TaskName -like "*$Filter*" }

        return $tasks | Select-Object TaskName, TaskPath, State, Author | Sort-Object TaskName
    } catch {
        Write-ProfileLog "Get-ScheduledTasksSummary failed: $_" -Level DEBUG -Component "Tasks"
        return @()
    }
}

function Get-ProcessTree {
    <#
    .SYNOPSIS
        Gets process tree structure.
    .DESCRIPTION
        Returns processes in a tree structure showing parent-child relationships.
        Windows-only for full parent-child resolution (uses Win32_Process CIM).
    .PARAMETER Name
        Process name to filter.
    #>
    [CmdletBinding()]
    param([string]$Name)

    if (-not $IsWindows) {
        Write-Warning 'Get-ProcessTree requires Windows (Win32_Process CIM class).'
        return @()
    }

    try {
        $procs = Get-Process -ErrorAction SilentlyContinue
        if ($Name) { $procs = $procs | Where-Object ProcessName -like "*$Name*" }

        # Bulk CIM query for all processes — avoids O(n) individual CIM calls
        $cimProcs = Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name -ErrorAction SilentlyContinue
        $parentMap = @{}
        foreach ($cp in $cimProcs) { $parentMap[$cp.ProcessId] = $cp.ParentProcessId }

        $tree = @()
        foreach ($p in $procs) {
            $tree += [PSCustomObject]@{
                Id       = $p.Id
                Name     = $p.ProcessName
                ParentId = $parentMap[$p.Id]
                Path     = $p.Path
            }
        }
        return $tree
    } catch {
        Write-ProfileLog "Get-ProcessTree failed: $_" -Level DEBUG -Component "Process"
        return @()
    }
}

function Stop-ProcessByName {
    <#
    .SYNOPSIS
        Stops processes by name.
    .DESCRIPTION
        Safely terminates processes matching the name.
    .PARAMETER Name
        Process name pattern.
    .PARAMETER Force
        Force termination.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )

    try {
        $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
        if (-not $procs) {
            Write-Host "No processes found matching: $Name" -ForegroundColor Yellow
            return $false
        }

        foreach ($p in $procs) {
            if ($PSCmdlet.ShouldProcess("$($p.ProcessName) (PID: $($p.Id))", 'Stop process')) {
                Stop-Process -Id $p.Id -Force:$Force -ErrorAction SilentlyContinue
                Write-ProfileLog "Process '$($p.ProcessName)' stopped" -Level INFO -Component "Process"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Stop-ProcessByName failed: $_" -Level WARN -Component "Process"
        return $false
    }
}

#endregion PROCESS AND SERVICE MANAGEMENT
