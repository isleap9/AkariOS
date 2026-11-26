$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# before and after numbers (X6): the pure parts, the readers mocked, a record's numbers kept with the rest
Describe 'Before and after numbers' {
    foreach ($f in 'Log', 'Registry', 'History', 'Metrics') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()

    It 'formats and compares the numbers both sides have, in order' {
        $rows = @(Get-AkariMetricsDiff ([ordered]@{ RamMB = 2458; Processes = 180; BootSeconds = 35.25 }) ([ordered]@{ RamMB = 1536; Processes = 120; Services = 90; BootSeconds = 22 }))
        ($rows | ForEach-Object { "$($_.Name): $($_.Before) > $($_.After)" }) -join ' | ' | Should Be 'RAM in use: 2.4 GB > 1.5 GB | Processes: 180 > 120 | Boot time: 35.3 s > 22 s'
        $rows[0].Text | Should Be "2.4 GB $([char]0x2192) 1.5 GB"
        @(Get-AkariMetricsDiff $null @{ RamMB = 1 }).Count | Should Be 0
    }

    It 'reads After once Windows has been up 3 minutes after a restart since the Run' {
        $r = @{ When = '2026-11-26T10:00:00'; Metrics = @{ Before = @{ RamMB = 1 } } }
        Test-AkariMetricsDue $r ([datetime]'2026-11-26T09:00') ([datetime]'2026-11-26T11:00') | Should Be 'No'
        Test-AkariMetricsDue $r ([datetime]'2026-11-26T10:30') ([datetime]'2026-11-26T10:31') | Should Be 'Wait'
        Test-AkariMetricsDue $r ([datetime]'2026-11-26T10:30') ([datetime]'2026-11-26T10:34') | Should Be 'Due'
        Test-AkariMetricsDue @{ When = '2026-11-26T10:00:00'; Metrics = @{ Before = @{ RamMB = 1 }; After = @{ RamMB = 1 } } } ([datetime]'2026-11-26T10:30') ([datetime]'2026-11-26T11:00') | Should Be 'No'
        Test-AkariMetricsDue @{ When = '2026-11-26T10:00:00'; Metrics = @{} } ([datetime]'2026-11-26T10:30') ([datetime]'2026-11-26T11:00') | Should Be 'No'
    }

    It 'reads every number through its wrapper' {
        Mock Get-AkariMemoryInUse { 2048 }
        Mock Get-AkariRunningCounts { @{ Processes = 150; Services = 80 } }
        Mock Get-AkariBootSeconds { 20.5 }
        function Get-AkariStartupItems { [pscustomobject]@{ Enabled = $true }; [pscustomobject]@{ Enabled = $false } }
        $m = Get-AkariMetrics
        "$($m.RamMB) $($m.Processes) $($m.Services) $($m.Startup) $($m.BootSeconds)" | Should Be '2048 150 80 1 20.5'
    }

    It 'keeps a record''s numbers through later writes, and finds the one to show' {
        $AkariHistoryDir = "$TestDrive\history"
        $h = New-AkariHistory 'Guided run' ([datetime]'2026-11-26T10:00')
        Set-AkariHistoryMetrics $h 'Before' ([ordered]@{ RamMB = 2048; Processes = 150 })
        Add-AkariHistoryOutcomes $h @([pscustomobject]@{ Id = 'x'; Mode = 'Apply'; Outcome = 'Applied' })
        $p = Find-AkariMetricsPending @(Get-AkariHistoryRecords) ([datetime]'2026-11-26T11:00') ([datetime]'2026-11-26T11:10')
        $p.State | Should Be 'Due'
        Get-AkariMetricsShown @(Get-AkariHistoryRecords) | Should Be $null
        Set-AkariHistoryMetrics $h 'After' ([ordered]@{ RamMB = 1024; Processes = 100 })
        $r = Get-AkariMetricsShown @(Get-AkariHistoryRecords)
        $r.Metrics['Before'].RamMB | Should Be 2048
        $r.Metrics['After'].Processes | Should Be 100
        @($r.Outcomes).Count | Should Be 1
    }
}
