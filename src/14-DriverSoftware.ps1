<#
.SYNOPSIS
    Profile component 14 - Driver And Software Management
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 14 (DRIVER AND SOFTWARE MANAGEMENT) for modular dot-sourced loading.
#>

#region 14 - DRIVER AND SOFTWARE MANAGEMENT
#==============================================================================
<#
.SYNOPSIS
    Driver and software management functions
.DESCRIPTION
    Provides functions for managing drivers and installed software.
#>

function Get-DriverInfo {
    <#
    .SYNOPSIS
        Retrieves driver information.
    .DESCRIPTION
        Returns installed drivers with version information.
    .PARAMETER Name
        Filter by driver name.
    #>
    [CmdletBinding()]
    param([string]$Name)

    if (-not $Global:IsWindows) { return @() }

    try {
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { $_.DriverVersion }

        if ($Name) {
            $drivers = $drivers | Where-Object { $_.DeviceName -like "*$Name*" -or $_.FriendlyName -like "*$Name*" }
        }

        return $drivers | Select-Object DeviceName, FriendlyName, DriverVersion, DriverDate, Manufacturer |
            Sort-Object DeviceName
    } catch {
        Write-ProfileLog "Get-DriverInfo failed: $_" -Level DEBUG -Component "Drivers"
        return @()
    }
}

function Get-InstalledSoftware {
    <#
    .SYNOPSIS
        Retrieves installed software.
    .DESCRIPTION
        Returns installed software from registry.
    .PARAMETER Name
        Filter by software name.
    #>
    [CmdletBinding()]
    param([string]$Name)

    if (-not $Global:IsWindows) { return @() }

    try {
        $software = @()

        $paths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
        )

        foreach ($p in $paths) {
            if (Test-Path $p) {
                $items = Get-ChildItem -Path $p -ErrorAction SilentlyContinue
                foreach ($i in $items) {
                    $props = Get-ItemProperty -Path $i.PSPath -ErrorAction SilentlyContinue
                    if ($props.DisplayName) {
                        $software += [PSCustomObject]@{
                            Name         = $props.DisplayName
                            Version      = $props.DisplayVersion
                            Publisher    = $props.Publisher
                            InstallDate  = $props.InstallDate
                            InstallLocation = $props.InstallLocation
                            UninstallString = $props.UninstallString
                        }
                    }
                }
            }
        }

        $software = $software | Sort-Object Name -Unique
        if ($Name) { $software = $software | Where-Object Name -like "*$Name*" }

        return $software
    } catch {
        Write-ProfileLog "Get-InstalledSoftware failed: $_" -Level DEBUG -Component "Software"
        return @()
    }
}

function Find-DuplicateDrivers {
    <#
    .SYNOPSIS
        Finds potentially duplicate drivers.
    .DESCRIPTION
        Identifies drivers with duplicate device names.
    #>
    [CmdletBinding()]
    param()

    if (-not $Global:IsWindows) { return @() }

    try {
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { $_.DeviceName }

        $grouped = $drivers | Group-Object DeviceName | Where-Object { $_.Count -gt 1 }

        return $grouped | Select-Object Name, Count, @{N = 'Versions'; E = { ($_.Group | Select-Object -ExpandProperty DriverVersion -Unique) -join ', ' }}
    } catch {
        Write-ProfileLog "Find-DuplicateDrivers failed: $_" -Level DEBUG -Component "Drivers"
        return @()
    }
}

#endregion DRIVER AND SOFTWARE MANAGEMENT
