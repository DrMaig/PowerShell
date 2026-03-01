<#
.SYNOPSIS
    Profile component 02 - Platform Detection And Global Flags
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 2 (PLATFORM DETECTION AND GLOBAL FLAGS) for modular dot-sourced loading.
#>

#region 2 - PLATFORM DETECTION AND GLOBAL FLAGS
#==============================================================================

function ConvertTo-ProfileHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-ProfileHashtable -InputObject $InputObject[$key]
        }
        return $result
    }

    if (($InputObject -is [System.Collections.IEnumerable]) -and -not ($InputObject -is [string])) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += , (ConvertTo-ProfileHashtable -InputObject $item)
        }
        return $result
    }

    if ($InputObject -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $result[$prop.Name] = ConvertTo-ProfileHashtable -InputObject $prop.Value
        }
        return $result
    }

    return $InputObject
}

function Merge-ProfileConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,

        [Parameter(Mandatory)]
        [hashtable]$Override
    )

    foreach ($key in $Override.Keys) {
        if ($Base.Contains($key) -and ($Base[$key] -is [System.Collections.IDictionary]) -and ($Override[$key] -is [System.Collections.IDictionary])) {
            $nestedBase = [hashtable](ConvertTo-ProfileHashtable -InputObject $Base[$key])
            $nestedOverride = [hashtable](ConvertTo-ProfileHashtable -InputObject $Override[$key])
            $Base[$key] = Merge-ProfileConfig -Base $nestedBase -Override $nestedOverride
        } else {
            $Base[$key] = $Override[$key]
        }
    }

    return $Base
}

function Get-ProfileConfigDefaults {
    [CmdletBinding()]
    param()

    return [ordered]@{
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

        # Startup control
        StartupMode       = 'full'
        Features          = @{
            UsePSReadLine = $true
            UseWelcomeScreen = $true
            UseDeferredModuleLoader = $true
            UseCompletions = $true
        }

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

        # Error Handling
        ErrorHandling    = @{
            LogCaughtExceptions   = $true
            IncludeScriptStack    = $false
            ReThrowInDebug        = $false
            MaxInnerExceptionDepth = 3
        }

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
            EnablePredictorModules = $true
            PredictorModules = @('CompletionPredictor', 'Az.Tools.Predictor')
            HistoryNoDuplicates = $true
            HistorySearchCursorMovesToEnd = $true
            ShowToolTips = $true
            MaximumKillRingCount = 20
            WordDelimiters = ';:,.[]{}()/\|!?^&*-=+''"–�—―'
            Colors = @{
                Command            = "`e[38;2;78;201;176m"  # Teal
                Parameter          = "`e[38;2;135;206;235m" # Sky blue
                Operator           = "`e[38;2;212;212;212m" # Light gray
                Variable           = "`e[38;2;156;220;254m" # Light blue
                String             = "`e[38;2;206;145;120m" # Salmon
                Number             = "`e[38;2;181;206;168m" # Light green
                Type               = "`e[38;2;78;201;176m"  # Teal
                Comment            = "`e[38;2;106;153;85m"  # Green
                Keyword            = "`e[38;2;86;156;214m"  # Blue
                Error              = "`e[38;2;244;71;71m"   # Red
                Member             = "`e[38;2;79;193;255m"  # Bright blue
                Default            = "`e[38;2;212;212;212m" # Light gray
                Emphasis           = "`e[38;2;220;220;170m" # Yellow
                Selection          = "`e[48;2;38;79;120m"   # Dark blue bg
                InlinePrediction   = "`e[38;2;108;108;108m" # Dark gray
                ListPrediction     = "`e[38;2;78;201;176m"  # Teal
                ListPredictionSelected = "`e[48;2;0;122;204m" # VS Code blue bg
            }
            # Core key bindings (applied via Set-PSReadLineKeyHandler -Function)
            KeyBindings = @{
                'Ctrl+z'       = 'Undo'
                'Ctrl+y'       = 'Redo'
                'Alt+a'        = 'SelectCommandArgument'
            }
        }
        # NetworkProfiles will be initialized later
    }
}

function Get-ProfileConfigPath {
    [CmdletBinding()]
    param()

    $profileRootVar = Get-Variable -Scope Script -Name ProfileRoot -ErrorAction Ignore
    if ($profileRootVar -and $profileRootVar.Value) {
        return (Join-Path $profileRootVar.Value 'powershell.config.json')
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    return (Join-Path $repoRoot 'powershell.config.json')
}

function Import-ProfileRuntimeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BaseConfig
    )

    $configPath = Get-ProfileConfigPath
    if (-not (Test-Path -LiteralPath $configPath)) {
        return $BaseConfig
    }

    try {
        $rawConfig = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -Depth 64 -ErrorAction Stop
        $runtimeConfig = [hashtable](ConvertTo-ProfileHashtable -InputObject $rawConfig)
    } catch {
        Write-Warning "Profile config could not be loaded from '$configPath': $($_.Exception.Message). Using defaults."
        return $BaseConfig
    }

    if ($runtimeConfig.Contains('Profile') -and ($runtimeConfig.Profile -is [System.Collections.IDictionary])) {
        $BaseConfig = Merge-ProfileConfig -Base $BaseConfig -Override ([hashtable](ConvertTo-ProfileHashtable -InputObject $runtimeConfig.Profile))
    }

    if ($runtimeConfig.Contains('LoggingEnabled')) {
        $BaseConfig.EnableLogging = [bool]$runtimeConfig.LoggingEnabled
    }

    if ($runtimeConfig.Contains('StartupMode') -and $runtimeConfig.StartupMode) {
        $BaseConfig.StartupMode = [string]$runtimeConfig.StartupMode
    }

    if ($runtimeConfig.Contains('User') -and ($runtimeConfig.User -is [System.Collections.IDictionary]) -and $runtimeConfig.User.Contains('Editor')) {
        $BaseConfig.Editor = [string]$runtimeConfig.User.Editor
    }

    if ($runtimeConfig.Contains('Features') -and ($runtimeConfig.Features -is [System.Collections.IDictionary])) {
        if ($runtimeConfig.Features.Contains('UsePSReadLine')) {
            $BaseConfig.Features.UsePSReadLine = [bool]$runtimeConfig.Features.UsePSReadLine
        }
        if ($runtimeConfig.Features.Contains('UseOhMyPosh')) {
            $BaseConfig.EnableOhMyPosh = [bool]$runtimeConfig.Features.UseOhMyPosh
        }
        if ($runtimeConfig.Features.Contains('UseWelcomeScreen')) {
            $BaseConfig.WelcomeScreen.Show = [bool]$runtimeConfig.Features.UseWelcomeScreen
            $BaseConfig.Features.UseWelcomeScreen = [bool]$runtimeConfig.Features.UseWelcomeScreen
        }
        if ($runtimeConfig.Features.Contains('UseDeferredModuleLoader')) {
            $BaseConfig.Features.UseDeferredModuleLoader = [bool]$runtimeConfig.Features.UseDeferredModuleLoader
        }
        if ($runtimeConfig.Features.Contains('UseCompletions')) {
            $BaseConfig.Features.UseCompletions = [bool]$runtimeConfig.Features.UseCompletions
        }
    }

    if ($runtimeConfig.Contains('Modules') -and ($runtimeConfig.Modules -is [System.Collections.IDictionary]) -and $runtimeConfig.Modules.Contains('ImportOnStartup')) {
        $importOnStartup = @($runtimeConfig.Modules.ImportOnStartup | Where-Object { $_ })
        if ($importOnStartup.Count -gt 0) {
            $BaseConfig.DeferredLoader.Modules = $importOnStartup
        }
    }

    switch -Regex ($BaseConfig.StartupMode) {
        '^(minimal|safe)$' {
            $BaseConfig.ShowDiagnostics = $false
            $BaseConfig.WelcomeScreen.Show = $false
            $BaseConfig.Features.UseWelcomeScreen = $false
            $BaseConfig.Features.UseDeferredModuleLoader = $false
            $BaseConfig.DeferredLoader.Modules = @()
            $BaseConfig.EnableOhMyPosh = $false
            $BaseConfig.EnableTerminalIcons = $false
            $BaseConfig.EnablePoshGit = $false
            break
        }
        default { }
    }

    return $BaseConfig
}

$defaultProfileConfig = Get-ProfileConfigDefaults
if (Test-Path variable:global:ProfileConfig) {
    $externalProfileConfigValue = $Global:ProfileConfig
} else {
    $externalProfileConfigValue = $null
}
if ($externalProfileConfigValue -and ($externalProfileConfigValue -is [System.Collections.IDictionary])) {
    $externalProfileConfig = [hashtable](ConvertTo-ProfileHashtable -InputObject $externalProfileConfigValue)
    $defaultProfileConfig = Merge-ProfileConfig -Base $defaultProfileConfig -Override $externalProfileConfig
}

$Global:ProfileConfig = Import-ProfileRuntimeConfig -BaseConfig $defaultProfileConfig

# Ensure ErrorHandling defaults exist even when ProfileConfig was preloaded externally
if (-not $Global:ProfileConfig.Contains('ErrorHandling')) {
    $Global:ProfileConfig.ErrorHandling = @{}
}
if ($null -eq $Global:ProfileConfig.ErrorHandling.LogCaughtExceptions) { $Global:ProfileConfig.ErrorHandling.LogCaughtExceptions = $true }
if ($null -eq $Global:ProfileConfig.ErrorHandling.IncludeScriptStack) { $Global:ProfileConfig.ErrorHandling.IncludeScriptStack = $false }
if ($null -eq $Global:ProfileConfig.ErrorHandling.ReThrowInDebug) { $Global:ProfileConfig.ErrorHandling.ReThrowInDebug = $false }
if ($null -eq $Global:ProfileConfig.ErrorHandling.MaxInnerExceptionDepth) { $Global:ProfileConfig.ErrorHandling.MaxInnerExceptionDepth = 3 }

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
    } catch {
        Write-ProfileLog "Failed to ensure directory '$p': $($_.Exception.Message)" -Level DEBUG -Component "Bootstrap"
    }
}

#endregion PLATFORM DETECTION AND GLOBAL FLAGS
