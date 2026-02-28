#Requires -Version 7.5
<# ==============================================================================
   POWERSHELL 7.5+ PROFILE  —  Windows Terminal · Windows 10/11 x64
   ------------------------------------------------------------------------------
   Sections (use Ctrl+M in VS Code to fold/expand):
     1.  Bootstrap & Safety Guards
     2.  Oh-My-Posh
     3.  PSReadLine Configuration
     4.  Completion Predictors & Plugins
     5.  Package-Manager Tab Completions
     6.  Runtime & Framework Completions
     7.  System Information & Hardware
     8.  OS Health, Repair & Optimisation
    10.  Network Administration & Diagnostics
    11.  Security Auditing & Hardening
    12.  Event-Log & Error Analysis
    13.  Performance & Monitoring
    14.  Update Orchestration
    15.  Prompt Utilities & Aliases
   ============================================================================== #>

#region ── 1. BOOTSTRAP & SAFETY GUARDS ───────────────────────────────────────

Set-StrictMode -Version Latest

# Ensure the profile runs only on Windows
if (-not $IsWindows) {
    Write-Warning 'This profile targets Windows 10/11 x64. Non-Windows platform detected — aborting.'
    return
}

# Resolve profile directory early for use throughout the file
$Script:ProfileDir = Split-Path -Parent $PROFILE

# Elevaton helper — referenced later; not a built-in name
function Test-AdminPrivilege {
    [OutputType([bool])]
    param()
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$Script:IsAdmin = Test-AdminPrivilege

# Silent module-importer — installs from PSGallery only when missing
function Import-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$MinimumVersion
    )
    $installed = Get-Module -Name $Name -ListAvailable -ErrorAction Ignore
    if (-not $installed) {
        Write-Host "  Installing module: $Name …" -ForegroundColor Cyan
        $installSplat = @{ Name = $Name; Scope = 'CurrentUser'; Force = $true; AllowClobber = $true; ErrorAction = 'SilentlyContinue' }
        if ($MinimumVersion) { $installSplat['MinimumVersion'] = $MinimumVersion }
        Install-Module @installSplat
    } elseif ($MinimumVersion) {
        $maxVer = ($installed | Sort-Object Version -Descending | Select-Object -First 1).Version
        if ($maxVer -lt [version]$MinimumVersion) {
            Write-Host "  Updating module: $Name to $MinimumVersion …" -ForegroundColor Cyan
            Install-Module -Name $Name -MinimumVersion $MinimumVersion -Scope CurrentUser -Force -AllowClobber -ErrorAction Ignore
        }
    }
    Import-Module -Name $Name -ErrorAction Ignore
}

#endregion

#region ── 2. OH-MY-POSH ──────────────────────────────────────────────────────
# Theme: "atomic" (preferred) with fallbacks to other popular themes
# Requires: winget install JanDeDobbeleer.OhMyPosh  (or scoop install oh-my-posh)

if (Get-Command oh-my-posh -ErrorAction Ignore) {
    $themeOrder = @('atomic', 'powerlevel10k_rainbow', 'paradox', 'jandedobbeleer', 'agnoster')
    $themeLoaded = $false
    
    foreach ($theme in $themeOrder) {
        $themePath = "$env:POSH_THEMES_PATH\$theme.omp.json"
        if (Test-Path $themePath) {
            try {
                Invoke-Expression (& oh-my-posh init pwsh --config $themePath 2>$null)
                $themeLoaded = $true
                break
            } catch {
                continue
            }
        }
    }
    
    if (-not $themeLoaded) {
        Write-Host '[Profile] No Oh-My-Posh theme found. Using default prompt.' -ForegroundColor Yellow
        Write-Host "  Available themes: Get-ChildItem `"$env:POSH_THEMES_PATH`"" -ForegroundColor DarkGray
    }
} else {
    Write-Host '[Profile] oh-my-posh not found. Install with: winget install JanDeDobbeleer.OhMyPosh' -ForegroundColor Yellow
}

#endregion

#region ── 3. PSREADLINE CONFIGURATION ────────────────────────────────────────

Import-RequiredModule -Name 'PSReadLine' -MinimumVersion '2.3.0'

# Core behaviour
Set-PSReadLineOption -EditMode                   Windows
Set-PSReadLineOption -HistorySaveStyle           SaveIncrementally
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount        32767
Set-PSReadLineOption -HistoryNoDuplicates

# Prediction — ListView uses history + installed predictors
Set-PSReadLineOption -PredictionSource    HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Colours (Terminal-safe ANSI)
Set-PSReadLineOption -Colors @{
    Command            = "`e[38;2;97;175;239m"   # Cornflower blue
    Parameter          = "`e[38;2;198;120;221m"  # Lavender
    String             = "`e[38;2;152;195;121m"  # Sage green
    Variable           = "`e[38;2;224;182;100m"  # Amber
    Comment            = "`e[38;2;92;99;112m"    # Dim grey
    Keyword            = "`e[38;2;198;120;221m"  # Lavender
    Type               = "`e[38;2;86;182;194m"   # Teal
    Number             = "`e[38;2;209;154;102m"  # Warm orange
    Operator           = "`e[38;2;171;178;191m"  # Light grey
    InlinePrediction   = "`e[38;2;80;87;99m"     # Subtle grey
    ListPrediction     = "`e[38;2;97;175;239m"
    ListPredictionSelected = "`e[48;2;40;44;52;38;2;255;255;255m"
}

# Key bindings
Set-PSReadLineKeyHandler -Key Tab                -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab          -Function TabCompletePrevious
Set-PSReadLineKeyHandler -Key UpArrow            -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow          -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+d             -Function DeleteCharOrExit
Set-PSReadLineKeyHandler -Key Ctrl+w             -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow     -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow    -Function ForwardWord
Set-PSReadLineKeyHandler -Key F7 -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    $pattern = [regex]::Escape($pattern)
    $history = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() |
               Where-Object CommandLine -match $pattern |
               Select-Object -ExpandProperty CommandLine -Unique |
               Sort-Object -Descending
    if ($history) {
        $chosen = $history | Out-GridView -Title 'Command History' -OutputMode Single
        if ($chosen) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($chosen)
        }
    }
}

# Smart quote & bracket pairing
@(
    @{ Open = '"'; Close = '"' }
    @{ Open = "'"; Close = "'" }
    @{ Open = '('; Close = ')' }
    @{ Open = '{'; Close = '}' }
    @{ Open = '['; Close = ']' }
) | ForEach-Object {
    $open  = $_.Open
    $close = $_.Close
    Set-PSReadLineKeyHandler -Chord $open -ScriptBlock {
        param($key, $arg)
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$open$close")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }.GetNewClosure()
}

#endregion

#region ── 4. COMPLETION PREDICTORS & PLUGINS ─────────────────────────────────

# Az.Tools.Predictor — Azure CLI history-aware completions
Import-RequiredModule -Name 'Az.Tools.Predictor'

# CompletionPredictor — general plugin predictor host
Import-RequiredModule -Name 'CompletionPredictor'

# PSFzf — fuzzy-finder integration (requires fzf in PATH)
if (Get-Command fzf -ErrorAction Ignore) {
    Import-RequiredModule -Name 'PSFzf'
    if (Get-Module PSFzf -ErrorAction Ignore) {
        # PSFzf sets up its own key bindings; configure them here
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction Ignore
    }
} else {
    Write-Host '[Profile] fzf not found. Install with: winget install junegunn.fzf' -ForegroundColor DarkYellow
}

# Terminal-Icons — file-type icons in listings (safe to import always)
Import-RequiredModule -Name 'Terminal-Icons'

# Posh-Git — Git prompt integration
Import-RequiredModule -Name 'posh-git'

#endregion

#region ── 5. PACKAGE-MANAGER TAB COMPLETIONS ─────────────────────────────────

# ── Winget ──────────────────────────────────────────────────────────────────
if (Get-Command winget -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        $Local:word   = $wordToComplete.Replace('"', '""')
        $Local:ast    = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── Scoop ────────────────────────────────────────────────────────────────────
if (Get-Command scoop -ErrorAction Ignore) {
    Import-RequiredModule -Name 'scoop-completion'
}

# ── Chocolatey ───────────────────────────────────────────────────────────────
$Script:ChocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $Script:ChocoProfile) {
    Import-Module $Script:ChocoProfile -ErrorAction Ignore
}

# ── npm / Node ───────────────────────────────────────────────────────────────
if (Get-Command npm -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName npm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $npmCmd = $commandAst.ToString() -replace '^npm\s*', ''
        npm completion -- $npmCmd 2>$null |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── pnpm ─────────────────────────────────────────────────────────────────────
if (Get-Command pnpm -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName pnpm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        pnpm completion pwsh -- $commandAst.ToString() 2>$null |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── pip / pipx ───────────────────────────────────────────────────────────────
foreach ($cmd in @('pip', 'pip3', 'pipx')) {
    if (Get-Command $cmd -ErrorAction Ignore) {
        Register-ArgumentCompleter -Native -CommandName $cmd -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $env:_PIP_COMPLETE = 'powershell'
            $line = $commandAst.ToString()
            & $cmd complete --word="$wordToComplete" --cmd="$line" 2>$null |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new(
                        $_, $_, 'ParameterValue', $_)
                }
            Remove-Item Env:\_PIP_COMPLETE -ErrorAction Ignore
        }
    }
}

# ── Cargo (Rust) ─────────────────────────────────────────────────────────────
if (Get-Command cargo -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName cargo -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $words = $commandAst.ToString().Trim().Split() | Select-Object -Skip 1
        cargo --list 2>$null | Select-String '^\s+\S+' |
            Where-Object { $_ -like "*$wordToComplete*" } |
            ForEach-Object {
                $c = $_.ToString().Trim().Split()[0]
                [System.Management.Automation.CompletionResult]::new(
                    $c, $c, 'ParameterValue', $c)
            }
    }
}

#endregion

#region ── 6. RUNTIME & FRAMEWORK COMPLETIONS ─────────────────────────────────

# ── .NET SDK / dotnet CLI ────────────────────────────────────────────────────
if (Get-Command dotnet -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition $commandAst.ToString() 2>$null |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── Rustup ──────────────────────────────────────────────────────────────────
if (Get-Command rustup -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName rustup -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        rustup completions powershell 2>$null | Invoke-Expression
        # Fallback: simple subcommand list
        rustup help 2>$null | Select-String '^\s{4}\S+' |
            Where-Object { $_ -like "*$wordToComplete*" } |
            ForEach-Object {
                $c = $_.ToString().Trim().Split()[0]
                [System.Management.Automation.CompletionResult]::new(
                    $c, $c, 'ParameterValue', $c)
            }
    }
}

# ── Go toolchain ─────────────────────────────────────────────────────────────
if (Get-Command go -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName go -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @('build','clean','doc','env','bug','fix','fmt','generate',
                         'get','install','list','mod','run','test','tool','version','vet','work')
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_, $_, 'ParameterValue', $_)
            }
    }
}

# ── Python / uv ──────────────────────────────────────────────────────────────
if (Get-Command uv -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName uv -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        uv --generate-shell-completion powershell 2>$null | Invoke-Expression -ErrorAction Ignore
    }
}

# ── PowerShell module / script completions ────────────────────────────────────
if (Get-Command gh -ErrorAction Ignore) {
    Invoke-Expression (& gh completion -s powershell 2>$null)
}

#endregion

#region ── 7. SYSTEM INFORMATION & HARDWARE ───────────────────────────────────

function Get-SystemSummary {
<#
.SYNOPSIS  Returns a structured summary of CPU, RAM, OS, and uptime.
.EXAMPLE   Get-SystemSummary
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $os  = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $cs  = Get-CimInstance -ClassName Win32_ComputerSystem

    [PSCustomObject]@{
        ComputerName    = $env:COMPUTERNAME
        OS              = "$($os.Caption) Build $($os.BuildNumber)"
        Architecture    = $os.OSArchitecture
        CPU             = $cpu.Name.Trim()
        Cores           = "$($cpu.NumberOfCores) physical / $($cpu.NumberOfLogicalProcessors) logical"
        RAM_GB          = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        RAM_Free_GB     = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        Uptime          = (Get-Date) - $os.LastBootUpTime
        LastBoot        = $os.LastBootUpTime
        TimeZone        = (Get-TimeZone).DisplayName
        PSVersion       = $PSVersionTable.PSVersion.ToString()
    }
}

function Get-CpuDetail {
<#
.SYNOPSIS  Returns detailed CPU metrics including utilisation and clock speeds.
#>
    [CmdletBinding()]
    param()
    Get-CimInstance -ClassName Win32_Processor | ForEach-Object {
        [PSCustomObject]@{
            Name            = $_.Name.Trim()
            Manufacturer    = $_.Manufacturer
            PhysicalCores   = $_.NumberOfCores
            LogicalCores    = $_.NumberOfLogicalProcessors
            MaxClockMHz     = $_.MaxClockSpeed
            CurrentClockMHz = $_.CurrentClockSpeed
            LoadPercent     = $_.LoadPercentage
            SocketDesignation = $_.SocketDesignation
            L2CacheKB       = $_.L2CacheSize
            L3CacheKB       = $_.L3CacheSize
        }
    }
}

function Get-MemoryDetail {
<#
.SYNOPSIS  Returns per-DIMM memory module details from WMI.
#>
    [CmdletBinding()]
    param()
    $slots = Get-CimInstance -ClassName Win32_PhysicalMemory
    if (-not $slots) {
        Write-Warning 'No physical memory data returned (may occur in VMs).'
        return
    }
    $slots | ForEach-Object {
        [PSCustomObject]@{
            Bank            = $_.BankLabel
            Slot            = $_.DeviceLocator
            CapacityGB      = [math]::Round($_.Capacity / 1GB, 2)
            SpeedMHz        = $_.Speed
            Type            = switch ($_.SMBIOSMemoryType) {
                                26 { 'DDR4' } 34 { 'DDR5' } 24 { 'DDR3' } default { "Type $($_.SMBIOSMemoryType)" }
                              }
            Manufacturer    = $_.Manufacturer
            PartNumber      = $_.PartNumber.Trim()
            ConfiguredVolt  = $_.ConfiguredVoltage
        }
    }
}

function Get-GpuDetail {
<#
.SYNOPSIS  Lists all display adapters with VRAM and driver version.
#>
    [CmdletBinding()]
    param()
    Get-CimInstance -ClassName Win32_VideoController | ForEach-Object {
        [PSCustomObject]@{
            Name            = $_.Name
            VRAM_GB         = [math]::Round($_.AdapterRAM / 1GB, 2)
            DriverVersion   = $_.DriverVersion
            DriverDate      = $_.DriverDate
            VideoProcessor  = $_.VideoProcessor
            Resolution      = "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate)Hz"
            Status          = $_.Status
        }
    }
}

function Get-DiskDetail {
<#
.SYNOPSIS  Combines physical disk info with logical volume health and space.
.PARAMETER DriveLetter  Optionally filter to a specific drive (e.g. 'C').
#>
    [CmdletBinding()]
    param([string]$DriveLetter)

    $physicalDisks = Get-PhysicalDisk | Sort-Object DeviceId
    $volumes       = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }

    if ($DriveLetter) {
        $volumes = $volumes | Where-Object { $_.DriveLetter -eq $DriveLetter }
    }

    $volumes | ForEach-Object {
        $vol = $_
        $pd  = $physicalDisks | Where-Object { $_.ObjectId -match "Disk #?$($vol.UniqueId -replace '.*(\d+).*','$1')" } |
               Select-Object -First 1
        [PSCustomObject]@{
            DriveLetter     = $vol.DriveLetter
            Label           = $vol.FileSystemLabel
            FileSystem      = $vol.FileSystem
            SizeGB          = [math]::Round($vol.Size / 1GB, 2)
            FreeGB          = [math]::Round($vol.SizeRemaining / 1GB, 2)
            UsedPct         = if ($vol.Size -gt 0) { [math]::Round((1 - $vol.SizeRemaining / $vol.Size) * 100, 1) } else { 0 }
            HealthStatus    = $vol.HealthStatus
            MediaType       = if ($pd) { $pd.MediaType } else { 'Unknown' }
            BusType         = if ($pd) { $pd.BusType   } else { 'Unknown' }
            Model           = if ($pd) { $pd.FriendlyName } else { 'N/A' }
        }
    }
}

function Get-BatteryStatus {
<#
.SYNOPSIS  Reports battery level, charge state, and estimated runtime.
#>
    [CmdletBinding()]
    param()
    $bat = Get-CimInstance -ClassName Win32_Battery
    if (-not $bat) { Write-Host 'No battery detected (desktop system).' -ForegroundColor Cyan; return }
    $bat | ForEach-Object {
        [PSCustomObject]@{
            Name             = $_.Name
            EstChargePercent = $_.EstimatedChargeRemaining
            StatusText       = switch ($_.BatteryStatus) {
                                 1 { 'Discharging' } 2 { 'AC / Plugged In' }
                                 3 { 'Fully Charged' } 4 { 'Low' } 5 { 'Critical' }
                                 default { "Code $($_.BatteryStatus)" }
                               }
            EstRuntimeMin    = $_.EstimatedRunTime
            ChemistryText    = switch ($_.Chemistry) {
                                 3 { 'Lead Acid' } 4 { 'NiCd' } 5 { 'NiMH' }
                                 6 { 'Li-Ion' } 7 { 'Zinc Air' } default { 'Other' }
                               }
        }
    }
}

function Get-HardwareSummary {
<#
.SYNOPSIS  Convenience wrapper that outputs all hardware facts in one call.
#>
    [CmdletBinding()]
    param()
    Write-Host "`n═══ SYSTEM ═══" -ForegroundColor Cyan;  Get-SystemSummary  | Format-List
    Write-Host "`n═══ CPU ══════" -ForegroundColor Cyan;  Get-CpuDetail      | Format-List
    Write-Host "`n═══ MEMORY ═══" -ForegroundColor Cyan;  Get-MemoryDetail   | Format-Table -AutoSize
    Write-Host "`n═══ GPU ══════" -ForegroundColor Cyan;  Get-GpuDetail      | Format-List
    Write-Host "`n═══ DISKS ════" -ForegroundColor Cyan;  Get-DiskDetail     | Format-Table -AutoSize
    Write-Host "`n═══ BATTERY ══" -ForegroundColor Cyan;  Get-BatteryStatus  | Format-List
}

#endregion

#region ── 8. OS HEALTH, REPAIR & OPTIMISATION ────────────────────────────────

function Invoke-SystemFileCheck {
<#
.SYNOPSIS  Runs SFC /scannow with optional DISM restoration, requires elevation.
.PARAMETER RepairDism  Also run DISM RestoreHealth before SFC.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$RepairDism)

    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required. Re-run as Administrator.'; return }

    if ($RepairDism) {
        if ($PSCmdlet.ShouldProcess('DISM', 'RestoreHealth')) {
            Write-Host 'Running DISM RestoreHealth …' -ForegroundColor Cyan
            & dism.exe /Online /Cleanup-Image /RestoreHealth
        }
    }
    if ($PSCmdlet.ShouldProcess('SFC', 'scannow')) {
        Write-Host 'Running SFC …' -ForegroundColor Cyan
        & sfc.exe /scannow
    }
}

function Invoke-DiskCleanup {
<#
.SYNOPSIS  Triggers Disk Cleanup in silent / sageset-1 mode.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required.'; return }
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Disk Cleanup (sageset 1)')) {
        & cleanmgr.exe /sagerun:1
    }
}

function Optimize-SystemDrive {
<#
.SYNOPSIS  Runs Defrag / TRIM depending on drive media type.
.PARAMETER DriveLetter  Target drive letter (default: C).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$DriveLetter = 'C')

    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required.'; return }
    $vol = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop
    if ($PSCmdlet.ShouldProcess("Drive $DriveLetter", 'Optimize-Volume')) {
        Write-Host "Optimising drive $DriveLetter ($($vol.FileSystemLabel)) …" -ForegroundColor Cyan
        Optimize-Volume -DriveLetter $DriveLetter -Verbose
    }
}

function Test-SystemHealth {
<#
.SYNOPSIS  Non-destructive health snapshot: event errors, disk, memory, services.
.OUTPUTS   PSCustomObject with a Pass/Warn/Fail grade per category.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Host 'Analysing system health …' -ForegroundColor Cyan

    # Disk health
    $diskHealth = (Get-Disk | Where-Object HealthStatus -ne 'Healthy').Count
    # Critical application events in last 24 h
    $appErrors = (Get-WinEvent -FilterHashtable @{
        LogName   = 'Application'
        Level     = 2           # Error
        StartTime = (Get-Date).AddHours(-24)
    } -ErrorAction Ignore).Count
    # Memory: available MB
    $freeMemMB = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024
    # Services that should be running but are stopped
    $stoppedCritical = @('WinDefend','EventLog','BITS','wuauserv') | ForEach-Object {
        $svc = Get-Service -Name $_ -ErrorAction Ignore
        if ($svc -and $svc.Status -ne 'Running') { $svc.Name }
    }

    [PSCustomObject]@{
        DiskHealthIssues      = $diskHealth
        AppErrorsLast24h      = $appErrors
        FreeMemoryMB          = [math]::Round($freeMemMB, 0)
        StoppedCriticalSvcs   = if ($stoppedCritical) { $stoppedCritical -join ', ' } else { 'None' }
        Grade                 = if ($diskHealth -gt 0 -or $stoppedCritical) { 'FAIL' }
                                elseif ($appErrors -gt 50 -or $freeMemMB -lt 512) { 'WARN' }
                                else { 'PASS' }
    }
}

function Get-StartupProgram {
<#
.SYNOPSIS  Lists all user and machine startup entries from registry and WMI.
#>
    [CmdletBinding()]
    param([switch]$IncludeWMI)

    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )

    $results = foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $hive = if ($path -like 'HKLM:*') { 'HKLM' } else { 'HKCU' }
            $key  = Get-ItemProperty -Path $path -ErrorAction Ignore
            $key.PSObject.Properties |
                Where-Object { $_.Name -notmatch '^PS' } |
                ForEach-Object {
                    [PSCustomObject]@{
                        Source = $hive
                        Name   = $_.Name
                        Command = $_.Value
                    }
                }
        }
    }

    if ($IncludeWMI) {
        Get-CimInstance -ClassName Win32_StartupCommand | ForEach-Object {
            [PSCustomObject]@{
                Source  = "WMI ($($_.Location))"
                Name    = $_.Name
                Command = $_.Command
            }
        }
    } else { $results }

    if (-not $results) { Write-Host 'No startup entries found.' }
}

function Get-WindowsActivationStatus {
<#
.SYNOPSIS  Shows Windows licence and activation state.
#>
    [CmdletBinding()]
    param()
    $lic = Get-CimInstance -ClassName SoftwareLicensingProduct |
           Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey }
    $lic | Select-Object Name,
        @{N='Status'; E={ switch ($_.LicenseStatus) {
            0 {'Unlicensed'} 1 {'Licensed'} 2 {'OOBGrace'} 3 {'OOTGrace'} 4 {'NonGenuine'} default {'Unknown'}
        }}},
        LicenseFamily, PartialProductKey |
        Format-List
}

#endregion

#region ── 9. APPLICATION & PACKAGE MANAGEMENT ────────────────────────────────

function Get-InstalledApp {
<#
.SYNOPSIS  Searches installed applications across 32-bit and 64-bit registry hives.
.PARAMETER Name  Wildcard filter (default: * — all).
.EXAMPLE   Get-InstalledApp -Name '*Visual Studio*'
#>
    [CmdletBinding()]
    param([string]$Name = '*')

    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $regPaths | ForEach-Object {
        Get-ItemProperty $_ -ErrorAction Ignore
    } |
        Where-Object { $_.DisplayName -and $_.DisplayName -like $Name } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate,
                      @{N='InstallSize_MB'; E={ [math]::Round($_.EstimatedSize / 1024, 1) }},
                      UninstallString |
        Sort-Object DisplayName
}

function Find-RunningProcess {
<#
.SYNOPSIS  Finds running processes matching a name or window title pattern.
.PARAMETER Name   Wildcard process name.
.PARAMETER Title  Wildcard main window title.
#>
    [CmdletBinding()]
    param(
        [string]$Name  = '*',
        [string]$Title = '*'
    )
    Get-Process -ErrorAction Ignore |
        Where-Object { $_.Name -like $Name -and $_.MainWindowTitle -like $Title } |
        Select-Object Id, Name, MainWindowTitle,
            @{N='CPU_s';   E={ [math]::Round($_.CPU, 1) }},
            @{N='RAM_MB';  E={ [math]::Round($_.WorkingSet64 / 1MB, 1) }},
            @{N='Threads'; E={ $_.Threads.Count }},
            Path |
        Sort-Object RAM_MB -Descending
}

function Stop-ProcessByName {
<#
.SYNOPSIS  Gracefully stops (then force-kills) a process by name.
.PARAMETER Name     Process name (wildcards supported).
.PARAMETER Force    Skip graceful close and kill immediately.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )
    $procs = Get-Process -Name $Name -ErrorAction Ignore
    if (-not $procs) { Write-Warning "No process matching '$Name' found."; return }
    foreach ($p in $procs) {
        if ($PSCmdlet.ShouldProcess("$($p.Name) (PID $($p.Id))", 'Stop-Process')) {
            if ($Force) {
                Stop-Process -InputObject $p -Force
            } else {
                $p.CloseMainWindow() | Out-Null
                Start-Sleep -Seconds 2
                if (-not $p.HasExited) { Stop-Process -InputObject $p -Force }
            }
        }
    }
}

function Get-ServiceDetail {
<#
.SYNOPSIS  Returns extended service info including binary path and startup account.
.PARAMETER Name    Service name or wildcard.
.PARAMETER Status  Filter by Running, Stopped, etc.
#>
    [CmdletBinding()]
    param(
        [string]$Name   = '*',
        [string]$Status = '*'
    )
    Get-CimInstance -ClassName Win32_Service |
        Where-Object { $_.Name -like $Name -and $_.State -like $Status } |
        Select-Object Name, DisplayName, State, StartMode,
            StartName, PathName, Description |
        Sort-Object State, Name
}

function Set-ServiceStartupType {
<#
.SYNOPSIS  Changes a Windows service start type (requires elevation for system services).
.PARAMETER ServiceName  Exact service name.
.PARAMETER StartupType  Automatic | AutomaticDelayedStart | Manual | Disabled.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ServiceName,
        [Parameter(Mandatory)]
        [ValidateSet('Automatic','AutomaticDelayedStart','Manual','Disabled')]
        [string]$StartupType
    )
    if ($PSCmdlet.ShouldProcess($ServiceName, "Set-Service StartupType=$StartupType")) {
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        Write-Host "Service '$ServiceName' startup type set to '$StartupType'." -ForegroundColor Green
    }
}

#endregion

#region ── 10. NETWORK ADMINISTRATION & DIAGNOSTICS ───────────────────────────

function Get-NetworkAdapterDetail {
<#
.SYNOPSIS  Lists active adapters with IP, MAC, speed, and link state.
#>
    [CmdletBinding()]
    param([switch]$IncludeDisabled)

    $adapters = Get-NetAdapter
    if (-not $IncludeDisabled) { $adapters = $adapters | Where-Object Status -eq 'Up' }

    $adapters | ForEach-Object {
        $ad    = $_
        $ipCfg = Get-NetIPAddress -InterfaceIndex $ad.ifIndex -ErrorAction Ignore
        $dns   = Get-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -AddressFamily IPv4 -ErrorAction Ignore
        [PSCustomObject]@{
            Name         = $ad.Name
            Description  = $ad.InterfaceDescription
            Status       = $ad.Status
            MAC          = $ad.MacAddress
            SpeedMbps    = if ($ad.LinkSpeed) { ($ad.LinkSpeed -replace '[^0-9]', '') / 1MB } else { 'N/A' }
            IPv4         = ($ipCfg | Where-Object AddressFamily -eq 'IPv4').IPAddress -join ', '
            IPv6         = ($ipCfg | Where-Object AddressFamily -eq 'IPv6' |
                            Where-Object { $_.IPAddress -notlike 'fe80*' }).IPAddress -join ', '
            DNSServers   = $dns.ServerAddresses -join ', '
            DHCP         = (Get-NetIPInterface -InterfaceIndex $ad.ifIndex -AddressFamily IPv4 -ErrorAction Ignore).Dhcp
        }
    }
}

function Get-ActiveConnection {
<#
.SYNOPSIS  Shows established TCP and UDP connections with owning process names.
.PARAMETER State  TCP state filter (default: Established).
#>
    [CmdletBinding()]
    param(
        [ValidateSet('Established','Listen','TimeWait','CloseWait','All')]
        [string]$State = 'Established'
    )

    $tcpConns = Get-NetTCPConnection -ErrorAction Ignore
    if ($State -ne 'All') { $tcpConns = $tcpConns | Where-Object State -eq $State }

    $tcpConns | ForEach-Object {
        $proc = if ($_.OwningProcess -gt 0) {
                    Get-Process -Id $_.OwningProcess -ErrorAction Ignore |
                        Select-Object -ExpandProperty Name
                } else { 'System' }
        [PSCustomObject]@{
            Protocol    = 'TCP'
            LocalAddr   = "$($_.LocalAddress):$($_.LocalPort)"
            RemoteAddr  = "$($_.RemoteAddress):$($_.RemotePort)"
            State       = $_.State
            PID         = $_.OwningProcess
            ProcessName = $proc
        }
    }
}

function Test-NetworkEndpoint {
<#
.SYNOPSIS  Tests TCP connectivity to a host:port, ping, and optionally DNS.
.PARAMETER HostName   Target hostname or IP.
.PARAMETER Port       TCP port to test (optional).
.PARAMETER Count      ICMP ping count.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostName,
        [int]$Port,
        [int]$Count = 4
    )

    Write-Host "── Ping $HostName ──" -ForegroundColor Cyan
    Test-Connection -TargetName $HostName -Count $Count -ErrorAction Ignore |
        Select-Object Address, Latency, Status | Format-Table -AutoSize

    if ($Port) {
        Write-Host "── TCP $HostName`:$Port ──" -ForegroundColor Cyan
        $result = Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue
        [PSCustomObject]@{
            Host           = $HostName
            Port           = $Port
            TcpTestSucceeded = $result.TcpTestSucceeded
            PingSucceeded  = $result.PingSucceeded
            RemoteAddress  = $result.RemoteAddress
        } | Format-List
    }

    Write-Host "── DNS $HostName ──" -ForegroundColor Cyan
    Resolve-DnsName -Name $HostName -ErrorAction Ignore |
        Select-Object Name, Type, IPAddress, NameHost | Format-Table -AutoSize
}

function Get-DnsConfiguration {
<#
.SYNOPSIS  Shows DNS server assignments for each active adapter.
.PARAMETER SetPrimary   If provided, assigns this DNS to all active adapters.
.PARAMETER SetSecondary Secondary DNS used alongside SetPrimary.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SetPrimary,
        [string]$SetSecondary = '1.1.1.1'
    )

    if ($SetPrimary) {
        if (-not $Script:IsAdmin) { Write-Warning 'Elevation required to change DNS.'; return }
        $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
        foreach ($ad in $adapters) {
            if ($PSCmdlet.ShouldProcess($ad.Name, "Set-DnsClientServerAddress $SetPrimary, $SetSecondary")) {
                Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex `
                    -ServerAddresses @($SetPrimary, $SetSecondary) -ErrorAction Ignore
                Write-Host "DNS set on $($ad.Name) → $SetPrimary, $SetSecondary" -ForegroundColor Green
            }
        }
    } else {
        Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
            $dns = Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction Ignore
            [PSCustomObject]@{
                Adapter    = $_.Name
                DNSServers = $dns.ServerAddresses -join ', '
            }
        }
    }
}

function Get-WifiProfile {
<#
.SYNOPSIS  Lists saved Wi-Fi profiles; optionally exports plaintext key.
.PARAMETER Name      Profile name filter (wildcards).
.PARAMETER ShowKey   Include plaintext PSK (requires elevation).
#>
    [CmdletBinding()]
    param(
        [string]$Name = '*',
        [switch]$ShowKey
    )

    $profiles = (& netsh wlan show profiles 2>$null) -match ':\s+(.+)$' |
                ForEach-Object { $_ -replace '.*:\s+', '' } |
                Where-Object { $_ -like $Name }

    foreach ($p in $profiles) {
        $arg   = if ($ShowKey -and $Script:IsAdmin) { "key=clear" } else { "" }
        $detail = & netsh wlan show profile name="$p" $arg 2>$null
        $key    = if ($ShowKey) {
                      ($detail | Select-String 'Key Content\s*:\s*(.+)').Matches.Groups[1].Value
                  } else { '(hidden)' }
        $auth  = ($detail | Select-String 'Authentication\s*:\s*(.+)').Matches.Groups[1].Value
        [PSCustomObject]@{
            Profile = $p
            Authentication = $auth.Trim()
            PSK     = $key
        }
    }
}

function Get-RoutingTable {
<#
.SYNOPSIS  Returns the IPv4 routing table in a structured format.
#>
    [CmdletBinding()]
    param()
    Get-NetRoute -AddressFamily IPv4 -ErrorAction Ignore |
        Where-Object DestinationPrefix -ne '255.255.255.255/32' |
        Select-Object DestinationPrefix, NextHop, RouteMetric, InterfaceAlias, Protocol |
        Sort-Object RouteMetric, DestinationPrefix
}

function Invoke-NetworkDiagnostic {
<#
.SYNOPSIS  Comprehensive network snapshot: adapters, DNS, routes, external IP, speed estimate.
#>
    [CmdletBinding()]
    param()

    Write-Host "`n═══ ADAPTERS ═════════" -ForegroundColor Cyan
    Get-NetworkAdapterDetail | Format-Table -AutoSize

    Write-Host "`n═══ ACTIVE CONNECTIONS ═" -ForegroundColor Cyan
    Get-ActiveConnection | Select-Object -First 20 | Format-Table -AutoSize

    Write-Host "`n═══ ROUTES ═══════════" -ForegroundColor Cyan
    Get-RoutingTable | Select-Object -First 15 | Format-Table -AutoSize

    Write-Host "`n═══ DNS SERVERS ══════" -ForegroundColor Cyan
    Get-DnsConfiguration | Format-Table -AutoSize

    Write-Host "`n═══ CONNECTIVITY TESTS ═" -ForegroundColor Cyan
    foreach ($target in @('8.8.8.8', '1.1.1.1', 'www.microsoft.com')) {
        $ping = Test-Connection -TargetName $target -Count 2 -ErrorAction Ignore
        $lat  = if ($ping) { ($ping | Measure-Object Latency -Average).Average } else { 'FAIL' }
        Write-Host "  $target  →  $lat ms"
    }

    Write-Host "`n═══ EXTERNAL IP ══════" -ForegroundColor Cyan
    try {
        $ext = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5
        Write-Host "  Public IPv4: $($ext.ip)"
    } catch {
        Write-Host '  Could not retrieve external IP.' -ForegroundColor Yellow
    }
}

function Get-FirewallRule {
<#
.SYNOPSIS  Lists firewall rules matching a display-name pattern.
.PARAMETER Name     Wildcard display name filter.
.PARAMETER Enabled  Restrict to enabled (True) or disabled (False) rules.
#>
    [CmdletBinding()]
    param(
        [string]$Name = '*',
        [nullable[bool]]$Enabled
    )
    $rules = Get-NetFirewallRule -DisplayName $Name -ErrorAction Ignore
    if ($null -ne $Enabled) { $rules = $rules | Where-Object Enabled -eq $Enabled }
    $rules | Select-Object DisplayName, Direction, Action, Enabled, Profile, Description |
             Sort-Object Direction, DisplayName
}

function Add-FirewallAllowRule {
<#
.SYNOPSIS  Adds an inbound allow rule for a specific port/protocol (requires elevation).
.PARAMETER DisplayName  Rule name.
.PARAMETER Port         TCP/UDP port number.
.PARAMETER Protocol     TCP or UDP (default TCP).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][int]$Port,
        [ValidateSet('TCP','UDP')][string]$Protocol = 'TCP'
    )
    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required.'; return }
    if ($PSCmdlet.ShouldProcess("Port $Port/$Protocol", "New-NetFirewallRule '$DisplayName'")) {
        New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow `
            -Protocol $Protocol -LocalPort $Port -ErrorAction Stop | Out-Null
        Write-Host "Firewall rule '$DisplayName' created for $Protocol port $Port." -ForegroundColor Green
    }
}

function Test-OpenPort {
<#
.SYNOPSIS  Scans a port range on a target host for open TCP ports.
.PARAMETER HostName  Target IP or hostname.
.PARAMETER StartPort Start of port range.
.PARAMETER EndPort   End of port range.
.PARAMETER TimeoutMs Timeout per port in milliseconds.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostName,
        [int]$StartPort   = 1,
        [int]$EndPort     = 1024,
        [int]$TimeoutMs   = 200
    )

    Write-Host "Scanning $HostName ports $StartPort–$EndPort …" -ForegroundColor Cyan
    $open = [System.Collections.Generic.List[int]]::new()

    $StartPort..$EndPort | ForEach-Object -Parallel {
        $port = $_
        $tcp  = [System.Net.Sockets.TcpClient]::new()
        try {
            $async = $tcp.BeginConnect($using:HostName, $port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne($using:TimeoutMs)) {
                $tcp.EndConnect($async)
                $port   # emit to pipeline
            }
        } catch { } finally { $tcp.Dispose() }
    } -ThrottleLimit 50 | ForEach-Object { $open.Add($_) }

    if ($open.Count -eq 0) {
        Write-Host 'No open ports found in range.' -ForegroundColor Yellow
    } else {
        $open | Sort-Object | ForEach-Object {
            Write-Host "  OPEN  →  $HostName`:$_" -ForegroundColor Green
        }
    }
    return $open
}

function Get-NetworkShare {
<#
.SYNOPSIS  Lists SMB shares and active SMB sessions on the local machine.
#>
    [CmdletBinding()]
    param()
    Write-Host '── Local Shares ──' -ForegroundColor Cyan
    Get-SmbShare | Select-Object Name, Path, Description, ScopeName | Format-Table -AutoSize

    Write-Host '── Active SMB Sessions ──' -ForegroundColor Cyan
    Get-SmbSession -ErrorAction Ignore |
        Select-Object ClientComputerName, ClientUserName, NumOpens | Format-Table -AutoSize
}

function Reset-NetworkStack {
<#
.SYNOPSIS  Resets Winsock, TCP/IP stack, and optionally flushes DNS (requires elevation).
.PARAMETER FlushDns  Also flush the DNS resolver cache.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([switch]$FlushDns)

    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required.'; return }
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Reset network stack')) {
        Write-Host 'Resetting Winsock …'   -ForegroundColor Cyan; & netsh.exe winsock reset
        Write-Host 'Resetting TCP/IP …'    -ForegroundColor Cyan; & netsh.exe int ip reset
        if ($FlushDns) {
            Write-Host 'Flushing DNS cache …' -ForegroundColor Cyan; Clear-DnsClientCache
        }
        Write-Host 'Network stack reset complete. A reboot is recommended.' -ForegroundColor Yellow
    }
}

#endregion

#region ── 11. SECURITY AUDITING & HARDENING ──────────────────────────────────

function Get-LocalUserAudit {
<#
.SYNOPSIS  Lists local user accounts with enabled/disabled and last-logon metadata.
#>
    [CmdletBinding()]
    param()
    Get-LocalUser | ForEach-Object {
        [PSCustomObject]@{
            Name           = $_.Name
            Enabled        = $_.Enabled
            PasswordExpires = $_.PasswordExpires
            LastLogon      = $_.LastLogon
            AccountExpires = $_.AccountExpires
            Description    = $_.Description
        }
    } | Sort-Object Enabled -Descending | Format-Table -AutoSize
}

function Get-LocalGroupMembership {
<#
.SYNOPSIS  Lists members of every local group, highlighting Administrators.
#>
    [CmdletBinding()]
    param()
    Get-LocalGroup | ForEach-Object {
        $grp = $_
        $members = Get-LocalGroupMember -Group $grp -ErrorAction Ignore |
                   Select-Object -ExpandProperty Name
        [PSCustomObject]@{
            Group   = $grp.Name
            Members = $members -join ', '
        }
    } | Format-Table -AutoSize
}

function Get-DefenderStatus {
<#
.SYNOPSIS  Returns Windows Defender / Microsoft Defender state and signature age.
#>
    [CmdletBinding()]
    param()
    $status = Get-MpComputerStatus -ErrorAction Ignore
    if (-not $status) { Write-Warning 'Microsoft Defender status unavailable.'; return }
    [PSCustomObject]@{
        RealTimeProtection      = $status.RealTimeProtectionEnabled
        BehaviorMonitor         = $status.BehaviorMonitorEnabled
        AntivirusEnabled        = $status.AntivirusEnabled
        AntiSpywareEnabled      = $status.AntispywareEnabled
        NISEnabled              = $status.NISEnabled
        SignatureAge_days        = $status.AntispywareSignatureAge
        SignatureVersion        = $status.AntispywareSignatureVersion
        EngineVersion           = $status.AMEngineVersion
        LastQuickScanDate       = $status.QuickScanEndTime
        LastFullScanDate        = $status.FullScanEndTime
        TamperProtection        = $status.IsTamperProtected
    } | Format-List
}

function Start-DefenderScan {
<#
.SYNOPSIS  Triggers a Windows Defender scan.
.PARAMETER ScanType  QuickScan (default) or FullScan.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('QuickScan','FullScan')]
        [string]$ScanType = 'QuickScan'
    )
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Defender $ScanType")) {
        Write-Host "Initiating Defender $ScanType …" -ForegroundColor Cyan
        Start-MpScan -ScanType $ScanType -ErrorAction Stop
    }
}

function Update-DefenderSignature {
<#
.SYNOPSIS  Downloads and applies the latest Defender signature update.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Update Defender signatures')) {
        Update-MpSignature -ErrorAction Stop
        Write-Host 'Defender signatures updated.' -ForegroundColor Green
    }
}

function Get-AuditPolicyStatus {
<#
.SYNOPSIS  Reads the Windows Advanced Audit Policy configuration via auditpol.
#>
    [CmdletBinding()]
    param()
    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required for auditpol.'; return }
    $raw = & auditpol.exe /get /category:* 2>$null
    $raw | Select-String '^\s{2}\S' | ForEach-Object {
        $line = $_.Line.Trim() -split '\s{2,}'
        [PSCustomObject]@{
            Subcategory = $line[0]
            Setting     = if ($line.Count -gt 1) { $line[-1] } else { 'Unknown' }
        }
    } | Format-Table -AutoSize
}

function Test-WindowsSecurityBaseline {
<#
.SYNOPSIS  Quick security baseline check: UAC, Defender, SMBv1, Guest account, RDP encryption.
#>
    [CmdletBinding()]
    param()

    $results = [ordered]@{}

    # UAC
    $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
                -Name EnableLUA -ErrorAction Ignore).EnableLUA
    $results['UAC Enabled']         = $uac -eq 1

    # Defender
    $def = Get-MpComputerStatus -ErrorAction Ignore
    $results['Defender RealTime']   = [bool]$def.RealTimeProtectionEnabled
    $results['Defender Updated']    = $def.AntispywareSignatureAge -le 3

    # SMBv1
    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Ignore
    $results['SMBv1 Disabled']      = $smb1.State -ne 'Enabled'

    # Guest account
    $guest = Get-LocalUser -Name Guest -ErrorAction Ignore
    $results['Guest Disabled']      = -not $guest.Enabled

    # RDP NLA
    $rdp = (Get-ItemProperty `
        'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
        -Name UserAuthentication -ErrorAction Ignore).UserAuthentication
    $results['RDP NLA Required']    = $rdp -eq 1

    # Firewall
    $fw = Get-NetFirewallProfile | Where-Object Enabled -eq $false
    $results['Firewall All Profiles On'] = $null -eq $fw

    $results.GetEnumerator() | ForEach-Object {
        $colour = if ($_.Value) { 'Green' } else { 'Red' }
        Write-Host ("  {0,-30} {1}" -f $_.Key, $(if ($_.Value) { '✔ PASS' } else { '✘ FAIL' })) `
            -ForegroundColor $colour
    }
}

#endregion

#region ── 12. EVENT-LOG & ERROR ANALYSIS ─────────────────────────────────────

function Get-RecentError {
<#
.SYNOPSIS  Retrieves the most recent Error-level events from a named log.
.PARAMETER LogName   Event log name (default: System).
.PARAMETER Hours     Look-back window in hours (default: 24).
.PARAMETER MaxEvents Maximum records returned (default: 50).
#>
    [CmdletBinding()]
    param(
        [string]$LogName   = 'System',
        [int]$Hours        = 24,
        [int]$MaxEvents    = 50
    )
    $filter = @{
        LogName   = $LogName
        Level     = 2   # Error
        StartTime = (Get-Date).AddHours(-$Hours)
    }
    Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction Ignore |
        Select-Object TimeCreated, Id, ProviderName,
            @{N='Message'; E={ $_.Message -replace '\r?\n', ' ' | Out-String -Width 120 }} |
        Format-Table -AutoSize -Wrap
}

function Get-CriticalEvent {
<#
.SYNOPSIS  Retrieves Critical-level events (Level 1) from the System log.
.PARAMETER Hours  Look-back window in hours.
#>
    [CmdletBinding()]
    param([int]$Hours = 72)
    $filter = @{
        LogName   = 'System'
        Level     = 1
        StartTime = (Get-Date).AddHours(-$Hours)
    }
    Get-WinEvent -FilterHashtable $filter -ErrorAction Ignore |
        Select-Object TimeCreated, Id, ProviderName, Message |
        Format-Table -AutoSize -Wrap
}

function Get-BlueScreenEvent {
<#
.SYNOPSIS  Searches the System event log for BugCheck (BSOD) events (ID 1001/41).
#>
    [CmdletBinding()]
    param([int]$Days = 30)
    $filter = @{
        LogName   = 'System'
        Id        = @(1001, 41)
        StartTime = (Get-Date).AddDays(-$Days)
    }
    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction Ignore
    if (-not $events) { Write-Host 'No BSOD events found in last' $Days 'days. ✔' -ForegroundColor Green; return }
    $events | Select-Object TimeCreated, Id, Message | Format-List
}

function Get-ApplicationCrash {
<#
.SYNOPSIS  Retrieves application crash events (ID 1000) from the Application log.
.PARAMETER Hours  Look-back window in hours.
#>
    [CmdletBinding()]
    param([int]$Hours = 24)
    $filter = @{
        LogName   = 'Application'
        Id        = 1000
        StartTime = (Get-Date).AddHours(-$Hours)
    }
    Get-WinEvent -FilterHashtable $filter -ErrorAction Ignore |
        Select-Object TimeCreated,
            @{N='FaultingApp';   E={ $_.Properties[0].Value }},
            @{N='FaultingMod';   E={ $_.Properties[2].Value }},
            @{N='ExceptionCode'; E={ $_.Properties[6].Value }} |
        Format-Table -AutoSize
}

function Export-EventLogReport {
<#
.SYNOPSIS  Exports the last N Error/Critical events from all standard logs to a CSV.
.PARAMETER OutputPath  Destination CSV file path.
.PARAMETER Hours       Look-back window.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$OutputPath = "$env:USERPROFILE\Desktop\EventReport_$(Get-Date -Format yyyyMMdd_HHmm).csv",
        [int]$Hours = 48
    )
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Export event log report')) {
        $logs   = @('System','Application','Security')
        $filter = @{ Level = @(1,2); StartTime = (Get-Date).AddHours(-$Hours) }
        $all    = foreach ($log in $logs) {
            $filter['LogName'] = $log
            Get-WinEvent -FilterHashtable $filter -ErrorAction Ignore |
                Select-Object TimeCreated, LogName, Level, Id, ProviderName, Message
        }
        $all | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Report exported → $OutputPath" -ForegroundColor Green
    }
}

#endregion

#region ── 13. PERFORMANCE & MONITORING ───────────────────────────────────────

function Measure-SystemPerformance {
<#
.SYNOPSIS  Samples CPU, memory, and disk I/O counters over a specified interval.
.PARAMETER Seconds    Sampling duration.
.PARAMETER Interval   Sample interval in seconds.
#>
    [CmdletBinding()]
    param(
        [int]$Seconds  = 10,
        [int]$Interval = 2
    )

    $samples = [System.Collections.Generic.List[PSObject]]::new()
    $end     = (Get-Date).AddSeconds($Seconds)

    while ((Get-Date) -lt $end) {
        $os  = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = (Get-CimInstance -ClassName Win32_Processor | Measure-Object LoadPercentage -Average).Average
        $samples.Add([PSCustomObject]@{
            Timestamp   = Get-Date
            CPU_Pct     = $cpu
            FreeRAM_MB  = [math]::Round($os.FreePhysicalMemory / 1024, 0)
        })
        Start-Sleep -Seconds $Interval
    }

    $samples | Format-Table -AutoSize
    $samples | Measure-Object CPU_Pct -Average -Maximum | ForEach-Object {
        Write-Host "CPU — Avg: $([math]::Round($_.Average,1))%   Max: $($_.Maximum)%" -ForegroundColor Cyan
    }
}

function Get-TopProcess {
<#
.SYNOPSIS  Returns the top N processes by CPU or memory consumption.
.PARAMETER By   CPU or Memory.
.PARAMETER Top  Number of processes to show.
#>
    [CmdletBinding()]
    param(
        [ValidateSet('CPU','Memory')]
        [string]$By  = 'Memory',
        [int]$Top    = 15
    )

    $sort = if ($By -eq 'Memory') { 'WorkingSet64' } else { 'CPU' }
    Get-Process -ErrorAction Ignore |
        Sort-Object $sort -Descending |
        Select-Object -First $Top |
        Select-Object Name, Id,
            @{N='CPU_s';  E={ [math]::Round($_.CPU, 1) }},
            @{N='RAM_MB'; E={ [math]::Round($_.WorkingSet64 / 1MB, 1) }},
            @{N='Handles';E={ $_.HandleCount }},
            @{N='Threads';E={ $_.Threads.Count }} |
        Format-Table -AutoSize
}

function Get-DiskIORate {
<#
.SYNOPSIS  Samples disk read/write bytes per second for all physical disks.
.PARAMETER Seconds  Sampling window.
#>
    [CmdletBinding()]
    param([int]$Seconds = 5)

    $counters = '\PhysicalDisk(*)\Disk Read Bytes/sec',
                '\PhysicalDisk(*)\Disk Write Bytes/sec'

    $samples = Get-Counter -Counter $counters -SampleInterval 1 -MaxSamples $Seconds
    $samples.CounterSamples |
        Group-Object Path | ForEach-Object {
            [PSCustomObject]@{
                Counter = $_.Name
                Avg_MB_s = [math]::Round(($_.Group | Measure-Object CookedValue -Average).Average / 1MB, 2)
                Max_MB_s = [math]::Round(($_.Group | Measure-Object CookedValue -Maximum).Maximum / 1MB, 2)
            }
        } | Format-Table -AutoSize
}

function Get-ThermalZone {
<#
.SYNOPSIS  Returns thermal zone temperatures reported via WMI (values in tenths of Kelvin).
#>
    [CmdletBinding()]
    param()
    Get-CimInstance -Namespace 'root/WMI' -ClassName MSAcpi_ThermalZoneTemperature `
        -ErrorAction Ignore |
        ForEach-Object {
            $celsius = [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1)
            [PSCustomObject]@{
                Zone        = $_.InstanceName
                Temperature = "$celsius °C"
                CriticalC   = [math]::Round(($_.CriticalTripPoint / 10) - 273.15, 1)
            }
        }
}

#endregion

#region ── 14. UPDATE ORCHESTRATION ───────────────────────────────────────────

function Update-AllPackageManagers {
<#
.SYNOPSIS  Runs upgrade commands for every detected package manager sequentially.
.PARAMETER IncludeWinget    Include winget upgrade --all (default: true).
.PARAMETER IncludeScoop     Include scoop update * (default: true).
.PARAMETER IncludeChoco     Include choco upgrade all (default: true).
.PARAMETER IncludePip       Upgrade all pip packages for the active Python (default: false).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool]$IncludeWinget = $true,
        [bool]$IncludeScoop  = $true,
        [bool]$IncludeChoco  = $true,
        [bool]$IncludePip    = $false
    )

    if ($IncludeWinget -and (Get-Command winget -ErrorAction Ignore)) {
        if ($PSCmdlet.ShouldProcess('winget', 'upgrade --all')) {
            Write-Host "`n── winget upgrade all ──" -ForegroundColor Cyan
            winget upgrade --all --accept-package-agreements --accept-source-agreements
        }
    }

    if ($IncludeScoop -and (Get-Command scoop -ErrorAction Ignore)) {
        if ($PSCmdlet.ShouldProcess('scoop', 'update + upgrade all')) {
            Write-Host "`n── scoop update ──" -ForegroundColor Cyan
            scoop update *
        }
    }

    if ($IncludeChoco -and (Get-Command choco -ErrorAction Ignore)) {
        if (-not $Script:IsAdmin) {
            Write-Warning 'Chocolatey upgrades require elevation — skipping.'
        } elseif ($PSCmdlet.ShouldProcess('choco', 'upgrade all')) {
            Write-Host "`n── choco upgrade all ──" -ForegroundColor Cyan
            choco upgrade all --yes
        }
    }

    if ($IncludePip -and (Get-Command pip -ErrorAction Ignore)) {
        if ($PSCmdlet.ShouldProcess('pip', 'upgrade all packages')) {
            Write-Host "`n── pip upgrade all ──" -ForegroundColor Cyan
            pip list --outdated --format=freeze 2>$null |
                ForEach-Object { pip install --upgrade ($_ -split '==')[0] }
        }
    }

    Write-Host "`nAll selected package managers updated. ✔" -ForegroundColor Green
}

function Update-PowerShellModule {
<#
.SYNOPSIS  Updates all or a named PowerShell module from PSGallery.
.PARAMETER Name  Module name (default: * — all installed modules).
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Name = '*')

    $modules = Get-InstalledModule -Name $Name -ErrorAction Ignore
    if (-not $modules) { Write-Warning "No installed modules match '$Name'."; return }

    foreach ($mod in $modules) {
        if ($PSCmdlet.ShouldProcess($mod.Name, 'Update-Module')) {
            Write-Host "Updating $($mod.Name) …" -ForegroundColor Cyan
            Update-Module -Name $mod.Name -Force -ErrorAction Ignore
        }
    }
    Write-Host 'Module updates complete. ✔' -ForegroundColor Green
}

function Get-PendingWindowsUpdate {
<#
.SYNOPSIS  Lists pending Windows Updates via the PSWindowsUpdate module.
#>
    [CmdletBinding()]
    param()
    Import-RequiredModule -Name 'PSWindowsUpdate'
    if (Get-Module PSWindowsUpdate -ErrorAction Ignore) {
        Get-WindowsUpdate -ErrorAction Ignore | Format-Table -AutoSize
    } else {
        Write-Warning 'PSWindowsUpdate could not be loaded.'
    }
}

function Install-PendingWindowsUpdate {
<#
.SYNOPSIS  Downloads and installs all available Windows Updates (requires elevation).
.PARAMETER AutoReboot  Automatically reboot after installation if required.
#>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param([switch]$AutoReboot)

    if (-not $Script:IsAdmin) { Write-Warning 'Elevation required.'; return }
    Import-RequiredModule -Name 'PSWindowsUpdate'
    if (-not (Get-Module PSWindowsUpdate -ErrorAction Ignore)) {
        Write-Warning 'PSWindowsUpdate unavailable.'; return
    }

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install all Windows Updates')) {
        $splat = @{ AcceptAll = $true; ErrorAction = 'Stop' }
        if ($AutoReboot) { $splat['AutoReboot'] = $true } else { $splat['IgnoreReboot'] = $true }
        Install-WindowsUpdate @splat
    }
}

#endregion

#region ── 15. PROMPT UTILITIES & ALIASES ─────────────────────────────────────

function Get-ProfileInfo {
<#
.SYNOPSIS  Shows the profile path, PowerShell version, and loaded modules count.
#>
    [CmdletBinding()]
    param()
    [PSCustomObject]@{
        ProfilePath     = $PROFILE
        PSVersion       = $PSVersionTable.PSVersion.ToString()
        Host            = $Host.Name
        LoadedModules   = (Get-Module).Count
        IsAdmin         = $Script:IsAdmin
        OhMyPosh        = [bool](Get-Command oh-my-posh -ErrorAction Ignore)
        PSReadLineVer   = (Get-Module PSReadLine -ErrorAction Ignore).Version.ToString()
    } | Format-List
}

function Invoke-ProfileReload {
<#
.SYNOPSIS  Re-sources the current PowerShell profile.
#>
    [CmdletBinding()]
    param()
    Write-Host 'Reloading profile …' -ForegroundColor Cyan
    . $PROFILE
    Write-Host 'Profile reloaded. ✔' -ForegroundColor Green
}

function Edit-Profile {
<#
.SYNOPSIS  Opens the PowerShell profile in the preferred editor.
.PARAMETER Editor  Editor command (default: code for VS Code, falls back to notepad).
#>
    [CmdletBinding()]
    param([string]$Editor)

    if (-not $Editor) {
        $Editor = if (Get-Command code  -ErrorAction Ignore) { 'code' }
                  elseif (Get-Command nvim -ErrorAction Ignore) { 'nvim' }
                  elseif (Get-Command vim  -ErrorAction Ignore) { 'vim' }
                  else   { 'notepad' }
    }
    & $Editor $PROFILE
}

function Show-CommandPalette {
<#
.SYNOPSIS  Displays all profile-defined functions with a one-line synopsis.
#>
    [CmdletBinding()]
    param([string]$Filter = '*')
    Write-Host "`nProfile Functions:" -ForegroundColor Cyan
    Get-Command -CommandType Function |
        Where-Object { 
            $_.Source -eq '' -and 
            $_.Name -like $Filter -and
            $_.Name -notmatch '^[A-Z]:$'  # Exclude drive letter functions
        } |
        Sort-Object Name | ForEach-Object {
            try {
                $help = Get-Help $_.Name -ErrorAction Stop
                $synopsis = if ($help.Synopsis -and $help.Synopsis -notmatch '^$') {
                                $help.Synopsis.Trim()
                            } else { '' }
            } catch {
                $synopsis = ''
            }
            Write-Host ("  {0,-40} {1}" -f $_.Name, $synopsis)
        }
    Write-Host ''
}

# ── Environment tweaks ───────────────────────────────────────────────────────
$env:PYTHONIOENCODING      = 'utf-8'
$env:PYTHONUTF8            = '1'
[Console]::OutputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding   = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['Out-Default:OutVariable']        = '__'
$PSDefaultParameterValues['Format-Table:AutoSize']          = $true
$PSDefaultParameterValues['Invoke-RestMethod:ContentType']  = 'application/json'

# ── Aliases (avoid collisions with built-in names) ──────────────────────────
Set-Alias -Name pf      -Value Get-ProfileInfo         -Option ReadOnly
Set-Alias -Name palette -Value Show-CommandPalette      -Option ReadOnly
Set-Alias -Name reload  -Value Invoke-ProfileReload     -Option ReadOnly
Set-Alias -Name ep      -Value Edit-Profile             -Option ReadOnly
Set-Alias -Name sysinfo -Value Get-HardwareSummary      -Option ReadOnly
Set-Alias -Name netdiag -Value Invoke-NetworkDiagnostic -Option ReadOnly
Set-Alias -Name syscheck -Value Test-SystemHealth       -Option ReadOnly
Set-Alias -Name seccheck -Value Test-WindowsSecurityBaseline -Option ReadOnly
Set-Alias -Name updall  -Value Update-AllPackageManagers -Option ReadOnly
Set-Alias -Name toph    -Value Get-TopProcess           -Option ReadOnly

# ── Startup banner ──────────────────────────────────────────────────────────
if ($Host.Name -eq 'ConsoleHost') {
    $elev = if ($Script:IsAdmin) { ' [ADMIN]' } else { '' }
    Write-Host ''
    Write-Host "  PowerShell $($PSVersionTable.PSVersion)$elev  ·  $env:COMPUTERNAME  ·  $(Get-Date -Format 'ddd dd-MMM-yyyy HH:mm')" `
        -ForegroundColor DarkCyan
    Write-Host "  Type 'palette' for a list of profile functions." -ForegroundColor DarkGray
    Write-Host ''
}

# ── Cleanup ─────────────────────────────────────────────────────────────────
# Clear any errors that accumulated during profile loading (e.g., missing optional commands)
$Error.Clear()

#endregion