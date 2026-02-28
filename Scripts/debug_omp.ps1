$initLines = @(& oh-my-posh init pwsh 2>&1)
Write-Output "Lines: $($initLines.Count)"
Write-Output "---CONTENT---"
foreach ($line in $initLines) {
    Write-Output $line
}
