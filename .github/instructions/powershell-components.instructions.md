---
description: "Use when editing PowerShell profile components in src/*.ps1, adding new profile commands, refactoring dot-sourced startup logic, or changing component-level logging, platform guards, package manager helpers, or mutating functions."
name: "PowerShell Profile Components"
applyTo: "src/*.ps1"
---
# PowerShell Profile Component Guidelines

- Treat files in `src/` as dot-sourced components, not standalone scripts. Keep them safe to load during shell startup and avoid behavior that assumes isolated script execution.
- Preserve the numbered component boundaries and existing responsibilities. Put new behavior in the most specific existing component instead of expanding orchestrator logic in `Microsoft.PowerShell_profile.ps1`.
- Keep startup fail-soft. Optional integrations should warn, log, or return safely rather than block profile load.
- Use `Get-Command ... -ErrorAction Ignore` for command availability checks so startup probes do not pollute `$Error`.
- Prefer `Write-ProfileLog` for diagnostic messages and `Write-CaughtException` inside catch blocks when those helpers are available in the component load order.
- Respect `$Global:ProfileConfig`, `$Global:ProfileState`, and `$Global:ProfileStats` as shared contracts. Extend them compatibly; do not replace expected dictionary structures such as `ComponentLoadTimes`.
- Preserve cross-platform behavior with `$IsWindows`, `$IsLinux`, and `$IsMacOS` guards. Windows-only features should degrade cleanly on other platforms.
- For exported or user-invoked functions, prefer advanced functions with typed parameters and help, matching the existing component style.
- For mutating commands, preserve `SupportsShouldProcess` and set `ConfirmImpact` when the operation is meaningfully destructive.
- Avoid new `Invoke-Expression` usage. The repository allows the conda-managed hook in `profile.ps1`; component code should use safer alternatives.