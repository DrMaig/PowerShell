Describe 'Profile config' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:ProfileRoot = $repoRoot
        $configPath = Join-Path $repoRoot 'powershell.config.json'
        $script:Config = Get-Content $configPath -Raw | ConvertFrom-Json
        . (Join-Path $repoRoot 'src/02-Config.ps1')
    }

    It 'has valid JSON config' {
        $script:Config | Should -Not -BeNullOrEmpty
    }

    It 'returns expected defaults structure' {
        $defaults = Get-ProfileConfigDefaults
        $defaults | Should -Not -BeNullOrEmpty
        $defaults.Contains('StartupMode') | Should -BeTrue
        $defaults.Contains('Features') | Should -BeTrue
    }

    It 'merges override values into defaults' {
        $base = [ordered]@{ StartupMode = 'full'; Features = [ordered]@{ UsePSReadLine = $true } }
        $override = [ordered]@{ StartupMode = 'minimal'; Features = [ordered]@{ UsePSReadLine = $false } }
        $merged = Merge-ProfileConfig -Base $base -Override $override
        $merged.StartupMode | Should -Be 'minimal'
        $merged.Features.UsePSReadLine | Should -BeFalse
    }
}
