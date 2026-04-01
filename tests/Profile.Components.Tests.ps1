 $script:ComponentFiles = Get-ChildItem -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') -Filter '*.ps1' -File | Sort-Object Name

BeforeAll {
    function Write-ProfileLog { param([string]$Message,[string]$Level='INFO',[string]$Component='Tests') }
    function Write-CaughtException { param([string]$Context,[object]$ErrorRecord) }
    function Test-ProfileInteractive { return $false }
    function Test-Admin { return $false }

    $Global:ProfileState = [ordered]@{ IsWindows = $IsWindows; IsLinux = $IsLinux; IsMacOS = $IsMacOS; Notes = @() }
    $Global:ProfileStats = [ordered]@{ ModulesLoaded = 0; ComponentLoadTimes = [ordered]@{} }
    $Global:ProfileConfig = [ordered]@{
        StartupMode = 'minimal'
        ShowWelcome = $false
        LoggingEnabled = $false
        Features = [ordered]@{}
        Integrations = [ordered]@{}
        DeferredLoader = [ordered]@{ Modules = @(); TimeoutSeconds = 1; UseJobs = $false }
        AlertThresholds = [ordered]@{ CpuPercent = 95; MemoryPercent = 95; DiskPercent = 95 }
    }
}

Describe 'Profile components' {
    It 'dot-sources each component without throwing' -ForEach $script:ComponentFiles {
        { . $_.FullName } | Should -Not -Throw
    }
}

Describe 'ProfileStats contract' {
    It 'bootstrap preserves existing ComponentLoadTimes map' {
        $bootstrapPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/01-Bootstrap.ps1'

        $Global:ProfileStats = [ordered]@{
            ModulesLoaded = 7
            ComponentLoadTimes = [ordered]@{ 'pre' = 1.23 }
        }

        . $bootstrapPath

        $Global:ProfileStats.Contains('ComponentLoadTimes') | Should -BeTrue
        $Global:ProfileStats.ComponentLoadTimes['pre'] | Should -Be 1.23
    }

    It 'bootstrap initializes ComponentLoadTimes when missing' {
        $bootstrapPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/01-Bootstrap.ps1'

        $Global:ProfileStats = [ordered]@{ ModulesLoaded = 0 }

        . $bootstrapPath

        $Global:ProfileStats.Contains('ComponentLoadTimes') | Should -BeTrue
        ($Global:ProfileStats.ComponentLoadTimes -is [System.Collections.IDictionary]) | Should -BeTrue
    }
}
