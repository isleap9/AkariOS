# Loader: reads one-file tweaks (Tweaks\<Section>\<Category>\*.ps1, each returning a hashtable)
# into normalized tweak objects, and reports files that break the rules in AkariOS-PLAN.md §7.

$AkariTweakFields = 'Id', 'Name', 'Description', 'Section', 'Category', 'Kind', 'Risk', 'Button', 'Confirm', 'Reboot', 'SafeMode',
    'Requires', 'Registry', 'Choices', 'Recommended', 'Default', 'Editable', 'Apply', 'Revert', 'Detect', 'Check', 'Actions', 'Source', 'Legacy'

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
    $o.Source = $Source
    $o.Legacy = $Legacy
    [pscustomobject]$o
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
    if ($h.Kind -eq 'Group') { throw "${rel}: Groups are not supported in tweak files yet" }
    if ($h.Kind -and $h.Kind -notin 'Toggle', 'Choice', 'Action') { throw "${rel}: Kind must be Toggle, Choice or Action" }
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
        if ($t.Kind -eq 'Toggle' -and -not $t.Detect -and -not $t.Registry) {
            $problems.Add([pscustomobject]@{ File = $f.FullName; Level = 'Warning'; Message = 'no Detect: State falls back to what Akari last applied' })
        }
        $tweaks.Add($t)
    }
    @{ Tweaks = $tweaks; Problems = $problems }
}
