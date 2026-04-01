<#
.SYNOPSIS
    Profile component 03 - Logging And Telemetry Framework
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 3 (LOGGING AND TELEMETRY FRAMEWORK) for modular dot-sourced loading.
#>

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
            } catch {
                Write-Verbose "Write-ProfileLog file sink failed: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Verbose "Write-ProfileLog failed: $($_.Exception.Message)"
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

function Get-ExceptionSummary {
    <#
    .SYNOPSIS
        Builds a concise exception summary string.
    .DESCRIPTION
        Flattens exception and inner exception messages up to a maximum depth.
    .PARAMETER Exception
        Exception instance to summarize.
    .PARAMETER MaxDepth
        Maximum inner exception depth.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Exception]$Exception,
        [int]$MaxDepth = 3
    )

    $parts = @()
    $depth = 0
    $cursor = $Exception

    while ($null -ne $cursor -and $depth -lt $MaxDepth) {
        $parts += "$($cursor.GetType().Name): $($cursor.Message)"
        $cursor = $cursor.InnerException
        $depth++
    }

    return ($parts -join ' | ')
}

function Write-CaughtException {
    <#
    .SYNOPSIS
        Standardized catch-block logger.
    .DESCRIPTION
        Writes a consistent, compact exception summary for handled failures.
    .PARAMETER Context
        Human-readable operation context.
    .PARAMETER ErrorRecord
        Error record captured in catch (`$_`).
    .PARAMETER Component
        Logical profile component name.
    .PARAMETER Level
        Log severity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Component = 'General',
        [ValidateSet('DEBUG', 'INFO', 'SUCCESS', 'WARN', 'ERROR', 'CRITICAL')]
        [string]$Level = 'WARN'
    )

    try {
        if (-not $ErrorRecord.Exception) {
            Write-ProfileLog "$Context | Unknown exception" -Level $Level -Component $Component
            return
        }

        $maxDepth = 3
        if ($Global:ProfileConfig -and $Global:ProfileConfig.ErrorHandling -and $Global:ProfileConfig.ErrorHandling.MaxInnerExceptionDepth) {
            $maxDepth = [int]$Global:ProfileConfig.ErrorHandling.MaxInnerExceptionDepth
        }

        $summary = Get-ExceptionSummary -Exception $ErrorRecord.Exception -MaxDepth $maxDepth
        $message = "$Context | $summary"

        if (
            $Global:ProfileConfig -and
            $Global:ProfileConfig.ErrorHandling -and
            $Global:ProfileConfig.ErrorHandling.IncludeScriptStack -and
            $ErrorRecord.ScriptStackTrace
        ) {
            $message += " | Stack: $($ErrorRecord.ScriptStackTrace)"
        }

        $shouldLog = $true
        if (
            $Global:ProfileConfig -and
            $Global:ProfileConfig.ErrorHandling -and
            $null -ne $Global:ProfileConfig.ErrorHandling.LogCaughtExceptions
        ) {
            $shouldLog = [bool]$Global:ProfileConfig.ErrorHandling.LogCaughtExceptions
        }

        if ($shouldLog) {
            Write-ProfileLog $message -Level $Level -Component $Component
        }
    } catch {
        Write-ProfileLog "$Context | exception logging failed: $($_.Exception.Message)" -Level DEBUG -Component $Component
    }
}

# Initialize logging
Write-ProfileLog "PowerShell profile v$script:ProfileVersion loading..." -Level INFO -Component "Bootstrap"

#endregion LOGGING AND TELEMETRY FRAMEWORK
