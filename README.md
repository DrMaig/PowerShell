<!-- logo -->

# ⚡ PowerShell Pro Profile

*Enterprise-grade modular PowerShell profile — loads in under 500ms, works everywhere, and makes your terminal brilliant.*

![PowerShell 7.5+](https://img.shields.io/badge/PowerShell-7.5%2B-5391FE?logo=powershell&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![CI](https://img.shields.io/github/actions/workflow/status/DrMaig/PowerShell/lint.yml?label=CI)
![Platforms](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)
![GitHub stars](https://img.shields.io/github/stars/DrMaig/PowerShell?style=social)

## Why This Profile?

- ⚡ **Blazing-fast startup** via modular dot-sourcing, deferred module loading, lazy CIM queries, and per-component timing
- 🧩 **32 modular components** — enable, disable, or customize any feature independently
- 🖥️ **100+ built-in commands** for system admin, networking, diagnostics, package management, and productivity
- 🌍 **Cross-platform ready** — full feature set on Windows, graceful degradation on Linux/macOS

## ✨ Feature Showcase

### 🚀 Instant Startup
- Modular dot-sourcing orchestration
- Deferred module loading
- Lazy CIM queries
- Cached module resolution
- Per-component timing capture

### 🖥️ System Administration
`Get-SystemInfo`, `Get-DiskInfo`, `Get-MemoryInfo`, `Get-CPUInfo`, `Get-GPUInfo`, `Get-BIOSInfo`, `Get-SystemHealth`, `Get-Uptime`, `Get-HardwareSummary`, `Get-SmartDiskHealth`, `Get-BatteryHealth`

### 🌐 Network & DNS Management
`Test-TcpPort`, `Get-PublicIP`, `Get-LocalIP`, `Set-DnsProfile`, `Use-CloudflareDns`, `Use-GoogleDns`, `Use-Quad9Dns`, `Use-OpenDns`, `Use-AdGuardDns`, `Test-Internet`, `Get-NetworkSnapshot`, `Invoke-Traceroute`, `Invoke-PortScan`, `Test-DnsResolution`, `Get-ArpTable`, `Get-NicStatistics`

### 📊 Performance Monitoring
`Get-PerfSnapshot`, `Get-TopProcesses`, `Measure-Benchmark`, `Test-ThresholdAlerts`

### 🔧 Windows Optimization
`Optimize-System`, `Set-PowerPlan`, `Invoke-DiskMaintenance`, `Clear-TempFiles`

### 🧠 Smart Terminal
- PSReadLine predictive IntelliSense
- Smart paired quotes/braces
- 20+ native tool completions (winget/choco/scoop/npm/pip/docker/kubectl/terraform/aws/az/git/gh/cargo/...)
- oh-my-posh prompt integration (optional)

### 📦 Package Management
Unified wrappers for winget, chocolatey, scoop, npm, pnpm, yarn, pip, pipx, dotnet, cargo, nuget with `Install-DevPackage` and `Update-AllPackages`.

### 🔒 Security-First
- `SupportsShouldProcess` on mutating operations
- No automatic install/update on startup
- Admin/session context detection
- Code signing helper support

### 📝 Logging & Diagnostics
Structured log levels, rotation, JSON monitoring entries, `Export-SystemSnapshot`, `Test-ProfileHealth`, `Invoke-ProfileLint`.

### 🌍 Cross-Platform
Windows/Linux/macOS adaptive behavior with platform guards and graceful degradation.

All Windows-only functions (CIM-based system admin, performance counters, services,
code signing, disk maintenance) include `$IsWindows` guards and return informative
warnings on non-Windows platforms. Core utilities (networking, benchmarking, file
operations, package management) work cross-platform.

### 🖧 Remote Management
`Test-RemoteHost`, `Connect-RemoteHost`, `Invoke-RemoteCommand` with credential prompts and session cleanup.

### 📋 Event Log Analysis
`Get-RecentEvents`, `Export-EventLogToJson`, `Get-EventLogSummary`.

## 🚀 Quick Start

Prerequisites: PowerShell 7.5+ (https://github.com/PowerShell/PowerShell/releases)
Optional: oh-my-posh, Terminal-Icons, posh-git, PSScriptAnalyzer, Pester

```powershell
git clone https://github.com/DrMaig/PowerShell.git "$HOME/Documents/PowerShell"
# or symlink if already cloned elsewhere
New-Item -ItemType SymbolicLink -Path "$HOME/Documents/PowerShell" -Target "<clone-path>"
# restart terminal, then verify
Show-EnvironmentReport
```

## ⚙️ Configuration

Use `$Global:ProfileConfig` and `powershell.config.json` to tune behavior:

- `StartupMode`: `minimal` or `full`
- feature flags under `Features`
- integration toggles under component-specific config blocks

Disable components by toggling feature flags or removing entries from the orchestrator component list in `Microsoft.PowerShell_profile.ps1`.

## 📖 Command Reference

<details>
<summary>🖥️ System Administration</summary>

| Command | Description | Example |
|---|---|---|
| `Get-SystemInfo` | System summary | `Get-SystemInfo` |
| `Get-DiskInfo` | Disk overview | `Get-DiskInfo` |
| `Get-HardwareSummary` | Hardware summary | `Get-HardwareSummary` |

</details>

<details>
<summary>🌐 Network & DNS</summary>

| Command | Description | Example |
|---|---|---|
| `Test-TcpPort` | Check TCP connectivity | `Test-TcpPort -ComputerName github.com -Port 443` |
| `Set-DnsProfile` | Apply DNS profile | `Set-DnsProfile -Profile Cloudflare` |
| `Invoke-Traceroute` | Trace route to host | `Invoke-Traceroute -Target 1.1.1.1` |

</details>

<details>
<summary>📊 Performance Monitoring</summary>

| Command | Description | Example |
|---|---|---|
| `Get-PerfSnapshot` | Performance snapshot | `Get-PerfSnapshot` |
| `Get-TopProcesses` | Top processes by metric | `Get-TopProcesses -Top 10` |
| `Measure-Benchmark` | Benchmark script block | `Measure-Benchmark -ScriptBlock { Get-Process }` |

</details>

<details>
<summary>🔧 Optimization / Maintenance</summary>

| Command | Description | Example |
|---|---|---|
| `Optimize-System` | Run optimization tasks | `Optimize-System -WhatIf` |
| `Invoke-DiskMaintenance` | Disk maintenance actions | `Invoke-DiskMaintenance -DriveLetter C -WhatIf` |
| `Clear-TempFiles` | Cleanup temp files | `Clear-TempFiles -WhatIf` |

</details>

<details>
<summary>📦 Package Management</summary>

| Command | Description | Example |
|---|---|---|
| `Install-DevPackage` | Install package via manager | `Install-DevPackage -Manager winget -Package git.git` |
| `Update-AllPackages` | Update packages across managers | `Update-AllPackages -Manager all` |
| `Get-PackageManagerStatus` | Package manager health | `Get-PackageManagerStatus` |

</details>

<details>
<summary>🔒 Security, Diagnostics, Remote, Events</summary>

| Command | Description | Example |
|---|---|---|
| `Test-ProfileHealth` | Profile health checks | `Test-ProfileHealth` |
| `Export-SystemSnapshot` | Export diagnostics snapshot | `Export-SystemSnapshot -WhatIf` |
| `Invoke-RemoteCommand` | Execute remote command | `Invoke-RemoteCommand -ComputerName srv01 -ScriptBlock { hostname }` |
| `Get-RecentEvents` | Recent event log entries | `Get-RecentEvents -LogName System -MaxEvents 50` |

</details>

## 🏗️ Architecture

- `Microsoft.PowerShell_profile.ps1` is a thin orchestrator.
- Components live in `src/` (`01-Bootstrap.ps1` ... `32-CodeSigning.ps1`).
- Startup flow: **Bootstrap → Config → Logging → Environment → PSReadLine → Modules → ... → Welcome → Exit Handlers**.
- Component timing is captured per file load.
- Extension point: add your own `src/99-Custom.ps1` and include it in orchestrator order.

## 🧪 Testing

```powershell
Invoke-ProfilePesterTests
Test-ProfileScript
Invoke-ProfileLint
```

Or run CI-equivalent tests:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester ./tests -Output Detailed"
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Quick flow: **fork → branch → code → test → PR**.

## 📄 License

MIT — see [LICENSE](LICENSE).

## 🙏 Acknowledgments

Thanks to the teams and communities behind:
- [oh-my-posh](https://ohmyposh.dev/)
- [PSReadLine](https://github.com/PowerShell/PSReadLine)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
- [PowerShell](https://github.com/PowerShell/PowerShell)
- The wider PowerShell community
