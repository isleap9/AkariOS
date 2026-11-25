# The ISO Builder's removals (dot-sourced by Core\Iso.ps1): the apps, features, capabilities and packages the user and
# the removal groups pick, the leftovers, Minimal's component store pruning, AkariOS copied into the image, and the
# wizard's modes and removal groups (Iso\Wizard).

# frameworks the app list leaves out (zISO's filter): removing them breaks the apps that use them
$AkariIsoFrameworkApps = 'DesktopAppInstaller|AppRuntime|VCLibs|UI\.Xaml|NET\.Native'

# a choice list without its empty entries (@($null) has one item). Pure.
function Get-AkariIsoList($Value) { , @(@($Value) | Where-Object { $_ }) }

# ---- rows and names

# several "hide:" lists for Settings' SettingsPageVisibility (Defender's, AI's) become one row, or the last would win. Pure.
function Merge-AkariIsoRows($Rows) {
    $out = [System.Collections.Generic.List[hashtable]]::new()
    $hide = $null; $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($r in @($Rows)) {
        if ($r.Name -eq 'SettingsPageVisibility' -and "$($r.Value)" -like 'hide:*') {
            foreach ($p in "$($r.Value)".Substring(5).Split(';')) { if ($p -and -not $parts.Contains($p)) { $parts.Add($p) } }
            if (-not $hide) { $hide = $r.Clone(); $out.Add($hide) }
            continue
        }
        $out.Add($r)
    }
    if ($hide) { $hide.Value = 'hide:' + ($parts -join ';') + ';' }
    , $out.ToArray()
}

# the names to remove: the user's picks plus what on the image matches a group's patterns, once each. Pure.
function Resolve-AkariIsoNames($Picked, $Patterns, $Available) {
    $set = [System.Collections.Generic.List[string]]::new()
    foreach ($n in @($Picked)) { if ($n -and -not $set.Contains($n)) { $set.Add($n) } }
    foreach ($p in @($Patterns)) {
        foreach ($n in @($Available)) { if ($n -like $p -and -not $set.Contains($n)) { $set.Add($n) } }
    }
    , $set.ToArray()
}

# 'Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe' -> 'Microsoft.BingNews_8wekyb3d8bbwe'. Pure.
function Get-AkariAppFamily([string]$Package) {
    $p = $Package -split '_'
    "$($p[0])_$($p[-1])"
}

# ---- image reads (wrappers: tests mock these)

function Read-AkariImageApps([string]$Mount) {
    @(Get-AppxProvisionedPackage -Path $Mount -ErrorAction Stop | ForEach-Object { @{ Name = $_.DisplayName; Package = $_.PackageName } })
}
function Get-AkariImageFeatures([string]$Mount) {
    @(Get-WindowsOptionalFeature -Path $Mount -ErrorAction Stop | ForEach-Object { @{ Name = $_.FeatureName; State = "$($_.State)" } })
}
function Get-AkariImageCapabilities([string]$Mount) {
    @(Get-WindowsCapability -Path $Mount -ErrorAction Stop | Where-Object { "$($_.State)" -eq 'Installed' } | ForEach-Object { @{ Name = $_.Name; State = "$($_.State)" } })
}
function Get-AkariImagePackages([string]$Mount) {
    @(Get-WindowsPackage -Path $Mount -ErrorAction Stop | ForEach-Object { @{ Name = $_.PackageName; State = "$($_.PackageState)" } })
}

# the image's provisioned apps without the frameworks: @{ Name; Package }
function Get-AkariImageApps([string]$Mount) {
    Read-AkariImageApps $Mount | Where-Object { $_.Name -notmatch $AkariIsoFrameworkApps }
}

# ---- removals

# deletes the keys whose last part matches (rows 'SOFTWARE\...\Name*') in the loaded hives; a key an admin can't
# delete goes as TrustedInstaller
function Remove-AkariIsoKeys([string[]]$Patterns, [string[]]$Loaded) {
    foreach ($pat in @($Patterns)) {
        $hive, $rest = $pat -split '\\', 2
        if ($hive -notin $Loaded) { continue }
        $parent = "$AkariIsoRegRoot$hive\" + (Split-Path $rest)
        $leaf = Split-Path $rest -Leaf
        foreach ($k in @(Get-ChildItem -LiteralPath $parent -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like $leaf })) {
            try { Remove-Item -LiteralPath $k.PSPath -Recurse -Force -ErrorAction Stop }
            catch { Remove-AkariIsoKeyTrusted $k.Name }
        }
    }
}

# provisioned apps out of the image (zISO's Remove-Packages): deprovisioned in its registry so Windows doesn't bring
# them back, removed with DISM, their folders deleted
function Remove-AkariImageApps([string]$Mount, [string[]]$Packages) {
    $store = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
    # DISM first: it finds an offline image's provisioned apps through AppxAllUserStore's keys, so deleting them before
    # made every removal fail with exit code 2 (not found)
    foreach ($p in $Packages) {
        $name = ($p -split '_')[0]
        Invoke-AkariIsoOp "App $name" {
            Write-Log "Removing $name"
            [void](Invoke-AkariDism "/Image:$Mount" /Set-NonRemovableAppPolicy "/PackageFamily:$(Get-AkariAppFamily $p)" /NonRemovable:0)
            $c = Invoke-AkariDism "/Image:$Mount" /Remove-ProvisionedAppxPackage "/PackageName:$p"
            if ($c -ne 0) { Write-Log "  DISM could not remove it (exit code $c)" }
            [void](Remove-AkariImagePaths $Mount @("Program Files\WindowsApps\$($name)_*", "Windows\SystemApps\$($name)_*"))
            if ($c -eq 0) { @{ State = 'Done'; Note = '' } } else { @{ State = 'Failed'; Note = "DISM exit code $c; its files removed" } }
        }
    }
    # then each app marked deprovisioned (a feature update doesn't bring it back) and its keys DISM left removed
    $loaded = Mount-AkariOfflineHives $Mount
    try {
        foreach ($p in $Packages) {
            $name = ($p -split '_')[0]
            Write-AkariIsoRegistry @(@{ Path = "$store\Deprovisioned\$(Get-AkariAppFamily $p)"; Value = 'Key' }) $loaded
            Remove-AkariIsoKeys @("$store\InboxApplications\$($name)_*", "$store\Applications\$($name)_*", "$store\Staged\$($name)_*") $loaded
        }
    }
    finally { Dismount-AkariOfflineHives $loaded }
}

# an item's kind as the build page names it. Pure.
$AkariIsoKindNames = @{ Feature = 'Windows feature'; Capability = 'Optional feature'; Package = 'OS package' }

# features, capabilities, OS packages: one DISM call each, an operation each; a failure is logged and the build goes
# on (as zISO)
function Remove-AkariImageItems([string]$Mount, [ValidateSet('Feature', 'Capability', 'Package')][string]$Kind, [string[]]$Names) {
    foreach ($n in $Names) {
        Invoke-AkariIsoOp "$($AkariIsoKindNames[$Kind]) $n" {
            Write-Log "Removing $($Kind.ToLower()) $n"
            $c = switch ($Kind) {
                'Feature' { Invoke-AkariDism "/Image:$Mount" /Disable-Feature "/FeatureName:$n" /Remove /NoRestart }
                'Capability' { Invoke-AkariDism "/Image:$Mount" /Remove-Capability "/CapabilityName:$n" }
                'Package' { Invoke-AkariDism "/Image:$Mount" /Remove-Package "/PackageName:$n" }
            }
            if ($c -ne 0 -and $c -ne 3010) { Write-Log "  DISM could not remove it (exit code $c)" }
            if ($c -eq 0) { @{ State = 'Done'; Note = '' } }
            elseif ($c -eq 3010) { @{ State = 'Done'; Note = 'Finishes when the new Windows first starts' } }
            else { @{ State = 'Failed'; Note = "DISM exit code $c" } }
        }
    }
}

# Turbo (the Build settings): the Windows features out in one dism /Disable-Feature with a /FeatureName each (payload
# removed), then each one's state read back: Done when it is disabled or gone, Failed when it isn't
function Remove-AkariImageFeaturesAtOnce([string]$Mount, [string[]]$Names) {
    $Names = @($Names | Where-Object { $_ })
    if (-not $Names.Count) { return }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $kind = $AkariIsoKindNames['Feature']
    foreach ($n in $Names) { Add-AkariIsoOperation @{ Stage = $script:AkariIsoStage; Name = "$kind $n"; State = 'Running'; Seconds = 0; Note = '' } }
    Write-Log "Removing $($Names.Count) Windows features at once"
    $a = @("/Image:$Mount", '/Disable-Feature') + @($Names | ForEach-Object { "/FeatureName:$_" }) + @('/Remove', '/NoRestart')
    $code = Invoke-AkariDism @a
    if ($code -ne 0 -and $code -ne 3010) { Write-Log "  DISM exit code $($code): each feature's state read back" }
    $states = @{}
    foreach ($f in @(Get-AkariImageFeatures $Mount)) { $states[[string]$f.Name] = [string]$f.State }
    $each = $clock.Elapsed.TotalSeconds / $Names.Count
    foreach ($n in $Names) {
        if (-not $states.ContainsKey($n)) { $state = 'Done'; $note = 'Not in the image any more' }
        elseif ($states[$n] -like '*Disabled*') { $state = 'Done'; $note = if ($code -eq 3010) { 'Finishes when the new Windows first starts' } else { '' } }
        else { $state = 'Failed'; $note = "Still $($states[$n]) (DISM exit code $code)"; Write-Log "  $n is still $($states[$n])" }
        Complete-AkariIsoOp "$kind $n" $state $each $note
    }
}

# Remove leftover image data (the Build settings): $AkariIsoLeftovers, one operation each; all kept while the image
# has pending servicing
function Remove-AkariIsoLeftovers([string]$Mount) {
    if (Test-Path -LiteralPath (Join-Path $Mount $AkariIsoPendingXml)) {
        Write-Log 'The image has pending servicing (pending.xml): leftover data kept'
        Invoke-AkariIsoOp 'Leftover image data' { @{ State = 'Skipped'; Note = 'The image has pending servicing (pending.xml): kept' } }
        return
    }
    foreach ($path in $AkariIsoLeftovers) {
        Invoke-AkariIsoOp $path {
            $gone = Remove-AkariImagePaths $Mount @($path)
            if ($gone -gt 0) { @{ State = 'Done'; Note = "$gone removed" } } else { @{ State = 'Skipped'; Note = 'Nothing there' } }
        }
    }
}

# Minimal's component store pruning (Tiny11 Core, ADR 0010; the native PruneComponentStore): every WinSxS folder but
# the store's metadata and the runtimes Windows loads from it removed, ownership taken once for the store. Refused (the
# build fails, nothing removed) while servicing is pending or when the image's own runtimes can't be found.
function Remove-AkariIsoComponentStore([string]$Mount) {
    if (Test-Path -LiteralPath (Join-Path $Mount $AkariIsoPendingXml)) { throw 'The image has pending servicing (pending.xml): Minimal can''t prune its component store. Nothing was pruned.' }
    $store = Join-Path $Mount 'Windows\WinSxS'
    if (-not (Test-Path -LiteralPath $store -PathType Container)) { throw 'The image has no Windows\WinSxS folder: nothing to prune.' }
    $folders = @([IO.Directory]::GetDirectories($store) | ForEach-Object { [IO.Path]::GetFileName($_) })
    foreach ($family in $AkariIsoRequiredRuntimes) {
        $found = @($folders | Where-Object { $_.IndexOf($family, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and (Test-AkariKeepInComponentStore $_) })
        if (-not $found.Count) { throw "Minimal can't find the image's $family runtime in WinSxS: nothing was pruned." }
    }
    $removable = @($folders | Where-Object { -not (Test-AkariKeepInComponentStore $_) })
    Invoke-AkariIsoOp "$($removable.Count) component folders" {
        Grant-AkariOwnership $store | Out-Null
        $gone = 0
        foreach ($f in $removable) { $gone += Remove-AkariPaths @(Join-Path $store $f) }
        Write-Log "Pruned $gone of $($removable.Count) component folders"
        @{ State = 'Done'; Note = "$gone removed; $($folders.Count - $removable.Count) kept" }
    }
}

# ---- the wizard's modes and removal groups (src\Core\Iso\Wizard: the native app reads them too)

$AkariIsoWizardDir = Join-Path $PSScriptRoot 'Wizard'
# the preset the AkariOS mode bakes in; the Default user's RunOnce value that finishes it at each new account's first
# sign-in (the PowerShell app copied to C:\AkariOS: Akari.ps1 -FirstSignIn, started elevated: one UAC prompt)
$AkariIsoBakePreset = 'AkariOS'
$AkariIsoRunOnceKey = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$AkariIsoRunOnceName = 'AkariOS'
$AkariIsoFirstSignIn = "powershell.exe -NoProfile -WindowStyle Hidden -Command `"Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -File C:\AkariOS\Akari.ps1 -FirstSignIn' -Verb RunAs`""

# a Wizard folder's .psd1 files, each with Id = its file name, by Order then Id
function Read-AkariIsoWizard([string]$Folder) {
    $o = foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $AkariIsoWizardDir $Folder) -Filter *.psd1 -File)) {
        $d = Import-PowerShellDataFile $f.FullName
        $d.Id = $f.BaseName
        $d
    }
    $o | Sort-Object @{ Expression = { [int]$_.Order } }, @{ Expression = { $_.Id } }
}
# the removal groups (Name, Description, Kind, Risk, Order, Apps, Features, Capabilities, Packages, Registry,
# RemoveKeys, Remove, Boot, PruneComponentStore) and the modes (Name, Description, Tag, Order, Groups, Settings,
# AkariOS, Minimal)
function Get-AkariIsoGroups { Read-AkariIsoWizard 'Groups' }
function Get-AkariIsoModes { Read-AkariIsoWizard 'Modes' }

# the picked groups (ids), in Order; an unknown id throws
function Get-AkariIsoGroupsPicked($Ids, $All) {
    $ids = @($Ids | Where-Object { $_ })
    foreach ($id in $ids) { if (-not @($All | Where-Object { $_.Id -eq $id }).Count) { throw "Unknown removal group: $id" } }
    , @($All | Where-Object { $ids -contains $_.Id })
}

# the groups' app patterns, matched on the image's apps when it is built: 'appx:Safe' = the appx Group's rows rated
# Safe and not Keep (Select recommended), 'appx:AkariOS' = its rows not Keep (the AkariOS preset's "appx/*"),
# anything else as written. $Tweaks = the loaded Tweaks. Pure.
function Get-AkariIsoAppPatterns($Groups, $Tweaks) {
    $appx = @($Tweaks | Where-Object { $_.Id -like 'appx/*' })
    $out = [Collections.Generic.List[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($a in @($Groups | ForEach-Object { $_.Apps } | Where-Object { $_ })) {
        $names = if ($a -eq 'appx:Safe') { @($appx | Where-Object { $_.Risk -eq 'Safe' -and -not $_.Keep } | ForEach-Object { $_.Id.Substring(5) }) }
        elseif ($a -eq 'appx:AkariOS') { @($appx | Where-Object { -not $_.Keep } | ForEach-Object { $_.Id.Substring(5) }) }
        else { @($a) }
        foreach ($n in $names) { if ($seen.Add($n)) { $out.Add($n) } }
    }
    , $out.ToArray()
}

# a Tweak's registry path in the loaded image (under $Root), or $null where the image has no place for it: HKLM's
# SOFTWARE and SYSTEM (CurrentControlSet = ControlSet001), HKCU = the Default user's NTUSER.DAT (but
# Software\Classes), HKEY_USERS\.DEFAULT, HKEY_CLASSES_ROOT = SOFTWARE\Classes. Pure.
function Get-AkariIsoImagePath([string]$Path, [string]$Root = $AkariIsoRegRoot) {
    $p = if ($Path -like 'Registry::*') { $Path.Substring(10) } else { $Path }
    $cut = $p.IndexOfAny([char[]]@(':', '\'))
    $head = if ($cut -lt 0) { $p.ToUpperInvariant() } else { $p.Substring(0, $cut).ToUpperInvariant() }
    $rest = if ($cut -lt 0) { '' } else { $p.Substring($cut).TrimStart(':').Trim('\') }
    $hives = @{ HKLM = 'HKLM'; HKEY_LOCAL_MACHINE = 'HKLM'; HKCU = 'HKCU'; HKEY_CURRENT_USER = 'HKCU'; HKU = 'HKU'; HKEY_USERS = 'HKU'
        HKCR = 'HKCR'; HKEY_CLASSES_ROOT = 'HKCR'; HKCC = 'HKCC'; HKEY_CURRENT_CONFIG = 'HKCC' }
    if (-not $hives.ContainsKey($head)) { return $null }
    if ($cut -ge 0 -and $p[$cut] -eq ':' -and $head.StartsWith('HKEY_')) { return $null }
    $under = { param($prefix, $r) "$Root$prefix$(if ($r) { '\' + $r })" }
    # $s -eq $h or under it: what follows it ($null when it isn't)
    $after = { param($s, $h) if ($s -eq $h) { '' } elseif ($s -like "$h\*") { $s.Substring($h.Length + 1) } else { $null } }
    switch ($hives[$head]) {
        'HKLM' {
            $r = & $after $rest 'SYSTEM\CurrentControlSet'; if ($null -ne $r) { return & $under 'SYSTEM\ControlSet001' $r }
            $r = & $after $rest 'SYSTEM'; if ($null -ne $r) { return & $under 'SYSTEM' $r }
            $r = & $after $rest 'SOFTWARE'; if ($null -ne $r) { return & $under 'SOFTWARE' $r }
            return $null
        }
        'HKCU' { if ($null -ne (& $after $rest 'Software\Classes')) { return $null }; return & $under 'NTUSER' $rest }
        'HKU' { $r = & $after $rest '.DEFAULT'; if ($null -ne $r) { return & $under 'DEFAULT' $r }; return $null }
        'HKCR' { return & $under 'SOFTWARE\Classes' $rest }
    }
    $null
}

# a Tweak file with code in it (a foreach, a command, a script block: e.g. rows built in a loop), as the native loader
# finds it (Tweak.NeedsCode): its rows aren't plain data, so neither app bakes it. Each file parsed once.
$AkariIsoFileCode = @{}
function Test-AkariTweakFileCode([string]$Path) {
    if (-not $Path -or -not [IO.File]::Exists($Path)) { return $false }
    if (-not $AkariIsoFileCode.ContainsKey($Path)) {
        $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $AkariIsoFileCode[$Path] = $null -ne $ast.Find({
                param($a)
                $a -is [Management.Automation.Language.ForEachStatementAst] -or $a -is [Management.Automation.Language.CommandAst] -or
                $a -is [Management.Automation.Language.ScriptBlockExpressionAst]
            }, $true)
    }
    $AkariIsoFileCode[$Path]
}

# a Tweak written into the image whole: a Toggle or Choice of registry rows only (no script block or other code in
# its file, not a Group Entry, an install, Safe Mode or a restart), whose Requires the image answers (Win10 / Win11
# only), every row with a place in the image; a Choice over one named row with a Recommended value. Pure but for
# reading the Tweak's file.
function Test-AkariIsoBakeable($Tweak, [int]$Build) {
    if ($Tweak.Kind -notin 'Toggle', 'Choice') { return $false }
    if (Test-AkariTweakFileCode $Tweak.Source) { return $false }
    if ($Tweak.EntryKind -or @($Tweak.Winget | Where-Object { $_ }).Count -or $Tweak.SafeMode -or $Tweak.Restarts) { return $false }
    foreach ($p in $Tweak.PSObject.Properties) { if ($p.Value -is [scriptblock]) { return $false } }
    $rows = @($Tweak.Registry | Where-Object { $_ })
    if (-not $rows.Count) { return $false }
    foreach ($r in @($Tweak.Requires | Where-Object { $_ })) {
        if (-not (($r -eq 'Win11' -and $Build -ge 22000) -or ($r -eq 'Win10' -and $Build -lt 22000))) { return $false }
    }
    if ($Tweak.Kind -eq 'Choice' -and ($null -eq $Tweak.Recommended -or $null -eq $rows[0].Name)) { return $false }
    foreach ($r in $rows) { if ($null -eq (Get-AkariIsoImagePath $r.Path 'HKLM:\AkariIso_')) { return $false } }
    $true
}

# the preset's Apply items split for an image of $Build: InImage = @(@{ Tweak; Value (a Choice's) }) written into its
# hives, Later = the other ids, run at the first sign-in. Pure.
function Get-AkariIsoBake($Preset, $Tweaks, [int]$Build) {
    $byId = @{}
    foreach ($t in @($Tweaks)) { if (-not $byId.ContainsKey($t.Id)) { $byId[$t.Id] = $t } }
    $in = [Collections.Generic.List[object]]::new()
    $later = [Collections.Generic.List[string]]::new()
    foreach ($i in @((Resolve-AkariPreset $Preset $Tweaks).Items)) {
        $t = $byId[$i.Id]
        if ($i.Mode -eq 'Apply' -and $t -and (Test-AkariIsoBakeable $t $Build)) {
            $v = if ($t.Kind -eq 'Choice') { if ($null -ne $i.Value) { $i.Value } else { $t.Recommended } } else { $null }
            $in.Add(@{ Tweak = $t; Value = $v })
        }
        else { $later.Add($i.Id) }
    }
    @{ InImage = $in.ToArray(); Later = $later.ToArray() }
}

# the image's own app logos (name -> a copy in $Folder): each app's AppxManifest.xml under the mount's WindowsApps
# read as for installed apps (Get-AkariAppxLogos), the logo copied out, as the image is unmounted after a build
function Get-AkariImageAppLogos([string]$Mount, $Apps, [string]$Folder) {
    $pk = @(foreach ($a in @($Apps)) { @{ Name = $a.Name; InstallLocation = (Join-Path $Mount "Program Files\WindowsApps\$($a.Package)") } })
    $found = Get-AkariAppxLogos $pk
    $copies = @{}
    foreach ($n in @($found.Keys)) {
        try {
            [void][IO.Directory]::CreateDirectory($Folder)
            $copy = Join-Path $Folder ($n + [IO.Path]::GetExtension($found[$n]))
            [IO.File]::Copy($found[$n], $copy, $true)
            $copies[$n] = $copy
        } catch { }
    }
    $copies
}

# ---- the AkariOS mode: the preset's settings in the image, the rest at the first sign-in

# the baked Tweaks written into the loaded hives, one operation each (a row an admin can't write goes as
# TrustedInstaller; a Tweak whose hive the image lacks is skipped), then the Default user's RunOnce entry
function Invoke-AkariIsoBake([string]$Mount, [hashtable]$Choices) {
    $loaded = @(Mount-AkariOfflineHives $Mount)
    try {
        foreach ($item in @($Choices.Bake | Where-Object { $_ })) {
            Invoke-AkariIsoOp "Tweak $($item.Tweak.Name)" { Write-AkariIsoBakeItem $item $loaded }
        }
        if ($Choices.FirstSignIn -and $Choices.AkariDir) {
            Invoke-AkariIsoOp 'The rest of AkariOS at the first sign-in' {
                if ($loaded -notcontains 'NTUSER') { return @{ State = 'Skipped'; Note = 'The image has no Default user hive' } }
                Invoke-AkariRegistry @(@{ Path = "$AkariIsoRegRoot$AkariIsoRunOnceKey"; Name = $AkariIsoRunOnceName; Type = 'String'; Value = $AkariIsoFirstSignIn }) 'Apply'
                @{ State = 'Done'; Note = 'A RunOnce entry for each new account: one UAC prompt, then One-click''s console' }
            }
        }
    }
    finally { Dismount-AkariOfflineHives $loaded }
}
function Write-AkariIsoBakeItem($Item, $Loaded) {
    $t = $Item.Tweak
    $rows = @(foreach ($r in @($t.Registry)) { $c = $r.Clone(); $c.Path = Get-AkariIsoImagePath $r.Path; $c })
    # a hive the image doesn't have: nothing written (it would land in the real HKLM)
    foreach ($r in $rows) {
        $h = ($r.Path.Substring($AkariIsoRegRoot.Length) -split '\\')[0]
        if ($Loaded -notcontains $h) { return @{ State = 'Skipped'; Note = "The image has no $h hive" } }
    }
    if ($t.Kind -eq 'Choice') {
        $r = $rows[0]
        $one = @{ Path = $r.Path; Name = $r.Name; Type = $(if ($r.Type) { $r.Type } else { 'DWord' }); Value = $Item.Value }
        try { Invoke-AkariRegistry @($one) 'Apply' } catch { Invoke-AkariRegistryTrusted @($one) 'Apply' }
        return @{ State = 'Done'; Note = "$($Item.Value)" }
    }
    try { Invoke-AkariRegistry $rows 'Apply' } catch { Invoke-AkariRegistryTrusted $rows 'Apply' }
    @{ State = 'Done'; Note = '' }
}

# ---- AkariOS in the image

# a .lnk file (wrapper: tests mock it)
function New-AkariShortcutFile([string]$Lnk, [string]$Target, [string]$Arguments, [string]$WorkDir, [string]$Icon) {
    New-Item -Path (Split-Path $Lnk) -ItemType Directory -Force | Out-Null
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($Lnk)
    $s.TargetPath = $Target
    if ($Arguments) { $s.Arguments = $Arguments }
    $s.WorkingDirectory = $WorkDir
    if ($Icon) { $s.IconLocation = $Icon }
    $s.Description = 'AkariOS'
    $s.Save()
}

# this AkariOS ($Source = its folder) copied to the image's C:\AkariOS, with a Start menu and a desktop shortcut for
# every user (as build\Bootstrap.ps1 installs it). Without AkariOS.exe (a developer copy) the shortcut starts
# Akari.ps1 through PowerShell; it asks for administrator itself.
function Copy-AkariToImage([string]$Mount, [string]$Source) {
    $dest = Join-Path $Mount 'AkariOS'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -Path $dest -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $dest -Recurse -Force -ErrorAction Stop
    $exe = Test-Path -LiteralPath (Join-Path $Source 'AkariOS.exe')
    $target = if ($exe) { 'C:\AkariOS\AkariOS.exe' } else { 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' }
    $arg = if ($exe) { '' } else { '-NoProfile -ExecutionPolicy Bypass -STA -File "C:\AkariOS\Akari.ps1"' }
    foreach ($lnk in 'ProgramData\Microsoft\Windows\Start Menu\Programs\AkariOS.lnk', 'Users\Public\Desktop\AkariOS.lnk') {
        New-AkariShortcutFile (Join-Path $Mount $lnk) $target $arg 'C:\AkariOS' 'C:\AkariOS\Assets\AkariLogo.ico'
    }
}
