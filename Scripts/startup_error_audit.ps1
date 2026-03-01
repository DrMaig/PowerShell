$Error.Clear()
. "$PSScriptRoot\..\Microsoft.PowerShell_profile.ps1"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("ERRCOUNT=$($Error.Count)") | Out-Null
foreach ($err in ($Error | Select-Object -First 20)) {
    $cmd = if ($err.InvocationInfo -and $err.InvocationInfo.MyCommand) { $err.InvocationInfo.MyCommand.Name } else { '<none>' }
    $line = if ($err.InvocationInfo) { $err.InvocationInfo.ScriptLineNumber } else { -1 }
    $lines.Add("ERR: $($err.FullyQualifiedErrorId) | CMD=$cmd | LINE=$line") | Out-Null
}
$lines | Set-Content -Path "$PSScriptRoot\..\Logs\startup_error_audit.txt" -Encoding UTF8
$lines | ForEach-Object { Write-Output $_ }
