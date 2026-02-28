Set-StrictMode -Off
$f = Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.ps1'
$lines = [System.IO.File]::ReadAllLines($f)
$changed = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $trimmed = $lines[$i].TrimEnd()
    if ($trimmed -ne $lines[$i]) {
        $lines[$i] = $trimmed
        $changed++
    }
}
[System.IO.File]::WriteAllLines($f, $lines, [System.Text.UTF8Encoding]::new($true))
Write-Host "Stripped trailing whitespace from $changed lines"
