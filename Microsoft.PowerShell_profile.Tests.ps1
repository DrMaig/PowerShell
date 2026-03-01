#requires -Modules Pester
<#!
.SYNOPSIS
    Modular smoke tests for Microsoft.PowerShell_profile.ps1
.DESCRIPTION
    Validates orchestrator/component parse integrity, expected component wiring,
    configuration file validity, and constrained security policy for Invoke-Expression.
#>

BeforeAll {
    $script:RepoRoot = $PSScriptRoot
    $script:ProfilePath = Join-Path $script:RepoRoot 'Microsoft.PowerShell_profile.ps1'
    $script:SrcPath = Join-Path $script:RepoRoot 'src'
    $script:ProfileContent = Get-Content -LiteralPath $script:ProfilePath -Raw
}

Describe 'Profile Parse Validation' {
    It 'parses orchestrator and all src components without errors' {
        $allFiles = @($script:ProfilePath) + @(Get-ChildItem -Path $script:SrcPath -Filter '*.ps1' -File | ForEach-Object FullName)
        $parseErrors = @()

        foreach ($file in $allFiles) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errors) > $null
            if ($errors) { $parseErrors += $errors }
        }

        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'Orchestrator Contract' {
    It 'requires PowerShell 7.5+' {
        $script:ProfileContent | Should -Match '#requires\s+-Version\s+7\.5'
    }

    It 'declares exactly 32 ordered components' {
        $componentMatches = [regex]::Matches($script:ProfileContent, "'\d{2}-[^']+'").Value
        $componentMatches.Count | Should -Be 32
    }

    It 'includes ComponentLoadTimes in ProfileStats schema' {
        $script:ProfileContent | Should -Match 'ComponentLoadTimes\s*=\s*\[ordered\]@\{\}'
    }
}

Describe 'Component Wiring' {
    It 'contains all declared component files' {
        $expected = @(1..32 | ForEach-Object { '{0:D2}-*.ps1' -f $_ })
        foreach ($pattern in $expected) {
            @(Get-ChildItem -Path $script:SrcPath -Filter $pattern -File).Count | Should -BeGreaterThan 0
        }
    }

    It 'native completer bootstrap script exists and parses cleanly' {
        $completerPath = Join-Path $script:RepoRoot 'Scripts\Initialize-NativeToolCompleters.ps1'
        Test-Path -LiteralPath $completerPath | Should -BeTrue

        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($completerPath, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }
}

Describe 'Configuration Validation' {
    It 'powershell.config.json is valid JSON' {
        $configPath = Join-Path $script:RepoRoot 'powershell.config.json'
        { Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
}

Describe 'Security Policy' {
    It 'does not use Invoke-Expression in orchestrator' {
        [regex]::Matches($script:ProfileContent, 'Invoke-Expression').Count | Should -Be 0
    }

    It 'allows Invoke-Expression only for conda hook in profile.ps1' {
        $profilePath = Join-Path $script:RepoRoot 'profile.ps1'
        if (-not (Test-Path -LiteralPath $profilePath)) {
            Set-ItResult -Skipped -Because 'profile.ps1 not found'
            return
        }

        $profileContent = Get-Content -LiteralPath $profilePath -Raw
        $iexMatches = [regex]::Matches($profileContent, 'Invoke-Expression')
        $iexMatches.Count | Should -BeLessOrEqual 1

        if ($iexMatches.Count -eq 1) {
            $profileContent | Should -Match 'conda\.exe[\s\S]{0,500}shell\.powershell[\s\S]{0,500}hook[\s\S]{0,500}Invoke-Expression'
        }
    }
}
