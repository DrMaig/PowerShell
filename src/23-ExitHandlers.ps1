<#
.SYNOPSIS
    Profile component 23 - Exit Handlers And Cleanup
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 23 (EXIT HANDLERS AND CLEANUP) for modular dot-sourced loading.
#>

#region 23 - EXIT HANDLERS AND CLEANUP
#==============================================================================
<#
.SYNOPSIS
    Exit handlers and cleanup
.DESCRIPTION
    Registers cleanup actions for profile exit.
#>

# Register exit action
function Register-ExitAction {
    <#
    .SYNOPSIS
        Registers an action to run on profile exit.
    .DESCRIPTION
        Adds a script block to be executed when PowerShell exits.
    .PARAMETER Action
        Script block to execute.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock]$Action)

    $global:OnExitActions += $Action
}

# --- FIX: Remove unsupported OnRemove handler and use Register-EngineEvent for exit ---
$existingSub = Get-EventSubscriber -ErrorAction Ignore |
    Where-Object { $_.SourceIdentifier -eq 'PowerShell.Exiting' } |
    Select-Object -First 1
if (-not $existingSub) {
    Register-EngineEvent PowerShell.Exiting -Action {
        foreach ($action in $global:OnExitActions) {
            try {
                & $action
            } catch {
                Write-Verbose "Exit action failed: $($_.Exception.Message)"
            }
        }
    } | Out-Null
}

#endregion EXIT HANDLERS AND CLEANUP
