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
