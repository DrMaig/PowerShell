# Project Guidelines

## Agent Quick Start
- Edit `Microsoft.PowerShell_profile.ps1` only for orchestrator concerns such as VS Code shell integration, profile stats, or component load order.
- Keep `profile.ps1` limited to conda bootstrap; do not move profile features into it.
- Put runtime behavior in `src/*.ps1` components and preserve the numbered load order.
- Validate parser first, then config, then analyzer/tests.
- Prefer existing VS Code tasks or repo scripts over ad hoc commands when they already cover the workflow.
- Treat mutating commands as high-impact and require explicit user intent.

## Architecture
- Primary entrypoint: `Microsoft.PowerShell_profile.ps1` (thin orchestrator).
- Secondary entrypoint: `profile.ps1` for conda init only.
- Modular runtime source: `src/01-Bootstrap.ps1` through `src/32-CodeSigning.ps1`.
- Startup flow begins Bootstrap -> Config -> Logging -> Environment -> PSReadLine -> ModuleManagement and ends with Welcome -> ExitHandlers -> Hardware/Toolkit/Monitoring/Linting/Signing components.
- `powershell.config.json` and `$Global:ProfileConfig` drive feature toggles and integration behavior; prefer config-aware changes over hardcoded behavior.
- Keep optional dependency integrations soft-fail and gate interactive setup behind `Test-ProfileInteractive`.
- Preserve `$Global:ProfileStats`, especially `ComponentLoadTimes`, when touching bootstrap or orchestrator logic.

## Build and Test
- Prefer these VS Code tasks when available: `PowerShell: Parse Check Profile`, `PowerShell: Validate powershell.config.json`, `PowerShell: Run PSScriptAnalyzer (Test)`, `PowerShell: Invoke Pester (Recommended)`, and `PowerShell: Quality Gate (Parse + Analyzer + Pester)`.
- Parser validation:
  ```powershell
  pwsh -NoProfile -Command "$allFiles = @('Microsoft.PowerShell_profile.ps1') + @(Get-ChildItem src/*.ps1 -File | ForEach-Object FullName); $totalErrors = 0; foreach ($f in $allFiles) { $e = $null; [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e) > $null; if($e){$totalErrors += $e.Count} }; if($totalErrors){exit 1}else{'parse ok'}"
  ```
- Single-file parse helper:
  ```powershell
  pwsh -NoProfile -File .\Scripts\validate_parse.ps1
  ```
- JSON config validation:
  ```powershell
  pwsh -NoProfile -Command "Get-Content .\powershell.config.json -Raw | ConvertFrom-Json | Out-Null; 'config ok'"
  ```
- Analyzer with repo settings:
  ```powershell
  pwsh -NoProfile -Command "Import-Module PSScriptAnalyzer -ErrorAction Stop; $issues = Invoke-ScriptAnalyzer -Path './Microsoft.PowerShell_profile.ps1' -Settings './PSScriptAnalyzerSettings.psd1' -Severity Error,Warning; if($issues){$issues | Select-Object RuleName,Severity,Line,Message | Format-Table -AutoSize; exit 1} else {'analyzer ok'}"
  ```
- Root smoke suite:
  ```powershell
  pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop; Invoke-Pester -Path './Microsoft.PowerShell_profile.Tests.ps1' -Output Detailed"
  ```
- Wrapper with deterministic summary written to `Scripts/pester_results.txt`:
  ```powershell
  pwsh -NoProfile -File .\Scripts\run_pester.ps1
  ```
- Modular `tests/` suite:
  ```powershell
  pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester ./tests -Output Detailed"
  ```

## Conventions
- Use advanced functions (`[CmdletBinding()]`, typed params, help) for exported commands.
- Preserve `SupportsShouldProcess` and `ConfirmImpact` semantics on mutating functions.
- Prefer `$IsWindows`, `$IsLinux`, `$IsMacOS` guards and graceful degradation for platform-specific behavior.
- Use `Get-Command ... -ErrorAction Ignore` for optional tool probes to avoid polluting `$Error` during startup.
- Avoid adding new `Invoke-Expression` usage; the allowed exception is the conda-managed hook in `profile.ps1`.
- Keep startup changes lightweight and fail-soft; avoid blocking profile load for optional integrations.
