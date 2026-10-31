# The ISO Builder (plan docs/plans/2026-10-31-iso-builder.md), after zoicware's zISO Tweaker (MIT): a custom
# Windows 11 ISO from a stock one. The ISO's files are copied to <out>\AkariIso\Media, the chosen edition exported to
# <out>\AkariIso\install.wim and mounted at <out>\AkariIso\Mount, its registry hives loaded at HKLM\AkariIso_<hive>
# and written, then the image saved, compressed back into Media, boot.wim patched and the ISO built with oscdimg.
# Native and system-changing calls only through the wrappers below (tests mock them). Nothing here touches this PC's
# own Windows.

if (-not $AkariIsoMarker) { $AkariIsoMarker = Join-Path $env:ProgramData 'Akari\iso-mount.json' }
$AkariIsoData = Join-Path $PSScriptRoot 'Iso\Data'
# the image's hives: name -> file under the mounted image
$AkariIsoHives = [ordered]@{
    SOFTWARE = 'Windows\System32\config\SOFTWARE'
    SYSTEM   = 'Windows\System32\config\SYSTEM'
    DEFAULT  = 'Windows\System32\config\DEFAULT'
    NTUSER   = 'Users\Default\NTUSER.DAT'
}
$AkariIsoMinFree = 25GB

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

# one image of $Source into a new $Dest (.swm: all its parts read)
function Export-AkariWim([string]$Source, [int]$Index, [string]$Dest, [string]$Compression) {
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

# dism.exe on an image: returns the exit code. Continue: see Invoke-AkariPowerCfg.
function Invoke-AkariDism {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\dism.exe" /English @Arguments 2>&1 | Out-Null
    $LASTEXITCODE
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
        $h.Path = "HKLM:\AkariIso_$hive\$rest"
        $h.Hive = $hive
        $h
    }
}

function Get-AkariIsoData([string]$Name) { Import-PowerShellDataFile (Join-Path $AkariIsoData "$Name.psd1") }

# the build's ordered steps: @{ Id; Text }
function New-AkariIsoPlan([hashtable]$Choices) {
    $s = [System.Collections.Generic.List[object]]::new()
    $add = { param($id, $text) $s.Add(@{ Id = $id; Text = $text }) }
    & $add 'Adk' 'Getting the ISO tool ready (Windows ADK)'
    & $add 'Mount' "Mounting $($Choices.Edition)"
    & $add 'Registry' 'Writing settings into the image''s registry'
    & $add 'Files' 'Removing files from the image'
    & $add 'NetFx3' 'Adding .NET Framework 3.5'
    & $add 'Cleanup' 'Cleaning up the component store'
    & $add 'Commit' 'Saving the image'
    & $add 'Compress' 'Compressing install.wim'
    & $add 'Boot' 'Skipping the Windows 11 requirements in setup (boot.wim)'
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
function Set-AkariIsoMarker([string]$Mount) {
    New-Item -Path (Split-Path $AkariIsoMarker) -ItemType Directory -Force | Out-Null
    @{ Mount = $Mount } | ConvertTo-Json | Set-Content -LiteralPath $AkariIsoMarker -Encoding UTF8
}
function Clear-AkariIsoMarker { Remove-Item -LiteralPath $AkariIsoMarker -Force -ErrorAction SilentlyContinue }

function Test-AkariIsoMounted($Work) {
    $m = Get-AkariIsoMarker
    [bool]($m -and $m.Mount -eq $Work.Mount)
}

# the chosen edition exported to <out>\AkariIso\install.wim and mounted (once: the page mounts it to read its apps)
function Mount-AkariIsoEdition($Work, [string]$Image, [int]$Index) {
    if (Test-AkariIsoMounted $Work) { return }
    Remove-Item -LiteralPath $Work.Wim -Force -ErrorAction SilentlyContinue
    Export-AkariWim $Image $Index $Work.Wim 'fast'
    New-Item -Path $Work.Mount -ItemType Directory -Force | Out-Null
    Set-AkariIsoMarker $Work.Mount
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
    foreach ($r in @(ConvertTo-AkariIsoRows $Rows)) {
        if ($r.Hive -notin $Loaded) { continue }
        if ($r.Trusted) { $trusted.Add($r); continue }
        try { Invoke-AkariRegistry @($r) 'Apply' }
        catch { if ($r.ContainsKey('Name')) { $trusted.Add($r) } else { Write-Log "Could not change $($r.Path): $($_.Exception.Message)" } }
    }
    if ($trusted.Count) { Invoke-AkariRegistryTrusted $trusted.ToArray() 'Apply' }
}

# loads the hives, writes the rows, unloads them
function Invoke-AkariIsoRegistry([string]$Mount, $Rows) {
    $loaded = Mount-AkariOfflineHives $Mount
    try { Write-AkariIsoRegistry $Rows $loaded }
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

# ---- the build

# $Choices: @{ OutDir; Iso (the source file, for the name); Image (from Open-AkariIsoSource); Index; Edition }.
# Returns @{ Ok; Path; Message }; on a failure the image is discarded, never left mounted.
function Invoke-AkariIsoBuild([hashtable]$Choices) {
    $w = Get-AkariIsoWork $Choices.OutDir
    $out = Join-Path $Choices.OutDir (Get-AkariIsoOutName $Choices.Iso)
    $always = Get-AkariIsoData 'Always'
    $steps = New-AkariIsoPlan $Choices
    $oscdimg = $null
    try {
        for ($i = 0; $i -lt $steps.Count; $i++) {
            $s = $steps[$i]
            Set-AkariProgress $i $steps.Count $s.Text
            Write-Log $s.Text
            switch ($s.Id) {
                'Adk' { $oscdimg = Install-AkariAdk }
                'Mount' { Mount-AkariIsoEdition $w $Choices.Image $Choices.Index }
                'Registry' { Invoke-AkariIsoRegistry $w.Mount (@($always.Requirements) + @($always.Registry)) }
                'Files' { [void](Remove-AkariImagePaths $w.Mount $always.Remove) }
                'NetFx3' {
                    $sxs = Join-Path $w.Media 'sources\sxs'
                    if (-not (Test-Path -LiteralPath $sxs)) { Write-Log 'No sources\sxs on the ISO: .NET Framework 3.5 left out'; break }
                    $c = Invoke-AkariDism "/Image:$($w.Mount)" /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess "/Source:$sxs"
                    if ($c -ne 0) { Write-Log ".NET Framework 3.5 was not added (DISM exit code $c)" }
                }
                'Cleanup' {
                    $c = Invoke-AkariDism "/Image:$($w.Mount)" /Cleanup-Image /StartComponentCleanup /ResetBase
                    if ($c -ne 0) { Write-Log "Component cleanup skipped (DISM exit code $($c), pending operations)" }
                }
                'Commit' { Save-AkariWim $w.Mount }
                'Compress' {
                    foreach ($old in @(Get-ChildItem -LiteralPath (Join-Path $w.Media 'sources') -Filter 'install*' -File -ErrorAction SilentlyContinue)) {
                        if ($old.Extension -in '.wim', '.esd', '.swm') { Remove-Item -LiteralPath $old.FullName -Force }
                    }
                    Export-AkariWim $w.Wim 1 (Join-Path $w.Media 'sources\install.wim') 'max'
                    Remove-Item -LiteralPath $w.Wim -Force -ErrorAction SilentlyContinue
                }
                'Boot' {
                    $boot = Join-Path $w.Media 'sources\boot.wim'
                    if (-not (Test-Path -LiteralPath $boot) -or @(Get-AkariWimImages $boot).Count -lt 2) { Write-Log 'No setup image in boot.wim: left as it is'; break }
                    Mount-AkariWim $boot 2 $w.Mount
                    Invoke-AkariIsoRegistry $w.Mount (@($always.Requirements) + @($always.Boot))
                    Save-AkariWim $w.Mount
                    Clear-AkariIsoMarker
                }
                'Iso' {
                    Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
                    $c = Invoke-AkariExe $oscdimg (Get-AkariOscdimgArgs $w.Media $out)
                    if ($c -ne 0) { throw "oscdimg failed (exit code $c)" }
                }
                'Tidy' { Clear-AkariIsoMarker; Remove-Item -LiteralPath $w.Root -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
        Set-AkariProgress $steps.Count $steps.Count 'Done'
        Write-Log "ISO ready: $out"
        @{ Ok = $true; Path = $out; Message = '' }
    }
    catch {
        $m = $_.Exception.Message
        Write-Log "ISO build failed: $m"
        Write-ErrLog "ISO Builder: $m"
        Dismount-AkariOfflineHives
        if (Get-AkariIsoMarker) { Undo-AkariWim $w.Mount; Clear-AkariIsoMarker }
        @{ Ok = $false; Path = $null; Message = $m }
    }
}
