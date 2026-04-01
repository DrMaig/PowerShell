<#
.SYNOPSIS
    Profile component 06 - Module Management System
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 6 (MODULE MANAGEMENT SYSTEM) for modular dot-sourced loading.
#>

#region 6 - MODULE MANAGEMENT SYSTEM
#==============================================================================
<#
.SYNOPSIS
    Module management with caching and deferred loading
.DESCRIPTION
    Provides comprehensive module management including caching, version checking,
    and deferred loading for optimal profile performance.
#>

# Module cache file
$script:InstalledModulesCacheFile = Join-Path $Global:ProfileConfig.CachePath 'installed_modules_cache.json'
$script:InstalledModulesCacheTtlSeconds = 300

function Update-InstalledModulesCache {
    <#
    .SYNOPSIS
        Updates the installed modules cache.
    .DESCRIPTION
        Caches information about installed modules for faster lookups.
    .PARAMETER Force
        Force refresh even if cache is not expired.
    #>
    [CmdletBinding()]
    param([switch]$Force)

    try {
        $needRefresh = $true
        if (-not $Force -and (Test-Path $script:InstalledModulesCacheFile)) {
            $age = (Get-Date) - (Get-Item $script:InstalledModulesCacheFile).LastWriteTime
            if ($age.TotalSeconds -lt $script:InstalledModulesCacheTtlSeconds) {
                $needRefresh = $false
            }
        }

        if (-not $needRefresh) { return $true }

        $installed = [ordered]@{}
        try {
            $mods = Get-InstalledModule -ErrorAction Ignore
            foreach ($m in $mods) {
                $installed[$m.Name] = @{
                    Name = $m.Name
                    Version = $m.Version.ToString()
                    Repository = $m.Repository
                    InstalledAt = (Get-Date).ToString('o')
                    Path = $m.InstalledLocation
                    Description = $m.Description
                }
            }
        } catch {
            # Fallback to Get-Module -ListAvailable
            $mods = Get-Module -ListAvailable -ErrorAction Ignore | Group-Object Name | ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 }
            foreach ($m in $mods) {
                $installed[$m.Name] = @{
                    Name = $m.Name
                    Version = ($m.Version).ToString()
                    Repository = $null
                    InstalledAt = (Get-Date).ToString('o')
                    Path = $m.ModuleBase
                    Description = $m.Description
                }
            }
        }

        $installed | ConvertTo-Json -Depth 4 | Set-Content -Path $script:InstalledModulesCacheFile -Encoding UTF8 -Force
        Write-ProfileLog "Module cache refreshed ($($installed.Keys.Count) entries)" -Level DEBUG -Component "Modules"
        return $true

    } catch {
        Write-ProfileLog "Module cache update failed: $_" -Level WARN -Component "Modules"
        return $false
    }
}

function Get-InstalledModulesCache {
    <#
    .SYNOPSIS
        Retrieves the installed modules cache.
    .DESCRIPTION
        Returns cached module information.
    .PARAMETER Refresh
        Force refresh before returning.
    #>
    [CmdletBinding()]
    param([switch]$Refresh)

    if ($Refresh) { Update-InstalledModulesCache -Force | Out-Null }
    if (-not (Test-Path $script:InstalledModulesCacheFile)) {
        Update-InstalledModulesCache | Out-Null
    }

    try {
        $json = Get-Content -Path $script:InstalledModulesCacheFile -Raw -ErrorAction Stop
        return $json | ConvertFrom-Json
    } catch {
        return @{}
    }
}

function Test-ModuleAvailable {
    <#
    .SYNOPSIS
        Tests if a module is available.
    .DESCRIPTION
        Checks if a module is installed and optionally meets minimum version.
    .PARAMETER Name
        Module name to check.
    .PARAMETER MinimumVersion
        Minimum required version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [version]$MinimumVersion
    )

    $cache = Get-InstalledModulesCache
    if ($null -ne $cache -and $cache.PSObject.Properties.Name -contains $Name) {
        $mod = $cache.$Name
        if ($mod.Version) {
            $ver = [version]$mod.Version
            if ($MinimumVersion -and $ver -lt $MinimumVersion) { return $false }
            return $true
        }
    }

    # Fallback to direct check
    $mod = Get-Module -ListAvailable -Name $Name -ErrorAction Ignore | Select-Object -First 1
    if ($mod) {
        if ($MinimumVersion -and $mod.Version -lt $MinimumVersion) { return $false }
        return $true
    }
    return $false
}

function Import-ProfileModule {
    <#
    .SYNOPSIS
        Imports a module with error handling and tracking.
    .DESCRIPTION
        Safely imports a module and tracks load time.
    .PARAMETER ModuleName
        Name of the module to import.
    .PARAMETER Required
        Treat as required (warnings on failure).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [switch]$Required
    )

    $loadStart = Get-Date

    if (Test-ModuleAvailable -Name $ModuleName) {
        try {
            Import-Module -Name $ModuleName -ErrorAction Stop -Global
            $loadTime = (Get-Date) - $loadStart
            $Global:ProfileStats.ModulesLoaded++
            Write-ProfileLog "Module '$ModuleName' loaded in $($loadTime.TotalMilliseconds)ms" -Level DEBUG -Component "Modules"
            return $true
        } catch {
            if ($Required) {
                Write-ProfileLog "Required module '$ModuleName' failed to load: $_" -Level WARN -Component "Modules"
            }
            return $false
        }
    } else {
        if ($Required) {
            Write-ProfileLog "Required module '$ModuleName' not found" -Level WARN -Component "Modules"
        }
        return $false
    }
}

function Assert-ModuleAvailable {
    # NOTE: Keep Ensure-Module as alias for backward compatibility
    <#
    .SYNOPSIS
        Ensures a module is available, installing if necessary.
    .DESCRIPTION
        Checks for module and installs from PSGallery if missing.
    .PARAMETER Name
        Module name.
    .PARAMETER Repository
        Repository name (default: PSGallery).
    .PARAMETER InstallIfMissing
        Install if not found.
    .PARAMETER Force
        Force reinstall.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Repository = 'PSGallery',
        [switch]$InstallIfMissing,
        [switch]$Force
    )

    try {
        if (Test-ModuleAvailable -Name $Name) {
            Import-Module $Name -ErrorAction SilentlyContinue
            return $true
        }

        if ($InstallIfMissing -and (Get-Command Install-Module -ErrorAction Ignore)) {
            # Ensure PSGallery is registered
            if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                Register-PSRepository -Name PSGallery -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            }

            Install-Module -Name $Name -Repository $Repository -Scope CurrentUser -Force:$Force -Confirm:$false -ErrorAction SilentlyContinue

            if (Test-ModuleAvailable -Name $Name) {
                Import-Module $Name -ErrorAction SilentlyContinue
                return $true
            }
        }
        return $false
    } catch {
        return $false
    }
}

# Deferred Module Loader
$Global:DeferredModulesStatus = [ordered]@{
    Started = $false
    Completed = $false
    StartedAt = $null
    CompletedAt = $null
    Modules = @{}
    Jobs = @{}
}

function Start-DeferredModuleLoader {
    <#
    .SYNOPSIS
        Loads optional modules after profile startup for non-blocking load.
    .DESCRIPTION
        Registers a PowerShell.OnIdle engine event to import modules after the
        first prompt is displayed, keeping profile startup fast. Falls back to
        synchronous in-process import when OnIdle registration fails.
    .PARAMETER Modules
        Array of module names to load.
    .PARAMETER TimeoutSeconds
        Timeout for synchronous fallback (seconds).
    #>
    [CmdletBinding()]
    param(
        [string[]]$Modules = $Global:ProfileConfig.DeferredLoader.Modules,
        [int]$TimeoutSeconds = $Global:ProfileConfig.DeferredLoader.TimeoutSeconds
    )

    if ($Global:DeferredModulesStatus.Started) { return }

    $Global:DeferredModulesStatus.Started = $true
    $Global:DeferredModulesStatus.StartedAt = (Get-Date).ToString('o')

    if (-not $Modules -or $Modules.Count -eq 0) {
        $Global:DeferredModulesStatus.Completed = $true
        $Global:DeferredModulesStatus.CompletedAt = (Get-Date).ToString('o')
        return
    }

    $status = [ordered]@{}
    foreach ($m in $Modules) { $status[$m] = 'Pending' }
    $Global:DeferredModulesStatus.Modules = $status

    # Preferred path: Register-EngineEvent PowerShell.OnIdle imports modules
    # in the current session after the first prompt, truly non-blocking.
    $registered = $false
    try {
        $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
            $mods = $Event.MessageData.Modules
            $stat = $Event.MessageData.Status
            foreach ($m in $mods) {
                try {
                    if (Get-Module -ListAvailable -Name $m -ErrorAction Ignore) {
                        Import-Module $m -ErrorAction Stop -Global
                        $stat[$m] = 'Imported'
                    } else {
                        $stat[$m] = 'NotFound'
                    }
                } catch {
                    $stat[$m] = "Failed: $($_.Exception.Message)"
                }
            }
            $Global:DeferredModulesStatus.Completed = $true
            $Global:DeferredModulesStatus.CompletedAt = (Get-Date).ToString('o')

            $imported = $stat.GetEnumerator() | Where-Object { $_.Value -eq 'Imported' } | ForEach-Object { $_.Key }
            if ($imported -and (Get-Command Write-ProfileLog -ErrorAction Ignore)) {
                Write-ProfileLog "Deferred modules loaded (OnIdle): $($imported -join ', ')" -Level DEBUG -Component 'Modules'
            }
        } -MessageData @{ Modules = $Modules; Status = $status } -ErrorAction Stop
        $registered = $true
    } catch {
        Write-ProfileLog "OnIdle registration failed, using synchronous fallback: $($_.Exception.Message)" -Level DEBUG -Component 'Modules'
    }

    # Fallback: synchronous in-process import (still correct — loads into caller session)
    if (-not $registered) {
        foreach ($m in $Modules) {
            try {
                if (Get-Module -ListAvailable -Name $m -ErrorAction Ignore) {
                    Import-Module $m -ErrorAction Stop -Global
                    $status[$m] = 'Imported'
                } else {
                    $status[$m] = 'NotFound'
                }
            } catch {
                $status[$m] = "Failed: $($_.Exception.Message)"
            }
        }

        $Global:DeferredModulesStatus.Completed = $true
        $Global:DeferredModulesStatus.CompletedAt = (Get-Date).ToString('o')

        $imported = $status.GetEnumerator() | Where-Object { $_.Value -eq 'Imported' } | ForEach-Object { $_.Key }
        if ($imported) {
            Write-ProfileLog "Deferred modules loaded (sync): $($imported -join ', ')" -Level DEBUG -Component 'Modules'
        }
    }
}

# FIX: Defer module cache to first use instead of synchronous load (startup perf)
# Update-InstalledModulesCache is called lazily by Get-InstalledModulesCache
# Update-InstalledModulesCache | Out-Null  # <-- removed for startup speed

# Start deferred loader for interactive sessions (uses OnIdle event for true async)
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.Features.UseDeferredModuleLoader -and $Global:ProfileConfig.DeferredLoader.Modules.Count -gt 0) {
    Start-DeferredModuleLoader | Out-Null
}

#endregion MODULE MANAGEMENT SYSTEM
