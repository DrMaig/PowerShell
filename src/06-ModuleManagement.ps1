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
        Loads optional modules in background for non-blocking profile load.
    .DESCRIPTION
        Uses jobs to load modules asynchronously for better startup performance.
    .PARAMETER Modules
        Array of module names to load.
    .PARAMETER TimeoutSeconds
        Timeout for job completion.
    .PARAMETER UseJobs
        Use background jobs for loading.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Modules = $Global:ProfileConfig.DeferredLoader.Modules,
        [int]$TimeoutSeconds = $Global:ProfileConfig.DeferredLoader.TimeoutSeconds,
        [switch]$UseJobs
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

    if ($UseJobs) {
        $scriptBlock = {
            param($mods)
            $result = @{}
            foreach ($mod in $mods) {
                try {
                    if (Get-Module -ListAvailable -Name $mod -ErrorAction Ignore) {
                        Import-Module $mod -ErrorAction Stop -Global
                        $result[$mod] = 'Imported'
                    } else {
                        $result[$mod] = 'NotFound'
                    }
                } catch {
                    $result[$mod] = "Failed: $($_.Exception.Message)"
                }
            }
            return $result
        }

        $job = $null
        try {
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList (, $Modules) -ErrorAction Stop
            $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds -ErrorAction Ignore
            if ($completed) {
                $res = Receive-Job -Job $job -ErrorAction Ignore
                foreach ($k in $res.Keys) { $status[$k] = $res[$k] }
            } else {
                foreach ($m in $Modules) {
                    if ($status[$m] -eq 'Pending') { $status[$m] = 'Timeout' }
                }
                try { Stop-Job -Job $job -ErrorAction Ignore } catch { Write-ProfileLog "Stop-Job failed during deferred loader timeout: $($_.Exception.Message)" -Level DEBUG -Component "Modules" }
            }
        } catch {
            Write-CaughtException -Context "Start-DeferredModuleLoader job execution" -ErrorRecord $_ -Component "Modules" -Level WARN
            foreach ($m in $Modules) {
                if ($status[$m] -eq 'Pending') { $status[$m] = 'Failed' }
            }
        } finally {
            if ($job) {
                try { Remove-Job -Job $job -Force -ErrorAction Ignore } catch { Write-ProfileLog "Remove-Job failed during deferred loader cleanup: $($_.Exception.Message)" -Level DEBUG -Component "Modules" }
            }
        }
    } else {
        foreach ($m in $Modules) {
            try {
                Import-Module $m -ErrorAction Stop -Global
                $status[$m] = 'Imported'
            } catch {
                $status[$m] = "Failed: $($_.Exception.Message)"
            }
        }
    }

    $Global:DeferredModulesStatus.Modules = $status
    $Global:DeferredModulesStatus.Completed = $true
    $Global:DeferredModulesStatus.CompletedAt = (Get-Date).ToString('o')

    # Log results
    $imported = $status.GetEnumerator() | Where-Object { $_.Value -eq 'Imported' } | ForEach-Object { $_.Key }
    if ($imported) {
        Write-ProfileLog "Deferred modules loaded: $($imported -join ', ')" -Level DEBUG -Component "Modules"
    }
}

# FIX: Defer module cache to first use instead of synchronous load (startup perf)
# Update-InstalledModulesCache is called lazily by Get-InstalledModulesCache
# Update-InstalledModulesCache | Out-Null  # <-- removed for startup speed

# Start deferred loader for interactive sessions
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.Features.UseDeferredModuleLoader -and $Global:ProfileConfig.DeferredLoader.Modules.Count -gt 0) {
    Start-DeferredModuleLoader -UseJobs:$Global:ProfileConfig.DeferredLoader.UseJobs | Out-Null
}

#endregion MODULE MANAGEMENT SYSTEM
