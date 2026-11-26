# Before and after numbers (plan docs/plans/2026-11-26-new-features.md, X6): RAM in use, processes, running services,
# startup apps on and the last boot's time, read when a Guided or One-click Run starts ('Before', in its history
# record, Core\History.ps1) and again at the first launch after its restart, once Windows has been up 3 minutes
# ('After': numbers right after a Run or a boot mean nothing). Home shows them side by side. The native app's
# AkariOS.Core/Machine/Metrics.cs does the same; MetricsTests compares the pure parts.

# the numbers, in Home's order, with their names
$AkariMetricNames = [ordered]@{
    RamMB       = 'RAM in use'
    Processes   = 'Processes'
    Services    = 'Running services'
    Startup     = 'Startup apps on'
    BootSeconds = 'Boot time'
}
# how long Windows must have been up before 'After' is read
$AkariMetricsSettle = 180

# ---- the readers (tests mock them)

function Get-AkariMemoryInUse {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    [int][Math]::Round(([double]$os.TotalVisibleMemorySize - [double]$os.FreePhysicalMemory) / 1024)
}

function Get-AkariLastBoot { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime }

# the last boot's time in seconds (Diagnostics-Performance event 100), $null when the log doesn't have it
function Get-AkariBootSeconds {
    try {
        $e = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 1 -ErrorAction Stop
        $ms = ([xml]$e.ToXml()).Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' } | Select-Object -First 1
        if ($ms) { return [Math]::Round([double]$ms.'#text' / 1000, 1) }
    } catch { }
    $null
}

function Get-AkariRunningCounts {
    @{ Processes = @(Get-Process -ErrorAction SilentlyContinue).Count; Services = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { "$($_.Status)" -eq 'Running' }).Count }
}

# every number now: @{ RamMB; Processes; Services; Startup; BootSeconds } (one that can't be read is left out)
function Get-AkariMetrics {
    $m = [ordered]@{}
    try { $m.RamMB = Get-AkariMemoryInUse } catch { }
    try { $c = Get-AkariRunningCounts; $m.Processes = $c.Processes; $m.Services = $c.Services } catch { }
    if (Get-Command Get-AkariStartupItems -ErrorAction SilentlyContinue) { try { $m.Startup = @(Get-AkariStartupItems | Where-Object { $_.Enabled }).Count } catch { } }
    $b = Get-AkariBootSeconds
    if ($null -ne $b) { $m.BootSeconds = $b }
    $m
}

# ---- pure

# a number as Home shows it: RAM in GB (one decimal), the boot in seconds, the rest as they are
function Format-AkariMetric([string]$Name, $Value) {
    $inv = [Globalization.CultureInfo]::InvariantCulture
    switch ($Name) {
        'RamMB' { ([double]$Value / 1024).ToString('0.0', $inv) + ' GB' }
        'BootSeconds' { ([double]$Value).ToString('0.#', $inv) + ' s' }
        default { ([long]$Value).ToString($inv) }
    }
}

# the rows Home shows: @{ Key; Name; Before; After; Text } for each number both sides have, in $AkariMetricNames' order
function Get-AkariMetricsDiff($Before, $After) {
    @(foreach ($k in $AkariMetricNames.Keys) {
        if (-not $Before -or -not $After -or $null -eq $Before[$k] -or $null -eq $After[$k]) { continue }
        $b = Format-AkariMetric $k $Before[$k]; $a = Format-AkariMetric $k $After[$k]
        @{ Key = $k; Name = $AkariMetricNames[$k]; Before = $b; After = $a; Text = "$b $([char]0x2192) $a" }
    })
}

# what to do about a record's 'After': 'Due' (read it now), 'Wait' (Windows came up less than $AkariMetricsSettle
# seconds ago), 'No' (no 'Before', already read, or no restart since the Run)
function Test-AkariMetricsDue($Record, [datetime]$LastBoot, [datetime]$Now) {
    if (-not $Record -or -not $Record.Metrics -or -not $Record.Metrics['Before'] -or $Record.Metrics['After']) { return 'No' }
    $when = try { [datetime]$Record.When } catch { return 'No' }
    if ($LastBoot -le $when) { return 'No' }
    if (($Now - $LastBoot).TotalSeconds -lt $AkariMetricsSettle) { return 'Wait' }
    'Due'
}

# the newest record whose 'After' is due or waiting (@{ Record; State }), $null when none
function Find-AkariMetricsPending($Records, [datetime]$LastBoot, [datetime]$Now) {
    foreach ($r in @($Records)) {
        $s = Test-AkariMetricsDue $r $LastBoot $Now
        if ($s -ne 'No') { return @{ Record = $r; State = $s } }
    }
    $null
}

# the newest record with both sides, for Home
function Get-AkariMetricsShown($Records) {
    foreach ($r in @($Records)) { if ($r.Metrics -and $r.Metrics['Before'] -and $r.Metrics['After']) { return $r } }
    $null
}
