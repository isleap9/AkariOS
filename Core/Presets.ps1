# Presets (AkariOS-PLAN.md §8): named lists of Tweak ids, built-in (Presets\*.json) or the user's own
# (%LOCALAPPDATA%\Akari\presets\*.json), plus Last used (%LOCALAPPDATA%\Akari\lastused.json, saved after each Guided Run).
# A file: { "Name": "...", "Description": "...", "Tweaks": [ ... ] }. Each entry:
#   "id"                    Apply (a Choice gets its Recommended value)
#   { "id": <value> }       a Choice set to <value>
#   { "id": "Default" }     Revert (back to the Windows Default)
#   "<group>/*"             every Entry of that data-list Group on this PC except its keep-list (appx/*, capability/*, feature/*)
# Or, instead of "Tweaks", "Phases": [ { "Name": "...", "Boot": "Normal" | "SafeMode", "Tweaks": [ ... ] }, ... ]: a Run in steps
# across restarts (Core\Phases.ps1); Entries then lists every phase's entries in order, each with its Phase index.
# Needs Core\Log.ps1 for the warnings.

if (-not $AkariPresetDir) { $AkariPresetDir = "$env:LOCALAPPDATA\Akari\presets" }
if (-not $AkariLastUsedPath) { $AkariLastUsedPath = "$env:LOCALAPPDATA\Akari\lastused.json" }

# one preset file -> @{ Name; Description; Entries (@{ Id; Value; HasValue; Phase }); Phases (@{ Name; Boot }, or none);
# Path; Builtin }, or $null (the warning is logged)
function Read-AkariPreset([string]$Path, [bool]$Builtin = $false) {
    try { $j = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { Write-Log "Warning: preset $Path could not be read ($($_.Exception.Message))"; return $null }
    $groups = @(if ($j.Phases) { $j.Phases } else { [pscustomobject]@{ Tweaks = $j.Tweaks } })
    $phases = @(); $entries = @()
    for ($k = 0; $k -lt $groups.Count; $k++) {
        if ($j.Phases) {
            $boot = if ("$($groups[$k].Boot)" -eq 'SafeMode') { 'SafeMode' } else { 'Normal' }
            $phases += @{ Name = [string]$groups[$k].Name; Boot = $boot }
        }
        $entries += foreach ($x in @($groups[$k].Tweaks)) {
            if ($x -is [string]) { @{ Id = $x; HasValue = $false; Phase = $k } }
            elseif ($x) { foreach ($p in $x.PSObject.Properties) { @{ Id = $p.Name; Value = $p.Value; HasValue = $true; Phase = $k } } }
        }
    }
    $name = if ($j.Name) { [string]$j.Name } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
    @{ Name = $name; Description = [string]$j.Description; Entries = @($entries); Phases = $phases; Path = $Path; Builtin = $Builtin }
}

# the built-in presets ($BuiltinDir: Akari's Presets\ folder), then the user's, each by name
function Get-AkariPresets([string]$BuiltinDir) {
    foreach ($d in @(@($BuiltinDir, $true), @($AkariPresetDir, $false))) {
        if (-not $d[0] -or -not (Test-Path -LiteralPath $d[0])) { continue }
        Get-ChildItem -LiteralPath $d[0] -Filter *.json -File | Sort-Object Name | ForEach-Object { Read-AkariPreset $_.FullName $d[1] } | Where-Object { $_ }
    }
}

# a preset by name (built-in or the user's, case-insensitive) or by file path, or $null
function Find-AkariPreset([string]$NameOrPath, [string]$BuiltinDir) {
    if ($NameOrPath -match '\.json$' -and (Test-Path -LiteralPath $NameOrPath)) { return Read-AkariPreset (Resolve-Path -LiteralPath $NameOrPath).Path $false }
    @(Get-AkariPresets $BuiltinDir | Where-Object { $_.Name -eq $NameOrPath }) | Select-Object -First 1
}

# plan items for a preset: @{ Items = @(@{ Id; Mode; Value }); Unknown = ids not found }. $Tweaks: every Tweak and
# Entry known (for the wildcards: the Entries on this PC). -Revert: the reverse order, every item Revert (the Runner
# skips Actions and reports them). An Entry a wildcard and an id both name runs once. Pure.
function Resolve-AkariPreset($Preset, $Tweaks, [switch]$Revert) {
    $items = [System.Collections.Generic.List[object]]::new()
    $unknown = [System.Collections.Generic.List[string]]::new()
    $seen = @{}
    foreach ($e in $Preset.Entries) {
        if ($e.Id -like '*/[*]') {
            $g = $e.Id.Substring(0, $e.Id.Length - 2)
            # nothing found = nothing of that Group on this PC (capability / feature Entries exist only once read)
            $hits = @($Tweaks | Where-Object { $_.Group -eq $g -and -not $_.Keep })
            foreach ($t in $hits) { if (-not $seen.ContainsKey($t.Id)) { $seen[$t.Id] = $true; $items.Add(@{ Id = $t.Id; Mode = 'Apply'; Phase = [int]$e.Phase }) } }
            continue
        }
        $t = $Tweaks | Where-Object { $_.Id -eq $e.Id } | Select-Object -First 1
        if (-not $t) { $unknown.Add($e.Id); continue }
        if ($seen.ContainsKey($t.Id)) { continue }
        $seen[$t.Id] = $true
        $i = @{ Id = $t.Id; Mode = 'Apply'; Phase = [int]$e.Phase }
        if ($e.HasValue) {
            if ("$($e.Value)" -eq 'Default') { $i.Mode = 'Revert' }
            elseif ($t.Kind -eq 'Choice') { if (-not (Test-AkariRegMatch $e.Value $t.Recommended)) { $i.Value = $e.Value } }
        }
        $items.Add($i)
    }
    if ($Revert) {
        $items.Reverse()
        foreach ($i in $items) { $i.Mode = 'Revert'; $i.Remove('Value'); $i.Phase = 0 }
    }
    @{ Items = @($items); Unknown = @($unknown) }
}

# the JSON entries for plan items (what Save writes): Apply = the id, a Choice value = { id: value }, Revert = { id: "Default" }
function ConvertTo-AkariPresetEntries($Items) {
    foreach ($i in $Items) {
        if ($i.Mode -eq 'Revert') { [ordered]@{ $i.Id = 'Default' } }
        elseif ($i.ContainsKey('Value') -and $null -ne $i.Value) { [ordered]@{ $i.Id = $i.Value } }
        else { $i.Id }
    }
}

# writes a user preset (or Last used with -Path $AkariLastUsedPath); returns the file path
function Save-AkariPreset([string]$Name, $Items, [string]$Description = '', [string]$Path = '') {
    if (-not $Path) {
        $safe = ($Name -replace '[\\/:*?"<>|]', '_').Trim()
        if (-not $safe) { throw 'a preset needs a name' }
        $Path = Join-Path $AkariPresetDir "$safe.json"
    }
    New-Item (Split-Path $Path) -ItemType Directory -Force | Out-Null
    $doc = [ordered]@{ Name = $Name; Description = $Description; Tweaks = @(ConvertTo-AkariPresetEntries $Items) }
    [IO.File]::WriteAllText($Path, ($doc | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    $Path
}

# Last used: the plan of the last Guided Run, as a preset named "Last used"; $null when there is none yet
function Get-AkariLastUsed { if (Test-Path -LiteralPath $AkariLastUsedPath) { Read-AkariPreset $AkariLastUsedPath $false } }
function Save-AkariLastUsed($Items) { [void](Save-AkariPreset 'Last used' $Items 'The changes of the last Guided Run' $AkariLastUsedPath) }

# the phases of a Run for a preset's plan items (Resolve-AkariPreset): one per preset phase (empty ones too: a Safe Mode
# phase still takes the PC there and back), or one Normal phase. -Revert: always one phase (the Runner takes SafeMode
# Tweaks to Safe Mode by itself). Pure.
function Get-AkariPresetPhases($Preset, $Items, [switch]$Revert) {
    if ($Revert -or -not $Preset.Phases) { return @{ Name = $Preset.Name; Boot = 'Normal'; Items = @($Items | ForEach-Object { $h = $_.Clone(); $h.Remove('Phase'); $h }) } }
    $out = for ($k = 0; $k -lt @($Preset.Phases).Count; $k++) {
        @{ Name = $Preset.Phases[$k].Name; Boot = $Preset.Phases[$k].Boot; Items = @($Items | Where-Object { [int]$_.Phase -eq $k } | ForEach-Object { $h = $_.Clone(); $h.Remove('Phase'); $h }) }
    }
    $out
}