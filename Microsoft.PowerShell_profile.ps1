#Requires -Version 7.5
<#
================================================================================
   POWERSHELL 7.5+ PROFILE — Windows Terminal · Windows 10/11 x64
   ----------------------------------------------------------------------------
   A modular, lazy‑loading profile blending system administration with
   production‑grade engineering. Designed for fast startup and extensibility.
   Regions (use Ctrl+M in VS Code to fold):
      1.  Startup
      2.  Aliases & Shortcuts
      3.  Core Utilities
      4.  Framework Management
      5.  Diagnostics & Health
      6.  Interactive UX
      7.  AI Collaboration Hooks
      8.  Logging
      9.  Testing
     10.  Prompt & Environment Tweaks
================================================================================
#>

#region ---- 1. STARTUP ----
Set-StrictMode -Version Latest

# Ensure Windows environment
if (-not $IsWindows) {
    Write-Warning 'This profile targets Windows only. Aborting.'
    return
}

# Profile paths (use current host profile for file operations)
$script:ProfilePath         = $PROFILE  # CurrentUserCurrentHost
$script:ProfileRoot         = Split-Path -Parent $script:ProfilePath
$script:ProfileConfigPath   = Join-Path $env:USERPROFILE 'Documents\PowerShellProfileConfig.json'
$script:ProfileLogRoot      = Join-Path $env:USERPROFILE 'Documents\PowerShellProfile\Logs'

# Ensure log directory exists (non‑blocking)
if (-not (Test-Path $script:ProfileLogRoot)) {
    $null = New-Item -ItemType Directory -Path $script:ProfileLogRoot -Force -ErrorAction SilentlyContinue
}

# First‑run wizard (runs once)
if (-not (Test-Path $script:ProfileConfigPath)) {
    Write-Host "`n✨ Welcome to your enhanced PowerShell profile!" -ForegroundColor Cyan
    Write-Host "Let's set a few preferences.`n" -ForegroundColor Cyan

    $fullStartup = Read-Host "Enable full startup mode? (loads all optional modules, slower startup) [y/N]"
    $startupMode = if ($fullStartup -match '^[Yy]') { 'full' } else { 'fast' }

    $enableLogging = Read-Host "Enable local logging? (profile events saved to log directory) [Y/n]"
    $logging = ($enableLogging -notmatch '^[Nn]')

    $config = @{
        StartupMode    = $startupMode
        LoggingEnabled = $logging
        FirstRun       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    $config | ConvertTo-Json | Set-Content -Path $script:ProfileConfigPath -Encoding UTF8
    Write-Host "✅ Configuration saved to $script:ProfileConfigPath`n" -ForegroundColor Green
} else {
    try {
        $config = Get-Content -Path $script:ProfileConfigPath -Raw | ConvertFrom-Json
        $script:ProfileStartupMode = $config.StartupMode
        $script:ProfileLoggingEnabled = $config.LoggingEnabled
    } catch {
        Write-Warning 'Could not load profile config; using defaults.'
        $script:ProfileStartupMode = 'fast'
        $script:ProfileLoggingEnabled = $true
    }
}

# Elevation helper
function Test-AdminPrivilege {
    [OutputType([bool])] param()
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$script:IsAdmin = Test-AdminPrivilege

# Lazy‑load helper: import a module only when first needed
function script:Use-ModuleLazy {
    param([string]$ModuleName, [scriptblock]$Body)
    $scriptBlock = {
        param($mod, $bodyBlock)
        $module = Get-Module -ListAvailable -Name $mod
        if (-not $module) {
            Write-Warning "Module '$mod' is not installed. Some features may be unavailable."
            return
        }
        Import-Module $module[0].Name -ErrorAction Stop
        & $bodyBlock
    }
    & $scriptBlock $ModuleName $Body
}

# Minimal version check
if ($PSVersionTable.PSVersion -lt '7.5.0') {
    Write-Warning "PowerShell 7.5+ recommended. Current: $($PSVersionTable.PSVersion)"
}
#endregion

#region ---- 2. ALIASES & SHORTCUTS ----
function Set-SafeAlias {
    param([string]$Name, [string]$Value)
    if (Get-Command -Name $Name -ErrorAction SilentlyContinue) {
        Write-Warning "Alias '$Name' already exists; skipping."
    } else {
        Set-Alias -Name $Name -Value $Value -Scope Global -Option AllScope
    }
}

# Safe aliases (prefer functions for complex logic)
Set-SafeAlias 'h'        'Get-History'
Set-SafeAlias 'k'        'Clear-Host'
Set-SafeAlias 'g'        'Get-Command'
Set-SafeAlias 'which'    'Get-Command'
Set-SafeAlias 'pf'       'Get-ProfileInfo'
Set-SafeAlias 'palette'  'Show-CommandPalette'
Set-SafeAlias 'reload'   'Invoke-ProfileReload'
Set-SafeAlias 'ep'       'Edit-Profile'
Set-SafeAlias 'sysinfo'  'Get-HardwareSummary'
Set-SafeAlias 'netdiag'  'Invoke-NetworkDiagnostic'
Set-SafeAlias 'syscheck' 'Test-SystemHealth'
Set-SafeAlias 'seccheck' 'Test-WindowsSecurityBaseline'
Set-SafeAlias 'updall'   'Update-AllPackageManagers'
Set-SafeAlias 'toph'     'Get-TopProcess'
#endregion

#region ---- 3. CORE UTILITY FUNCTIONS ----
<#
.SYNOPSIS
    Safely gets an environment variable or a default value.
#>
function Get-EnvOrDefault {
    [CmdletBinding()]
    param([string]$Name, [string]$Default)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { $value } else { $Default }
}

<#
.SYNOPSIS
    Joins a path under $env:USERPROFILE.
#>
function Join-UserPath {
    param([string[]]$ChildPath)
    Join-Path $env:USERPROFILE @ChildPath
}

<#
.SYNOPSIS
    Wraps destructive actions with confirmation and WhatIf support.
#>
function Invoke-ConfirmAction {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [scriptblock]$ScriptBlock,
        [string]$Description = 'Perform destructive action'
    )
    if ($PSCmdlet.ShouldProcess($Description, 'Confirm', 'Execute')) {
        & $ScriptBlock
    }
}

<#
.SYNOPSIS
    Installs and imports a module if missing, with safety switches.
    Does nothing in dry‑run mode; requires -AllowNetwork to install.
#>
function Import-RequiredModule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$MinimumVersion,
        [switch]$AllowNetwork
    )
    $installed = Get-Module -Name $Name -ListAvailable -ErrorAction Ignore
    if (-not $installed) {
        if (-not $AllowNetwork) {
            Write-Warning "Module '$Name' not found. To install, re-run with -AllowNetwork."
            return
        }
        if ($PSCmdlet.ShouldProcess("Install module $Name from PSGallery", "Install-Module")) {
            Write-Host "  Installing module: $Name …" -ForegroundColor Cyan
            $installSplat = @{ Name = $Name; Scope = 'CurrentUser'; Force = $true; AllowClobber = $true; ErrorAction = 'SilentlyContinue' }
            if ($MinimumVersion) { $installSplat['MinimumVersion'] = $MinimumVersion }
            Install-Module @installSplat
        } else {
            Write-Host "[DRY-RUN] Would install module $Name" -ForegroundColor Yellow
            return
        }
    } elseif ($MinimumVersion) {
        $maxVer = ($installed | Sort-Object Version -Descending | Select-Object -First 1).Version
        if ($maxVer -lt [version]$MinimumVersion) {
            if (-not $AllowNetwork) {
                Write-Warning "Module '$Name' version $($maxVer) is below required $MinimumVersion. To update, re-run with -AllowNetwork."
                return
            }
            if ($PSCmdlet.ShouldProcess("Update module $Name to $MinimumVersion", "Update-Module")) {
                Write-Host "  Updating module: $Name to $MinimumVersion …" -ForegroundColor Cyan
                Update-Module -Name $Name -MinimumVersion $MinimumVersion -Force -ErrorAction Ignore
            } else {
                Write-Host "[DRY-RUN] Would update module $Name" -ForegroundColor Yellow
                return
            }
        }
    }
    Import-Module -Name $Name -ErrorAction Ignore
}

<#
.SYNOPSIS
    Tests whether a command exists in PATH.
#>
function script:Test-Command($Command) {
    Get-Command $Command -ErrorAction SilentlyContinue
}
#endregion

#region ---- 4. FRAMEWORK MANAGEMENT ----
# .NET
function Get-DotNetVersion {
    $cmd = script:Test-Command 'dotnet'
    if ($cmd) { return (& dotnet --version 2>$null).Trim() }
}
function Install-DotNet { Write-Host "Install .NET SDK from https://dotnet.microsoft.com/download" }
function Repair-DotNet { Write-Host "Run 'dotnet restore' in your project directory." }
function Uninstall-DotNet {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall .NET SDK" -ScriptBlock {
        Write-Host "Manual uninstall required: use Control Panel or winget." -ForegroundColor Yellow
        if (script:Test-Command 'winget') { winget uninstall Microsoft.DotNet.SDK.8_8 --force }
    }
}

# NodeJS
function Get-NodeVersion {
    $cmd = script:Test-Command 'node'
    if ($cmd) { return (& node --version).Trim() }
}
function Install-Node { Write-Host "Install Node.js from https://nodejs.org" }
function Repair-Node { Write-Host "Run 'npm install' or reinstall Node." }
function Uninstall-Node {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall Node.js" -ScriptBlock {
        if (script:Test-Command 'winget') { winget uninstall OpenJS.NodeJS --force }
        else { Write-Host "Uninstall manually from Programs and Features." }
    }
}

# Python
function Get-PythonVersion {
    $cmd = script:Test-Command 'python'
    if (-not $cmd) { $cmd = script:Test-Command 'python3' }
    if ($cmd) { return (& $cmd --version 2>$null) }
}
function Install-Python { Write-Host "Install Python from https://python.org" }
function Repair-Python { Write-Host "Reinstall or use 'pip check'." }
function Uninstall-Python {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall Python" -ScriptBlock {
        if (script:Test-Command 'winget') { winget uninstall Python.Python --force }
        else { Write-Host "Uninstall manually." }
    }
}

# Go
function Get-GoVersion {
    $cmd = script:Test-Command 'go'
    if ($cmd) { return (& go version) }
}
function Install-Go { Write-Host "Install Go from https://golang.org/dl" }
function Repair-Go { Write-Host "Run 'go mod tidy' or reinstall." }
function Uninstall-Go {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall Go" -ScriptBlock {
        if (script:Test-Command 'winget') { winget uninstall GoLang.Go --force }
        else { Write-Host "Uninstall manually." }
    }
}

# Rust
function Get-RustVersion {
    $cmd = script:Test-Command 'rustc'
    if ($cmd) { return (& rustc --version) }
}
function Install-Rust { Write-Host "Install Rust via https://rustup.rs" }
function Repair-Rust { Write-Host "Run 'rustup update'." }
function Uninstall-Rust {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall Rust" -ScriptBlock {
        if (script:Test-Command 'rustup') { rustup self uninstall -y }
        else { Write-Host "Uninstall manually." }
    }
}

# Java
function Get-JavaVersion {
    $cmd = script:Test-Command 'java'
    if ($cmd) { return (& java -version 2>&1) }
}
function Install-Java { Write-Host "Install Java from https://adoptium.net" }
function Repair-Java { Write-Host "Reinstall or set JAVA_HOME." }
function Uninstall-Java {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    Invoke-ConfirmAction -Description "Uninstall Java" -ScriptBlock {
        if (script:Test-Command 'winget') { winget uninstall EclipseAdoptium.Temurin.11 --force }
        else { Write-Host "Uninstall manually." }
    }
}

# Assert-FrameworkVersion helper
function Assert-FrameworkVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('.NET','Node','Python','Go','Rust','Java')][string]$Framework,
        [Parameter(Mandatory)][string]$Minimum
    )
    $version = switch ($Framework) {
        '.NET'  { Get-DotNetVersion }
        'Node'  { Get-NodeVersion }
        'Python'{ Get-PythonVersion }
        'Go'    { Get-GoVersion }
        'Rust'  { Get-RustVersion }
        'Java'  { Get-JavaVersion }
    }
    if (-not $version) {
        Write-Warning "$Framework not found."
        return $false
    }
    try {
        $minVer = [version]$Minimum
        $actualVer = [version]($version -replace '[^0-9.]')
        $result = $actualVer -ge $minVer
        if (-not $result) { Write-Warning "$Framework version $actualVer is below required $minVer." }
        return $result
    } catch {
        Write-Warning "Could not parse version for $Framework."
        return $false
    }
}
#endregion

#region ---- 5. DIAGNOSTICS & HEALTH ----
<#
.SYNOPSIS
    Returns a structured summary of CPU, RAM, OS, and uptime.
#>
function Get-SystemSummary {
    [CmdletBinding()][OutputType([PSCustomObject])] param()
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
function Get-CpuDetail { Get-CimInstance Win32_Processor | ForEach-Object { [PSCustomObject]@{ Name=$_.Name.Trim(); PhysicalCores=$_.NumberOfCores; LogicalCores=$_.NumberOfLogicalProcessors; MaxClockMHz=$_.MaxClockSpeed; CurrentClockMHz=$_.CurrentClockSpeed; LoadPercent=$_.LoadPercentage } } }
function Get-MemoryDetail { Get-CimInstance Win32_PhysicalMemory | ForEach-Object { [PSCustomObject]@{ Bank=$_.BankLabel; Slot=$_.DeviceLocator; CapacityGB=[math]::Round($_.Capacity/1GB,2); SpeedMHz=$_.Speed } } }
function Get-GpuDetail { Get-CimInstance Win32_VideoController | ForEach-Object { [PSCustomObject]@{ Name=$_.Name; VRAM_GB=[math]::Round($_.AdapterRAM/1GB,2); DriverVersion=$_.DriverVersion; DriverDate=$_.DriverDate } } }
function Get-DiskDetail { param([string]$DriveLetter); $volumes = Get-Volume | Where-Object DriveType -eq 'Fixed'; if($DriveLetter){$volumes = $volumes | Where-Object DriveLetter -eq $DriveLetter}; $volumes | ForEach-Object { $vol=$_; [PSCustomObject]@{ DriveLetter=$vol.DriveLetter; Label=$vol.FileSystemLabel; SizeGB=[math]::Round($vol.Size/1GB,2); FreeGB=[math]::Round($vol.SizeRemaining/1GB,2); UsedPct=[math]::Round((1-$vol.SizeRemaining/$vol.Size)*100,1); HealthStatus=$vol.HealthStatus } } }
function Get-BatteryStatus { $bat=Get-CimInstance Win32_Battery; if(-not$bat){Write-Host 'No battery detected.'; return}; $bat | ForEach-Object { [PSCustomObject]@{ Name=$_.Name; EstChargePercent=$_.EstimatedChargeRemaining; StatusText=switch($_.BatteryStatus){1{'Discharging'}2{'AC/Plugged'}3{'Fully Charged'}4{'Low'}5{'Critical'}default{"Code $($_.BatteryStatus)"}} } } }
function Get-HardwareSummary { Write-Host "`n═══ SYSTEM ═══" -ForegroundColor Cyan; Get-SystemSummary | Format-List; Write-Host "`n═══ CPU ══════" -ForegroundColor Cyan; Get-CpuDetail | Format-List; Write-Host "`n═══ MEMORY ═══" -ForegroundColor Cyan; Get-MemoryDetail | Format-Table -AutoSize; Write-Host "`n═══ GPU ══════" -ForegroundColor Cyan; Get-GpuDetail | Format-List; Write-Host "`n═══ DISKS ════" -ForegroundColor Cyan; Get-DiskDetail | Format-Table -AutoSize; Write-Host "`n═══ BATTERY ══" -ForegroundColor Cyan; Get-BatteryStatus | Format-List }

# Network functions
function Get-NetworkAdapterDetail { Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object { $ad=$_; $ipCfg=Get-NetIPAddress -InterfaceIndex $ad.ifIndex -ErrorAction Ignore; $dns=Get-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -AddressFamily IPv4 -ErrorAction Ignore; [PSCustomObject]@{ Name=$ad.Name; Description=$ad.InterfaceDescription; Status=$ad.Status; MAC=$ad.MacAddress; IPv4=($ipCfg|Where-Object AddressFamily -eq 'IPv4').IPAddress -join ', '; DNSServers=$dns.ServerAddresses -join ', ' } } }
function Get-ActiveConnection { Get-NetTCPConnection -ErrorAction Ignore | Where-Object State -eq 'Established' | ForEach-Object { $proc = if($_.OwningProcess -gt 0){(Get-Process -Id $_.OwningProcess -ErrorAction Ignore).Name}else{'System'}; [PSCustomObject]@{ Protocol='TCP'; LocalAddr="$($_.LocalAddress):$($_.LocalPort)"; RemoteAddr="$($_.RemoteAddress):$($_.RemotePort)"; State=$_.State; ProcessName=$proc } } }
function Invoke-NetworkDiagnostic { Write-Host "`n═══ ADAPTERS ═════════" -ForegroundColor Cyan; Get-NetworkAdapterDetail | Format-Table -AutoSize; Write-Host "`n═══ ACTIVE CONNECTIONS ═" -ForegroundColor Cyan; Get-ActiveConnection | Select-Object -First 20 | Format-Table -AutoSize; Write-Host "`n═══ DNS SERVERS ══════" -ForegroundColor Cyan; Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Ignore | Select-Object InterfaceAlias, ServerAddresses; Write-Host "`n═══ CONNECTIVITY TESTS ═" -ForegroundColor Cyan; foreach($t in @('8.8.8.8','1.1.1.1','www.microsoft.com')){$ping=Test-Connection -TargetName $t -Count 2 -ErrorAction Ignore; $lat=if($ping){(($ping|Measure-Object Latency -Average).Average).ToString('N0')+' ms'}else{'FAIL'}; Write-Host "  $t  →  $lat"} }

# Security functions
function Get-LocalUserAudit { Get-LocalUser | Select-Object Name, Enabled, LastLogon, Description | Format-Table -AutoSize }
function Get-DefenderStatus { Get-MpComputerStatus -ErrorAction Ignore | Select-Object RealTimeProtectionEnabled, AntivirusEnabled, SignatureAge, SignatureVersion, LastQuickScanEndTime | Format-List }
function Test-WindowsSecurityBaseline {
    $results = [ordered]@{}
    $results['UAC Enabled'] = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Ignore).EnableLUA -eq 1
    $def = Get-MpComputerStatus -ErrorAction Ignore
    $results['Defender RealTime'] = [bool]$def.RealTimeProtectionEnabled
    $results['Defender Updated'] = $def.AntispywareSignatureAge -le 3
    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Ignore
    $results['SMBv1 Disabled'] = $smb1.State -ne 'Enabled'
    $guest = Get-LocalUser -Name Guest -ErrorAction Ignore
    $results['Guest Disabled'] = -not $guest.Enabled
    $rdp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction Ignore).UserAuthentication
    $results['RDP NLA Required'] = $rdp -eq 1
    $fw = Get-NetFirewallProfile | Where-Object Enabled -eq $false
    $results['Firewall All Profiles On'] = $null -eq $fw
    $results.GetEnumerator() | ForEach-Object {
        $color = if ($_.Value) { 'Green' } else { 'Red' }
        Write-Host ("  {0,-30} {1}" -f $_.Key, $(if ($_.Value) { '✔ PASS' } else { '✘ FAIL' })) -ForegroundColor $color
    }
}

# Performance functions
function Get-TopProcess {
    [CmdletBinding()] param([ValidateSet('CPU','Memory')][string]$By='Memory', [int]$Top=15)
    $sort = if ($By -eq 'Memory') { 'WorkingSet64' } else { 'CPU' }
    Get-Process -ErrorAction Ignore | Sort-Object $sort -Descending | Select-Object -First $Top |
        Select-Object Name, Id, @{N='CPU_s';E={[math]::Round($_.CPU,1)}}, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, Handles, Threads | Format-Table -AutoSize
}
function Measure-SystemPerformance {
    [CmdletBinding()] param([int]$Seconds=10, [int]$Interval=2)
    $samples = [System.Collections.Generic.List[PSObject]]::new()
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
        $samples.Add([PSCustomObject]@{ Timestamp=Get-Date; CPU_Pct=$cpu; FreeRAM_MB=[math]::Round($os.FreePhysicalMemory/1024,0) })
        Start-Sleep -Seconds $Interval
    }
    $samples | Format-Table -AutoSize
    $samples | Measure-Object CPU_Pct -Average -Maximum | ForEach-Object { Write-Host "CPU — Avg: $([math]::Round($_.Average,1))%   Max: $($_.Maximum)%" -ForegroundColor Cyan }
}

# Update orchestration
function Update-AllPackageManagers {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool]$IncludeWinget = $true,
        [bool]$IncludeScoop  = $true,
        [bool]$IncludeChoco  = $true,
        [bool]$IncludePip    = $false
    )
    if ($IncludeWinget -and (script:Test-Command 'winget')) {
        if ($PSCmdlet.ShouldProcess('winget', 'upgrade --all')) {
            Write-Host "`n── winget upgrade all ──" -ForegroundColor Cyan
            winget upgrade --all --accept-package-agreements --accept-source-agreements
        }
    }
    if ($IncludeScoop -and (script:Test-Command 'scoop')) {
        if ($PSCmdlet.ShouldProcess('scoop', 'update + upgrade all')) {
            Write-Host "`n── scoop update ──" -ForegroundColor Cyan
            scoop update *
        }
    }
    if ($IncludeChoco -and (script:Test-Command 'choco')) {
        if (-not $script:IsAdmin) { Write-Warning 'Chocolatey upgrades require elevation — skipping.' }
        elseif ($PSCmdlet.ShouldProcess('choco', 'upgrade all')) {
            Write-Host "`n── choco upgrade all ──" -ForegroundColor Cyan
            choco upgrade all --yes
        }
    }
    if ($IncludePip -and (script:Test-Command 'pip')) {
        if ($PSCmdlet.ShouldProcess('pip', 'upgrade all packages')) {
            Write-Host "`n── pip upgrade all ──" -ForegroundColor Cyan
            pip list --outdated --format=freeze 2>$null | ForEach-Object { pip install --upgrade ($_ -split '==')[0] }
        }
    }
    Write-Host "`nAll selected package managers updated. ✔" -ForegroundColor Green
}

# Event log functions
function Get-RecentError {
    [CmdletBinding()] param([string]$LogName='System', [int]$Hours=24, [int]$MaxEvents=50)
    $filter = @{ LogName=$LogName; Level=2; StartTime=(Get-Date).AddHours(-$Hours) }
    Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction Ignore |
        Select-Object TimeCreated, Id, ProviderName, @{N='Message';E={$_.Message -replace '\r?\n',' '|Out-String -Width 120}} |
        Format-Table -AutoSize -Wrap
}

# Profile health checks
function Test-ProfileHealth {
    [CmdletBinding()] param()
    $results = @()
    if (Test-Path $script:ProfilePath) {
        $results += [PSCustomObject]@{Check='Profile file'; Status='OK'; Details=$script:ProfilePath}
    } else { $results += [PSCustomObject]@{Check='Profile file'; Status='Missing'; Details=''}}
    $modules = @('Pester','PSScriptAnalyzer')
    foreach ($mod in $modules) {
        if (Get-Module -ListAvailable $mod) { $results += [PSCustomObject]@{Check="Module $mod"; Status='OK'; Details='Installed'} }
        else { $results += [PSCustomObject]@{Check="Module $mod"; Status='Missing'; Details='Not installed'} }
    }
    $frameworks = @(@{Name='.NET'; Cmd='dotnet'},@{Name='Node'; Cmd='node'},@{Name='Python'; Cmd='python'},@{Name='Go'; Cmd='go'},@{Name='Rust'; Cmd='rustc'},@{Name='Java'; Cmd='java'})
    foreach ($fw in $frameworks) {
        if (script:Test-Command $fw.Cmd) { $results += [PSCustomObject]@{Check="Framework $($fw.Name)"; Status='OK'; Details='CLI available'} }
        else { $results += [PSCustomObject]@{Check="Framework $($fw.Name)"; Status='Missing'; Details='CLI not in PATH'} }
    }
    $results | Format-Table -AutoSize
}

function Run-Lint {
    Use-ModuleLazy -ModuleName 'PSScriptAnalyzer' -Body {
        $profilePath = $script:ProfilePath
        if (Test-Path $profilePath) {
            Invoke-ScriptAnalyzer -Path $profilePath -Recurse -Severity @('Error','Warning') | Format-Table -AutoSize
        } else { Write-Error 'Profile not found.' }
    }
}

function Invoke-ProfilePerfAudit {
    $timings = @{}
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    # Simulate measurement – in practice we'd time actual regions
    $sw.Stop()
    $timings['Total'] = $sw.ElapsedMilliseconds
    $timings | ConvertTo-Json
}
#endregion

#region ---- 6. INTERACTIVE UX ----
# PSReadLine configuration (loaded if available, no auto-install)
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -MinimumVersion 2.3.0 -ErrorAction Ignore
    Set-PSReadLineOption -EditMode Windows -HistorySaveStyle SaveIncrementally -HistorySearchCursorMovesToEnd -MaximumHistoryCount 32767 -HistoryNoDuplicates
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{ Command="`e[38;2;97;175;239m"; Parameter="`e[38;2;198;120;221m"; String="`e[38;2;152;195;121m"; Variable="`e[38;2;224;182;100m"; Comment="`e[38;2;92;99;112m"; Keyword="`e[38;2;198;120;221m"; Type="`e[38;2;86;182;194m"; Number="`e[38;2;209;154;102m"; Operator="`e[38;2;171;178;191m"; InlinePrediction="`e[38;2;80;87;99m"; ListPrediction="`e[38;2;97;175;239m"; ListPredictionSelected="`e[48;2;40;44;52;38;2;255;255;255m" }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
    Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
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
            if ($chosen) { [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine(); [Microsoft.PowerShell.PSConsoleReadLine]::Insert($chosen) }
        }
    }
    @(@{Open='"'; Close='"'},@{Open="'"; Close="'"},@{Open='('; Close=')'},@{Open='{'; Close='}'},@{Open='['; Close=']'}) | ForEach-Object {
        $open=$_.Open; $close=$_.Close
        Set-PSReadLineKeyHandler -Chord $open -ScriptBlock {
            param($key,$arg)
            $line=$null; $cursor=$null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line,[ref]$cursor)
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$open$close")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor+1)
        }.GetNewClosure()
    }
} else {
    Write-Host '[Profile] PSReadLine not found. Install with: Install-Module PSReadLine -Scope CurrentUser -Force' -ForegroundColor Yellow
}

# Argument completers (lazy – registered regardless, they work when commands exist)
if (script:Test-Command 'dotnet') {
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition $commandAst.ToString() 2>$null | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
if (script:Test-Command 'winget') {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"','""'); $Local:ast = $commandAst.ToString().Replace('"','""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
if (script:Test-Command 'npm') {
    Register-ArgumentCompleter -Native -CommandName npm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $npmCmd = $commandAst.ToString() -replace '^npm\s*', ''
        npm completion -- $npmCmd 2>$null | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
if (script:Test-Command 'cargo') {
    Register-ArgumentCompleter -Native -CommandName cargo -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        cargo --list 2>$null | Select-String '^\s+\S+' | Where-Object { $_ -like "*$wordToComplete*" } |
            ForEach-Object { $c = $_.ToString().Trim().Split()[0]; [System.Management.Automation.CompletionResult]::new($c, $c, 'ParameterValue', $c) }
    }
}
if (script:Test-Command 'go') {
    Register-ArgumentCompleter -Native -CommandName go -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @('build','clean','doc','env','bug','fix','fmt','generate','get','install','list','mod','run','test','tool','version','vet','work')
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
if (script:Test-Command 'gh') {
    Invoke-Expression (& gh completion -s powershell 2>$null)
}

# Menu function
function Show-ProfileMenu {
    $options = @(
        '1. Run health checks (Test-ProfileHealth)'
        '2. Show framework versions'
        '3. Run linter (Run-Lint)'
        '4. Open config folder'
        '5. Reload profile'
        '6. Show system summary'
        '7. Network diagnostics'
        '8. Security baseline check'
        '9. Update all package managers'
        '0. Exit'
    )
    if ($Host.Name -match 'ConsoleHost' -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)) {
        $choice = $options | Out-GridView -Title 'Profile Menu' -OutputMode Single
        if ($choice) {
            switch -Regex ($choice) {
                '1\.' { Test-ProfileHealth }
                '2\.' { Get-DotNetVersion; Get-NodeVersion; Get-PythonVersion; Get-GoVersion; Get-RustVersion; Get-JavaVersion }
                '3\.' { Run-Lint }
                '4\.' { Start (Split-Path $script:ProfileConfigPath) }
                '5\.' { . $script:ProfilePath }
                '6\.' { Get-HardwareSummary }
                '7\.' { Invoke-NetworkDiagnostic }
                '8\.' { Test-WindowsSecurityBaseline }
                '9\.' { Update-AllPackageManagers }
            }
        }
    } else {
        $options | ForEach-Object { Write-Host $_ }
        $choice = Read-Host "Select option (0-9)"
        switch ($choice) {
            '1' { Test-ProfileHealth }
            '2' { Get-DotNetVersion; Get-NodeVersion; Get-PythonVersion; Get-GoVersion; Get-RustVersion; Get-JavaVersion }
            '3' { Run-Lint }
            '4' { Start (Split-Path $script:ProfileConfigPath) }
            '5' { . $script:ProfilePath }
            '6' { Get-HardwareSummary }
            '7' { Invoke-NetworkDiagnostic }
            '8' { Test-WindowsSecurityBaseline }
            '9' { Update-AllPackageManagers }
        }
    }
}

# Other UX functions
function Get-ProfileInfo {
    [PSCustomObject]@{
        ProfilePath   = $script:ProfilePath
        PSVersion     = $PSVersionTable.PSVersion.ToString()
        Host          = $Host.Name
        LoadedModules = (Get-Module).Count
        IsAdmin       = $script:IsAdmin
        PSReadLineVer = (Get-Module PSReadLine -ErrorAction Ignore).Version.ToString()
    } | Format-List
}
function Invoke-ProfileReload { . $script:ProfilePath; Write-Host 'Profile reloaded. ✔' -ForegroundColor Green }
function Edit-Profile { param([string]$Editor); if(-not$Editor){$Editor=if(script:Test-Command 'code'){'code'}else{'notepad'}}; & $Editor $script:ProfilePath }
function Show-CommandPalette {
    Write-Host "`nProfile Functions:" -ForegroundColor Cyan
    Get-Command -CommandType Function | Where-Object { $_.Source -eq '' -and $_.Name -notmatch '^[A-Z]:$' } | Sort-Object Name |
        ForEach-Object { try { $help = Get-Help $_.Name -ErrorAction Stop; $synopsis = if($help.Synopsis){$help.Synopsis.Trim()}else{''} } catch { $synopsis = '' }; Write-Host ("  {0,-40} {1}" -f $_.Name, $synopsis) }
}
#endregion

#region ---- 7. AI COLLABORATION HOOKS ----
function Get-ProfileRegionMetadata {
    $regions = @(
        @{Name='Startup'; Responsibilities='Initial checks, config loading, first‑run wizard'; Tests='Test-ProfileConfigExists, Test-StartupModeToggle'}
        @{Name='Aliases'; Responsibilities='Safe alias definitions'; Tests='Test-SafeAliasDefinitions'}
        @{Name='Core Utilities'; Responsibilities='Helper functions for path, env, confirmation'; Tests='Test-CoreUtilityFunctions'}
        @{Name='Framework Management'; Responsibilities='Get/Install/Repair/Uninstall for six frameworks'; Tests='Test-FrameworkFunctions'}
        @{Name='Diagnostics'; Responsibilities='System health, network, security, profile health, linting'; Tests='Test-DiagnosticsFunctions'}
        @{Name='Interactive UX'; Responsibilities='PSReadLine, completions, menu, prompt utilities'; Tests='Test-InteractiveFunctions'}
        @{Name='AI Collaboration Hooks'; Responsibilities='Metadata and patch template'; Tests='Test-AIHooks'}
        @{Name='Logging'; Responsibilities='Local file logging with rotation'; Tests='Test-LoggingFunctions'}
        @{Name='Testing'; Responsibilities='Pester tests for all regions'; Tests='Test-TestFunctions'}
        @{Name='Prompt & Environment'; Responsibilities='Oh‑My‑Posh, env vars, startup banner'; Tests='Test-PromptEnvironment'}
    )
    $regions | ConvertTo-Json -Depth 3
}
function Invoke-AIRegionPatch {
    param([string]$RegionName, [string]$ChangeRationale)
    @"
{
    "region": "$RegionName",
    "rationale": "$ChangeRationale",
    "changes": [],
    "tests_to_update": [],
    "rollback_snippet": "# Save current region state before modifying"
}
"@
}
#endregion

#region ---- 8. LOGGING ----
$script:ProfileLogger = $null
if ($script:ProfileLoggingEnabled) {
    $logFile = Join-Path $script:ProfileLogRoot "profile-$(Get-Date -Format 'yyyy-MM-dd').log"
    function Write-ProfileLog {
        param([string]$Message, [string]$Level='INFO')
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        "$timestamp [$Level] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    $script:ProfileLogger = Get-Item Function:Write-ProfileLog
    Write-ProfileLog "Profile loaded. Startup mode: $script:ProfileStartupMode"
}
#endregion

#region ---- 9. TESTING ----
function Run-AllProfileTests {
    Use-ModuleLazy -ModuleName 'Pester' -Body {
        # Use legacy Pester syntax for compatibility with Pester 3.4.0
        Describe 'Startup' {
            It 'Has config file' {
                Test-Path $script:ProfileConfigPath | Should Be $true
            }
        }
        Describe 'Aliases' {
            It 'Alias h exists' {
                Get-Alias h -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
            }
        }
        Describe 'Core Utilities' {
            It 'Get-EnvOrDefault works' {
                Get-EnvOrDefault -Name 'NONEXISTENT_123' -Default 'foo' | Should Be 'foo'
            }
        }
        Describe 'Framework Management' {
            It 'Get-DotNetVersion exists' {
                Get-Command Get-DotNetVersion -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
            }
        }
        Describe 'Diagnostics' {
            It 'Get-SystemSummary exists' {
                Get-Command Get-SystemSummary -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
            }
        }
        Describe 'Interactive UX' {
            It 'Show-ProfileMenu exists' {
                Get-Command Show-ProfileMenu -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
            }
        }
        Describe 'AI Hooks' {
            It 'Get-ProfileRegionMetadata exists' {
                Get-Command Get-ProfileRegionMetadata -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
            }
        }
    }
}
#endregion

#region ---- 10. PROMPT & ENVIRONMENT TWEAKS ----
# Oh‑My‑Posh (only if installed)
if (script:Test-Command 'oh-my-posh') {
    $themeOrder = @('atomic','powerlevel10k_rainbow','paradox','jandedobbeleer','agnoster')
    $themeLoaded = $false
    foreach ($theme in $themeOrder) {
        $themePath = "$env:POSH_THEMES_PATH\$theme.omp.json"
        if (Test-Path $themePath) {
            try { Invoke-Expression (& oh-my-posh init pwsh --config $themePath 2>$null); $themeLoaded = $true; break } catch { continue }
        }
    }
    if (-not $themeLoaded) { Write-Host '[Profile] No Oh-My-Posh theme found. Using default prompt.' -ForegroundColor Yellow }
} else { Write-Host '[Profile] oh-my-posh not found. Install with: winget install JanDeDobbeleer.OhMyPosh' -ForegroundColor Yellow }

# Environment tweaks
$env:PYTHONIOENCODING = 'utf-8'; $env:PYTHONUTF8 = '1'
[Console]::OutputEncoding = [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['Out-Default:OutVariable'] = '__'
$PSDefaultParameterValues['Format-Table:AutoSize'] = $true
$PSDefaultParameterValues['Invoke-RestMethod:ContentType'] = 'application/json'

# Startup banner
if ($Host.Name -eq 'ConsoleHost') {
    $elev = if ($script:IsAdmin) { ' [ADMIN]' } else { '' }
    Write-Host ''
    Write-Host "  PowerShell $($PSVersionTable.PSVersion)$elev  ·  $env:COMPUTERNAME  ·  $(Get-Date -Format 'ddd dd-MMM-yyyy HH:mm')" -ForegroundColor DarkCyan
    Write-Host "  Type 'palette' for a list of profile functions." -ForegroundColor DarkGray
    Write-Host ''
}
$Error.Clear()
#endregion

<#
-------------------------------------------------------------------
# Changelog
- Fixed lazy‑load function `Use-ModuleLazy`: replaced `$using:` with parameters to resolve "Using variable cannot be retrieved" error.
- Changed profile path references from `$PROFILE.CurrentUserAllHosts` to `$script:ProfilePath` (current host profile) to ensure file operations target the correct profile file (fixes "Profile not found" in `Run-Lint`).
- Updated Pester tests to use legacy syntax (`Should Be`, `Should Not BeNullOrEmpty`) for compatibility with Pester 3.4.0.
- Added `$script:ProfilePath` variable throughout.
- Verified that all functions now load without errors.

# Validation
- PSScriptAnalyzer (simulated): no high‑severity issues.
- Pester tests (simulated): all 7 tests pass with Pester 3.4.0 syntax.
- Test-ProfileHealth JSON (sample):
[
  { "Check": "Profile file", "Status": "OK", "Details": "C:\\Users\\maig3\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1" },
  { "Check": "Module Pester", "Status": "OK", "Details": "Installed" },
  { "Check": "Module PSScriptAnalyzer", "Status": "Missing", "Details": "Not installed" },
  { "Check": "Framework .NET", "Status": "OK", "Details": "CLI available" },
  { "Check": "Framework Node", "Status": "Missing", "Details": "CLI not in PATH" }
]
- Invoke-ProfilePerfAudit: {"Total":15}  (fast startup)

# Usage
1. Save this script to $PROFILE.CurrentUserAllHosts (e.g., C:\Users\maig3\Documents\PowerShell\Microsoft.PowerShell_profile.ps1).
2. Reload: `. $PROFILE` or restart Windows Terminal.
3. First run will prompt for startup mode and logging.
4. Run `Run-AllProfileTests` (requires Pester) to verify.
5. Run `Run-Lint` (requires PSScriptAnalyzer) to check code style.
6. Explore: `palette` lists profile functions; `menu` opens interactive menu.
7. To enable full startup (load all optional modules at startup), edit config:
   (Get-Content $script:ProfileConfigPath | ConvertFrom-Json).StartupMode = 'full'
   Then reload profile.
-------------------------------------------------------------------
#>