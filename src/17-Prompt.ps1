<#
.SYNOPSIS
    Profile component 17 - Prompt Customization And Shell Enhancements
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 17 (PROMPT CUSTOMIZATION AND SHELL ENHANCEMENTS) for modular dot-sourced loading.
#>

#region 17 - PROMPT CUSTOMIZATION AND SHELL ENHANCEMENTS
#==============================================================================
<#
.SYNOPSIS
    Prompt customization and shell enhancements
.DESCRIPTION
    Provides custom prompt functions and shell enhancements including
    oh-my-posh integration and terminal icons.
#>

function Get-CustomPrompt {
    <#
    .SYNOPSIS
        Returns a custom prompt string.
    .DESCRIPTION
        Generates a custom prompt with git status, admin indicator, and path.
    #>
    [CmdletBinding()]
    param()

    try {
        $isAdmin = Test-Admin
        $path = (Get-Location).Path
        $shortPath = if ($path -eq $env:USERPROFILE) { '~' } else { Split-Path $path -Leaf }

        # Git status (if available)
        $gitBranch = $null
        if (Get-Command git -ErrorAction Ignore) {
            try {
                $gitBranch = git branch --show-current 2>$null
            } catch {
                Write-ProfileLog "Git branch detection failed: $($_.Exception.Message)" -Level DEBUG -Component "Prompt"
            }
        }

        # Build prompt
        $prompt = "`n"

        # Admin indicator
        if ($isAdmin) {
            $prompt += "[$([char]0x26A1)] "  # Lightning bolt
        }

        # Path
        $prompt += "$shortPath"

        # Git branch
        if ($gitBranch) {
            $prompt += " [$gitBranch]"
        }

        $prompt += "`nPS> "

        return $prompt
    } catch {
        return "PS> "
    }
}

function Resolve-OhMyPoshThemePath {
    [CmdletBinding()]
    param()

    $preferredTheme = Join-Path $Global:ProfileConfig.ThemesPath 'atomic.omp.json'
    if (Test-Path -LiteralPath $preferredTheme) {
        return $preferredTheme
    }

    $localTheme = Get-ChildItem -Path $Global:ProfileConfig.ThemesPath -Filter '*.omp.json' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($localTheme) {
        return $localTheme
    }

    if ($env:POSH_THEMES_PATH -and (Test-Path -LiteralPath $env:POSH_THEMES_PATH)) {
        $bundledTheme = Get-ChildItem -Path $env:POSH_THEMES_PATH -Filter '*.omp.json' -File -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($bundledTheme) {
            return $bundledTheme
        }
    }

    return $null
}

function Initialize-OhMyPosh {
    <#
    .SYNOPSIS
        Initializes oh-my-posh prompt.
    .DESCRIPTION
        Configures oh-my-posh with a local theme when available.
    #>
    [CmdletBinding()]
    param()

    $ompCommand = Get-Command 'oh-my-posh' -ErrorAction Ignore |
        Select-Object -First 1

    if (-not $ompCommand) {
        Write-ProfileLog "oh-my-posh not found; skipping oh-my-posh initialization" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        $themePath = Resolve-OhMyPoshThemePath
        $ompArgs = @('init', 'pwsh')
        if ($themePath) {
            $ompArgs += '--config'
            $ompArgs += $themePath
        } else {
            $themePath = '(default)'
        }

        $initScript = (& $ompCommand.Source @ompArgs) | Out-String

        if (-not [string]::IsNullOrWhiteSpace($initScript)) {
            $trimmedInit = $initScript.TrimStart()
            if ($trimmedInit -match '^(#!|export\s+)' -or $trimmedInit -match '^if\s+\[' -or $trimmedInit -match '^function\s+_omp_init\(\)') {
                Write-ProfileLog "oh-my-posh init returned non-PowerShell script; skipping prompt init" -Level WARN -Component "Prompt"
                return $false
            }

            $initPath = $null
            if ($trimmedInit -match "&\s*'([^']+init\.[^']+\.ps1)'") {
                $initPath = $matches[1]
            }

            if ($initPath -and (Test-Path -LiteralPath $initPath)) {
                . $initPath
            } else {
                & ([ScriptBlock]::Create($initScript))
            }

            Write-ProfileLog "oh-my-posh initialized with theme: $themePath" -Level DEBUG -Component "Prompt"
        } else {
            Write-ProfileLog "oh-my-posh init returned empty output" -Level WARN -Component "Prompt"
            return $false
        }

        return $true
    } catch {
        Write-CaughtException -Context "Initialize-OhMyPosh failed" -ErrorRecord $_ -Component "Prompt" -Level DEBUG
        return $false
    }
}

function Repair-TerminalIconsUserThemes {
    [CmdletBinding()]
    param()

    $storagePath = Join-Path $env:APPDATA 'powershell\Community\Terminal-Icons'
    if (-not (Test-Path -LiteralPath $storagePath)) {
        return $false
    }

    $hadRepair = $false
    $targets = Get-ChildItem -Path $storagePath -Filter '*.xml' -File -ErrorAction SilentlyContinue
    foreach ($target in $targets) {
        try {
            $null = [xml](Get-Content -LiteralPath $target.FullName -Raw -ErrorAction Stop)
        } catch {
            $backupName = "$($target.BaseName).corrupt.$(Get-Date -Format 'yyyyMMddHHmmss').bak"
            $backupPath = Join-Path $storagePath $backupName
            try {
                Move-Item -LiteralPath $target.FullName -Destination $backupPath -Force -ErrorAction Stop
                $hadRepair = $true
                Write-ProfileLog "Terminal-Icons user theme repaired: moved corrupt file '$($target.Name)' to '$backupName'" -Level WARN -Component "Prompt"
            } catch {
                Write-ProfileLog "Terminal-Icons repair failed for '$($target.Name)': $($_.Exception.Message)" -Level WARN -Component "Prompt"
            }
        }
    }

    return $hadRepair
}

function Initialize-TerminalIcons {
    <#
    .SYNOPSIS
        Initializes Terminal-Icons module.
    .DESCRIPTION
        Configures Terminal-Icons for enhanced file listings.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-ModuleAvailable -Name 'Terminal-Icons')) {
        Write-ProfileLog "Terminal-Icons not available" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        Import-Module Terminal-Icons -Force -ErrorAction Stop
        Write-ProfileLog "Terminal-Icons initialized" -Level DEBUG -Component "Prompt"
        return $true
    } catch {
        $firstError = $_.Exception.Message
        Write-ProfileLog "Terminal-Icons initialization failed (non-blocking): $firstError" -Level DEBUG -Component "Prompt"

        $repaired = Repair-TerminalIconsUserThemes
        if (-not $repaired) {
            return $false
        }

        try {
            Import-Module Terminal-Icons -Force -ErrorAction Stop
            Write-ProfileLog "Terminal-Icons initialized after user theme repair" -Level WARN -Component "Prompt"
            return $true
        } catch {
            Write-ProfileLog "Terminal-Icons re-initialization failed (non-blocking): $($_.Exception.Message)" -Level DEBUG -Component "Prompt"
            return $false
        }
    }
}

function Initialize-PoshGit {
    <#
    .SYNOPSIS
        Initializes posh-git module.
    .DESCRIPTION
        Configures posh-git for enhanced git prompt integration.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-ModuleAvailable -Name 'posh-git')) {
        Write-ProfileLog "posh-git not available" -Level DEBUG -Component "Prompt"
        return $false
    }

    try {
        Import-Module posh-git -Force -ErrorAction Stop
        $Global:GitPromptSettings.EnableFileStatus = $true
        Write-ProfileLog "posh-git initialized" -Level DEBUG -Component "Prompt"
        return $true
    } catch {
        Write-ProfileLog "posh-git initialization failed: $_" -Level DEBUG -Component "Prompt"
        return $false
    }
}

# Initialize prompt enhancements for interactive sessions
if (Test-ProfileInteractive) {
    if ($Global:ProfileConfig.EnableOhMyPosh) {
        Initialize-OhMyPosh | Out-Null
    }
    if ($Global:ProfileConfig.EnableTerminalIcons) {
        Initialize-TerminalIcons | Out-Null
    }
    if ($Global:ProfileConfig.EnablePoshGit) {
        Initialize-PoshGit | Out-Null
    }
}

#endregion PROMPT CUSTOMIZATION AND SHELL ENHANCEMENTS
