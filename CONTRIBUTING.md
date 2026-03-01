# Contributing

Thanks for helping improve this profile.

## Setup

1. Clone the repository.
2. Use PowerShell 7.5+.
3. Run checks from repository root with `pwsh -NoProfile`.

## Coding Standards

- Follow `.github/copilot-instructions.md`.
- Keep changes focused and within relevant components under `src/`.
- Use approved verbs, `[CmdletBinding()]`, typed params, and comment-based help for exported functions.
- Keep optional dependencies soft-fail and interactive behavior behind `Test-ProfileInteractive`.

## Validation

Run:

```powershell
pwsh -NoProfile -Command "$allFiles = @('Microsoft.PowerShell_profile.ps1') + @(Get-ChildItem src/*.ps1 -File | ForEach-Object FullName); $totalErrors = 0; foreach ($f in $allFiles) { $e = $null; [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e) > $null; if($e){$totalErrors += $e.Count} }; if($totalErrors){exit 1}"
pwsh -NoProfile -Command "Get-Content .\powershell.config.json -Raw | ConvertFrom-Json | Out-Null"
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester ./tests -Output Detailed"
```

## Pull Requests

1. Fork and create a feature branch.
2. Make focused changes.
3. Run validations locally.
4. Open a PR with clear summary, rationale, and validation output.
