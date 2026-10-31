# The ISO Builder's options and removals (dot-sourced by Core\Iso.ps1): zISO's ten options (Data\Options\*.psd1),
# the apps, features, capabilities and packages the user picks, AkariOS copied into the image.

$AkariIsoOptionsDir = Join-Path $AkariIsoData 'Options'
$AkariIsoGroups = @('Update', 'Security', 'Apps')
# frameworks the app list leaves out (zISO's filter): removing them breaks the apps that use them
$AkariIsoFrameworkApps = 'DesktopAppInstaller|AppRuntime|VCLibs|UI\.Xaml|NET\.Native'

# a choice list without its empty entries (@($null) has one item). Pure.
function Get-AkariIsoList($Value) { , @(@($Value) | Where-Object { $_ }) }

# ---- options

# every option: its data plus Id (the file name), in page order (Group, then Order)
function Get-AkariIsoOptions {
    $o = foreach ($f in @(Get-ChildItem -LiteralPath $AkariIsoOptionsDir -Filter *.psd1 -File)) {
        $d = Import-PowerShellDataFile $f.FullName
        $d.Id = $f.BaseName
        $d
    }
    , @($o | Sort-Object { $AkariIsoGroups.IndexOf($_.Group) }, { $_.Order })
}

# a message when the picked ids don't go together (an unknown id, or two that exclude each other), else $null. Pure.
function Test-AkariIsoOptions($Ids, $Options) {
    $Ids = Get-AkariIsoList $Ids
    foreach ($id in $Ids) {
        $o = @($Options | Where-Object { $_.Id -eq $id })[0]
        if (-not $o) { return "Unknown ISO option: $id" }
        foreach ($x in @($o.Excludes)) {
            if ($x -and $Ids -contains $x) { return "'$($o.Name)' and '$(@($Options | Where-Object { $_.Id -eq $x })[0].Name)' can't be picked together." }
        }
    }
    $null
}

# the picked options' data, in page order. Pure.
function Get-AkariIsoPicked([hashtable]$Choices, $Options) { , @($Options | Where-Object { @($Choices.Options) -contains $_.Id }) }

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

# the names to remove: the user's picks plus what on the image matches an option's patterns, once each. Pure.
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
    $loaded = Mount-AkariOfflineHives $Mount
    try {
        foreach ($p in $Packages) {
            $name = ($p -split '_')[0]
            Write-AkariIsoRegistry @(@{ Path = "$store\Deprovisioned\$(Get-AkariAppFamily $p)"; Value = 'Key' }) $loaded
            Remove-AkariIsoKeys @("$store\InboxApplications\$($name)_*", "$store\Applications\$($name)_*", "$store\Staged\$($name)_*") $loaded
        }
    }
    finally { Dismount-AkariOfflineHives $loaded }
    foreach ($p in $Packages) {
        $name = ($p -split '_')[0]
        Write-Log "Removing $name"
        [void](Invoke-AkariDism "/Image:$Mount" /Set-NonRemovableAppPolicy "/PackageFamily:$(Get-AkariAppFamily $p)" /NonRemovable:0)
        $c = Invoke-AkariDism "/Image:$Mount" /Remove-ProvisionedAppxPackage "/PackageName:$p"
        if ($c -ne 0) { Write-Log "  DISM could not remove it (exit code $c)" }
        [void](Remove-AkariImagePaths $Mount @("Program Files\WindowsApps\$($name)_*", "Windows\SystemApps\$($name)_*"))
    }
}

# features, capabilities, OS packages: one DISM call each; a failure is logged and the build goes on (as zISO)
function Remove-AkariImageItems([string]$Mount, [ValidateSet('Feature', 'Capability', 'Package')][string]$Kind, [string[]]$Names) {
    foreach ($n in $Names) {
        Write-Log "Removing $($Kind.ToLower()) $n"
        $c = switch ($Kind) {
            'Feature' { Invoke-AkariDism "/Image:$Mount" /Disable-Feature "/FeatureName:$n" /Remove /NoRestart }
            'Capability' { Invoke-AkariDism "/Image:$Mount" /Remove-Capability "/CapabilityName:$n" }
            'Package' { Invoke-AkariDism "/Image:$Mount" /Remove-Package "/PackageName:$n" }
        }
        if ($c -ne 0 -and $c -ne 3010) { Write-Log "  DISM could not remove it (exit code $c)" }
    }
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
