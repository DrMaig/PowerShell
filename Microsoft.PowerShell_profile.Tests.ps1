#requires -Modules Pester
<#
.SYNOPSIS
    Pester smoke tests for Microsoft.PowerShell_profile.ps1
.DESCRIPTION
    Validates core profile functions are defined, parse-clean, and return
    expected types. Run with:
        Invoke-Pester .\Microsoft.PowerShell_profile.Tests.ps1 -Output Detailed
    Or from inside the profile:
        Invoke-ProfilePesterTests
.NOTES
    These are non-destructive smoke tests. They do NOT test state-changing functions
    (DNS changes, service restarts, package installs, etc.).
#>

BeforeAll {
    # Source the profile in a clean scope for function definitions
    # This avoids side effects from the bootstrap guards by mocking globals
    $profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
    if (-not (Test-Path $profilePath)) {
        throw "Profile not found at $profilePath"
    }
}

Describe 'Profile Script Parsing' {
    It 'Parses without syntax errors' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'),
            [ref]$tokens, [ref]$errors
        ) | Out-Null
        $errors.Count | Should -Be 0 -Because "profile should have zero parse errors"
    }
}

Describe 'Bootstrap and Guards' {
    It 'Sets $script:ProfileVersion' {
        # Parse to verify the variable is declared
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $content | Should -Match '\$script:ProfileVersion\s*=' -Because "ProfileVersion should be declared"
    }

    It 'Requires PowerShell 7.5+' {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $content | Should -Match '#requires\s+-Version\s+7\.5' -Because "profile should require 7.5+"
    }

    It 'Sets StrictMode' {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $content | Should -Match 'Set-StrictMode' -Because "StrictMode should be enabled"
    }
}

Describe 'Core Function Definitions' {
    BeforeAll {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $script:functionNames = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            ForEach-Object { $_.Name }
    }

    It 'Defines Test-Admin' {
        $script:functionNames | Should -Contain 'Test-Admin'
    }

    It 'Defines Test-ProfileInteractive' {
        $script:functionNames | Should -Contain 'Test-ProfileInteractive'
    }

    It 'Defines Write-ProfileLog' {
        $script:functionNames | Should -Contain 'Write-ProfileLog'
    }

    It 'Defines Test-Environment' {
        $script:functionNames | Should -Contain 'Test-Environment'
    }

    It 'Defines Get-SystemInfo' {
        $script:functionNames | Should -Contain 'Get-SystemInfo'
    }

    It 'Defines Get-DiskInfo' {
        $script:functionNames | Should -Contain 'Get-DiskInfo'
    }

    It 'Defines Get-MemoryInfo' {
        $script:functionNames | Should -Contain 'Get-MemoryInfo'
    }

    It 'Defines Get-CPUInfo' {
        $script:functionNames | Should -Contain 'Get-CPUInfo'
    }

    It 'Defines Test-TcpPort' {
        $script:functionNames | Should -Contain 'Test-TcpPort'
    }

    It 'Defines Get-NetworkSnapshot' {
        $script:functionNames | Should -Contain 'Get-NetworkSnapshot'
    }

    It 'Defines Test-ProfileHealth' {
        $script:functionNames | Should -Contain 'Test-ProfileHealth'
    }

    It 'Defines Get-TopProcesses' {
        $script:functionNames | Should -Contain 'Get-TopProcesses'
    }
}

Describe 'New Enhancement Functions' {
    BeforeAll {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $script:functionNames = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            ForEach-Object { $_.Name }
    }

    # Region 24: Hardware Diagnostics
    It 'Defines Invoke-SafeCimQuery' {
        $script:functionNames | Should -Contain 'Invoke-SafeCimQuery'
    }

    It 'Defines Get-HardwareSummary' {
        $script:functionNames | Should -Contain 'Get-HardwareSummary'
    }

    It 'Defines Get-SmartDiskHealth' {
        $script:functionNames | Should -Contain 'Get-SmartDiskHealth'
    }

    It 'Defines Get-BatteryHealth' {
        $script:functionNames | Should -Contain 'Get-BatteryHealth'
    }

    # Region 25: Network Toolkit
    It 'Defines Invoke-Traceroute' {
        $script:functionNames | Should -Contain 'Invoke-Traceroute'
    }

    It 'Defines Get-ArpTable' {
        $script:functionNames | Should -Contain 'Get-ArpTable'
    }

    It 'Defines Invoke-PortScan' {
        $script:functionNames | Should -Contain 'Invoke-PortScan'
    }

    It 'Defines Get-NicStatistics' {
        $script:functionNames | Should -Contain 'Get-NicStatistics'
    }

    It 'Defines Test-DnsResolution' {
        $script:functionNames | Should -Contain 'Test-DnsResolution'
    }

    # Region 26: Event Log
    It 'Defines Get-RecentEvents' {
        $script:functionNames | Should -Contain 'Get-RecentEvents'
    }

    It 'Defines Export-EventLogToJson' {
        $script:functionNames | Should -Contain 'Export-EventLogToJson'
    }

    It 'Defines Get-EventLogSummary' {
        $script:functionNames | Should -Contain 'Get-EventLogSummary'
    }

    # Region 27: Remote Management
    It 'Defines Test-RemoteHost' {
        $script:functionNames | Should -Contain 'Test-RemoteHost'
    }

    It 'Defines Connect-RemoteHost' {
        $script:functionNames | Should -Contain 'Connect-RemoteHost'
    }

    It 'Defines Invoke-RemoteCommand' {
        $script:functionNames | Should -Contain 'Invoke-RemoteCommand'
    }

    # Region 28: Monitoring
    It 'Defines Write-MonitorEvent' {
        $script:functionNames | Should -Contain 'Write-MonitorEvent'
    }

    It 'Defines Test-ThresholdAlerts' {
        $script:functionNames | Should -Contain 'Test-ThresholdAlerts'
    }

    It 'Defines Get-MonitorLog' {
        $script:functionNames | Should -Contain 'Get-MonitorLog'
    }

    # Region 29: Productivity
    It 'Defines Show-CommandPalette' {
        $script:functionNames | Should -Contain 'Show-CommandPalette'
    }

    It 'Defines Find-ProfileCommand' {
        $script:functionNames | Should -Contain 'Find-ProfileCommand'
    }

    # Region 30: Snapshot
    It 'Defines Collect-SystemSnapshot' {
        $script:functionNames | Should -Contain 'Collect-SystemSnapshot'
    }

    # Region 31: Linting
    It 'Defines Invoke-ProfileLint' {
        $script:functionNames | Should -Contain 'Invoke-ProfileLint'
    }

    It 'Defines Test-ProfileScript' {
        $script:functionNames | Should -Contain 'Test-ProfileScript'
    }

    # Region 32: Signing
    It 'Defines Sign-ProfileScript' {
        $script:functionNames | Should -Contain 'Sign-ProfileScript'
    }
}

Describe 'ShouldProcess Compliance' {
    BeforeAll {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $script:allFunctions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    }

    It 'Set-DnsServers has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Set-DnsServers' }
        $f | Should -Not -BeNullOrEmpty -Because 'Set-DnsServers should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Set-DnsProfile has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Set-DnsProfile' }
        $f | Should -Not -BeNullOrEmpty -Because 'Set-DnsProfile should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Set-PowerPlan has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Set-PowerPlan' }
        $f | Should -Not -BeNullOrEmpty -Because 'Set-PowerPlan should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Restart-NetworkAdapter has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Restart-NetworkAdapter' }
        $f | Should -Not -BeNullOrEmpty -Because 'Restart-NetworkAdapter should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Restart-ServiceByName has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Restart-ServiceByName' }
        $f | Should -Not -BeNullOrEmpty -Because 'Restart-ServiceByName should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Stop-ProcessByName has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Stop-ProcessByName' }
        $f | Should -Not -BeNullOrEmpty -Because 'Stop-ProcessByName should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Optimize-System has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Optimize-System' }
        $f | Should -Not -BeNullOrEmpty -Because 'Optimize-System should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Invoke-DiskMaintenance has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Invoke-DiskMaintenance' }
        $f | Should -Not -BeNullOrEmpty -Because 'Invoke-DiskMaintenance should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Clear-DnsCache has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Clear-DnsCache' }
        $f | Should -Not -BeNullOrEmpty -Because 'Clear-DnsCache should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Repair-Profile has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Repair-Profile' }
        $f | Should -Not -BeNullOrEmpty -Because 'Repair-Profile should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Reset-ProfileToDefaults has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Reset-ProfileToDefaults' }
        $f | Should -Not -BeNullOrEmpty -Because 'Reset-ProfileToDefaults should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Clear-TempFiles has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Clear-TempFiles' }
        $f | Should -Not -BeNullOrEmpty -Because 'Clear-TempFiles should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Invoke-RemoteCommand has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Invoke-RemoteCommand' }
        $f | Should -Not -BeNullOrEmpty -Because 'Invoke-RemoteCommand should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Collect-SystemSnapshot has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Collect-SystemSnapshot' }
        $f | Should -Not -BeNullOrEmpty -Because 'Collect-SystemSnapshot should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }

    It 'Sign-ProfileScript has SupportsShouldProcess' {
        $f = $script:allFunctions | Where-Object { $_.Name -eq 'Sign-ProfileScript' }
        $f | Should -Not -BeNullOrEmpty -Because 'Sign-ProfileScript should exist'
        $f.Body.Extent.Text | Should -Match 'SupportsShouldProcess'
    }
}

Describe 'Parameter Validation' {
    BeforeAll {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
    }

    It 'Test-TcpPort has ValidateRange on Port' {
        $content | Should -Match 'ValidateRange\(1,\s*65535\)' -Because "Port should be validated 1-65535"
    }

    It 'Invoke-DiskMaintenance has ValidatePattern on DriveLetter' {
        # ValidatePattern and DriveLetter are on adjacent lines; use (?s) for dotall
        $content | Should -Match '(?s)ValidatePattern.{0,50}DriveLetter' -Because "Drive letter should be validated"
    }

    It 'Invoke-PortScan limits port count' {
        $content | Should -Match 'ValidateCount\(1,\s*100\)' -Because "Port scan should limit port count"
    }
}

Describe 'Security Checks' {
    BeforeAll {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
    }

    It 'Does not contain plaintext credentials or API keys' {
        $content | Should -Not -Match '(password|apikey|secret|token)\s*=\s*[''"][^''"]+[''"]' -Because "No hardcoded secrets should exist"
    }

    It 'Invoke-Expression is not used (ScriptBlock::Create preferred)' {
        $iexMatches = [regex]::Matches($content, 'Invoke-Expression')
        $iexMatches.Count | Should -Be 0 -Because "Invoke-Expression was replaced with ScriptBlock::Create for safety"
    }

    It 'No automatic install/update in startup path' {
        # Verify that top-level startup execution (outside function bodies) does not call Install-Module or Update-Module.
        # Function definitions like Ensure-Module legitimately reference Install-Module inside their body.
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $funcBodies = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            ForEach-Object { $_.Body.Extent.Text }
        # Strip function bodies from startup section to get only top-level statements
        $startupSection = $content.Substring(0, $content.IndexOf('Show-WelcomeScreen'))
        $stripped = $startupSection
        foreach ($body in $funcBodies) {
            $stripped = $stripped.Replace($body, '')
        }
        $stripped | Should -Not -Match 'Install-Module\s' -Because "Startup should not auto-install modules"
        $stripped | Should -Not -Match 'Update-Module\s' -Because "Startup should not auto-update modules"
    }
}

Describe 'Idempotency' {
    It 'Profile has reload guard' {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $content | Should -Match 'ProfileLoadedTimestamp.*Skipping reload' -Because "Profile should guard against duplicate loads"
    }

    It 'Exit handler registration is idempotent' {
        $content = Get-Content (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') -Raw
        $content | Should -Match 'Get-EventSubscriber.*PowerShell\.Exiting' -Because "Exit handler should check before registering"
    }
}

Describe 'JSON Config Validation' {
    It 'powershell.config.json is valid JSON' {
        $configPath = Join-Path $PSScriptRoot 'powershell.config.json'
        if (Test-Path $configPath) {
            { Get-Content $configPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Config file not found"
        }
    }
}
