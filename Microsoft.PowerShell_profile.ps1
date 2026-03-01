#requires -Version 7.5
#==============================================================================
# ⚡ PowerShell Pro Profile - Thin Orchestrator
#==============================================================================
# .SYNOPSIS
#    Thin orchestrator that dot-sources modular profile components from src/.
# .NOTES
#    Author: PowerShell Profile Builder
#    Version: 3.0.0
#    PowerShell: 7.5+
#    OS: Windows/Linux/macOS
#    Last Modified: 2026-03-01
#==============================================================================

if ($env:TERM_PROGRAM -eq "vscode") {
    try {
        $vscodeShellIntegration = $null
        if ($env:VSCODE_SHELL_INTEGRATION -and (Test-Path -LiteralPath $env:VSCODE_SHELL_INTEGRATION)) {
            $vscodeShellIntegration = $env:VSCODE_SHELL_INTEGRATION
        } elseif (Get-Command code -ErrorAction Ignore) {
            $vscodeShellIntegration = & code --locate-shell-integration-path pwsh 2>$null
            if (-not $vscodeShellIntegration) {
                $vscodeShellIntegration = & code --locate-shell-integration-path powershell 2>$null
            }
        }

        if ($vscodeShellIntegration -and (Test-Path -LiteralPath $vscodeShellIntegration)) {
            . $vscodeShellIntegration
        }
    } catch {
        Write-Verbose "VS Code shell integration unavailable: $($_.Exception.Message)"
    }
}

$Global:ProfileLoadStart = Get-Date
$script:ProfileRoot = $PSScriptRoot
$script:SrcPath = Join-Path $script:ProfileRoot 'src'
$Global:ProfileStats = [ordered]@{
    ModulesLoaded = 0
    ComponentLoadTimes = [ordered]@{}
}

$script:ComponentOrder = @(
    '01-Bootstrap','02-Config','03-Logging','04-Environment','05-PSReadLine','06-ModuleManagement',
    '07-SystemAdmin','08-Performance','09-Network','10-DnsProfiles','11-WinOptimization','12-Diagnostics',
    '13-ProcessService','14-DriverSoftware','15-Updates','16-FileUtils','17-Prompt','18-PackageManagers',
    '19-Completions','20-Aliases','21-NativeCompleters','22-Welcome','23-ExitHandlers','24-HardwareDiag',
    '25-NetToolkit','26-EventLog','27-Remoting','28-Monitoring','29-Productivity','30-Snapshot',
    '31-Linting','32-CodeSigning'
)

foreach ($component in $script:ComponentOrder) {
    $componentPath = Join-Path $script:SrcPath "$component.ps1"
    if (-not (Test-Path -LiteralPath $componentPath)) {
        Write-Warning "Profile component missing: $componentPath"
        continue
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        . $componentPath
        $sw.Stop()
        $Global:ProfileStats.ComponentLoadTimes[$component] = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)

        if (Get-Command Write-ProfileLog -ErrorAction Ignore) {
            Write-ProfileLog "Loaded component '$component' in $($Global:ProfileStats.ComponentLoadTimes[$component]) ms" -Level DEBUG -Component 'Orchestrator'
        }
    } catch {
        $sw.Stop()
        $Global:ProfileStats.ComponentLoadTimes[$component] = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        if (Get-Command Write-CaughtException -ErrorAction Ignore) {
            Write-CaughtException -Context "Component '$component' load failure" -ErrorRecord $_
        } else {
            Write-Warning "Component '$component' failed: $($_.Exception.Message)"
        }
    }
}
