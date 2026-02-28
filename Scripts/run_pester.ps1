Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$outFile = Join-Path $PSScriptRoot 'pester_results.txt'

Import-Module Pester -MinimumVersion 5.0

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.PassThru = $true

$result = Invoke-Pester -Configuration $config

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("========== PESTER SUMMARY ==========")
$lines.Add("Total:   $($result.TotalCount)")  
$lines.Add("Passed:  $($result.PassedCount)")
$lines.Add("Failed:  $($result.FailedCount)")
$lines.Add("Skipped: $($result.SkippedCount)")
$lines.Add("Duration: $($result.Duration)")

if ($result.FailedCount -gt 0) {
    $lines.Add("")
    $lines.Add("========== FAILURES ==========")
    foreach ($container in $result.Containers) {
        foreach ($block in $container.Blocks) {
            foreach ($test in $block.Tests) {
                if ($test.Result -eq 'Failed') {
                    $lines.Add("FAIL: [$($block.Name)] $($test.Name)")
                    foreach ($er in $test.ErrorRecord) {
                        $lines.Add("  Error: $($er.Exception.Message)")
                    }
                    $lines.Add("")
                }
            }
            # Check nested blocks (e.g. Context inside Describe)
            foreach ($nested in $block.Blocks) {
                foreach ($test in $nested.Tests) {
                    if ($test.Result -eq 'Failed') {
                        $lines.Add("FAIL: [$($block.Name) > $($nested.Name)] $($test.Name)")
                        foreach ($er in $test.ErrorRecord) {
                            $lines.Add("  Error: $($er.Exception.Message)")
                        }
                        $lines.Add("")
                    }
                }
            }
        }
    }
}

[System.IO.File]::WriteAllLines($outFile, $lines.ToArray())
foreach ($l in $lines) { Write-Host $l }

if ($result.FailedCount -gt 0) { exit 1 } else { exit 0 }
