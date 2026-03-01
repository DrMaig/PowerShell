$script:ExpectedFunctions = @(
    'Test-Admin','Test-ProfileInteractive','Write-ProfileLog','Write-CaughtException',
    'Test-Environment','Assert-ModuleAvailable','Get-SystemInfo','Get-DiskInfo','Get-MemoryInfo',
    'Get-CPUInfo','Test-TcpPort','Get-LocalIP','Get-PublicIP','Set-DnsProfile','Optimize-System',
    'Test-ProfileHealth','Get-TopProcesses','Get-HardwareSummary','Invoke-Traceroute',
    'Get-RecentEvents','Invoke-RemoteCommand','Collect-SystemSnapshot','Invoke-ProfileLint','Sign-ProfileScript'
)

BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    function Write-ProfileLog { param([string]$Message,[string]$Level='INFO',[string]$Component='Tests') }
    function Write-CaughtException { param([string]$Context,[object]$ErrorRecord) }
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
    Get-ChildItem -Path (Join-Path $repoRoot 'src') -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }

}

Describe 'Profile functions' {
    It 'loads expected functions' -ForEach $script:ExpectedFunctions {
        Get-Command -Name $_ -CommandType Function -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'uses CmdletBinding on key advanced functions' -ForEach @(
        'Test-TcpPort','Set-DnsProfile','Optimize-System','Invoke-RemoteCommand','Collect-SystemSnapshot','Sign-ProfileScript'
    ) {
        $cmd = Get-Command -Name $_ -CommandType Function -ErrorAction Stop
        $cmd.CmdletBinding | Should -BeTrue
    }

    It 'retains Ensure-Module backwards-compatibility alias' {
        (Get-Command Ensure-Module -ErrorAction Stop).CommandType | Should -Be 'Alias'
        (Get-Alias Ensure-Module).Definition | Should -Be 'Assert-ModuleAvailable'
    }
}
