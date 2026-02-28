Set-StrictMode -Off
$p = Join-Path $PSScriptRoot '..' 'Microsoft.PowerShell_profile.ps1'
$content = Get-Content $p -Raw
$ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
$fns = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

$targets = @('Set-DnsServers', 'Optimize-System', 'Invoke-RemoteCommand', 'Sign-ProfileScript')
foreach ($name in $targets) {
    $match = $fns | Where-Object { $_.Name -eq $name }
    if ($match) {
        Write-Host "FOUND: $name at line $($match.Extent.StartLineNumber)"
        $hasSP = $match.Body.Extent.Text -match 'SupportsShouldProcess'
        Write-Host "  SupportsShouldProcess: $hasSP"
    } else {
        Write-Host "NOT FOUND: $name"
    }
}
Write-Host "`nTotal functions found: $($fns.Count)"
