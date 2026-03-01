function Test-NativeCommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandName
    )

    return ($null -ne (Get-Command -Name $CommandName -ErrorAction Ignore))
}

function Register-NativeToolCompleter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )

    if (Test-NativeCommandAvailable -CommandName $CommandName) {
        Register-ArgumentCompleter -Native -CommandName $CommandName -ScriptBlock $ScriptBlock -ErrorAction Ignore
        return $true
    }

    return $false
}

$registeredNative = [System.Collections.Generic.List[string]]::new()

# Git native completer (if posh-git not loaded, fall back)
if ((Test-NativeCommandAvailable -CommandName 'git') -and -not (Get-Module posh-git -ErrorAction Ignore)) {
    $ok = Register-NativeToolCompleter -CommandName 'git' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $words = $commandAst.ToString().Split([char[]]@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -le 1) {
            (& git --list-cmds=builtins 2>$null) -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
    if ($ok) { $registeredNative.Add('git') | Out-Null }
}

# kubectl native completer (if installed)
if (Test-NativeCommandAvailable -CommandName 'kubectl') {
    try {
        $kubectlCompletionScript = (& kubectl completion powershell 2>$null | Out-String)
        if (-not [string]::IsNullOrWhiteSpace($kubectlCompletionScript)) {
            & ([scriptblock]::Create($kubectlCompletionScript))
            $registeredNative.Add('kubectl') | Out-Null
        }
    } catch {
        Write-ProfileLog "kubectl native completion registration failed: $($_.Exception.Message)" -Level DEBUG -Component "Completions"
    }
}

# docker native-like completer (PowerShell-only fallback)
if (Test-NativeCommandAvailable -CommandName 'docker') {
    $dockerCommands = @(
        'attach','build','builder','commit','compose','config','container','context','cp','create','diff','events',
        'exec','export','history','image','images','import','info','inspect','kill','load','login','logout','logs',
        'manifest','network','node','pause','plugin','port','ps','pull','push','rename','restart','rm','rmi','run',
        'save','search','secret','service','stack','start','stats','stop','swarm','system','tag','top','trust',
        'unpause','update','version','volume','wait'
    )

    $ok = Register-NativeToolCompleter -CommandName 'docker' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $words = $commandAst.ToString().Split([char[]]@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -le 1) {
            $dockerCommands |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
    if ($ok) { $registeredNative.Add('docker') | Out-Null }
}

# Terraform native-like completer
if (Test-NativeCommandAvailable -CommandName 'terraform') {
    $ok = Register-NativeToolCompleter -CommandName 'terraform' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $words = $commandAst.ToString().Split([char[]]@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -le 1) {
            @('init', 'plan', 'apply', 'destroy', 'validate', 'fmt', 'workspace', 'state', 'output', 'console', 'taint', 'untaint', 'refresh', 'import', 'graph', 'show', 'providers', 'version', 'help') |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
    if ($ok) { $registeredNative.Add('terraform') | Out-Null }
}

# Helm native-like completer
if (Test-NativeCommandAvailable -CommandName 'helm') {
    $ok = Register-NativeToolCompleter -CommandName 'helm' -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $words = $commandAst.ToString().Split([char[]]@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -le 1) {
            @('install', 'uninstall', 'upgrade', 'rollback', 'list', 'status', 'get', 'values', 'env', 'repo', 'search', 'pull', 'push', 'chart', 'version', 'help') |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
    if ($ok) { $registeredNative.Add('helm') | Out-Null }
}

if ($registeredNative.Count -gt 0) {
    Write-ProfileLog "Native tool completers registered: $($registeredNative -join ', ')" -Level DEBUG -Component "Completions"
} else {
    Write-ProfileLog "No native tool completers registered" -Level DEBUG -Component "Completions"
}
