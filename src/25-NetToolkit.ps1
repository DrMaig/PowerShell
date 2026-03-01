<#
.SYNOPSIS
    Profile component 25 - Network Toolkit
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 25 (NETWORK TOOLKIT) for modular dot-sourced loading.
#>

#region 25 - NETWORK TOOLKIT
#==============================================================================
<#
.SYNOPSIS
    Extended network diagnostics: traceroute, ARP/neighbor, port scan, NIC stats
.DESCRIPTION
    All operations are read-only and non-destructive. Port scanning is rate-limited
    and restricted to a small port set by default.
.EXAMPLE
    Invoke-Traceroute -Target 1.1.1.1
    Get-ArpTable | Format-Table
    Invoke-PortScan -Target 192.168.1.1 -Ports 22,80,443,3389
    Get-NicStatistics | Format-Table
#>

function Invoke-Traceroute {
    <#
    .SYNOPSIS
        Performs a traceroute to a target using Test-Connection.
    .PARAMETER Target
        Hostname or IP address.
    .PARAMETER MaxHops
        Maximum hop count (default: 30).
    .PARAMETER TimeoutMs
        Per-hop timeout in milliseconds.
    .EXAMPLE
        Invoke-Traceroute -Target 1.1.1.1
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,
        [ValidateRange(1, 128)][int]$MaxHops = 30,
        [ValidateRange(100, 10000)][int]$TimeoutMs = 3000
    )

    try {
        if ($Global:IsWindows -and (Get-Command Test-Connection -ErrorAction Ignore)) {
            # PowerShell 7.4+ supports -Traceroute
            if ($PSVersionTable.PSVersion -ge [version]'7.4.0') {
                return Test-Connection -TargetName $Target -Traceroute -MaxHops $MaxHops -TimeoutSeconds ([math]::Ceiling($TimeoutMs / 1000)) -ErrorAction Stop
            }
        }
        # Fallback: parse tracert output
        $output = tracert -d -h $MaxHops -w $TimeoutMs $Target 2>&1
        $hops = @()
        foreach ($line in $output) {
            if ($line -match '^\s*(\d+)\s+(?:(\d+)\s+ms|(\*)\s+)\s+(?:(\d+)\s+ms|(\*)\s+)\s+(?:(\d+)\s+ms|(\*)\s+)\s+(.+)$') {
                $hops += [PSCustomObject]@{
                    Hop     = [int]$Matches[1]
                    RTT1Ms  = if ($Matches[2]) { [int]$Matches[2] } else { $null }
                    RTT2Ms  = if ($Matches[4]) { [int]$Matches[4] } else { $null }
                    RTT3Ms  = if ($Matches[6]) { [int]$Matches[6] } else { $null }
                    Address = $Matches[8].Trim()
                }
            }
        }
        return $hops
    } catch {
        Write-CaughtException -Context "Invoke-Traceroute $Target" -ErrorRecord $_ -Component "NetToolkit" -Level WARN
        return @()
    }
}

function Get-ArpTable {
    <#
    .SYNOPSIS
        Retrieves ARP/neighbor cache entries.
    .EXAMPLE
        Get-ArpTable | Format-Table -AutoSize
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    if (-not $Global:IsWindows) { return @() }

    try {
        if (Get-Command Get-NetNeighbor -ErrorAction Ignore) {
            return Get-NetNeighbor -ErrorAction SilentlyContinue |
                Where-Object { $_.State -ne 'Unreachable' } |
                Select-Object IPAddress, LinkLayerAddress, State, InterfaceAlias
        }
        # Fallback to arp -a
        $output = arp -a 2>$null
        $entries = @()
        foreach ($line in $output) {
            if ($line -match '^\s*([\d.]+)\s+([\w-]+)\s+(\w+)') {
                $entries += [PSCustomObject]@{
                    IPAddress        = $Matches[1]
                    LinkLayerAddress = $Matches[2]
                    State            = $Matches[3]
                }
            }
        }
        return $entries
    } catch {
        Write-CaughtException -Context "Get-ArpTable" -ErrorRecord $_ -Component "NetToolkit" -Level WARN
        return @()
    }
}

function Invoke-PortScan {
    <#
    .SYNOPSIS
        Rate-limited, non-destructive TCP port scan.
    .DESCRIPTION
        Tests a small set of TCP ports on a single target. Maximum 100 ports per call
        with a configurable delay between probes to avoid flooding.
    .PARAMETER Target
        Hostname or IP address.
    .PARAMETER Ports
        Array of port numbers (max 100).
    .PARAMETER TimeoutMs
        Per-port timeout.
    .PARAMETER DelayMs
        Delay between probes (rate limiting).
    .EXAMPLE
        Invoke-PortScan -Target 192.168.1.1 -Ports 22,80,443,3389
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,
        [ValidateCount(1, 100)]
        [ValidateRange(1, 65535)]
        [int[]]$Ports = @(21,22,23,25,53,80,110,135,139,143,443,445,993,995,1433,3306,3389,5432,5900,8080),
        [ValidateRange(100, 10000)][int]$TimeoutMs = 1000,
        [ValidateRange(0, 5000)][int]$DelayMs = 50
    )

    $results = @()
    foreach ($port in $Ports) {
        $open = Test-TcpPort -HostName $Target -Port $port -TimeoutMs $TimeoutMs
        $results += [PSCustomObject]@{
            Target  = $Target
            Port    = $port
            Open    = $open
            Service = switch ($port) {
                21 {'FTP'}; 22 {'SSH'}; 23 {'Telnet'}; 25 {'SMTP'}; 53 {'DNS'}
                80 {'HTTP'}; 110 {'POP3'}; 135 {'RPC'}; 139 {'NetBIOS'}; 143 {'IMAP'}
                443 {'HTTPS'}; 445 {'SMB'}; 993 {'IMAPS'}; 995 {'POP3S'}
                1433 {'MSSQL'}; 3306 {'MySQL'}; 3389 {'RDP'}; 5432 {'PostgreSQL'}
                5900 {'VNC'}; 8080 {'HTTP-Alt'}; default {'Unknown'}
            }
        }
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }
    return $results
}

function Get-NicStatistics {
    <#
    .SYNOPSIS
        Retrieves NIC statistics (bytes sent/received, errors).
    .EXAMPLE
        Get-NicStatistics | Format-Table -AutoSize
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    if (-not $Global:IsWindows) { return @() }

    try {
        if (-not (Get-Command Get-NetAdapterStatistics -ErrorAction Ignore)) { return @() }
        Get-NetAdapterStatistics -ErrorAction SilentlyContinue |
            Select-Object Name,
                @{N='ReceivedGB';E={[math]::Round($_.ReceivedBytes/1GB,3)}},
                @{N='SentGB';E={[math]::Round($_.SentBytes/1GB,3)}},
                ReceivedUnicastPackets, SentUnicastPackets,
                InboundDiscardedPackets, OutboundDiscardedPackets
    } catch {
        Write-CaughtException -Context "Get-NicStatistics" -ErrorRecord $_ -Component "NetToolkit" -Level WARN
        return @()
    }
}

function Get-LinkSpeed {
    <#
    .SYNOPSIS
        Returns link speed for active network adapters.
    .EXAMPLE
        Get-LinkSpeed | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    if (-not $Global:IsWindows) { return @() }

    try {
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object Status -eq 'Up' |
            Select-Object Name, InterfaceDescription, LinkSpeed, MediaType, FullDuplex
    } catch {
        Write-CaughtException -Context "Get-LinkSpeed" -ErrorRecord $_ -Component "NetToolkit" -Level DEBUG
        return @()
    }
}

function Test-DnsResolution {
    <#
    .SYNOPSIS
        Tests DNS resolution for a name across multiple DNS servers.
    .PARAMETER Name
        DNS name to resolve.
    .PARAMETER DnsServers
        Servers to query (default: current + Cloudflare + Google).
    .PARAMETER RecordType
        DNS record type (default: A).
    .EXAMPLE
        Test-DnsResolution -Name "github.com" | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$DnsServers = @('', '1.1.1.1', '8.8.8.8'),
        [ValidateSet('A','AAAA','MX','NS','SOA','TXT','CNAME','SRV','PTR')]
        [string]$RecordType = 'A'
    )

    if (-not $Global:IsWindows -or -not (Get-Command Resolve-DnsName -ErrorAction Ignore)) {
        Write-ProfileLog "Test-DnsResolution requires Windows Resolve-DnsName" -Level WARN -Component "NetToolkit"
        return @()
    }

    $results = @()
    foreach ($server in $DnsServers) {
        $label = if ($server -eq '') { 'System DNS' } else { $server }
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $dnsParams = @{ Name = $Name; Type = $RecordType; ErrorAction = 'Stop'; DnsOnly = $true }
            if ($server -ne '') { $dnsParams.Server = $server }
            $answer = Resolve-DnsName @dnsParams
            $sw.Stop()
            $results += [PSCustomObject]@{
                Server     = $label
                Name       = $Name
                Type       = $RecordType
                Resolved   = $true
                LatencyMs  = [int]$sw.ElapsedMilliseconds
                Addresses  = ($answer | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ', '
            }
        } catch {
            $results += [PSCustomObject]@{
                Server     = $label
                Name       = $Name
                Type       = $RecordType
                Resolved   = $false
                LatencyMs  = $null
                Addresses  = $null
            }
        }
    }
    return $results
}

#endregion ADDED: NETWORK TOOLKIT
