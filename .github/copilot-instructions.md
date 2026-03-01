# Project Guidelines

## Agent Quick Start
- Edit `Microsoft.PowerShell_profile.ps1` only as orchestrator/entrypoint logic.
- Keep `profile.ps1` limited to conda bootstrap.
- Place profile behavior in `src/*.ps1` components and preserve component order.
- Validate parser first with `pwsh -NoProfile` before analyzer/tests.
- Treat mutating commands as high-impact and require explicit user intent.

## Architecture
- Primary entrypoint: `Microsoft.PowerShell_profile.ps1` (thin orchestrator).
- Modular runtime source: `src/01-Bootstrap.ps1` ... `src/32-CodeSigning.ps1`.
- Startup flow: Bootstrap -> Config -> Logging -> Environment -> PSReadLine -> ModuleManagement -> ... -> Welcome -> ExitHandlers.
- Keep optional dependency integrations soft-fail and interactive setup behind `Test-ProfileInteractive`.

## Build and Test
- Parser validation:
  ```powershell
  pwsh -NoProfile -Command "$allFiles = @('Microsoft.PowerShell_profile.ps1') + @(Get-ChildItem src/*.ps1 -File | ForEach-Object FullName); $totalErrors = 0; foreach ($f in $allFiles) { $e = $null; [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e) > $null; if($e){$totalErrors += $e.Count} }; if($totalErrors){exit 1}else{'parse ok'}"
  ```
- JSON config validation:
  ```powershell
  pwsh -NoProfile -Command "Get-Content .\powershell.config.json -Raw | ConvertFrom-Json | Out-Null; 'config ok'"
  ```
- Analyzer (best effort):
  ```powershell
  pwsh -NoProfile -Command "try { Import-Module PSScriptAnalyzer -ErrorAction Stop; Get-ChildItem -Path . -Include *.ps1 -Recurse -File | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error,Warning } } catch { 'PSScriptAnalyzer unavailable: ' + $_.Exception.Message }"
  ```
- Pester tests:
  ```powershell
  pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester ./tests -Output Detailed"
  ```

## Conventions
- Use advanced functions (`[CmdletBinding()]`, typed params, help) for exported commands.
- Preserve `SupportsShouldProcess`/`ConfirmImpact` semantics on mutating functions.
- Prefer `$IsWindows`, `$IsLinux`, `$IsMacOS` platform guards and graceful degradation.
- Avoid adding new `Invoke-Expression` usage.
