## [3.1.0] - 2026-03-02

### Fixed
- Added `$IsWindows` platform guards to 12+ Windows-only functions across 5 components:
  - `07-SystemAdmin.ps1`: `Get-SystemInfo`, `Get-DiskInfo`, `Get-MemoryInfo`, `Get-CPUInfo`, `Get-GPUInfo`, `Get-BIOSInfo`, `Get-SystemHealth`
  - `08-Performance.ps1`: `Get-PerfSnapshot`; `Get-TopProcesses -By IO` falls back to Memory sort on non-Windows
  - `13-ProcessService.ps1`: `Get-ServiceHealth`, `Get-ProcessTree`
  - `28-Monitoring.ps1`: `Test-ThresholdAlerts`
  - `32-CodeSigning.ps1`: `Sign-ProfileScript`
- Added `$IsWindows` guard to `Optimize-System` in `11-WinOptimization.ps1`
- Wrapped `nano→notepad` alias and `sudo` function in `$IsWindows` checks in `20-Aliases.ps1` to avoid shadowing real Unix commands
- Wrapped Windows-only temp paths (`$env:LOCALAPPDATA`, `$env:WINDIR`) in `$IsWindows` guard in `Clear-TempFiles`
- Fixed broken `Start-Job` deferred module loader in `06-ModuleManagement.ps1` — jobs import modules in a child process, making them unavailable to the caller. Replaced with `Register-EngineEvent PowerShell.OnIdle` for true non-blocking deferred loading with synchronous fallback.
- Fixed version banner in `22-Welcome.ps1` — was hardcoded "v2.1", now uses dynamic `$script:ProfileVersion`
- Optimized `Get-ProcessTree` to use a single bulk CIM query instead of O(n) individual queries per process

### Changed
- Renamed `Collect-SystemSnapshot` to `Export-SystemSnapshot` (approved verb). Backward-compatibility alias `Collect-SystemSnapshot` retained.
- Added `ConfirmImpact = 'High'` to `Optimize-System` and `Clear-TempFiles` (destructive file operations)
- Added `ConfirmImpact = 'Medium'` to `Sign-ProfileScript` and `Export-SystemSnapshot`
- Removed duplicate `$Global:ProfileStats` defensive re-initialization from orchestrator try/catch blocks (already initialized before loop)
- Differentiated `la` alias to use `Get-ChildItem -Force` (show hidden files), distinct from `ll` and `l`
- Bumped profile version to 3.1.0

### Notes
- All 02-Config functions already had `[CmdletBinding()]`; no changes needed.
- `Connect-RemoteHost` already had optional `-Credential` parameter with interactive fallback; no changes needed.
- All Windows-only functions now return informative warnings on non-Windows platforms rather than errors.

## [3.0.0] - 2026-03-01

### Changed
- Refactored `Microsoft.PowerShell_profile.ps1` into a thin orchestrator that dot-sources 32 modular components from `src/`.
- Preserved original region ordering by mapping each region to `src/XX-Name.ps1`.
- Updated profile metadata to version `3.0.0` with Windows/Linux/macOS support note.
- Replaced hard non-Windows bootstrap exit with reduced-feature loading behavior.
- Promoted `Assert-ModuleAvailable` as primary function name and kept `Ensure-Module` alias for backward compatibility.

### Added
- `src/` modular component architecture (`01-Bootstrap.ps1` through `32-CodeSigning.ps1`).
- `tests/` Pester suite:
  - `Profile.Parse.Tests.ps1`
  - `Profile.Functions.Tests.ps1`
  - `Profile.Config.Tests.ps1`
  - `Profile.Components.Tests.ps1`
- Repository infrastructure files:
  - `.gitignore`, `.editorconfig`, `.gitattributes`
  - `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`
  - `.github/workflows/lint.yml`
  - `.github/ISSUE_TEMPLATE/bug_report.md`
  - `.github/ISSUE_TEMPLATE/feature_request.md`

### Notes
- `profile.ps1` remains conda bootstrap only.
- Optional integrations continue to fail soft when dependencies are unavailable.
