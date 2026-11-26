# The ISO Builder (plan docs/plans/2026-10-31-iso-builder.md), after zoicware's zISO Tweaker (MIT): a custom
# Windows 11 ISO from a stock one. The ISO's files are copied to <out>\AkariIso\Media, the chosen edition exported to
# <out>\AkariIso\install.wim and mounted at <out>\AkariIso\Mount, its registry hives loaded at HKLM\AkariIso_<hive>
# and written, then the image saved, compressed back into Media, boot.wim patched and the ISO built with oscdimg.
# Native and system-changing calls only through the wrappers below (tests mock them). Nothing here touches this PC's
# own Windows.

if (-not $AkariIsoMarker) { $AkariIsoMarker = Join-Path $env:ProgramData 'Akari\iso-mount.json' }
# the image's hives: name -> file under the mounted image
$AkariIsoHives = [ordered]@{
    SOFTWARE = 'Windows\System32\config\SOFTWARE'
    SYSTEM   = 'Windows\System32\config\SYSTEM'
    DEFAULT  = 'Windows\System32\config\DEFAULT'
    NTUSER   = 'Users\Default\NTUSER.DAT'
}
$AkariIsoMinFree = 25GB
# where the loaded hives are, as a provider path prefix (tests point it at a test key under HKCU)
if (-not $AkariIsoRegRoot) { $AkariIsoRegRoot = 'HKLM:\AkariIso_' }
# the report names the version that built the ISO (the background job doesn't load Version.ps1 itself)
if (-not $AkariVersion) { . (Join-Path $PSScriptRoot 'Version.ps1') }
. (Join-Path $PSScriptRoot 'Iso\Image.ps1')

# ---- wrappers (tests mock these)

# the ISO mounted as a drive: returns its root ('E:\')
function Mount-AkariDiskImage([string]$Path) {
    $v = Mount-DiskImage -ImagePath $Path -StorageType ISO -PassThru -ErrorAction Stop | Get-Volume
    "$($v.DriveLetter):\"
}
function Dismount-AkariDiskImage([string]$Path) { Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue | Out-Null }

# @{ Free; Format } of the drive holding $Path
function Get-AkariDriveInfo([string]$Path) {
    $d = [IO.DriveInfo]::new([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)))
    @{ Free = $d.AvailableFreeSpace; Format = $d.DriveFormat }
}

# the images in a .wim / .esd / .swm: @{ Index; Name; Version; Architecture }
function Get-AkariWimImages([string]$Path) {
    foreach ($i in @(Get-WindowsImage -ImagePath $Path -ErrorAction Stop)) {
        $d = Get-WindowsImage -ImagePath $Path -Index $i.ImageIndex -ErrorAction Stop
        @{ Index = [int]$i.ImageIndex; Name = $i.ImageName; Version = "$($d.Version)"; Architecture = $d.Architecture }
    }
}

# one image of $Source into a new $Dest (.swm: all its parts read); $Compression max / fast / recovery (install.esd:
# dism.exe /Export-Image, as the native app exports)
function Export-AkariWim([string]$Source, [int]$Index, [string]$Dest, [string]$Compression) {
    if ($Compression -eq 'recovery') {
        $a = @('/Export-Image', "/SourceImageFile:$Source")
        if ($Source -like '*.swm') { $a += "/SWMFile:$([IO.Path]::Combine([IO.Path]::GetDirectoryName($Source), 'install*.swm'))" }
        $a += "/SourceIndex:$Index", "/DestinationImageFile:$Dest", '/Compress:recovery'
        $code = Invoke-AkariDism @a
        if ($code -ne 0) { throw "DISM could not export the image (exit code $code)" }
        return
    }
    $p = @{ SourceImagePath = $Source; SourceIndex = $Index; DestinationImagePath = $Dest; CompressionType = $Compression }
    if ($Source -like '*.swm') { $p.SplitImageFilePattern = Join-Path (Split-Path $Source) 'install*.swm' }
    Export-WindowsImage @p -ErrorAction Stop | Out-Null
}
function Mount-AkariWim([string]$Path, [int]$Index, [string]$Mount) { Mount-WindowsImage -ImagePath $Path -Index $Index -Path $Mount -ErrorAction Stop | Out-Null }
function Save-AkariWim([string]$Mount) { Dismount-WindowsImage -Path $Mount -Save -ErrorAction Stop | Out-Null }
function Undo-AkariWim([string]$Mount) {
    Dismount-WindowsImage -Path $Mount -Discard -ErrorAction SilentlyContinue | Out-Null
    Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null
}

# oscdimg.exe from the Windows ADK, or $null
function Get-AkariOscdimg {
    foreach ($a in 'amd64', 'x86') {
        $p = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\$a\Oscdimg\oscdimg.exe"
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $null
}

# makes sure oscdimg is there: installs the ADK's Deployment Tools (Microsoft's adksetup, quiet) when it isn't.
# Returns oscdimg's path, or throws.
function Install-AkariAdk {
    $o = Get-AkariOscdimg
    if ($o) { return $o }
    $setup = Join-Path $env:TEMP 'akari-adksetup.exe'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2196127' -OutFile $setup -UseBasicParsing -ErrorAction Stop
    try { [void](Invoke-AkariExe $setup @('/quiet', '/norestart', '/features', 'OptionId.DeploymentTools')) }
    finally { Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue }
    $o = Get-AkariOscdimg
    if (-not $o) { throw 'The Windows ADK Deployment Tools did not install (oscdimg.exe is missing).' }
    $o
}

# ---- pure helpers

# <out>\AkariIso and its parts
function Get-AkariIsoWork([string]$OutDir) {
    $r = Join-Path $OutDir 'AkariIso'
    @{ Root = $r; Media = Join-Path $r 'Media'; Mount = Join-Path $r 'Mount'; Wim = Join-Path $r 'install.wim' }
}

# oscdimg's arguments: BIOS + UEFI boot when the media has both boot files, UEFI only otherwise
function Get-AkariOscdimgArgs([string]$Media, [string]$Out) {
    $etfs = Join-Path $Media 'boot\etfsboot.com'
    $efi = Join-Path $Media 'efi\microsoft\boot\efisys.bin'
    if (-not (Test-Path -LiteralPath $efi)) { throw 'The ISO has no efi\microsoft\boot\efisys.bin: it can''t boot.' }
    $boot = if (Test-Path -LiteralPath $etfs) { "-bootdata:2#p0,e,b$etfs#pEF,e,b$efi" } else { "-bootdata:1#pEF,e,b$efi" }
    @('-m', '-o', '-u2', '-udfver102', $boot, $Media, $Out)
}

# data rows ('SOFTWARE\...') -> registry rows under the loaded hives ('HKLM:\AkariIso_SOFTWARE\...')
function ConvertTo-AkariIsoRows($Rows) {
    foreach ($r in @($Rows)) {
        $hive, $rest = $r.Path -split '\\', 2
        if ($hive -notin $AkariIsoHives.Keys) { throw "Unknown hive in ISO row: $($r.Path)" }
        $h = $r.Clone()
        $h.Path = "$AkariIsoRegRoot$hive\$rest"
        $h.Hive = $hive
        # binary values are hex text in the data files
        if ($h.Type -eq 'Binary' -and $h.Value -is [string]) { $h.Value = ConvertFrom-AkariHex $h.Value }
        $h
    }
}


# ---- the Build settings (the native IsoBuildSettings)

# the final compression: Recovery = install.esd (/Compress:recovery), Maximum = install.wim max (the default), Fast
$AkariIsoCompressions = [ordered]@{ Recovery = 'Recovery ESD (smallest, slowest)'; Maximum = 'Maximum WIM'; Fast = 'Fast WIM (largest, quickest)' }
# Remove leftover image data's allow-list, paths under the mounted image (the last part may hold wildcards): downloaded
# updates, temp files, archived CBS and DISM logs, Windows Error Reporting's queues, crash dumps. Kept whole while the
# image has pending servicing ($AkariIsoPendingXml).
$AkariIsoLeftovers = @(
    'Windows\SoftwareDistribution\Download\*', 'Windows\Temp\*', 'Windows\Logs\CBS\*.cab', 'Windows\Logs\CBS\CbsPersist_*.log'
    'Windows\Logs\DISM\*.bak', 'ProgramData\Microsoft\Windows\WER\ReportQueue\*', 'ProgramData\Microsoft\Windows\WER\ReportArchive\*'
    'ProgramData\Microsoft\Windows\WER\Temp\*', 'Windows\Minidump\*', 'Windows\MEMORY.DMP', 'Windows\LiveKernelReports\*.dmp'
)
$AkariIsoPendingXml = 'Windows\WinSxS\pending.xml'
# Minimal's component store pruning (Tiny11 Core, ADR 0010; the native IsoWizard.KeepInComponentStore): the WinSxS
# folders it keeps = the store's own metadata and the runtimes Windows still loads from it (common controls, GDI+,
# isolation automation, the VC CRTs, the servicing stack); it refuses unless it finds the $AkariIsoRequiredRuntimes
$AkariIsoStoreMetadata = @('Catalogs', 'FileMaps', 'Fusion', 'InstallTemp', 'Manifests', 'SettingsManifests', 'Temp')
$AkariIsoStoreRuntimes = '(?:common-controls|c\.\.-controls|gdiplus|isolationautomation|utomation\.proxystub|microsoft\.vc\d+\.crt|servicing|s\.\.(?:ngstack|stack))'
$AkariIsoRequiredRuntimes = @('common-controls', 'gdiplus', 'servicing')
# a WinSxS folder the pruning keeps. Pure.
function Test-AkariKeepInComponentStore([string]$Folder) { ($AkariIsoStoreMetadata -contains $Folder) -or ($Folder -match $AkariIsoStoreRuntimes) }

# $Choices.Settings as @{ Compression (a key of $AkariIsoCompressions); Turbo (the Windows features in one DISM call,
# each read back); CleanLeftovers ($AkariIsoLeftovers removed); LeaveOutNetFx3Files (sources\sxs off the ISO);
# AddDrivers (X7: this PC's third-party drivers exported and added to the image) };
# missing = the defaults: Maximum, all off. Pure.
function Get-AkariIsoSettings([hashtable]$Choices) {
    $s = $Choices.Settings
    $comp = 'Maximum'
    if ($s) { foreach ($k in $AkariIsoCompressions.Keys) { if ($k -eq "$($s.Compression)") { $comp = $k } } }
    @{ Compression = $comp; Turbo = [bool]($s -and $s.Turbo); CleanLeftovers = [bool]($s -and $s.CleanLeftovers); LeaveOutNetFx3Files = [bool]($s -and $s.LeaveOutNetFx3Files)
        AddDrivers = [bool]($s -and $s.AddDrivers) }
}
# the settings as Review's lines (the native IsoBuildSettings.Lines). Pure.
function Get-AkariIsoSettingsLines([hashtable]$Settings) {
    $on = { param($b) if ($b) { 'On' } else { 'Off' } }
    @(
        "Compression: $($AkariIsoCompressions[$Settings.Compression])"
        "Turbo feature removal: $(& $on $Settings.Turbo)"
        "Remove leftover image data: $(& $on $Settings.CleanLeftovers)"
        ".NET 3.5's setup files on the ISO: $(if ($Settings.LeaveOutNetFx3Files) { 'Left out' } else { 'Kept' })"
        "This PC's drivers: $(if ($Settings.AddDrivers) { 'Added' } else { 'Not added' })"
    )
}

# the build's ordered steps: @{ Id; Text }. $Groups = the picked removal groups (Get-AkariIsoGroupsPicked): their
# lists add the removal steps, and the settings, files and boot.wim steps come only when a group has some. .NET 3.5
# and the component store cleanup come right after the apps, before any feature, capability or package is removed
# (those leave operations pending, and DISM refuses the cleanup then); Minimal's pruning (a group with
# PruneComponentStore) after the leftovers, before the image is saved. Pure.
function New-AkariIsoPlan([hashtable]$Choices, $Groups = @()) {
    $s = [System.Collections.Generic.List[object]]::new()
    $add = { param($id, $text) $s.Add(@{ Id = $id; Text = $text }) }
    $g = @($Groups | Where-Object { $_ })
    $has = { param($k) [bool]@($g | Where-Object { @($_[$k] | Where-Object { $_ }).Count }).Count }
    & $add 'Adk' 'Getting the ISO tool ready (Windows ADK)'
    & $add 'Mount' "Mounting $($Choices.Edition)"
    if ((Get-AkariIsoSettings $Choices).AddDrivers) { & $add 'Drivers' 'Adding this PC''s drivers' }
    if ((Get-AkariIsoList $Choices.Apps).Count -or (Get-AkariIsoList $Choices.AppPatterns).Count) { & $add 'Apps' 'Removing apps' }
    & $add 'NetFx3' 'Adding .NET Framework 3.5'
    & $add 'Cleanup' 'Cleaning up the component store'
    if ((Get-AkariIsoList $Choices.Features).Count -or (& $has 'Features')) { & $add 'Features' 'Removing Windows features' }
    if ((Get-AkariIsoList $Choices.Capabilities).Count -or (& $has 'Capabilities')) { & $add 'Capabilities' 'Removing optional features (capabilities)' }
    if ((Get-AkariIsoList $Choices.Packages).Count -or (& $has 'Packages')) { & $add 'Packages' 'Removing OS packages' }
    if ((& $has 'Registry') -or (& $has 'RemoveKeys')) { & $add 'Registry' 'Writing settings into the image''s registry' }
    if (@($Choices.Bake | Where-Object { $_ }).Count -or ($Choices.FirstSignIn -and $Choices.AkariDir)) { & $add 'Bake' 'Writing the AkariOS settings into the image' }
    if (& $has 'Remove') { & $add 'Files' 'Removing files from the image' }
    if ($Choices.AkariDir) { & $add 'AkariOS' 'Adding AkariOS to the image' }
    $set = Get-AkariIsoSettings $Choices
    if ($set.CleanLeftovers) { & $add 'Leftovers' 'Removing leftover image data' }
    if (@($g | Where-Object { $_.PruneComponentStore }).Count) { & $add 'Prune' 'Pruning the component store (Minimal: no updates or repairs afterwards)' }
    & $add 'Commit' 'Saving the image'
    & $add 'Compress' $(switch ($set.Compression) {
            'Recovery' { 'Compressing install.esd (recovery compression)' }
            'Fast' { 'Compressing install.wim (fast compression)' }
            default { 'Compressing install.wim' }
        })
    if (& $has 'Boot') { & $add 'Boot' 'Skipping the Windows 11 requirements in setup (boot.wim)' }
    if ($Choices.Unattend) { & $add 'Answer' 'Adding the answer file (autounattend.xml)' }
    if ($set.LeaveOutNetFx3Files) { & $add 'NoSxs' 'Leaving .NET Framework 3.5''s setup files off the ISO' }
    & $add 'Iso' 'Building the ISO'
    & $add 'Tidy' 'Removing the work folder'
    , $s.ToArray()
}

# the ISO's file name: <source>-Akari.iso
function Get-AkariIsoOutName([string]$Iso) {
    $n = if ($Iso) { [IO.Path]::GetFileNameWithoutExtension($Iso) } else { 'Windows11' }
    "$n-Akari.iso"
}

# ---- the work folder

# a message when $OutDir can't hold a build (not NTFS, under 25 GB free), else $null
function Test-AkariIsoSpace([string]$OutDir) {
    $d = Get-AkariDriveInfo $OutDir
    if ($d.Format -ne 'NTFS') { return "The output folder must be on an NTFS drive (this one is $($d.Format))." }
    if ($d.Free -lt $AkariIsoMinFree) { return ('The output drive needs {0} GB free (it has {1:N1} GB).' -f ($AkariIsoMinFree / 1GB), ($d.Free / 1GB)) }
    $null
}

function Find-AkariInstallImage([string]$Media) {
    foreach ($n in 'install.wim', 'install.esd', 'install.swm') {
        $p = Join-Path $Media "sources\$n"
        if (Test-Path -LiteralPath $p) { return $p }
    }
    $null
}

# the editions in an install image: @{ Index; Name; Version; Supported } (Supported = Windows 11, build 22000+)
function Get-AkariIsoEditions([string]$Image) {
    , @(foreach ($i in @(Get-AkariWimImages $Image)) {
            $b = try { ([version]$i.Version).Build } catch { 0 }
            @{ Index = $i.Index; Name = $i.Name; Version = $i.Version; Supported = ($b -ge 22000) }
        })
}

# copies the ISO's files to <out>\AkariIso\Media (a previous build's folder is cleared first) and reads its editions:
# @{ Work; Image; Editions }. Throws with a message for the user.
function Open-AkariIsoSource([string]$Iso, [string]$OutDir) {
    $msg = Test-AkariIsoSpace $OutDir
    if ($msg) { throw $msg }
    $w = Get-AkariIsoWork $OutDir
    Clear-AkariIsoLeftover
    if (Test-Path -LiteralPath $w.Root) { Remove-Item -LiteralPath $w.Root -Recurse -Force -ErrorAction Stop }
    New-Item -Path $w.Media -ItemType Directory -Force | Out-Null
    New-Item -Path $w.Mount -ItemType Directory -Force | Out-Null
    Write-Log "Copying $Iso"
    $root = Mount-AkariDiskImage $Iso
    try { Copy-Item -Path (Join-Path $root '*') -Destination $w.Media -Recurse -Force -ErrorAction Stop }
    finally { Dismount-AkariDiskImage $Iso }
    # files copied off a disc are read-only
    Get-ChildItem -LiteralPath $w.Media -Recurse -File -Force | ForEach-Object { $_.Attributes = 'Normal' }
    $img = Find-AkariInstallImage $w.Media
    if (-not $img) { throw 'This ISO has no sources\install.wim, install.esd or install.swm: it isn''t a Windows setup ISO.' }
    $eds = Get-AkariIsoEditions $img
    if (-not @($eds | Where-Object { $_.Supported })) { throw 'This ISO isn''t Windows 11: the ISO Builder only works on Windows 11 images.' }
    @{ Work = $w; Image = $img; Editions = @($eds) }
}

# the mount Akari left (crash, power loss): read from $AkariIsoMarker
function Get-AkariIsoMarker {
    if (-not (Test-Path -LiteralPath $AkariIsoMarker)) { return $null }
    try { Get-Content -LiteralPath $AkariIsoMarker -Raw | ConvertFrom-Json } catch { $null }
}
# what is mounted: the folder, and which edition of which image (0 / '' = boot.wim or not known)
function Set-AkariIsoMarker([string]$Mount, [string]$Image = '', [int]$Index = 0) {
    New-Item -Path (Split-Path $AkariIsoMarker) -ItemType Directory -Force | Out-Null
    @{ Mount = $Mount; Image = $Image; Index = $Index } | ConvertTo-Json | Set-Content -LiteralPath $AkariIsoMarker -Encoding UTF8
}
function Clear-AkariIsoMarker { Remove-Item -LiteralPath $AkariIsoMarker -Force -ErrorAction SilentlyContinue }

# $true when this edition ($Image, $Index) is the one mounted in $Work; without $Image, any mount there counts
function Test-AkariIsoMounted($Work, [string]$Image = '', [int]$Index = 0) {
    $m = Get-AkariIsoMarker
    if (-not $m -or $m.Mount -ne $Work.Mount) { return $false }
    if (-not $Image) { return $true }
    [bool]($m.Image -eq $Image -and [int]$m.Index -eq $Index)
}

# the chosen edition exported to <out>\AkariIso\install.wim and mounted (once: the page mounts it to read its apps;
# another edition mounted there is discarded first)
function Mount-AkariIsoEdition($Work, [string]$Image, [int]$Index) {
    if (Test-AkariIsoMounted $Work $Image $Index) { return }
    if (Get-AkariIsoMarker) { Clear-AkariIsoLeftover }
    Remove-Item -LiteralPath $Work.Wim -Force -ErrorAction SilentlyContinue
    Export-AkariWim $Image $Index $Work.Wim 'fast'
    New-Item -Path $Work.Mount -ItemType Directory -Force | Out-Null
    Set-AkariIsoMarker $Work.Mount $Image $Index
    try { Mount-AkariWim $Work.Wim 1 $Work.Mount }
    catch { Undo-AkariWim $Work.Mount; Clear-AkariIsoMarker; throw }
}

# a mount left behind by a build that didn't finish: hives unloaded, image discarded. On launch; never throws.
function Clear-AkariIsoLeftover {
    $m = Get-AkariIsoMarker
    if (-not $m) { return }
    try {
        Write-ErrLog "ISO Builder: discarding the image left mounted at $($m.Mount)"
        Dismount-AkariOfflineHives
        Undo-AkariWim $m.Mount
    }
    catch { Write-ErrLog "ISO Builder: leftover cleanup failed: $($_.Exception.Message)" }
    Clear-AkariIsoMarker
}

# ---- the image's registry

# loads the hives the mounted image has: returns their names
function Mount-AkariOfflineHives([string]$Mount) {
    @(foreach ($h in $AkariIsoHives.Keys) {
            $f = Join-Path $Mount $AkariIsoHives[$h]
            if (-not (Test-Path -LiteralPath $f)) { continue }
            if ((Invoke-AkariRegExe load "HKLM\AkariIso_$h" $f) -eq 0) { $h } else { Write-Log "Could not load the image's $h hive" }
        })
}

# unloads them (a few tries: a handle .NET still holds keeps a hive loaded until collected)
function Dismount-AkariOfflineHives([string[]]$Names = @($AkariIsoHives.Keys)) {
    foreach ($h in $Names) {
        for ($i = 0; $i -lt 3; $i++) {
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            if ((Invoke-AkariRegExe unload "HKLM\AkariIso_$h") -eq 0) { break }
            if ($i -lt 2) { Start-Sleep -Milliseconds 500 }
        }
    }
}

# writes data rows into the loaded hives: rows of a hive that isn't loaded are skipped; a row an admin can't write
# goes again as TrustedInstaller (as do rows marked Trusted)
function Write-AkariIsoRegistry($Rows, [string[]]$Loaded) {
    $trusted = [System.Collections.Generic.List[hashtable]]::new()
    $version = $null
    foreach ($r in @(ConvertTo-AkariIsoRows (Merge-AkariIsoRows $Rows))) {
        if ($r.Hive -notin $Loaded) { continue }
        # {DisplayVersion} = the image's own version (Disable version upgrades)
        if ($r.Value -eq '{DisplayVersion}') {
            if (-not $version) { $version = Get-AkariRegValue "$($AkariIsoRegRoot)SOFTWARE\Microsoft\Windows NT\CurrentVersion" 'DisplayVersion' }
            if (-not $version) { Write-Log "The image has no DisplayVersion: $($r.Name) left out"; continue }
            $r.Value = $version
        }
        if ($r.Trusted) { $trusted.Add($r); continue }
        try { Invoke-AkariRegistry @($r) 'Apply' }
        catch {
            if ($r.ContainsKey('Name')) { $trusted.Add($r) }
            elseif ($null -eq $r.Value) { Remove-AkariIsoKeyTrusted ('HKEY_LOCAL_MACHINE\' + $r.Path.Substring(6)) }
            else { Write-Log "Could not change $($r.Path): $($_.Exception.Message)" }
        }
    }
    if ($trusted.Count) { Invoke-AkariRegistryTrusted $trusted.ToArray() 'Apply' }
}

# deletes a key ('HKEY_LOCAL_MACHINE\...') with its contents as TrustedInstaller (Defender's services, for one)
function Remove-AkariIsoKeyTrusted([string]$Key) {
    if ($Key -notlike 'HKEY_LOCAL_MACHINE\*') { return }
    Run-Trusted "Remove-Item -LiteralPath 'Registry::$($Key -replace "'", "''")' -Recurse -Force -ErrorAction SilentlyContinue"
}

# loads the hives, writes the rows and deletes the wildcard keys, unloads them
function Invoke-AkariIsoRegistry([string]$Mount, $Rows, [string[]]$Keys = @()) {
    $loaded = Mount-AkariOfflineHives $Mount
    try {
        Write-AkariIsoRegistry $Rows $loaded
        if ($Keys) { Remove-AkariIsoKeys $Keys $loaded }
    }
    finally { Dismount-AkariOfflineHives $loaded }
}

# removes paths under the mounted image (wildcards allowed), taking ownership first: returns the count
function Remove-AkariImagePaths([string]$Mount, [string[]]$Paths) {
    $n = 0
    foreach ($p in $Paths) {
        foreach ($i in @(Get-Item -Path (Join-Path $Mount $p) -Force -ErrorAction SilentlyContinue)) {
            Grant-AkariOwnership $i.FullName
            $n += Remove-AkariPaths @($i.FullName)
        }
    }
    $n
}

# ---- the build's operations and report (the native IsoReport's JSON: <name>.report.json next to the ISO)

# an operation reported to the page: @{ Stage (its step's index); Name; State Running|Done|Skipped|Failed; Seconds;
# Note }, into the background job's $AkariShared.IsoOps (elsewhere nothing; the oracle records it)
function Add-AkariIsoOperation([hashtable]$Operation) {
    $s = Get-Variable AkariShared -ValueOnly -ErrorAction SilentlyContinue
    if ($s -is [hashtable] -and $s.IsoOps -is [Collections.IList]) { [void]$s.IsoOps.Add($Operation) }
}

# one operation of the running stage: Running, then how $AkariOpWork ended (its last output, @{ State; Note }); a
# throw = Failed, and the build fails as before. No log line of its own. (Odd names: $AkariOpWork runs in this
# function's scope chain, so a name of its own would hide the caller's $name, $n...)
function Invoke-AkariIsoOp([string]$AkariOpName, [scriptblock]$AkariOpWork) {
    $akariOpClock = [Diagnostics.Stopwatch]::StartNew()
    Add-AkariIsoOperation @{ Stage = $script:AkariIsoStage; Name = $AkariOpName; State = 'Running'; Seconds = 0; Note = '' }
    try { $akariOpEnd = @(& $AkariOpWork)[-1] }
    catch { Complete-AkariIsoOp $AkariOpName 'Failed' $akariOpClock.Elapsed.TotalSeconds $_.Exception.Message; throw }
    Complete-AkariIsoOp $AkariOpName $akariOpEnd.State $akariOpClock.Elapsed.TotalSeconds "$($akariOpEnd.Note)"
}
# how an operation ended: to the page and the running stage's report
function Complete-AkariIsoOp([string]$Name, [string]$State, [double]$Seconds, [string]$Note) {
    $sec = [Math]::Round($Seconds, 1)
    Add-AkariIsoOperation @{ Stage = $script:AkariIsoStage; Name = $Name; State = $State; Seconds = $sec; Note = $Note }
    if ($null -ne $script:AkariIsoStageOps) { $script:AkariIsoStageOps.Add([ordered]@{ name = $Name; state = $State; seconds = $sec; note = $Note }) }
}

# a stage of the report: its step, how it ended, its time, its operations
function New-AkariIsoReportStage($Step, [string]$State, [double]$Seconds, $Operations) {
    [ordered]@{ id = $Step.Id; text = $Step.Text; state = $State; seconds = [Math]::Round($Seconds, 1); operations = @($Operations) }
}

# the report (the native IsoReport's fields, camelCase): what was built from what, each stage, the ISO's size and
# SHA-256, or why it failed
function New-AkariIsoReport([hashtable]$Choices, [string]$Out, [datetime]$Started, [bool]$Ok, [string]$Message, $Stages, [long]$Size = 0, [string]$Sha = '') {
    [ordered]@{
        akariOS = "$AkariVersion"; started = $Started.ToString('o'); finished = (Get-Date).ToString('o'); ok = $Ok; message = $Message
        source = "$($Choices.Iso)"; edition = "$($Choices.Edition)"; iso = $Out
        settings = $(
            $set = Get-AkariIsoSettings $Choices
            [ordered]@{ compression = $set.Compression; turbo = $set.Turbo; cleanLeftovers = $set.CleanLeftovers; leaveOutNetFx3Files = $set.LeaveOutNetFx3Files; addDrivers = $set.AddDrivers })
        size = $Size; sha256 = $Sha; stages = @($Stages)
    }
}

# the report's file for an ISO: Win11-Akari.iso -> Win11-Akari.report.json. Pure.
function Get-AkariIsoReportFile([string]$Iso) { [IO.Path]::ChangeExtension($Iso, '.report.json') }

# the report next to the ISO; never fails the build (a folder that can't be written = no file)
function Save-AkariIsoReport($Report) {
    try {
        $file = Get-AkariIsoReportFile $Report.iso
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file))
        [IO.File]::WriteAllText($file, (ConvertTo-Json $Report -Depth 8), [Text.UTF8Encoding]::new($false))
    }
    catch { }
    $Report
}

# a file's SHA-256 as lowercase hex ('' when it isn't there)
function Get-AkariFileSha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $s = [IO.File]::OpenRead($Path)
    try { -join @([Security.Cryptography.SHA256]::Create().ComputeHash($s) | ForEach-Object { $_.ToString('x2') }) }
    finally { $s.Dispose() }
}

# ---- the build

# $Choices: @{ OutDir; Iso (the source file, for the name); Image (from Open-AkariIsoSource); Index; Edition;
# Apps (provisioned package names); Features; Capabilities; Packages (names); AkariDir (this AkariOS's folder, to copy
# into the image; none = left out); Unattend ([byte[]] autounattend.xml; none = left out); Settings (the Build
# settings, Get-AkariIsoSettings); Groups (removal group ids; none = no group), AppPatterns (Get-AkariIsoAppPatterns),
# Bake (Get-AkariIsoBake's InImage), FirstSignIn (with AkariDir: the RunOnce value) }.
# Returns @{ Ok; Path; Message; Report }; on a failure the image is discarded, never left mounted. Each step's
# operations go to the page (Add-AkariIsoOperation); either way a report goes next to the ISO and on the result.
function Invoke-AkariIsoBuild([hashtable]$Choices) {
    $groups = @()
    try { $groups = Get-AkariIsoGroupsPicked $Choices.Groups (Get-AkariIsoGroups) }
    catch { return @{ Ok = $false; Path = $null; Message = $_.Exception.Message } }
    $w = Get-AkariIsoWork $Choices.OutDir
    $out = Join-Path $Choices.OutDir (Get-AkariIsoOutName $Choices.Iso)
    # a group's list, joined
    $fromGroups = { param($k) @($groups | ForEach-Object { $_[$k] } | Where-Object { $_ }) }
    $steps = New-AkariIsoPlan $Choices $groups
    $set = Get-AkariIsoSettings $Choices
    $oscdimg = $null
    $started = Get-Date
    $stages = [System.Collections.Generic.List[object]]::new()
    $stageClock = [Diagnostics.Stopwatch]::new()
    $current = $null
    # what an operation's block hands back (its own variables don't outlive it)
    $hold = @{ Sha = '' }
    try {
        for ($i = 0; $i -lt $steps.Count; $i++) {
            $s = $steps[$i]
            $current = $s
            $script:AkariIsoStage = $i
            $script:AkariIsoStageOps = [System.Collections.Generic.List[object]]::new()
            $stageClock.Restart()
            Set-AkariProgress $i $steps.Count $s.Text
            Write-Log $s.Text
            switch ($s.Id) {
                'Adk' { $oscdimg = Install-AkariAdk }
                'Mount' { Mount-AkariIsoEdition $w $Choices.Image $Choices.Index }
                'Drivers' {
                    # X7: this PC's third-party drivers (dism /Export-Driver), then into the image in one DISM call
                    $dir = Join-Path $w.Root 'Drivers'
                    New-Item $dir -ItemType Directory -Force | Out-Null
                    $hold.Drivers = 0
                    Invoke-AkariIsoOp 'Export this PC''s drivers' {
                        $code = Invoke-AkariDism /Online /Export-Driver "/Destination:$dir"
                        if ($code -ne 0) { return @{ State = 'Failed'; Note = "DISM exit code $code" } }
                        $hold.Drivers = @([IO.Directory]::GetDirectories($dir)).Count
                        @{ State = 'Done'; Note = "$($hold.Drivers) drivers" }
                    }
                    Invoke-AkariIsoOp 'Add the drivers to the image' {
                        if (-not $hold.Drivers) { return @{ State = 'Skipped'; Note = 'No third-party drivers to add' } }
                        $code = Invoke-AkariDism "/Image:$($w.Mount)" /Add-Driver "/Driver:$dir" /Recurse
                        if ($code -eq 0) { return @{ State = 'Done'; Note = "$($hold.Drivers) drivers" } }
                        Write-Log "This PC's drivers were not added (DISM exit code $code)"
                        @{ State = 'Failed'; Note = "DISM exit code $code" }
                    }
                }
                'Apps' {
                    # the user's picks plus the image's apps the groups' patterns name
                    $pats = Get-AkariIsoList $Choices.AppPatterns
                    $matched = @(Get-AkariImageApps $w.Mount | Where-Object { $n = $_.Name; @($pats | Where-Object { $n -like $_ }).Count } | ForEach-Object { $_.Package })
                    Remove-AkariImageApps $w.Mount (Resolve-AkariIsoNames ((Get-AkariIsoList $Choices.Apps) + $matched) @() @())
                }
                'Features' {
                    $pats = @(& $fromGroups 'Features')
                    $have = if ($pats) { @(Get-AkariImageFeatures $w.Mount | ForEach-Object { $_.Name }) } else { @() }
                    $names = Resolve-AkariIsoNames (Get-AkariIsoList $Choices.Features) $pats $have
                    if ($set.Turbo) { Remove-AkariImageFeaturesAtOnce $w.Mount $names } else { Remove-AkariImageItems $w.Mount 'Feature' $names }
                }
                'Capabilities' {
                    # the groups' capabilities are patterns, matched on what the image has installed
                    $pats = @(& $fromGroups 'Capabilities')
                    $have = if ($pats) { @(Get-AkariImageCapabilities $w.Mount | ForEach-Object { $_.Name }) } else { @() }
                    Remove-AkariImageItems $w.Mount 'Capability' (Resolve-AkariIsoNames (Get-AkariIsoList $Choices.Capabilities) $pats $have)
                }
                'Packages' {
                    $names = [Collections.Generic.List[string]]::new()
                    foreach ($n in (Get-AkariIsoList $Choices.Packages) + @(& $fromGroups 'Packages')) { if (-not @($names | Where-Object { $_ -eq $n }).Count) { $names.Add($n) } }
                    Remove-AkariImageItems $w.Mount 'Package' $names.ToArray()
                }
                'Registry' {
                    $rows = @(& $fromGroups 'Registry')
                    $keys = @(& $fromGroups 'RemoveKeys')
                    Invoke-AkariIsoOp "Write $($rows.Count) settings" { Invoke-AkariIsoRegistry $w.Mount $rows $keys; @{ State = 'Done'; Note = '' } }
                }
                'Files' {
                    foreach ($path in @(& $fromGroups 'Remove')) {
                        Invoke-AkariIsoOp $path {
                            $gone = Remove-AkariImagePaths $w.Mount @($path)
                            if ($gone -gt 0) { @{ State = 'Done'; Note = "$gone removed" } } else { @{ State = 'Skipped'; Note = 'Not in this image' } }
                        }
                    }
                }
                'Bake' { Invoke-AkariIsoBake $w.Mount $Choices }
                'AkariOS' { Invoke-AkariIsoOp 'AkariOS and its shortcuts' { Copy-AkariToImage $w.Mount $Choices.AkariDir; @{ State = 'Done'; Note = '' } } }
                'Answer' { Invoke-AkariIsoOp 'autounattend.xml' { [IO.File]::WriteAllBytes((Join-Path $w.Media 'autounattend.xml'), [byte[]]$Choices.Unattend); @{ State = 'Done'; Note = '' } } }
                'NetFx3' {
                    Invoke-AkariIsoOp '.NET Framework 3.5' {
                        $sxs = Join-Path $w.Media 'sources\sxs'
                        if (-not (Test-Path -LiteralPath $sxs)) {
                            Write-Log 'No sources\sxs on the ISO: .NET Framework 3.5 left out'
                            return @{ State = 'Skipped'; Note = 'The ISO has no sources\sxs' }
                        }
                        $code = Invoke-AkariDism "/Image:$($w.Mount)" /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess "/Source:$sxs"
                        if ($code -eq 0) { return @{ State = 'Done'; Note = '' } }
                        Write-Log ".NET Framework 3.5 was not added (DISM exit code $code)"
                        @{ State = 'Failed'; Note = "DISM exit code $code" }
                    }
                }
                'Cleanup' {
                    Invoke-AkariIsoOp 'Component store cleanup' {
                        $code = Invoke-AkariDism "/Image:$($w.Mount)" /Cleanup-Image /StartComponentCleanup /ResetBase
                        if ($code -eq 0) { return @{ State = 'Done'; Note = '' } }
                        Write-Log "Component cleanup skipped (DISM exit code $($code), pending operations)"
                        @{ State = 'Skipped'; Note = "Pending operations (DISM exit code $code): the image may be larger" }
                    }
                }
                'Leftovers' { Remove-AkariIsoLeftovers $w.Mount }
                'Prune' { Remove-AkariIsoComponentStore $w.Mount }
                'Commit' { Save-AkariWim $w.Mount }
                'Compress' {
                    foreach ($old in @(Get-ChildItem -LiteralPath (Join-Path $w.Media 'sources') -Filter 'install*' -File -ErrorAction SilentlyContinue)) {
                        if ($old.Extension -in '.wim', '.esd', '.swm') { Remove-Item -LiteralPath $old.FullName -Force }
                    }
                    $file, $mode = switch ($set.Compression) { 'Recovery' { 'install.esd', 'recovery' } 'Fast' { 'install.wim', 'fast' } default { 'install.wim', 'max' } }
                    Export-AkariWim $w.Wim 1 (Join-Path $w.Media "sources\$file") $mode
                    Remove-Item -LiteralPath $w.Wim -Force -ErrorAction SilentlyContinue
                }
                'Boot' {
                    $boot = Join-Path $w.Media 'sources\boot.wim'
                    if (-not (Test-Path -LiteralPath $boot) -or @(Get-AkariWimImages $boot).Count -lt 2) { Write-Log 'No setup image in boot.wim: left as it is'; break }
                    Mount-AkariWim $boot 2 $w.Mount
                    Invoke-AkariIsoRegistry $w.Mount @(& $fromGroups 'Boot')
                    Save-AkariWim $w.Mount
                    Clear-AkariIsoMarker
                }
                'NoSxs' {
                    Invoke-AkariIsoOp 'sources\sxs' {
                        $sxs = Join-Path $w.Media 'sources\sxs'
                        if (-not (Test-Path -LiteralPath $sxs -PathType Container)) { return @{ State = 'Skipped'; Note = 'Not on this ISO' } }
                        Remove-Item -LiteralPath $sxs -Recurse -Force
                        @{ State = 'Done'; Note = '' }
                    }
                }
                'Iso' {
                    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
                    $c = Invoke-AkariExe $oscdimg (Get-AkariOscdimgArgs $w.Media $out)
                    if ($c -ne 0) { throw "oscdimg failed (exit code $c)" }
                    Invoke-AkariIsoOp 'SHA-256 of the ISO' {
                        $hold.Sha = Get-AkariFileSha256 $out
                        if ($hold.Sha) { @{ State = 'Done'; Note = $hold.Sha } } else { @{ State = 'Skipped'; Note = 'No ISO to check' } }
                    }
                }
                'Tidy' { Clear-AkariIsoMarker; Remove-Item -LiteralPath $w.Root -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $stages.Add((New-AkariIsoReportStage $s 'Done' $stageClock.Elapsed.TotalSeconds $script:AkariIsoStageOps))
        }
        Set-AkariProgress $steps.Count $steps.Count 'Done'
        Write-Log "ISO ready: $out"
        $size = if (Test-Path -LiteralPath $out -PathType Leaf) { (Get-Item -LiteralPath $out -Force).Length } else { 0 }
        $report = Save-AkariIsoReport (New-AkariIsoReport $Choices $out $started $true '' $stages $size $hold.Sha)
        @{ Ok = $true; Path = $out; Message = ''; Report = $report }
    }
    catch {
        $m = $_.Exception.Message
        if ($current) { $stages.Add((New-AkariIsoReportStage $current 'Failed' $stageClock.Elapsed.TotalSeconds $script:AkariIsoStageOps)) }
        for ($j = $stages.Count; $j -lt $steps.Count; $j++) { $stages.Add((New-AkariIsoReportStage $steps[$j] 'Not run' 0 @())) }
        $report = Save-AkariIsoReport (New-AkariIsoReport $Choices $out $started $false $m $stages)
        Write-Log "ISO build failed: $m"
        Write-ErrLog "ISO Builder: $m"
        Dismount-AkariOfflineHives
        if (Get-AkariIsoMarker) { Undo-AkariWim $w.Mount; Clear-AkariIsoMarker }
        @{ Ok = $false; Path = $null; Message = $m; Report = $report }
    }
    finally { $script:AkariIsoStageOps = $null; $script:AkariIsoStage = $null }
}
