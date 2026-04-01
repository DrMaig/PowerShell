<#
.SYNOPSIS
    Profile component 01 - Bootstrap And Runtime Guards
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 1 (BOOTSTRAP AND RUNTIME GUARDS) for modular dot-sourced loading.
#>

#region 1 - BOOTSTRAP AND RUNTIME GUARDS
#==============================================================================
<#
.SYNOPSIS
    Core bootstrap and runtime guard mechanisms
.DESCRIPTION
    Provides fundamental runtime safety, environment validation, and bootstrapping
    capabilities to ensure the PowerShell profile operates in a controlled manner.
#>
# Profile version
$script:ProfileVersion = '3.1.0'

# Profile load start timestamp
$Global:ProfileLoadStart = Get-Date
$Global:ProfileLoadedTimestamp = $Global:ProfileLoadStart

# Initialize ProfileState
$Global:ProfileState = [ordered]@{
    IsWindows = $false
    IsLinux = $false
    IsMacOS = $false
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    IsAdmin = $false
    HasNetwork = $null
    MissingCommands = @()
    Notes = @()
    LastChecked = $null
}

# Initialize/normalize ProfileStats without replacing orchestrator schema
if (-not ($Global:ProfileStats -is [System.Collections.IDictionary])) {
    $Global:ProfileStats = [ordered]@{}
}
if (-not $Global:ProfileStats.Contains('ModulesLoaded')) {
    $Global:ProfileStats.ModulesLoaded = 0
}
if (-not $Global:ProfileStats.Contains('ComponentLoadTimes') -or -not ($Global:ProfileStats.ComponentLoadTimes -is [System.Collections.IDictionary])) {
    $Global:ProfileStats.ComponentLoadTimes = [ordered]@{}
}

# Ensure running PowerShell 7.5 or higher
if ($PSVersionTable.PSVersion.Major -lt 7 -or
    ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
    Write-Warning "This profile requires PowerShell 7.5 or higher. Current version: $($PSVersionTable.PSVersion)"
    return
}

# Verify 64-bit PowerShell process
if ([Environment]::Is64BitProcess -eq $false) {
    Write-Warning "This profile is designed for 64-bit PowerShell. Current: 32-bit"
    return
}

# Verify OS (allow reduced-feature load on non-Windows)
if (-not $IsWindows) {
    Write-Warning "Non-Windows platform detected. Loading profile with reduced feature set."
}

# Check if profile has already been loaded in this session
if ($Global:ProfileLoadedTimestamp -and ($Global:ProfileLoadedTimestamp -ne $Global:ProfileLoadStart)) {
    Write-Warning "Profile already loaded at $Global:ProfileLoadedTimestamp. Skipping reload to prevent conflicts."
    return
}

# Set strict mode for better error detection (with fallback)
try {
    Set-StrictMode -Version Latest
} catch {
    Set-StrictMode -Version 3.0
}

# Set error action preferences
$ErrorActionPreference = 'Continue'
$WarningPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
# FIX: Save original ProgressPreference; suppress only during load for speed
$script:OriginalProgressPreference = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'

# Global exit actions registry
if (-not (Test-Path variable:global:OnExitActions)) {
    $global:OnExitActions = @()
}

#endregion BOOTSTRAP AND RUNTIME GUARDS
