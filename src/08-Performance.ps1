<#
.SYNOPSIS
    Profile component 08 - Performance Monitoring And Benchmarking
.DESCRIPTION
    Extracted from Microsoft.PowerShell_profile.ps1 region 8 (PERFORMANCE MONITORING AND BENCHMARKING) for modular dot-sourced loading.
#>

#region 8 - PERFORMANCE MONITORING AND BENCHMARKING
#==============================================================================
<#
.SYNOPSIS
    Performance monitoring and benchmarking functions
.DESCRIPTION
    Provides functions for monitoring system performance, capturing metrics,
    and running benchmarks.
#>

function Get-PerfSnapshot {
    <#
    .SYNOPSIS
        Captures a performance snapshot.
    .DESCRIPTION
        Returns key performance counters for CPU, memory, and disk.
        Windows-only (uses Get-Counter with Windows performance counters).
    .PARAMETER SampleSeconds
        Sample interval in seconds (default: 1).
    #>
    [CmdletBinding()]
    param([int]$SampleSeconds = 1)

    if (-not $IsWindows) {
        Write-Warning 'Get-PerfSnapshot requires Windows (performance counters).'
        return $null
    }

    $ud = $Global:ProfileConfig.UtilityDefaults
    if ($SampleSeconds -le 0 -and $ud.PerfSnapshotSampleSeconds -gt 0) {
        $SampleSeconds = [int]$ud.PerfSnapshotSampleSeconds
    } elseif ($SampleSeconds -le 0) {
        $SampleSeconds = 1
    }

    $data = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
    }

    try {
        $counters = @(
            '\Processor(_Total)\% Processor Time',
            '\Memory\Available MBytes',
            '\PhysicalDisk(_Total)\Avg. Disk Queue Length',
            '\PhysicalDisk(_Total)\% Disk Time'
        )

        $ctr = Get-Counter -Counter $counters -SampleInterval $SampleSeconds -MaxSamples 1 -ErrorAction SilentlyContinue

        if ($ctr -and $ctr.CounterSamples) {
            foreach ($s in $ctr.CounterSamples) {
                $name = ($s.Path -split '\')[-1]
                $data[$name] = [math]::Round($s.CookedValue, 2)
            }
        }
    } catch {
        Write-ProfileLog "Get-PerfSnapshot failed: $_" -Level DEBUG -Component "Performance"
    }

    return [PSCustomObject]$data
}

function Get-TopProcesses {
    <#
    .SYNOPSIS
        Returns top processes by resource usage.
    .DESCRIPTION
        Returns the top processes sorted by CPU, Memory, or IO.
    .PARAMETER By
        Sort by: CPU, Memory, or IO.
    .PARAMETER Top
        Number of processes to return.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('CPU', 'Memory', 'IO')]
        [string]$By = 'Memory',
        [int]$Top = 0
    )

    $ud = $Global:ProfileConfig.UtilityDefaults
    if ($Top -le 0) { $Top = $ud.TopProcessesTop }
    if ($Top -le 0) { $Top = 15 }

    try {
        $procs = Get-Process -ErrorAction SilentlyContinue

        switch ($By) {
            'CPU' {
                return $procs | Sort-Object CPU -Descending |
                    Select-Object -First $Top Name, Id, CPU, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) }}
            }
            'IO' {
                # IOReadBytes/IOWriteBytes are only available on Windows
                if (-not $IsWindows) {
                    Write-Warning 'IO-based sorting requires Windows. Falling back to Memory.'
                    return $procs | Sort-Object WorkingSet64 -Descending |
                        Select-Object -First $Top Name, Id, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) }},
                            @{N = 'CPUTime'; E = { $_.CPU }}
                }
                return $procs | Sort-Object IOReadBytes -Descending |
                    Select-Object -First $Top Name, Id, @{N = 'ReadMB'; E = { [math]::Round($_.IOReadBytes / 1MB, 2) }},
                        @{N = 'WriteMB'; E = { [math]::Round($_.IOWriteBytes / 1MB, 2) }}
            }
            default {
                return $procs | Sort-Object WorkingSet64 -Descending |
                    Select-Object -First $Top Name, Id, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) }},
                        @{N = 'CPUTime'; E = { $_.CPU }}
            }
        }
    } catch {
        Write-ProfileLog "Get-TopProcesses failed: $_" -Level DEBUG -Component "Performance"
        return @()
    }
}

function Measure-Benchmark {
    <#
    .SYNOPSIS
        Runs a benchmark and measures execution time.
    .DESCRIPTION
        Executes a script block multiple times and returns statistics.
    .PARAMETER ScriptBlock
        The code to benchmark.
    .PARAMETER Iterations
        Number of iterations (default: 10).
    .PARAMETER Warmup
        Number of warmup runs before measurement.
    .EXAMPLE
        Measure-Benchmark -ScriptBlock { Get-Process } -Iterations 100
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [int]$Iterations = 10,
        [int]$Warmup = 2
    )

    try {
        # Warmup runs
        for ($i = 0; $i -lt $Warmup; $i++) {
            $null = & $ScriptBlock
        }

        # Measure runs
        $times = @()
        for ($i = 0; $i -lt $Iterations; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = & $ScriptBlock
            $sw.Stop()
            $times += $sw.ElapsedMilliseconds
        }

        $sorted = $times | Sort-Object

        [PSCustomObject]@{
            Iterations  = $Iterations
            MinMs       = $sorted | Select-Object -First 1
            MaxMs       = $sorted | Select-Object -Last 1
            AvgMs       = [math]::Round(($times | Measure-Object -Average).Average, 2)
            MedianMs    = if ($sorted.Count % 2 -eq 0) {
                [math]::Round(($sorted[$sorted.Count / 2 - 1] + $sorted[$sorted.Count / 2]) / 2, 2)
            } else {
                $sorted[[math]::Floor($sorted.Count / 2)]
            }
            TotalMs     = ($times | Measure-Object -Sum).Sum
        }
    } catch {
        Write-CaughtException -Context "Measure-Benchmark failed" -ErrorRecord $_ -Component "Performance" -Level WARN
        return $null
    }
}

#endregion PERFORMANCE MONITORING AND BENCHMARKING
