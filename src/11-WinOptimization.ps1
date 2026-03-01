<#
.SYNOPSIS
    Profile component 11 - Windows Optimization And Maintenance
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 11 (WINDOWS OPTIMIZATION AND MAINTENANCE) for modular dot-sourced loading.
#>

#region 11 - WINDOWS OPTIMIZATION AND MAINTENANCE
#==============================================================================
<#
.SYNOPSIS
    Windows optimization and maintenance functions
.DESCRIPTION
    Provides system optimization, cleanup, and maintenance functions.
#>

function Optimize-System {
    <#
    .SYNOPSIS
        Performs system optimization.
    .DESCRIPTION
        Cleans temporary files and performs non-destructive optimizations.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not (Test-Admin)) {
        Write-ProfileLog "Optimize-System requires admin privileges" -Level WARN -Component "Optimization"
        Write-Host "This function requires administrator privileges." -ForegroundColor Yellow
        return $false
    }

    try {
        # Clean user temp files older than 7 days
        $temp = [IO.Path]::GetTempPath()
        $cutoff = (Get-Date).AddDays(-7)

        $files = Get-ChildItem -Path $temp -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }

        $count = 0
        $failed = 0
        foreach ($f in $files) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                $count++
            } catch {
                $failed++
                Write-ProfileLog "Temp cleanup failed for '$($f.FullName)': $($_.Exception.Message)" -Level DEBUG -Component "Optimization"
            }
        }

        Write-ProfileLog "Cleaned $count temp files ($failed skipped)" -Level INFO -Component "Optimization"

        # Clear Recycle Bin (optional, with ShouldProcess)
        try {
            if ($PSCmdlet.ShouldProcess('Recycle Bin', 'Clear contents')) {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-ProfileLog "Recycle bin cleared" -Level INFO -Component "Optimization"
            }
        } catch {
            Write-CaughtException -Context "Optimize-System recycle bin cleanup" -ErrorRecord $_ -Component "Optimization" -Level DEBUG
        }

        return $true
    } catch {
        Write-ProfileLog "Optimize-System failed: $_" -Level ERROR -Component "Optimization"
        return $false
    }
}

function Invoke-DiskMaintenance {
    <#
    .SYNOPSIS
        Performs disk maintenance.
    .DESCRIPTION
        Runs disk optimization (defrag/TRIM) on specified drive.
    .PARAMETER DriveLetter
        Drive letter to optimize.
    .PARAMETER AnalyzeOnly
        Only analyze, don't optimize.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [ValidatePattern('^[A-Za-z]:?$')]
        [string]$DriveLetter = 'C',
        [switch]$AnalyzeOnly
    )

    if (-not $Global:IsWindows) {
        Write-ProfileLog "Invoke-DiskMaintenance is Windows-only" -Level WARN -Component "Optimization"
        return $false
    }

    $drive = ($DriveLetter.TrimEnd(':') + ':')

    try {
        if ($AnalyzeOnly) {
            if ($PSCmdlet.ShouldProcess($drive, 'Analyze disk')) {
                Start-Process -FilePath 'defrag.exe' -ArgumentList "$drive /A /U /V" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                return $true
            }
        } else {
            if ($PSCmdlet.ShouldProcess($drive, 'Optimize disk')) {
                Start-Process -FilePath 'defrag.exe' -ArgumentList "$drive /U /V /O" -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
                Write-ProfileLog "Disk maintenance completed for $drive" -Level INFO -Component "Optimization"
                return $true
            }
        }
        return $false
    } catch {
        Write-ProfileLog "Invoke-DiskMaintenance failed: $_" -Level WARN -Component "Optimization"
        return $false
    }
}

function Set-PowerPlan {
    <#
    .SYNOPSIS
        Sets the active power plan.
    .DESCRIPTION
        Changes the Windows power plan.
    .PARAMETER Plan
        Power plan: Balanced, HighPerformance, or PowerSaver.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Balanced', 'HighPerformance', 'PowerSaver')]
        [string]$Plan
    )

    if (-not $Global:IsWindows) {
        Write-ProfileLog "Set-PowerPlan is Windows-only" -Level WARN -Component "Optimization"
        return $false
    }

    $planGuid = switch ($Plan) {
        'Balanced'        { '381b4222-f694-41f0-9685-ff5bb260df2e' }
        'HighPerformance' { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
        'PowerSaver'      { 'a1841308-3541-4fab-bc81-f71556f20b4a' }
    }

    try {
        if ($PSCmdlet.ShouldProcess($Plan, 'Set power plan')) {
            powercfg /setactive $planGuid | Out-Null
            Write-ProfileLog "Power plan set to: $Plan" -Level INFO -Component "Optimization"
            return $true
        }
        return $false
    } catch {
        Write-ProfileLog "Set-PowerPlan failed: $_" -Level WARN -Component "Optimization"
        return $false
    }
}

function Get-PowerPlan {
    <#
    .SYNOPSIS
        Gets the active power plan.
    .DESCRIPTION
        Returns the currently active Windows power plan.
    #>
    [CmdletBinding()]
    param()

    if (-not $Global:IsWindows) { return $null }

    try {
        $activePlan = powercfg /getactivescheme
        if ($activePlan -match 'GUID:\s+([a-f0-9-]+)\s+\((.+)\)') {
            return [PSCustomObject]@{
                ActivePlan = $Matches[2]
                GUID       = $Matches[1]
            }
        }
    } catch {
        return $null
    }
}

#endregion WINDOWS OPTIMIZATION AND MAINTENANCE
