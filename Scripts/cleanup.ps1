#requires -Version 5.1
<#
.SYNOPSIS
Safe, hardware-aware Windows 10 cleanup and optimization script with strong guardrails.

.DESCRIPTION
Optimize-Windows performs conservative maintenance, cleanup, diagnostics, and optional optimization tasks with
administrator enforcement, strict OS validation, dry-run support, interactive confirmation flow, reversible backups,
manifest generation, and detailed reporting.

Target OS: Windows 10 Pro 64-bit 22H2 build 19045.7058.

Safety notes:
- Never touches protected user data stores (credentials, browser profiles, search index data, account-sensitive stores).
- Exports manifests before removals and backups before destructive operations where possible.
- Does not disable security-critical services by default.

.PARAMETER DryRun
Reports all planned actions without applying changes.

.PARAMETER Force
Runs non-interactively (skips prompts) while still respecting safety gates.

.PARAMETER Interactive
Enables interactive confirmations for major destructive steps. Interactive mode is default unless -Force is used.

.PARAMETER OverrideOSCheck
Allows running on non-target Windows builds after warning.

.PARAMETER OverrideSafety
Allows continuing when restore point cannot be created or safety prerequisites are degraded.

.PARAMETER TempAgeDays
Minimum age (in days) for temp files eligible for deletion.

.PARAMETER RemovePrefetch
Opt-in prefetch cleanup. Disabled by default.

.PARAMETER RebuildSearchIndex
Opt-in search index rebuild request (does not delete index files).

.PARAMETER RecommendTelemetryChanges
Shows conservative telemetry reduction recommendations and optionally applies with explicit consent.

.PARAMETER OptimizationProfile
Optimization recommendation profile: Gaming, Office, Development.
Alias: -Profile

.PARAMETER Aggressive
Enables more aggressive performance tweaks (still confirmation-gated).

.PARAMETER RemoveBloat
Removes safe bloatware candidates with confirmation.

.PARAMETER PreviewBloatRemoval
Shows bloatware candidates without removing.

.PARAMETER AutoUpdateDrivers
Attempts driver updates from Windows Update channel only after backup and confirmation.

.PARAMETER AllowListPath
Explicit allow-list paths for user content areas otherwise protected from deletion.

.EXAMPLE
.\Optimize-Windows.ps1 -DryRun

.EXAMPLE
.\Optimize-Windows.ps1 -Force -AutoUpdateDrivers -RemoveBloat

.EXAMPLE
.\Optimize-Windows.ps1 -OptimizationProfile Gaming -Aggressive
#>
[CmdletBinding()]
param(
	[switch]$DryRun,
	[switch]$Force,
	[switch]$Interactive,
	[switch]$OverrideOSCheck,
	[switch]$OverrideSafety,
	[ValidateRange(1, 365)]
	[int]$TempAgeDays = 7,
	[switch]$RemovePrefetch,
	[switch]$RebuildSearchIndex,
	[switch]$RecommendTelemetryChanges,
	[Alias('Profile')]
	[ValidateSet('Gaming', 'Office', 'Development')]
	[string]$OptimizationProfile = 'Office',
	[switch]$Aggressive,
	[switch]$RemoveBloat,
	[switch]$PreviewBloatRemoval,
	[switch]$AutoUpdateDrivers,
	[string[]]$AllowListPath = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RunId = [guid]::NewGuid().ToString()
$script:StartTime = Get-Date
$script:CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$script:Machine = $env:COMPUTERNAME
$script:ScriptRoot = Split-Path -Parent $PSCommandPath
$script:Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:LogRoot = Join-Path $script:ScriptRoot 'Logs'
$script:RunRoot = Join-Path $script:LogRoot "OptimizeRun_$script:Stamp`_$($script:RunId.Substring(0,8))"
$script:ManifestRoot = Join-Path $script:RunRoot 'Manifests'
$script:BackupRoot = Join-Path $script:RunRoot 'Backups'
$script:ReportPath = Join-Path $script:RunRoot 'summary_report.json'
$script:LogPath = Join-Path $script:RunRoot 'optimize.log'
if ($Force) {
	$script:IsInteractiveMode = $false
}
elseif ($PSBoundParameters.ContainsKey('Interactive')) {
	$script:IsInteractiveMode = [bool]$Interactive
}
else {
	$script:IsInteractiveMode = $true
}
$script:ExitCode = 0

$script:TargetOS = [ordered]@{
	ProductName = 'Windows 10 Pro'
	BuildNumber = 19045
	Ubr = 7058
	Architecture = '64-bit'
	ReleaseId = '22H2'
}

$script:ProtectedRoots = @(
	"$env:USERPROFILE\Documents",
	"$env:USERPROFILE\Pictures",
	"$env:USERPROFILE\Videos",
	"$env:USERPROFILE\Desktop",
	"$env:USERPROFILE\Downloads",
	"$env:APPDATA",
	"$env:LOCALAPPDATA\Packages",
	"$env:USERPROFILE\AppData\Roaming\Microsoft\Credentials",
	"$env:LOCALAPPDATA\Microsoft\Credentials",
	"$env:LOCALAPPDATA\Microsoft\Edge\User Data",
	"$env:LOCALAPPDATA\Google\Chrome\User Data",
	"$env:APPDATA\Mozilla\Firefox\Profiles",
	"$env:PROGRAMDATA\Microsoft\Search"
)

$script:SafeUserTempRoots = @(
	"$env:LOCALAPPDATA\Temp",
	"$env:SystemRoot\Temp",
	"$env:TEMP"
)

$script:EssentialServices = @(
	'WinDefend','WdNisSvc','Sense','SecurityHealthService','MpsSvc','BFE','LanmanWorkstation','LanmanServer',
	'Dhcp','Dnscache','NlaSvc','Netprofm','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','ProfSvc','SamSs',
	'LSM','TermService','WSearch','W32Time','wuauserv','UsoSvc','BITS','CryptSvc','TrustedInstaller','Schedule'
)

$script:Result = [ordered]@{
	RunId = $script:RunId
	StartedAt = $script:StartTime
	EndedAt = $null
	User = $script:CurrentUser
	Machine = $script:Machine
	DryRun = [bool]$DryRun
	Force = [bool]$Force
	Interactive = [bool]$script:IsInteractiveMode
	Profile = $OptimizationProfile
	Aggressive = [bool]$Aggressive
	Hardware = $null
	ActionsPerformed = New-Object System.Collections.Generic.List[string]
	ActionsSkipped = New-Object System.Collections.Generic.List[string]
	ActionsFailed = New-Object System.Collections.Generic.List[string]
	FilesRemoved = New-Object System.Collections.Generic.List[string]
	ServicesChanged = New-Object System.Collections.Generic.List[object]
	DriversBackedUp = New-Object System.Collections.Generic.List[string]
	DriversRemoved = New-Object System.Collections.Generic.List[string]
	SfcResult = $null
	DismResult = $null
	Recommendations = New-Object System.Collections.Generic.List[string]
	BackupArtifacts = New-Object System.Collections.Generic.List[string]
	ManifestArtifacts = New-Object System.Collections.Generic.List[string]
}

function Initialize-RunFolders {
	New-Item -Path $script:RunRoot -ItemType Directory -Force | Out-Null
	New-Item -Path $script:ManifestRoot -ItemType Directory -Force | Out-Null
	New-Item -Path $script:BackupRoot -ItemType Directory -Force | Out-Null
}

function Write-Log {
	param(
		[Parameter(Mandatory)][string]$Message,
		[ValidateSet('INFO','WARN','ERROR','SUCCESS','DEBUG')]
		[string]$Level = 'INFO',
		[string]$Category = 'General'
	)

	$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
	$line = "[$ts] [$Level] [Run:$script:RunId] [User:$script:CurrentUser] [Host:$script:Machine] [$Category] $Message"
	Add-Content -Path $script:LogPath -Value $line
	if ($Level -in @('ERROR','WARN')) {
		Write-Host $line -ForegroundColor Yellow
	}
	elseif ($Level -eq 'SUCCESS') {
		Write-Host $line -ForegroundColor Green
	}
	else {
		Write-Host $line
	}
}

function Add-ActionResult {
	param(
		[Parameter(Mandatory)][string]$Action,
		[ValidateSet('Performed','Skipped','Failed')]
		[string]$Status,
		[string]$Reason
	)

	switch ($Status) {
		'Performed' { $script:Result.ActionsPerformed.Add($Action) }
		'Skipped' {
			$skippedText = $Action
			if ($Reason) {
				$skippedText = "$Action ($Reason)"
			}
			$script:Result.ActionsSkipped.Add($skippedText)
		}
		'Failed' {
			$failedText = $Action
			if ($Reason) {
				$failedText = "$Action ($Reason)"
			}
			$script:Result.ActionsFailed.Add($failedText)
			if ($script:ExitCode -lt 1) { $script:ExitCode = 1 }
		}
	}
}

function Test-IsAdministrator {
	try {
		$id = [Security.Principal.WindowsIdentity]::GetCurrent()
		$principal = [Security.Principal.WindowsPrincipal]::new($id)
		return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch {
		Write-Log -Message "Failed to evaluate admin role: $($_.Exception.Message)" -Level 'ERROR' -Category 'Preflight'
		return $false
	}
}

function Assert-Administrator {
	if (-not (Test-IsAdministrator)) {
		Write-Log -Message 'Administrator privileges are required. Re-run from an elevated PowerShell session.' -Level 'ERROR' -Category 'Preflight'
		$script:ExitCode = 2
		throw 'Not elevated.'
	}
}

function Get-OsFacts {
	$os = Get-CimInstance Win32_OperatingSystem
	$cs = Get-CimInstance Win32_ComputerSystem
	$cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

	[ordered]@{
		Caption = $os.Caption
		BuildNumber = [int]$os.BuildNumber
		Ubr = [int]$cv.UBR
		ProductName = [string]$cv.ProductName
		DisplayVersion = [string]$cv.DisplayVersion
		Architecture = [string]$os.OSArchitecture
		DomainRole = [int]$cs.DomainRole
	}
}

function Assert-OsCompatibility {
	$facts = Get-OsFacts
	$isMatch = $true
	if ($facts.ProductName -notlike '*Windows 10 Pro*') { $isMatch = $false }
	if ($facts.BuildNumber -ne $script:TargetOS.BuildNumber) { $isMatch = $false }
	if ($facts.Ubr -ne $script:TargetOS.Ubr) { $isMatch = $false }
	if ($facts.Architecture -notlike '*64*') { $isMatch = $false }
	if ($facts.DisplayVersion -ne $script:TargetOS.ReleaseId) { $isMatch = $false }

	if (-not $isMatch) {
		$msg = "OS mismatch. Required: Windows 10 Pro 22H2 build 19045.7058 x64. Detected: $($facts.ProductName) $($facts.DisplayVersion) build $($facts.BuildNumber).$($facts.Ubr) $($facts.Architecture)."
		if ($OverrideOSCheck) {
			Write-Log -Message "$msg Continuing due to -OverrideOSCheck." -Level 'WARN' -Category 'Preflight'
			$script:Result.Recommendations.Add('Ran with OS override; review results carefully for compatibility.')
		}
		else {
			Write-Log -Message $msg -Level 'ERROR' -Category 'Preflight'
			$script:ExitCode = 2
			throw 'OS compatibility check failed.'
		}
	}
	else {
		Write-Log -Message 'Target OS check passed.' -Level 'SUCCESS' -Category 'Preflight'
	}
}

function Confirm-Step {
	param(
		[Parameter(Mandatory)][string]$Title,
		[string]$Warning,
		[switch]$Permanent
	)

	if ($Force) {
		Write-Log -Message "Auto-confirmed due to -Force: $Title" -Category 'Confirm'
		return $true
	}

	if (-not $script:IsInteractiveMode) {
		Write-Log -Message "Non-interactive mode without -Force: skipping '$Title'." -Level 'WARN' -Category 'Confirm'
		return $false
	}

	$prompt = $Title
	if ($Permanent) {
		$prompt = "[PERMANENT] $Title"
	}
	if ($Warning) {
		Write-Host "WARNING: $Warning" -ForegroundColor Yellow
	}
	$choice = Read-Host "$prompt (Y/N)"
	return $choice -match '^(Y|y|Yes|YES)$'
}

function Test-PathAllowListed {
	param([Parameter(Mandatory)][string]$Path)

	foreach ($allowed in $AllowListPath) {
		if ([string]::IsNullOrWhiteSpace($allowed)) { continue }
		try {
			$resolvedAllowed = [IO.Path]::GetFullPath($allowed)
			$resolvedPath = [IO.Path]::GetFullPath($Path)
			if ($resolvedPath.StartsWith($resolvedAllowed, [System.StringComparison]::OrdinalIgnoreCase)) {
				return $true
			}
		}
		catch {
			continue
		}
	}
	return $false
}

function Test-ProtectedPath {
	param([Parameter(Mandatory)][string]$Path)

	try {
		$full = [IO.Path]::GetFullPath($Path)
	}
	catch {
		return $true
	}

	foreach ($root in $script:ProtectedRoots) {
		if ([string]::IsNullOrWhiteSpace($root)) { continue }
		$resolvedRoot = [IO.Path]::GetFullPath($root)
		if ($full.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
			if (Test-PathAllowListed -Path $full) {
				return $false
			}
			return $true
		}
	}
	return $false
}

function Export-Manifest {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][System.Collections.IEnumerable]$Items
	)

	$rows = foreach ($item in $Items) {
		if ($null -eq $item) { continue }
		if ($item -is [string]) {
			[PSCustomObject]@{
				Path = $item
				Exists = Test-Path -LiteralPath $item
				Timestamp = (Get-Date)
			}
		}
		else {
			$item
		}
	}

	$jsonPath = Join-Path $script:ManifestRoot "$Name.json"
	$csvPath = Join-Path $script:ManifestRoot "$Name.csv"

	$rows | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
	$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
	$script:Result.ManifestArtifacts.Add($jsonPath)
	$script:Result.ManifestArtifacts.Add($csvPath)
	Write-Log -Message "Manifest exported: $jsonPath ; $csvPath" -Category 'Manifest'
}

function Invoke-ExternalCommand {
	param(
		[Parameter(Mandatory)][string]$FilePath,
		[Parameter()][string[]]$ArgumentList = @(),
		[Parameter(Mandatory)][string]$Name
	)

	$stdOut = Join-Path $script:RunRoot "$Name.stdout.log"
	$stdErr = Join-Path $script:RunRoot "$Name.stderr.log"

	if ($DryRun) {
		Write-Log -Message "[DryRun] Would run: $FilePath $($ArgumentList -join ' ')" -Category 'Command'
		return [PSCustomObject]@{ ExitCode = 0; StdOut = $stdOut; StdErr = $stdErr; DryRun = $true }
	}

	$proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
	Write-Log -Message "Command completed [$Name] ExitCode=$($proc.ExitCode). Output: $stdOut" -Category 'Command'

	[PSCustomObject]@{
		ExitCode = $proc.ExitCode
		StdOut = $stdOut
		StdErr = $stdErr
		DryRun = $false
	}
}

function Test-PendingReboot {
	$keys = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
		'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
	)
	$pending = $false
	foreach ($key in $keys) {
		if (Test-Path -LiteralPath $key) {
			if ($key -like '*Session Manager') {
				$value = (Get-ItemProperty -Path $key -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
				if ($value) { $pending = $true }
			}
			else {
				$pending = $true
			}
		}
	}
	return $pending
}

function Test-UpdateInProgress {
	$procs = @('TiWorker','TrustedInstaller','MoUsoCoreWorker','MusNotification','wuauclt')
	foreach ($name in $procs) {
		if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
			return $true
		}
	}
	return $false
}

function Assert-UpdateSafeState {
	$pendingReboot = Test-PendingReboot
	$updateBusy = Test-UpdateInProgress

	if ($pendingReboot -or $updateBusy) {
		$reason = @()
		if ($pendingReboot) { $reason += 'pending reboot detected' }
		if ($updateBusy) { $reason += 'update installation currently active' }
		$message = "Update-safe-state check failed: $($reason -join '; ')."
		Write-Log -Message $message -Level 'ERROR' -Category 'Preflight'
		Write-Log -Message 'Abort and re-run after reboot/update completion. Optionally schedule this script post-reboot.' -Level 'WARN' -Category 'Preflight'
		$script:ExitCode = 2
		throw $message
	}
}

function Test-FreeSpace {
	param(
		[int]$MinimumGB = 2,
		[string]$DriveLetter = ($env:SystemDrive -replace ':','')
	)
	$drive = Get-PSDrive -Name $DriveLetter
	return ($drive.Free / 1GB) -ge $MinimumGB
}

function New-SystemRestorePoint {
	$desc = "Optimize-Windows-$script:Stamp"
	try {
		if ($DryRun) {
			Write-Log -Message "[DryRun] Would create system restore point: $desc" -Category 'RestorePoint'
			Add-ActionResult -Action 'System restore point' -Status 'Skipped' -Reason 'DryRun'
			return
		}

		if (-not (Test-FreeSpace -MinimumGB 2)) {
			throw 'Insufficient disk space for reliable safety backups/restore operations (<2 GB free on current drive).'
		}

		Checkpoint-Computer -Description $desc -RestorePointType 'MODIFY_SETTINGS' | Out-Null
		Write-Log -Message 'System restore point created successfully.' -Level 'SUCCESS' -Category 'RestorePoint'
		Add-ActionResult -Action 'System restore point' -Status 'Performed'
	}
	catch {
		$msg = "System restore point unavailable: $($_.Exception.Message)"
		if ($OverrideSafety) {
			Write-Log -Message "$msg Continuing due to -OverrideSafety." -Level 'WARN' -Category 'RestorePoint'
			Add-ActionResult -Action 'System restore point' -Status 'Skipped' -Reason 'OverrideSafety'
			$script:Result.Recommendations.Add('Restore point was not created; ensure offline backup exists before future runs.')
		}
		else {
			Write-Log -Message "$msg Use -OverrideSafety to continue without restore point." -Level 'ERROR' -Category 'RestorePoint'
			$script:ExitCode = 2
			throw 'Restore point requirement not met.'
		}
	}
}

function Get-HardwareProfile {
	$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
	$mem = Get-CimInstance Win32_ComputerSystem
	$disks = Get-CimInstance Win32_DiskDrive

	$storageType = 'Unknown'
	if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
		$media = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MediaType -ErrorAction SilentlyContinue
		if ($media -contains 'SSD') { $storageType = 'SSD' }
		elseif ($media -contains 'HDD' -or $media -contains 'Unspecified') { $storageType = 'HDD' }
	}
	elseif ($disks.Model -match 'SSD|NVMe') {
		$storageType = 'SSD'
	}
	elseif ($disks) {
		$storageType = 'HDD'
	}

	$ramGb = [math]::Round(($mem.TotalPhysicalMemory / 1GB), 2)
	$aggressiveness = 'Balanced'
	if ($Aggressive) {
		$aggressiveness = 'Aggressive'
	}
	elseif ($ramGb -lt 8 -or $storageType -eq 'HDD') {
		$aggressiveness = 'Conservative'
	}

	$obj = [PSCustomObject]@{
		CpuCores = [int]$cpu.NumberOfCores
		LogicalProcessors = [int]$cpu.NumberOfLogicalProcessors
		RamGB = $ramGb
		StorageType = $storageType
		Aggressiveness = $aggressiveness
	}
	$script:Result.Hardware = $obj
	Write-Log -Message "Hardware profile: Cores=$($obj.CpuCores), RAM=$($obj.RamGB)GB, Storage=$($obj.StorageType), Mode=$($obj.Aggressiveness)." -Category 'Hardware'
}

function Get-SafeDeletionTargets {
	param(
		[Parameter(Mandatory)][string[]]$Roots,
		[int]$OlderThanDays = 0
	)

	$threshold = (Get-Date).AddDays(-$OlderThanDays)
	$targets = New-Object System.Collections.Generic.List[string]
	foreach ($root in $Roots) {
		if (-not (Test-Path -LiteralPath $root)) { continue }
		try {
			$items = Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue
			foreach ($item in $items) {
				if ($item.PSIsContainer) { continue }
				if ($OlderThanDays -gt 0 -and $item.LastWriteTime -gt $threshold) { continue }
				if (Test-ProtectedPath -Path $item.FullName) { continue }
				$targets.Add($item.FullName)
			}
		}
		catch {
			Write-Log -Message "Failed enumerating $root : $($_.Exception.Message)" -Level 'WARN' -Category 'Cleanup'
		}
	}
	return $targets
}

function Remove-TargetsWithManifest {
	param(
		[Parameter(Mandatory)][string]$ActionName,
		[Parameter(Mandatory)][System.Collections.Generic.List[string]]$Targets,
		[string]$Category = 'Cleanup'
	)

	if ($Targets.Count -eq 0) {
		Write-Log -Message "No targets found for $ActionName." -Category $Category
		Add-ActionResult -Action $ActionName -Status 'Skipped' -Reason 'NoTargets'
		return
	}

	Export-Manifest -Name ($ActionName -replace '\s+','_') -Items $Targets

	if ($DryRun) {
		Write-Log -Message "[DryRun] Would remove $($Targets.Count) items for '$ActionName'." -Category $Category
		Add-ActionResult -Action $ActionName -Status 'Skipped' -Reason 'DryRun'
		return
	}

	$removed = 0
	foreach ($target in $Targets) {
		try {
			Remove-Item -LiteralPath $target -Force -ErrorAction Stop
			$script:Result.FilesRemoved.Add($target)
			$removed++
		}
		catch {
			Write-Log -Message "Failed removing $target : $($_.Exception.Message)" -Level 'WARN' -Category $Category
		}
	}

	Write-Log -Message "Removed $removed items for '$ActionName'." -Category $Category
	Add-ActionResult -Action $ActionName -Status 'Performed'
}

function Invoke-SystemFileValidation {
	Write-Log -Message 'Starting system file validation (SFC + DISM RestoreHealth).' -Category 'Health'
	try {
		$sfc = Invoke-ExternalCommand -FilePath 'sfc.exe' -ArgumentList @('/scannow') -Name 'sfc_scannow'
		$dism = Invoke-ExternalCommand -FilePath 'dism.exe' -ArgumentList @('/Online','/Cleanup-Image','/RestoreHealth') -Name 'dism_restorehealth'
		$script:Result.SfcResult = $sfc
		$script:Result.DismResult = $dism
		Add-ActionResult -Action 'System file validation' -Status 'Performed'
	}
	catch {
		Write-Log -Message "System file validation failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Health'
		Add-ActionResult -Action 'System file validation' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-ComponentStoreCleanup {
	Write-Log -Message 'Running component store cleanup.' -Category 'DISM'
	try {
		Invoke-ExternalCommand -FilePath 'dism.exe' -ArgumentList @('/Online','/Cleanup-Image','/StartComponentCleanup') -Name 'dism_startcomponentcleanup' | Out-Null
		Add-ActionResult -Action 'Component store cleanup' -Status 'Performed'

		if (Confirm-Step -Title 'Run DISM /ResetBase (permanent; uninstall rollback for superseded components becomes unavailable)' -Warning 'This is permanent for superseded component versions.' -Permanent) {
			$reset = Invoke-ExternalCommand -FilePath 'dism.exe' -ArgumentList @('/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase') -Name 'dism_resetbase'
			if ($reset.ExitCode -eq 0) {
				Add-ActionResult -Action 'Component cleanup ResetBase' -Status 'Performed'
			}
			else {
				Add-ActionResult -Action 'Component cleanup ResetBase' -Status 'Failed' -Reason "ExitCode=$($reset.ExitCode)"
			}
		}
		else {
			Add-ActionResult -Action 'Component cleanup ResetBase' -Status 'Skipped' -Reason 'UserDeclined'
		}
	}
	catch {
		Write-Log -Message "Component cleanup error: $($_.Exception.Message)" -Level 'ERROR' -Category 'DISM'
		Add-ActionResult -Action 'Component store cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-WindowsUpdateCleanup {
	Write-Log -Message 'Preparing Windows Update cache cleanup.' -Category 'WindowsUpdate'
	$downloadPath = Join-Path $env:SystemRoot 'SoftwareDistribution\Download'

	try {
		Assert-UpdateSafeState

		if (-not (Confirm-Step -Title "Clear Windows Update download cache at $downloadPath" -Warning 'Ensures no active update operation first.')) {
			Add-ActionResult -Action 'Windows Update download cache cleanup' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}

		if (-not (Test-Path -LiteralPath $downloadPath)) {
			Add-ActionResult -Action 'Windows Update download cache cleanup' -Status 'Skipped' -Reason 'PathMissing'
			return
		}

		$targets = Get-ChildItem -LiteralPath $downloadPath -Force -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object FullName
		$targetList = New-Object System.Collections.Generic.List[string]
		foreach ($t in $targets) { if (-not (Test-ProtectedPath -Path $t)) { $targetList.Add($t) } }

		if (-not $DryRun) {
			Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
			Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
		}

		Remove-TargetsWithManifest -ActionName 'Windows Update Download Cache' -Targets $targetList -Category 'WindowsUpdate'

		if (-not $DryRun) {
			Start-Service -Name bits -ErrorAction SilentlyContinue
			Start-Service -Name wuauserv -ErrorAction SilentlyContinue
		}
	}
	catch {
		Write-Log -Message "Windows Update cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'WindowsUpdate'
		Add-ActionResult -Action 'Windows Update download cache cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-DeliveryOptimizationCleanup {
	$doPath = Join-Path $env:SystemRoot 'SoftwareDistribution\DeliveryOptimization'
	Write-Log -Message "Preparing Delivery Optimization cleanup at $doPath" -Category 'DeliveryOptimization'
	try {
		if (-not (Confirm-Step -Title 'Clear Delivery Optimization cache' -Warning 'This will remove locally cached delivery optimization content.')) {
			Add-ActionResult -Action 'Delivery Optimization cache cleanup' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}
		$targets = New-Object System.Collections.Generic.List[string]
		if (Test-Path -LiteralPath $doPath) {
			Get-ChildItem -LiteralPath $doPath -Force -Recurse -ErrorAction SilentlyContinue |
				Where-Object { -not $_.PSIsContainer } |
				ForEach-Object {
					if (-not (Test-ProtectedPath -Path $_.FullName)) { $targets.Add($_.FullName) }
				}
		}
		Remove-TargetsWithManifest -ActionName 'Delivery Optimization Cache' -Targets $targets -Category 'DeliveryOptimization'
	}
	catch {
		Write-Log -Message "Delivery Optimization cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'DeliveryOptimization'
		Add-ActionResult -Action 'Delivery Optimization cache cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-TemporaryFilesCleanup {
	Write-Log -Message "Cleaning temporary files older than $TempAgeDays day(s)." -Category 'Temp'
	try {
		$roots = @($env:SystemRoot + '\Temp', $env:TEMP, "$env:LOCALAPPDATA\Temp") | Select-Object -Unique
		$targets = Get-SafeDeletionTargets -Roots $roots -OlderThanDays $TempAgeDays
		Remove-TargetsWithManifest -ActionName 'Temporary Files Cleanup' -Targets $targets -Category 'Temp'
	}
	catch {
		Write-Log -Message "Temporary cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Temp'
		Add-ActionResult -Action 'Temporary files cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-ThumbnailAndBrowserCacheCleanup {
	Write-Log -Message 'Preparing thumbnail and browser cache cleanup.' -Category 'Cache'
	try {
		$browserProcesses = Get-Process -Name msedge,chrome,firefox -ErrorAction SilentlyContinue
		$warn = 'Only cache paths will be targeted; profile/account data is excluded.'
		if ($browserProcesses) {
			$warn = 'Browser processes are running; signed-in session data may be active. Cached web content only will be targeted.'
		}
		if (-not (Confirm-Step -Title 'Clear thumbnail and browser cache files (not profiles, not credentials)' -Warning $warn)) {
			Add-ActionResult -Action 'Thumbnail and browser cache cleanup' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}

		$paths = @(
			"$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
			"$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
			"$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
			"$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
		)

		$targets = New-Object System.Collections.Generic.List[string]
		foreach ($path in $paths) {
			if (-not (Test-Path -LiteralPath $path)) { continue }
			if ($path -like '*Firefox\Profiles') {
				Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
					$firefoxCache = Join-Path $_.FullName 'cache2'
					if (Test-Path -LiteralPath $firefoxCache) {
						Get-ChildItem -LiteralPath $firefoxCache -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
							$targets.Add($_.FullName)
						}
					}
				}
				continue
			}
			if ($path -like '*Windows\Explorer') {
				Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'thumbcache*' } | ForEach-Object {
					$targets.Add($_.FullName)
				}
				continue
			}
			Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
				$targets.Add($_.FullName)
			}
		}

		Remove-TargetsWithManifest -ActionName 'Thumbnail_Browser_Cache_Cleanup' -Targets $targets -Category 'Cache'
	}
	catch {
		Write-Log -Message "Cache cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Cache'
		Add-ActionResult -Action 'Thumbnail and browser cache cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-RecycleBinCleanup {
	try {
		if (-not (Confirm-Step -Title 'Empty Recycle Bin' -Warning 'Items in Recycle Bin will be removed.')) {
			Add-ActionResult -Action 'Recycle Bin cleanup' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}
		if ($DryRun) {
			Write-Log -Message '[DryRun] Would empty Recycle Bin.' -Category 'RecycleBin'
			Add-ActionResult -Action 'Recycle Bin cleanup' -Status 'Skipped' -Reason 'DryRun'
			return
		}
		Clear-RecycleBin -Force -ErrorAction Stop
		Write-Log -Message 'Recycle Bin emptied.' -Level 'SUCCESS' -Category 'RecycleBin'
		Add-ActionResult -Action 'Recycle Bin cleanup' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Recycle Bin cleanup failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'RecycleBin'
		Add-ActionResult -Action 'Recycle Bin cleanup' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-PrefetchCleanup {
	if (-not $RemovePrefetch) {
		Add-ActionResult -Action 'Prefetch cleanup' -Status 'Skipped' -Reason 'FlagNotSet'
		return
	}

	if (-not (Confirm-Step -Title 'Remove Prefetch files' -Warning 'Prefetch cleanup can cause short-term slowdown after reboot.')) {
		Add-ActionResult -Action 'Prefetch cleanup' -Status 'Skipped' -Reason 'UserDeclined'
		return
	}

	$path = Join-Path $env:SystemRoot 'Prefetch'
	$targets = New-Object System.Collections.Generic.List[string]
	if (Test-Path -LiteralPath $path) {
		Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue | ForEach-Object { $targets.Add($_.FullName) }
	}
	Remove-TargetsWithManifest -ActionName 'Prefetch Cleanup' -Targets $targets -Category 'Prefetch'
}

function Invoke-SearchIndexRebuild {
	if (-not $RebuildSearchIndex) {
		Add-ActionResult -Action 'Search index rebuild' -Status 'Skipped' -Reason 'FlagNotSet'
		return
	}

	if (-not (Confirm-Step -Title 'Request Windows Search index rebuild' -Warning 'Index rebuild may increase CPU and disk usage temporarily.')) {
		Add-ActionResult -Action 'Search index rebuild' -Status 'Skipped' -Reason 'UserDeclined'
		return
	}

	try {
		if ($DryRun) {
			Write-Log -Message '[DryRun] Would request Windows Search index rebuild via COM interface.' -Category 'Search'
			Add-ActionResult -Action 'Search index rebuild' -Status 'Skipped' -Reason 'DryRun'
			return
		}

		$catalogManager = New-Object -ComObject 'Search.Manager'
		$catalog = $catalogManager.GetCatalog('SystemIndex')
		$catalog.Reindex()
		Add-ActionResult -Action 'Search index rebuild' -Status 'Performed'
		Write-Log -Message 'Search index rebuild requested.' -Category 'Search'
	}
	catch {
		Write-Log -Message "Search index rebuild request failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Search'
		Add-ActionResult -Action 'Search index rebuild' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Export-RegistryBackup {
	param(
		[Parameter(Mandatory)][string]$RegistryPath,
		[Parameter(Mandatory)][string]$Name
	)

	$regPath = $RegistryPath -replace '^HKLM:', 'HKEY_LOCAL_MACHINE' -replace '^HKCU:', 'HKEY_CURRENT_USER'
	$dest = Join-Path $script:BackupRoot "$Name.reg"

	if ($DryRun) {
		Write-Log -Message "[DryRun] Would export registry path $RegistryPath to $dest" -Category 'Registry'
		return $dest
	}

	$result = Invoke-ExternalCommand -FilePath 'reg.exe' -ArgumentList @('export', $regPath, $dest, '/y') -Name "reg_export_$Name"
	if ($result.ExitCode -eq 0) {
		$script:Result.BackupArtifacts.Add($dest)
	}
	return $dest
}

function Invoke-TelemetryRecommendations {
	if (-not $RecommendTelemetryChanges) {
		$script:Result.Recommendations.Add('Telemetry tuning not requested. Consider reviewing diagnostic data level and startup telemetry apps manually.')
		Add-ActionResult -Action 'Telemetry recommendations' -Status 'Skipped' -Reason 'FlagNotSet'
		return
	}

	Write-Log -Message 'Preparing conservative telemetry recommendations.' -Category 'Telemetry'
	$script:Result.Recommendations.Add('Suggested: Set diagnostic data to Required only (Basic).')
	$script:Result.Recommendations.Add('Suggested: Review startup telemetry apps and scheduled tasks before disabling.')

	if (-not (Confirm-Step -Title 'Apply conservative diagnostic data setting changes' -Warning 'Changes are reversible; registry backup will be exported first.')) {
		Add-ActionResult -Action 'Telemetry settings change' -Status 'Skipped' -Reason 'UserDeclined'
		return
	}

	try {
		$backup = Export-RegistryBackup -RegistryPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DataCollection_backup'
		if (-not $DryRun) {
			New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
			Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type DWord -Value 1
		}
		Write-Log -Message "Telemetry policy updated (AllowTelemetry=1). Backup: $backup" -Category 'Telemetry'
		Add-ActionResult -Action 'Telemetry settings change' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Telemetry settings update failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Telemetry'
		Add-ActionResult -Action 'Telemetry settings change' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Get-ServiceStartupRecommendations {
	$services = Get-Service | Sort-Object Status, DisplayName
	$startupCommands = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
	$weights = @{ Gaming = 3; Office = 2; Development = 1 }
	$profileWeight = $weights[$OptimizationProfile]

	$candidates = foreach ($svc in $services) {
		if ($script:EssentialServices -contains $svc.Name) { continue }
		if ($svc.Status -ne 'Running') { continue }
		$score = 1
		if ($svc.Name -match 'OEM|Updater|Update|Telemetry|Diag|Assistant') { $score += 2 }
		if ($OptimizationProfile -eq 'Gaming' -and $svc.Name -match 'Xbox|Game') { $score += 2 }
		if ($OptimizationProfile -eq 'Development' -and $svc.Name -match 'Docker|Hyper|WSL') { $score -= 2 }
		if ($score -lt $profileWeight) { continue }
		$priority = 'Medium'
		if ($score -ge 3) {
			$priority = 'High'
		}
		[PSCustomObject]@{
			Type = 'Service'
			Name = $svc.Name
			DisplayName = $svc.DisplayName
			Status = [string]$svc.Status
			RecommendedAction = 'SetStartupTypeManual'
			Priority = $priority
			Description = (Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue).Description
		}
	}

	$startup = foreach ($cmd in $startupCommands) {
		if ($cmd.Name -match 'Security|Defender|OneDrive|Windows') { continue }
		[PSCustomObject]@{
			Type = 'StartupApp'
			Name = $cmd.Name
			DisplayName = $cmd.Caption
			Status = 'Enabled'
			RecommendedAction = 'DisableStartupEntry'
			Priority = 'Medium'
			Description = $cmd.Command
			Location = $cmd.Location
		}
	}

	$recommendations = @($candidates + $startup | Sort-Object Priority)
	$path = Join-Path $script:RunRoot 'service_startup_recommendations.json'
	$recommendations | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
	Write-Log -Message "Service/startup recommendations exported: $path" -Category 'Optimization'
	return $recommendations
}

function Disable-StartupCommandEntry {
	param(
		[Parameter(Mandatory)][string]$EntryName,
		[string]$Location
	)

	$targets = @(
		'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
		'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
		'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
	)

	foreach ($target in $targets) {
		if (-not (Test-Path -LiteralPath $target)) { continue }
		$props = Get-ItemProperty -Path $target -ErrorAction SilentlyContinue
		if ($null -ne $props.PSObject.Properties[$EntryName]) {
			Remove-ItemProperty -Path $target -Name $EntryName -ErrorAction Stop
			return $true
		}
	}

	Write-Log -Message "Startup entry '$EntryName' could not be disabled automatically. Location: $Location" -Level 'WARN' -Category 'Optimization'
	return $false
}

function Invoke-ServiceStartupOptimization {
	Write-Log -Message "Analyzing services/startup candidates for profile '$OptimizationProfile'." -Category 'Optimization'
	try {
		$recs = Get-ServiceStartupRecommendations
		if (-not $recs -or $recs.Count -eq 0) {
			Add-ActionResult -Action 'Service/startup optimization analysis' -Status 'Skipped' -Reason 'NoCandidates'
			return
		}

		$previewPath = Join-Path $script:RunRoot 'service_startup_candidates.csv'
		$recs | Export-Csv -Path $previewPath -NoTypeInformation -Encoding UTF8

		foreach ($rec in $recs) {
			$title = "Apply recommendation: [$($rec.Type)] $($rec.Name) -> $($rec.RecommendedAction)"
			if (-not (Confirm-Step -Title $title -Warning 'Essential networking/auth/search/update/security services are protected.')) {
				continue
			}

			if ($DryRun) {
				Write-Log -Message "[DryRun] Would apply recommendation to $($rec.Name)." -Category 'Optimization'
				continue
			}

			if ($rec.Type -eq 'Service' -and $script:EssentialServices -notcontains $rec.Name) {
				Set-Service -Name $rec.Name -StartupType Manual -ErrorAction Stop
				$change = [PSCustomObject]@{ Name = $rec.Name; Action = 'StartupType=Manual'; Timestamp = Get-Date }
				$script:Result.ServicesChanged.Add($change)
			}
			elseif ($rec.Type -eq 'StartupApp') {
				if (Disable-StartupCommandEntry -EntryName $rec.Name -Location $rec.Location) {
					$change = [PSCustomObject]@{ Name = $rec.Name; Action = 'StartupEntryDisabled'; Timestamp = Get-Date }
					$script:Result.ServicesChanged.Add($change)
				}
			}
		}

		Add-ActionResult -Action 'Service/startup optimization analysis' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Service/startup optimization failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Optimization'
		Add-ActionResult -Action 'Service/startup optimization analysis' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Get-DriverInventory {
	$resultPath = Join-Path $script:RunRoot 'drivers_inventory_raw.txt'
	if ($DryRun) {
		Write-Log -Message '[DryRun] Would enumerate drivers using pnputil /enum-drivers.' -Category 'Drivers'
		return @()
	}

	$raw = & pnputil.exe /enum-drivers 2>&1
	$raw | Set-Content -Path $resultPath -Encoding UTF8

	$drivers = New-Object System.Collections.Generic.List[object]
	$current = [ordered]@{}
	foreach ($line in $raw) {
		if ($line -match '^Published Name\s*:\s*(.+)$') {
			if ($current.Count -gt 0) {
				$drivers.Add([PSCustomObject]$current)
				$current = [ordered]@{}
			}
			$current.PublishedName = $Matches[1].Trim()
		}
		elseif ($line -match '^Original Name\s*:\s*(.+)$') { $current.OriginalName = $Matches[1].Trim() }
		elseif ($line -match '^Provider Name\s*:\s*(.+)$') { $current.ProviderName = $Matches[1].Trim() }
		elseif ($line -match '^Class Name\s*:\s*(.+)$') { $current.ClassName = $Matches[1].Trim() }
		elseif ($line -match '^Driver Version\s*:\s*(.+)$') { $current.DriverVersion = $Matches[1].Trim() }
		elseif ($line -match '^Signer Name\s*:\s*(.+)$') { $current.SignerName = $Matches[1].Trim() }
	}
	if ($current.Count -gt 0) { $drivers.Add([PSCustomObject]$current) }
	return $drivers
}

function Invoke-DriverManagement {
	Write-Log -Message 'Starting driver inventory and duplicate analysis.' -Category 'Drivers'
	try {
		$drivers = Get-DriverInventory
		$csv = Join-Path $script:RunRoot 'drivers_inventory.csv'
		$json = Join-Path $script:RunRoot 'drivers_inventory.json'
		$drivers | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
		$drivers | ConvertTo-Json -Depth 6 | Set-Content -Path $json -Encoding UTF8
		Write-Log -Message "Driver inventory exported: $csv ; $json" -Category 'Drivers'

		$dupes = $drivers | Where-Object { $_.OriginalName } | Group-Object OriginalName | Where-Object { $_.Count -gt 1 }
		if ($dupes) {
			$dupPath = Join-Path $script:RunRoot 'duplicate_drivers.csv'
			$dupes | ForEach-Object {
				$_.Group | Select-Object OriginalName, PublishedName, ProviderName, DriverVersion, ClassName
			} | Export-Csv -Path $dupPath -NoTypeInformation -Encoding UTF8
			Write-Log -Message "Duplicate drivers listed: $dupPath" -Level 'WARN' -Category 'Drivers'

			if (Confirm-Step -Title 'Review duplicate drivers for optional removal now' -Warning 'No driver will be removed automatically without explicit confirmation.') {
				foreach ($dup in $dupes) {
					foreach ($entry in $dup.Group) {
						$title = "Remove duplicate driver $($entry.PublishedName) ($($entry.OriginalName))"
						if (-not (Confirm-Step -Title $title -Warning 'Driver removal can affect hardware functionality. Backup will be created first.')) { continue }

						$backupDir = Join-Path $script:BackupRoot "Drivers_$script:Stamp"
						if (-not $DryRun) {
							New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
							try {
								if (Get-Command Export-WindowsDriver -ErrorAction SilentlyContinue) {
									Export-WindowsDriver -Online -Destination $backupDir | Out-Null
								}
								else {
									# Fallback when Export-WindowsDriver cmdlet is unavailable.
									& pnputil.exe /export-driver * $backupDir | Out-Null
								}
							}
							catch {
								Write-Log -Message "Driver backup failed before removal: $($_.Exception.Message)" -Level 'ERROR' -Category 'Drivers'
								continue
							}
							$script:Result.DriversBackedUp.Add($backupDir)

							$removeResult = Invoke-ExternalCommand -FilePath 'pnputil.exe' -ArgumentList @('/delete-driver', $entry.PublishedName, '/uninstall') -Name "driver_remove_$($entry.PublishedName)"
							if ($removeResult.ExitCode -eq 0) {
								$script:Result.DriversRemoved.Add($entry.PublishedName)
							}
						}
						else {
							Write-Log -Message "[DryRun] Would backup drivers and remove duplicate $($entry.PublishedName)." -Category 'Drivers'
						}
					}
				}
			}
		}

		Add-ActionResult -Action 'Driver inventory and duplicate analysis' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Driver analysis failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Drivers'
		Add-ActionResult -Action 'Driver inventory and duplicate analysis' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Get-DriverUpdateRecommendations {
	$report = Join-Path $script:RunRoot 'driver_update_recommendations.json'
	try {
		if (Get-Command -Name Get-WindowsUpdate -ErrorAction SilentlyContinue) {
			if ($DryRun) {
				$updates = @([PSCustomObject]@{ Source='PSWindowsUpdate'; Title='Driver update scan would run in non-DryRun mode.' })
			}
			else {
				$updates = Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -IgnoreReboot -ErrorAction Stop |
					Select-Object Title, KB, Size, LastDeploymentChangeTime
			}
			$updates | ConvertTo-Json -Depth 5 | Set-Content -Path $report -Encoding UTF8
			return $updates
		}

		# Limitation: native COM API gives less-rich metadata than PSWindowsUpdate, but avoids non-default dependency.
		$session = New-Object -ComObject 'Microsoft.Update.Session'
		$searcher = $session.CreateUpdateSearcher()
		$criteria = "IsInstalled=0 and Type='Driver'"
		$searchResult = $searcher.Search($criteria)
		$updates = for ($i=0; $i -lt $searchResult.Updates.Count; $i++) {
			$u = $searchResult.Updates.Item($i)
			[PSCustomObject]@{
				Source = 'WindowsUpdateCOM'
				Title = $u.Title
				IsDownloaded = $u.IsDownloaded
				RebootRequired = $u.RebootRequired
			}
		}
		$updates | ConvertTo-Json -Depth 5 | Set-Content -Path $report -Encoding UTF8
		return $updates
	}
	catch {
		Write-Log -Message "Driver update recommendation query failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Drivers'
		return @()
	}
}

function Invoke-DriverAutoUpdate {
	$updates = Get-DriverUpdateRecommendations
	if (-not $updates -or $updates.Count -eq 0) {
		Add-ActionResult -Action 'Driver update installation' -Status 'Skipped' -Reason 'NoUpdates'
		return
	}

	if (-not $AutoUpdateDrivers) {
		Write-Log -Message 'Driver updates available; AutoUpdateDrivers not set. See recommendation report.' -Category 'Drivers'
		Add-ActionResult -Action 'Driver update installation' -Status 'Skipped' -Reason 'FlagNotSet'
		return
	}

	if (-not (Confirm-Step -Title 'Install driver updates from Windows Update channel only' -Warning 'No third-party vendor installers will be invoked. Drivers will be backed up first.')) {
		Add-ActionResult -Action 'Driver update installation' -Status 'Skipped' -Reason 'UserDeclined'
		return
	}

	$backupDir = Join-Path $script:BackupRoot "Drivers_PreUpdate_$script:Stamp"
	if ($DryRun) {
		Write-Log -Message "[DryRun] Would backup drivers to $backupDir and install Windows Update driver updates." -Category 'Drivers'
		Add-ActionResult -Action 'Driver update installation' -Status 'Skipped' -Reason 'DryRun'
		return
	}

	try {
		New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
		if (Get-Command Export-WindowsDriver -ErrorAction SilentlyContinue) {
			Export-WindowsDriver -Online -Destination $backupDir | Out-Null
		}
		else {
			& pnputil.exe /export-driver * $backupDir | Out-Null
		}
		$script:Result.DriversBackedUp.Add($backupDir)

		if (Get-Command -Name Install-WindowsUpdate -ErrorAction SilentlyContinue) {
			Install-WindowsUpdate -MicrosoftUpdate -Category Drivers -AcceptAll -IgnoreReboot -ErrorAction Stop | Out-Null
		}
		else {
			# Limitation fallback: COM installation path may install only updates surfaced in current scan and can provide limited progress details.
			$session = New-Object -ComObject 'Microsoft.Update.Session'
			$searcher = $session.CreateUpdateSearcher()
			$sr = $searcher.Search("IsInstalled=0 and Type='Driver'")
			if ($sr.Updates.Count -gt 0) {
				$coll = New-Object -ComObject 'Microsoft.Update.UpdateColl'
				for ($i=0; $i -lt $sr.Updates.Count; $i++) { [void]$coll.Add($sr.Updates.Item($i)) }
				$downloader = $session.CreateUpdateDownloader()
				$downloader.Updates = $coll
				[void]$downloader.Download()
				$installer = $session.CreateUpdateInstaller()
				$installer.Updates = $coll
				[void]$installer.Install()
			}
		}

		Add-ActionResult -Action 'Driver update installation' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Driver update installation failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Drivers'
		Add-ActionResult -Action 'Driver update installation' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Get-BloatwareCandidates {
	$safeNames = @(
		'Microsoft.BingNews',
		'Microsoft.BingWeather',
		'Microsoft.GetHelp',
		'Microsoft.Getstarted',
		'Microsoft.MicrosoftOfficeHub',
		'Microsoft.MicrosoftSolitaireCollection',
		'Microsoft.People',
		'Microsoft.SkypeApp',
		'Microsoft.Xbox.TCUI',
		'Microsoft.XboxGamingOverlay',
		'Microsoft.XboxGameOverlay',
		'Microsoft.XboxIdentityProvider',
		'Microsoft.XboxSpeechToTextOverlay',
		'Microsoft.ZuneMusic',
		'Microsoft.ZuneVideo'
	)

	$all = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
	$all | Where-Object { $safeNames -contains $_.Name } | Select-Object Name, PackageFullName, Publisher, InstallLocation
}

function Invoke-BloatwareWorkflow {
	try {
		$inventoryPath = Join-Path $script:BackupRoot 'appx_inventory_before.json'
		$all = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, PackageFullName, NonRemovable, SignatureKind
		$all | ConvertTo-Json -Depth 5 | Set-Content -Path $inventoryPath -Encoding UTF8
		$script:Result.BackupArtifacts.Add($inventoryPath)

		$candidates = Get-BloatwareCandidates
		$preview = Join-Path $script:RunRoot 'bloatware_candidates.csv'
		$candidates | Export-Csv -Path $preview -NoTypeInformation -Encoding UTF8

		if ($PreviewBloatRemoval -or -not $RemoveBloat) {
			Write-Log -Message "Bloatware preview exported: $preview" -Category 'Bloatware'
			$skipReason = 'FlagNotSet'
			if ($RemoveBloat) {
				$skipReason = 'PreviewOnly'
			}
			Add-ActionResult -Action 'Bloatware removal' -Status 'Skipped' -Reason $skipReason
			return
		}

		if (-not (Confirm-Step -Title 'Remove bloatware candidates from safe list' -Warning 'Core OS/account-critical apps are excluded.')) {
			Add-ActionResult -Action 'Bloatware removal' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}

		$removed = New-Object System.Collections.Generic.List[object]
		foreach ($pkg in $candidates) {
			if ($DryRun) {
				Write-Log -Message "[DryRun] Would remove Appx package: $($pkg.PackageFullName)" -Category 'Bloatware'
				continue
			}

			try {
				Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
				$removed.Add($pkg)
			}
			catch {
				Write-Log -Message "Failed removing package $($pkg.Name): $($_.Exception.Message)" -Level 'WARN' -Category 'Bloatware'
			}
		}

		$removedPath = Join-Path $script:RunRoot 'removed_bloatware.csv'
		$removed | Export-Csv -Path $removedPath -NoTypeInformation -Encoding UTF8
		Add-ActionResult -Action 'Bloatware removal' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Bloatware workflow failed: $($_.Exception.Message)" -Level 'ERROR' -Category 'Bloatware'
		Add-ActionResult -Action 'Bloatware removal' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-PowerPlanOptimization {
	try {
		if (-not (Confirm-Step -Title 'Apply conservative power plan policy (AC=High Performance, Battery=Balanced)' -Warning 'Balanced behavior on battery is preserved by default.')) {
			Add-ActionResult -Action 'Power plan optimization' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}

		if ($DryRun) {
			Write-Log -Message '[DryRun] Would switch active plan based on current power source.' -Category 'Performance'
			Add-ActionResult -Action 'Power plan optimization' -Status 'Skipped' -Reason 'DryRun'
			return
		}

		$battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
		$highPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
		$balancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
		if ($battery) {
			powercfg /setactive $balancedGuid | Out-Null
			Write-Log -Message 'Battery-capable system detected. Balanced plan set.' -Category 'Performance'
		}
		else {
			powercfg /setactive $highPerfGuid | Out-Null
			Write-Log -Message 'AC-only system detected. High Performance plan set.' -Category 'Performance'
		}
		Add-ActionResult -Action 'Power plan optimization' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Power plan optimization failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Performance'
		Add-ActionResult -Action 'Power plan optimization' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-StorageOptimization {
	try {
		$storage = $script:Result.Hardware.StorageType
		if ($storage -eq 'SSD') {
			$trimCheck = & fsutil.exe behavior query DisableDeleteNotify 2>&1
			Write-Log -Message "TRIM status query: $trimCheck" -Category 'Performance'
			$trimDisabled = [bool]($trimCheck -match '=\s*1')
			if ($trimDisabled) {
				if (Confirm-Step -Title 'Enable SSD TRIM (DisableDeleteNotify=0)' -Warning 'TRIM appears disabled; enabling is recommended for SSD health and performance.') {
					if ($DryRun) {
						Write-Log -Message '[DryRun] Would run: fsutil behavior set DisableDeleteNotify 0' -Category 'Performance'
					}
					else {
						& fsutil.exe behavior set DisableDeleteNotify 0 | Out-Null
						Write-Log -Message 'Enabled SSD TRIM (DisableDeleteNotify=0).' -Category 'Performance'
					}
				}
				else {
					Write-Log -Message 'TRIM remains disabled by user choice.' -Level 'WARN' -Category 'Performance'
				}
			}
			if ($DryRun) {
				Write-Log -Message '[DryRun] Would schedule SSD optimization (retrim) and skip defragmentation.' -Category 'Performance'
			}
			else {
				Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue | Out-Null
			}
			$ssdActionStatus = 'Performed'
			$ssdActionReason = $null
			if ($DryRun) {
				$ssdActionStatus = 'Skipped'
				$ssdActionReason = 'DryRun'
			}
			Add-ActionResult -Action 'Storage optimization (SSD)' -Status $ssdActionStatus -Reason $ssdActionReason
		}
		elseif ($storage -eq 'HDD') {
			if (Confirm-Step -Title 'Schedule HDD defragmentation/optimization' -Warning 'Defragmentation is only offered for HDD scenarios.') {
				if ($DryRun) {
					Write-Log -Message '[DryRun] Would run Optimize-Volume -Defrag on C:.' -Category 'Performance'
					Add-ActionResult -Action 'Storage optimization (HDD defrag)' -Status 'Skipped' -Reason 'DryRun'
				}
				else {
					Optimize-Volume -DriveLetter C -Defrag -Verbose -ErrorAction SilentlyContinue | Out-Null
					Add-ActionResult -Action 'Storage optimization (HDD defrag)' -Status 'Performed'
				}
			}
			else {
				Add-ActionResult -Action 'Storage optimization (HDD defrag)' -Status 'Skipped' -Reason 'UserDeclined'
			}
		}
		else {
			Add-ActionResult -Action 'Storage optimization' -Status 'Skipped' -Reason 'UnknownStorageType'
		}
	}
	catch {
		Write-Log -Message "Storage optimization failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Performance'
		Add-ActionResult -Action 'Storage optimization' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-VisualEffectsOptimization {
	try {
		$mode = 'BalancedReducedAnimations'
		if ($Aggressive) {
			$mode = 'BestPerformance'
		}
		if (-not (Confirm-Step -Title "Apply visual effects mode: $mode" -Warning 'Registry backup will be exported before changes.')) {
			Add-ActionResult -Action 'Visual effects optimization' -Status 'Skipped' -Reason 'UserDeclined'
			return
		}

		$backup = Export-RegistryBackup -RegistryPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualEffects_backup'
		if ($DryRun) {
			Write-Log -Message "[DryRun] Would apply visual effects mode $mode (backup: $backup)." -Category 'Performance'
			Add-ActionResult -Action 'Visual effects optimization' -Status 'Skipped' -Reason 'DryRun'
			return
		}

		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Force | Out-Null
		if ($Aggressive) {
			Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -Value 2 -Type DWord
		}
		else {
			Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -Value 3 -Type DWord
			Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name UserPreferencesMask -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary
		}
		Add-ActionResult -Action 'Visual effects optimization' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Visual effects optimization failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Performance'
		Add-ActionResult -Action 'Visual effects optimization' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Invoke-OptionalRegistryTweaks {
	if (-not $Aggressive) {
		Add-ActionResult -Action 'Optional registry tweaks' -Status 'Skipped' -Reason 'AggressiveNotSet'
		return
	}

	if (-not (Confirm-Step -Title 'Apply optional aggressive registry performance tweaks' -Warning 'Registry exports will be created before changes.')) {
		Add-ActionResult -Action 'Optional registry tweaks' -Status 'Skipped' -Reason 'UserDeclined'
		return
	}

	try {
		$backup1 = Export-RegistryBackup -RegistryPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'MemoryManagement_backup'
		if (-not $DryRun) {
			Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Type DWord -Value 0
			Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Type DWord -Value 0
		}
		Write-Log -Message "Optional registry tweaks applied. Backup: $backup1" -Category 'Performance'
		Add-ActionResult -Action 'Optional registry tweaks' -Status 'Performed'
	}
	catch {
		Write-Log -Message "Optional registry tweaks failed: $($_.Exception.Message)" -Level 'WARN' -Category 'Performance'
		Add-ActionResult -Action 'Optional registry tweaks' -Status 'Failed' -Reason $_.Exception.Message
	}
}

function Write-FinalSummary {
	$script:Result.EndedAt = Get-Date
	$duration = New-TimeSpan -Start $script:StartTime -End $script:Result.EndedAt

	$summaryTxt = Join-Path $script:RunRoot 'summary_report.txt'

	$lines = @(
		"Run ID: $($script:Result.RunId)",
		"Started: $($script:Result.StartedAt)",
		"Ended: $($script:Result.EndedAt)",
		"Duration: $([int]$duration.TotalSeconds) sec",
		"User: $($script:Result.User)",
		"Machine: $($script:Result.Machine)",
		"DryRun: $($script:Result.DryRun)",
		"Actions Performed: $($script:Result.ActionsPerformed.Count)",
		"Actions Skipped: $($script:Result.ActionsSkipped.Count)",
		"Actions Failed: $($script:Result.ActionsFailed.Count)",
		"Files Removed: $($script:Result.FilesRemoved.Count)",
		"Services Changed: $($script:Result.ServicesChanged.Count)",
		"Drivers Backed Up: $($script:Result.DriversBackedUp.Count)",
		"Drivers Removed: $($script:Result.DriversRemoved.Count)",
		"---",
		"Performed:",
		($script:Result.ActionsPerformed -join [Environment]::NewLine),
		"---",
		"Skipped:",
		($script:Result.ActionsSkipped -join [Environment]::NewLine),
		"---",
		"Failed:",
		($script:Result.ActionsFailed -join [Environment]::NewLine),
		"---",
		"Recommendations:",
		($script:Result.Recommendations -join [Environment]::NewLine)
	)

	$lines | Set-Content -Path $summaryTxt -Encoding UTF8
	$script:Result | ConvertTo-Json -Depth 8 | Set-Content -Path $script:ReportPath -Encoding UTF8

	Write-Log -Message "Final summary written: $summaryTxt" -Category 'Summary'
	Write-Log -Message "JSON summary written: $script:ReportPath" -Category 'Summary'

	Write-Host "`n===== Optimize-Windows Summary ====="
	Write-Host "Run folder: $script:RunRoot"
	Write-Host "Performed: $($script:Result.ActionsPerformed.Count)"
	Write-Host "Skipped: $($script:Result.ActionsSkipped.Count)"
	Write-Host "Failed: $($script:Result.ActionsFailed.Count)"
	Write-Host "ExitCode: $script:ExitCode"
	Write-Host '===================================='
}

function Test-IsWindowsPlatform {
    # PowerShell 6+ exposes $IsWindows; Windows PowerShell 5.1 does not.
    # Under Set-StrictMode, direct use of undefined $IsWindows throws.
    if (Get-Variable -Name IsWindows -Scope Global -ErrorAction SilentlyContinue) {
        return [bool]$IsWindows
    }

    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Invoke-Main {
    try {
        Initialize-RunFolders
        Write-Log -Message 'Optimize-Windows run started.' -Category 'Start'

        if (-not (Test-IsWindowsPlatform)) {
            throw 'This script supports Windows only.'
        }

        Assert-Administrator
        Assert-OsCompatibility
        Assert-UpdateSafeState
        New-SystemRestorePoint
        Get-HardwareProfile | Out-Null

        Invoke-SystemFileValidation
        Invoke-ComponentStoreCleanup
        Invoke-WindowsUpdateCleanup
        Invoke-DeliveryOptimizationCleanup
        Invoke-TemporaryFilesCleanup
        Invoke-ThumbnailAndBrowserCacheCleanup
        Invoke-RecycleBinCleanup
        Invoke-PrefetchCleanup
        Invoke-SearchIndexRebuild
        Invoke-TelemetryRecommendations

        Invoke-ServiceStartupOptimization

        Invoke-DriverManagement
        Invoke-DriverAutoUpdate

        Invoke-BloatwareWorkflow

        Invoke-PowerPlanOptimization
        Invoke-StorageOptimization
        Invoke-VisualEffectsOptimization
        Invoke-OptionalRegistryTweaks
    }
    catch {
        Write-Log -Message "Fatal run error: $($_.Exception.Message)" -Level 'ERROR' -Category 'Main'
        if ($script:ExitCode -lt 2) { $script:ExitCode = 2 }
    }
    finally {
        Write-FinalSummary
    }

    if ($script:Result.ActionsFailed.Count -gt 0 -and $script:ExitCode -eq 0) {
        $script:ExitCode = 1
    }

    exit $script:ExitCode
}

# Explicit policy note: This script does not exfiltrate user data and does not send telemetry externally.
Invoke-Main
