Set-StrictMode -Off
$profileFile = Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.ps1'
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    $results = @(Invoke-ScriptAnalyzer -Path $profileFile -Severity Error, Warning, Information)
    Write-Output "PSSA Findings: $($results.Count)"
    if ($results.Count -gt 0) {
        foreach ($r in $results) {
            Write-Output "[$($r.Severity)] Line $($r.Line): $($r.RuleName) - $($r.Message)"
        }
    } else {
        Write-Output 'Clean - no findings at any severity.'
    }
} catch {
    Write-Output "PSScriptAnalyzer unavailable: $($_.Exception.Message)"
}
