<#
.SYNOPSIS
    Profile component 10 - Dns Profiles And Quick Switching
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 10 (DNS PROFILES AND QUICK SWITCHING) for modular dot-sourced loading.
#>

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
