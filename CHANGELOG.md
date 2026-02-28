## [2.1.0] - 2026-02-28
### Fixed
- Scoped $ProgressPreference to profile load only (was leaked globally)
- Deferred Update-InstalledModulesCache (removed synchronous Get-InstalledModule on every load)
- Eliminated duplicate argument-completer registration (Region 21 → no-op)
- Added ValidateRange(1,65535) to Test-TcpPort -Port
- Added ValidatePattern on Invoke-DiskMaintenance -DriveLetter
- Added ShouldProcess guard to Optimize-System Clear-RecycleBin
- Renamed $event → $monitorEntry (avoids automatic variable conflict)
- Fixed unused $fixedContent in Invoke-ProfileLint -Fix

### Added
- Region 24: Hardware Diagnostics (Invoke-SafeCimQuery, Get-HardwareSummary, Get-SmartDiskHealth, Get-BatteryHealth)
- Region 25: Network Toolkit (Invoke-Traceroute, Get-ArpTable, Invoke-PortScan, Get-NicStatistics, Test-DnsResolution)
- Region 26: Event & Log Helpers (Get-RecentEvents, Export-EventLogToJson, Get-EventLogSummary)
- Region 27: Secure Remote Management (Connect-RemoteHost, Invoke-RemoteCommand, Remove-AllRemoteSessions)
- Region 28: Monitoring & Alerting (Write-MonitorEvent, Test-ThresholdAlerts, Get-MonitorLog)
- Region 29: Interactive Productivity (Show-CommandPalette, Find-ProfileCommand, Get-ContextSuggestions)
- Region 30: Diagnostics Automation (Collect-SystemSnapshot)
- Region 31: Testing & Linting (Invoke-ProfileLint, Test-ProfileScript, Invoke-ProfilePesterTests)
- Region 32: Code Signing Guidance (Sign-ProfileScript)
- Assert-ModuleAvailable alias for Ensure-Module
- Pester test suite (50+ smoke tests)

### Rollback Notes
- Copy Backups/Microsoft.PowerShell_profile.ps1 to workspace root
- New regions 24-32 are additive; removing them has no effect on regions 1-23
- $Global:ProfileConfig.AlertThresholds is new; removing it is safe