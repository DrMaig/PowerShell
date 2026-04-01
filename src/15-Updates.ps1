<#
.SYNOPSIS
    Profile component 15 - System Update Functions
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 15 (SYSTEM UPDATE FUNCTIONS) for modular dot-sourced loading.
#>

#region 15 - SYSTEM UPDATE FUNCTIONS
#==============================================================================
<#
.SYNOPSIS
    System update functions
.DESCRIPTION
    Provides functions for checking and installing system updates.
#>

function Get-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Gets Windows Update status.
    .DESCRIPTION
        Returns information about pending Windows updates.
    #>
    [CmdletBinding()]
    param()

    if (-not $Global:IsWindows) { return $null }

    try {
        if (-not (Get-Command Get-WindowsUpdate -ErrorAction Ignore)) {
            return [PSCustomObject]@{
                ModuleAvailable = $false
                Note = 'PSWindowsUpdate module not available. Install with: Install-Module PSWindowsUpdate'
            }
        }

        $updates = Get-WindowsUpdate -ErrorAction SilentlyContinue
        return [PSCustomObject]@{
            ModuleAvailable = $true
            PendingUpdates  = $updates.Count
            Updates         = $updates | Select-Object Title, KB, Size
        }
    } catch {
        Write-ProfileLog "Get-WindowsUpdateStatus failed: $_" -Level DEBUG -Component "Updates"
        return $null
    }
}

function Update-ProfileModules {
    <#
    .SYNOPSIS
        Updates installed PowerShell modules.
    .DESCRIPTION
        Checks for and installs module updates from PSGallery.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    try {
        if (-not (Get-Command Update-Module -ErrorAction Ignore)) {
            Write-Host "Update-Module not available. Ensure PowerShellGet is installed." -ForegroundColor Yellow
            return $false
        }

        $installed = Get-InstalledModule -ErrorAction SilentlyContinue
        if (-not $installed) {
            Write-Host "No installed modules found." -ForegroundColor Yellow
            return $true
        }

        $updated = 0
        foreach ($mod in $installed) {
            try {
                $available = Find-Module -Name $mod.Name -ErrorAction SilentlyContinue
                if ($available -and $available.Version -gt $mod.Version) {
                    if ($PSCmdlet.ShouldProcess("$($mod.Name) to v$($available.Version)", 'Update module')) {
                        Update-Module -Name $mod.Name -Force -ErrorAction SilentlyContinue
                        Write-ProfileLog "Module '$($mod.Name)' updated to v$($available.Version)" -Level INFO -Component "Updates"
                        $updated++
                    }
                }
            } catch {
                Write-CaughtException -Context "Update-ProfileModules item '$($mod.Name)'" -ErrorRecord $_ -Component "Updates" -Level DEBUG
            }
        }

        Write-Host "Modules updated: $updated" -ForegroundColor Green
        return $true
    } catch {
        Write-CaughtException -Context "Update-ProfileModules failed" -ErrorRecord $_ -Component "Updates" -Level WARN
        return $false
    }
}

function Update-HelpProfile {
    <#
    .SYNOPSIS
        Updates PowerShell help files.
    .DESCRIPTION
        Updates help files for installed modules.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    try {
        if ($PSCmdlet.ShouldProcess('PowerShell help files', 'Update')) {
            Update-Help -Force -ErrorAction SilentlyContinue
            Write-ProfileLog "Help files updated" -Level INFO -Component "Updates"
            return $true
        }
        return $false
    } catch {
        Write-ProfileLog "Update-HelpProfile failed: $_" -Level WARN -Component "Updates"
        return $false
    }
}

#endregion SYSTEM UPDATE FUNCTIONS
