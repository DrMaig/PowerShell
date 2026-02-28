# Project Guidelines

## Code Style
- Use advanced PowerShell functions with comment-based help, `[CmdletBinding()]`, typed params, and `Verb-Noun` naming (see `Microsoft.PowerShell_profile.ps1`).
- Match existing defensive style: `try/catch`, targeted `-ErrorAction`, and resilient fallbacks during profile load.
- Keep shared runtime state in existing hashtables (`$Global:ProfileConfig`, `$Global:ProfileState`, `$Global:ProfileStats`) instead of introducing new global patterns.
- Preserve startup guard order and intent in Region 1 (`version -> x64 -> OS -> strict mode`) in `Microsoft.PowerShell_profile.ps1`.

## Architecture
- Main implementation is a single regioned script: `Microsoft.PowerShell_profile.ps1` (23 regions, root runtime entrypoint).
- `profile.ps1` is a minimal conda hook bootstrap only; keep profile logic in `Microsoft.PowerShell_profile.ps1`.
- Runtime load sequence matters: environment validation -> PSReadLine init -> module cache/deferred loader -> prompt integrations -> log rotation -> welcome screen.
- Treat `Backups/` and `Modules/` as support/vendor/historical content, not primary runtime source for feature changes.

## Build and Test
- No app build pipeline is present at workspace root; validate changes as script checks.
- Use parser validation first:
  ```powershell
  pwsh -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('Microsoft.PowerShell_profile.ps1',[ref]$null,[ref]$e) > $null; $e | Format-List"
  ```
- Use PSScriptAnalyzer when available:
  ```powershell
  pwsh -NoProfile -Command "Import-Module PSScriptAnalyzer; Invoke-ScriptAnalyzer -Path .\Microsoft.PowerShell_profile.ps1 -Severity Error,Warning | Select-Object RuleName,Severity,Line,Message | Format-Table -AutoSize"
  ```
- Validate JSON config when touched:
  ```powershell
  pwsh -NoProfile -Command "Get-Content .\powershell.config.json -Raw | ConvertFrom-Json | Out-Null; 'config ok'"
  ```
- Debug workflow in VS Code: use `.vscode/launch.json` profile `PowerShell Launch Current File`; `PowerShell: Binary Module Pester Tests` exists but is only relevant when Pester test targets are present.

## Project Conventions
- Preserve `SupportsShouldProcess`/`ConfirmImpact` semantics on mutating functions.
- Keep startup fast and failure-tolerant; avoid adding hard failures for optional tools/modules.
- Prefer additive edits inside existing regions over restructuring files.
- Maintain aliases and helper naming patterns already used in Region 20 (`helpme`, short command wrappers).
- Keep command detection patterns (`Get-Command ... -ErrorAction SilentlyContinue`) for optional integrations.

## Integration Points
- External CLI integrations are command-detected (`winget`, `choco`, `scoop`, `npm`, `pip`, `dotnet`, `git`, `gh`, `kubectl`, `helm`).
- Prompt integrations: `oh-my-posh`, `Terminal-Icons`, `posh-git` (interactive sessions).
- Cache and logs are part of expected behavior (`Cache/installed_modules_cache.json`, `Logs/`).
- Tool completions are primarily declared in Region 19; Region 21 provides additional completion integration helpers.
- `powershell.config.json` carries startup/editor/module hints and should remain valid JSON.

## Security
- Do not run high-impact operations without explicit request: DNS/network mutation, package install/update/uninstall, process/service stops, cleanup/deletion tasks.
- Prefer `pwsh -NoProfile` for analysis and linting to avoid loading full profile side effects.
- Treat `Invoke-Expression` usage as sensitive (present in `profile.ps1` conda hook and oh-my-posh initialization); avoid adding new uses and prefer safer alternatives where practical.
