
#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
If (Test-Path "C:\Users\maig3\miniforge3\Scripts\conda.exe") {
    # Conda-managed hook output is executed as part of the standard conda init bootstrap.
    (& "C:\Users\maig3\miniforge3\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Where-Object { $_ } | Invoke-Expression
}
#endregion
