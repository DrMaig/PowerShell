<#
.SYNOPSIS
    Profile component 18 - Package Managers And Framework Management
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 18 (PACKAGE MANAGERS AND FRAMEWORK MANAGEMENT) for modular dot-sourced loading.
#>

#region 18 - PACKAGE MANAGERS AND FRAMEWORK MANAGEMENT
#==============================================================================
<#
.SYNOPSIS
    Package manager and development framework management functions
.DESCRIPTION
    Provides comprehensive management for Windows package managers (winget,
    chocolatey, scoop), language package managers (npm, pip, pipx, nuget),
    and development frameworks (dotnet, node, python).
#>

#------------------------------------------------------------------------------
# Package Manager Detection and Status
#------------------------------------------------------------------------------

function Get-PackageManagerStatus {
    <#
    .SYNOPSIS
        Gets status of all package managers.
    .DESCRIPTION
        Returns availability and version info for all installed package managers.
    #>
    [CmdletBinding()]
    param()

    $managers = @(
        @{ Name = 'winget'; Command = 'winget'; VersionArg = '--version' }
        @{ Name = 'choco'; Command = 'choco'; VersionArg = '--version' }
        @{ Name = 'scoop'; Command = 'scoop'; VersionArg = '--version' }
        @{ Name = 'npm'; Command = 'npm'; VersionArg = '--version' }
        @{ Name = 'pnpm'; Command = 'pnpm'; VersionArg = '--version' }
        @{ Name = 'yarn'; Command = 'yarn'; VersionArg = '--version' }
        @{ Name = 'pip'; Command = 'pip'; VersionArg = '--version' }
        @{ Name = 'pipx'; Command = 'pipx'; VersionArg = '--version' }
        @{ Name = 'nuget'; Command = 'nuget'; VersionArg = 'help' }
        @{ Name = 'dotnet'; Command = 'dotnet'; VersionArg = '--version' }
        @{ Name = 'cargo'; Command = 'cargo'; VersionArg = '--version' }
        @{ Name = 'gem'; Command = 'gem'; VersionArg = '--version' }
    )

    $results = @()
    foreach ($m in $managers) {
        $cmd = Get-Command $m.Command -ErrorAction Ignore
        $version = $null
        if ($cmd) {
            try {
                $verOutput = & $m.Command $m.VersionArg 2>$null | Select-Object -First 1
                $version = ($verOutput -replace '.*?([0-9]+\.[0-9]+\.[0-9]+).*', '$1').Trim()
            } catch {
                Write-ProfileLog "Version detection failed for '$($m.Name)': $($_.Exception.Message)" -Level DEBUG -Component "PackageManager"
            }
        }
        $results += [PSCustomObject]@{
            Name = $m.Name
            Available = $null -ne $cmd
            Version = $version
            Path = if ($cmd) { $cmd.Source } else { $null }
        }
    }
    return $results | Sort-Object Name
}

#------------------------------------------------------------------------------
# Winget Package Manager
#------------------------------------------------------------------------------

function Get-WingetPackage {
    <#
    .SYNOPSIS
        Searches for packages using winget.
    .DESCRIPTION
        Searches winget repositories for packages matching the query.
    .PARAMETER Query
        Search query string.
    .PARAMETER Exact
        Match exact package name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [switch]$Exact
    )

    if (-not (Get-Command winget -ErrorAction Ignore)) {
        Write-Warning "winget is not installed or not in PATH."
        return
    }

    try {
        $wingetArgs = @('search', $Query)
        if ($Exact) { $wingetArgs += '--exact' }
        $wingetArgs += '--accept-source-agreements'

        & winget @wingetArgs | Out-String | Write-Output
    } catch {
        Write-ProfileLog "Get-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        Installs a package using winget.
    .DESCRIPTION
        Installs a package from winget repositories.
    .PARAMETER Package
        Package name or ID.
    .PARAMETER Silent
        Silent installation.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Package,
        [switch]$Silent
    )

    if (-not (Get-Command winget -ErrorAction Ignore)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Install')) {
            $wingetArgs = @('install', $Package, '--accept-package-agreements', '--accept-source-agreements')
            if ($Silent) { $wingetArgs += '--silent' }

            & winget @wingetArgs
            Write-ProfileLog "Installed winget package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-WingetPackage {
    <#
    .SYNOPSIS
        Updates a package using winget.
    .DESCRIPTION
        Updates a specific package or all packages.
    .PARAMETER Package
        Package name, or 'all' for all packages.
    .PARAMETER Silent
        Silent upgrade.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Package = 'all',
        [switch]$Silent
    )

    if (-not (Get-Command winget -ErrorAction Ignore)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        $target = if ($Package -eq 'all') { '--all' } else { $Package }
        if ($PSCmdlet.ShouldProcess($target, 'Upgrade')) {
            $wingetArgs = @('upgrade', $target, '--accept-package-agreements')
            if ($Silent) { $wingetArgs += '--silent' }

            & winget @wingetArgs
            Write-ProfileLog "Updated winget package(s): $target" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Uninstall-WingetPackage {
    <#
    .SYNOPSIS
        Uninstalls a package using winget.
    .DESCRIPTION
        Removes a package installed via winget.
    .PARAMETER Package
        Package name or ID.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Package
    )

    if (-not (Get-Command winget -ErrorAction Ignore)) {
        Write-Warning "winget is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Uninstall')) {
            winget uninstall $Package
            Write-ProfileLog "Uninstalled winget package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Uninstall-WingetPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-WingetOutdated {
    <#
    .SYNOPSIS
        Lists outdated winget packages.
    .DESCRIPTION
        Shows packages with available updates.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command winget -ErrorAction Ignore)) {
        Write-Warning "winget is not installed or not in PATH."
        return
    }

    try {
        winget upgrade --accept-source-agreements
    } catch {
        Write-ProfileLog "Get-WingetOutdated failed: $_" -Level WARN -Component "PackageManager"
    }
}

#------------------------------------------------------------------------------
# Chocolatey Package Manager
#------------------------------------------------------------------------------

function Get-ChocoPackage {
    <#
    .SYNOPSIS
        Searches for packages using Chocolatey.
    .PARAMETER Query
        Search query.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    if (-not (Get-Command choco -ErrorAction Ignore)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return
    }

    try {
        choco search $Query --limit-output | ConvertFrom-Csv -Delimiter '|' -Header Name, Version
    } catch {
        Write-ProfileLog "Get-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Installs a package using Chocolatey.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Force
        Force reinstall.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Force
    )

    if (-not (Get-Command choco -ErrorAction Ignore)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'Install')) {
                $chocoArgs = @('install', $p, '-y')
                if ($Force) { $chocoArgs += '--force' }
                choco @chocoArgs
                Write-ProfileLog "Installed choco package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-ChocoPackage {
    <#
    .SYNOPSIS
        Updates Chocolatey packages.
    .PARAMETER Package
        Package name or 'all'.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Package = 'all')

    if (-not (Get-Command choco -ErrorAction Ignore)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        $target = if ($Package -eq 'all') { 'all' } else { $Package }
        if ($PSCmdlet.ShouldProcess($target, 'Upgrade')) {
            if ($Package -eq 'all') {
                choco upgrade all -y
            } else {
                choco upgrade $Package -y
            }
            Write-ProfileLog "Updated choco package(s): $target" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Uninstall-ChocoPackage {
    <#
    .SYNOPSIS
        Uninstalls a Chocolatey package.
    .PARAMETER Package
        Package name.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)][string]$Package)

    if (-not (Get-Command choco -ErrorAction Ignore)) {
        Write-Warning "Chocolatey is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'Uninstall')) {
            choco uninstall $Package -y
            Write-ProfileLog "Uninstalled choco package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Uninstall-ChocoPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Scoop Package Manager
#------------------------------------------------------------------------------

function Get-ScoopPackage {
    <#
    .SYNOPSIS
        Searches for packages using Scoop.
    .PARAMETER Query
        Search query.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    if (-not (Get-Command scoop -ErrorAction Ignore)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return
    }

    try {
        scoop search $Query | ConvertFrom-String -PropertyNames Bucket, Name, Version -Delimiter '\s+'
    } catch {
        Write-ProfileLog "Get-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-ScoopPackage {
    <#
    .SYNOPSIS
        Installs a package using Scoop.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Global
        Install globally.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Global
    )

    if (-not (Get-Command scoop -ErrorAction Ignore)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'Install')) {
                if ($Global) {
                    scoop install $p --global
                } else {
                    scoop install $p
                }
                Write-ProfileLog "Installed scoop package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-ScoopPackage {
    <#
    .SYNOPSIS
        Updates Scoop packages.
    .PARAMETER Package
        Package name or '*' for all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Package = '*')

    if (-not (Get-Command scoop -ErrorAction Ignore)) {
        Write-Warning "Scoop is not installed or not in PATH."
        return $false
    }

    try {
        if ($Package -eq '*') {
            if ($PSCmdlet.ShouldProcess('all packages', 'Update')) {
                scoop update
                scoop update '*'
                Write-ProfileLog "Updated all scoop packages" -Level INFO -Component "PackageManager"
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Package, 'Update')) {
                scoop update $Package
                Write-ProfileLog "Updated scoop package: $Package" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-ScoopPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Node.js and NPM Management
#------------------------------------------------------------------------------

function Get-NpmPackage {
    <#
    .SYNOPSIS
        Searches for npm packages.
    .PARAMETER Query
        Search query.
    .PARAMETER Limit
        Maximum results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [int]$Limit = 20
    )

    if (-not (Get-Command npm -ErrorAction Ignore)) {
        Write-Warning "npm is not installed or not in PATH."
        return
    }

    try {
        npm search $Query --limit $Limit 2>$null | Select-Object -Skip 1 |
            ConvertFrom-String -PropertyNames Name, Description, Author, Date, Version, Keywords
    } catch {
        Write-ProfileLog "Get-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-NpmPackage {
    <#
    .SYNOPSIS
        Installs npm packages globally or locally.
    .PARAMETER Package
        Package name(s).
    .PARAMETER Global
        Install globally.
    .PARAMETER Dev
        Install as dev dependency.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$Global,
        [switch]$Dev
    )

    if (-not (Get-Command npm -ErrorAction Ignore)) {
        Write-Warning "npm is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'npm install')) {
                $npmArgs = @('install')
                if ($Global) {
                    $npmArgs += '-g'
                } elseif ($Dev) {
                    $npmArgs += '--save-dev'
                }
                $npmArgs += $p

                & npm @npmArgs
                Write-ProfileLog "Installed npm package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-NpmPackage {
    <#
    .SYNOPSIS
        Updates npm packages.
    .PARAMETER Package
        Package name or 'all'.
    .PARAMETER Global
        Update global packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Package = 'all',
        [switch]$Global
    )

    if (-not (Get-Command npm -ErrorAction Ignore)) {
        Write-Warning "npm is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'npm update')) {
            if ($Global) {
                npm update -g $Package
            } else {
                if ($Package -eq 'all') {
                    npm update
                } else {
                    npm update $Package
                }
            }
            Write-ProfileLog "Updated npm package(s): $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Update-NpmPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-NodeVersion {
    <#
    .SYNOPSIS
        Gets Node.js and npm version information.
    #>
    [CmdletBinding()]
    param()

    $result = @{}

    if (Get-Command node -ErrorAction Ignore) {
        $result.NodeVersion = (node --version) -replace '^v'
    }

    if (Get-Command npm -ErrorAction Ignore) {
        $result.NpmVersion = (npm --version)
    }

    if (Get-Command nvm -ErrorAction Ignore) {
        $result.NvmVersion = (nvm version)
    }

    if (Get-Command pnpm -ErrorAction Ignore) {
        $result.PnpmVersion = (pnpm --version)
    }

    if (Get-Command yarn -ErrorAction Ignore) {
        $result.YarnVersion = (yarn --version)
    }

    return [PSCustomObject]$result
}

#------------------------------------------------------------------------------
# Python and Pip Management
#------------------------------------------------------------------------------

function Get-PipPackage {
    <#
    .SYNOPSIS
        Lists or searches pip packages.
    .PARAMETER Search
        Search query (optional).
    .PARAMETER Outdated
        Show outdated packages.
    #>
    [CmdletBinding()]
    param(
        [string]$Search,
        [switch]$Outdated
    )

    if (-not (Get-Command pip -ErrorAction Ignore)) {
        Write-Warning "pip is not installed or not in PATH."
        return
    }

    try {
        if ($Outdated) {
            pip list --outdated --format=columns
        } elseif ($Search) {
            pip search $Search 2>$null
        } else {
            pip list --format=columns
        }
    } catch {
        Write-ProfileLog "Get-PipPackage failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-PipPackage {
    <#
    .SYNOPSIS
        Installs pip packages.
    .PARAMETER Package
        Package name(s).
    .PARAMETER User
        Install for user only.
    .PARAMETER Upgrade
        Upgrade existing packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string[]]$Package,
        [switch]$User,
        [switch]$Upgrade
    )

    if (-not (Get-Command pip -ErrorAction Ignore)) {
        Write-Warning "pip is not installed or not in PATH."
        return $false
    }

    try {
        foreach ($p in $Package) {
            if ($PSCmdlet.ShouldProcess($p, 'pip install')) {
                $pipArgs = @('install')
                if ($User) { $pipArgs += '--user' }
                if ($Upgrade) { $pipArgs += '--upgrade' }
                $pipArgs += $p

                & pip @pipArgs
                Write-ProfileLog "Installed pip package: $p" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Install-PipPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-PipPackage {
    <#
    .SYNOPSIS
        Updates pip packages.
    .PARAMETER Package
        Package name or 'all'.
    .PARAMETER User
        Update user packages.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Package = 'all',
        [switch]$User
    )

    if (-not (Get-Command pip -ErrorAction Ignore)) {
        Write-Warning "pip is not installed or not in PATH."
        return $false
    }

    try {
        if ($Package -eq 'all') {
            $packages = pip list --outdated --format=json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty name
            foreach ($p in $packages) {
                if ($PSCmdlet.ShouldProcess($p, 'pip upgrade')) {
                    $pipArgs = @('install', '--upgrade')
                    if ($User) { $pipArgs += '--user' }
                    $pipArgs += $p
                    & pip @pipArgs
                }
            }
            Write-ProfileLog "Updated all pip packages" -Level INFO -Component "PackageManager"
        } else {
            if ($PSCmdlet.ShouldProcess($Package, 'pip upgrade')) {
                $pipArgs = @('install', '--upgrade')
                if ($User) { $pipArgs += '--user' }
                $pipArgs += $Package
                & pip @pipArgs
                Write-ProfileLog "Updated pip package: $Package" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-PipPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Install-PipxPackage {
    <#
    .SYNOPSIS
        Installs Python applications using pipx.
    .PARAMETER Package
        Package name.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory)][string]$Package)

    if (-not (Get-Command pipx -ErrorAction Ignore)) {
        Write-Warning "pipx is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Package, 'pipx install')) {
            pipx install $Package
            Write-ProfileLog "Installed pipx package: $Package" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-PipxPackage failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Get-PythonVersion {
    <#
    .SYNOPSIS
        Gets Python and pip version information.
    #>
    [CmdletBinding()]
    param()

    $result = @{}

    if (Get-Command python -ErrorAction Ignore) {
        $result.PythonVersion = (python --version) -replace '^Python\s+'
    }

    if (Get-Command pip -ErrorAction Ignore) {
        $result.PipVersion = (pip --version) -split '\s+' | Select-Object -Index 1
    }

    if (Get-Command pipx -ErrorAction Ignore) {
        $result.PipxVersion = (pipx --version)
    }

    if (Get-Command conda -ErrorAction Ignore) {
        $result.CondaVersion = (conda --version) -replace '^conda\s+'
    }

    return [PSCustomObject]$result
}

#------------------------------------------------------------------------------
# .NET Framework Management
#------------------------------------------------------------------------------

function Get-DotnetInfo {
    <#
    .SYNOPSIS
        Gets .NET SDK and runtime information.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command dotnet -ErrorAction Ignore)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return
    }

    try {
        [PSCustomObject]@{
            SdkVersion = (dotnet --version)
            Runtimes = dotnet --list-runtimes | ForEach-Object { ($_ -split '\s+')[0,1] -join ' ' }
            Sdks = dotnet --list-sdks | ForEach-Object { ($_ -split '\s+')[0,1] -join ' ' }
        }
    } catch {
        Write-ProfileLog "Get-DotnetInfo failed: $_" -Level WARN -Component "PackageManager"
    }
}

function Install-DotnetTool {
    <#
    .SYNOPSIS
        Installs a .NET global tool.
    .PARAMETER Tool
        Tool name.
    .PARAMETER Version
        Specific version.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [string]$Version
    )

    if (-not (Get-Command dotnet -ErrorAction Ignore)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return $false
    }

    try {
        if ($PSCmdlet.ShouldProcess($Tool, 'dotnet tool install')) {
            $dotnetArgs = @('tool', 'install', '--global', $Tool)
            if ($Version) { $dotnetArgs += '--version'; $dotnetArgs += $Version }

            & dotnet @dotnetArgs
            Write-ProfileLog "Installed dotnet tool: $Tool" -Level INFO -Component "PackageManager"
        }
        return $true
    } catch {
        Write-ProfileLog "Install-DotnetTool failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

function Update-DotnetTool {
    <#
    .SYNOPSIS
        Updates .NET global tools.
    .PARAMETER Tool
        Tool name or omitted for all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Tool)

    if (-not (Get-Command dotnet -ErrorAction Ignore)) {
        Write-Warning "dotnet CLI is not installed or not in PATH."
        return $false
    }

    try {
        if ($Tool) {
            if ($PSCmdlet.ShouldProcess($Tool, 'dotnet tool update')) {
                dotnet tool update --global $Tool
                Write-ProfileLog "Updated dotnet tool: $Tool" -Level INFO -Component "PackageManager"
            }
        } else {
            if ($PSCmdlet.ShouldProcess('all tools', 'dotnet tool update')) {
                dotnet tool list --global | Select-Object -Skip 2 | ForEach-Object {
                    $toolName = ($_ -split '\s+')[0]
                    if ($toolName) {
                        dotnet tool update --global $toolName
                    }
                }
                Write-ProfileLog "Updated all dotnet tools" -Level INFO -Component "PackageManager"
            }
        }
        return $true
    } catch {
        Write-ProfileLog "Update-DotnetTool failed: $_" -Level WARN -Component "PackageManager"
        return $false
    }
}

#------------------------------------------------------------------------------
# Unified Package Management
#------------------------------------------------------------------------------

function Install-DevPackage {
    <#
    .SYNOPSIS
        Installs a package using the appropriate package manager.
    .DESCRIPTION
        Automatically detects and uses the correct package manager based on context or preference.
    .PARAMETER Package
        Package name.
    .PARAMETER Manager
        Package manager to use (winget, choco, scoop, npm, pip, dotnet).
    .PARAMETER Global
        Install globally where supported.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Package,
        [ValidateSet('winget', 'choco', 'scoop', 'npm', 'pip', 'pipx', 'dotnet')]
        [string]$Manager,
        [switch]$Global
    )

    if (-not $Manager) {
        # Auto-detect based on package prefix or available managers
        $priority = @('winget', 'choco', 'npm', 'pip', 'scoop')
        foreach ($m in $priority) {
            if (Get-Command $m -ErrorAction Ignore) {
                $Manager = $m
                break
            }
        }
    }

    switch ($Manager) {
        'winget' { return Install-WingetPackage -Package $Package }
        'choco' { return Install-ChocoPackage -Package $Package }
        'scoop' { return Install-ScoopPackage -Package $Package }
        'npm' { return Install-NpmPackage -Package $Package -Global:$Global }
        'pip' { return Install-PipPackage -Package $Package }
        'pipx' { return Install-PipxPackage -Package $Package }
        'dotnet' { return Install-DotnetTool -Tool $Package }
        default {
            Write-Warning "No suitable package manager found."
            return $false
        }
    }
}

function Update-AllPackages {
    <#
    .SYNOPSIS
        Updates packages across all package managers.
    .DESCRIPTION
        Updates packages for all detected package managers.
    .PARAMETER Manager
        Specific manager(s) to update, or all.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('all', 'winget', 'choco', 'scoop', 'npm', 'pip', 'dotnet')]
        [string[]]$Manager = 'all'
    )

    $results = @()

    if ($Manager -contains 'all' -or $Manager -contains 'winget') {
        if (Get-Command winget -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('winget packages', 'Update')) {
                Update-WingetPackage -Package 'all'
                $results += 'winget'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'choco') {
        if (Get-Command choco -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('choco packages', 'Update')) {
                Update-ChocoPackage -Package 'all'
                $results += 'choco'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'scoop') {
        if (Get-Command scoop -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('scoop packages', 'Update')) {
                Update-ScoopPackage
                $results += 'scoop'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'npm') {
        if (Get-Command npm -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('npm packages', 'Update')) {
                Update-NpmPackage -Global
                $results += 'npm'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'pip') {
        if (Get-Command pip -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('pip packages', 'Update')) {
                Update-PipPackage -Package 'all'
                $results += 'pip'
            }
        }
    }

    if ($Manager -contains 'all' -or $Manager -contains 'dotnet') {
        if (Get-Command dotnet -ErrorAction Ignore) {
            if ($PSCmdlet.ShouldProcess('dotnet tools', 'Update')) {
                Update-DotnetTool
                $results += 'dotnet'
            }
        }
    }

    Write-ProfileLog "Updated packages for: $($results -join ', ')" -Level INFO -Component "PackageManager"
    return $results
}

#endregion PACKAGE MANAGERS AND FRAMEWORK MANAGEMENT
