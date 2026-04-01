<#
.SYNOPSIS
    Profile component 07 - System Administration Functions
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 7 (SYSTEM ADMINISTRATION FUNCTIONS) for modular dot-sourced loading.
#>

#region 7 - SYSTEM ADMINISTRATION FUNCTIONS
#==============================================================================
<#
.SYNOPSIS
    System administration and hardware information functions
.DESCRIPTION
    Provides comprehensive functions for system information, hardware inventory,
    BIOS details, and system health monitoring.
#>

function Get-SystemInfo {
    <#
    .SYNOPSIS
        Retrieves comprehensive system information.
    .DESCRIPTION
        Returns detailed information about the operating system, hardware,
        and system configuration. Windows-only (uses Win32_* CIM classes).
    .EXAMPLE
        Get-SystemInfo | Format-List
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-SystemInfo requires Windows (Win32_* CIM classes).'
        return $null
    }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            ComputerName     = $cs.Name
            Manufacturer     = $cs.Manufacturer
            Model            = $cs.Model
            SystemType       = $cs.SystemType
            BIOSVersion      = $bios.SMBIOSBIOSVersion
            BIOSSerial       = $bios.SerialNumber
            OSName           = $os.Caption
            OSVersion        = $os.Version
            OSBuild          = $os.BuildNumber
            OSArchitecture   = $os.OSArchitecture
            InstallDate      = $os.InstallDate
            LastBootTime     = $os.LastBootUpTime
            Uptime           = (Get-Date) - $os.LastBootUpTime
            Processor        = $cpu.Name
            ProcessorCores   = $cpu.NumberOfCores
            ProcessorLogical = $cpu.NumberOfLogicalProcessors
            TotalMemoryGB    = [math]::Round(($memory | Measure-Object Capacity -Sum).Sum / 1GB, 2)
            Domain           = $cs.Domain
            DomainRole       = switch ($cs.DomainRole) {
                0 { "Standalone Workstation" }
                1 { "Member Workstation" }
                2 { "Standalone Server" }
                3 { "Member Server" }
                4 { "Backup Domain Controller" }
                5 { "Primary Domain Controller" }
                default { "Unknown" }
            }
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            IsElevated       = Test-Admin
        }
    } catch {
        Write-ProfileLog "Get-SystemInfo failed: $_" -Level WARN -Component "System"
        return $null
    }
}

function Get-DiskInfo {
    <#
    .SYNOPSIS
        Retrieves disk information.
    .DESCRIPTION
        Returns information about logical disks including size, free space,
        and usage percentages. Windows-only (uses Win32_LogicalDisk).
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-DiskInfo requires Windows (Win32_LogicalDisk CIM class).'
        return @()
    }

    try {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
            Select-Object @{
                N = 'Drive'; E = { $_.DeviceID }
            }, @{
                N = 'Label'; E = { $_.VolumeName }
            }, @{
                N = 'SizeGB'; E = { [math]::Round($_.Size / 1GB, 2) }
            }, @{
                N = 'FreeGB'; E = { [math]::Round($_.FreeSpace / 1GB, 2) }
            }, @{
                N = 'UsedGB'; E = { [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2) }
            }, @{
                N = 'PercentFree'; E = { if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 } }
            }
    } catch {
        Write-ProfileLog "Get-DiskInfo failed: $_" -Level WARN -Component "System"
        return @()
    }
}

function Get-MemoryInfo {
    <#
    .SYNOPSIS
        Retrieves memory information.
    .DESCRIPTION
        Returns detailed memory information including total, free, and used memory.
        Windows-only (uses Win32_OperatingSystem and Win32_PhysicalMemory).
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-MemoryInfo requires Windows (Win32_* CIM classes).'
        return $null
    }

    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue

        $totalGB = [math]::Round(($memory | Measure-Object Capacity -Sum).Sum / 1GB, 2)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

        [PSCustomObject]@{
            TotalMemoryGB = $totalGB
            FreeMemoryGB  = $freeGB
            UsedMemoryGB  = [math]::Round($totalGB - $freeGB, 2)
            PercentUsed   = if ($totalGB -gt 0) { [math]::Round((($totalGB - $freeGB) / $totalGB) * 100, 2) } else { 0 }
            MemoryModules = $memory.Count
            Speed         = ($memory | Select-Object -First 1).Speed
            FormFactor    = switch (($memory | Select-Object -First 1).FormFactor) {
                8  { "DIMM" }
                12 { "SO-DIMM" }
                default { "Unknown" }
            }
        }
    } catch {
        Write-ProfileLog "Get-MemoryInfo failed: $_" -Level WARN -Component "System"
        return $null
    }
}

function Get-CPUInfo {
    <#
    .SYNOPSIS
        Retrieves CPU information.
    .DESCRIPTION
        Returns detailed CPU information including architecture, cores, and speed.
        Windows-only (uses Win32_Processor).
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-CPUInfo requires Windows (Win32_Processor CIM class).'
        return $null
    }

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name                  = $cpu.Name
            Manufacturer          = $cpu.Manufacturer
            Architecture          = switch ($cpu.Architecture) {
                0 { "x86" }
                1 { "MIPS" }
                2 { "Alpha" }
                3 { "PowerPC" }
                5 { "ARM" }
                6 { "Itanium" }
                9 { "x64" }
                default { "Unknown" }
            }
            Cores                 = $cpu.NumberOfCores
            LogicalProcessors     = $cpu.NumberOfLogicalProcessors
            MaxClockSpeedMHz      = $cpu.MaxClockSpeed
            CurrentClockSpeedMHz  = $cpu.CurrentClockSpeed
            L2CacheSizeKB         = $cpu.L2CacheSize
            L3CacheSizeKB         = $cpu.L3CacheSize
            VirtualizationEnabled = $cpu.VirtualizationFirmwareEnabled
        }
    } catch {
        Write-ProfileLog "Get-CPUInfo failed: $_" -Level WARN -Component "System"
        return $null
    }
}

function Get-GPUInfo {
    <#
    .SYNOPSIS
        Retrieves GPU information.
    .DESCRIPTION
        Returns information about video controllers/GPUs.
        Windows-only (uses Win32_VideoController).
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-GPUInfo requires Windows (Win32_VideoController CIM class).'
        return @()
    }

    try {
        Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
            Select-Object Name,
                @{N = 'AdapterRAM_GB'; E = { if ($_.AdapterRAM) { [math]::Round($_.AdapterRAM / 1GB, 2) } else { 0 } }},
                DriverVersion,
                VideoModeDescription,
                Status
    } catch {
        Write-ProfileLog "Get-GPUInfo failed: $_" -Level WARN -Component "System"
        return @()
    }
}

function Get-BIOSInfo {
    <#
    .SYNOPSIS
        Retrieves BIOS information.
    .DESCRIPTION
        Returns detailed BIOS information including version and settings.
        Windows-only (uses Win32_BIOS and Win32_ComputerSystem).
    #>
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        Write-Warning 'Get-BIOSInfo requires Windows (Win32_BIOS CIM class).'
        return $null
    }

    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Manufacturer    = $bios.Manufacturer
            Name            = $bios.Name
            Version         = $bios.SMBIOSBIOSVersion
            SerialNumber    = $bios.SerialNumber
            ReleaseDate     = $bios.ReleaseDate
            BIOSVersion     = $bios.Version
            SystemSKU       = $system.SystemSKUNumber
            BootupState     = $system.BootupState
        }
    } catch {
        Write-ProfileLog "Get-BIOSInfo failed: $_" -Level WARN -Component "System"
        return $null
    }
}

function Get-SystemHealth {
    <#
    .SYNOPSIS
        Retrieves system health status.
    .DESCRIPTION
        Returns health information for disk, memory, and CPU.
        Windows-only (delegates to Win32_* CIM-based functions and Get-Counter).
    .PARAMETER Quick
        Return quick summary only.
    #>
    [CmdletBinding()]
    param([switch]$Quick)

    if (-not $IsWindows) {
        Write-Warning 'Get-SystemHealth requires Windows.'
        return $null
    }

    try {
        $cpuInfo = Get-CPUInfo
        $health = [ordered]@{
            Timestamp = Get-Date
            Disk      = Get-DiskInfo
            Memory    = Get-MemoryInfo
            CPU       = if ($cpuInfo) { $cpuInfo | Select-Object Name, Cores, LogicalProcessors, CurrentClockSpeedMHz } else { $null }
        }

        if (-not $Quick) {
            # Add performance counters
            try {
                $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                $health.CPUPercent = [math]::Round($cpuCounter.CounterSamples.CookedValue, 2)
            } catch {
                $health.CPUPercent = $null
                Write-CaughtException -Context "Get-SystemHealth counter sampling" -ErrorRecord $_ -Component "System" -Level DEBUG
            }
        }

        return [PSCustomObject]$health
    } catch {
        Write-CaughtException -Context "Get-SystemHealth failed" -ErrorRecord $_ -Component "System" -Level WARN
        return $null
    }
}

function Get-Uptime {
    <#
    .SYNOPSIS
        Retrieves system uptime.
    .DESCRIPTION
        Returns the time since last system boot.
    #>
    [CmdletBinding()]
    param()

    try {
        if ($Global:IsWindows) {
            $boot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
            return (Get-Date) - $boot
        } else {
            $proc = Get-Process -Id 1 -ErrorAction SilentlyContinue
            if ($proc) { return (Get-Date) - $proc.StartTime }
            return $null
        }
    } catch {
        Write-ProfileLog "Get-Uptime failed: $_" -Level DEBUG
        return $null
    }
}

#endregion SYSTEM ADMINISTRATION FUNCTIONS
