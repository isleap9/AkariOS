# Loader: reads one-file tweaks (Tweaks\<Section>\<Category>\*.ps1, each returning a hashtable)
# into normalized tweak objects, and reports files that break the rules in AkariOS-PLAN.md §7.

$AkariTweakFields = 'Id', 'Name', 'Description', 'Section', 'Category', 'Kind', 'Risk', 'Button', 'Confirm', 'Reboot', 'SafeMode',
    'Requires', 'Registry', 'Choices', 'Recommended', 'Default', 'Editable', 'Apply', 'Revert', 'Detect', 'Check', 'Actions', 'Source', 'Legacy',
    'EntryKind', 'Entries', 'KeepNames', 'Group', 'Package', 'Keep', 'Winget', 'WingetSource', 'After', 'AppType', 'StoreId'
# data-list Group handlers the engine knows (ADR 0002). Rows: the Entries are the data file's rows (every row is a
# Tweak); otherwise the Entries are what is on this PC (read live by the GUI), the rows only name and rate them.
# Apply / Detect: script text, {0} = the quoted Entry name, {1} = the quoted row StoreId (engine functions in
# Core\Appx.ps1 and Core\Winget.ps1). Reboot: doing it needs a restart.
$AkariEntryKinds = @{
    AppxRemove       = @{ Rows = $true; Button = 'Remove'; Reboot = $false; Apply = 'Remove-AkariAppx {0}'; Detect = '-not (Test-AkariAppxInstalled {0})' }
    CapabilityRemove = @{ Rows = $false; Button = 'Remove'; Reboot = $true; Apply = 'Remove-AkariCapability {0}'; Detect = '-not (Test-AkariCapabilityInstalled {0})' }
    FeatureDisable   = @{ Rows = $false; Button = 'Remove'; Reboot = $true; Apply = 'Disable-AkariFeature {0}'; Detect = '-not (Test-AkariFeatureEnabled {0})' }
    # a Store app the debloat removed, downloaded again from the Microsoft Store through winget
    StoreInstall     = @{ Rows = $true; Button = 'Install'; Reboot = $false; Apply = "Install-AkariWingetPackage {1} 'msstore'"; Detect = 'Test-AkariAppxInstalled {0}' }
}

# turns a tweak hashtable into the object every other part of Akari uses
function ConvertTo-AkariTweak([hashtable]$h, [string]$Source, [bool]$Legacy) {
    $o = [ordered]@{}
    foreach ($f in $AkariTweakFields) { $o[$f] = $h[$f] }
    if (-not $o.Kind) { $o.Kind = 'Toggle' }
    if (-not $o.Button) { $o.Button = 'Run' }
    $o.Reboot = [bool]$o.Reboot
    $o.SafeMode = [bool]$o.SafeMode
    $o.Editable = [bool]$o.Editable
    if ($null -ne $o.Registry) { $o.Registry = [hashtable[]]@($o.Registry) }
    $o.Keep = [bool]$o.Keep
    $o.Source = $Source
    $o.Legacy = $Legacy
    [pscustomobject]$o
}

# the data file row that names $Name (a row Name may have wildcards: 'Hello.Face.*'); for a capability, its name
# before the version counts too ('App.StepsRecorder~~~~0.0.1.0' -> row 'App.StepsRecorder')
function Get-AkariEntryRow($Group, [string]$Name) {
    $base = if ($Group.EntryKind -eq 'CapabilityRemove') { ($Name -split '~')[0] } else { $Name }
    @($Group.Entries | Where-Object { $Name -like $_.Name -or $base -like $_.Name }) | Select-Object -First 1
}

# one Entry of a data-list Group: id '<group-id>/<name>', an Action that does the Group's job (remove, install),
# Detect = already done. $Row: a data file row, or only @{ Name } (something on this PC the data file doesn't list:
# named after itself, Risk Caution). Keep: the row says so, or the name matches one of the Group's KeepNames
# (FR33THY's keep-list); a kept item with no Risk of its own is Advanced.
function New-AkariEntry($Group, [hashtable]$Row) {
    $k = $AkariEntryKinds[[string]$Group.EntryKind]
    if (-not $k) { throw "unknown EntryKind '$($Group.EntryKind)'" }
    $name = [string]$Row.Name
    $known = Get-AkariEntryRow $Group $name
    if ($known -and -not $Row.Display) { foreach ($f in 'Display', 'Description', 'Risk', 'Keep', 'StoreId') { if ($null -eq $Row[$f]) { $Row[$f] = $known[$f] } } }
    $keep = [bool]$Row.Keep -or [bool](@($Group.KeepNames | Where-Object { $name -like $_ }).Count)
    $risk = if ($Row.Risk) { $Row.Risk } elseif ($keep) { 'Advanced' } else { 'Caution' }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $h = @{
        Id = "$($Group.Id)/$name"; Name = $(if ($Row.Display) { $Row.Display } else { $name }); Description = $Row.Description
        Section = $Group.Section; Category = $Group.Category; Kind = 'Action'; Button = $k.Button; Reboot = $k.Reboot
        Risk = $risk; Keep = $keep; Group = $Group.Id; Package = $name; StoreId = $Row.StoreId; AppType = $Group.AppType
        Apply = [scriptblock]::Create(($k.Apply -f (& $q $name), (& $q $Row.StoreId)))
        Detect = [scriptblock]::Create(($k.Detect -f (& $q $name), (& $q $Row.StoreId)))
    }
    ConvertTo-AkariTweak $h $Group.Source $false
}

# an Entry id ('<group-id>/<name>') that is not a loaded Tweak (an installed app or a feature): built from the name.
# $null when no Group owns the id.
function Resolve-AkariEntry($Groups, [string]$Id) {
    $g = @($Groups | Where-Object { $Id.StartsWith("$($_.Id)/") }) | Select-Object -First 1
    if (-not $g -or $Id.Length -le $g.Id.Length + 1) { return $null }
    New-AkariEntry $g @{ Name = $Id.Substring($g.Id.Length + 1) }
}

# throws "<relative path>: <reason>" when the file breaks a rule
function Import-AkariTweakFile([string]$Path, [string]$TweaksRoot) {
    $rel = $Path
    if ($TweaksRoot -and $Path.StartsWith($TweaksRoot)) { $rel = $Path.Substring($TweaksRoot.Length).TrimStart('\') }
    $h = & $Path
    if ($h -isnot [hashtable]) { throw "${rel}: the file must return one hashtable" }
    foreach ($f in 'Id', 'Name', 'Description', 'Section', 'Category', 'Risk') {
        if (-not $h[$f]) { throw "${rel}: missing $f" }
    }
    if ($h.Id -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "${rel}: Id '$($h.Id)' must be kebab-case" }
    if ($h.Risk -notin 'Safe', 'Caution', 'Advanced') { throw "${rel}: Risk must be Safe, Caution or Advanced" }
    if ($h.Kind -eq 'Group') {
        # only data-list Groups so far: rows the engine turns into Tweaks (or uses to name what it finds on the PC)
        if (-not $h.EntryKind -or -not $AkariEntryKinds.ContainsKey([string]$h.EntryKind)) {
            throw "${rel}: a Group needs an EntryKind ($(($AkariEntryKinds.Keys | Sort-Object) -join ', '))"
        }
        if (-not $h.Entries) { throw "${rel}: a Group needs Entries" }
        foreach ($r in $h.Entries) {
            if ($r -isnot [hashtable] -or -not $r.Name) { throw "${rel}: every Entry needs a Name" }
            if ($r.Risk -and $r.Risk -notin 'Safe', 'Caution', 'Advanced') { throw "${rel}: Entry '$($r.Name)': Risk must be Safe, Caution or Advanced" }
            if ($h.EntryKind -eq 'StoreInstall' -and "$($r.StoreId)" -notmatch '^[A-Z0-9]+$') { throw "${rel}: Entry '$($r.Name)': StoreId must be a Microsoft Store product id" }
        }
    } elseif ($h.Kind -and $h.Kind -notin 'Toggle', 'Choice', 'Action') { throw "${rel}: Kind must be Toggle, Choice, Action or Group" }
    $catDir = Split-Path (Split-Path $Path -Parent) -Leaf
    $secDir = Split-Path (Split-Path (Split-Path $Path -Parent) -Parent) -Leaf
    if ($catDir -ne $h.Category -or $secDir -ne $h.Section) {
        throw "${rel}: Section/Category '$($h.Section)/$($h.Category)' must match the folder '$secDir/$catDir'"
    }
    $t = ConvertTo-AkariTweak $h $Path $false
    switch ($t.Kind) {
        'Toggle' {
            if (-not $t.Registry -and -not ($t.Apply -and $t.Revert)) { throw "${rel}: a Toggle needs Registry, or both Apply and Revert" }
            foreach ($e in $t.Registry) {
                foreach ($k in 'Path', 'Name', 'Type', 'Value') { if (-not $e.ContainsKey($k)) { throw "${rel}: Registry entry is missing $k" } }
                # Default may be $null (= delete on Revert), but it must be written down
                if (-not $e.ContainsKey('Default')) { throw "${rel}: Registry entry '$($e.Name)' is missing Default (use `$null to delete on Revert)" }
            }
        }
        'Choice' {
            if (-not $t.Registry -or $t.Registry.Count -ne 1) { throw "${rel}: a Choice needs exactly one Registry entry" }
            foreach ($k in 'Path', 'Name', 'Type') { if (-not $t.Registry[0].ContainsKey($k)) { throw "${rel}: Registry entry is missing $k" } }
            if (-not $t.Choices) { throw "${rel}: a Choice needs Choices" }
            foreach ($k in 'Recommended', 'Default') { if (-not $h.ContainsKey($k)) { throw "${rel}: a Choice needs $k" } }
            if (-not $t.Editable -and $t.Recommended -notin @($t.Choices | ForEach-Object { $_.Value })) {
                throw "${rel}: Recommended must be one of the Choices"
            }
        }
        'Action' {
            if ($t.Winget) {
                # an app from winget: the engine installs it (Core\Winget.ps1), then runs After; Detect = installed
                if ($t.Apply) { throw "${rel}: an Action with Winget gets its Apply from the engine; put extra steps in After" }
                $ids = @($t.Winget)
                foreach ($i in $ids) { if ($i -notmatch '^[\w.+-]+$') { throw "${rel}: Winget id '$i' is not a package id" } }
                # WingetSource 'msstore': a Microsoft Store app (its id is a Store product id)
                $src = if ($t.WingetSource) { [string]$t.WingetSource } else { 'winget' }
                if ($src -notin 'winget', 'msstore') { throw "${rel}: WingetSource must be winget or msstore" }
                $tail = if ($src -eq 'msstore') { " 'msstore'" } else { '' }
                $t.Apply = [scriptblock]::Create((@($ids | ForEach-Object { "Install-AkariWingetPackage '$_'$tail" }) + @("$($t.After)")) -join "`n")
                $t.Detect = [scriptblock]::Create((@($ids | ForEach-Object { "(Test-AkariWingetInstalled '$_'$tail)" }) -join ' -and '))
            } elseif ($t.After) { throw "${rel}: After is only for an Action with Winget" }
            if (-not $t.Apply) { throw "${rel}: an Action needs Apply" }
            if (-not (Select-String -Path $Path -Pattern '^\s*#\s*Action:\s*\S' -Quiet)) {
                throw "${rel}: an Action file needs a '# Action: <why it can't be a Toggle>' line"
            }
        }
    }
    foreach ($b in 'Apply', 'Revert', 'Detect', 'Check') {
        if ($t.$b -and "$($t.$b)" -match '(?i)\b(Pause|Read-Host|Clear-Host)\b') { throw "${rel}: $b uses $($Matches[1]); tweaks must not be interactive" }
    }
    $t
}

function Get-AkariTweaks([string]$TweaksRoot) {
    $TweaksRoot = (Resolve-Path $TweaksRoot).Path
    $tweaks = [System.Collections.Generic.List[object]]::new()
    $groups = [System.Collections.Generic.List[object]]::new()
    $problems = [System.Collections.Generic.List[object]]::new()
    # exactly <Section>\<Category>\file.ps1: the legacy top-level files are not tweak files
    $files = Get-ChildItem $TweaksRoot -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory } |
        ForEach-Object { Get-ChildItem $_.FullName -Filter *.ps1 -File } | Sort-Object FullName
    $seen = @{}
    foreach ($f in $files) {
        try { $t = Import-AkariTweakFile $f.FullName $TweaksRoot }
        catch { $problems.Add([pscustomobject]@{ File = $f.FullName; Level = 'Error'; Message = $_.Exception.Message }); continue }
        if ($seen.ContainsKey($t.Id)) {
            $problems.Add([pscustomobject]@{ File = $f.FullName; Level = 'Error'; Message = "Id '$($t.Id)' is already used by $($seen[$t.Id])" })
            continue
        }
        $seen[$t.Id] = $f.FullName
        if ($t.Kind -eq 'Group') {
            # the Group itself is not a Tweak of its own here: its Entries are (for the Installed kinds, only once the
            # GUI has read what is on the PC, through Resolve-AkariEntry)
            $groups.Add($t)
            if (-not $AkariEntryKinds[[string]$t.EntryKind].Rows) { continue }
            foreach ($r in $t.Entries) {
                $e = New-AkariEntry $t $r
                if ($seen.ContainsKey($e.Id)) {
                    $problems.Add([pscustomobject]@{ File = $f.FullName; Level = 'Error'; Message = "Id '$($e.Id)' is already used by $($seen[$e.Id])" })
                    continue
                }
                $seen[$e.Id] = $f.FullName
                $tweaks.Add($e)
            }
            continue
        }
        if ($t.Kind -eq 'Toggle' -and -not $t.Detect -and -not $t.Registry) {
            $problems.Add([pscustomobject]@{ File = $f.FullName; Level = 'Warning'; Message = 'no Detect: State falls back to what Akari last applied' })
        }
        $tweaks.Add($t)
    }
    @{ Tweaks = $tweaks; Groups = $groups; Problems = $problems }
}
