# Run history and Undo (plan docs/plans/2026-11-26-new-features.md, X4). Before a Run changes a Tweak whose effect is
# only its registry rows, each row's value is saved as it was (its kind and data, or missing); Undo writes them back,
# so the PC gets the user's own values again, not only Windows' defaults (ADR 0001's Revert). Tweaks with code can only
# go back to Windows' default (their Revert); Actions and removed apps can't be undone here.
# A record: history\<yyyyMMdd-HHmmss>.json next to akari.log = { Name; When; Before = { id: [ rows ] }; Outcomes =
# [ { Id; Mode; Outcome } ] }; a row = { Path; Name; Exists; Kind; Data } (Binary as hex text). The newest 10 are kept.
# Only where $AkariHistoryDir is set (Akari.ps1 and its job; tests set their own). Invoke-AkariPlan records into
# $AkariHistoryFile when it is set (Guided's Run; a Run in phases sets it from the Run's History).
# The native app's AkariOS.Core/Runs/History.cs does the same.

if (-not $AkariHistoryKeep) { $AkariHistoryKeep = 10 }

# the history folder ('' = no history kept)
function Get-AkariHistoryDir { "$AkariHistoryDir" }

# a new record for a Run named $Name; returns its path, '' without a history folder (older records past
# $AkariHistoryKeep removed)
function New-AkariHistory([string]$Name, [datetime]$Now = (Get-Date)) {
    $dir = Get-AkariHistoryDir
    if (-not $dir) { return '' }
    New-Item $dir -ItemType Directory -Force | Out-Null
    $stamp = $Now.ToString('yyyyMMdd-HHmmss')
    $path = Join-Path $dir "$stamp.json"
    for ($k = 2; [IO.File]::Exists($path); $k++) { $path = Join-Path $dir "$stamp-$k.json" }
    Save-AkariHistory $path @{ Name = $Name; When = $Now.ToString('o'); Before = @{}; Outcomes = @(); Metrics = @{} }
    # undone ones (.undone) count too
    $old = @([IO.Directory]::GetFiles($dir) | Sort-Object -Descending | Select-Object -Skip $AkariHistoryKeep)
    foreach ($f in $old) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    $path
}

function Save-AkariHistory([string]$Path, $Record) {
    [IO.File]::WriteAllText($Path, ($Record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

# a record as hashtables (Before's ids, rows, Outcomes), or $null when it can't be read
function Read-AkariHistory([string]$Path) {
    try { $j = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    $before = @{}
    if ($j.Before) {
        foreach ($p in $j.Before.PSObject.Properties) {
            $before[$p.Name] = @(foreach ($r in @($p.Value)) { if ($r) { @{ Path = [string]$r.Path; Name = [string]$r.Name; Exists = [bool]$r.Exists; Kind = [string]$r.Kind; Data = $r.Data } } })
        }
    }
    $outs = @(foreach ($o in @($j.Outcomes)) { if ($o) { @{ Id = [string]$o.Id; Mode = [string]$o.Mode; Outcome = [string]$o.Outcome } } })
    # X6: the numbers before the Run and after its restart (Core\Metrics.ps1)
    $metrics = @{}
    if ($j.Metrics) { foreach ($w in 'Before', 'After') { if ($j.Metrics.$w) { $metrics[$w] = ConvertTo-AkariMetricsTable $j.Metrics.$w } } }
    @{ Path = $Path; Name = [string]$j.Name; When = [string]$j.When; Before = $before; Outcomes = $outs; Metrics = $metrics }
}

# the newest record, or $null
function Get-AkariLastHistory {
    $dir = Get-AkariHistoryDir
    if (-not $dir -or -not [IO.Directory]::Exists($dir)) { return $null }
    $f = @([IO.Directory]::GetFiles($dir, '*.json') | Sort-Object -Descending) | Select-Object -First 1
    if ($f) { Read-AkariHistory $f } else { $null }
}

# (pure) a record's numbers read back from JSON as a hashtable
function ConvertTo-AkariMetricsTable($O) {
    $h = [ordered]@{}
    if ($O -is [Collections.IDictionary]) { foreach ($k in @($O.Keys)) { $h[$k] = $O[$k] } }
    elseif ($O) { foreach ($p in $O.PSObject.Properties) { $h[$p.Name] = $p.Value } }
    $h
}

# a record's numbers before the Run ('Before') or after its restart ('After'), kept with the rest
function Set-AkariHistoryMetrics([string]$Path, [string]$Which, $Metrics) {
    if (-not $Path -or -not $Metrics) { return }
    try {
        $r = Read-AkariHistory $Path
        if (-not $r) { return }
        $m = $r.Metrics; $m[$Which] = $Metrics
        Save-AkariHistory $Path @{ Name = $r.Name; When = $r.When; Before = $r.Before; Outcomes = $r.Outcomes; Metrics = $m }
    } catch { Write-ErrLog "history: $($_.Exception.Message)" }
}

# every record, newest first (undone ones too: their numbers still count)
function Get-AkariHistoryRecords {
    $dir = Get-AkariHistoryDir
    if (-not $dir -or -not [IO.Directory]::Exists($dir)) { return @() }
    @([IO.Directory]::GetFiles($dir) | Sort-Object -Descending | ForEach-Object { Read-AkariHistory $_ } | Where-Object { $_ })
}

# (pure) a Tweak whose effect is only its value rows: a Toggle or Choice with registry rows, none a key row, no script
# block (no Detect / Apply / Revert / After / Value), not a Group Entry, an install or a Safe Mode one
function Test-AkariUndoable($Tweak) {
    if ($Tweak.Kind -notin 'Toggle', 'Choice' -or $Tweak.EntryKind -or $Tweak.SafeMode) { return $false }
    if (@($Tweak.Winget | Where-Object { $_ }).Count) { return $false }
    foreach ($p in $Tweak.PSObject.Properties) { if ($p.Value -is [scriptblock]) { return $false } }
    $rows = @($Tweak.Registry | Where-Object { $_ })
    if (-not $rows.Count) { return $false }
    foreach ($r in $rows) { if ($null -eq $r.Name -or "$($r.Name)" -eq '') { return $false } }
    $true
}

# one value row as it is now: @{ Path; Name; Exists; Kind; Data } (Data unexpanded; Binary as hex text)
function Read-AkariUndoRow([string]$Path, [string]$Name) {
    $row = @{ Path = $Path; Name = $Name; Exists = $false; Kind = ''; Data = $null }
    $k = Get-Item -LiteralPath (Resolve-AkariRegPath $Path) -ErrorAction SilentlyContinue
    if (-not $k) { return $row }
    $vn = if ($Name -eq '(default)') { '' } else { $Name }
    if ($vn -notin @($k.GetValueNames()) -and -not ($vn -eq '' -and $null -ne $k.GetValue(''))) { return $row }
    $kind = "$($k.GetValueKind($vn))"
    $data = $k.GetValue($vn, $null, 'DoNotExpandEnvironmentNames')
    if ($kind -eq 'Binary') { $data = (@($data) | ForEach-Object { '{0:x2}' -f $_ }) -join ',' }
    elseif ($kind -eq 'MultiString') { $data = @($data) }
    $row.Exists = $true; $row.Kind = $kind; $row.Data = $data
    $row
}

# records a Tweak's rows as they are, once per record (the first Run step that touches it); nothing for a Tweak
# Undo can't put back exactly
function Add-AkariHistoryBefore([string]$Path, $Tweak) {
    if (-not $Path -or -not (Test-AkariUndoable $Tweak)) { return }
    try {
        $r = Read-AkariHistory $Path
        if (-not $r -or $r.Before.ContainsKey($Tweak.Id)) { return }
        $r.Before[$Tweak.Id] = @(foreach ($row in @($Tweak.Registry | Where-Object { $_ })) { Read-AkariUndoRow $row.Path $row.Name })
        Save-AkariHistory $Path @{ Name = $r.Name; When = $r.When; Before = $r.Before; Outcomes = $r.Outcomes; Metrics = $r.Metrics }
    } catch { Write-ErrLog "history: $($_.Exception.Message)" }
}

function Add-AkariHistoryOutcomes([string]$Path, $Outcomes) {
    if (-not $Path) { return }
    try {
        $r = Read-AkariHistory $Path
        if (-not $r) { return }
        $add = @(foreach ($o in @($Outcomes)) { if ($o.Id) { @{ Id = [string]$o.Id; Mode = [string]$o.Mode; Outcome = [string]$o.Outcome } } })
        Save-AkariHistory $Path @{ Name = $r.Name; When = $r.When; Before = $r.Before; Outcomes = @($r.Outcomes) + $add; Metrics = $r.Metrics }
    } catch { Write-ErrLog "history: $($_.Exception.Message)" }
}

# (pure) what Undo does with a record: Exact = ids changed (Applied / Reverted) with their rows saved; Default = Toggles
# and Choices Applied without rows (code: back to Windows' default, their Revert); Never = the rest that changed
# (Actions, removed or installed apps, a Tweak with code that was Reverted, ids no longer loaded). Each by its last
# Outcome, in the Run's order.
function Get-AkariUndoPlan($Record, $Tweaks) {
    $byId = @{}
    foreach ($t in @($Tweaks)) { if ($t -and -not $byId.ContainsKey($t.Id)) { $byId[$t.Id] = $t } }
    $last = [ordered]@{}
    foreach ($o in @($Record.Outcomes)) { if ($o.Outcome -in 'Applied', 'Reverted') { $last.Remove($o.Id); $last[$o.Id] = $o } }
    $exact = [Collections.Generic.List[string]]::new(); $default = [Collections.Generic.List[string]]::new(); $never = [Collections.Generic.List[string]]::new()
    foreach ($id in @($last.Keys)) {
        $t = $byId[$id]
        if ($Record.Before.ContainsKey($id) -and $t) { $exact.Add($id) }
        elseif ($t -and $t.Kind -in 'Toggle', 'Choice' -and -not $t.EntryKind -and $last[$id].Mode -eq 'Apply' -and -not @($t.Winget | Where-Object { $_ }).Count) { $default.Add($id) }
        else { $never.Add($id) }
    }
    @{ Exact = @($exact); Default = @($default); Never = @($never) }
}

# writes one saved row back: missing = removed, else its kind and data
function Restore-AkariUndoRow($Row) {
    if (-not $Row.Exists) { Remove-Reg $Row.Path $Row.Name; return }
    $data = switch ($Row.Kind) {
        'Binary' { ConvertFrom-AkariHex ([string]$Row.Data) }
        'DWord' { [int64]$Row.Data }
        'QWord' { [int64]$Row.Data }
        'MultiString' { [string[]]@($Row.Data) }
        default { [string]$Row.Data }
    }
    if ($Row.Kind -eq 'DWord' -and $data -lt 0) { $data = [uint32]($data + 4294967296) }
    Set-Reg $Row.Path $Row.Name $data $Row.Kind
}

# Undo: the Exact ids' rows written back, the Default ones Reverted, in reverse order; Outcomes (Mode Revert: Reverted,
# Failed). Explorer restarted once when a Tweak needs it.
function Invoke-AkariUndo($Record, $Tweaks, [switch]$NoDefaults) {
    $plan = Get-AkariUndoPlan $Record $Tweaks
    $byId = @{}
    foreach ($t in @($Tweaks)) { if ($t -and -not $byId.ContainsKey($t.Id)) { $byId[$t.Id] = $t } }
    $explorer = $false
    $ids = @($plan.Exact) + $(if ($NoDefaults) { @() } else { @($plan.Default) })
    [array]::Reverse($ids)
    $done = 0
    foreach ($id in $ids) {
        $t = $byId[$id]
        Set-AkariProgress $done $ids.Count $t.Name
        $done++
        if ($id -in $plan.Exact) {
            try {
                foreach ($row in @($Record.Before[$id])) { Restore-AkariUndoRow $row }
                # not AkariOS' value any more: the drift check leaves it alone (Core\State.ps1)
                Remove-AkariExpected $id
                Write-Log "Reverted: $($t.Name) (as it was before the Run)"
                $o = New-AkariOutcome $id 'Revert' 'Reverted' $false 'as it was before the Run'
            } catch {
                Write-Log "Failed: $($t.Name): $($_.Exception.Message)"
                $o = New-AkariOutcome $id 'Revert' 'Failed' $false $_.Exception.Message
            }
        } else { $o = Invoke-AkariTweak $t 'Revert' }
        if ($t.Explorer -and $o.Outcome -eq 'Reverted') { $explorer = $true }
        $o
    }
    if ($explorer) { Restart-AkariExplorer }
}
