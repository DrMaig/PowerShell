<#
.SYNOPSIS
    Profile component 27 - Secure Remote Management
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 27 (SECURE REMOTE MANAGEMENT) for modular dot-sourced loading.
#>

#region 27 - SECURE REMOTE MANAGEMENT
#==============================================================================
<#
.SYNOPSIS
    Safe wrappers for PS remoting with connection validation and session cleanup.
.DESCRIPTION
    Provides secure remote session management with credential prompts,
    connection testing, and automatic session disposal.
    No credentials are stored or logged.
.EXAMPLE
    $session = Connect-RemoteHost -ComputerName Server01
    Invoke-RemoteCommand -ComputerName Server01 -ScriptBlock { Get-Service }
#>

function Test-RemoteHost {
    <#
    .SYNOPSIS
        Tests if a remote host is reachable via WinRM/PSRemoting.
    .PARAMETER ComputerName
        Target computer name or IP.
    .PARAMETER Port
        WinRM port (default: 5985).
    .PARAMETER UseSSL
        Use HTTPS/5986.
    .PARAMETER TimeoutMs
        Connection timeout.
    .EXAMPLE
        Test-RemoteHost -ComputerName Server01
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ComputerName,
        [ValidateRange(1, 65535)][int]$Port = 5985,
        [switch]$UseSSL,
        [ValidateRange(100, 30000)][int]$TimeoutMs = 3000
    )

    if ($UseSSL -and $Port -eq 5985) { $Port = 5986 }

    $tcpOk = Test-TcpPort -HostName $ComputerName -Port $Port -TimeoutMs $TimeoutMs
    [PSCustomObject]@{
        ComputerName = $ComputerName
        Port         = $Port
        UseSSL       = [bool]$UseSSL
        Reachable    = $tcpOk
        Timestamp    = (Get-Date).ToString('o')
    }
}

function Connect-RemoteHost {
    <#
    .SYNOPSIS
        Creates a validated PSSession to a remote host.
    .DESCRIPTION
        Prompts for credentials, tests connectivity, then creates a session.
        Returns the session object or $null on failure.
    .PARAMETER ComputerName
        Target computer.
    .PARAMETER Credential
        PSCredential (prompted if not supplied).
    .PARAMETER UseSSL
        Use HTTPS transport.
    .PARAMETER ConfigurationName
        Remote endpoint configuration (e.g., 'Microsoft.PowerShell').
    .EXAMPLE
        $s = Connect-RemoteHost -ComputerName Server01
        Enter-PSSession $s
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ComputerName,
        [PSCredential]$Credential,
        [switch]$UseSSL,
        [string]$ConfigurationName
    )

    # Test connectivity first
    $test = Test-RemoteHost -ComputerName $ComputerName -UseSSL:$UseSSL
    if (-not $test.Reachable) {
        Write-Host "Remote host '$ComputerName' is not reachable on port $($test.Port)." -ForegroundColor Yellow
        return $null
    }

    # Prompt for credentials if not provided
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Credentials for $ComputerName"
        if (-not $Credential) { return $null }
    }

    try {
        $sessParams = @{
            ComputerName = $ComputerName
            Credential   = $Credential
            ErrorAction  = 'Stop'
        }
        if ($UseSSL) { $sessParams.UseSSL = $true }
        if ($ConfigurationName) { $sessParams.ConfigurationName = $ConfigurationName }

        $session = New-PSSession @sessParams
        Write-ProfileLog "Connected to $ComputerName (Session $($session.Id))" -Level INFO -Component "Remoting"
        return $session
    } catch {
        Write-CaughtException -Context "Connect-RemoteHost $ComputerName" -ErrorRecord $_ -Component "Remoting" -Level WARN
        return $null
    }
}

function Invoke-RemoteCommand {
    <#
    .SYNOPSIS
        Runs a command on a remote host with automatic session cleanup.
    .DESCRIPTION
        Creates a temporary session, runs the command, returns results, and
        removes the session. Credentials are prompted if not supplied.
    .PARAMETER ComputerName
        Target computer.
    .PARAMETER ScriptBlock
        Code to execute remotely.
    .PARAMETER Credential
        PSCredential (prompted if not supplied).
    .PARAMETER ArgumentList
        Arguments to pass to the script block.
    .EXAMPLE
        Invoke-RemoteCommand -ComputerName Server01 -ScriptBlock { Get-Service }
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ComputerName,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [PSCredential]$Credential,
        [object[]]$ArgumentList
    )

    if (-not $PSCmdlet.ShouldProcess($ComputerName, 'Execute remote command')) { return }

    $session = Connect-RemoteHost -ComputerName $ComputerName -Credential $Credential
    if (-not $session) { return }

    try {
        $invokeParams = @{
            Session      = $session
            ScriptBlock  = $ScriptBlock
            ErrorAction  = 'Stop'
        }
        if ($ArgumentList) { $invokeParams.ArgumentList = $ArgumentList }

        return Invoke-Command @invokeParams
    } catch {
        Write-CaughtException -Context "Invoke-RemoteCommand $ComputerName" -ErrorRecord $_ -Component "Remoting" -Level WARN
    } finally {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        Write-ProfileLog "Session to $ComputerName cleaned up" -Level DEBUG -Component "Remoting"
    }
}

function Get-RemoteSessions {
    <#
    .SYNOPSIS
        Lists active PSSessions.
    .EXAMPLE
        Get-RemoteSessions | Format-Table
    #>
    [CmdletBinding()]
    param()
    Get-PSSession | Select-Object Id, Name, ComputerName, State, Availability, ConfigurationName
}

function Remove-AllRemoteSessions {
    <#
    .SYNOPSIS
        Removes all active PSSessions.
    .EXAMPLE
        Remove-AllRemoteSessions
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $sessions = Get-PSSession
    if ($sessions.Count -eq 0) {
        Write-Host "No active sessions." -ForegroundColor DarkGray
        return
    }
    foreach ($s in $sessions) {
        if ($PSCmdlet.ShouldProcess("Session $($s.Id) to $($s.ComputerName)", 'Remove')) {
            Remove-PSSession -Session $s -ErrorAction SilentlyContinue
            Write-ProfileLog "Removed session $($s.Id) to $($s.ComputerName)" -Level DEBUG -Component "Remoting"
        }
    }
}

# Guidance: For constrained endpoints, connect with:
#   New-PSSession -ComputerName $host -ConfigurationName 'MyConstrainedEndpoint'
# See: https://learn.microsoft.com/powershell/scripting/learn/remoting/jea/overview

#endregion ADDED: SECURE REMOTE MANAGEMENT
