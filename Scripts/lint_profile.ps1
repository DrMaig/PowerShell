try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $results = Invoke-ScriptAnalyzer -Path (Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.ps1') -Severity Error, Warning
    if ($results) {
        $results | Select-Object RuleName, Severity, Line, Message | Format-Table -AutoSize -Wrap
    } else {
        Write-Host 'No errors or warnings found.'
    }
} catch {
    Write-Host "PSScriptAnalyzer unavailable: $($_.Exception.Message)"
}
