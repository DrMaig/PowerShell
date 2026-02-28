# Project Guidelines

## Agent Quick Start
- Open and edit `Microsoft.PowerShell_profile.ps1` for profile behavior changes; keep `profile.ps1` limited to conda bootstrap.
- Keep changes inside existing regions and preserve region order; avoid broad structural rewrites.
- Validate edits with parser check first using `pwsh -NoProfile`, then run JSON/PSScriptAnalyzer checks only when relevant.
- Treat mutating commands as high-impact (`Set-Dns*`, package install/update/uninstall, process/service stop, cleanup/delete); require explicit user request.
- Keep startup resilient: optional modules/tools should fail soft, and interactive features should stay behind `Test-ProfileInteractive`.

## Code Style
- Use advanced PowerShell functions with comment-based help, `[CmdletBinding()]`, typed params, and `Verb-Noun` naming (see `Microsoft.PowerShell_profile.ps1`).
- Match the existing defensive style: `try/catch`, targeted `-ErrorAction`, and resilient fallbacks during profile load.
- Keep shared runtime state in existing hashtables: `$Global:ProfileConfig`, `$Global:ProfileState`, `$Global:ProfileStats`.
- Preserve Region 1 bootstrap guard order and intent: `version -> x64 -> OS -> strict mode`.

## Architecture
- Primary runtime entrypoint is `Microsoft.PowerShell_profile.ps1` (23 ordered regions).
- `profile.ps1` is conda bootstrap only; keep profile behavior in `Microsoft.PowerShell_profile.ps1`.
- Startup order is important: bootstrap/log init -> `Test-Environment -SkipNetworkCheck` -> PSReadLine init -> module cache/deferred loader -> prompt integrations -> finalization/log rotation/welcome.
- Region 19 is the active completion registration path; Region 21 helper integration should only be expanded when explicitly wired in.
- Treat `Backups/` and `Modules/` as support/vendor/historical content, not primary runtime sources.

## Build and Test
- No build pipeline exists at workspace root; validate with script checks.
- Parser validation first:
  ```powershell
  pwsh -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('Microsoft.PowerShell_profile.ps1',[ref]$null,[ref]$e) > $null; if($e){$e | Format-List; exit 1} else {'parse ok'}"
  ```
- Validate JSON config when touched:
  ```powershell
  pwsh -NoProfile -Command "Get-Content .\powershell.config.json -Raw | ConvertFrom-Json | Out-Null; 'config ok'"
  ```
- Run PSScriptAnalyzer best-effort:
  ```powershell
  pwsh -NoProfile -Command "try { Import-Module PSScriptAnalyzer -ErrorAction Stop; Invoke-ScriptAnalyzer -Path .\Microsoft.PowerShell_profile.ps1 -Severity Error,Warning | Select-Object RuleName,Severity,Line,Message | Format-Table -AutoSize } catch { 'PSScriptAnalyzer unavailable: ' + $_.Exception.Message }"
  ```

## Project Conventions
- Preserve `SupportsShouldProcess`/`ConfirmImpact` semantics on mutating functions.
- Keep startup fast and failure-tolerant; do not turn optional dependency failures into hard startup failures.
- Prefer additive edits inside existing regions over structural rewrites or region reordering.
- Keep interactive-only setup gated with `Test-ProfileInteractive`.
- Maintain Region 20 helper/alias patterns (`helpme`, short command wrappers) and command detection with `Get-Command ... -ErrorAction SilentlyContinue`.

## Integration Points
- Prompt integrations: `oh-my-posh`, `Terminal-Icons`, `posh-git` (interactive sessions).
- Completion coverage includes `winget`, `choco`, `scoop`, `npm`, `pnpm`, `yarn`, `pip`, `pipx`, `dotnet`, `git`, `gh`, `kubectl`, `helm`, `docker`, `terraform`, `aws`, `az`, `cargo`, `nuget`, `code`.
- Runtime artifacts are expected: `Cache/installed_modules_cache.json`, `Cache/PSReadLine_history.txt`, `Logs/`.
- `powershell.config.json` contains startup/editor/module hints and must remain valid JSON.

## Security
- Do not run high-impact operations without explicit request: DNS changes, package install/update/uninstall, process/service stops, cleanup/deletion actions.
- Never add automatic install/update behavior to startup path (module/package operations are side-effecting).
- Prefer `pwsh -NoProfile` for analysis/linting to avoid profile side effects.
- Treat `Invoke-Expression` usage as sensitive (existing uses: conda bootstrap and oh-my-posh init); avoid introducing new uses.
