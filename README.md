<div align="center">

<!-- Hero Banner -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:5391FE,100:00B4D8&height=200&section=header&text=PowerShell%20Pro%20Profile&fontSize=48&fontColor=ffffff&fontAlignY=38&desc=Enterprise-grade%20%E2%80%A2%20Modular%20%E2%80%A2%20Cross-platform%20%E2%80%A2%20Blazing-fast&descSize=18&descAlignY=58&animation=fadeIn" width="100%" alt="PowerShell Pro Profile"/>

<!-- Badge Row -->
<p>
  <img src="https://img.shields.io/badge/PowerShell-7.5%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell 7.5+"/>
  <img src="https://img.shields.io/badge/Version-3.1.0-00B4D8?style=for-the-badge&logo=v&logoColor=white" alt="v3.1.0"/>
  <img src="https://img.shields.io/github/actions/workflow/status/DrMaig/PowerShell/lint.yml?style=for-the-badge&label=CI&logo=github-actions&logoColor=white" alt="CI"/>
  <img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge&logo=open-source-initiative&logoColor=white" alt="MIT License"/>
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-8b5cf6?style=for-the-badge&logo=windows&logoColor=white" alt="Cross-Platform"/>
  <img src="https://img.shields.io/github/stars/DrMaig/PowerShell?style=for-the-badge&logo=github&color=f59e0b" alt="GitHub Stars"/>
</p>

<!-- Tagline -->
<h3>⚡ The terminal experience your productivity deserves.</h3>
<p><em>150+ commands • 32 plug-and-play modules • sub-500 ms cold start • works everywhere</em></p>

</div>

---

## ✨ What Makes It Different?

<div align="center">

| 🚀 Blazing Fast | 🧩 Fully Modular | 🌍 Cross-Platform | 🔒 Security-First |
|:---:|:---:|:---:|:---:|
| Sub-500 ms cold start with deferred loading & lazy CIM queries | 32 independent components — toggle any feature without touching others | Full feature set on Windows, graceful degradation on Linux & macOS | `SupportsShouldProcess` on every mutating command, zero auto-installs |

| 🤖 AI-Powered Shell | 📦 Universal Package Hub | 🛠️ 150+ Commands | 📊 Real-Time Insights |
|:---:|:---:|:---:|:---:|
| PSReadLine predictive IntelliSense with history + plugin sources | Unified wrappers for 10+ package managers in one interface | System, network, disk, process, event log & more — all built-in | Live CPU, memory, disk I/O, network & threshold alerting |

</div>

---

## 🌟 Feature Showcase

<details open>
<summary><b>⚡ Blazing-Fast Intelligent Startup</b></summary>
<br>

Every millisecond counts. The profile uses a **thin orchestrator** pattern that dot-sources components on demand, defers heavy module loading to the idle engine event, and caches CIM results to avoid repeated WMI round-trips.

```
╔══════════════════════════════════════════════════════════════╗
║     PowerShell 7.5+ Professional Profile v3.1.0              ║
╠══════════════════════════════════════════════════════════════╣
║  Version:        3.1.0                                        ║
║  Load Time:      347 ms                                       ║
║  Admin:          No                                           ║
║  Modules Loaded: 4                                            ║
╚══════════════════════════════════════════════════════════════╝

  Quick Tips:
    • 'helpme'  – command reference          F1 – help on current cmd
    • 'diag'    – profile diagnostics        F2 – toggle predictions
    • 'sysinfo' – system information      Tab – completion menu
```

- **Modular dot-sourcing** — only load what you enable
- **`Register-EngineEvent PowerShell.OnIdle`** deferred module loader (no blocking `Start-Job`)
- **Lazy CIM query cache** — `Invoke-SafeCimQuery` with `$script:CimQueryCache`
- **Per-component `Stopwatch` timing** — see exactly which component costs what
- **`$Global:ProfileStats.ComponentLoadTimes`** — introspect load performance at any time

</details>

<details>
<summary><b>🖥️ System Administration & Hardware Diagnostics</b></summary>
<br>

Full hardware introspection via CIM/WMI, with `$IsWindows` guards so every function degrades gracefully on Linux/macOS.

| Command | Description |
|---|---|
| `Get-SystemInfo` | Complete OS + hardware summary |
| `Get-CPUInfo` | Processor details, cores, clock speed |
| `Get-MemoryInfo` | RAM slots, capacity, speed |
| `Get-GPUInfo` | GPU name, VRAM, driver version |
| `Get-DiskInfo` | All logical & physical drives |
| `Get-BIOSInfo` | BIOS version, vendor, release date |
| `Get-BatteryHealth` | Battery status, charge level, health |
| `Get-SmartDiskHealth` | S.M.A.R.T. disk health status |
| `Get-SystemHealth` | Aggregated system health score |
| `Get-Uptime` | Current session and last boot time |
| `Get-HardwareSummary` | One-shot hardware overview table |

```powershell
PS> sysinfo          # alias → Get-SystemInfo | Format-List
PS> Get-HardwareSummary
PS> Get-BatteryHealth
PS> Get-SmartDiskHealth
```

</details>

<details>
<summary><b>🌐 Network & DNS Command Center</b></summary>
<br>

Complete network toolbox covering connectivity testing, DNS management, route tracing, port scanning, and NIC statistics — all from the terminal.

| Command | Description | Example |
|---|---|---|
| `Test-TcpPort` | TCP connectivity check | `Test-TcpPort -ComputerName github.com -Port 443` |
| `Test-Internet` | Full Internet connectivity test | `Test-Internet` |
| `Get-PublicIP` | External IP via API | `Get-PublicIP` |
| `Get-LocalIP` | Local IP on all adapters | `Get-LocalIP` |
| `Get-NetworkSnapshot` | Full network state snapshot | `Get-NetworkSnapshot` |
| `Get-NetworkAdapters` | Adapter list with MAC, speed | `Get-NetworkAdapters` |
| `Get-NicStatistics` | Bytes/packets per NIC | `Get-NicStatistics` |
| `Get-ArpTable` | ARP cache table | `Get-ArpTable` |
| `Get-LinkSpeed` | Adapter link speed | `Get-LinkSpeed` |
| `Test-DnsResolution` | DNS resolution test | `Test-DnsResolution -Hostname github.com` |
| `Get-DnsConfig` | Current DNS config | `Get-DnsConfig` |
| `Clear-DnsCache` | Flush DNS resolver cache | `Clear-DnsCache` |
| `Set-DnsProfile` | Apply a preset DNS profile | `Set-DnsProfile -Profile Cloudflare` |
| `Invoke-Traceroute` | Trace route to host | `Invoke-Traceroute -Target 1.1.1.1` |
| `Invoke-PortScan` | Scan ports on a host | `Invoke-PortScan -Target 192.168.1.1` |

**Built-in DNS presets:** `Cloudflare` · `Google` · `Quad9` · `OpenDNS` · `AdGuard`

```powershell
PS> Set-DnsProfile -Profile Cloudflare   # switch to 1.1.1.1
PS> netinfo                              # alias → Get-NetworkSnapshot
PS> ipinfo                               # alias → Get-LocalIP
```

</details>

<details>
<summary><b>📊 Performance Monitoring & Benchmarking</b></summary>
<br>

Real-time performance snapshots, process ranking, and custom benchmarking — no third-party tools required.

| Command | Description | Example |
|---|---|---|
| `Get-PerfSnapshot` | CPU, RAM, disk I/O snapshot | `Get-PerfSnapshot` |
| `Get-TopProcesses` | Top processes ranked by metric | `Get-TopProcesses -By CPU -Top 10` |
| `Measure-Benchmark` | Benchmark a script block | `Measure-Benchmark -ScriptBlock { ls } -Iterations 100` |
| `Test-ThresholdAlerts` | Check against configured thresholds | `Test-ThresholdAlerts` |

```powershell
PS> top        # alias → Get-TopProcesses | Format-Table -AutoSize
PS> topcpu     # CPU-ranked processes
PS> topio      # I/O-ranked processes (Windows) / Memory on Unix
PS> benchmark { Get-Process }
```

</details>

<details>
<summary><b>🔧 Windows Optimization Suite</b></summary>
<br>

Safe, reversible system tuning with full `SupportsShouldProcess` and `ConfirmImpact = 'High'` on destructive operations.

| Command | Description |
|---|---|
| `Optimize-System` | Run full optimization plan (`-WhatIf` safe) |
| `Invoke-WinOptimization` | Apply specific optimization tasks |
| `Undo-WinOptimization` | Revert previously applied changes |
| `Set-PowerPlan` | Switch Windows power plan |
| `Get-PowerPlan` | Show current power plan |
| `Invoke-DiskMaintenance` | Defrag / optimize volumes |
| `Clear-TempFiles` | Remove temp files (`-WhatIf` safe) |
| `Get-WinOptimizationPlan` | Preview what will be changed |
| `Get-WinOptimizationState` | View current optimization state |

```powershell
PS> Optimize-System -WhatIf         # preview changes
PS> Optimize-System -Confirm        # apply with confirmation
PS> Undo-WinOptimization            # revert to previous state
```

> **Note:** All Windows-only functions return informative warnings on Linux/macOS instead of errors.

</details>

<details>
<summary><b>🤖 AI-Powered Smart Terminal (PSReadLine)</b></summary>
<br>

Configured for PowerShell 7.5+ with the most productive key-bindings and prediction modes.

- **Predictive IntelliSense** — `HistoryAndPlugin` prediction source showing inline ghost text
- **Smart auto-pairing** — quotes and braces automatically paired and skipped
- **ListView mode** — `F2` to toggle between inline and list prediction
- **History-aware completions** — 10,000-entry persistent history
- **Custom key handlers:**

| Key | Action |
|---|---|
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Alt+A` | Select command argument |
| `F1` | Open help for current command |
| `F2` | Toggle prediction view (inline ↔ list) |
| `Tab` | Open completion menu |

</details>

<details>
<summary><b>🎨 Tab Completion for 20+ Tools</b></summary>
<br>

Native argument completers registered for all major CLI tools — no additional modules needed.

<div align="center">

| 📦 Package Managers | 🐳 Containers & Cloud | 🔨 Dev Tools | 🖥️ System |
|:---:|:---:|:---:|:---:|
| `winget` | `docker` | `git` | `pwsh` |
| `choco` | `kubectl` | `gh` | `dotnet` |
| `scoop` | `terraform` | `cargo` | `npm` |
| `pip` | `aws` | `node` | `pnpm` |
| — | `az` | `yarn` | — |

</div>

```powershell
PS> winget ins<Tab>          # → install, …
PS> docker run --<Tab>       # → --name, --rm, --env, …
PS> git che<Tab>             # → checkout, cherry-pick, …
```

</details>

<details>
<summary><b>📦 Universal Package Management Hub</b></summary>
<br>

One interface to rule them all — unified wrappers for every major package manager.

| Command | Description | Example |
|---|---|---|
| `Install-DevPackage` | Install via any manager | `Install-DevPackage -Manager winget -Package git.git` |
| `Update-AllPackages` | Update all managers at once | `Update-AllPackages -Manager all` |
| `Get-PackageManagerStatus` | Health check all managers | `Get-PackageManagerStatus` |
| `Get-WingetPackage` | List winget packages | `Get-WingetPackage` |
| `Get-ChocoPackage` | List choco packages | `Get-ChocoPackage` |
| `Get-NpmPackage` | List npm globals | `Get-NpmPackage` |
| `Get-PipPackage` | List pip packages | `Get-PipPackage` |
| `Get-ScoopPackage` | List scoop packages | `Get-ScoopPackage` |
| `Get-DotnetInfo` | .NET SDK/runtime info | `Get-DotnetInfo` |
| `Install-DotnetTool` | Install a .NET global tool | `Install-DotnetTool -Tool roslynator` |

**Supported managers:** `winget` · `chocolatey` · `scoop` · `npm` · `pnpm` · `yarn` · `pip` · `pipx` · `dotnet` · `cargo` · `nuget`

</details>

<details>
<summary><b>🔒 Security & Code Signing</b></summary>
<br>

Security is built-in, not bolted on.

- **`SupportsShouldProcess`** — every mutating command supports `-WhatIf` and `-Confirm`
- **`ConfirmImpact = 'High'`** — destructive operations (`Optimize-System`, `Clear-TempFiles`) require explicit confirmation
- **`Test-Admin`** — detect elevated sessions; gate privileged commands automatically
- **`Test-ProfileInteractive`** — prevent setup prompts in non-interactive contexts (CI, scripts)
- **`Sign-ProfileScript`** — sign profile components with an Authenticode certificate
- **Zero auto-installs on startup** — the profile never silently modifies your system at load time

```powershell
PS> Test-Admin                    # → True if elevated
PS> Sign-ProfileScript -WhatIf    # preview signing
```

</details>

<details>
<summary><b>📊 Process, Service & Driver Management</b></summary>
<br>

| Command | Description |
|---|---|
| `Get-TopProcesses` | Top processes by CPU/RAM/IO |
| `Get-ProcessTree` | Parent/child process tree (single bulk CIM query) |
| `Stop-ProcessByName` | Stop by name with confirmation |
| `Get-ServiceHealth` | Service status overview |
| `Restart-ServiceByName` | Restart a named service |
| `Get-ScheduledTasksSummary` | Scheduled task overview |
| `Get-DriverInfo` | Driver list with version |
| `Find-DuplicateDrivers` | Detect duplicate driver entries |
| `Get-InstalledSoftware` | Full installed software list |

</details>

<details>
<summary><b>📝 Structured Logging & Diagnostics</b></summary>
<br>

Production-grade logging built directly into the profile.

| Command | Description |
|---|---|
| `Write-ProfileLog` | Write a structured log entry (DEBUG/INFO/WARN/ERROR) |
| `Get-ProfileLog` | Read recent log entries |
| `Invoke-ProfileLogRotation` | Rotate log files |
| `Test-ProfileHealth` | Full profile health check |
| `Repair-Profile` | Auto-repair common profile issues |
| `Show-ProfileDiagnostics` | Full diagnostics dashboard |
| `Show-EnvironmentReport` | Environment overview |
| `Invoke-ProfileLint` | Lint all profile components with PSScriptAnalyzer |
| `Invoke-ProfilePesterTests` | Run full Pester test suite |
| `Test-ProfileScript` | Parse-check all components |
| `Export-SystemSnapshot` | Export full diagnostics bundle to JSON |

```powershell
PS> diag      # alias → Show-ProfileDiagnostics
PS> repair    # alias → Repair-Profile
PS> health    # alias → Get-SystemHealth | Format-List
```

</details>

<details>
<summary><b>📋 Event Log Analysis</b></summary>
<br>

| Command | Description | Example |
|---|---|---|
| `Get-RecentEvents` | Recent event log entries | `Get-RecentEvents -LogName System -MaxEvents 50` |
| `Export-EventLogToJson` | Export event log to JSON file | `Export-EventLogToJson -LogName Application` |
| `Get-EventLogSummary` | Summary statistics per event source | `Get-EventLogSummary` |

</details>

<details>
<summary><b>🖧 Remote Management</b></summary>
<br>

| Command | Description | Example |
|---|---|---|
| `Test-RemoteHost` | Ping / WMI reachability test | `Test-RemoteHost -ComputerName srv01` |
| `Connect-RemoteHost` | Enter PSSession to remote host | `Connect-RemoteHost -ComputerName srv01` |
| `Invoke-RemoteCommand` | Run a script block remotely | `Invoke-RemoteCommand -ComputerName srv01 -ScriptBlock { hostname }` |
| `Get-RemoteSessions` | List open PSSessions | `Get-RemoteSessions` |
| `Remove-AllRemoteSessions` | Disconnect all PSSessions | `Remove-AllRemoteSessions` |

</details>

<details>
<summary><b>🎯 Productivity & Discoverability</b></summary>
<br>

Never forget a command again.

| Command | Description | Example |
|---|---|---|
| `Show-CommandPalette` | Browse all commands by category | `Show-CommandPalette -Category Network` |
| `Find-ProfileCommand` | Fuzzy-search functions & aliases | `Find-ProfileCommand 'dns'` |
| `Get-ContextSuggestions` | Context-aware command suggestions | `Get-ContextSuggestions` |
| `helpme` | Quick reference card | `helpme` |

**Categories:** `System` · `Network` · `Package` · `Diagnostic` · `Process` · `Disk` · `Security` · `Monitor`

</details>

<details>
<summary><b>⌨️ 60+ Power Aliases</b></summary>
<br>

Fluent shortcuts for every common operation:

```powershell
# Navigation
..        cd ..        ...       cd ../..
~         cd ~         cd..      cd ..

# System info
sysinfo   Get-SystemInfo | Format-List
meminfo   Get-MemoryInfo | Format-List
cpuinfo   Get-CPUInfo | Format-List
diskinfo  Get-DiskInfo | Format-Table
gpuinfo   Get-GPUInfo | Format-Table
biosinfo  Get-BIOSInfo | Format-List

# Network
netinfo   Get-NetworkSnapshot | Format-List
ipinfo    Get-LocalIP
pubip     Get-PublicIP
flushdns  Clear-DnsCache

# Processes
top       Get-TopProcesses | Format-Table -AutoSize
topcpu    Get-TopProcesses -By CPU | Format-Table -AutoSize
topio     Get-TopProcesses -By IO | Format-Table -AutoSize

# Files
ll        Get-ChildItem
la        Get-ChildItem -Force   (shows hidden)
l         Get-ChildItem
du        Get-DiskUsage
largefiles Find-LargeFiles

# Diagnostics
diag      Show-ProfileDiagnostics
repair    Repair-Profile
health    Get-SystemHealth | Format-List
optimize  Optimize-System
helpme    (quick reference card)

# Utilities
grep      Select-String
which     Get-Command
touch     New-Item or update LastWriteTime
edit      Open file in $ProfileConfig.Editor
code.     code .
```

> On **Windows**: `sudo` → `Start-Process pwsh -Verb runAs`, `nano` → `notepad`
> On **Linux/macOS**: native `sudo` and `nano` are preserved untouched.

</details>

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Details |
|---|---|
| **PowerShell** | 7.5+ — [Download](https://github.com/PowerShell/PowerShell/releases) |
| **oh-my-posh** *(optional)* | Custom prompt themes — `winget install JanDeDobbeleer.OhMyPosh` |
| **Terminal-Icons** *(optional)* | File icons in listings — `Install-Module Terminal-Icons` |
| **posh-git** *(optional)* | Git branch in prompt — `Install-Module posh-git` |
| **PSScriptAnalyzer** *(optional)* | Linting support — `Install-Module PSScriptAnalyzer` |
| **Pester** *(optional)* | Test runner — `Install-Module Pester -MinimumVersion 5.0` |

### Installation

**Option A — Clone directly into the PowerShell Documents folder:**

```powershell
git clone https://github.com/DrMaig/PowerShell.git "$HOME/Documents/PowerShell"
```

**Option B — Clone anywhere, then symlink:**

```powershell
git clone https://github.com/DrMaig/PowerShell.git "C:/Dev/PowerShell-Profile"
New-Item -ItemType SymbolicLink `
         -Path "$HOME/Documents/PowerShell" `
         -Target "C:/Dev/PowerShell-Profile"
```

**Option C — Linux / macOS:**

```bash
git clone https://github.com/DrMaig/PowerShell.git ~/.config/powershell
```

### First Run

Restart your terminal (or `pwsh`) — you'll be greeted with the welcome banner. Then verify:

```powershell
Show-EnvironmentReport    # full environment overview
Test-ProfileHealth        # profile self-check
Show-CommandPalette       # browse all available commands
```

---

## ⚙️ Configuration

The profile is driven by `powershell.config.json` (committed, version-controlled) merged over `$Global:ProfileConfig` defaults at startup.

### `powershell.config.json` — key knobs

```jsonc
{
  "Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned",
  "StartupMode": "full",       // "full" | "minimal"
  "LoggingEnabled": true,
  "Features": {
    "UsePSReadLine": true,
    "UseOhMyPosh": true,
    "UseCompletions": true,
    "UseDeferredModuleLoader": true,
    "UseWelcomeScreen": true
  },
  "User": {
    "Name": "YourName",
    "Editor": "code"            // or "notepad", "vim", etc.
  },
  "Modules": {
    "ImportOnStartup": [
      "Microsoft.PowerShell.PSReadLine",
      "Oh-my-posh"
    ]
  }
}
```

### Runtime config via `$Global:ProfileConfig`

```powershell
# Inspect current config
$Global:ProfileConfig

# Check what loaded and how long it took
$Global:ProfileStats.ComponentLoadTimes

# Disable welcome screen for this session
$Global:ProfileConfig.ShowWelcome = $false
```

### Disabling individual components

Remove or comment out a component name from `$script:ComponentOrder` in `Microsoft.PowerShell_profile.ps1`. All remaining components continue to load independently.

---

## 🏗️ Architecture

```
Microsoft.PowerShell_profile.ps1   ← thin orchestrator (VS Code integration, timer, dot-source loop)
│
├── src/01-Bootstrap.ps1           ← runtime guards, PS version check
├── src/02-Config.ps1              ← defaults, JSON merge, $Global:ProfileConfig
├── src/03-Logging.ps1             ← Write-ProfileLog, rotation, Write-CaughtException
├── src/04-Environment.ps1         ← Test-Admin, Test-ProfileInteractive, path setup
├── src/05-PSReadLine.ps1          ← IntelliSense, key bindings, history
├── src/06-ModuleManagement.ps1    ← deferred loader, Assert-ModuleAvailable
├── src/07-SystemAdmin.ps1         ← CIM-based hardware & OS functions
├── src/08-Performance.ps1         ← PerfSnapshot, TopProcesses, Benchmark
├── src/09-Network.ps1             ← TCP, IP, NIC, ARP, snapshot
├── src/10-DnsProfiles.ps1         ← DNS preset profiles
├── src/11-WinOptimization.ps1     ← Optimize-System, power plans, disk
├── src/12-Diagnostics.ps1         ← ProfileHealth, Repair, Diagnostics
├── src/13-ProcessService.ps1      ← processes, services, scheduled tasks
├── src/14-DriverSoftware.ps1      ← driver info, duplicate detection
├── src/15-Updates.ps1             ← Windows Update, WinGet outdated
├── src/16-FileUtils.ps1           ← DiskUsage, FindLargeFiles, ClearTemp
├── src/17-Prompt.ps1              ← oh-my-posh init, posh-git, custom prompt
├── src/18-PackageManagers.ps1     ← unified package manager wrappers
├── src/19-Completions.ps1         ← argument completers for 20+ CLI tools
├── src/20-Aliases.ps1             ← 60+ shortcuts and navigation helpers
├── src/21-NativeCompleters.ps1    ← Initialize-NativeToolCompleters
├── src/22-Welcome.ps1             ← Show-WelcomeScreen, Show-ProfileSummary
├── src/23-ExitHandlers.ps1        ← Register-ExitAction, cleanup on exit
├── src/24-HardwareDiag.ps1        ← battery, SMART disk, GPU details
├── src/25-NetToolkit.ps1          ← traceroute, port scan, link speed
├── src/26-EventLog.ps1            ← event log read/export/summary
├── src/27-Remoting.ps1            ← PSSession helpers
├── src/28-Monitoring.ps1          ← threshold alerts, monitor log
├── src/29-Productivity.ps1        ← CommandPalette, FindCommand, suggestions
├── src/30-Snapshot.ps1            ← Export-SystemSnapshot (JSON bundle)
├── src/31-Linting.ps1             ← Invoke-ProfileLint, PSScriptAnalyzer
└── src/32-CodeSigning.ps1         ← Sign-ProfileScript, Authenticode
```

**Startup flow:**

```
Bootstrap → Config → Logging → Environment → PSReadLine → ModuleManagement
→ SystemAdmin → Performance → Network → DNS → WinOpt → Diagnostics
→ Process → Drivers → Updates → FileUtils → Prompt → Packages → Completions
→ Aliases → NativeCompleters → Welcome → ExitHandlers
→ HardwareDiag → NetToolkit → EventLog → Remoting → Monitoring
→ Productivity → Snapshot → Linting → CodeSigning
```

Each component is timed with a `Stopwatch` and recorded in `$Global:ProfileStats.ComponentLoadTimes`. Failures in any component are caught, logged, and skipped — they never block the profile from loading.

**Extension point:** Create `src/99-Custom.ps1` with your own functions and add `'99-Custom'` to `$script:ComponentOrder`.

---

## 📖 Full Command Reference

<details>
<summary><b>🖥️ System Administration</b></summary>

| Command | Description | Example |
|---|---|---|
| `Get-SystemInfo` | Complete system summary | `Get-SystemInfo` |
| `Get-CPUInfo` | CPU details | `Get-CPUInfo` |
| `Get-MemoryInfo` | RAM capacity & speed | `Get-MemoryInfo` |
| `Get-GPUInfo` | GPU details | `Get-GPUInfo` |
| `Get-DiskInfo` | Disk drive overview | `Get-DiskInfo` |
| `Get-BIOSInfo` | BIOS vendor & version | `Get-BIOSInfo` |
| `Get-SystemHealth` | Health score (CPU/RAM/Disk) | `Get-SystemHealth` |
| `Get-Uptime` | System uptime | `Get-Uptime` |
| `Get-HardwareSummary` | One-shot hardware table | `Get-HardwareSummary` |
| `Get-SmartDiskHealth` | S.M.A.R.T. disk status | `Get-SmartDiskHealth` |
| `Get-BatteryHealth` | Battery level & health | `Get-BatteryHealth` |

</details>

<details>
<summary><b>🌐 Network & DNS</b></summary>

| Command | Description | Example |
|---|---|---|
| `Test-TcpPort` | TCP connectivity | `Test-TcpPort -ComputerName github.com -Port 443` |
| `Test-Internet` | Internet connectivity | `Test-Internet` |
| `Get-PublicIP` | External IP | `Get-PublicIP` |
| `Get-LocalIP` | Local IP addresses | `Get-LocalIP` |
| `Get-NetworkSnapshot` | Full network state | `Get-NetworkSnapshot` |
| `Get-NetworkAdapters` | NIC list | `Get-NetworkAdapters` |
| `Get-NicStatistics` | Bytes/packets per NIC | `Get-NicStatistics` |
| `Get-ArpTable` | ARP cache | `Get-ArpTable` |
| `Get-LinkSpeed` | Adapter link speed | `Get-LinkSpeed` |
| `Test-DnsResolution` | DNS resolution test | `Test-DnsResolution -Hostname github.com` |
| `Get-DnsConfig` | Current DNS servers | `Get-DnsConfig` |
| `Clear-DnsCache` | Flush DNS cache | `Clear-DnsCache` |
| `Set-DnsProfile` | Apply DNS preset | `Set-DnsProfile -Profile Cloudflare` |
| `Invoke-Traceroute` | Trace route | `Invoke-Traceroute -Target 1.1.1.1` |
| `Invoke-PortScan` | Scan ports on host | `Invoke-PortScan -Target 192.168.1.1` |
| `Restart-NetworkAdapter` | Restart NIC | `Restart-NetworkAdapter -WhatIf` |

</details>

<details>
<summary><b>📊 Performance & Monitoring</b></summary>

| Command | Description | Example |
|---|---|---|
| `Get-PerfSnapshot` | CPU/RAM/Disk I/O snapshot | `Get-PerfSnapshot` |
| `Get-TopProcesses` | Top processes by metric | `Get-TopProcesses -By CPU -Top 10` |
| `Measure-Benchmark` | Script block benchmark | `Measure-Benchmark -ScriptBlock { ls } -Iterations 100` |
| `Test-ThresholdAlerts` | Check configured thresholds | `Test-ThresholdAlerts` |
| `Write-MonitorEvent` | Write to monitor log | `Write-MonitorEvent -Message 'Alert' -Level WARN` |
| `Get-MonitorLog` | Read monitor log | `Get-MonitorLog -Tail 50` |

</details>

<details>
<summary><b>🔧 Optimization & Maintenance</b></summary>

| Command | Description | Example |
|---|---|---|
| `Optimize-System` | Full optimization run | `Optimize-System -WhatIf` |
| `Invoke-WinOptimization` | Targeted optimization | `Invoke-WinOptimization` |
| `Undo-WinOptimization` | Revert changes | `Undo-WinOptimization` |
| `Set-PowerPlan` | Change power plan | `Set-PowerPlan -Plan HighPerformance` |
| `Get-PowerPlan` | Current power plan | `Get-PowerPlan` |
| `Invoke-DiskMaintenance` | Defrag/optimize volume | `Invoke-DiskMaintenance -DriveLetter C -WhatIf` |
| `Clear-TempFiles` | Delete temp files | `Clear-TempFiles -WhatIf` |
| `Get-WinOptimizationPlan` | Preview optimization plan | `Get-WinOptimizationPlan` |
| `Get-WinOptimizationState` | Saved optimization state | `Get-WinOptimizationState` |

</details>

<details>
<summary><b>📦 Package Management</b></summary>

| Command | Description | Example |
|---|---|---|
| `Install-DevPackage` | Install via named manager | `Install-DevPackage -Manager winget -Package git.git` |
| `Update-AllPackages` | Update all managers | `Update-AllPackages -Manager all` |
| `Get-PackageManagerStatus` | Manager health check | `Get-PackageManagerStatus` |
| `Get-WingetPackage` | List winget installs | `Get-WingetPackage` |
| `Install-WingetPackage` | Install via winget | `Install-WingetPackage -Package git.git` |
| `Get-WingetOutdated` | Outdated winget packages | `Get-WingetOutdated` |
| `Get-ChocoPackage` | List choco installs | `Get-ChocoPackage` |
| `Install-ChocoPackage` | Install via choco | `Install-ChocoPackage -Package googlechrome` |
| `Get-ScoopPackage` | List scoop installs | `Get-ScoopPackage` |
| `Install-ScoopPackage` | Install via scoop | `Install-ScoopPackage -Package fzf` |
| `Get-NpmPackage` | List npm globals | `Get-NpmPackage` |
| `Install-NpmPackage` | npm global install | `Install-NpmPackage -Package typescript` |
| `Get-PipPackage` | List pip installs | `Get-PipPackage` |
| `Install-PipPackage` | pip install | `Install-PipPackage -Package requests` |
| `Install-PipxPackage` | pipx install | `Install-PipxPackage -Package black` |
| `Get-DotnetInfo` | .NET SDK info | `Get-DotnetInfo` |
| `Install-DotnetTool` | .NET global tool install | `Install-DotnetTool -Tool roslynator` |

</details>

<details>
<summary><b>🗂️ Process, Service & Driver Management</b></summary>

| Command | Description | Example |
|---|---|---|
| `Get-ProcessTree` | Parent/child process tree | `Get-ProcessTree` |
| `Stop-ProcessByName` | Kill process by name | `Stop-ProcessByName -Name notepad` |
| `Get-ServiceHealth` | Service status overview | `Get-ServiceHealth` |
| `Restart-ServiceByName` | Restart a service | `Restart-ServiceByName -Name Spooler` |
| `Get-ScheduledTasksSummary` | Scheduled tasks list | `Get-ScheduledTasksSummary` |
| `Get-DriverInfo` | Driver list | `Get-DriverInfo` |
| `Find-DuplicateDrivers` | Duplicate driver check | `Find-DuplicateDrivers` |
| `Get-InstalledSoftware` | All installed software | `Get-InstalledSoftware` |
| `Get-NodeVersion` | Node.js version info | `Get-NodeVersion` |
| `Get-PythonVersion` | Python version info | `Get-PythonVersion` |

</details>

<details>
<summary><b>📁 File Utilities</b></summary>

| Command | Description | Example |
|---|---|---|
| `Get-DiskUsage` | Folder size summary | `Get-DiskUsage -Path C:\Projects -Top 20` |
| `Find-LargeFiles` | Find files over threshold | `Find-LargeFiles -Path C:\ -SizeMB 100 -Top 20` |
| `Clear-TempFiles` | Remove temp files | `Clear-TempFiles -WhatIf` |
| `Invoke-DiskMaintenance` | Volume maintenance | `Invoke-DiskMaintenance -DriveLetter C` |
| `touch` | Create file / update timestamp | `touch newfile.txt` |

</details>

<details>
<summary><b>🔒 Security, Diagnostics, Remote & Events</b></summary>

| Command | Description | Example |
|---|---|---|
| `Test-Admin` | Check if elevated | `Test-Admin` |
| `Test-ProfileHealth` | Full profile health check | `Test-ProfileHealth` |
| `Repair-Profile` | Auto-repair profile issues | `Repair-Profile` |
| `Reset-ProfileToDefaults` | Reset config to defaults | `Reset-ProfileToDefaults -WhatIf` |
| `Show-ProfileDiagnostics` | Full diagnostics view | `Show-ProfileDiagnostics` |
| `Show-EnvironmentReport` | Environment overview | `Show-EnvironmentReport` |
| `Export-SystemSnapshot` | JSON diagnostics bundle | `Export-SystemSnapshot -WhatIf` |
| `Invoke-ProfileLint` | Lint with PSScriptAnalyzer | `Invoke-ProfileLint` |
| `Invoke-ProfilePesterTests` | Run Pester test suite | `Invoke-ProfilePesterTests` |
| `Test-ProfileScript` | Parse-check components | `Test-ProfileScript` |
| `Sign-ProfileScript` | Sign with Authenticode | `Sign-ProfileScript -WhatIf` |
| `Test-RemoteHost` | WMI reachability | `Test-RemoteHost -ComputerName srv01` |
| `Connect-RemoteHost` | Enter PSSession | `Connect-RemoteHost -ComputerName srv01` |
| `Invoke-RemoteCommand` | Run script remotely | `Invoke-RemoteCommand -ComputerName srv01 -ScriptBlock { hostname }` |
| `Get-RemoteSessions` | List open PSSessions | `Get-RemoteSessions` |
| `Remove-AllRemoteSessions` | Disconnect all sessions | `Remove-AllRemoteSessions` |
| `Get-RecentEvents` | Event log entries | `Get-RecentEvents -LogName System -MaxEvents 50` |
| `Export-EventLogToJson` | Export events to JSON | `Export-EventLogToJson -LogName Application` |
| `Get-EventLogSummary` | Event source statistics | `Get-EventLogSummary` |

</details>

---

## 🧪 Testing

The profile ships with a complete test suite using Pester 5+.

```powershell
# Run from within a PowerShell session with the profile loaded
Invoke-ProfilePesterTests      # full Pester suite via wrapper
Test-ProfileScript             # parse-check all 32 components
Invoke-ProfileLint             # PSScriptAnalyzer with repo settings

# Or run the modular tests/ suite directly
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester ./tests -Output Detailed"

# CI-equivalent quality gate
pwsh -NoProfile -File .\Scripts\run_pester.ps1
```

**Test suite structure:**

| File | Coverage |
|---|---|
| `Microsoft.PowerShell_profile.Tests.ps1` | Root smoke tests |
| `tests/Profile.Parse.Tests.ps1` | Syntax / parser validation for all 32 components |
| `tests/Profile.Functions.Tests.ps1` | Function existence and parameter checks |
| `tests/Profile.Config.Tests.ps1` | Config defaults and JSON schema |
| `tests/Profile.Components.Tests.ps1` | Component load order and timing |

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

**Quick flow:**

```
Fork → Create branch → Make changes → Run tests → Open PR
```

```powershell
# Validate your changes before pushing
Test-ProfileScript       # parse check
Invoke-ProfileLint       # analyzer
Invoke-ProfilePesterTests  # full test suite
```

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

Built on the shoulders of giants:

<div align="center">

| Project | Role |
|:---:|:---:|
| [oh-my-posh](https://ohmyposh.dev/) | Beautiful cross-platform prompts |
| [PSReadLine](https://github.com/PowerShell/PSReadLine) | Predictive IntelliSense & key bindings |
| [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) | File & folder icons in the terminal |
| [posh-git](https://github.com/dahlbyk/posh-git) | Git status in the prompt |
| [PowerShell](https://github.com/PowerShell/PowerShell) | The platform itself |

</div>

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:5391FE,100:00B4D8&height=100&section=footer" width="100%" alt="footer"/>

**⭐ If this profile makes your terminal life better, consider starring the repo!**

[![GitHub stars](https://img.shields.io/github/stars/DrMaig/PowerShell?style=for-the-badge&logo=github&color=f59e0b)](https://github.com/DrMaig/PowerShell/stargazers)

*Made with ❤️ for the PowerShell community*

</div>
