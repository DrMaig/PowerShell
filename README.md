# PowerShell Profile

An enterprise-grade PowerShell 7.5+ profile for Windows 10/11 Pro x64 with comprehensive system administration, automation, security, diagnostics, and optimization features.

## Requirements

- PowerShell 7.5+ (64-bit)
- Windows 10/11 Pro x64

## Installation

Copy `Microsoft.PowerShell_profile.ps1` to your PowerShell profile location:

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE
```

## Features

| Region | Description |
|--------|-------------|
| 1  | Bootstrap and runtime guards |
| 2  | Platform detection and global flags |
| 3  | Logging and telemetry framework |
| 4  | Environment validation and utility functions |
| 5  | PSReadLine configuration with predictive IntelliSense |
| 6  | Module management with deferred loading |
| 7  | System administration (hardware, OS, BIOS) |
| 8  | Performance monitoring and benchmarking |
| 9  | Network management and DNS functions |
| 10 | DNS profiles and quick switching |
| 11 | Windows optimization and maintenance |
| 12 | Self-diagnostics and troubleshooting |
| 13 | Process and service management |
| 14 | Driver and software management |
| 15 | System update functions |
| 16 | File and disk utilities |
| 17 | Prompt customization and shell enhancements |
| 18 | Package managers and framework management |
| 19 | Tool integrations and code completions |
| 20 | Aliases and shortcuts |
| 21 | Native tool completers and shims |
| 22 | Welcome screen and finalization |
| 23 | Exit handlers and cleanup |
| 24 | Hardware diagnostics |
| 25 | Network toolkit |
| 26 | Event and log helpers |
| 27 | Secure remote management |
| 28 | Monitoring and alerting hooks |
| 29 | Interactive productivity helpers |
| 30 | Diagnostics automation |
| 31 | Testing and linting integration |
| 32 | Code signing guidance |

## Optional Integrations

- [Oh-My-Posh](https://ohmyposh.dev/) — prompt theming
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) — file icons in the terminal
- [posh-git](https://github.com/dahlbyk/posh-git) — Git status in prompt

## Testing

Run the Pester smoke tests:

```powershell
Invoke-Pester .\Microsoft.PowerShell_profile.Tests.ps1 -Output Detailed
```

Or from within a loaded profile session:

```powershell
Invoke-ProfilePesterTests
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Links

- [Microsoft Learn – PowerShell](https://learn.microsoft.com/powershell/)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [PSReadLine](https://github.com/PowerShell/PSReadLine)
