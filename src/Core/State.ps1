# State: what a Tweak's setting is right now: Optimized, Default, Custom or Unknown.
# Order: Detect, then Registry data, then what Akari last applied (state.json).

$AkariStates = 'Optimized', 'Default', 'Custom', 'Unknown'
if (-not $AkariStatePath) { $AkariStatePath = "$env:LOCALAPPDATA\Akari\state.json" }

# state.json is { "<id>": true|false } (true = last Applied). Read on every call: the GUI's background job writes it too.
function Read-AkariStateFile {
    $s = @{}
    try { (Get-Content $AkariStatePath -Raw -ErrorAction Stop | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $s[$_.Name] = [bool]$_.Value } } catch { }
    $s
}

function Get-AkariRememberedState([string]$Id) {
    $s = Read-AkariStateFile
    if ($s.ContainsKey($Id)) { return $s[$Id] }
    $null
}

function Set-AkariRememberedState([string]$Id, [bool]$Applied) {
    $s = Read-AkariStateFile
    $s[$Id] = $Applied
    New-Item (Split-Path $AkariStatePath) -ItemType Directory -Force | Out-Null
    ($s | ConvertTo-Json) | Set-Content $AkariStatePath
}

# a Choice's current value: its registry value, or what its Value block returns (a Choice over many settings, e.g. a
# list of service start types; $null = none of its values). Throws when it can't be read.
function Get-AkariChoiceValue($Tweak) {
    if ($Tweak.Value) {
        $AkariTweakDir = if ($Tweak.Source -and (Test-Path -LiteralPath $Tweak.Source)) { Split-Path $Tweak.Source } else { '' }
        return & ([scriptblock]::Create($Tweak.Value.ToString()))
    }
    $e = $Tweak.Registry[0]
    Get-AkariRegValue $e.Path $e.Name
}

function Get-AkariState($Tweak) {
    if ($Tweak.Kind -eq 'Action') { return 'Unknown' }
    if ($Tweak.Detect) {
        # like Apply / Revert, Detect sees $AkariTweakDir (the tweak file's folder, for files shipped next to it)
        $AkariTweakDir = if ($Tweak.Source -and (Test-Path -LiteralPath $Tweak.Source)) { Split-Path $Tweak.Source } else { '' }
        try { $r = & $Tweak.Detect } catch { return 'Unknown' }
        if ($r -is [bool]) { if ($r) { return 'Optimized' } else { return 'Default' } }
        if ($r -is [string] -and $r -in $AkariStates) { return $r }
        return 'Unknown'
    }
    if ($Tweak.Kind -eq 'Choice') {
        try { $cur = Get-AkariChoiceValue $Tweak } catch { return 'Unknown' }
        $def = Resolve-AkariDefault $Tweak.Default
        # a Value block's $null: readable, but none of its values
        if ($null -eq $cur -and $Tweak.Value) { return 'Custom' }
        if ($null -eq $cur) { if ($null -eq $def) { return 'Default' } else { return 'Unknown' } }
        if (Test-AkariRegMatch $cur $Tweak.Recommended) { return 'Optimized' }
        if (Test-AkariRegMatch $cur $def) { return 'Default' }
        return 'Custom'
    }
    if ($Tweak.Registry) { return Get-AkariRegistryState $Tweak.Registry }
    $r = Get-AkariRememberedState $Tweak.Id
    if ($null -eq $r) { return 'Unknown' }
    if ($r) { 'Optimized' } else { 'Default' }
}

# ---- what each setting should be, and the drift check (plan docs/plans/2026-11-26-new-features.md, X3)
# expected.json = { "<id>": { "Mode": "Apply" | "Revert", "Value": <a Choice's value, or null = its Recommended>,
# "When": <ISO time> } }, the latest change per Tweak; written by Invoke-AkariTweak for Toggles and Choices (no Group
# Entries) on Applied, Reverted and Already. Only where $AkariExpectedPath is set (Akari.ps1 and its job; tests set
# their own), so a test never writes the user's file. The native app's Tweaks/Drift.cs keeps the same file shape.

function Get-AkariExpected {
    $s = @{}
    if (-not $AkariExpectedPath) { return $s }
    try {
        (Get-Content $AkariExpectedPath -Raw -ErrorAction Stop | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
            if ($_.Value.Mode -in 'Apply', 'Revert') { $s[$_.Name] = @{ Mode = [string]$_.Value.Mode; Value = $_.Value.Value; When = [string]$_.Value.When } }
        }
    } catch { }
    $s
}

function Set-AkariExpected($Tweak, [string]$Mode, $Value = $null) {
    if (-not $AkariExpectedPath -or $Tweak.Kind -notin 'Toggle', 'Choice' -or $Tweak.EntryKind) { return }
    try {
        $s = Get-AkariExpected
        $s[$Tweak.Id] = @{ Mode = $Mode; Value = $(if ($Mode -eq 'Apply' -and $Tweak.Kind -eq 'Choice') { $Value } else { $null }); When = (Get-Date).ToString('o') }
        New-Item (Split-Path $AkariExpectedPath) -ItemType Directory -Force | Out-Null
        $o = [ordered]@{}
        foreach ($k in @($s.Keys | Sort-Object)) { $o[$k] = [ordered]@{ Mode = $s[$k].Mode; Value = $s[$k].Value; When = $s[$k].When } }
        ($o | ConvertTo-Json -Depth 4) | Set-Content $AkariExpectedPath -Encoding UTF8
    } catch { Write-ErrLog "expected.json: $($_.Exception.Message)" }
}

# forgets what a Tweak should be (Undo put the user's own value back)
function Remove-AkariExpected([string]$Id) {
    if (-not $AkariExpectedPath) { return }
    $s = Get-AkariExpected
    if (-not $s.ContainsKey($Id)) { return }
    $s.Remove($Id)
    try {
        $o = [ordered]@{}
        foreach ($k in @($s.Keys | Sort-Object)) { $o[$k] = [ordered]@{ Mode = $s[$k].Mode; Value = $s[$k].Value; When = $s[$k].When } }
        ($o | ConvertTo-Json -Depth 4) | Set-Content $AkariExpectedPath -Encoding UTF8
    } catch { Write-ErrLog "expected.json: $($_.Exception.Message)" }
}

# (pure) whether a setting went off what was last asked: Revert = its State isn't Default; Apply = not Optimized, or,
# for a Choice set to a value, its current value isn't that value. Unknown is never drift (it can't be told).
function Test-AkariDrift([string]$Kind, [string]$Mode, $Value, [string]$State, $Current) {
    if ($State -eq 'Unknown') { return $false }
    if ($Mode -eq 'Revert') { return $State -ne 'Default' }
    if ($Kind -eq 'Choice' -and $null -ne $Value) { return -not ($null -ne $Current -and (Test-AkariRegMatch $Current $Value)) }
    $State -ne 'Optimized'
}

# the settings in expected.json that drifted, by name: @{ Id; Name; Mode; Value; State }. Tweaks no longer loaded,
# Actions, Entries and ones this PC doesn't meet are left out.
function Get-AkariDrift($Tweaks, $Expected = $null) {
    if ($null -eq $Expected) { $Expected = Get-AkariExpected }
    $byId = @{}
    foreach ($t in @($Tweaks)) { if ($t.Kind -in 'Toggle', 'Choice' -and -not $t.EntryKind) { $byId[$t.Id] = $t } }
    $out = foreach ($id in @($Expected.Keys)) {
        $t = $byId[$id]
        if (-not $t -or ($t.Requires -and (Test-AkariRequirement $t))) { continue }
        $e = $Expected[$id]
        $state = try { Get-AkariState $t } catch { 'Unknown' }
        $cur = if ($t.Kind -eq 'Choice' -and $e.Mode -eq 'Apply' -and $null -ne $e.Value) { try { Get-AkariChoiceValue $t } catch { $null } } else { $null }
        if (Test-AkariDrift $t.Kind $e.Mode $e.Value $state $cur) { @{ Id = $id; Name = $t.Name; Mode = $e.Mode; Value = $e.Value; State = $state } }
    }
    @($out | Sort-Object { $_.Name })
}

# the drifted settings as a preset Guided's Quick select takes (Read-AkariPreset's shape): Apply = the id (a Choice
# with a value: id = value), Revert = id = Default
function ConvertTo-AkariDriftPreset($Drift) {
    $entries = @(foreach ($d in @($Drift)) {
        if ($d.Mode -eq 'Revert') { @{ Id = $d.Id; Value = 'Default'; HasValue = $true; Phase = 0 } }
        elseif ($null -ne $d.Value) { @{ Id = $d.Id; Value = $d.Value; HasValue = $true; Phase = 0 } }
        else { @{ Id = $d.Id; HasValue = $false; Phase = 0 } }
    })
    @{ Name = 'Settings that went back'; Description = 'AkariOS settings Windows changed back'; Entries = $entries; Phases = @(); Path = ''; Builtin = $false }
}
