#region Initialization & Oh-My-Posh
# Initialize Oh-My-Posh with a powerline theme optimized for Windows Terminal
try {
    $env:POSH_THEME = "$env:POSH_THEMES_PATH/powerlevel10k_rainbow.omp.json"
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config $env:POSH_THEME | Invoke-Expression
    }
} catch {
    Write-Warning "Oh-My-Posh initialization failed: $_"
}
#endregion

#region PSReadLine Configuration - Advanced
# Modern PSReadLine settings for PowerShell 7.5+
$PSReadLineOptions = @{
    EditMode = 'Windows'
    BellStyle = 'None'
    PredictionSource = 'HistoryAndPlugin'
    PredictionViewStyle = 'ListView'
    MaximumHistoryCount = 10000
    HistorySearchCursorMovesToEnd = $true
    ShowToolTips = $true
    ExtraPromptLineCount = 1
    HighlightEntireLine = $false
    Colors = @{
        Command = '#87CEEB'
        Parameter = '#98FB98'
        Operator = '#FFB6C1'
        Variable = '#DDA0DD'
        String = '#FFD700'
        Number = '#FF6B6B'
        Type = '#87CEFA'
        Comment = '#808080'
        Keyword = '#DA70D6'
        Error = '#FF4500'
        Prediction = '#708090'
        Selection = '#FFFFFF'
        Default = '#F0F0F0'
    }
}

Set-PSReadLineOption @PSReadLineOptions

# Advanced key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function Complete
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+Shift+RightArrow' -Function SelectNextWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+Shift+LeftArrow' -Function SelectBackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function SelectAll
Set-PSReadLineKeyHandler -Chord 'Ctrl+Shift+End' -Function SelectLine
Set-PSReadLineKeyHandler -Chord 'Alt+Delete' -Function DeleteLine
Set-PSReadLineKeyHandler -Chord 'Ctrl+Alt+b' -Function ShowParameterHelp
Set-PSReadLineKeyHandler -Chord 'F1' -Function ShowCommandHelp
Set-PSReadLineKeyHandler -Chord 'Ctrl+Alt+e' -Function ViEditVisually

# Fuzzy search with Ctrl+T (requires fzf module)
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock {
    $result = fzf --height 40% --layout=reverse --border
    if ($result) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
    }
}

# Directory navigation with Ctrl+O
Set-PSReadLineKeyHandler -Chord 'Ctrl+o' -ScriptBlock {
    $path = Get-ChildItem -Directory | Select-Object -ExpandProperty Name | fzf --height 40%
    if ($path) {
        Set-Location $path
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}
#endregion

#region Package Managers & Runtime Configuration

# Winget Configuration
$env:WINGET_INSTALLER_PROGRESS = 'disabled'

# Chocolatey Profile (if installed)
if (Test-Path "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1") {
    Import-Module "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
}

# Scoop Configuration
if (Test-Path "$env:USERPROFILE/scoop/shims") {
    $env:PATH = "$env:USERPROFILE/scoop/shims;$env:PATH"
}

# Node Version Manager (fnm)
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd | Out-String | Invoke-Expression
}

# Python Pyenv
if (Test-Path "$env:USERPROFILE/.pyenv/pyenv-win/bin") {
    $env:PYENV_ROOT = "$env:USERPROFILE/.pyenv/pyenv-win"
    $env:PATH = "$env:PYENV_ROOT/bin;$env:PYENV_ROOT/shims;$env:PATH"
}

# Rust Cargo
if (Test-Path "$env:USERPROFILE/.cargo/bin") {
    $env:PATH = "$env:USERPROFILE/.cargo/bin;$env:PATH"
}

# Go
if (Test-Path "$env:USERPROFILE/go/bin") {
    $env:PATH = "$env:USERPROFILE/go/bin;$env:PATH"
}

# Java (SDKMAN style or manual)
if (Test-Path "$env:ProgramFiles/Eclipse Adoptium") {
    $latestJava = Get-ChildItem "$env:ProgramFiles/Eclipse Adoptium" | Sort-Object Name -Descending | Select-Object -First 1
    if ($latestJava) {
        $env:JAVA_HOME = $latestJava.FullName
        $env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
    }
}

# .NET SDK
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# Azure CLI Completion
if (Get-Command az -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $completionFile = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completionFile
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        az 2>&1 | Out-Null
        Get-Content $completionFile | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item $completionFile
    }
}
#endregion

#region System Administration & Hardware Functions

function Get-SystemHealth {
    <#
    .SYNOPSIS
    Comprehensive system health check
    .DESCRIPTION
    Analyzes CPU, memory, disk, and thermal status
    #>
    [CmdletBinding()]
    param()

    $health = @{}

    # CPU Information
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $health.CPU = @{
        Name = $cpu.Name
        LoadPercentage = $cpu.LoadPercentage
        NumberOfCores = $cpu.NumberOfCores
        NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
        MaxClockSpeed = "$($cpu.MaxClockSpeed) MHz"
        Status = $cpu.Status
    }

    # Memory Information
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMemory = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemory = $totalMemory - $freeMemory
    $memoryPercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)

    $health.Memory = @{
        TotalGB = $totalMemory
        FreeGB = $freeMemory
        UsedGB = $usedMemory
        UsagePercent = $memoryPercent
        Status = if ($memoryPercent -gt 90) { 'Critical' } elseif ($memoryPercent -gt 75) { 'Warning' } else { 'Normal' }
    }

    # Disk Information
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $size = [math]::Round($_.Size / 1GB, 2)
        $free = [math]::Round($_.FreeSpace / 1GB, 2)
        $used = $size - $free
        $percent = if ($size -gt 0) { [math]::Round(($used / $size) * 100, 2) } else { 0 }

        [PSCustomObject]@{
            Drive = $_.DeviceID
            Label = $_.VolumeName
            TotalGB = $size
            FreeGB = $free
            UsedGB = $used
            UsagePercent = $percent
            Status = if ($percent -gt 90) { 'Critical' } elseif ($percent -gt 80) { 'Warning' } else { 'Normal' }
            FileSystem = $_.FileSystem
        }
    }
    $health.Disks = $disks

    # Uptime
    $uptime = (Get-Date) - $os.LastBootUpTime
    $health.Uptime = @{
        Days = $uptime.Days
        Hours = $uptime.Hours
        Minutes = $uptime.Minutes
        TotalHours = [math]::Round($uptime.TotalHours, 2)
    }

    # Thermal (if available)
    try {
        $thermal = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction Stop | ForEach-Object {
            [math]::Round(($_.CurrentTemperature / 10) - 273.15, 2)
        }
        $health.Thermal = @{
            TemperaturesC = $thermal
            AverageTemp = if ($thermal) { ($thermal | Measure-Object -Average).Average } else { $null }
        }
    } catch {
        $health.Thermal = @{ Status = 'Not Available' }
    }

    [PSCustomObject]$health | Format-List
}

function Repair-SystemHealth {
    <#
    .SYNOPSIS
    Performs system repair operations
    .DESCRIPTION
    Runs DISM and SFC to repair system files
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$DeepScan,
        [switch]$RestoreHealth
    )

    if ($PSCmdlet.ShouldProcess("System", "Repair")) {
        Write-Host "Starting system repair sequence..." -ForegroundColor Cyan

        if ($RestoreHealth -or $DeepScan) {
            Write-Host "Running DISM /RestoreHealth..." -ForegroundColor Yellow
            Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/RestoreHealth" -Wait -NoNewWindow
        }

        Write-Host "Running DISM /ScanHealth..." -ForegroundColor Yellow
        Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/ScanHealth" -Wait -NoNewWindow

        Write-Host "Running SFC /scannow..." -ForegroundColor Yellow
        Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow -Verb RunAs

        Write-Host "System repair completed. Check logs for details." -ForegroundColor Green
    }
}

function Optimize-SystemPerformance {
    <#
    .SYNOPSIS
    Optimizes system performance
    .DESCRIPTION
    Clears temp files, optimizes drives, and manages startup items
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$CleanTemp,
        [switch]$OptimizeDrives,
        [switch]$ManageStartup
    )

    if ($CleanTemp) {
        if ($PSCmdlet.ShouldProcess("Temp Files", "Clean")) {
            $tempPaths = @($env:TEMP, "$env:SystemRoot/Temp", "$env:LOCALAPPDATA/Temp")
            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | 
                        Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt (Get-Date).AddDays(-7) } |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "Temporary files cleaned." -ForegroundColor Green
        }
    }

    if ($OptimizeDrives) {
        if ($PSCmdlet.ShouldProcess("Drives", "Optimize")) {
            Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
                Write-Host "Optimizing drive $($_.DriveLetter)..." -ForegroundColor Yellow
                Optimize-Volume -DriveLetter $_.DriveLetter -Analyze -Defrag
            }
        }
    }

    if ($ManageStartup) {
        Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | 
            Out-GridView -Title "Startup Items - Select to Disable" -OutputMode Multiple |
            ForEach-Object {
                Write-Warning "Disable startup item: $($_.Name)? Manual removal required via Task Manager or Registry."
            }
    }
}

function Get-HardwareInventory {
    <#
    .SYNOPSIS
    Detailed hardware inventory
    #>
    [CmdletBinding()]
    param()

    $inventory = @{}

    # System Info
    $cs = Get-CimInstance Win32_ComputerSystem
    $inventory.System = @{
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        SystemType = $cs.SystemType
        TotalPhysicalMemory = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        NumberOfProcessors = $cs.NumberOfProcessors
    }

    # BIOS
    $bios = Get-CimInstance Win32_BIOS
    $inventory.BIOS = @{
        Manufacturer = $bios.Manufacturer
        Name = $bios.Name
        Version = $bios.SMBIOSBIOSVersion
        SerialNumber = $bios.SerialNumber
    }

    # Motherboard
    $baseboard = Get-CimInstance Win32_BaseBoard
    $inventory.Motherboard = @{
        Manufacturer = $baseboard.Manufacturer
        Product = $baseboard.Product
        Version = $baseboard.Version
    }

    # CPU Details
    $inventory.CPUs = Get-CimInstance Win32_Processor | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Socket = $_.SocketDesignation
            Cores = $_.NumberOfCores
            Threads = $_.NumberOfLogicalProcessors
            BaseSpeed = $_.MaxClockSpeed
            L2Cache = $_.L2CacheSize
            L3Cache = $_.L3CacheSize
            Virtualization = $_.VirtualizationFirmwareEnabled
        }
    }

    # Memory Modules
    $inventory.MemoryModules = Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [PSCustomObject]@{
            BankLabel = $_.BankLabel
            DeviceLocator = $_.DeviceLocator
            Manufacturer = $_.Manufacturer
            PartNumber = $_.PartNumber
            CapacityGB = [math]::Round($_.Capacity / 1GB, 2)
            Speed = $_.Speed
            MemoryType = $_.MemoryType
            FormFactor = $_.FormFactor
        }
    }

    # Storage
    $inventory.Storage = Get-CimInstance Win32_DiskDrive | ForEach-Object {
        [PSCustomObject]@{
            Model = $_.Model
            InterfaceType = $_.InterfaceType
            SizeGB = [math]::Round($_.Size / 1GB, 2)
            MediaType = $_.MediaType
            SerialNumber = $_.SerialNumber
            Status = $_.Status
        }
    }

    # GPU
    $inventory.GPUs = Get-CimInstance Win32_VideoController | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            AdapterRAM = [math]::Round($_.AdapterRAM / 1GB, 2)
            VideoProcessor = $_.VideoProcessor
            DriverVersion = $_.DriverVersion
            VideoModeDescription = $_.VideoModeDescription
        }
    }

    # Network Adapters
    $inventory.NetworkAdapters = Get-CimInstance Win32_NetworkAdapter -Filter "NetEnabled=True" | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            AdapterType = $_.AdapterType
            MACAddress = $_.MACAddress
            Speed = if ($_.Speed) { "$([math]::Round($_.Speed / 1000000, 2)) Mbps" } else { 'N/A' }
        }
    }

    [PSCustomObject]$inventory
}

function Test-MemoryHealth {
    <#
    .SYNOPSIS
    Tests system memory for errors
    #>
    [CmdletBinding()]
    param(
        [switch]$ScheduleBootTest
    )

    if ($ScheduleBootTest) {
        Write-Host "Scheduling Windows Memory Diagnostic for next reboot..." -ForegroundColor Yellow
        Start-Process -FilePath "mdsched.exe" -ArgumentList "/restart" -Wait
    } else {
        $memory = Get-CimInstance Win32_PhysicalMemory
        $memory | ForEach-Object {
            $status = switch ($_.SMBIOSMemoryType) {
                20 { 'DDR' }
                21 { 'DDR2' }
                22 { 'DDR2 FB-DIMM' }
                24 { 'DDR3' }
                26 { 'DDR4' }
                34 { 'DDR5' }
                default { 'Unknown' }
            }

            [PSCustomObject]@{
                Device = $_.DeviceLocator
                CapacityGB = [math]::Round($_.Capacity / 1GB, 2)
                Type = $status
                Speed = $_.Speed
                Voltage = $_.ConfiguredVoltage
                Status = if ($_.Status -eq 0) { 'OK' } else { 'Error' }
            }
        }
    }
}
#endregion

#region Network Administration & Security

function Get-NetworkAnalysis {
    <#
    .SYNOPSIS
    Comprehensive network analysis
    .DESCRIPTION
    Displays network configuration, active connections, and statistics
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludePublicIP,
        [switch]$TestConnectivity
    )

    $analysis = @{}

    # Network Configuration
    $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
        [PSCustomObject]@{
            Description = $_.Description
            MACAddress = $_.MACAddress
            IPAddresses = $_.IPAddress -join ', '
            SubnetMask = $_.IPSubnet -join ', '
            DefaultGateway = $_.DefaultIPGateway -join ', '
            DNSServers = $_.DNSServerSearchOrder -join ', '
            DHCPEnabled = $_.DHCPEnabled
            DHCPServer = $_.DHCPServer
        }
    }
    $analysis.Adapters = $adapters

    # Active Connections
    $connections = Get-NetTCPConnection | Where-Object { $_.State -eq 'Established' } | 
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess,
            @{N='ProcessName'; E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name }},
            CreationTime
    $analysis.ActiveConnections = $connections

    # Network Statistics
    $stats = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface | 
        Select-Object Name, BytesReceivedPerSec, BytesSentPerSec, PacketsReceivedPerSec, PacketsSentPerSec
    $analysis.Statistics = $stats

    # Public IP
    if ($IncludePublicIP) {
        try {
            $publicIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5
            $analysis.PublicIP = $publicIP.ip

            # IP Geolocation (basic)
            $geo = Invoke-RestMethod -Uri "https://ipapi.co/$($publicIP.ip)/json/" -TimeoutSec 5
            $analysis.Location = "$($geo.city), $($geo.region), $($geo.country_name)"
        } catch {
            $analysis.PublicIP = 'Unable to retrieve'
        }
    }

    # Connectivity Test
    if ($TestConnectivity) {
        $testResults = @()
        $targets = @('8.8.8.8', '1.1.1.1', 'google.com', 'microsoft.com')
        foreach ($target in $targets) {
            $result = Test-Connection -TargetName $target -Count 2 -ErrorAction SilentlyContinue
            $testResults += [PSCustomObject]@{
                Target = $target
                Status = if ($result) { 'Success' } else { 'Failed' }
                Latency = if ($result) { "$(($result | Measure-Object Latency -Average).Average) ms" } else { 'N/A' }
            }
        }
        $analysis.ConnectivityTests = $testResults
    }

    [PSCustomObject]$analysis | Format-List
}

function Get-NetworkSecurityStatus {
    <#
    .SYNOPSIS
    Analyzes network security configuration
    #>
    [CmdletBinding()]
    param()

    $security = @{}

    # Firewall Status
    $firewallProfiles = Get-NetFirewallProfile | ForEach-Object {
        [PSCustomObject]@{
            Profile = $_.Name
            Enabled = $_.Enabled
            DefaultInbound = $_.DefaultInboundAction
            DefaultOutbound = $_.DefaultOutboundAction
            LogFile = $_.LogFileName
        }
    }
    $security.FirewallProfiles = $firewallProfiles

    # Firewall Rules Analysis
    $activeRules = Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' } | 
        Group-Object Direction | ForEach-Object {
            [PSCustomObject]@{
                Direction = $_.Name
                Count = $_.Count
                Rules = $_.Group | Select-Object -First 5 DisplayName, Action
            }
        }
    $security.FirewallRules = $activeRules

    # Open Ports
    $listeningPorts = Get-NetTCPConnection -State Listen | 
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{N='ProcessName'; E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name }},
            @{N='Path'; E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Path }}
    $security.ListeningPorts = $listeningPorts

    # Network Shares
    $shares = Get-SmbShare | Where-Object { $_.Name -notin @('ADMIN$', 'IPC$', 'print$') } | 
        Select-Object Name, Path, Description, CurrentUses
    $security.NetworkShares = $shares

    # Windows Defender Status
    try {
        $defender = Get-MpComputerStatus
        $security.Defender = @{
            RealTimeProtection = $defender.RealTimeProtectionEnabled
            BehaviorMonitor = $defender.BehaviorMonitorEnabled
            AntivirusSignatureLastUpdated = $defender.AntivirusSignatureLastUpdated
            QuickScanAge = $defender.QuickScanAge
            FullScanAge = $defender.FullScanAge
        }
    } catch {
        $security.Defender = @{ Status = 'Unable to retrieve' }
    }

    [PSCustomObject]$security | Format-List
}

function Test-PortConnectivity {
    <#
    .SYNOPSIS
    Tests TCP/UDP port connectivity
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [int[]]$Port,

        [ValidateSet('TCP', 'UDP')]
        [string]$Protocol = 'TCP',

        [int]$Timeout = 1000
    )

    foreach ($p in $Port) {
        $result = [PSCustomObject]@{
            Target = $Target
            Port = $p
            Protocol = $Protocol
            Status = 'Unknown'
            ResponseTime = $null
        }

        if ($Protocol -eq 'TCP') {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $connection = $tcpClient.BeginConnect($Target, $p, $null, $null)
                $success = $connection.AsyncWaitHandle.WaitOne($Timeout, $false)
                $stopwatch.Stop()

                if ($success -and $tcpClient.Connected) {
                    $result.Status = 'Open'
                    $result.ResponseTime = $stopwatch.ElapsedMilliseconds
                    $tcpClient.Close()
                } else {
                    $result.Status = 'Closed/Filtered'
                }
            } catch {
                $result.Status = 'Error'
            }
        } else {
            # UDP test (limited, just checks if we can send)
            $udpClient = New-Object System.Net.Sockets.UdpClient
            try {
                $udpClient.Connect($Target, $p)
                $bytes = [System.Text.Encoding]::ASCII.GetBytes("Test")
                $udpClient.Send($bytes, $bytes.Length) | Out-Null
                $result.Status = 'Sent (UDP stateless)'
                $udpClient.Close()
            } catch {
                $result.Status = 'Error'
            }
        }

        $result
    }
}

function Get-DnsAnalysis {
    <#
    .SYNOPSIS
    Performs DNS analysis and troubleshooting
    #>
    [CmdletBinding()]
    param(
        [string]$Domain = 'google.com',
        [string]$DnsServer
    )

    $analysis = @{}

    # Current DNS servers
    $analysis.CurrentDNSServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | 
        Where-Object { $_.ServerAddresses }).ServerAddresses

    # DNS Resolution test
    try {
        $resolve = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop
        $analysis.Resolution = $resolve | Select-Object Name, Type, IPAddress, TTL
    } catch {
        $analysis.Resolution = @{ Error = $_.Exception.Message }
    }

    # Specific server test
    if ($DnsServer) {
        try {
            $customResolve = Resolve-DnsName -Name $Domain -Server $DnsServer -Type A
            $analysis.CustomServerResult = $customResolve | Select-Object Name, IPAddress
        } catch {
            $analysis.CustomServerResult = @{ Error = $_.Exception.Message }
        }
    }

    # DNS Cache
    $analysis.DNSCache = Get-DnsClientCache | Select-Object -First 10 Entry, RecordType, Data

    # Flush DNS option
    $analysis.FlushDNSCommand = 'Clear-DnsClientCache (Run as Admin)'

    [PSCustomObject]$analysis | Format-List
}

function Get-NetworkPerformance {
    <#
    .SYNOPSIS
    Measures network performance metrics
    #>
    [CmdletBinding()]
    param(
        [string]$Target = '8.8.8.8',
        [int]$Count = 10
    )

    Write-Host "Testing network performance to $Target..." -ForegroundColor Cyan

    $pings = Test-Connection -TargetName $Target -Count $Count -ErrorAction SilentlyContinue

    if ($pings) {
        $latencies = $pings | Measure-Object Latency -Average -Minimum -Maximum
        $packetLoss = (($Count - $pings.Count) / $Count) * 100

        [PSCustomObject]@{
            Target = $Target
            PacketsSent = $Count
            PacketsReceived = $pings.Count
            PacketLossPercent = [math]::Round($packetLoss, 2)
            AverageLatency = [math]::Round($latencies.Average, 2)
            MinimumLatency = $latencies.Minimum
            MaximumLatency = $latencies.Maximum
            Jitter = [math]::Round(($pings | ForEach-Object { [math]::Abs($_.Latency - $latencies.Average) } | Measure-Object -Average).Average, 2)
            Status = if ($packetLoss -eq 0) { 'Excellent' } elseif ($packetLoss -lt 5) { 'Good' } elseif ($packetLoss -lt 20) { 'Fair' } else { 'Poor' }
        }
    } else {
        Write-Error "Unable to reach target $Target"
    }
}
#endregion

#region Software Management & Updates

function Update-AllPackages {
    <#
    .SYNOPSIS
    Updates all package managers
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$Winget,
        [switch]$Chocolatey,
        [switch]$PowerShellModules,
        [switch]$All
    )

    if ($All) { $Winget = $Chocolatey = $PowerShellModules = $true }

    if ($Winget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Updating Winget packages..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Winget Packages", "Update")) {
            winget upgrade --all --accept-source-agreements --accept-package-agreements
        }
    }

    if ($Chocolatey -and (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Updating Chocolatey packages..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Chocolatey Packages", "Update")) {
            choco upgrade all -y
        }
    }

    if ($PowerShellModules) {
        Write-Host "Updating PowerShell modules..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("PowerShell Modules", "Update")) {
            Get-InstalledModule | ForEach-Object {
                try {
                    Update-Module -Name $_.Name -Force -ErrorAction Stop
                    Write-Host "Updated: $($_.Name)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to update $($_.Name): $_"
                }
            }
        }
    }
}

function Get-InstalledSoftwareInventory {
    <#
    .SYNOPSIS
    Comprehensive software inventory
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeWindowsUpdates
    )

    $inventory = @{}

    # Registry-based installed software
    $regPaths = @(
        'HKLM:/Software/Microsoft/Windows/CurrentVersion/Uninstall/*',
        'HKLM:/Software/Wow6432Node/Microsoft/Windows/CurrentVersion/Uninstall/*',
        'HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/*'
    )

    $software = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, UninstallString
    }
    $inventory.Software = $software | Sort-Object DisplayName -Unique

    # Winget installed
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetList = winget list --accept-source-agreements | Out-String
        $inventory.WingetInstalled = $wingetList
    }

    # Windows Updates
    if ($IncludeWindowsUpdates) {
        try {
            $updates = Get-CimInstance Win32_QuickFixEngineering | 
                Select-Object HotFixID, Description, InstalledBy, InstalledOn
            $inventory.WindowsUpdates = $updates
        } catch {
            $inventory.WindowsUpdates = @{ Error = 'Unable to retrieve' }
        }
    }

    [PSCustomObject]$inventory
}

function Install-DevelopmentTools {
    <#
    .SYNOPSIS
    Installs essential development tools via winget
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [ValidateSet('Basic', 'Full', 'Minimal')]
        [string]$Set = 'Basic'
    )

    $packages = switch ($Set) {
        'Minimal' { @('Git.Git', 'Microsoft.PowerShell', 'Microsoft.WindowsTerminal') }
        'Basic' { 
            @('Git.Git', 'Microsoft.PowerShell', 'Microsoft.WindowsTerminal', 'Microsoft.VisualStudioCode',
              'GitHub.cli', 'Microsoft.PowerToys', 'JanDeDobbeleer.OhMyPosh')
        }
        'Full' {
            @('Git.Git', 'Microsoft.PowerShell', 'Microsoft.WindowsTerminal', 'Microsoft.VisualStudioCode',
              'GitHub.cli', 'Microsoft.PowerToys', 'JanDeDobbeleer.OhMyPosh', 'Docker.DockerDesktop',
              'Python.Python.3.12', 'OpenJS.NodeJS', 'Microsoft.DotNet.SDK.8', 'Rustlang.Rust.MSVC',
              'GoLang.Go', 'JetBrains.Toolbox', 'Postman.Postman', 'Microsoft.SQLServerManagementStudio')
        }
    }

    foreach ($pkg in $packages) {
        if ($PSCmdlet.ShouldProcess($pkg, "Install")) {
            Write-Host "Installing $pkg..." -ForegroundColor Yellow
            winget install $pkg --accept-source-agreements --accept-package-agreements
        }
    }
}
#endregion

#region Process & Service Management

function Get-ProcessAnalysis {
    <#
    .SYNOPSIS
    Advanced process analysis with resource usage
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeServices,
        [string]$ProcessName
    )

    $processes = if ($ProcessName) {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    } else {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 20
    }

    $analysis = $processes | ForEach-Object {
        $proc = $_
        $info = [PSCustomObject]@{
            Name = $proc.Name
            Id = $proc.Id
            CPU = [math]::Round($proc.CPU, 2)
            MemoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            StartTime = $proc.StartTime
            Threads = $proc.Threads.Count
            Handles = $proc.HandleCount
            Path = $proc.Path
            Company = $proc.Company
            CommandLine = $null
        }

        # Try to get command line
        try {
            $cimProc = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)"
            $info.CommandLine = $cimProc.CommandLine
        } catch {}

        if ($IncludeServices) {
            $services = Get-CimInstance Win32_Service -Filter "ProcessId = $($proc.Id)" | Select-Object Name, State, StartMode
            $info | Add-Member -NotePropertyName Services -NotePropertyValue $services
        }

        $info
    }

    $analysis | Format-Table -AutoSize
}

function Stop-ProcessSafely {
    <#
    .SYNOPSIS
    Safely terminates processes with confirmation
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [int]$ProcessId,

        [switch]$Force
    )

    process {
        try {
            $proc = Get-Process -Id $ProcessId -ErrorAction Stop
            if ($PSCmdlet.ShouldProcess("$($proc.Name) (PID: $ProcessId)", "Terminate")) {
                if ($Force) {
                    Stop-Process -Id $ProcessId -Force
                } else {
                    $proc.CloseMainWindow()
                    Start-Sleep -Seconds 2
                    if (!$proc.HasExited) {
                        Stop-Process -Id $ProcessId -Force
                    }
                }
                Write-Host "Process terminated successfully." -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to terminate process: $_"
        }
    }
}

function Get-ServiceSecurity {
    <#
    .SYNOPSIS
    Analyzes service security configuration
    #>
    [CmdletBinding()]
    param(
        [string]$ServiceName
    )

    $services = if ($ServiceName) {
        Get-Service -Name $ServiceName
    } else {
        Get-Service | Where-Object { $_.Status -eq 'Running' }
    }

    $services | ForEach-Object {
        $svc = $_
        $cimSvc = Get-CimInstance Win32_Service -Filter "Name = '$($svc.Name)'"

        [PSCustomObject]@{
            Name = $svc.Name
            DisplayName = $svc.DisplayName
            Status = $svc.Status
            StartType = $svc.StartType
            Account = $cimSvc.StartName
            ProcessId = $cimSvc.ProcessId
            Path = $cimSvc.PathName
            Description = $cimSvc.Description
            CanStop = $svc.CanStop
            CanPauseAndContinue = $svc.CanPauseAndContinue
        }
    } | Format-Table -AutoSize
}
#endregion

#region Logging & Diagnostics

function Get-SystemEvents {
    <#
    .SYNOPSIS
    Retrieves critical system events
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('System', 'Application', 'Security', 'Setup', 'ForwardedEvents')]
        [string]$LogName = 'System',

        [ValidateSet('Critical', 'Error', 'Warning', 'Information')]
        [string[]]$Level = @('Critical', 'Error'),

        [int]$HoursBack = 24
    )

    $startTime = (Get-Date).AddHours(-$HoursBack)
    $levelMap = @{ Critical = 1; Error = 2; Warning = 3; Information = 4 }
    $levelIds = $Level | ForEach-Object { $levelMap[$_] }

    Get-WinEvent -FilterHashtable @{
        LogName = $LogName
        Level = $levelIds
        StartTime = $startTime
    } -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message | 
        Format-Table -Wrap
}

function Export-DiagnosticReport {
    <#
    .SYNOPSIS
    Exports comprehensive diagnostic report
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "$env:USERPROFILE/Desktop/DiagnosticReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Diagnostic Report - $(Get-Date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        h2 { color: #0099cc; border-bottom: 2px solid #0099cc; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0099cc; color: white; }
        .critical { color: #cc0000; font-weight: bold; }
        .warning { color: #ff9900; }
        .good { color: #009900; }
    </style>
</head>
<body>
    <h1>System Diagnostic Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Computer: $env:COMPUTERNAME</p>
    <p>User: $env:USERNAME</p>
"@

    # System Info
    $html += "<h2>System Information</h2>"
    $sysInfo = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, SystemType, TotalPhysicalMemory
    $html += $sysInfo | ConvertTo-Html -Fragment

    # CPU
    $html += "<h2>CPU Information</h2>"
    $cpu = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
    $html += $cpu | ConvertTo-Html -Fragment

    # Memory
    $html += "<h2>Memory Status</h2>"
    $os = Get-CimInstance Win32_OperatingSystem
    $memory = [PSCustomObject]@{
        TotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        FreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        UsedPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
    }
    $html += $memory | ConvertTo-Html -Fragment

    # Disk
    $html += "<h2>Disk Status</h2>"
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | 
        Select-Object DeviceID, VolumeName, @{N='SizeGB'; E={[math]::Round($_.Size/1GB,2)}}, 
            @{N='FreeGB'; E={[math]::Round($_.FreeSpace/1GB,2)}},
            @{N='Used%'; E={[math]::Round((($_.Size-$_.FreeSpace)/$_.Size)*100,2)}}
    $html += $disks | ConvertTo-Html -Fragment

    # Recent Errors
    $html += "<h2>Recent Critical Events (Last 24h)</h2>"
    $events = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddHours(-24)} -ErrorAction SilentlyContinue | 
        Select-Object -First 10 TimeCreated, Id, LevelDisplayName, ProviderName, @{N='Message'; E={$_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))}}
    $html += $events | ConvertTo-Html -Fragment

    $html += "</body></html>"

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Diagnostic report saved to: $OutputPath" -ForegroundColor Green
}
#endregion

#region Utility Functions

function Find-CommandLocation {
    <#
    .SYNOPSIS
    Locates command source
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        [PSCustomObject]@{
            Name = $cmd.Name
            CommandType = $cmd.CommandType
            Source = $cmd.Source
            Version = $cmd.Version
            Module = $cmd.Module
            Path = if ($cmd.Path) { $cmd.Path } else { 'N/A' }
        }
    } else {
        Write-Error "Command '$Command' not found."
    }
}

function Measure-CommandPerformance {
    <#
    .SYNOPSIS
    Measures command execution performance
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [int]$Iterations = 10
    )

    $times = 1..$Iterations | ForEach-Object {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $ScriptBlock | Out-Null
        $sw.Stop()
        $sw.ElapsedMilliseconds
    }

    [PSCustomObject]@{
        Iterations = $Iterations
        AverageMS = ($times | Measure-Object -Average).Average
        MinimumMS = ($times | Measure-Object -Minimum).Minimum
        MaximumMS = ($times | Measure-Object -Maximum).Maximum
        TotalMS = ($times | Measure-Object -Sum).Sum
    }
}

function Convert-ToSecureString {
    <#
    .SYNOPSIS
    Secure string conversion helper
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$String,

        [switch]$AsPlainText
    )

    if ($AsPlainText) {
        ConvertTo-SecureString -String $String -AsPlainText -Force
    } else {
        Read-Host -Prompt "Enter string to secure" -AsSecureString
    }
}

# Quick navigation aliases
function Set-LocationUp { Set-Location .. }
function Set-LocationBack { Set-Location - }
function Get-ChildItemAll { Get-ChildItem -Force }

# Aliases (using approved verbs)
Set-Alias -Name .. -Value Set-LocationUp
Set-Alias -Name ... -Value function:Set-LocationUp
Set-Alias -Name cd- -Value Set-LocationBack
Set-Alias -Name l -Value Get-ChildItemAll
Set-Alias -Name ll -Value Get-ChildItemAll
Set-Alias -Name which -Value Find-CommandLocation
Set-Alias -Name touch -Value New-Item
Set-Alias -Name grep -Value Select-String
Set-Alias -Name df -Value Get-Volume
Set-Alias -Name uptime -Value Get-SystemHealth

# Environment shortcuts
function Set-LocationHome { Set-Location $env:USERPROFILE }
function Set-LocationDesktop { Set-Location $env:USERPROFILE/Desktop }
function Set-LocationDocuments { Set-Location $env:USERPROFILE/Documents }
function Set-LocationDownloads { Set-Location $env:USERPROFILE/Downloads }

Set-Alias -Name ~ -Value Set-LocationHome
Set-Alias -Name desktop -Value Set-LocationDesktop
Set-Alias -Name docs -Value Set-LocationDocuments
Set-Alias -Name dl -Value Set-LocationDownloads
#endregion

#region Windows Terminal Specific Configuration

# Windows Terminal specific settings
if ($env:WT_SESSION) {
    # Detect if running in Windows Terminal
    $env:IS_WINDOWS_TERMINAL = $true

    # Enable advanced terminal features
    $PSStyle.OutputRendering = 'Ansi'

    # Terminal Icons (if installed)
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module Terminal-Icons
    }

    # z directory jumper (if installed)
    if (Get-Module -ListAvailable -Name z) {
        Import-Module z
    }

    # FZF integration
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        if (Get-Module -ListAvailable -Name PSFzf) {
            Import-Module PSFzf
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
        }
    }
}

# Custom prompt enhancements for Windows Terminal
function prompt {
    $loc = Get-Location
    $gitBranch = $null

    # Git branch detection
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitBranch = git branch --show-current 2>$null
    }

    # Build prompt
    $prompt = "`n"
    $prompt += "$([char]0x1b)[38;5;81m$loc$([char]0x1b)[0m"

    if ($gitBranch) {
        $prompt += " $([char]0x1b)[38;5;183m($gitBranch)$([char]0x1b)[0m"
    }

    $prompt += "`n$([char]0x1b)[38;5;118m➜$([char]0x1b)[0m "

    return $prompt
}
#endregion

#region Profile Completion Message
Write-Host "PowerShell 7.5+ Profile Loaded Successfully!" -ForegroundColor Green
Write-Host "Available modules: SystemAdmin, NetworkTools, SoftwareMgmt, Diagnostics" -ForegroundColor Cyan
Write-Host "Type 'Get-Command -Module <ModuleName>' to explore functions." -ForegroundColor Gray
#endregion
