param([string]$Path)
if (-not $Path) { $Path = Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.ps1' }
$t = $null
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $Path),
    [ref]$t,
    [ref]$e
)
if ($e -and $e.Count -gt 0) {
    $e | Format-List
    exit 1
} else {
    Write-Host "parse ok: $Path"
}
