<#
.SYNOPSIS
    Profile component 11 - Windows Optimization and Maintenance.
.DESCRIPTION
    Safe, auditable, and reversible optimization helpers for Windows 10 Pro.
    This component avoids destructive defaults and uses explicit plan/apply/undo flows.

    Compatibility:
    - Windows 10 Pro (latest released build)
    - Windows PowerShell 5.1 and PowerShell 7+

    Usage examples:
    - Get-WinOptimizationPlan
    - Invoke-WinOptimization -DryRun -PowerPlan HighPerformance -TuneExplorerStartupDelay -AnalyzeVolume
    - Invoke-WinOptimization -Apply -PowerPlan HighPerformance -TuneExplorerStartupDelay -OptimizeVolume -VolumeMode Retrim -DriveLetter C -Confirm
    - Undo-WinOptimization -Last -Confirm
#>

#region 11 - WINDOWS OPTIMIZATION AND MAINTENANCE
#==============================================================================

function Test-WinHostIsWindows {
    [CmdletBinding()]
    param()

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        return $true
    }

    if ($null -ne (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue)) {
        return [bool]$IsWindows
    }

    return ($env:OS -eq 'Windows_NT')
}

function Test-WinOptimizationAdministrator {
    [CmdletBinding()]
    param()

    if (-not (Test-WinHostIsWindows)) {
        return $false
    }

    if (Get-Command Test-Admin -ErrorAction Ignore) {
        try {
            return [bool](Test-Admin)
        } catch {
            return $false
        }
    }

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function New-WinOptimizationContext {
    [CmdletBinding()]
    param(
        [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\Logs\win-optimization.log.jsonl'),
        [string]$StatePath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\State\win-optimization-state.json'),
        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $stateDir = Split-Path -Path $StatePath -Parent
    if ($stateDir -and -not (Test-Path -LiteralPath $stateDir)) {
        New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
    }

    [PSCustomObject]@{
        CorrelationId  = [guid]::NewGuid().Guid
        LogPath        = $LogPath
        StatePath      = $StatePath
        EnableEventLog = [bool]$EnableEventLog
        EventLogName   = $EventLogName
        EventSource    = $EventSource
    }
}

function Write-WinOptimizationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Info', 'Warn', 'Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [hashtable]$Data,
        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    $record = [ordered]@{
        TimestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Level         = $Level
        Action        = $Action
        Message       = $Message
        CorrelationId = $CorrelationId
        User          = $env:USERNAME
        Computer      = $env:COMPUTERNAME
        ProcessId     = $PID
        Data          = $Data
    }

    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Depth 8 -Compress) -Encoding UTF8

    if (Get-Command Write-ProfileLog -ErrorAction Ignore) {
        $mappedLevel = switch ($Level) {
            'Debug' { 'DEBUG' }
            'Info'  { 'INFO' }
            'Warn'  { 'WARN' }
            'Error' { 'ERROR' }
        }
        Write-ProfileLog "$Action - $Message (CID: $CorrelationId)" -Level $mappedLevel -Component 'Optimization'
    }

    if ($EnableEventLog -and (Test-WinHostIsWindows) -and (Get-Command Write-EventLog -ErrorAction Ignore)) {
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
                if (Test-WinOptimizationAdministrator) {
                    New-EventLog -LogName $EventLogName -Source $EventSource -ErrorAction Stop
                }
            }

            if ([System.Diagnostics.EventLog]::SourceExists($EventSource)) {
                $entryType = switch ($Level) {
                    'Debug' { 'Information' }
                    'Info'  { 'Information' }
                    'Warn'  { 'Warning' }
                    'Error' { 'Error' }
                }

                Write-EventLog -LogName $EventLogName -Source $EventSource -EntryType $entryType -EventId 5001 -Message "$Action - $Message (CID: $CorrelationId)"
            }
        } catch {
            if (Get-Command Write-CaughtException -ErrorAction Ignore) {
                Write-CaughtException -Context 'Write-WinOptimizationLog EventLog write failed' -ErrorRecord $_ -Component 'Optimization' -Level DEBUG
            }
        }
    }

    return [PSCustomObject]$record
}

function Get-WinOptimizationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StatePath
    )

    if (-not (Test-Path -LiteralPath $StatePath)) {
        return [ordered]@{
            Version     = 1
            LastUpdated = $null
            History     = @()
        }
    }

    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -Depth 20
        return [ordered]@{
            Version     = [int]($obj.Version)
            LastUpdated = [string]($obj.LastUpdated)
            History     = @($obj.History)
        }
    } catch {
        return [ordered]@{
            Version     = 1
            LastUpdated = $null
            History     = @()
        }
    }
}

function Save-WinOptimizationStateChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StatePath,

        [Parameter(Mandatory)]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$ChangeType,

        [Parameter(Mandatory)]
        [object]$Before,

        [Parameter(Mandatory)]
        [object]$After
    )

    $state = Get-WinOptimizationState -StatePath $StatePath
    $history = @($state.History)

    $history += [ordered]@{
        TimestampUtc  = (Get-Date).ToUniversalTime().ToString('o')
        CorrelationId = $CorrelationId
        ChangeType    = $ChangeType
        Before        = $Before
        After         = $After
    }

    $toWrite = [ordered]@{
        Version     = 1
        LastUpdated = (Get-Date).ToUniversalTime().ToString('o')
        History     = $history
    }

    $toWrite | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-WinPowerPlan {
    <#
    .SYNOPSIS
        Gets the active Windows power plan.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-WinHostIsWindows)) {
        return $null
    }

    try {
        $activePlan = powercfg /getactivescheme 2>$null
        if ($activePlan -match 'GUID:\s+([a-f0-9-]+)\s+\((.+)\)') {
            return [PSCustomObject]@{
                ActivePlan = $Matches[2]
                Guid       = $Matches[1]
            }
        }
    } catch {
        return $null
    }

    return $null
}

function Resolve-WinPowerPlanGuid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Balanced', 'HighPerformance', 'PowerSaver')]
        [string]$Plan
    )

    switch ($Plan) {
        'Balanced'        { return '381b4222-f694-41f0-9685-ff5bb260df2e' }
        'HighPerformance' { return '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
        'PowerSaver'      { return 'a1841308-3541-4fab-bc81-f71556f20b4a' }
    }
}

function Set-WinPowerPlan {
    <#
    .SYNOPSIS
        Safely sets the active power plan.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Balanced', 'HighPerformance', 'PowerSaver')]
        [string]$Plan,

        [Parameter(Mandatory)]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$StatePath,

        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    if (-not (Test-WinHostIsWindows)) {
        return [PSCustomObject]@{ Action = 'SetPowerPlan'; Changed = $false; Skipped = $true; Reason = 'Windows only' }
    }

    $before = Get-WinPowerPlan
    if (-not $before) {
        throw 'Unable to determine the active power plan.'
    }

    $targetGuid = Resolve-WinPowerPlanGuid -Plan $Plan
    if ($before.Guid -eq $targetGuid) {
        Write-WinOptimizationLog -Level Info -Action 'SetPowerPlan' -Message "Power plan already set to $Plan" -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        return [PSCustomObject]@{ Action = 'SetPowerPlan'; Changed = $false; Idempotent = $true; Before = $before; After = $before; CorrelationId = $CorrelationId }
    }

    if (-not $PSCmdlet.ShouldProcess("Power plan [$Plan]", 'Set active plan')) {
        return [PSCustomObject]@{ Action = 'SetPowerPlan'; Changed = $false; Skipped = $true; Reason = 'WhatIf or confirmation declined'; CorrelationId = $CorrelationId }
    }

    try {
        powercfg /setactive $targetGuid | Out-Null
        $after = Get-WinPowerPlan

        Save-WinOptimizationStateChange -StatePath $StatePath -CorrelationId $CorrelationId -ChangeType 'PowerPlan' -Before $before -After $after
        Write-WinOptimizationLog -Level Info -Action 'SetPowerPlan' -Message "Power plan changed from $($before.ActivePlan) to $($after.ActivePlan)" -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource -Data @{ Before = $before; After = $after } | Out-Null

        return [PSCustomObject]@{ Action = 'SetPowerPlan'; Changed = $true; Idempotent = $false; Before = $before; After = $after; CorrelationId = $CorrelationId }
    } catch {
        Write-WinOptimizationLog -Level Error -Action 'SetPowerPlan' -Message $_.Exception.Message -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        throw
    }
}

function Set-WinExplorerStartupDelay {
    <#
    .SYNOPSIS
        Controls Explorer startup delay setting for current user.
    .DESCRIPTION
        Uses HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize\StartupDelayInMSec.
        This is reversible via Undo-WinOptimization.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Disabled', 'Default')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [string]$StatePath,

        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    if (-not (Test-WinHostIsWindows)) {
        return [PSCustomObject]@{ Action = 'SetExplorerStartupDelay'; Changed = $false; Skipped = $true; Reason = 'Windows only' }
    }

    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
    $name = 'StartupDelayInMSec'

    $exists = $false
    $value = $null
    if (Test-Path -LiteralPath $path) {
        $props = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
        if ($null -ne $props -and $null -ne $props.$name) {
            $exists = $true
            $value = [int]$props.$name
        }
    }

    $before = [PSCustomObject]@{ Path = $path; Name = $name; Exists = $exists; Value = $value }
    $alreadySet = ($Mode -eq 'Disabled' -and $exists -and $value -eq 0) -or ($Mode -eq 'Default' -and -not $exists)

    if ($alreadySet) {
        Write-WinOptimizationLog -Level Info -Action 'SetExplorerStartupDelay' -Message "Explorer startup delay already in mode $Mode" -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        return [PSCustomObject]@{ Action = 'SetExplorerStartupDelay'; Changed = $false; Idempotent = $true; Before = $before; After = $before; RestartExplorerRecommended = $false; CorrelationId = $CorrelationId }
    }

    if (-not $PSCmdlet.ShouldProcess("$path [$name]", "Set mode $Mode")) {
        return [PSCustomObject]@{ Action = 'SetExplorerStartupDelay'; Changed = $false; Skipped = $true; Reason = 'WhatIf or confirmation declined'; CorrelationId = $CorrelationId }
    }

    try {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        if ($Mode -eq 'Disabled') {
            New-ItemProperty -LiteralPath $path -Name $name -PropertyType DWord -Value 0 -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
        }

        $afterExists = $false
        $afterValue = $null
        if (Test-Path -LiteralPath $path) {
            $afterProps = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
            if ($null -ne $afterProps -and $null -ne $afterProps.$name) {
                $afterExists = $true
                $afterValue = [int]$afterProps.$name
            }
        }

        $after = [PSCustomObject]@{ Path = $path; Name = $name; Exists = $afterExists; Value = $afterValue }
        Save-WinOptimizationStateChange -StatePath $StatePath -CorrelationId $CorrelationId -ChangeType 'ExplorerStartupDelay' -Before $before -After $after

        Write-WinOptimizationLog -Level Info -Action 'SetExplorerStartupDelay' -Message "Explorer startup delay set to mode $Mode" -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource -Data @{ Before = $before; After = $after } | Out-Null

        return [PSCustomObject]@{ Action = 'SetExplorerStartupDelay'; Changed = $true; Idempotent = $false; Before = $before; After = $after; RestartExplorerRecommended = $true; CorrelationId = $CorrelationId }
    } catch {
        Write-WinOptimizationLog -Level Error -Action 'SetExplorerStartupDelay' -Message $_.Exception.Message -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        throw
    }
}

function Invoke-WinVolumeOptimization {
    <#
    .SYNOPSIS
        Performs explicit, auditable volume optimization.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [ValidatePattern('^[A-Za-z]$')]
        [string]$DriveLetter = 'C',

        [ValidateSet('Analyze', 'Retrim', 'Defrag')]
        [string]$Mode = 'Analyze',

        [Parameter(Mandatory)]
        [string]$CorrelationId,

        [Parameter(Mandatory)]
        [string]$LogPath,

        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    if (-not (Test-WinHostIsWindows)) {
        return [PSCustomObject]@{ Action = 'OptimizeVolume'; Changed = $false; Skipped = $true; Reason = 'Windows only' }
    }

    if (-not (Test-WinOptimizationAdministrator)) {
        $reason = 'Volume optimization requires Administrator privileges. Re-run elevated to apply.'
        Write-WinOptimizationLog -Level Warn -Action 'OptimizeVolume' -Message $reason -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        return [PSCustomObject]@{ Action = 'OptimizeVolume'; Changed = $false; Skipped = $true; Reason = $reason; Drive = $DriveLetter; Mode = $Mode }
    }

    if (-not $PSCmdlet.ShouldProcess("Drive $DriveLetter", "Optimize volume in mode $Mode")) {
        return [PSCustomObject]@{ Action = 'OptimizeVolume'; Changed = $false; Skipped = $true; Reason = 'WhatIf or confirmation declined'; Drive = $DriveLetter; Mode = $Mode }
    }

    try {
        $result = $null
        if (Get-Command Optimize-Volume -ErrorAction Ignore) {
            switch ($Mode) {
                'Analyze' { $result = Optimize-Volume -DriveLetter $DriveLetter -Analyze -ErrorAction Stop }
                'Retrim'  { $result = Optimize-Volume -DriveLetter $DriveLetter -ReTrim -ErrorAction Stop }
                'Defrag'  { $result = Optimize-Volume -DriveLetter $DriveLetter -Defrag -ErrorAction Stop }
            }
        } elseif (Get-Command defrag.exe -ErrorAction Ignore) {
            $defragArgs = switch ($Mode) {
                'Analyze' { "$DriveLetter`: /A /U /V" }
                'Retrim'  { "$DriveLetter`: /L /U /V" }
                'Defrag'  { "$DriveLetter`: /U /V /O" }
            }
            $proc = Start-Process -FilePath 'defrag.exe' -ArgumentList $defragArgs -Wait -NoNewWindow -PassThru -ErrorAction Stop
            $result = [PSCustomObject]@{ ExitCode = $proc.ExitCode }
        } else {
            throw 'Neither Optimize-Volume nor defrag.exe is available.'
        }

        Write-WinOptimizationLog -Level Info -Action 'OptimizeVolume' -Message "Volume optimization completed for $DriveLetter in mode $Mode" -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        return [PSCustomObject]@{ Action = 'OptimizeVolume'; Changed = $true; Skipped = $false; Drive = $DriveLetter; Mode = $Mode; Result = $result; CorrelationId = $CorrelationId }
    } catch {
        Write-WinOptimizationLog -Level Error -Action 'OptimizeVolume' -Message $_.Exception.Message -CorrelationId $CorrelationId -LogPath $LogPath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource | Out-Null
        throw
    }
}

function Get-WinOptimizationPlan {
    <#
    .SYNOPSIS
        Returns a safe optimization plan with measurable targets.
    #>
    [CmdletBinding()]
    param()

    @(
        [PSCustomObject]@{
            Name          = 'PowerPlan'
            Description   = 'Set active power plan for responsiveness and workload profile.'
            RequiresAdmin = $false
            Reversible    = $true
            Metric        = 'CPU responsiveness and workload duration'
        }
        [PSCustomObject]@{
            Name          = 'ExplorerStartupDelay'
            Description   = 'Disable Explorer startup delay for current user startup responsiveness.'
            RequiresAdmin = $false
            Reversible    = $true
            Metric        = 'Perceived startup responsiveness'
        }
        [PSCustomObject]@{
            Name          = 'VolumeOptimization'
            Description   = 'Analyze/retrim/defrag selected volume using built-in tools.'
            RequiresAdmin = $true
            Reversible    = 'N/A'
            Metric        = 'Disk I/O consistency and throughput'
        }
    )
}

function Invoke-WinOptimization {
    <#
    .SYNOPSIS
        Orchestrates safe Windows optimization tasks.
    .DESCRIPTION
        Uses plan, dry-run, and explicit apply modes. Returns structured output suitable for auditing.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Apply,
        [switch]$DryRun,

        [ValidateSet('NoChange', 'Balanced', 'HighPerformance', 'PowerSaver')]
        [string]$PowerPlan = 'NoChange',

        [switch]$TuneExplorerStartupDelay,
        [switch]$AnalyzeVolume,
        [switch]$OptimizeVolume,

        [ValidatePattern('^[A-Za-z]$')]
        [string]$DriveLetter = 'C',

        [ValidateSet('Analyze', 'Retrim', 'Defrag')]
        [string]$VolumeMode = 'Analyze',

        [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\Logs\win-optimization.log.jsonl'),
        [string]$StatePath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\State\win-optimization-state.json'),
        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    if (-not (Test-WinHostIsWindows)) {
        throw 'Invoke-WinOptimization is supported only on Windows.'
    }

    if ($Apply -and $DryRun) {
        throw 'Specify either -Apply or -DryRun, not both.'
    }

    $context = New-WinOptimizationContext -LogPath $LogPath -StatePath $StatePath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource
    $mode = if ($DryRun) { 'DryRun' } elseif ($Apply) { 'Apply' } else { 'Plan' }

    Write-WinOptimizationLog -Level Info -Action 'InvokeWinOptimization' -Message "Started mode $mode" -CorrelationId $context.CorrelationId -LogPath $context.LogPath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource | Out-Null

    if (-not $Apply -and -not $DryRun) {
        return [PSCustomObject]@{
            Mode          = 'Plan'
            CorrelationId = $context.CorrelationId
            Plan          = Get-WinOptimizationPlan
            Notes         = @(
                'Use -DryRun to preview actions without applying changes.',
                'Use -Apply for explicit execution with confirmation support.'
            )
        }
    }

    $results = @()

    if ($PowerPlan -ne 'NoChange') {
        $results += Set-WinPowerPlan -Plan $PowerPlan -CorrelationId $context.CorrelationId -LogPath $context.LogPath -StatePath $context.StatePath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource -WhatIf:$DryRun
    }

    if ($TuneExplorerStartupDelay) {
        $results += Set-WinExplorerStartupDelay -Mode 'Disabled' -CorrelationId $context.CorrelationId -LogPath $context.LogPath -StatePath $context.StatePath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource -WhatIf:$DryRun
    }

    if ($AnalyzeVolume -or $OptimizeVolume) {
        $selectedMode = if ($AnalyzeVolume) { 'Analyze' } else { $VolumeMode }
        $results += Invoke-WinVolumeOptimization -DriveLetter $DriveLetter -Mode $selectedMode -CorrelationId $context.CorrelationId -LogPath $context.LogPath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource -WhatIf:$DryRun
    }

    $changedCount = @($results | Where-Object { $_.Changed }).Count
    $skippedCount = @($results | Where-Object { $_.Skipped }).Count

    Write-WinOptimizationLog -Level Info -Action 'InvokeWinOptimization' -Message "Completed mode $mode. Changed=$changedCount Skipped=$skippedCount" -CorrelationId $context.CorrelationId -LogPath $context.LogPath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource | Out-Null

    return [PSCustomObject]@{
        Mode          = $mode
        CorrelationId = $context.CorrelationId
        ChangedCount  = $changedCount
        SkippedCount  = $skippedCount
        Results       = $results
        LogPath       = $context.LogPath
        StatePath     = $context.StatePath
    }
}

function Undo-WinOptimization {
    <#
    .SYNOPSIS
        Rolls back recorded state changes from a previous optimization run.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [switch]$Last,
        [string]$CorrelationId,
        [string]$StatePath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\State\win-optimization-state.json'),
        [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'PowerShellProfile\Logs\win-optimization.log.jsonl'),
        [switch]$EnableEventLog,
        [string]$EventLogName = 'Application',
        [string]$EventSource = 'PowerShellProfile.WinOptimization'
    )

    if (-not (Test-WinHostIsWindows)) {
        throw 'Undo-WinOptimization is supported only on Windows.'
    }

    if (-not $Last -and -not $CorrelationId) {
        throw 'Specify -Last or -CorrelationId.'
    }

    $context = New-WinOptimizationContext -LogPath $LogPath -StatePath $StatePath -EnableEventLog:$EnableEventLog -EventLogName $EventLogName -EventSource $EventSource
    $state = Get-WinOptimizationState -StatePath $context.StatePath
    $history = @($state.History)

    if ($history.Count -eq 0) {
        return [PSCustomObject]@{ Action = 'Undo'; Changed = $false; Reason = 'No rollback history found.'; CorrelationId = $context.CorrelationId }
    }

    $target = if ($Last) { [string]$history[-1].CorrelationId } else { $CorrelationId }
    $entries = @($history | Where-Object { $_.CorrelationId -eq $target })
    if ($entries.Count -eq 0) {
        throw "No rollback entries found for correlation ID '$target'."
    }

    $results = @()
    foreach ($entry in ($entries | Sort-Object TimestampUtc -Descending)) {
        switch ($entry.ChangeType) {
            'PowerPlan' {
                if ($PSCmdlet.ShouldProcess("Power plan [$($entry.Before.ActivePlan)]", 'Restore previous power plan')) {
                    powercfg /setactive $entry.Before.Guid | Out-Null
                    $results += [PSCustomObject]@{ ChangeType = 'PowerPlan'; Changed = $true; RestoredTo = $entry.Before }
                }
            }
            'ExplorerStartupDelay' {
                $path = [string]$entry.Before.Path
                $name = [string]$entry.Before.Name
                $exists = [bool]$entry.Before.Exists

                if ($PSCmdlet.ShouldProcess("$path [$name]", 'Restore previous registry state')) {
                    if ($exists) {
                        if (-not (Test-Path -LiteralPath $path)) {
                            New-Item -Path $path -Force | Out-Null
                        }
                        New-ItemProperty -LiteralPath $path -Name $name -PropertyType DWord -Value ([int]$entry.Before.Value) -Force | Out-Null
                    } else {
                        if (Test-Path -LiteralPath $path) {
                            Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
                        }
                    }
                    $results += [PSCustomObject]@{ ChangeType = 'ExplorerStartupDelay'; Changed = $true; RestoredTo = $entry.Before }
                }
            }
            default {
                $results += [PSCustomObject]@{ ChangeType = [string]$entry.ChangeType; Changed = $false; Reason = 'Unknown change type; skipped.' }
            }
        }
    }

    Write-WinOptimizationLog -Level Info -Action 'UndoWinOptimization' -Message "Rollback completed for target correlation ID $target" -CorrelationId $context.CorrelationId -LogPath $context.LogPath -EnableEventLog:$context.EnableEventLog -EventLogName $context.EventLogName -EventSource $context.EventSource -Data @{ TargetCorrelationId = $target; Restored = $results.Count } | Out-Null

    return [PSCustomObject]@{
        Action              = 'Undo'
        TargetCorrelationId = $target
        ChangedCount        = @($results | Where-Object { $_.Changed }).Count
        Results             = $results
        CorrelationId       = $context.CorrelationId
    }
}

# Backward-compatible wrappers

function Optimize-System {
    <#
    .SYNOPSIS
        Deprecated compatibility wrapper.
    #>
    [CmdletBinding()]
    param(
        [switch]$Apply,
        [switch]$DryRun
    )

    Write-Warning 'Optimize-System is deprecated. Use Invoke-WinOptimization.'
    Invoke-WinOptimization -Apply:$Apply -DryRun:$DryRun -AnalyzeVolume
}

function Invoke-DiskMaintenance {
    <#
    .SYNOPSIS
        Deprecated compatibility wrapper.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [ValidatePattern('^[A-Za-z]:?$')]
        [string]$DriveLetter = 'C',
        [switch]$AnalyzeOnly
    )

    Write-Warning 'Invoke-DiskMaintenance is deprecated. Use Invoke-WinVolumeOptimization or Invoke-WinOptimization.'

    $ctx = New-WinOptimizationContext
    $mode = if ($AnalyzeOnly) { 'Analyze' } else { 'Defrag' }

    Invoke-WinVolumeOptimization -DriveLetter ($DriveLetter.TrimEnd(':')) -Mode $mode -CorrelationId $ctx.CorrelationId -LogPath $ctx.LogPath -WhatIf:$WhatIfPreference
}

function Set-PowerPlan {
    <#
    .SYNOPSIS
        Deprecated compatibility wrapper.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Balanced', 'HighPerformance', 'PowerSaver')]
        [string]$Plan
    )

    Write-Warning 'Set-PowerPlan is deprecated. Use Set-WinPowerPlan.'

    $ctx = New-WinOptimizationContext
    Set-WinPowerPlan -Plan $Plan -CorrelationId $ctx.CorrelationId -LogPath $ctx.LogPath -StatePath $ctx.StatePath -WhatIf:$WhatIfPreference
}

function Get-PowerPlan {
    <#
    .SYNOPSIS
        Deprecated compatibility wrapper.
    #>
    [CmdletBinding()]
    param()

    Get-WinPowerPlan
}

#endregion WINDOWS OPTIMIZATION AND MAINTENANCE
