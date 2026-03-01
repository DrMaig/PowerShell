BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $script:ComponentFiles = Get-ChildItem -Path (Join-Path $repoRoot 'src') -Filter '*.ps1' -File | Sort-Object Name

    function Write-ProfileLog { param([string]$Message,[string]$Level='INFO',[string]$Component='Tests') }
    function Write-CaughtException { param([string]$Context,[object]$ErrorRecord) }
    function Test-ProfileInteractive { return $false }
    function Test-Admin { return $false }

    $Global:ProfileState = [ordered]@{ IsWindows = $IsWindows; IsLinux = $IsLinux; IsMacOS = $IsMacOS; Notes = @() }
    $Global:ProfileStats = [ordered]@{ ModulesLoaded = 0 }
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
