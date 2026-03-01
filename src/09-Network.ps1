<#
.SYNOPSIS
    Profile component 09 - Network Management And Dns Functions
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 9 (NETWORK MANAGEMENT AND DNS FUNCTIONS) for modular dot-sourced loading.
#>

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
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        [ValidateRange(100, 30000)]
        [int]$TimeoutMs = 1200
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $null
        $waitHandle = $null

        try {
            $async = $client.BeginConnect($HostName, $Port, $null, $null)
            $waitHandle = $async.AsyncWaitHandle
            $ok = $waitHandle.WaitOne($TimeoutMs, $false)

            if (-not $ok) {
                return $false
            }

            try {
                $client.EndConnect($async)
            } catch {
                return $false
            }

            return $true
        } finally {
            if ($waitHandle) {
                try { $waitHandle.Dispose() } catch { Write-ProfileLog "TCP wait handle cleanup failed: $($_.Exception.Message)" -Level DEBUG -Component "Network" }
            }
            if ($client) {
                try { $client.Dispose() } catch { Write-ProfileLog "TCP client cleanup failed: $($_.Exception.Message)" -Level DEBUG -Component "Network" }
            }
        }
    } catch {
        Write-CaughtException -Context "Test-TcpPort failed (${HostName}:$Port)" -ErrorRecord $_ -Component "Network" -Level DEBUG
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
            } catch {
                Write-ProfileLog "Public IP provider failed ($p): $($_.Exception.Message)" -Level DEBUG -Component "Network"
                continue
            }
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
        if (-not (Get-Command Get-NetAdapter -ErrorAction Ignore)) { return @() }

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
        if (-not (Get-Command Get-DnsClientServerAddress -ErrorAction Ignore)) {
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

    try { $snap.LocalIP = Get-LocalIP } catch { Write-CaughtException -Context "Get-NetworkSnapshot LocalIP" -ErrorRecord $_ -Component "Network" -Level DEBUG }
    try { $snap.PublicIP = Get-PublicIP } catch { Write-CaughtException -Context "Get-NetworkSnapshot PublicIP" -ErrorRecord $_ -Component "Network" -Level DEBUG }

    if ($Global:IsWindows) {
        try {
            $snap.DnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Select-Object InterfaceAlias, ServerAddresses
        } catch {
            Write-CaughtException -Context "Get-NetworkSnapshot DNS query" -ErrorRecord $_ -Component "Network" -Level DEBUG
        }

        try {
            $snap.DefaultRoutes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Select-Object InterfaceAlias, NextHop, RouteMetric, ifIndex
        } catch {
            Write-CaughtException -Context "Get-NetworkSnapshot route query" -ErrorRecord $_ -Component "Network" -Level DEBUG
        }

        try {
            $snap.NetAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
                Select-Object Name, Status, LinkSpeed, MacAddress
        } catch {
            Write-CaughtException -Context "Get-NetworkSnapshot adapter query" -ErrorRecord $_ -Component "Network" -Level DEBUG
        }
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
        DnsError  = $null
        TcpError  = $null
        Timestamp = (Get-Date).ToString('o')
    }

    # DNS test
    try {
        if ($Global:IsWindows -and (Get-Command Resolve-DnsName -ErrorAction Ignore)) {
            $dns = Resolve-DnsName -Name $DnsName -ErrorAction SilentlyContinue -TimeoutSeconds ([math]::Ceiling($TimeoutMs / 1000))
            $result.Dns = $null -ne $dns
        } else {
            # Fallback TCP test
            $result.Dns = Test-TcpPort -HostName $TcpHost -Port $TcpPort -TimeoutMs $TimeoutMs
        }
    } catch {
        $result.DnsError = $_.Exception.Message
        Write-CaughtException -Context "Test-Internet DNS test" -ErrorRecord $_ -Component "Network" -Level DEBUG
    }

    # TCP test
    try {
        $result.Tcp = Test-TcpPort -HostName $TcpHost -Port $TcpPort -TimeoutMs $TimeoutMs
    } catch {
        $result.TcpError = $_.Exception.Message
        Write-CaughtException -Context "Test-Internet TCP test" -ErrorRecord $_ -Component "Network" -Level DEBUG
    }

    return [PSCustomObject]$result
}

#endregion NETWORK MANAGEMENT AND DNS FUNCTIONS
