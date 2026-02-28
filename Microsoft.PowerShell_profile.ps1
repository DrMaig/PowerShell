#requires -Version 7.5
#==============================================================================
# PowerShell 7.5+ Professional Profile for Windows 10 Pro
#==============================================================================
# .SYNOPSIS
#    Enterprise-grade PowerShell profile with comprehensive system administration,
#    automation, security, diagnostics, and optimization features.
#
# .DESCRIPTION
#    This profile provides:
#    - Runtime guards and environment detection
#    - Comprehensive logging and error handling
#    - Performance monitoring and benchmarking
#    - System administration (hardware, OS, BIOS, drivers)
#    - Network management and DNS configuration
#    - Process, service, and task management
#    - Windows optimization and maintenance
#    - Self-diagnostics and troubleshooting
#    - PSReadLine integration with predictive IntelliSense
#    - Module management with deferred loading
#    - Third-party CLI tool integrations
#
# .NOTES
#    Author: PowerShell Profile Builder
#    Version: 2.0.0
#    PowerShell: 7.5+
#    OS: Windows 10/11 Pro x64
#    Last Modified: 2026-02-09
#
# .LINK
#    Microsoft Learn: https://learn.microsoft.com/powershell/
#    PowerShell Gallery: https://www.powershellgallery.com/
#    Oh-My-Posh: https://ohmyposh.dev/
#    PSReadLine: https://github.com/PowerShell/PSReadLine
#==============================================================================

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
$script:ProfileVersion = '2.0.0'

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

# Initialize ProfileStats
$Global:ProfileStats = [ordered]@{
    ModulesLoaded = 0
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

# Verify Windows OS
if ($PSVersionTable.Platform -ne 'Win32NT' -and -not $IsWindows) {
    Write-Warning "This profile is designed for Windows operating systems."
    return
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
$ProgressPreference = 'SilentlyContinue'

# Global exit actions registry
if (-not (Test-Path variable:global:OnExitActions)) {
    $global:OnExitActions = @()
}

#endregion BOOTSTRAP AND RUNTIME GUARDS

#region 2 - PLATFORM DETECTION AND GLOBAL FLAGS
#==============================================================================

# --- FIX: Ensure ProfileConfig is initialized with all required nested properties ---

if ($null -eq (Get-Variable -Name ProfileConfig -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:ProfileConfig = [ordered]@{
        # Display Settings
        ShowDiagnostics   = $true
        ShowWelcome       = $true
        PromptStyle       = 'Modern'

        # Feature Flags
        EnableLogging     = $true
        EnableAutoUpdate  = $true
        EnableTranscript  = $false
        EnablePoshGit     = $true
        EnableFzf         = $true
        EnableOhMyPosh    = $true
        EnableTerminalIcons = $true

        # Paths
        LogPath           = (Join-Path $HOME 'Documents\PowerShell\Logs')
        TranscriptPath    = (Join-Path $HOME 'Documents\PowerShell\Transcripts')
        CachePath         = (Join-Path $HOME 'Documents\PowerShell\Cache')
        ThemesPath        = (Join-Path $HOME 'Documents\PowerShell\Themes')

        # Editor and Tools
        Editor            = 'code'

        # History and Performance
        UpdateCheckDays   = 7
        HistorySize       = 10000
        MaxHistoryCount   = 10000

        # Deferred Loader Configuration
        DeferredLoader   = @{
            Modules = @('posh-git', 'Terminal-Icons', 'oh-my-posh')
            TimeoutSeconds = 10
            UseJobs = $true
        }

        # Toolchain Catalog Configuration
        ToolchainCatalog = @{}

        # Telemetry (opt-in, disabled by default)
        Telemetry        = @{}

        # Aliases Configuration
        Aliases          = @{}

        # Utility Defaults
        UtilityDefaults  = @{
            PerfSnapshotSampleSeconds = 1
            TopProcessesTop = 15
            DiskUsageTop = 20
        }

        # Welcome Screen Configuration
        WelcomeScreen    = @{
            Show = $true
            Style = 'Full'
        }

        # PSReadLine Configuration
        PSReadLine       = @{
            EditMode = 'Windows'
            HistorySize = 10000
            HistorySavePath = $null
            BellStyle = 'None'
            PredictionSource = 'HistoryAndPlugin'
            PredictionViewStyle = 'ListView'
            HistoryNoDuplicates = $true
            HistorySearchCursorMovesToEnd = $true
            ShowToolTips = $true
            MaximumKillRingCount = 20
            Colors = @{}
            KeyBindings = @{}
        }
        # NetworkProfiles will be initialized later
    }
}

# Set PSReadLine HistorySavePath after CachePath is defined
if (-not $Global:ProfileConfig.PSReadLine.HistorySavePath) {
    $Global:ProfileConfig.PSReadLine.HistorySavePath = Join-Path $Global:ProfileConfig.CachePath 'PSReadLine_history.txt'
}

# Ensure required directories exist
$pathsToEnsure = @(
    $Global:ProfileConfig.LogPath,
    $Global:ProfileConfig.TranscriptPath,
    $Global:ProfileConfig.CachePath,
    $Global:ProfileConfig.ThemesPath
)
foreach ($p in $pathsToEnsure) {
    try {
        if (-not (Test-Path -Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    } catch {}
}

#endregion PLATFORM DETECTION AND GLOBAL FLAGS


#region 3 - LOGGING AND TELEMETRY FRAMEWORK
#==============================================================================
<#
.SYNOPSIS
    Unified logging and telemetry framework
.DESCRIPTION
    Provides comprehensive logging capabilities with multiple destinations,
    structured logging, and optional telemetry collection.
#>

# Log levels definition
$script:LogLevels = @('DEBUG', 'INFO', 'SUCCESS', 'WARN', 'ERROR', 'CRITICAL')

function Write-ProfileLog {
    <#
    .SYNOPSIS
        Structured logging helper for profile messages.
    .DESCRIPTION
        Writes log messages with timestamp, level, and optional file output.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        Log level: DEBUG, INFO, SUCCESS, WARN, ERROR, CRITICAL.
    .PARAMETER Component
        Optional component/category name.
    .PARAMETER File
        Optional file path to append logs.
    .EXAMPLE
        Write-ProfileLog -Message 'Operation completed' -Level SUCCESS
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARN', 'ERROR', 'CRITICAL')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$Component = 'General',

        [Parameter()]
        [string]$File = $null
    )

    try {
        # Check if logging is enabled
        if (-not $Global:ProfileConfig.EnableLogging -and $Level -eq 'DEBUG') {
            return
        }

        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        $line = "[$timestamp] [$Level] [$Component] $Message"

        # Console output with colors
        switch ($Level) {
            'CRITICAL' { Write-Host $line -ForegroundColor Magenta }
            'ERROR'    { Write-Host $line -ForegroundColor Red }
            'WARN'     { Write-Host $line -ForegroundColor Yellow }
            'SUCCESS'  { Write-Host $line -ForegroundColor Green }
            'DEBUG'    { 
                if ($Global:ProfileConfig.ShowDiagnostics) {
                    Write-Host $line -ForegroundColor DarkGray 
                }
            }
            default    { Write-Host $line -ForegroundColor Cyan }
        }

        # File logging
        if ($File -or $Global:ProfileConfig.LogPath) {
            $logFile = if ($File) { $File } else { 
                Join-Path $Global:ProfileConfig.LogPath ("profile_$(Get-Date -Format 'yyyyMM').log")
            }
            try {
                $dir = Split-Path -Path $logFile -Parent
                if (-not (Test-Path -Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
                Add-Content -Path $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
            } catch {}
        }
    } catch {
        # Silent failure for logging
    }
}

function Get-ProfileLog {
    <#
    .SYNOPSIS
        Retrieves profile log entries.
    .DESCRIPTION
        Reads log file and returns recent entries.
    .PARAMETER Lines
        Number of lines to return (default: 100).
    .PARAMETER Level
        Filter by log level.
    #>
    [CmdletBinding()]
    param(
        [int]$Lines = 100,
        [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARN', 'ERROR', 'CRITICAL', 'All')]
        [string]$Level = 'All'
    )

    $logFile = Join-Path $Global:ProfileConfig.LogPath ("profile_$(Get-Date -Format 'yyyyMM').log")
    if (-not (Test-Path $logFile)) {
        return @()
    }

    try {
        $content = Get-Content -Path $logFile -Tail $Lines -ErrorAction Stop
        if ($Level -ne 'All') {
            $content = $content | Where-Object { $_ -match "\[$Level\]" }
        }
        return $content
    } catch {
        return @()
    }
}

function Invoke-ProfileLogRotation {
    <#
    .SYNOPSIS
        Rotates log files to prevent unbounded growth.
    .DESCRIPTION
        Archives old log files and removes files older than specified months.
    .PARAMETER KeepMonths
        Number of months to retain (default: 6).
    #>
    [CmdletBinding()]
    param([int]$KeepMonths = 6)

    try {
        $files = Get-ChildItem -Path $Global:ProfileConfig.LogPath -Filter "profile_*.log" -File -ErrorAction SilentlyContinue
        $cutoff = (Get-Date).AddMonths(-$KeepMonths)

        foreach ($f in $files) {
            if ($f.BaseName -match 'profile_(\d{6})') {
                $ym = $Matches[1]
                $dt = [datetime]::ParseExact($ym, 'yyyyMM', $null)
                if ($dt -lt $cutoff) {
                    Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-ProfileLog "Log rotation completed (keep $KeepMonths months)" -Level DEBUG
    } catch {
        Write-ProfileLog "Log rotation failed: $_" -Level WARN
    }
}

# Initialize logging
Write-ProfileLog "PowerShell profile v$script:ProfileVersion loading..." -Level INFO -Component "Bootstrap"

#endregion LOGGING AND TELEMETRY FRAMEWORK

#region 4 - ENVIRONMENT VALIDATION AND UTILITY FUNCTIONS
#==============================================================================
<#
.SYNOPSIS
    Environment validation and core utility functions
.DESCRIPTION
    Provides functions for testing admin privileges, interactive mode,
    and comprehensive environment validation.
#>

function Test-Admin {
    <#
    .SYNOPSIS
        Tests if the current session has administrator privileges.
    .DESCRIPTION
        Returns $true if running as Administrator (Windows) or root (Unix).
    .EXAMPLE
        if (Test-Admin) { Write-Host "Running as admin" }
    #>
    [CmdletBinding()]
    param()

    try {
        if ($Global:IsWindows) {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } else {
            return ($null -ne $env:SUDO_UID) -or ($env:USERNAME -eq 'root')
        }
    } catch {
        return $false
    }
}

function Test-ProfileInteractive {
    <#
    .SYNOPSIS
        Tests if the current host is interactive.
    .DESCRIPTION
        Returns $true if the host supports interactive features.
    #>
    [CmdletBinding()]
    param()

    try {
        return ($Host -and $Host.UI -and $Host.UI.RawUI)
    } catch {
        return $false
    }
}

function Test-Environment {
    <#
    .SYNOPSIS
        Performs comprehensive environment validation.
    .DESCRIPTION
        Tests platform, admin status, network connectivity, and available commands.
    .PARAMETER SkipNetworkCheck
        Skip network connectivity test.
    #>
    [CmdletBinding()]
    param([switch]$SkipNetworkCheck)

    # Platform detection
    $Global:ProfileState.IsWindows = $Global:IsWindows
    $Global:ProfileState.IsLinux = $Global:IsLinux
    $Global:ProfileState.IsMacOS = $Global:IsMacOS
    $Global:ProfileState.PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    # Admin check
    try {
        $Global:ProfileState.IsAdmin = Test-Admin
    } catch {
        $Global:ProfileState.IsAdmin = $false
        $Global:ProfileState.Notes += "Admin check failed"
    }

    # Command availability check
    $commandsToCheck = @('git', 'winget', 'choco', 'scoop', 'oh-my-posh', 'code', 'python', 'node', 'npm')
    $missing = @()
    foreach ($c in $commandsToCheck) {
        if (-not (Get-Command $c -ErrorAction SilentlyContinue)) {
            $missing += $c
        }
    }
    $Global:ProfileState.MissingCommands = $missing

    # Network check
    if ($SkipNetworkCheck) {
        $Global:ProfileState.HasNetwork = $null
    } else {
        try {
            if ($Global:IsWindows) {
                $test = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -TimeoutSeconds 2
                $Global:ProfileState.HasNetwork = $test
            } else {
                $sock = New-Object System.Net.Sockets.TcpClient
                $async = $sock.BeginConnect('8.8.8.8', 53, $null, $null)
                $ok = $async.AsyncWaitHandle.WaitOne(3000)
                if ($ok) { 
                    $sock.EndConnect($async)
                    $sock.Close()
                    $Global:ProfileState.HasNetwork = $true 
                } else { 
                    $Global:ProfileState.HasNetwork = $false 
                }
            }
        } catch {
            $Global:ProfileState.HasNetwork = $false
            $Global:ProfileState.Notes += "Network probe failed: $($_.Exception.Message)"
        }
    }

    $Global:ProfileState.LastChecked = (Get-Date).ToString('o')
    return $Global:ProfileState
}

function Show-EnvironmentReport {
    <#
    .SYNOPSIS
        Displays a comprehensive environment report.
    .DESCRIPTION
        Shows platform, version, admin status, network, and missing commands.
    .PARAMETER VerboseReport
        Include additional notes and details.
    #>
    [CmdletBinding()]
    param([switch]$VerboseReport)

    if (-not $Global:ProfileState.LastChecked) {
        Test-Environment | Out-Null
    }

    Write-Host "`n=== Environment Report ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: " -NoNewline
    Write-Host $Global:ProfileState.PowerShellVersion -ForegroundColor Yellow

    Write-Host "Platform: " -NoNewline
    $plat = if ($Global:ProfileState.IsWindows) { 'Windows' } 
            elseif ($Global:ProfileState.IsLinux) { 'Linux' } 
            elseif ($Global:ProfileState.IsMacOS) { 'macOS' } 
            else { 'Unknown' }
    Write-Host $plat -ForegroundColor Yellow

    Write-Host "Is Admin: " -NoNewline
    Write-Host $Global:ProfileState.IsAdmin -ForegroundColor $(if ($Global:ProfileState.IsAdmin) { 'Green' } else { 'Yellow' })

    $netStatus = if ($null -eq $Global:ProfileState.HasNetwork) { 'Skipped' } else { $Global:ProfileState.HasNetwork }
    Write-Host "Has Network: " -NoNewline
    Write-Host $netStatus -ForegroundColor $(if ($netStatus -eq $true) { 'Green' } elseif ($netStatus -eq $false) { 'Red' } else { 'Gray' })

    if ($Global:ProfileState.MissingCommands.Count -gt 0) {
        Write-Host "`nMissing Commands:" -ForegroundColor Yellow
        Write-Host ($Global:ProfileState.MissingCommands -join ', ') -ForegroundColor DarkYellow
    }

    if ($VerboseReport -and $Global:ProfileState.Notes.Count -gt 0) {
        Write-Host "`nNotes:" -ForegroundColor Gray
        foreach ($n in $Global:ProfileState.Notes) {
            Write-Host "  - $n" -ForegroundColor DarkGray
        }
    }

    Write-Host "`nLast Checked: $($Global:ProfileState.LastChecked)" -ForegroundColor DarkGray
    Write-Host ""
}

# Initialize environment on load
try {
    Test-Environment -SkipNetworkCheck | Out-Null
    Write-ProfileLog "Environment validated successfully" -Level DEBUG -Component "Environment"
} catch {
    Write-ProfileLog "Environment validation error: $_" -Level WARN -Component "Environment"
}

#endregion ENVIRONMENT VALIDATION AND UTILITY FUNCTIONS


#region 5 - PSREADLINE CONFIGURATION
#==============================================================================
<#
.SYNOPSIS
    PSReadLine configuration with predictive IntelliSense
.DESCRIPTION
    Configures PSReadLine for enhanced command-line editing with history-based
    predictions, syntax coloring, and customizable key bindings.
    Reference: https://learn.microsoft.com/powershell/module/psreadline/
#>

function Initialize-PSReadLine {
    <#
    .SYNOPSIS
        Initializes and configures PSReadLine.
    .DESCRIPTION
        Sets up PSReadLine with optimal settings for PowerShell 7.5+.
    #>
    [CmdletBinding()]
    param()

    # Check if PSReadLine is available
    if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
        Write-ProfileLog "PSReadLine not available" -Level WARN -Component "PSReadLine"
        return $false
    }

    try {
        # Import PSReadLine
        Import-Module PSReadLine -Force -ErrorAction Stop

        $opts = $Global:ProfileConfig.PSReadLine

        # Basic options
        Set-PSReadLineOption -EditMode $opts.EditMode
        Set-PSReadLineOption -MaximumHistoryCount $opts.HistorySize
        Set-PSReadLineOption -HistorySavePath $opts.HistorySavePath
        Set-PSReadLineOption -BellStyle $opts.BellStyle

        # Prediction settings (PowerShell 7.2+)
        if ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
            try {
                Set-PSReadLineOption -PredictionSource $opts.PredictionSource -ErrorAction SilentlyContinue
            } catch {
                # Fallback to History only
                Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
            }
        } else {
            Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        }

        Set-PSReadLineOption -PredictionViewStyle $opts.PredictionViewStyle -ErrorAction SilentlyContinue
        Set-PSReadLineOption -HistoryNoDuplicates:$opts.HistoryNoDuplicates -ErrorAction SilentlyContinue
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd:$opts.HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
        Set-PSReadLineOption -ShowToolTips:$opts.ShowToolTips -ErrorAction SilentlyContinue

        # Colors
        if ($opts.Colors) {
            Set-PSReadLineOption -Colors $opts.Colors -ErrorAction SilentlyContinue
        }

        # Key bindings
        foreach ($kb in $opts.KeyBindings.GetEnumerator()) {
            try {
                Set-PSReadLineKeyHandler -Key $kb.Key -Function $kb.Value -ErrorAction SilentlyContinue
            } catch {}
        }

        # Maximum kill ring count
        Set-PSReadLineOption -MaximumKillRingCount $opts.MaximumKillRingCount -ErrorAction SilentlyContinue

        Write-ProfileLog "PSReadLine configured successfully" -Level INFO -Component "PSReadLine"
        return $true

    } catch {
        Write-ProfileLog "PSReadLine configuration failed: $_" -Level WARN -Component "PSReadLine"
        return $false
    }
}

function Show-PSReadLineConfig {
    <#
    .SYNOPSIS
        Displays current PSReadLine configuration.
    .DESCRIPTION
        Shows all current PSReadLine settings.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command Get-PSReadLineOption -ErrorAction SilentlyContinue)) {
        Write-Host "PSReadLine not available" -ForegroundColor Yellow
        return
    }

    try {
        Get-PSReadLineOption | Format-List
    } catch {
        Write-ProfileLog "Show-PSReadLineConfig failed: $_" -Level DEBUG
    }
}

# Initialize PSReadLine for interactive sessions
if (Test-ProfileInteractive) {
    Initialize-PSReadLine | Out-Null
}

#endregion PSREADLINE CONFIGURATION

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
            $mods = Get-InstalledModule -ErrorAction SilentlyContinue
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
            $mods = Get-Module -ListAvailable -ErrorAction SilentlyContinue | Group-Object Name | ForEach-Object { $_.Group | Sort-Object Version -Descending | Select-Object -First 1 }
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
    $mod = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
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

function Ensure-Module {
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

        if ($InstallIfMissing -and (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
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
                    if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
                        Import-Module $mod -ErrorAction Stop -Global
                        $result[$mod] = 'Imported'
                    } else {
                        $result[$mod] = 'NotFound'
                    }
                } catch {
                    $result[$mod] = "Failed: $_"
                }
            }
            return $result
        }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList (, $Modules) -ErrorAction SilentlyContinue
        if ($job) {
            $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
            if ($completed) {
                $res = Receive-Job -Job $job -ErrorAction SilentlyContinue
                foreach ($k in $res.Keys) { $status[$k] = $res[$k] }
            } else {
                foreach ($m in $Modules) { 
                    if ($status[$m] -eq 'Pending') { $status[$m] = 'Timeout' } 
                }
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    } else {
        foreach ($m in $Modules) {
            try {
                Import-Module $m -ErrorAction Stop -Global
                $status[$m] = 'Imported'
            } catch {
                $status[$m] = "Failed: $_"
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

# Initialize module cache on load
Update-InstalledModulesCache | Out-Null

# Start deferred loader for interactive sessions
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.DeferredLoader.Modules.Count -gt 0) {
    Start-DeferredModuleLoader -UseJobs:$Global:ProfileConfig.DeferredLoader.UseJobs | Out-Null
}

#endregion MODULE MANAGEMENT SYSTEM


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
        and system configuration.
    .EXAMPLE
        Get-SystemInfo | Format-List
    #>
    [CmdletBinding()]
    param()

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
        and usage percentages.
    #>
    [CmdletBinding()]
    param()

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
    #>
    [CmdletBinding()]
    param()

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
    #>
    [CmdletBinding()]
    param()

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
    #>
    [CmdletBinding()]
    param()

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
    #>
    [CmdletBinding()]
    param()

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
    .PARAMETER Quick
        Return quick summary only.
    #>
    [CmdletBinding()]
    param([switch]$Quick)

    try {
        $health = [ordered]@{
            Timestamp = Get-Date
            Disk      = Get-DiskInfo
            Memory    = Get-MemoryInfo
            CPU       = Get-CPUInfo | Select-Object Name, PercentUsed
        }

        if (-not $Quick) {
            # Add performance counters
            try {
                $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
                $health.CPUPercent = [math]::Round($cpuCounter.CounterSamples.CookedValue, 2)
            } catch {
                $health.CPUPercent = $null
            }
        }

        return [PSCustomObject]$health
    } catch {
        Write-ProfileLog "Get-SystemHealth failed: $_" -Level WARN -Component "System"
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

#region 8 - PERFORMANCE MONITORING AND BENCHMARKING
#==============================================================================
<#
.SYNOPSIS
    Performance monitoring and benchmarking functions
.DESCRIPTION
    Provides functions for monitoring system performance, capturing metrics,
    and running benchmarks.
#>

function Get-PerfSnapshot {
    <#
    .SYNOPSIS
        Captures a performance snapshot.
    .DESCRIPTION
        Returns key performance counters for CPU, memory, and disk.
    .PARAMETER SampleSeconds
        Sample interval in seconds (default: 1).
    #>
    [CmdletBinding()]
    param([int]$SampleSeconds = 1)

    $ud = $Global:ProfileConfig.UtilityDefaults
    if ($SampleSeconds -le 0 -and $ud.PerfSnapshotSampleSeconds -gt 0) {
        $SampleSeconds = [int]$ud.PerfSnapshotSampleSeconds
    } elseif ($SampleSeconds -le 0) {
        $SampleSeconds = 1
    }

    $data = [ordered]@{ 
        Timestamp = (Get-Date).ToString('o') 
    }

    try {
        $counters = @(
            '\Processor(_Total)\% Processor Time',
            '\Memory\Available MBytes',
            '\PhysicalDisk(_Total)\Avg. Disk Queue Length',
            '\PhysicalDisk(_Total)\% Disk Time'
        )

        $ctr = Get-Counter -Counter $counters -SampleInterval $SampleSeconds -MaxSamples 1 -ErrorAction SilentlyContinue

        if ($ctr -and $ctr.CounterSamples) {
            foreach ($s in $ctr.CounterSamples) {
                $name = ($s.Path -split '\')[-1]
                $data[$name] = [math]::Round($s.CookedValue, 2)
            }
        }
    } catch {
        Write-ProfileLog "Get-PerfSnapshot failed: $_" -Level DEBUG -Component "Performance"
    }

    return [PSCustomObject]$data
}

function Get-TopProcesses {
    <#
    .SYNOPSIS
        Returns top processes by resource usage.
    .DESCRIPTION
        Returns the top processes sorted by CPU, Memory, or IO.
    .PARAMETER By
        Sort by: CPU, Memory, or IO.
    .PARAMETER Top
        Number of processes to return.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('CPU', 'Memory', 'IO')]
        [string]$By = 'Memory',
        [int]$Top = 0
    )

    $ud = $Global:ProfileConfig.UtilityDefaults
    if ($Top -le 0) { $Top = $ud.TopProcessesTop }
    if ($Top -le 0) { $Top = 15 }

    try {
        $procs = Get-Process -ErrorAction SilentlyContinue

        switch ($By) {
            'CPU' { 
                return $procs | Sort-Object CPU -Descending | 
                    Select-Object -First $Top Name, Id, CPU, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) }}
            }
            'IO' { 
                return $procs | Sort-Object IOReadBytes -Descending | 
                    Select-Object -First $Top Name, Id, @{N = 'ReadMB'; E = { [math]::Round($_.IOReadBytes / 1MB, 2) }}, 
                        @{N = 'WriteMB'; E = { [math]::Round($_.IOWriteBytes / 1MB, 2) }}
            }
            default { 
                return $procs | Sort-Object WorkingSet64 -Descending | 
                    Select-Object -First $Top Name, Id, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) }}, 
                        @{N = 'CPUTime'; E = { $_.CPU }}
            }
        }
    } catch {
        Write-ProfileLog "Get-TopProcesses failed: $_" -Level DEBUG -Component "Performance"
        return @()
    }
}

function Measure-Benchmark {
    <#
    .SYNOPSIS
        Runs a benchmark and measures execution time.
    .DESCRIPTION
        Executes a script block multiple times and returns statistics.
    .PARAMETER ScriptBlock
        The code to benchmark.
    .PARAMETER Iterations
        Number of iterations (default: 10).
    .PARAMETER Warmup
        Number of warmup runs before measurement.
    .EXAMPLE
        Measure-Benchmark -ScriptBlock { Get-Process } -Iterations 100
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [int]$Iterations = 10,
        [int]$Warmup = 2
    )

    try {
        # Warmup runs
        for ($i = 0; $i -lt $Warmup; $i++) {
            $null = & $ScriptBlock
        }

        # Measure runs
        $times = @()
        for ($i = 0; $i -lt $Iterations; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = & $ScriptBlock
            $sw.Stop()
            $times += $sw.ElapsedMilliseconds
        }

        $sorted = $times | Sort-Object

        [PSCustomObject]@{
            Iterations  = $Iterations
            MinMs       = $sorted | Select-Object -First 1
            MaxMs       = $sorted | Select-Object -Last 1
            AvgMs       = [math]::Round(($times | Measure-Object -Average).Average, 2)
            MedianMs    = if ($sorted.Count % 2 -eq 0) { 
                [math]::Round(($sorted[$sorted.Count / 2 - 1] + $sorted[$sorted.Count / 2]) / 2, 2)
            } else { 
                $sorted[[math]::Floor($sorted.Count / 2)]
            }
            TotalMs     = ($times | Measure-Object -Sum).Sum
        }
    } catch {
        Write-ProfileLog "Measure-Benchmark failed: $_" -Level WARN -Component "Performance"
        return $null
    }
}

#endregion PERFORMANCE MONITORING AND BENCHMARKING


#region 9 - NETWORK MANAGEMENT AND DNS FUNCTIONS
#==============================================================================
<#
.SYNOPSIS
    Network management, DNS configuration, and diagnostic functions
.DESCRIPTION
    Provides comprehensive network management including DNS configuration,
    adapter management, and network diagnostics.
#>

function Test-TcpPort {
    <#
    .SYNOPSIS
        Tests TCP port connectivity.
    .DESCRIPTION
        Tests if a TCP port is open on a remote host.
    .PARAMETER HostName
        Target hostname or IP address.
    .PARAMETER Port
        TCP port number.
    .PARAMETER TimeoutMs
        Timeout in milliseconds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostName,
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutMs = 1200
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if (-not $ok) { 
            try { $client.Close() } catch {}
            return $false 
        }

        try { 
            $client.EndConnect($async) 
        } catch { 
            return $false 
        } finally { 
            try { $client.Close() } catch {} 
        }

        return $true
    } catch {
        return $false
    }
}

function Test-IpAddress {
    <#
    .SYNOPSIS
        Validates an IP address string.
    .DESCRIPTION
        Returns $true if the string is a valid IPv4 or IPv6 address.
    .PARAMETER Address
        IP address string to validate.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Address)

    try {
        $addr = $null
        return [System.Net.IPAddress]::TryParse($Address, [ref]$addr)
    } catch { 
        return $false 
    }
}

function Get-LocalIP {
    <#
    .SYNOPSIS
        Retrieves local IP addresses.
    .DESCRIPTION
        Returns all local IPv4 addresses.
    #>
    [CmdletBinding()]
    param()

    try {
        $ips = @()
        if ($Global:IsWindows) {
            $adapters = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                Where-Object { $_.IPAddress -and $_.PrefixOrigin -ne 'WellKnown' }
            foreach ($a in $adapters) { $ips += $a.IPAddress }
        } else {
            $raw = (ip -4 addr 2>$null)
            if ($raw) {
                $ips += ($raw | Select-String -Pattern '(?<=inet\s)\d+\.\d+\.\d+\.\d+' -AllMatches | 
                    ForEach-Object { $_.Matches.Value })
            }
        }
        return $ips | Select-Object -Unique
    } catch {
        Write-ProfileLog "Get-LocalIP failed: $_" -Level DEBUG -Component "Network"
        return @()
    }
}

function Get-PublicIP {
    <#
    .SYNOPSIS
        Retrieves public IP address.
    .DESCRIPTION
        Queries external services to determine public IP address.
    .PARAMETER TimeoutSeconds
        Request timeout.
    #>
    [CmdletBinding()]
    param([int]$TimeoutSeconds = 5)

    try {
        $providers = @(
            'https://api.ipify.org',
            'https://ifconfig.me/ip',
            'https://ipinfo.io/ip'
        )

        foreach ($p in $providers) {
            try {
                $resp = Invoke-RestMethod -Uri $p -Method Get -TimeoutSec $TimeoutSeconds -ErrorAction Stop
                if ($resp) { return $resp.Trim() }
            } catch { continue }
        }
        return $null
    } catch {
        Write-ProfileLog "Get-PublicIP failed: $_" -Level DEBUG -Component "Network"
        return $null
    }
}

function Get-NetworkAdapters {
    <#
    .SYNOPSIS
        Retrieves network adapter information.
    .DESCRIPTION
        Returns network adapters with optional filtering.
    .PARAMETER UpOnly
        Only return adapters that are up.
    .PARAMETER PhysicalOnly
        Only return physical adapters.
    #>
    [CmdletBinding()]
    param(
        [switch]$UpOnly,
        [switch]$PhysicalOnly
    )

    if (-not $Global:IsWindows) { return @() }

    try {
        if (-not (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue)) { return @() }

        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        if ($UpOnly) { $adapters = $adapters | Where-Object Status -eq 'Up' }
        if ($PhysicalOnly) { $adapters = $adapters | Where-Object { $_.HardwareInterface -eq $true } }

        return $adapters | Select-Object Name, InterfaceAlias, Status, LinkSpeed, MacAddress, HardwareInterface
    } catch {
        Write-ProfileLog "Get-NetworkAdapters failed: $_" -Level DEBUG -Component "Network"
        return @()
    }
}

function Get-DnsConfig {
    <#
    .SYNOPSIS
        Retrieves DNS configuration.
    .DESCRIPTION
        Returns DNS server addresses for network interfaces.
    .PARAMETER InterfaceAlias
        Optional interface alias to filter.
    #>
    [CmdletBinding()]
    param([string]$InterfaceAlias)

    if (-not $Global:IsWindows) { return $null }

    try {
        if (-not (Get-Command Get-DnsClientServerAddress -ErrorAction SilentlyContinue)) { 
            return $null 
        }

        $dnsArgs = @{ AddressFamily = 'IPv4'; ErrorAction = 'SilentlyContinue' }
        if ($InterfaceAlias) { $dnsArgs.InterfaceAlias = $InterfaceAlias }

        Get-DnsClientServerAddress @dnsArgs | Select-Object InterfaceAlias, ServerAddresses
    } catch {
        Write-ProfileLog "Get-DnsConfig failed: $_" -Level DEBUG -Component "Network"
        return $null
    }
}

function Set-DnsServers {
    <#
    .SYNOPSIS
        Configures DNS servers for an interface.
    .DESCRIPTION
        Sets DNS server addresses for a network interface.
    .PARAMETER InterfaceAlias
        Network interface alias.
    .PARAMETER Servers
        Array of DNS server IP addresses.
    .PARAMETER Dhcp
        Use DHCP for DNS.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$InterfaceAlias,
        [string[]]$Servers,
        [switch]$Dhcp
    )

    if (-not $Global:IsWindows) { 
        Write-ProfileLog "Set-DnsServers is Windows-only" -Level WARN -Component "Network"
        return $false 
    }

    if (-not (Test-Admin)) { 
        Write-Host "Set-DnsServers requires administrator privileges." -ForegroundColor Yellow
        return $false 
    }

    # Validate IP addresses
    if (-not $Dhcp -and $Servers) {
        foreach ($s in $Servers) {
            if (-not (Test-IpAddress -Address $s)) {
                Write-Host "Invalid IP address: $s" -ForegroundColor Yellow
                return $false
            }
        }
    }

    try {
        if ($Dhcp) {
            if ($PSCmdlet.ShouldProcess($InterfaceAlias, 'Set DNS to DHCP')) {
                Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction Stop
                Write-ProfileLog "DNS set to DHCP for $InterfaceAlias" -Level INFO -Component "Network"
                return $true
            }
        } else {
            if ($PSCmdlet.ShouldProcess($InterfaceAlias, "Set DNS servers: $($Servers -join ', ')")) {
                Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $Servers -ErrorAction Stop
                Write-ProfileLog "DNS servers set for $InterfaceAlias" -Level INFO -Component "Network"
                return $true
            }
        }
        return $false
    } catch {
        Write-ProfileLog "Set-DnsServers failed: $_" -Level WARN -Component "Network"
        return $false
    }
}

function Restart-NetworkAdapter {
    <#
    .SYNOPSIS
        Restarts network adapters.
    .DESCRIPTION
        Disables and re-enables network adapters.
    .PARAMETER InterfaceAlias
        Specific adapter to restart.
    .PARAMETER UpOnly
        Only restart adapters that are up.
    .PARAMETER PhysicalOnly
        Only restart physical adapters.
    .PARAMETER DelaySeconds
        Delay between disable and enable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [string]$InterfaceAlias,
        [switch]$UpOnly,
        [switch]$PhysicalOnly,
        [int]$DelaySeconds = 2
    )

    if (-not $Global:IsWindows) { 
        Write-ProfileLog "Restart-NetworkAdapter is Windows-only" -Level WARN -Component "Network"
        return $false 
    }

    if (-not (Test-Admin)) { 
        Write-Host "Restart-NetworkAdapter requires administrator privileges." -ForegroundColor Yellow
        return $false 
    }

    $targets = @()
    if ($InterfaceAlias) {
        $targets = @($InterfaceAlias)
    } else {
        $targets = Get-NetworkAdapters -UpOnly:$UpOnly -PhysicalOnly:$PhysicalOnly | 
            Select-Object -ExpandProperty InterfaceAlias
    }

    if (-not $targets) { 
        Write-Host "No adapters matched." -ForegroundColor Yellow
        return $false 
    }

    $ok = $true
    foreach ($a in $targets) {
        try {
            if ($PSCmdlet.ShouldProcess($a, 'Restart network adapter')) {
                Disable-NetAdapter -Name $a -Confirm:$false -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds $DelaySeconds
                Enable-NetAdapter -Name $a -Confirm:$false -ErrorAction Stop | Out-Null
                Write-ProfileLog "Adapter restarted: $a" -Level INFO -Component "Network"
            }
        } catch {
            $ok = $false
            Write-ProfileLog "Failed to restart adapter $a : $_" -Level WARN -Component "Network"
        }
    }
    return $ok
}

function Clear-DnsCache {
    <#
    .SYNOPSIS
        Clears DNS cache.
    .DESCRIPTION
        Flushes the DNS client cache.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not $Global:IsWindows) { return $false }

    try {
        if ($PSCmdlet.ShouldProcess('DNS cache', 'Clear')) {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns | Out-Null
            Write-ProfileLog "DNS cache cleared" -Level INFO -Component "Network"
            return $true
        }
        return $false
    } catch {
        Write-ProfileLog "Clear-DnsCache failed: $_" -Level DEBUG -Component "Network"
        return $false
    }
}

function Get-NetworkSnapshot {
    <#
    .SYNOPSIS
        Captures a network configuration snapshot.
    .DESCRIPTION
        Returns comprehensive network configuration information.
    #>
    [CmdletBinding()]
    param()

    $snap = [ordered]@{
        Timestamp   = (Get-Date).ToString('o')
        LocalIP     = @()
        PublicIP    = $null
        DnsServers  = @()
        DefaultRoutes = @()
        NetAdapters = @()
    }

    try { $snap.LocalIP = Get-LocalIP } catch {}
    try { $snap.PublicIP = Get-PublicIP } catch {}

    if ($Global:IsWindows) {
        try {
            $snap.DnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                Select-Object InterfaceAlias, ServerAddresses
        } catch {}

        try {
            $snap.DefaultRoutes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | 
                Select-Object InterfaceAlias, NextHop, RouteMetric, ifIndex
        } catch {}

        try {
            $snap.NetAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | 
                Select-Object Name, Status, LinkSpeed, MacAddress
        } catch {}
    }

    return [PSCustomObject]$snap
}

function Test-Internet {
    <#
    .SYNOPSIS
        Tests internet connectivity.
    .DESCRIPTION
        Performs DNS and TCP connectivity tests.
    .PARAMETER DnsName
        DNS name to resolve.
    .PARAMETER TcpHost
        TCP host to test.
    .PARAMETER TcpPort
        TCP port to test.
    .PARAMETER TimeoutMs
        Timeout in milliseconds.
    #>
    [CmdletBinding()]
    param(
        [string]$DnsName = 'www.microsoft.com',
        [string]$TcpHost = '1.1.1.1',
        [int]$TcpPort = 53,
        [int]$TimeoutMs = 1500
    )

    $result = [ordered]@{
        Dns       = $false
        Tcp       = $false
        Timestamp = (Get-Date).ToString('o')
    }

    # DNS test
    try {
        if ($Global:IsWindows -and (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue)) {
            $dns = Resolve-DnsName -Name $DnsName -ErrorAction SilentlyContinue -TimeoutSeconds ([math]::Ceiling($TimeoutMs / 1000))
            $result.Dns = $null -ne $dns
        } else {
            # Fallback TCP test
            $result.Dns = Test-TcpPort -HostName $TcpHost -Port $TcpPort -TimeoutMs $TimeoutMs
        }
    } catch {}

    # TCP test
    try {
        $result.Tcp = Test-TcpPort -HostName $TcpHost -Port $TcpPort -TimeoutMs $TimeoutMs
    } catch {}

    return [PSCustomObject]$result
}

#endregion NETWORK MANAGEMENT AND DNS FUNCTIONS


#region 10 - DNS PROFILES AND QUICK SWITCHING
#==============================================================================
<#
.SYNOPSIS
    DNS profile management and quick switching
.DESCRIPTION
    Provides predefined DNS profiles and quick switching between DNS servers.
#>

# Initialize DNS profiles
function Initialize-NetworkProfiles {
    <#
    .SYNOPSIS
        Initializes predefined DNS profiles.
    .DESCRIPTION
        Creates default DNS profiles for popular DNS services.
    #>
    [CmdletBinding()]
    param()

    if (-not $Global:ProfileConfig.Contains('NetworkProfiles')) {
        $Global:ProfileConfig.NetworkProfiles = [ordered]@{}
    }

    $profiles = @{
        Cloudflare = @{ DnsServers = @('1.1.1.1', '1.0.0.1'); Dhcp = $false; Description = 'Cloudflare DNS' }
        Google     = @{ DnsServers = @('8.8.8.8', '8.8.4.4'); Dhcp = $false; Description = 'Google Public DNS' }
        Quad9      = @{ DnsServers = @('9.9.9.9', '149.112.112.112'); Dhcp = $false; Description = 'Quad9 Secure DNS' }
        OpenDNS    = @{ DnsServers = @('208.67.222.222', '208.67.220.220'); Dhcp = $false; Description = 'OpenDNS' }
        AdGuard    = @{ DnsServers = @('94.140.14.14', '94.140.15.15'); Dhcp = $false; Description = 'AdGuard DNS' }
        DHCP       = @{ DnsServers = @(); Dhcp = $true; Description = 'DHCP Auto' }
    }

    foreach ($k in $profiles.Keys) {
        if (-not $Global:ProfileConfig.NetworkProfiles.Contains($k)) {
            $Global:ProfileConfig.NetworkProfiles[$k] = $profiles[$k]
        }
    }

    return $Global:ProfileConfig.NetworkProfiles
}

function Set-DnsProfile {
    <#
    .SYNOPSIS
        Applies a DNS profile to network adapters.
    .DESCRIPTION
        Sets DNS servers using a predefined profile.
    .PARAMETER Name
        Profile name (Cloudflare, Google, Quad9, DHCP, etc.).
    .PARAMETER InterfaceAlias
        Specific interface (default: all physical adapters).
    .PARAMETER RestartAdapter
        Restart adapters after change.
    .PARAMETER FlushDns
        Flush DNS cache after change.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$InterfaceAlias,
        [switch]$RestartAdapter,
        [switch]$FlushDns
    )

    if (-not $Global:IsWindows) { 
        Write-ProfileLog "Set-DnsProfile is Windows-only" -Level WARN -Component "Network"
        return $false 
    }

    if (-not (Test-Admin)) { 
        Write-Host "Set-DnsProfile requires administrator privileges." -ForegroundColor Yellow
        return $false 
    }

    Initialize-NetworkProfiles | Out-Null

    if (-not $Global:ProfileConfig.NetworkProfiles.Contains($Name)) {
        Write-Host "DNS profile not found: $Name" -ForegroundColor Yellow
        return $false
    }

    $dnsProfile = $Global:ProfileConfig.NetworkProfiles[$Name]

    $targets = @()
    if ($InterfaceAlias) {
        $targets = @($InterfaceAlias)
    } else {
        $targets = Get-NetworkAdapters -UpOnly -PhysicalOnly | Select-Object -ExpandProperty InterfaceAlias
    }

    if (-not $targets) { 
        Write-Host "No adapters matched." -ForegroundColor Yellow
        return $false 
    }

    $ok = $true
    foreach ($a in $targets) {
        if ($dnsProfile.Dhcp -eq $true) {
            $ok = (Set-DnsServers -InterfaceAlias $a -Dhcp) -and $ok
        } else {
            $ok = (Set-DnsServers -InterfaceAlias $a -Servers $dnsProfile.DnsServers) -and $ok
        }
    }

    if ($FlushDns) { Clear-DnsCache | Out-Null }
    if ($RestartAdapter) { Restart-NetworkAdapter -UpOnly -PhysicalOnly | Out-Null }

    if ($ok) {
        Write-ProfileLog "DNS profile '$Name' applied successfully" -Level INFO -Component "Network"
    }
    return $ok
}

function Use-BestDns {
    <#
    .SYNOPSIS
        Automatically selects and applies the best DNS server.
    .DESCRIPTION
        Tests multiple DNS candidates and applies the fastest responding one.
    .PARAMETER Candidates
        Array of DNS profile names to test.
    .PARAMETER InterfaceAlias
        Specific interface to configure.
    .PARAMETER RestartAdapter
        Restart adapters after change.
    .PARAMETER FlushDns
        Flush DNS cache after change.
    .PARAMETER TimeoutMs
        Test timeout in milliseconds.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [ValidateSet('Cloudflare', 'Google', 'Quad9', 'OpenDNS', 'AdGuard', 'DHCP')]
        [string[]]$Candidates = @('Cloudflare', 'Google', 'DHCP'),
        [string]$InterfaceAlias,
        [switch]$RestartAdapter,
        [switch]$FlushDns,
        [int]$TimeoutMs = 1200
    )

    if (-not $Global:IsWindows) { 
        Write-ProfileLog "Use-BestDns is Windows-only" -Level WARN -Component "Network"
        return $false 
    }

    Initialize-NetworkProfiles | Out-Null

    $tests = @()
    foreach ($name in $Candidates) {
        switch ($name) {
            'Cloudflare' { $tests += [pscustomobject]@{ Name = $name; Host = '1.1.1.1'; Port = 53 } }
            'Google'     { $tests += [pscustomobject]@{ Name = $name; Host = '8.8.8.8'; Port = 53 } }
            'Quad9'      { $tests += [pscustomobject]@{ Name = $name; Host = '9.9.9.9'; Port = 53 } }
            'OpenDNS'    { $tests += [pscustomobject]@{ Name = $name; Host = '208.67.222.222'; Port = 53 } }
            'AdGuard'    { $tests += [pscustomobject]@{ Name = $name; Host = '94.140.14.14'; Port = 53 } }
            'DHCP'       { $tests += [pscustomobject]@{ Name = $name; Host = 'www.microsoft.com'; Port = 443 } }
        }
    }

    $ranked = @()
    foreach ($t in $tests) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = Test-TcpPort -HostName $t.Host -Port $t.Port -TimeoutMs $TimeoutMs
        $sw.Stop()
        $ranked += [pscustomobject]@{ 
            Name = $t.Name; 
            Reachable = $ok; 
            LatencyMs = if ($ok) { [int]$sw.ElapsedMilliseconds } else { 999999 }
        }
    }

    $best = $ranked | Where-Object { $_.Reachable } | Sort-Object LatencyMs | Select-Object -First 1

    if (-not $best) {
        Write-Host "No DNS candidate reachable within timeout." -ForegroundColor Yellow
        return $false
    }

    Write-Host "Best DNS: $($best.Name) ($($best.LatencyMs) ms)" -ForegroundColor Cyan
    return Set-DnsProfile -Name $best.Name -InterfaceAlias $InterfaceAlias -RestartAdapter:$RestartAdapter -FlushDns:$FlushDns
}

# Quick DNS switching functions
function Use-CloudflareDns { Set-DnsProfile -Name 'Cloudflare' -FlushDns }
function Use-GoogleDns { Set-DnsProfile -Name 'Google' -FlushDns }
function Use-Quad9Dns { Set-DnsProfile -Name 'Quad9' -FlushDns }
function Use-OpenDns { Set-DnsProfile -Name 'OpenDNS' -FlushDns }
function Use-AdGuardDns { Set-DnsProfile -Name 'AdGuard' -FlushDns }
function Use-DhcpDns { Set-DnsProfile -Name 'DHCP' -FlushDns }

#endregion DNS PROFILES AND QUICK SWITCHING

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
    .PARAMETER WhatIf
        Show what would be done without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([switch]$WhatIf)

    if (-not (Test-Admin)) {
        Write-ProfileLog "Optimize-System requires admin privileges" -Level WARN -Component "Optimization"
        Write-Host "This function requires administrator privileges." -ForegroundColor Yellow
        return $false
    }

    if ($WhatIf) {
        Write-Host "WhatIf: Would clean temp files and optimize system" -ForegroundColor Cyan
        return $true
    }

    try {
        # Clean user temp files older than 7 days
        $temp = [IO.Path]::GetTempPath()
        $cutoff = (Get-Date).AddDays(-7)

        $files = Get-ChildItem -Path $temp -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { $_.LastWriteTime -lt $cutoff }

        $count = 0
        foreach ($f in $files) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                $count++
            } catch {}
        }

        Write-ProfileLog "Cleaned $count temp files" -Level INFO -Component "Optimization"

        # Clear Recycle Bin (optional)
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-ProfileLog "Recycle bin cleared" -Level INFO -Component "Optimization"
        } catch {}

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


#region 12 - SELF-DIAGNOSTICS AND TROUBLESHOOTING
#==============================================================================
<#
.SYNOPSIS
    Self-diagnostics and troubleshooting functions
.DESCRIPTION
    Provides comprehensive diagnostics for the PowerShell profile and system.
#>

function Test-ProfileHealth {
    <#
    .SYNOPSIS
        Tests profile health and reports issues.
    .DESCRIPTION
        Runs diagnostics on profile configuration, modules, and environment.
    .PARAMETER Repair
        Attempt to repair issues automatically.
    #>
    [CmdletBinding()]
    param([switch]$Repair)

    $report = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
        Tests = @()
        Issues = @()
        Recommendations = @()
    }

    # Test 1: PowerShell version
    $verOk = $PSVersionTable.PSVersion.Major -ge 7
    $report.Tests += [pscustomobject]@{ Test = 'PowerShell Version'; Status = if ($verOk) { 'PASS' } else { 'FAIL' }; Details = $PSVersionTable.PSVersion }
    if (-not $verOk) { $report.Issues += 'PowerShell version is below 7.0' }

    # Test 2: Execution policy
    $execPol = Get-ExecutionPolicy
    $execOk = $execPol -in @('RemoteSigned', 'Unrestricted', 'Bypass')
    $report.Tests += [pscustomobject]@{ Test = 'Execution Policy'; Status = if ($execOk) { 'PASS' } else { 'WARN' }; Details = $execPol }
    if (-not $execOk) { $report.Recommendations += "Consider: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" }

    # Test 3: Required directories
    $paths = @($Global:ProfileConfig.LogPath, $Global:ProfileConfig.CachePath)
    foreach ($p in $paths) {
        $pathOk = Test-Path $p
        $report.Tests += [pscustomobject]@{ Test = "Path: $(Split-Path $p -Leaf)"; Status = if ($pathOk) { 'PASS' } else { 'FAIL' }; Details = $p }
        if (-not $pathOk -and $Repair) {
            try { New-Item -Path $p -ItemType Directory -Force | Out-Null } catch {}
        }
    }

    # Test 4: Module availability
    $essentialModules = @('PSReadLine')
    foreach ($m in $essentialModules) {
        $modOk = Test-ModuleAvailable -Name $m
        $report.Tests += [pscustomobject]@{ Test = "Module: $m"; Status = if ($modOk) { 'PASS' } else { 'WARN' }; Details = if ($modOk) { 'Available' } else { 'Not installed' } }
    }

    # Test 5: PSReadLine configuration
    $psrlOk = (Get-Command Get-PSReadLineOption -ErrorAction SilentlyContinue) -ne $null
    $report.Tests += [pscustomobject]@{ Test = 'PSReadLine Config'; Status = if ($psrlOk) { 'PASS' } else { 'WARN' }; Details = if ($psrlOk) { 'Configured' } else { 'Not configured' } }

    # Test 6: Deferred modules
    if ($Global:DeferredModulesStatus.Completed) {
        $report.Tests += [pscustomobject]@{ Test = 'Deferred Modules'; Status = 'PASS'; Details = 'Completed' }
    } else {
        $report.Tests += [pscustomobject]@{ Test = 'Deferred Modules'; Status = 'PENDING'; Details = 'Not completed' }
    }

    return [PSCustomObject]$report
}

function Show-ProfileDiagnostics {
    <#
    .SYNOPSIS
        Displays profile diagnostics report.
    .DESCRIPTION
        Shows comprehensive profile diagnostics in a formatted display.
    .PARAMETER Detailed
        Show detailed information.
    #>
    [CmdletBinding()]
    param([switch]$Detailed)

    $report = Test-ProfileHealth

    Write-Host "`n=== Profile Diagnostics ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $($report.Timestamp)" -ForegroundColor DarkGray

    Write-Host "`nTest Results:" -ForegroundColor Yellow
    foreach ($t in $report.Tests) {
        $color = switch ($t.Status) {
            'PASS' { 'Green' }
            'FAIL' { 'Red' }
            'WARN' { 'Yellow' }
            default { 'Gray' }
        }
        Write-Host "  [$($t.Status)] $($t.Test)" -NoNewline
        Write-Host " - $($t.Details)" -ForegroundColor DarkGray
    }

    if ($report.Issues.Count -gt 0) {
        Write-Host "`nIssues Found:" -ForegroundColor Red
        foreach ($i in $report.Issues) {
            Write-Host "  - $i" -ForegroundColor Red
        }
    }

    if ($report.Recommendations.Count -gt 0) {
        Write-Host "`nRecommendations:" -ForegroundColor Cyan
        foreach ($r in $report.Recommendations) {
            Write-Host "  - $r" -ForegroundColor Yellow
        }
    }

    if ($Detailed) {
        Write-Host "`nProfile State:" -ForegroundColor Yellow
        $Global:ProfileState | Format-List | Out-String | Write-Host -ForegroundColor DarkGray

        Write-Host "`nProfile Stats:" -ForegroundColor Yellow
        $Global:ProfileStats | Format-List | Out-String | Write-Host -ForegroundColor DarkGray
    }

    Write-Host ""
}

function Repair-Profile {
    <#
    .SYNOPSIS
        Repairs common profile issues.
    .DESCRIPTION
        Attempts to repair profile configuration and recreate required directories.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess('Profile', 'Repair')) {
        Write-Host "Repairing profile..." -ForegroundColor Cyan

        # Recreate directories
        $paths = @($Global:ProfileConfig.LogPath, $Global:ProfileConfig.TranscriptPath, 
                   $Global:ProfileConfig.CachePath, $Global:ProfileConfig.ThemesPath)
        foreach ($p in $paths) {
            if (-not (Test-Path $p)) {
                try {
                    New-Item -Path $p -ItemType Directory -Force | Out-Null
                    Write-Host "  Created: $p" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed: $p" -ForegroundColor Red
                }
            }
        }

        # Refresh module cache
        Update-InstalledModulesCache -Force | Out-Null
        Write-Host "  Module cache refreshed" -ForegroundColor Green

        # Reinitialize PSReadLine
        Initialize-PSReadLine | Out-Null
        Write-Host "  PSReadLine reinitialized" -ForegroundColor Green

        Write-Host "Profile repair completed." -ForegroundColor Cyan
    }
}

function Reset-ProfileToDefaults {
    <#
    .SYNOPSIS
        Resets profile to default state.
    .DESCRIPTION
        Clears caches and resets configuration to defaults.
    .PARAMETER Confirm
        Confirm the reset action.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([switch]$Confirm)

    if ($PSCmdlet.ShouldProcess('Profile configuration', 'Reset to defaults')) {
        # Clear caches
        try {
            Remove-Item -Path (Join-Path $Global:ProfileConfig.CachePath '*') -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cache cleared." -ForegroundColor Green
        } catch {}

        # Clear logs (keep current month)
        try {
            Get-ChildItem -Path $Global:ProfileConfig.LogPath -Filter "profile_*.log" | 
                Where-Object { $_.Name -ne "profile_$(Get-Date -Format 'yyyyMM').log" } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "Old logs cleared." -ForegroundColor Green
        } catch {}

        # Reset deferred modules
        $Global:DeferredModulesStatus = [ordered]@{
            Started = $false
            Completed = $false
            StartedAt = $null
            CompletedAt = $null
            Modules = @{}
            Jobs = @{}
        }

        Write-Host "Profile reset completed. Restart PowerShell to reload." -ForegroundColor Cyan
    }
}

#endregion SELF-DIAGNOSTICS AND TROUBLESHOOTING

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
    .PARAMETER Filter
        Filter by status (Running, Stopped, All).
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Running', 'Stopped', 'All')]
        [string]$Filter = 'Running'
    )

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
        if ($PSCmdlet.ShouldProcess($Name, 'Restart service')) {
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
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }

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
    .PARAMETER Name
        Process name to filter.
    #>
    [CmdletBinding()]
    param([string]$Name)

    try {
        $procs = Get-Process -ErrorAction SilentlyContinue
        if ($Name) { $procs = $procs | Where-Object ProcessName -like "*$Name*" }

        $tree = @()
        foreach ($p in $procs) {
            $parent = $null
            try {
                $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).ParentProcessId
            } catch {}

            $tree += [PSCustomObject]@{
                Id       = $p.Id
                Name     = $p.ProcessName
                ParentId = $parent
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
        if (-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)) {
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
    .PARAMETER WhatIf
        Show what would be updated.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([switch]$WhatIf)

    try {
        if (-not (Get-Command Update-Module -ErrorAction SilentlyContinue)) {
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
                    if ($WhatIf) {
                        Write-Host "WhatIf: Would update $($mod.Name) from $($mod.Version) to $($available.Version)" -ForegroundColor Cyan
                    } elseif ($PSCmdlet.ShouldProcess("$($mod.Name) to v$($available.Version)", 'Update module')) {
                        Update-Module -Name $mod.Name -Force -ErrorAction SilentlyContinue
                        Write-ProfileLog "Module '$($mod.Name)' updated to v$($available.Version)" -Level INFO -Component "Updates"
                        $updated++
                    }
                }
            } catch {}
        }

        Write-Host "Modules updated: $updated" -ForegroundColor Green
        return $true
    } catch {
        Write-ProfileLog "Update-ProfileModules failed: $_" -Level WARN -Component "Updates"
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
            } catch {}
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
    .PARAMETER WhatIf
        Show what would be removed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [int]$DaysOld = 7,
        [switch]$WhatIf
    )

    if (-not (Test-Admin)) {
        Write-Host "Some temp locations may require administrator privileges." -ForegroundColor Yellow
    }

    try {
        $tempPaths = @(
            [IO.Path]::GetTempPath()
            Join-Path $env:LOCALAPPDATA 'Temp'
            Join-Path $env:WINDIR 'Temp'
        )

        $cutoff = (Get-Date).AddDays(-$DaysOld)
        $removed = 0
        $freed = 0

        foreach ($p in $tempPaths) {
            if (Test-Path $p) {
                $files = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt $cutoff }

                foreach ($f in $files) {
                    if ($WhatIf) {
                        Write-Host "WhatIf: Would remove $($f.FullName)" -ForegroundColor Cyan
                    } elseif ($PSCmdlet.ShouldProcess($f.FullName, 'Remove temp file')) {
                        try {
                            $freed += $f.Length
                            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                            $removed++
                        } catch {}
                    }
                }
            }
        }

        if (-not $WhatIf) {
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


#region 17 - PROMPT CUSTOMIZATION AND SHELL ENHANCEMENTS
#==============================================================================
<#
.SYNOPSIS
    Prompt customization and shell enhancements
.DESCRIPTION
    Provides custom prompt functions and shell enhancements including
    oh-my-posh integration and terminal icons.
#>

function Get-CustomPrompt {
    <#
    .SYNOPSIS
        Returns a custom prompt string.
    .DESCRIPTION
        Generates a custom prompt with git status, admin indicator, and path.
    #>
    [CmdletBinding()]
    param()

    try {
        $isAdmin = Test-Admin
        $path = (Get-Location).Path
        $shortPath = if ($path -eq $env:USERPROFILE) { '~' } else { Split-Path $path -Leaf }

        # Git status (if available)
        $gitBranch = $null
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $gitBranch = git branch --show-current 2>$null
            } catch {}
        }

        # Build prompt
        $prompt = "`n"

        # Admin indicator
        if ($isAdmin) {
            $prompt += "[$([char]0x26A1)] "  # Lightning bolt
        }

        # Path
        $prompt += "$shortPath"

        # Git branch
        if ($gitBranch) {
            $prompt += " [$gitBranch]"
        }

        $prompt += "`nPS> "

        return $prompt
    } catch {
        return "PS> "
    }
}

function Initialize-OhMyPosh {
    <#
    .SYNOPSIS
        Initializes oh-my-posh prompt.
    .DESCRIPTION
        Configures oh-my-posh with a custom theme.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-ProfileLog "oh-my-posh not found" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        # Use a built-in theme
        $theme = 'jandedobbeleer'
        oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$theme.omp.json" | Invoke-Expression
        Write-ProfileLog "oh-my-posh initialized with theme: $theme" -Level DEBUG -Component "Prompt"
        return $true
    } catch {
        Write-ProfileLog "oh-my-posh initialization failed: $_" -Level DEBUG -Component "Prompt"
        return $false
    }
}

function Initialize-TerminalIcons {
    <#
    .SYNOPSIS
        Initializes Terminal-Icons module.
    .DESCRIPTION
        Configures Terminal-Icons for enhanced file listings.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-ModuleAvailable -Name 'Terminal-Icons')) {
        Write-ProfileLog "Terminal-Icons not available" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        Import-Module Terminal-Icons -Force -ErrorAction Stop
        Write-ProfileLog "Terminal-Icons initialized" -Level DEBUG -Component "Prompt"
        return $true
    } catch {
        Write-ProfileLog "Terminal-Icons initialization failed: $_" -Level DEBUG -Component "Prompt"
        return $false
    }
}

function Initialize-PoshGit {
    <#
    .SYNOPSIS
        Initializes posh-git module.
    .DESCRIPTION
        Configures posh-git for enhanced git prompt integration.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-ModuleAvailable -Name 'posh-git')) {
        Write-ProfileLog "posh-git not available" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        Import-Module posh-git -Force -ErrorAction Stop
        $Global:GitPromptSettings.EnableFileStatus = $true
        Write-ProfileLog "posh-git initialized" -Level DEBUG -Component "Prompt"
        return $true
    } catch {
        Write-ProfileLog "posh-git initialization failed: $_" -Level DEBUG -Component "Prompt"
        return $false
    }
}

# Initialize prompt enhancements for interactive sessions
if (Test-ProfileInteractive) {
    if ($Global:ProfileConfig.EnableOhMyPosh) {
        Initialize-OhMyPosh | Out-Null
    }
    if ($Global:ProfileConfig.EnableTerminalIcons) {
        Initialize-TerminalIcons | Out-Null
    }
    if ($Global:ProfileConfig.EnablePoshGit) {
        Initialize-PoshGit | Out-Null
    }
}

#endregion PROMPT CUSTOMIZATION AND SHELL ENHANCEMENTS

#region 18 - PACKAGE MANAGERS AND FRAMEWORK MANAGEMENT
#==============================================================================
<#
.SYNOPSIS
    Package manager and development framework management functions
.DESCRIPTION
    Provides comprehensive management for Windows package managers (winget, 
    chocolatey, scoop), language package managers (npm, pip, pipx, nuget), 
    and development frameworks (dotnet, node, python).
#>

#------------------------------------------------------------------------------
# Package Manager Detection and Status
#------------------------------------------------------------------------------

function Get-PackageManagerStatus {
    <#
    .SYNOPSIS
        Gets status of all package managers.
    .DESCRIPTION
        Returns availability and version info for all installed package managers.
    #>
    [CmdletBinding()]
    param()

    $managers = @(
        @{ Name = 'winget'; Command = 'winget'; VersionArg = '--version' }
        @{ Name = 'choco'; Command = 'choco'; VersionArg = '--version' }
        @{ Name = 'scoop'; Command = 'scoop'; VersionArg = '--version' }
        @{ Name = 'npm'; Command = 'npm'; VersionArg = '--version' }
        @{ Name = 'pnpm'; Command = 'pnpm'; VersionArg = '--version' }
        @{ Name = 'yarn'; Command = 'yarn'; VersionArg = '--version' }
        @{ Name = 'pip'; Command = 'pip'; VersionArg = '--version' }
        @{ Name = 'pipx'; Command = 'pipx'; VersionArg = '--version' }
        @{ Name = 'nuget'; Command = 'nuget'; VersionArg = 'help' }
        @{ Name = 'dotnet'; Command = 'dotnet'; VersionArg = '--version' }
        @{ Name = 'cargo'; Command = 'cargo'; VersionArg = '--version' }
        @{ Name = 'gem'; Command = 'gem'; VersionArg = '--version' }
    )

    $results = @()
    foreach ($m in $managers) {
        $cmd = Get-Command $m.Command -ErrorAction SilentlyContinue
        $version = $null
        if ($cmd) {
            try {
                $verOutput = & $m.Command $m.VersionArg 2>$null | Select-Object -First 1
                $version = ($verOutput -replace '.*?([0-9]+\.[0-9]+\.[0-9]+).*', '$1').Trim()
            } catch {}
        }
        $results += [PSCustomObject]@{
            Name = $m.Name
            Available = $null -ne $cmd
            Version = $version
            Path = if ($cmd) { $cmd.Source } else { $null }
        }
    }
    return $results | Sort-Object Name
}

#------------------------------------------------------------------------------
# Winget Package Manager
#------------------------------------------------------------------------------

function Get-WingetPackage {
    <#
    .SYNOPSIS
        Searches for packages using winget.
    .DESCRIPTION
        Searches winget repositories for packages matching the query.
    .PARAMETER Query
        Search query string.
    .PARAMETER Exact
        Match exact package name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [switch]$Exact
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not installed or not in PATH."
        return
    }

    try {
        $args = @('search', $Query)
        if ($Exact) { $args += '--exact' }
        $args += '--accept-source-agreements'
        
        & winget @args | Out-String | Write-Output
    } catch {
        Write-ProfileLog "Get-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        Installs a package using winget.
    .DESCRIPTION
        Installs a package from winget repositories.
    .PARAMETER Package
        Package name or ID.
    .PARAMETER Silent
        Silent installation.
    .PARAMETER WhatIf
        Show what would be installed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Package,
        [switch]$Silent,
        [switch]$WhatIf
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Install')) {
            $args = @('install', $Package, '--accept-package-agreements', '--accept-source-agreements')
            if ($Silent) { $args += '--silent' }
            if ($WhatIf) { $args += '--what-if' }
            
            & winget @args
            Write-ProfileLog "Installed winget package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-WingetPackage {
    <#
    .SYNOPSIS
        Updates a package using winget.
    .DESCRIPTION
        Updates a specific package or all packages.
    .PARAMETER Package
        Package name, or 'all' for all packages.
    .PARAMETER Silent
        Silent upgrade.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Package = 'all',
        [switch]$Silent
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        $target = if ($Package -eq 'all') { '--all' } else { $Package }
        if ($PSCmdlet.ShouldProcess($target, 'Upgrade')) {
            $args = @('upgrade', $target, '--accept-package-agreements')
            if ($Silent) { $args += '--silent' }
            
            & winget @args
            Write-ProfileLog "Updated winget package(s): $target" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Uninstall-WingetPackage {
    <#
    .SYNOPSIS
        Uninstalls a package using winget.
    .DESCRIPTION
        Removes a package installed via winget.
    .PARAMETER Package
        Package name or ID.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Package
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Uninstall')) {
            winget uninstall $Package
            Write-ProfileLog "Uninstalled winget package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Uninstall-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-WingetOutdated {
    <#
    .SYNOPSIS
        Lists outdated winget packages.
    .DESCRIPTION
        Shows packages with available updates.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not installed or not in PATH."
        return
    }

    try {
        winget upgrade --accept-source-agreements
    } catch {
        Write-ProfileLog "Get-WingetOutdated failed: $_" -Level WARN -Component "PackageManager"
    }
}

#------------------------------------------------------------------------------
# Chocolatey Package Manager
#------------------------------------------------------------------------------

function Get-ChocoPackage {
    <#
    .SYNOPSIS
        Searches for packages using Chocolatey.
    .PARAMETER Query
        Search query.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return
    }

    try {
        choco search $Query --limit-output | ConvertFrom-Csv -Delimiter '|' -Header Name, Version
    } catch {
        Write-ProfileLog "Get-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Installs a package using Chocolatey.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Force
        Force reinstall.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Force
    )

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'Install')) {
                $args = @('install', $p, '-y')
                if ($Force) { $args += '--force' }
                choco @args
                Write-ProfileLog "Installed choco package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-ChocoPackage {
    <#
    .SYNOPSIS
        Updates Chocolatey packages.
    .PARAMETER Package
        Package name or 'all'.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Package = 'all')

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        $target = if ($Package -eq 'all') { 'all' } else { $Package }
        if ($PSCmdlet.ShouldProcess($target, 'Upgrade')) {
            if ($Package -eq 'all') {
                choco upgrade all -y
            } else {
                choco upgrade $Package -y
            }
            Write-ProfileLog "Updated choco package(s): $target" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Uninstall-ChocoPackage {
    <#
    .SYNOPSIS
        Uninstalls a Chocolatey package.
    .PARAMETER Package
        Package name.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][string]$Package)

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Uninstall')) {
            choco uninstall $Package -y
            Write-ProfileLog "Uninstalled choco package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Uninstall-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Scoop Package Manager
#------------------------------------------------------------------------------

function Get-ScoopPackage {
    <#
    .SYNOPSIS
        Searches for packages using Scoop.
    .PARAMETER Query
        Search query.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return
    }

    try {
        scoop search $Query | ConvertFrom-String -PropertyNames Bucket, Name, Version -Delimiter '\s+'
    } catch {
        Write-ProfileLog "Get-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-ScoopPackage {
    <#
    .SYNOPSIS
        Installs a package using Scoop.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Global
        Install globally.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Global
    )

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'Install')) {
                if ($Global) {
                    scoop install $p --global
                } else {
                    scoop install $p
                }
                Write-ProfileLog "Installed scoop package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-ScoopPackage {
    <#
    .SYNOPSIS
        Updates Scoop packages.
    .PARAMETER Package
        Package name or '*' for all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Package = '*')

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return $false
    }

    try {
        if ($Package -eq '*') {
            if ($PSCmdlet.ShouldProcess('all packages', 'Update')) {
                scoop update
                scoop update '*'
                Write-ProfileLog "Updated all scoop packages" -Level INFO -Component "PackageManager"
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Package, 'Update')) {
                scoop update $Package
                Write-ProfileLog "Updated scoop package: $Package" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Node.js and NPM Management
#------------------------------------------------------------------------------

function Get-NpmPackage {
    <#
    .SYNOPSIS
        Searches for npm packages.
    .PARAMETER Query
        Search query.
    .PARAMETER Limit
        Maximum results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [int]$Limit = 20
    )

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "npm is not installed or not in PATH."
        return
    }

    try {
        npm search $Query --limit $Limit 2>$null | Select-Object -Skip 1 | 
            ConvertFrom-String -PropertyNames Name, Description, Author, Date, Version, Keywords
    } catch {
        Write-ProfileLog "Get-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-NpmPackage {
    <#
    .SYNOPSIS
        Installs npm packages globally or locally.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Global
        Install globally.
    .PARAMETER Dev
        Install as dev dependency.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Global,
        [switch]$Dev
    )

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "npm is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'npm install')) {
                $args = @('install')
                if ($Global) { 
                    $args += '-g' 
                } elseif ($Dev) { 
                    $args += '--save-dev' 
                }
                $args += $p
                
                & npm @args
                Write-ProfileLog "Installed npm package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-NpmPackage {
    <#
    .SYNOPSIS
        Updates npm packages.
    .PARAMETER Package
        Package name or 'all'.
    .PARAMETER Global
        Update global packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Package = 'all',
        [switch]$Global
    )

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warning "npm is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'npm update')) {
            if ($Global) {
                npm update -g $Package
            } else {
                if ($Package -eq 'all') {
                    npm update
                } else {
                    npm update $Package
                }
            }
            Write-ProfileLog "Updated npm package(s): $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-NodeVersion {
    <#
    .SYNOPSIS
        Gets Node.js and npm version information.
    #>
    [CmdletBinding()]
    param()

    $result = @{}
    
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $result.NodeVersion = (node --version) -replace '^v'
    }
    
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $result.NpmVersion = (npm --version)
    }
    
    if (Get-Command nvm -ErrorAction SilentlyContinue) {
        $result.NvmVersion = (nvm version)
    }
    
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        $result.PnpmVersion = (pnpm --version)
    }
    
    if (Get-Command yarn -ErrorAction SilentlyContinue) {
        $result.YarnVersion = (yarn --version)
    }

    return [PSCustomObject]$result
}

#------------------------------------------------------------------------------
# Python and Pip Management
#------------------------------------------------------------------------------

function Get-PipPackage {
    <#
    .SYNOPSIS
        Lists or searches pip packages.
    .PARAMETER Search
        Search query (optional).
    .PARAMETER Outdated
        Show outdated packages.
    #>
    [CmdletBinding()]
    param(
        [string]$Search,
        [switch]$Outdated
    )

    if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
        Write-Warning "pip is not installed or not in PATH."
        return
    }

    try {
        if ($Outdated) {
            pip list --outdated --format=columns
        } elseif ($Search) {
            pip search $Search 2>$null
        } else {
            pip list --format=columns
        }
    } catch {
        Write-ProfileLog "Get-PipPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-PipPackage {
    <#
    .SYNOPSIS
        Installs pip packages.
    .PARAMETER Package
        Package name(s).
    .PARAMETER User
        Install for user only.
    .PARAMETER Upgrade
        Upgrade existing packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$User,
        [switch]$Upgrade
    )

    if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
        Write-Warning "pip is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'pip install')) {
                $args = @('install')
                if ($User) { $args += '--user' }
                if ($Upgrade) { $args += '--upgrade' }
                $args += $p
                
                & pip @args
                Write-ProfileLog "Installed pip package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-PipPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-PipPackage {
    <#
    .SYNOPSIS
        Updates pip packages.
    .PARAMETER Package
        Package name or 'all'.
    .PARAMETER User
        Update user packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Package = 'all',
        [switch]$User
    )

    if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
        Write-Warning "pip is not installed or not in PATH."
        return $false
    }

    try {
        if ($Package -eq 'all') {
            $packages = pip list --outdated --format=json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty name
            foreach ($p in $packages) {
                if ($PSCmdlet.ShouldProcess($p, 'pip upgrade')) {
                    $args = @('install', '--upgrade')
                    if ($User) { $args += '--user' }
                    $args += $p
                    & pip @args
                }
            }
            Write-ProfileLog "Updated all pip packages" -Level INFO -Component "PackageManager"
        } else {
            if ($PSCmdlet.ShouldProcess($Package, 'pip upgrade')) {
                $args = @('install', '--upgrade')
                if ($User) { $args += '--user' }
                $args += $Package
                & pip @args
                Write-ProfileLog "Updated pip package: $Package" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-PipPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Install-PipxPackage {
    <#
    .SYNOPSIS
        Installs Python applications using pipx.
    .PARAMETER Package
        Package name.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory)][string]$Package)

    if (-not (Get-Command pipx -ErrorAction SilentlyContinue)) {
        Write-Warning "pipx is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'pipx install')) {
            pipx install $Package
            Write-ProfileLog "Installed pipx package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-PipxPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-PythonVersion {
    <#
    .SYNOPSIS
        Gets Python and pip version information.
    #>
    [CmdletBinding()]
    param()

    $result = @{}
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $result.PythonVersion = (python --version) -replace '^Python\s+'
    }
    
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        $result.PipVersion = (pip --version) -split '\s+' | Select-Object -Index 1
    }
    
    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        $result.PipxVersion = (pipx --version)
    }
    
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        $result.CondaVersion = (conda --version) -replace '^conda\s+'
    }

    return [PSCustomObject]$result
}

#------------------------------------------------------------------------------
# .NET Framework Management
#------------------------------------------------------------------------------

function Get-DotnetInfo {
    <#
    .SYNOPSIS
        Gets .NET SDK and runtime information.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return
    }

    try {
        [PSCustomObject]@{
            SdkVersion = (dotnet --version)
            Runtimes = dotnet --list-runtimes | ForEach-Object { ($_ -split '\s+')[0,1] -join ' ' }
            Sdks = dotnet --list-sdks | ForEach-Object { ($_ -split '\s+')[0,1] -join ' ' }
        }
    } catch {
        Write-ProfileLog "Get-DotnetInfo failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-DotnetTool {
    <#
    .SYNOPSIS
        Installs a .NET global tool.
    .PARAMETER Tool
        Tool name.
    .PARAMETER Version
        Specific version.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [string]$Version
    )

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Tool, 'dotnet tool install')) {
            $args = @('tool', 'install', '--global', $Tool)
            if ($Version) { $args += '--version'; $args += $Version }
            
            & dotnet @args
            Write-ProfileLog "Installed dotnet tool: $Tool" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-DotnetTool failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-DotnetTool {
    <#
    .SYNOPSIS
        Updates .NET global tools.
    .PARAMETER Tool
        Tool name or omitted for all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Tool)

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return $false
    }

    try {
        if ($Tool) {
            if ($PSCmdlet.ShouldProcess($Tool, 'dotnet tool update')) {
                dotnet tool update --global $Tool
                Write-ProfileLog "Updated dotnet tool: $Tool" -Level INFO -Component "PackageManager"
            }
        } else {
            if ($PSCmdlet.ShouldProcess('all tools', 'dotnet tool update')) {
                dotnet tool list --global | Select-Object -Skip 2 | ForEach-Object {
                    $toolName = ($_ -split '\s+')[0]
                    if ($toolName) {
                        dotnet tool update --global $toolName
                    }
                }
                Write-ProfileLog "Updated all dotnet tools" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-DotnetTool failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Unified Package Management
#------------------------------------------------------------------------------

function Install-DevPackage {
    <#
    .SYNOPSIS
        Installs a package using the appropriate package manager.
    .DESCRIPTION
        Automatically detects and uses the correct package manager based on context or preference.
    .PARAMETER Package
        Package name.
    .PARAMETER Manager
        Package manager to use (winget, choco, scoop, npm, pip, dotnet).
    .PARAMETER Global
        Install globally where supported.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Package,
        [ValidateSet('winget', 'choco', 'scoop', 'npm', 'pip', 'pipx', 'dotnet')]
        [string]$Manager,
        [switch]$Global
    )

    if (-not $Manager) {
        # Auto-detect based on package prefix or available managers
        $priority = @('winget', 'choco', 'npm', 'pip', 'scoop')
        foreach ($m in $priority) {
            if (Get-Command $m -ErrorAction SilentlyContinue) {
                $Manager = $m
                break
            }
        }
    }

    switch ($Manager) {
        'winget' { return Install-WingetPackage -Package $Package }
        'choco' { return Install-ChocoPackage -Package $Package }
        'scoop' { return Install-ScoopPackage -Package $Package }
        'npm' { return Install-NpmPackage -Package $Package -Global:$Global }
        'pip' { return Install-PipPackage -Package $Package }
        'pipx' { return Install-PipxPackage -Package $Package }
        'dotnet' { return Install-DotnetTool -Tool $Package }
        default {
            Write-Warning "No suitable package manager found."
            return $false
        }
    }
}

function Update-AllPackages {
    <#
    .SYNOPSIS
        Updates packages across all package managers.
    .DESCRIPTION
        Updates packages for all detected package managers.
    .PARAMETER Manager
        Specific manager(s) to update, or all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('all', 'winget', 'choco', 'scoop', 'npm', 'pip', 'dotnet')]
        [string[]]$Manager = 'all'
    )

    $results = @()

    if ($Manager -contains 'all' -or $Manager -contains 'winget') {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('winget packages', 'Update')) {
                Update-WingetPackage -Package 'all'
                $results += 'winget'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'choco') {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('choco packages', 'Update')) {
                Update-ChocoPackage -Package 'all'
                $results += 'choco'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'scoop') {
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('scoop packages', 'Update')) {
                Update-ScoopPackage
                $results += 'scoop'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'npm') {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('npm packages', 'Update')) {
                Update-NpmPackage -Global
                $results += 'npm'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'pip') {
        if (Get-Command pip -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('pip packages', 'Update')) {
                Update-PipPackage -Package 'all'
                $results += 'pip'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'dotnet') {
        if (Get-Command dotnet -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess('dotnet tools', 'Update')) {
                Update-DotnetTool
                $results += 'dotnet'
            }
        }
    }

    Write-ProfileLog "Updated packages for: $($results -join ', ')" -Level INFO -Component "PackageManager"
    return $results
}

#endregion PACKAGE MANAGERS AND FRAMEWORK MANAGEMENT

#region 19 - TOOL INTEGRATIONS AND CODE COMPLETIONS
#==============================================================================
<#
.SYNOPSIS
    Third-party tool integrations with enhanced argument completion
.DESCRIPTION
    Provides argument completers and enhanced integrations for development tools,
    package managers, and frameworks.
#>

#------------------------------------------------------------------------------
# Helper function for registering completions
#------------------------------------------------------------------------------

function Register-ToolCompletion {
    <#
    .SYNOPSIS
        Registers argument completion for a tool.
    .PARAMETER Command
        Command name.
    .PARAMETER ScriptBlock
        Completion scriptblock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName $Command -ScriptBlock $ScriptBlock
    }
}

#------------------------------------------------------------------------------
# Winget Completions
#------------------------------------------------------------------------------

$WingetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('install', 'show', 'source', 'search', 'list', 'upgrade', 'uninstall', 'hash', 'validate', 'settings', 'features', 'export', 'import', 'pin', 'configure', 'repair')
    $options = @('--version', '--info', '--help', '--wait', '--verbose', '--nowarn', '--disable-interactivity', '--rainbow')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'winget' -ScriptBlock $WingetCompletion

#------------------------------------------------------------------------------
# Chocolatey Completions
#------------------------------------------------------------------------------

$ChocoCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('install', 'upgrade', 'uninstall', 'search', 'list', 'info', 'outdated', 'pin', 'unpin', 'config', 'feature', 'apikey', 'unpackself', 'version', 'download')
    $options = @('--version', '--help', '-v', '--verbose', '--debug', '--accept-license', '-y', '--yes', '--force', '--noop', '--whatif')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'choco' -ScriptBlock $ChocoCompletion

#------------------------------------------------------------------------------
# Scoop Completions
#------------------------------------------------------------------------------

$ScoopCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('install', 'uninstall', 'update', 'upgrade', 'search', 'list', 'show', 'info', 'cleanup', 'bucket', 'cache', 'alias', 'reset', 'hold', 'unhold', 'status', 'cat', 'checkup', 'shim', 'which')
    $options = @('--version', '--help', '-g', '--global')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'scoop' -ScriptBlock $ScoopCompletion

#------------------------------------------------------------------------------
# NPM/Yarn/PNPM Completions
#------------------------------------------------------------------------------

$NpmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('install', 'uninstall', 'update', 'outdated', 'search', 'ls', 'list', 'run', 'start', 'test', 'build', 'publish', 'init', 'config', 'cache', 'audit', 'fix', 'fund', 'info', 'view', 'adduser', 'logout', 'whoami', 'version', 'prune', 'dedupe')
    $options = @('--version', '--help', '-g', '--global', '--save', '--save-dev', '--save-optional', '--save-exact', '--force', '--production', '--json')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'npm' -ScriptBlock $NpmCompletion

$YarnCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('add', 'audit', 'autoclean', 'bin', 'cache', 'check', 'config', 'create', 'dedupe', 'generate-lock-entry', 'global', 'help', 'import', 'info', 'init', 'install', 'licenses', 'link', 'list', 'login', 'logout', 'node', 'outdated', 'owner', 'pack', 'policies', 'publish', 'remove', 'run', 'self-update', 'tag', 'team', 'test', 'upgrade', 'upgrade-interactive', 'version', 'versions', 'why', 'workspace', 'workspaces')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'yarn' -ScriptBlock $YarnCompletion

$PnpmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('add', 'audit', 'bin', 'config', 'exec', 'fetch', 'import', 'info', 'init', 'install', 'link', 'list', 'outdated', 'pack', 'prune', 'publish', 'rebuild', 'remove', 'run', 'search', 'start', 'store', 'test', 'unlink', 'update', 'upgrade', 'why')
    $options = @('--version', '--help', '-g', '--global', '--save-dev', '--save-prod', '--save-optional', '--frozen-lockfile')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'pnpm' -ScriptBlock $PnpmCompletion

#------------------------------------------------------------------------------
# Python/Pip Completions
#------------------------------------------------------------------------------

$PipCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('install', 'download', 'uninstall', 'freeze', 'list', 'show', 'search', 'check', 'config', 'cache', 'index', 'wheel', 'hash', 'completion', 'debug', 'help')
    $options = @('--version', '--help', '--upgrade', '-U', '--user', '--force-reinstall', '--no-deps', '--pre', '--require-virtualenv')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'pip' -ScriptBlock $PipCompletion
Register-ToolCompletion -Command 'pip3' -ScriptBlock $PipCompletion

#------------------------------------------------------------------------------
# .NET CLI Completions
#------------------------------------------------------------------------------

$DotnetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('new', 'restore', 'build', 'publish', 'run', 'test', 'pack', 'migrate', 'clean', 'sln', 'store', 'help', 'add', 'remove', 'list', 'tool', 'nuget', 'msbuild', 'vstest', 'watch', 'format', 'workload', 'sdk')
    $options = @('--version', '--info', '--list-runtimes', '--list-sdks', '--help', '-v', '--verbosity', '-c', '--configuration', '-f', '--framework', '--runtime')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'dotnet' -ScriptBlock $DotnetCompletion

#------------------------------------------------------------------------------
# Docker Completions
#------------------------------------------------------------------------------

$DockerCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('attach', 'build', 'builder', 'commit', 'compose', 'config', 'container', 'context', 'cp', 'create', 'diff', 'events', 'exec', 'export', 'history', 'image', 'images', 'import', 'info', 'inspect', 'kill', 'load', 'login', 'logout', 'logs', 'manifest', 'network', 'node', 'pause', 'plugin', 'port', 'ps', 'pull', 'push', 'rename', 'restart', 'rm', 'rmi', 'run', 'save', 'search', 'secret', 'service', 'stack', 'start', 'stats', 'stop', 'swarm', 'system', 'tag', 'top', 'trust', 'unpause', 'update', 'version', 'volume', 'wait')
    $options = @('--version', '--help', '-v', '--verbose', '-H', '--host', '--config', '--tls', '--tlscacert', '--tlscert', '--tlskey', '--tlsverify')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'docker' -ScriptBlock $DockerCompletion

#------------------------------------------------------------------------------
# Git Completions (enhanced)
#------------------------------------------------------------------------------

$GitCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('add', 'branch', 'checkout', 'clone', 'commit', 'config', 'diff', 'fetch', 'init', 'log', 'merge', 'mv', 'pull', 'push', 'rebase', 'reset', 'restore', 'rm', 'show', 'stash', 'status', 'switch', 'tag', 'bisect', 'cherry-pick', 'clean', 'describe', 'format-patch', 'gc', 'grep', 'help', 'notes', 'prune', 'reflog', 'remote', 'rerere', 'revert', 'shortlog', 'submodule', 'subtree', 'whatchanged', 'worktree')
    $options = @('--version', '--help', '--verbose', '--quiet', '--all', '--force', '--dry-run', '--porcelain', '--short')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'git' -ScriptBlock $GitCompletion

#------------------------------------------------------------------------------
# Kubernetes (kubectl) Completions
#------------------------------------------------------------------------------

$KubectlCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('get', 'describe', 'create', 'delete', 'apply', 'run', 'expose', 'set', 'edit', 'rollout', 'scale', 'autoscale', 'certificate', 'cluster-info', 'top', 'cordon', 'uncordon', 'drain', 'taint', 'label', 'annotate', 'completion', 'api-resources', 'api-versions', 'config', 'plugin', 'version', 'proxy', 'cp', 'auth', 'debug', 'events', 'exec', 'logs', 'port-forward', 'attach', 'wait')
    $options = @('--namespace', '-n', '--all-namespaces', '-A', '--output', '-o', '--selector', '-l', '--all', '--watch', '-w', '--show-labels', '--context')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'kubectl' -ScriptBlock $KubectlCompletion

#------------------------------------------------------------------------------
# Helm Completions
#------------------------------------------------------------------------------

$HelmCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('completion', 'create', 'dependency', 'env', 'get', 'history', 'install', 'lint', 'list', 'package', 'plugin', 'pull', 'push', 'repo', 'rollback', 'search', 'show', 'status', 'template', 'test', 'uninstall', 'upgrade', 'verify', 'version')
    $options = @('--namespace', '-n', '--kube-context', '--kubeconfig', '--debug', '--help', '--version', '-v', '--repo', '--values', '-f', '--set', '--wait', '--timeout')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'helm' -ScriptBlock $HelmCompletion

#------------------------------------------------------------------------------
# VS Code CLI Completions
#------------------------------------------------------------------------------

$CodeCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $options = @('--help', '--version', '-v', '--verbose', '--diff', '--merge', '--goto', '--new-window', '-n', '--reuse-window', '-r', '--wait', '-w', '--disable-extensions', '--list-extensions', '--show-versions', '--install-extension', '--uninstall-extension', '--enable-proposed-api', '--status', '--statuses', '--sync', '--export', '--telemetry', '--disable-telemetry', '--crash-reporter-directory', '--extensions-dir', '--user-data-dir', '--portable', '--enable-proposed-api', '--log', '--max-memory', '--turn-off-sync')
    
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'code' -ScriptBlock $CodeCompletion

#------------------------------------------------------------------------------
# Terraform Completions
#------------------------------------------------------------------------------

$TerraformCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('apply', 'console', 'destroy', 'env', 'fmt', 'force-unlock', 'get', 'graph', 'import', 'init', 'login', 'logout', 'metadata', 'output', 'plan', 'providers', 'refresh', 'show', 'state', 'taint', 'test', 'untaint', 'validate', 'version', 'workspace')
    $options = @('--version', '--help', '-chdir', '-json', '-var', '-var-file', '-out', '-auto-approve', '-input', '-lock', '-lock-timeout', '-parallelism', '-refresh', '-target', '-upgrade', '-check', '-diff', '-recursive', '-write')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'terraform' -ScriptBlock $TerraformCompletion

#------------------------------------------------------------------------------
# AWS CLI Completions
#------------------------------------------------------------------------------

$AwsCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $services = @('accessanalyzer', 'account', 'acm', 'acm-pca', 'amp', 'amplify', 'amplifybackend', 'amplifyuibuilder', 'apigateway', 'apigatewaymanagementapi', 'apigatewayv2', 'appconfig', 'appconfigdata', 'appfabric', 'appflow', 'appintegrations', 'application-autoscaling', 'application-insights', 'applicationcostprofiler', 'appmesh', 'apprunner', 'appstream', 'appsync', 'arc-zonal-shift', 'athena', 'auditmanager', 'autoscaling', 'autoscaling-plans', 'b2bi', 'backup', 'backup-gateway', 'backupstorage', 'batch', 'bedrock', 'bedrock-agent', 'bedrock-agent-runtime', 'bedrock-runtime', 'billingconductor', 'braket', 'budgets', 'ce', 'chatbot', 'chime', 'chime-sdk-identity', 'chime-sdk-media-pipelines', 'chime-sdk-meetings', 'chime-sdk-messaging', 'chime-sdk-voice', 'cleanrooms', 'cloud9', 'cloudcontrol', 'clouddirectory', 'cloudformation', 'cloudfront', 'cloudfront-keyvaluestore', 'cloudhsm', 'cloudhsmv2', 'cloudsearch', 'cloudsearchdomain', 'cloudtrail', 'cloudtrail-data', 'cloudwatch', 'codeartifact', 'codebuild', 'codecatalyst', 'codecommit', 'codedeploy', 'codeguru-reviewer', 'codeguru-security', 'codeguruprofiler', 'codepipeline', 'codestar', 'codestar-connections', 'codestar-notifications', 'cognito-identity', 'cognito-idp', 'cognito-sync', 'comprehend', 'comprehendmedical', 'compute-optimizer', 'configservice', 'configure', 'connect', 'connect-contact-lens', 'connectcases', 'connectparticipant', 'controltower', 'cur', 'customer-profiles', 'databrew', 'dataexchange', 'datapipeline', 'datasync', 'dax', 'deploy', 'detective', 'devicefarm', 'devops-guru', 'directconnect', 'discovery', 'dlm', 'dms', 'docdb', 'docdb-elastic', 'drs', 'ds', 'dynamodb', 'dynamodbstreams', 'ebs', 'ec2', 'ec2-instance-connect', 'ecr', 'ecr-public', 'ecs', 'efs', 'eks', 'eks-auth', 'elasticache', 'elasticbeanstalk', 'elastictranscoder', 'elb', 'elbv2', 'emr', 'emr-containers', 'emr-serverless', 'entityresolution', 'es', 'events', 'evidently', 'finspace', 'finspace-data', 'firehose', 'fis', 'fms', 'forecast', 'forecastquery', 'frauddetector', 'fsx', 'gamelift', 'glacier', 'globalaccelerator', 'glue', 'grafana', 'greengrass', 'greengrassv2', 'groundstation', 'guardduty', 'health', 'healthlake', 'history', 'iam', 'identitystore', 'imagebuilder', 'importexport', 'inspector', 'inspector2', 'internetmonitor', 'iot', 'iot-data', 'iot-jobs-data', 'iot-roborunner', 'iot1click-devices', 'iot1click-projects', 'iotanalytics', 'iotdeviceadvisor', 'iotevents', 'iotevents-data', 'iotfleethub', 'iotfleetwise', 'iotsecuretunneling', 'iotsitewise', 'iotthingsgraph', 'iotwireless', 'ivs', 'ivs-realtime', 'ivschat', 'kafka', 'kafkaconnect', 'kendra', 'kendra-ranking', 'keyspaces', 'kinesis', 'kinesis-video-archived-media', 'kinesis-video-media', 'kinesis-video-signaling', 'kinesis-video-webrtc-storage', 'kinesisanalytics', 'kinesisanalyticsv2', 'kinesisvideo', 'kms', 'lakeformation', 'lambda', 'launch-wizard', 'lex-models', 'lex-runtime', 'lexv2-models', 'lexv2-runtime', 'license-manager', 'license-manager-linux-subscriptions', 'license-manager-user-subscriptions', 'lightsail', 'location', 'logs', 'lookoutequipment', 'lookoutmetrics', 'lookoutvision', 'm2', 'machinelearning', 'macie2', 'managedblockchain', 'managedblockchain-query', 'marketplace-catalog', 'marketplace-entitlement', 'marketplacecommerceanalytics', 'mediaconnect', 'mediaconvert', 'medialive', 'mediapackage', 'mediapackage-vod', 'mediapackagev2', 'mediastore', 'mediastore-data', 'mediatailor', 'medical-imaging', 'memorydb', 'meteringmarketplace', 'mgh', 'mgn', 'migration-hub-refactor-spaces', 'migrationhub-config', 'migrationhuborchestrator', 'migrationhubstrategy', 'mq', 'mturk', 'mwaa', 'neptune', 'neptune-graph', 'neptunedata', 'network-firewall', 'networkmanager', 'nimble', 'oam', 'omics', 'opensearch', 'opensearchserverless', 'opsworks', 'opsworks-cm', 'organizations', 'osis', 'outposts', 'panorama', 'payment-cryptography', 'payment-cryptography-data', 'pca-connector-ad', 'personalize', 'personalize-events', 'personalize-runtime', 'pi', 'pinpoint', 'pinpoint-email', 'pinpoint-sms-voice', 'pinpoint-sms-voice-v2', 'pipes', 'polly', 'pricing', 'privatenetworks', 'proton', 'qldb', 'qldb-session', 'quicksight', 'ram', 'rbin', 'rds', 'rds-data', 'redshift', 'redshift-data', 'redshift-serverless', 'rekognition', 'resiliencehub', 'resource-explorer-2', 'resource-groups', 'resourcegroupstaggingapi', 'robomaker', 'rolesanywhere', 'route53', 'route53-recovery-cluster', 'route53-recovery-control-config', 'route53-recovery-readiness', 'route53domains', 'route53resolver', 'rum', 's3', 's3api', 's3control', 's3outposts', 'sagemaker', 'sagemaker-a2i-runtime', 'sagemaker-edge', 'sagemaker-featurestore-runtime', 'sagemaker-geospatial', 'sagemaker-metrics', 'sagemaker-runtime', 'savingsplans', 'scheduler', 'schemas', 'sdb', 'secretsmanager', 'securityhub', 'securitylake', 'serverlessrepo', 'service-quotas', 'servicecatalog', 'servicecatalog-appregistry', 'servicediscovery', 'ses', 'sesv2', 'shield', 'signer', 'simspaceweaver', 'sms', 'snow-device-management', 'snowball', 'sns', 'sqs', 'ssm', 'ssm-contacts', 'ssm-incidents', 'ssm-sap', 'sso', 'sso-admin', 'sso-oidc', 'stepfunctions', 'storagegateway', 'sts', 'support', 'support-app', 'swf', 'synthetics', 'textract', 'timestream-query', 'timestream-write', 'tls', 'transcribe', 'transfer', 'translate', 'verifiedpermissions', 'voice-id', 'vpc-lattice', 'waf', 'waf-regional', 'wafv2', 'wellarchitected', 'wisdom', 'workdocs', 'worklink', 'workmail', 'workmailmessageflow', 'workspaces', 'workspaces-web', 'xray')
    
    $services | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'aws' -ScriptBlock $AwsCompletion

#------------------------------------------------------------------------------
# Azure CLI Completions
#------------------------------------------------------------------------------

$AzCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('account', 'acr', 'ad', 'aks', 'apim', 'appconfig', 'appservice', 'backup', 'batch', 'billing', 'bot', 'cdn', 'cloud', 'cognitiveservices', 'config', 'configure', 'consumption', 'container', 'cosmosdb', 'deployment', 'disk', 'dla', 'dls', 'dms', 'eventgrid', 'eventhubs', 'extension', 'feedback', 'find', 'functionapp', 'group', 'hdinsight', 'identity', 'image', 'iot', 'keyvault', 'kusto', 'lab', 'lock', 'login', 'logout', 'managedapp', 'maps', 'mariadb', 'monitor', 'mysql', 'netappfiles', 'network', 'policy', 'postgres', 'ppg', 'provider', 'redis', 'relay', 'resource', 'role', 'search', 'security', 'servicebus', 'sf', 'signalr', 'snapshot', 'sql', 'sqlvm', 'ssh', 'storage', 'synapse', 'tag', 'term', 'ts', 'version', 'vm', 'vmss', 'webapp', 'webpubsub', 'workloads')
    $options = @('--version', '--help', '--verbose', '--debug', '--query', '--output', '-o', '--subscription', '-s', '--resource-group', '-g', '--location', '-l')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'az' -ScriptBlock $AzCompletion

#------------------------------------------------------------------------------
# GH (GitHub CLI) Completions
#------------------------------------------------------------------------------

$GhCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('alias', 'api', 'auth', 'browse', 'codespace', 'completion', 'config', 'extension', 'gpg-key', 'issue', 'label', 'org', 'pr', 'project', 'release', 'repo', 'run', 'search', 'secret', 'ssh-key', 'status', 'variable', 'workflow')
    $options = @('--version', '--help', '--repo', '-R', '--hostname', '--silent', '--jq', '--json', '--template', '--paginate', '-p')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'gh' -ScriptBlock $GhCompletion

#------------------------------------------------------------------------------
# Rust/Cargo Completions
#------------------------------------------------------------------------------

$CargoCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('add', 'bench', 'build', 'check', 'clean', 'clippy', 'doc', 'fetch', 'fix', 'fmt', 'generate-lockfile', 'init', 'install', 'locate-project', 'login', 'logout', 'metadata', 'new', 'owner', 'package', 'pkgid', 'publish', 'remove', 'report', 'run', 'rustdoc', 'search', 'test', 'tree', 'uninstall', 'update', 'vendor', 'verify-project', 'version', 'yank')
    $options = @('--version', '--help', '--verbose', '-v', '--quiet', '-q', '--color', '--frozen', '--locked', '--offline', '-p', '--package', '--workspace', '--all', '--exclude', '--lib', '--bin', '--bins', '--example', '--examples', '--test', '--tests', '--bench', '--benches', '--all-targets', '--features', '--all-features', '--no-default-features', '--target', '--release', '-r', '--profile', '--debug', '--jobs', '-j')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'cargo' -ScriptBlock $CargoCompletion

#------------------------------------------------------------------------------
# NuGet Completions
#------------------------------------------------------------------------------

$NugetCompletion = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $commands = @('add', 'client-cert', 'config', 'delete', 'disable', 'enable', 'init', 'install', 'list', 'locals', 'push', 'remove', 'restore', 'search', 'setApiKey', 'sign', 'sources', 'spec', 'trustedsigners', 'update', 'verify')
    $options = @('--version', '--help', '--source', '--configfile', '--output-directory', '-OutputDirectory', '--exclude-version', '-ExcludeVersion', '--disable-parallel-processing', '--no-cache', '--require-consent', '--non-interactive', '--verbosity', '-Verbosity')
    
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    $options | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ToolCompletion -Command 'nuget' -ScriptBlock $NugetCompletion

#------------------------------------------------------------------------------
# Initialize all completions
#------------------------------------------------------------------------------

Write-ProfileLog "Tool completions registered" -Level DEBUG -Component "Completions"

#endregion TOOL INTEGRATIONS AND CODE COMPLETIONS

#region 20 - ALIASES AND SHORTCUTS
#==============================================================================
<#
.SYNOPSIS
    Aliases and command shortcuts
.DESCRIPTION
    Provides convenient aliases and shortcuts for common commands.
#>

# Navigation functions (aliases with arguments don't work)
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function ~ { Set-Location ~ }

# Utility aliases
Set-Alias -Name grep -Value Select-String -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name which -Value Get-Command -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name touch -Value New-Item -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name nano -Value notepad -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name la -Value Get-ChildItem -Option AllScope -ErrorAction SilentlyContinue
Set-Alias -Name l -Value Get-ChildItem -Option AllScope -ErrorAction SilentlyContinue

# Function aliases for complex operations
function cd.. { Set-Location .. }
function cd... { Set-Location ../.. }
function cd.... { Set-Location ../../.. }
function cd..... { Set-Location ../../../.. }

# Quick system info
function sysinfo { Get-SystemInfo | Format-List }
function meminfo { Get-MemoryInfo | Format-List }
function cpuinfo { Get-CPUInfo | Format-List }
function diskinfo { Get-DiskInfo | Format-Table -AutoSize }
function gpuinfo { Get-GPUInfo | Format-Table -AutoSize }
function biosinfo { Get-BIOSInfo | Format-List }

# Quick network info
function netinfo { Get-NetworkSnapshot | Format-List }
function ipinfo { Get-LocalIP }
function pubip { Get-PublicIP }
function flushdns { Clear-DnsCache }

# Quick process info
function top { Get-TopProcesses | Format-Table -AutoSize }
function topcpu { Get-TopProcesses -By CPU | Format-Table -AutoSize }
function topio { Get-TopProcesses -By IO | Format-Table -AutoSize }

# Quick service info
function svc { Get-ServiceHealth | Format-Table -AutoSize }

# Quick health check
function health { Get-SystemHealth | Format-List }

# Quick diagnostics
function diag { Show-ProfileDiagnostics }
function repair { Repair-Profile }

# Quick optimization
function optimize { Optimize-System }

# Quick benchmark
function benchmark { param([scriptblock]$sb) Measure-Benchmark -ScriptBlock $sb }

# Quick file operations
function du { param([string]$p = $PWD, [int]$t = 20) Get-DiskUsage -Path $p -Top $t }
function largefiles { param([string]$p = $PWD, [int]$s = 100, [int]$t = 20) Find-LargeFiles -Path $p -SizeMB $s -Top $t }

# Quick editor
function edit { param([string]$f) & $Global:ProfileConfig.Editor $f }
function code. { code . }

# Quick admin
function sudo { Start-Process pwsh -Verb runAs }

# Quick module management
function mods { Get-InstalledModulesCache | Format-List }
function updatemods { Update-ProfileModules }

# Quick help
function helpme { 
    Write-Host "`n=== Profile Quick Reference ===" -ForegroundColor Cyan
    Write-Host "System: sysinfo, meminfo, cpuinfo, diskinfo, gpuinfo, biosinfo, health" -ForegroundColor Yellow
    Write-Host "Network: netinfo, ipinfo, pubip, flushdns" -ForegroundColor Yellow
    Write-Host "Processes: top, topcpu, topio" -ForegroundColor Yellow
    Write-Host "DNS: Use-CloudflareDns, Use-GoogleDns, Use-BestDns" -ForegroundColor Yellow
    Write-Host "Optimization: optimize, Set-PowerPlan, Invoke-DiskMaintenance" -ForegroundColor Yellow
    Write-Host "Diagnostics: diag, repair, Test-ProfileHealth" -ForegroundColor Yellow
    Write-Host "Updates: updatemods, Update-HelpProfile" -ForegroundColor Yellow
    Write-Host "Files: du, largefiles, Clear-TempFiles" -ForegroundColor Yellow
    Write-Host "Package Managers: pmstatus, updateall, Install-DevPackage" -ForegroundColor Yellow
    Write-Host "  Winget: wgs, wgi, wgu, wgun" -ForegroundColor DarkGray
    Write-Host "  Choco: chs, chi, chu, chun" -ForegroundColor DarkGray
    Write-Host "  NPM: npi, npu, npug" -ForegroundColor DarkGray
    Write-Host "  Pip: pipl, pipi, pipu" -ForegroundColor DarkGray
    Write-Host ""
}

# Package manager quick aliases
function wgs { param([string]$q) Get-WingetPackage -Query $q }
function wgi { param([string]$p) Install-WingetPackage -Package $p }
function wgu { param([string]$p = 'all') Update-WingetPackage -Package $p }
function wgun { param([string]$p) Uninstall-WingetPackage -Package $p }
function chs { param([string]$q) Get-ChocoPackage -Query $q }
function chi { param([string]$p) Install-ChocoPackage -Package $p }
function chu { param([string]$p = 'all') Update-ChocoPackage -Package $p }
function chun { param([string]$p) Uninstall-ChocoPackage -Package $p }
function npi { param([string]$p, [switch]$g) Install-NpmPackage -Package $p -Global:$g }
function npu { param([string]$p = 'all') Update-NpmPackage -Package $p }
function npug { Update-NpmPackage -Package 'all' -Global }
function pipl { Get-PipPackage }
function pipi { param([string]$p, [switch]$u) Install-PipPackage -Package $p -Upgrade:$u }
function pipu { param([string]$p = 'all') Update-PipPackage -Package $p }
function pmstatus { Get-PackageManagerStatus | Format-Table }
function updateall { Update-AllPackages -Manager 'all' }

#endregion ALIASES AND SHORTCUTS

#region 21 - THIRD-PARTY CLI TOOL INTEGRATIONS
#==============================================================================
<#
.SYNOPSIS
    Third-party CLI tool integrations
.DESCRIPTION
    Provides integration with popular third-party CLI tools with argument
    completion and configuration.
#>

function Initialize-ThirdPartyTools {
    [CmdletBinding()]
    param()

    # Winget completion
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # Add completion if available
        Register-ArgumentCompleter -CommandName winget -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            winget --help | Select-String -Pattern "^\s+\w+" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Line.Trim(), $_.Line.Trim(), 'ParameterValue', $_.Line.Trim()
                )
            }
        }
    }

    # gh (GitHub CLI) completion
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName gh -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            gh help | Select-String -Pattern "^\s+\w+" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Line.Trim(), $_.Line.Trim(), 'ParameterValue', $_.Line.Trim()
                )
            }
        }
    }

    # kubectl completion
    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName kubectl -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            kubectl help | Select-String -Pattern "^\s+\w+" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Line.Trim(), $_.Line.Trim(), 'ParameterValue', $_.Line.Trim()
                )
            }
        }
    }

    # helm completion
    if (Get-Command helm -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName helm -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            helm help | Select-String -Pattern "^\s+\w+" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Line.Trim(), $_.Line.Trim(), 'ParameterValue', $_.Line.Trim()
                )
            }
        }
    }

    # dotnet completion
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -CommandName dotnet -ScriptBlock {
            param($commandName, $wordToComplete, $cursorPosition)
            dotnet --help | Select-String -Pattern "^\s+\w+" | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Line.Trim(), $_.Line.Trim(), 'ParameterValue', $_.Line.Trim()
                )
            }
        }
    }
}

#endregion THIRD-PARTY CLI TOOL INTEGRATIONS


#region 22 - WELCOME SCREEN AND FINALIZATION
#==============================================================================
<#
.SYNOPSIS
    Welcome screen and profile finalization
.DESCRIPTION
    Displays welcome information and finalizes profile loading.
#>

function Show-WelcomeScreen {
    <#
    .SYNOPSIS
        Displays the profile welcome screen.
    .DESCRIPTION
        Shows system information and profile status on load.
    .PARAMETER Style
        Display style: Full, Minimal, or None.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Full', 'Minimal', 'None')]
        [string]$Style = 'Full'
    )

    if ($Style -eq 'None') { return }

    $loadTime = (Get-Date) - $Global:ProfileLoadStart

    if ($Style -eq 'Full') {
        Write-Host ""
        Write-Host "    ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "    ║               PowerShell 7.5+ Professional Profile           ║" -ForegroundColor Cyan
        Write-Host "    ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
        Write-Host "    ║  Version: $script:ProfileVersion" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * (53 - $script:ProfileVersion.Length))║" -ForegroundColor Cyan
        Write-Host "    ║  Load Time: $($loadTime.TotalMilliseconds) ms" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * (50 - $loadTime.TotalMilliseconds.ToString().Length))║" -ForegroundColor Cyan
        Write-Host "    ║  Admin: $(if (Test-Admin) { 'Yes' } else { 'No' })" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * 56)║" -ForegroundColor Cyan
        Write-Host "    ║  Modules Loaded: $($Global:ProfileStats.ModulesLoaded)" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * (48 - $Global:ProfileStats.ModulesLoaded.ToString().Length))║" -ForegroundColor Cyan
        Write-Host "    ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        # Quick tips
        Write-Host "    Quick Tips:" -ForegroundColor Yellow
        Write-Host "      • Type 'helpme' for command reference" -ForegroundColor DarkGray
        Write-Host "      • Type 'diag' for profile diagnostics" -ForegroundColor DarkGray
        Write-Host "      • Type 'sysinfo' for system information" -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  PowerShell Profile v$script:ProfileVersion loaded in $($loadTime.TotalMilliseconds)ms" -ForegroundColor Cyan
        Write-Host "  Type 'helpme' for quick reference" -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Show-ProfileSummary {
    <#
    .SYNOPSIS
        Shows a summary of profile capabilities.
    .DESCRIPTION
        Displays available functions and modules in the profile.
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== Profile Summary ===" -ForegroundColor Cyan

    # Profile functions
    $functions = Get-Command -CommandType Function | Where-Object { 
        $_.Source -eq '' -and $_.Name -match '^(Get|Set|Test|Show|Invoke|Initialize|Clear|Update|Repair|Reset|Restart|Stop|Find|Measure|Use)-' 
    } | Select-Object -ExpandProperty Name | Sort-Object

    Write-Host "`nAvailable Functions ($($functions.Count)):" -ForegroundColor Yellow
    $functions | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    # Aliases
    $aliases = Get-Alias | Where-Object { $_.Source -eq '' } | Select-Object Name, Definition | Sort-Object Name
    Write-Host "`nAliases ($($aliases.Count)):" -ForegroundColor Yellow
    $aliases | ForEach-Object { Write-Host "  $($_.Name) -> $($_.Definition)" -ForegroundColor DarkGray }

    # Loaded modules
    $modules = Get-Module | Select-Object -ExpandProperty Name | Sort-Object
    Write-Host "`nLoaded Modules ($($modules.Count)):" -ForegroundColor Yellow
    $modules | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

    Write-Host ""
}

# Profile load completion
$Global:ProfileLoadEnd = Get-Date
$Global:ProfileLoadDuration = $Global:ProfileLoadEnd - $Global:ProfileLoadStart
$Global:ProfileLoadedTimestamp = $Global:ProfileLoadEnd

# Log completion
Write-ProfileLog "Profile loaded in $($Global:ProfileLoadDuration.TotalMilliseconds)ms" -Level INFO -Component "Bootstrap"

# Rotate logs periodically
Invoke-ProfileLogRotation | Out-Null

# Show welcome screen for interactive sessions
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.WelcomeScreen.Show) {
    Show-WelcomeScreen -Style $Global:ProfileConfig.WelcomeScreen.Style
}

#endregion WELCOME SCREEN AND FINALIZATION

#region 23 - EXIT HANDLERS AND CLEANUP
#==============================================================================
<#
.SYNOPSIS
    Exit handlers and cleanup
.DESCRIPTION
    Registers cleanup actions for profile exit.
#>

# Register exit action
function Register-ExitAction {
    <#
    .SYNOPSIS
        Registers an action to run on profile exit.
    .DESCRIPTION
        Adds a script block to be executed when PowerShell exits.
    .PARAMETER Action
        Script block to execute.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock]$Action)

    $global:OnExitActions += $Action
}

# --- FIX: Remove unsupported OnRemove handler and use Register-EngineEvent for exit ---
if (-not (Get-EventSubscriber -SourceIdentifier 'PowerShell.Exiting' -ErrorAction SilentlyContinue)) {
    Register-EngineEvent PowerShell.Exiting -Action {
        foreach ($action in $global:OnExitActions) {
            try { & $action } catch {}
        }
    } | Out-Null
}

#endregion EXIT HANDLERS AND CLEANUP

#==============================================================================
# PROFILE END
#==============================================================================
# This PowerShell profile is complete and self-contained.
# For support and updates, refer to:
# - Microsoft Learn: https://learn.microsoft.com/powershell/
# - PowerShell Gallery: https://www.powershellgallery.com/
# - PSReadLine: https://github.com/PowerShell/PSReadLine
# - Oh-My-Posh: https://ohmyposh.dev/
#==============================================================================
