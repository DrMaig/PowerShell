<#
.SYNOPSIS
    Profile component 05 - Psreadline Configuration
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 5 (PSREADLINE CONFIGURATION) for modular dot-sourced loading.
#>

#region 5 - PSREADLINE CONFIGURATION
#==============================================================================
<#
.SYNOPSIS
    PSReadLine configuration with predictive IntelliSense
.DESCRIPTION
    Configures PSReadLine for enhanced command-line editing with history-based
    predictions, syntax coloring, and customizable key bindings.
    Reference: https://learn.microsoft.com/powershell/module/psreadline/
#>

function Set-ProfilePSReadLineKeyHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [string]$Function,
        [string]$BriefDescription,
        [string]$LongDescription,
        [scriptblock]$ScriptBlock
    )

    try {
        if ($ScriptBlock) {
            Set-PSReadLineKeyHandler -Key $Key -BriefDescription $BriefDescription -LongDescription $LongDescription -ScriptBlock $ScriptBlock -ErrorAction Stop
        } else {
            Set-PSReadLineKeyHandler -Key $Key -Function $Function -ErrorAction Stop
        }
        return $true
    } catch {
        Write-ProfileLog "PSReadLine key handler failed for '$Key': $($_.Exception.Message)" -Level DEBUG -Component "PSReadLine"
        return $false
    }
}

function Initialize-CommandPredictorModules {
    [CmdletBinding()]
    param([hashtable]$Options)

    if (-not $Options.EnablePredictorModules) {
        return @()
    }

    $loaded = @()
    foreach ($moduleName in @($Options.PredictorModules)) {
        if (-not $moduleName) { continue }

        $moduleInfo = Get-Module -ListAvailable -Name $moduleName -ErrorAction Ignore |
            Select-Object -First 1
        if (-not $moduleInfo) {
            continue
        }

        $missingDependencies = @()
        foreach ($requiredModule in @($moduleInfo.RequiredModules)) {
            $requiredName = if ($requiredModule -is [string]) { $requiredModule } else { $requiredModule.Name }
            if (-not $requiredName) { continue }
            if (-not (Get-Module -ListAvailable -Name $requiredName -ErrorAction Ignore)) {
                $missingDependencies += $requiredName
            }
        }

        if ($missingDependencies.Count -gt 0) {
            Write-ProfileLog "Predictor module '$moduleName' skipped; missing dependencies: $($missingDependencies -join ', ')" -Level DEBUG -Component "PSReadLine"
            continue
        }

        Import-Module -Name $moduleName -ErrorAction Ignore | Out-Null
        if (Get-Module -Name $moduleName -ErrorAction Ignore) {
            $loaded += $moduleName
        } else {
            Write-ProfileLog "Predictor module '$moduleName' was not loaded" -Level DEBUG -Component "PSReadLine"
        }
    }

    return $loaded
}

function Initialize-PSReadLine {
    <#
    .SYNOPSIS
        Initializes and configures PSReadLine.
    .DESCRIPTION
        Sets up PSReadLine with optimal settings for PowerShell 7.5+.
    #>
    [CmdletBinding()]
    param()

    # Check if PSReadLine is available
    if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
        Write-ProfileLog "PSReadLine not available" -Level WARN -Component "PSReadLine"
        return $false
    }

    try {
        # Import PSReadLine
        Import-Module PSReadLine -Force -ErrorAction Stop

        $opts = $Global:ProfileConfig.PSReadLine

        # Ensure history path parent exists
        if ($opts.HistorySavePath) {
            $historyDir = Split-Path -Path $opts.HistorySavePath -Parent
            if ($historyDir -and -not (Test-Path -LiteralPath $historyDir)) {
                New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
            }
        }

        # Basic options
        Set-PSReadLineOption -EditMode $opts.EditMode
        Set-PSReadLineOption -MaximumHistoryCount $opts.HistorySize
        Set-PSReadLineOption -HistorySavePath $opts.HistorySavePath
        Set-PSReadLineOption -BellStyle $opts.BellStyle

        $loadedPredictors = Initialize-CommandPredictorModules -Options $opts

        # Prediction settings (PowerShell 7.2+)
        if ($PSVersionTable.PSVersion -ge [version]'7.2.0') {
            try {
                $predictionSource = $opts.PredictionSource
                if ($predictionSource -eq 'HistoryAndPlugin' -and @($loadedPredictors).Count -eq 0) {
                    $predictionSource = 'History'
                }

                Set-PSReadLineOption -PredictionSource $predictionSource -ErrorAction Ignore
            } catch {
                # Fallback to History only
                Set-PSReadLineOption -PredictionSource History -ErrorAction Ignore
            }
        } else {
            Set-PSReadLineOption -PredictionSource History -ErrorAction Ignore
        }

        Set-PSReadLineOption -PredictionViewStyle $opts.PredictionViewStyle -ErrorAction Ignore
        Set-PSReadLineOption -HistoryNoDuplicates:$opts.HistoryNoDuplicates -ErrorAction Ignore
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd:$opts.HistorySearchCursorMovesToEnd -ErrorAction Ignore
        Set-PSReadLineOption -ShowToolTips:$opts.ShowToolTips -ErrorAction Ignore

        # Colors
        if ($opts.Colors) {
            Set-PSReadLineOption -Colors $opts.Colors -ErrorAction Ignore
        }

        # Key bindings
        foreach ($kb in $opts.KeyBindings.GetEnumerator()) {
            Set-ProfilePSReadLineKeyHandler -Key $kb.Key -Function $kb.Value | Out-Null
        }

        # Maximum kill ring count
        Set-PSReadLineOption -MaximumKillRingCount $opts.MaximumKillRingCount -ErrorAction Ignore

        # Word delimiters for Ctrl+Backspace, Ctrl+Left/Right word navigation
        if ($opts.WordDelimiters) {
            Set-PSReadLineOption -WordDelimiters $opts.WordDelimiters -ErrorAction Ignore
        }

        # ── Productivity key bindings ──────────────────────────────────
        # Tab → MenuComplete: shows a navigable completion menu instead of cycling
        Set-ProfilePSReadLineKeyHandler -Key Tab -Function MenuComplete | Out-Null
        Set-ProfilePSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious | Out-Null

        # Arrow keys → context-aware history search (type partial cmd then ↑/↓)
        Set-ProfilePSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward | Out-Null
        Set-ProfilePSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward | Out-Null

        # Ctrl+Space → show all available completions in a list
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+Spacebar -Function PossibleCompletions | Out-Null

        # F1 → show help for current command in a separate window
        Set-ProfilePSReadLineKeyHandler -Key F1 -Function ShowCommandHelp | Out-Null

        # F2 → toggle between inline and list prediction view
        Set-ProfilePSReadLineKeyHandler -Key F2 -Function SwitchPredictionView | Out-Null

        # Ctrl+r / Ctrl+s → interactive history search (Emacs-style)
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory | Out-Null
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+s -Function ForwardSearchHistory | Out-Null

        # Ctrl+w → delete word backward (Unix muscle memory)
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord | Out-Null

        # Alt+d → delete word forward
        Set-ProfilePSReadLineKeyHandler -Key Alt+d -Function DeleteWord | Out-Null

        # Alt+. → insert last argument of previous command (huge time saver)
        Set-ProfilePSReadLineKeyHandler -Key Alt+. -Function YankLastArg | Out-Null

        # Ctrl+Home / Ctrl+End → jump to start/end of buffer
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+Home -Function BeginningOfLine | Out-Null
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+End -Function EndOfLine | Out-Null

        # Smart paired quotes: typing " inserts paired quotes with cursor inside
        Set-ProfilePSReadLineKeyHandler -Key '"' -BriefDescription SmartInsertQuote -LongDescription 'Insert paired quotes; wrap selection if text is selected' -ScriptBlock {
                param($key, $arg)
                $quote = $key.KeyChar
                $selectionStart = $null
                $selectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($null -eq $line) { $line = '' }
                if ($selectionStart -ne -1) {
                    # Wrap selected text in quotes
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                } elseif ($cursor -lt $line.Length -and $line[$cursor] -eq $quote) {
                    # Skip over closing quote
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                } else {
                    # Insert paired quotes, cursor between them
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote + $quote)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                }
            } | Out-Null

        Set-ProfilePSReadLineKeyHandler -Key "'" -BriefDescription SmartInsertQuote -LongDescription 'Insert paired quotes; wrap selection if text is selected' -ScriptBlock {
                param($key, $arg)
                $quote = $key.KeyChar
                $selectionStart = $null
                $selectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($null -eq $line) { $line = '' }
                if ($selectionStart -ne -1) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                } elseif ($cursor -lt $line.Length -and $line[$cursor] -eq $quote) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote + $quote)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                }
            } | Out-Null

        # Smart paired braces: typing ( { [ inserts the pair
        Set-ProfilePSReadLineKeyHandler -Key '(' -BriefDescription InsertPairedBrace -LongDescription 'Insert matching closing brace; wrap selection if selected' -ScriptBlock {
                param($key, $arg)
                $openChar  = $key.KeyChar
                $closeChar = switch ($openChar) { '(' { ')' } '{' { '}' } '[' { ']' } }
                $selectionStart = $null; $selectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($selectionStart -ne -1) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $openChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($openChar + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                }
            } | Out-Null

        Set-ProfilePSReadLineKeyHandler -Key '{' -BriefDescription InsertPairedBrace -LongDescription 'Insert matching closing brace; wrap selection if selected' -ScriptBlock {
                param($key, $arg)
                $openChar  = $key.KeyChar
                $closeChar = switch ($openChar) { '(' { ')' } '{' { '}' } '[' { ']' } }
                $selectionStart = $null; $selectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($selectionStart -ne -1) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $openChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($openChar + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                }
            } | Out-Null

        Set-ProfilePSReadLineKeyHandler -Key '[' -BriefDescription InsertPairedBrace -LongDescription 'Insert matching closing brace; wrap selection if selected' -ScriptBlock {
                param($key, $arg)
                $openChar  = $key.KeyChar
                $closeChar = switch ($openChar) { '(' { ')' } '{' { '}' } '[' { ']' } }
                $selectionStart = $null; $selectionLength = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($selectionStart -ne -1) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $openChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($openChar + $closeChar)
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                }
            } | Out-Null

        # Smart closing brace: skip over existing close brace if it matches
        Set-ProfilePSReadLineKeyHandler -Key ')' -BriefDescription SmartCloseBrace -LongDescription 'Skip over closing brace if next char matches; otherwise insert' -ScriptBlock {
                param($key, $arg)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($null -eq $line) { $line = '' }
                if ($cursor -lt $line.Length -and $line[$cursor] -eq $key.KeyChar) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
                }
            } | Out-Null

        Set-ProfilePSReadLineKeyHandler -Key '}' -BriefDescription SmartCloseBrace -LongDescription 'Skip over closing brace if next char matches; otherwise insert' -ScriptBlock {
                param($key, $arg)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($null -eq $line) { $line = '' }
                if ($cursor -lt $line.Length -and $line[$cursor] -eq $key.KeyChar) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
                }
            } | Out-Null

        Set-ProfilePSReadLineKeyHandler -Key ']' -BriefDescription SmartCloseBrace -LongDescription 'Skip over closing brace if next char matches; otherwise insert' -ScriptBlock {
                param($key, $arg)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($null -eq $line) { $line = '' }
                if ($cursor -lt $line.Length -and $line[$cursor] -eq $key.KeyChar) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
                } else {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
                }
            } | Out-Null

        # Ctrl+Shift+c → copy entire command line
        Set-ProfilePSReadLineKeyHandler -Key Ctrl+Shift+c -BriefDescription CopyEntireLine -LongDescription 'Copy the entire command line to clipboard' -ScriptBlock {
                param($key, $arg)
                $line = $null; $cursor = $null
                [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
                if ($line) { Set-Clipboard $line }
            } | Out-Null

        if (@($loadedPredictors).Count -gt 0) {
            Write-ProfileLog "PSReadLine predictors loaded: $($loadedPredictors -join ', ')" -Level DEBUG -Component "PSReadLine"
        }

        Write-ProfileLog "PSReadLine configured successfully" -Level INFO -Component "PSReadLine"
        return $true

    } catch {
        Write-ProfileLog "PSReadLine configuration failed: $_" -Level WARN -Component "PSReadLine"
        return $false
    }
}

function Show-PSReadLineConfig {
    <#
    .SYNOPSIS
        Displays current PSReadLine configuration.
    .DESCRIPTION
        Shows all current PSReadLine settings.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command Get-PSReadLineOption -ErrorAction Ignore)) {
        Write-Host "PSReadLine not available" -ForegroundColor Yellow
        return
    }

    try {
        Get-PSReadLineOption | Format-List
    } catch {
        Write-ProfileLog "Show-PSReadLineConfig failed: $_" -Level DEBUG
    }
}

# Initialize PSReadLine for interactive sessions
if ((Test-ProfileInteractive) -and $Global:ProfileConfig.Features.UsePSReadLine) {
    Initialize-PSReadLine | Out-Null
}

#endregion PSREADLINE CONFIGURATION
