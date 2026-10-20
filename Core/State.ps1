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
        $e = $Tweak.Registry[0]
        try { $cur = Get-AkariRegValue $e.Path $e.Name } catch { return 'Unknown' }
        $def = Resolve-AkariDefault $Tweak.Default
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
