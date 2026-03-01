Describe 'Profile parse validation' {
    It 'parses orchestrator and all src components without errors' {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $allFiles = @(
            (Join-Path $repoRoot 'Microsoft.PowerShell_profile.ps1')
        ) + @(Get-ChildItem -Path (Join-Path $repoRoot 'src') -Filter '*.ps1' -File | ForEach-Object FullName)

        $parseErrors = @()
        foreach ($file in $allFiles) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$errors) > $null
            if ($errors) { $parseErrors += $errors }
        }

        $parseErrors | Should -BeNullOrEmpty
    }
}
