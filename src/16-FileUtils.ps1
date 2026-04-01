<#
.SYNOPSIS
    Profile component 16 - File And Disk Utilities
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 16 (FILE AND DISK UTILITIES) for modular dot-sourced loading.
#>

#region 16 - FILE AND DISK UTILITIES
#==============================================================================
<#
.SYNOPSIS
    File and disk utility functions
.DESCRIPTION
    Provides functions for file operations and disk usage analysis.
#>

function Get-DiskUsage {
    <#
    .SYNOPSIS
        Gets disk usage for a directory.
    .DESCRIPTION
        Returns size information for directories.
    .PARAMETER Path
        Directory path to analyze.
    .PARAMETER Top
        Number of top directories to return.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $PWD,
        [int]$Top = 0
    )

    $ud = $Global:ProfileConfig.UtilityDefaults
    if ($Top -le 0) { $Top = $ud.DiskUsageTop }
    if ($Top -le 0) { $Top = 20 }

    try {
        $items = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        $usage = @()

        foreach ($i in $items) {
            try {
                $size = (Get-ChildItem -Path $i.FullName -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                $usage += [PSCustomObject]@{
                    Path = $i.FullName
                    SizeGB = [math]::Round($size / 1GB, 2)
                    SizeMB = [math]::Round($size / 1MB, 2)
                }
            } catch {
                Write-ProfileLog "Get-DiskUsage failed for '$($i.FullName)': $($_.Exception.Message)" -Level DEBUG -Component "Disk"
            }
        }

        return $usage | Sort-Object SizeGB -Descending | Select-Object -First $Top
    } catch {
        Write-ProfileLog "Get-DiskUsage failed: $_" -Level DEBUG -Component "Disk"
        return @()
    }
}

function Find-LargeFiles {
    <#
    .SYNOPSIS
        Finds large files.
    .DESCRIPTION
        Returns files larger than specified size.
    .PARAMETER Path
        Directory path to search.
    .PARAMETER SizeMB
        Minimum file size in MB.
    .PARAMETER Top
        Number of results to return.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $PWD,
        [int]$SizeMB = 100,
        [int]$Top = 20
    )

    try {
        $minBytes = $SizeMB * 1MB
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -ge $minBytes } |
            Sort-Object Length -Descending |
            Select-Object -First $Top |
            Select-Object FullName, @{N = 'SizeMB'; E = { [math]::Round($_.Length / 1MB, 2) }}, LastWriteTime
    } catch {
        Write-ProfileLog "Find-LargeFiles failed: $_" -Level DEBUG -Component "Disk"
        return @()
    }
}

function Clear-TempFiles {
    <#
    .SYNOPSIS
        Clears temporary files.
    .DESCRIPTION
        Removes temporary files older than specified days.
    .PARAMETER DaysOld
        Files older than this many days will be removed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [int]$DaysOld = 7
    )

    if (-not (Test-Admin)) {
        Write-Host "Some temp locations may require administrator privileges." -ForegroundColor Yellow
    }

    try {
        # Build temp paths list — Windows-only paths guarded by $IsWindows
        $tempPaths = @([IO.Path]::GetTempPath())
        if ($IsWindows) {
            if ($env:LOCALAPPDATA) { $tempPaths += Join-Path $env:LOCALAPPDATA 'Temp' }
            if ($env:WINDIR)       { $tempPaths += Join-Path $env:WINDIR 'Temp' }
        }

        $cutoff = (Get-Date).AddDays(-$DaysOld)
        $removed = 0
        $freed = 0

        foreach ($p in $tempPaths) {
            if (Test-Path $p) {
                $files = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt $cutoff }

                foreach ($f in $files) {
                    if ($PSCmdlet.ShouldProcess($f.FullName, 'Remove temp file')) {
                        try {
                            $freed += $f.Length
                            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                            $removed++
                        } catch {
                            Write-ProfileLog "Failed to remove temp file '$($f.FullName)': $($_.Exception.Message)" -Level DEBUG -Component "Cleanup"
                        }
                    }
                }
            }
        }

        if (-not $WhatIfPreference) {
            Write-ProfileLog "Removed $removed temp files, freed $([math]::Round($freed / 1MB, 2)) MB" -Level INFO -Component "Cleanup"
        }

        return [PSCustomObject]@{
            FilesRemoved = $removed
            SpaceFreedMB = [math]::Round($freed / 1MB, 2)
        }
    } catch {
        Write-ProfileLog "Clear-TempFiles failed: $_" -Level WARN -Component "Cleanup"
        return $null
    }
}

#endregion FILE AND DISK UTILITIES
