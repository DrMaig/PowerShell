<#
.SYNOPSIS
    Profile component 21 - Native Tool Completers And Shims
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 21 (NATIVE TOOL COMPLETERS AND SHIMS) for modular dot-sourced loading.
#>

#region 21 - NATIVE TOOL COMPLETERS AND SHIMS
#==============================================================================
<#
.SYNOPSIS
    Dynamic native tool completers from installed tools.
.DESCRIPTION
    Tools like git, kubectl, docker, and aws generate their own PowerShell
    completers. These are far superior to static arrays because they provide:
    - Real-time context awareness (git branches, running containers, resources)
    - Automatic updates as tools are upgraded
    - Argument filtering and validation
    - Full shell integration for the tool's native UX
    
    This region loads native completers on-demand to avoid startup overhead.
#>

function Initialize-NativeToolCompleters {
    [CmdletBinding()]
    param()

    $profileRootVar = Get-Variable -Scope Script -Name ProfileRoot -ErrorAction Ignore
    $profileRoot = if ($profileRootVar -and $profileRootVar.Value) { $profileRootVar.Value } else { Split-Path -Parent $PSScriptRoot }
    $nativeCompleterScriptPath = Join-Path $profileRoot 'Scripts\Initialize-NativeToolCompleters.ps1'
    if (-not (Test-Path -LiteralPath $nativeCompleterScriptPath)) {
        Write-ProfileLog "Native completer script not found at '$nativeCompleterScriptPath'" -Level WARN -Component "Completions"
        return $false
    }

    try {
        . $nativeCompleterScriptPath
        return $true
    } catch {
        Write-CaughtException -Context "Initialize-NativeToolCompleters" -ErrorRecord $_ -Component "Completions" -Level WARN
        return $false
    }
}

if ((Test-ProfileInteractive) -and $Global:ProfileConfig.Features.UseCompletions) {
    Initialize-NativeToolCompleters | Out-Null
} else {
    Write-ProfileLog "Native tool completers skipped (non-interactive or disabled)" -Level DEBUG -Component "Completions"
}

#endregion NATIVE TOOL COMPLETERS AND SHIMS
