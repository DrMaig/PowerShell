<#
.SYNOPSIS
    Profile component 20 - Aliases And Shortcuts
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 20 (ALIASES AND SHORTCUTS) for modular dot-sourced loading.
#>

#region 20 - ALIASES AND SHORTCUTS
#==============================================================================
<#
.SYNOPSIS
    Aliases and command shortcuts
.DESCRIPTION
    Provides convenient aliases and shortcuts for common commands.
#>

# Navigation functions (aliases with arguments don't work)
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function ~ { Set-Location ~ }

# Utility aliases
Set-Alias -Name grep -Value Select-String -Option AllScope -ErrorAction Ignore
Set-Alias -Name which -Value Get-Command -Option AllScope -ErrorAction Ignore
function touch { param([Parameter(Mandatory)][string]$Path) if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType File | Out-Null } else { (Get-Item $Path).LastWriteTime = Get-Date } }

# Editor alias — only map nano→notepad on Windows (avoid shadowing real nano on Unix)
if ($IsWindows) {
    Set-Alias -Name nano -Value notepad -Option AllScope -ErrorAction Ignore
}

# Listing aliases — differentiate behavior to match Unix conventions
# ll = long listing (default), la = include hidden/force, l = compact
Set-Alias -Name ll -Value Get-ChildItem -Option AllScope -ErrorAction Ignore
function la { Get-ChildItem -Force @args }
Set-Alias -Name l -Value Get-ChildItem -Option AllScope -ErrorAction Ignore

# Function aliases for complex operations
function cd.. { Set-Location .. }
function cd... { Set-Location ../.. }
function cd.... { Set-Location ../../.. }
function cd..... { Set-Location ../../../.. }

# Quick system info
function sysinfo { Get-SystemInfo | Format-List }
function meminfo { Get-MemoryInfo | Format-List }
function cpuinfo { Get-CPUInfo | Format-List }
function diskinfo { Get-DiskInfo | Format-Table -AutoSize }
function gpuinfo { Get-GPUInfo | Format-Table -AutoSize }
function biosinfo { Get-BIOSInfo | Format-List }

# Quick network info
function netinfo { Get-NetworkSnapshot | Format-List }
function ipinfo { Get-LocalIP }
function pubip { Get-PublicIP }
function flushdns { Clear-DnsCache }

# Quick process info
function top { Get-TopProcesses | Format-Table -AutoSize }
function topcpu { Get-TopProcesses -By CPU | Format-Table -AutoSize }
function topio { Get-TopProcesses -By IO | Format-Table -AutoSize }

# Quick service info
function svc { Get-ServiceHealth | Format-Table -AutoSize }

# Quick health check
function health { Get-SystemHealth | Format-List }

# Quick diagnostics
function diag { Show-ProfileDiagnostics }
function repair { Repair-Profile }

# Quick optimization
function optimize { Optimize-System }

# Quick benchmark
function benchmark { param([scriptblock]$sb) Measure-Benchmark -ScriptBlock $sb }

# Quick file operations
function du { param([string]$p = $PWD, [int]$t = 20) Get-DiskUsage -Path $p -Top $t }
function largefiles { param([string]$p = $PWD, [int]$s = 100, [int]$t = 20) Find-LargeFiles -Path $p -SizeMB $s -Top $t }

# Quick editor
function edit { param([string]$f) & $Global:ProfileConfig.Editor $f }
function code. { code . }

# Quick admin — only define sudo wrapper on Windows (avoid shadowing real sudo on Unix)
if ($IsWindows) {
    function sudo { Start-Process pwsh -Verb runAs }
}

# Quick module management
function mods { Get-InstalledModulesCache | Format-List }
function updatemods { Update-ProfileModules }

# Backward-compat alias for Ensure-Module (non-standard verb)
Set-Alias -Name Ensure-Module -Value Assert-ModuleAvailable -ErrorAction Ignore

# Quick help
function helpme {
    Write-Host "`n=== Profile Quick Reference ===" -ForegroundColor Cyan
    Write-Host "System: sysinfo, meminfo, cpuinfo, diskinfo, gpuinfo, biosinfo, health" -ForegroundColor Yellow
    Write-Host "Network: netinfo, ipinfo, pubip, flushdns" -ForegroundColor Yellow
    Write-Host "Processes: top, topcpu, topio" -ForegroundColor Yellow
    Write-Host "DNS: Use-CloudflareDns, Use-GoogleDns, Use-BestDns" -ForegroundColor Yellow
    Write-Host "Optimization: optimize, Set-PowerPlan, Invoke-DiskMaintenance" -ForegroundColor Yellow
    Write-Host "Diagnostics: diag, repair, Test-ProfileHealth" -ForegroundColor Yellow
    Write-Host "Updates: updatemods, Update-HelpProfile" -ForegroundColor Yellow
    Write-Host "Files: du, largefiles, Clear-TempFiles" -ForegroundColor Yellow
    Write-Host "Package Managers: pmstatus, updateall, Install-DevPackage" -ForegroundColor Yellow
    Write-Host "  Winget: wgs, wgi, wgu, wgun" -ForegroundColor DarkGray
    Write-Host "  Choco: chs, chi, chu, chun" -ForegroundColor DarkGray
    Write-Host "  NPM: npi, npu, npug" -ForegroundColor DarkGray
    Write-Host "  Pip: pipl, pipi, pipu" -ForegroundColor DarkGray
    Write-Host ""
}

function Enable-CommandPredictorSupport {
    [CmdletBinding()]
    param([switch]$Install)

    $candidateModules = @('CompletionPredictor', 'Az.Tools.Predictor')
    $available = @()

    foreach ($moduleName in $candidateModules) {
        if (Get-Module -ListAvailable -Name $moduleName -ErrorAction Ignore) {
            $available += $moduleName
            continue
        }

        if ($Install) {
            Write-Host "Installing predictor module: $moduleName" -ForegroundColor Yellow
            Install-Module -Name $moduleName -Scope CurrentUser -AllowClobber -Force
            $available += $moduleName
        }
    }

    if ($available.Count -eq 0) {
        Write-Host "No predictor modules available. Run: Enable-CommandPredictorSupport -Install" -ForegroundColor Yellow
        return
    }

    foreach ($moduleName in $available) {
        Import-Module $moduleName -ErrorAction Ignore | Out-Null
    }

    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Ignore
    Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Ignore
    Write-Host "Predictor support enabled: $($available -join ', ')" -ForegroundColor Green
}

# Package manager quick aliases
function wgs { param([string]$q) Get-WingetPackage -Query $q }
function wgi { param([string]$p) Install-WingetPackage -Package $p }
function wgu { param([string]$p = 'all') Update-WingetPackage -Package $p }
function wgun { param([string]$p) Uninstall-WingetPackage -Package $p }
function chs { param([string]$q) Get-ChocoPackage -Query $q }
function chi { param([string]$p) Install-ChocoPackage -Package $p }
function chu { param([string]$p = 'all') Update-ChocoPackage -Package $p }
function chun { param([string]$p) Uninstall-ChocoPackage -Package $p }
function npi { param([string]$p, [switch]$g) Install-NpmPackage -Package $p -Global:$g }
function npu { param([string]$p = 'all') Update-NpmPackage -Package $p }
function npug { Update-NpmPackage -Package 'all' -Global }
function pipl { Get-PipPackage }
function pipi { param([string]$p, [switch]$u) Install-PipPackage -Package $p -Upgrade:$u }
function pipu { param([string]$p = 'all') Update-PipPackage -Package $p }
function pmstatus { Get-PackageManagerStatus | Format-Table }
function updateall { Update-AllPackages -Manager 'all' }

#endregion ALIASES AND SHORTCUTS
