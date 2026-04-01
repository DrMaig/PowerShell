<#
.SYNOPSIS
    Profile component 24 - Hardware Diagnostics
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 24 (HARDWARE DIAGNOSTICS) for modular dot-sourced loading.
#>

#region 24 - HARDWARE DIAGNOSTICS
#==============================================================================
<#
.SYNOPSIS
    Safe CIM/WMI wrappers with timeouts and cross-platform fallbacks
.DESCRIPTION
    Provides throttled, cached, timeout-protected hardware queries.
    All functions are read-only and non-destructive.
.EXAMPLE
    Get-HardwareSummary | Format-List
    Get-SmartDiskHealth | Format-Table -AutoSize
#>

function Invoke-SafeCimQuery {
    <#
    .SYNOPSIS
        Runs a CIM query with timeout, caching, and error handling.
    .PARAMETER ClassName
        WMI/CIM class name.
    .PARAMETER Filter
        Optional WQL filter.
    .PARAMETER Properties
        Properties to select.
    .PARAMETER OperationTimeoutSec
        CIM operation timeout (default: 10).
    .PARAMETER CacheKey
        Optional cache key; results cached for CacheTtlSec seconds.
    .PARAMETER CacheTtlSec
        Cache time-to-live (default: 120).
    .EXAMPLE
        Invoke-SafeCimQuery -ClassName Win32_Processor -Properties Name,NumberOfCores
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][string]$ClassName,
        [string]$Filter,
        [string[]]$Properties,
        [ValidateRange(1, 120)][int]$OperationTimeoutSec = 10,
        [string]$CacheKey,
        [ValidateRange(0, 3600)][int]$CacheTtlSec = 120
    )

    # Simple in-memory cache
    if (-not (Test-Path variable:script:CimQueryCache)) { $script:CimQueryCache = @{} }
    if ($CacheKey -and $script:CimQueryCache.ContainsKey($CacheKey)) {
        $entry = $script:CimQueryCache[$CacheKey]
        if (((Get-Date) - $entry.Timestamp).TotalSeconds -lt $CacheTtlSec) {
            return $entry.Data
        }
    }

    if (-not $Global:IsWindows) {
        Write-ProfileLog "Invoke-SafeCimQuery: CIM queries are Windows-only" -Level DEBUG -Component "HWDiag"
        return @()
    }

    try {
        $cimParams = @{
            ClassName        = $ClassName
            OperationTimeoutSec = $OperationTimeoutSec
            ErrorAction      = 'Stop'
        }
        if ($Filter) { $cimParams.Filter = $Filter }

        $result = Get-CimInstance @cimParams
        if ($Properties) { $result = $result | Select-Object $Properties }

        if ($CacheKey) {
            $script:CimQueryCache[$CacheKey] = @{ Data = $result; Timestamp = Get-Date }
        }
        return $result
    } catch [Microsoft.Management.Infrastructure.CimException] {
        Write-ProfileLog "CIM query '$ClassName' timed out or failed: $($_.Exception.Message)" -Level WARN -Component "HWDiag"
        return @()
    } catch {
        Write-CaughtException -Context "Invoke-SafeCimQuery $ClassName" -ErrorRecord $_ -Component "HWDiag" -Level WARN
        return @()
    }
}

function Get-HardwareSummary {
    <#
    .SYNOPSIS
        Returns a unified hardware inventory snapshot.
    .DESCRIPTION
        Aggregates CPU, memory, disk, GPU, BIOS, and firmware into a single object.
        Results are cached for 2 minutes.
    .EXAMPLE
        Get-HardwareSummary | Format-List
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        $cpu  = Invoke-SafeCimQuery -ClassName Win32_Processor -Properties Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed -CacheKey 'hw_cpu'
        $mem  = Invoke-SafeCimQuery -ClassName Win32_PhysicalMemory -Properties Capacity,Speed,Manufacturer,PartNumber -CacheKey 'hw_mem'
        $disk = Invoke-SafeCimQuery -ClassName Win32_DiskDrive -Properties Model,Size,MediaType,InterfaceType,FirmwareRevision,SerialNumber -CacheKey 'hw_disk'
        $gpu  = Invoke-SafeCimQuery -ClassName Win32_VideoController -Properties Name,AdapterRAM,DriverVersion,Status -CacheKey 'hw_gpu'
        $bios = Invoke-SafeCimQuery -ClassName Win32_BIOS -Properties Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber -CacheKey 'hw_bios'
        $mb   = Invoke-SafeCimQuery -ClassName Win32_BaseBoard -Properties Manufacturer,Product,Version,SerialNumber -CacheKey 'hw_board'

        [PSCustomObject]@{
            Timestamp    = (Get-Date).ToString('o')
            CPU          = $cpu | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
            MemoryGB     = [math]::Round(($mem | Measure-Object Capacity -Sum).Sum / 1GB, 2)
            MemoryModules= $mem | Select-Object Manufacturer,PartNumber,@{N='CapacityGB';E={[math]::Round($_.Capacity/1GB,2)}},Speed
            Disks        = $disk | Select-Object Model,@{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},MediaType,InterfaceType,FirmwareRevision
            GPUs         = $gpu | Select-Object Name,@{N='VRAM_GB';E={if($_.AdapterRAM){[math]::Round($_.AdapterRAM/1GB,2)}else{0}}},DriverVersion,Status
            BIOS         = $bios | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate
            Motherboard  = $mb | Select-Object Manufacturer,Product,Version
        }
    } catch {
        Write-CaughtException -Context "Get-HardwareSummary" -ErrorRecord $_ -Component "HWDiag" -Level WARN
        return $null
    }
}

function Get-SmartDiskHealth {
    <#
    .SYNOPSIS
        Retrieves SMART/health status for physical disks.
    .DESCRIPTION
        Uses Storage cmdlets to get disk reliability data without third-party tools.
    .EXAMPLE
        Get-SmartDiskHealth | Format-Table -AutoSize
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    if (-not $Global:IsWindows) { return @() }

    try {
        if (-not (Get-Command Get-PhysicalDisk -ErrorAction Ignore)) {
            Write-ProfileLog "Get-PhysicalDisk not available" -Level DEBUG -Component "HWDiag"
            return @()
        }
        Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,
            @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},BusType,FirmwareRevision
    } catch {
        Write-CaughtException -Context "Get-SmartDiskHealth" -ErrorRecord $_ -Component "HWDiag" -Level WARN
        return @()
    }
}

function Get-BatteryHealth {
    <#
    .SYNOPSIS
        Retrieves battery health information (laptops).
    .EXAMPLE
        Get-BatteryHealth | Format-List
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if (-not $Global:IsWindows) { return $null }

    try {
        $batt = Invoke-SafeCimQuery -ClassName Win32_Battery -CacheKey 'hw_battery'
        if (-not $batt) { return [PSCustomObject]@{ HasBattery = $false } }
        [PSCustomObject]@{
            HasBattery       = $true
            Status           = $batt.Status
            EstChargePercent = $batt.EstimatedChargeRemaining
            EstRunTimeMins   = $batt.EstimatedRunTime
            Chemistry        = switch ($batt.Chemistry) { 1{'Other'}; 2{'Unknown'}; 3{'LeadAcid'}; 4{'NiCd'}; 5{'NiMH'}; 6{'LiIon'}; default{'N/A'} }
        }
    } catch {
        Write-CaughtException -Context "Get-BatteryHealth" -ErrorRecord $_ -Component "HWDiag" -Level DEBUG
        return $null
    }
}

function Clear-CimQueryCache {
    <#
    .SYNOPSIS
        Clears the in-memory CIM query cache.
    .EXAMPLE
        Clear-CimQueryCache
    #>
    [CmdletBinding()]
    param()
    $script:CimQueryCache = @{}
    Write-ProfileLog "CIM query cache cleared" -Level DEBUG -Component "HWDiag"
}

#endregion ADDED: HARDWARE DIAGNOSTICS
