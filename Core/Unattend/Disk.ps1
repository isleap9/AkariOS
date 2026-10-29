# Install USB: the Windows PE stage, ported from Schneegans' modifier\Disk.cs (MIT; see Engine.ps1). With PEMode
# Generated or Script, setup's own PE stage is replaced by X:\pe.cmd (written line by line by echo commands): it finds
# the image, partitions the disk (diskpart), applies Windows (dism), makes it bootable and copies the answer file.

$AkariUaLetters = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

# the target disk script (VBScript) for the Generated criteria
function Get-AkariUaTargetDiskScript($C) {
    $w = [Collections.Generic.List[string]]::new()
    $add = { param([string]$t) foreach ($l in ($t -split "`r?`n")) { $w.Add($l) } }
    & $add @'
Function Fail(message)
  WScript.Echo message
  WScript.Quit 1
End Function

On Error Resume Next
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set drives = wmi.InstancesOf("Win32_DiskDrive")
If Err.Number <> 0 Then
  Fail "Could not enumerate disks: " & Err.Description
End If
Set accepted = CreateObject("Scripting.Dictionary")

For Each drive In drives
  accept = True

'@
    $check = { param([string]$body) & $add ($body + "`n") }
    if (Test-AkariUaOn $C 'TargetDiskInterfaceType') { & $check "  actual = drive.InterfaceType`n  If actual <> `"IDE`" And actual <> `"SCSI`" Then`n    accept = False`n  End If`n" }
    if (Test-AkariUaOn $C 'TargetDiskMediaType') { & $check "  actual = drive.MediaType`n  If actual <> `"Fixed hard disk media`" Then`n    accept = False`n  End If`n" }
    if (Test-AkariUaOn $C 'TargetDiskSize') {
        $min = Get-AkariUaField $C 'TargetDiskMinSize'; $max = Get-AkariUaField $C 'TargetDiskMaxSize'
        if ($min -and $max -and [int]$min -gt [int]$max) { throw "Value of 'minSizeGiB' ($min) must be less than or equal to value of 'maxSizeGiB' ($max)." }
        if ($min) { & $check "  actual = CInt(drive.Size / 1024 / 1024 / 1024)`n  expected = $min`n  If actual < expected Then`n    accept = False`n  End If`n" }
        if ($max) { & $check "  actual = CInt(drive.Size / 1024 / 1024 / 1024)`n  expected = $max`n  If actual > expected Then`n    accept = False`n  End If`n" }
    }
    if (Test-AkariUaOn $C 'TargetDiskIndex') { & $check "  actual = drive.Index`n  expected = $(Get-AkariUaField $C 'TargetDisk' '0')`n  If actual <> expected Then`n    accept = False`n  End If`n" }
    if (Test-AkariUaOn $C 'TargetDiskNoPartitions') { & $check "  actual = drive.Partitions`n  If actual > 0 Then`n    accept = False`n  End If`n" }
    & $add @'
  If accept Then
    accepted.Add drive.Index, ""
  End If
Next

If accepted.Count = 0 Then
  Fail "No disk satisfied the given criteria."
ElseIf accepted.Count > 1 Then
  Fail "Several disks (" & Join(accepted.Keys, ", ") & ") satisfied the given criteria."
Else
  WScript.Echo Join(accepted.Keys)
  WScript.Quit 0
End If
'@
    $w
}

# the diskpart script for a layout: GPT or MBR, Windows RE on its own partition or not
function Get-AkariUaDiskpartScript([string]$Disk, [string]$Layout, [bool]$Recovery, [int]$SystemSize, [int]$RecoverySize) {
    $r = { param($l) if ($Recovery) { $l } else { '' } }
    if ($Layout -eq 'MBR') {
        "SELECT DISK=$Disk", 'CLEAN', "CREATE PARTITION PRIMARY SIZE=$SystemSize", 'FORMAT QUICK FS=NTFS LABEL="System"', 'ASSIGN LETTER=S', 'ACTIVE',
        'CREATE PARTITION PRIMARY', (& $r "SHRINK MINIMUM=$RecoverySize"), 'FORMAT QUICK FS=NTFS LABEL="Windows"', 'ASSIGN LETTER=W',
        (& $r 'CREATE PARTITION PRIMARY'), (& $r 'FORMAT QUICK FS=NTFS LABEL="Recovery"'), (& $r 'ASSIGN LETTER=R'), (& $r 'SET ID=27')
    } else {
        "SELECT DISK=$Disk", 'CLEAN', 'CONVERT GPT', "CREATE PARTITION EFI SIZE=$SystemSize", 'FORMAT QUICK FS=FAT32 LABEL="System"', 'ASSIGN LETTER=S',
        'CREATE PARTITION MSR SIZE=16', 'CREATE PARTITION PRIMARY', (& $r "SHRINK MINIMUM=$RecoverySize"), 'FORMAT QUICK FS=NTFS LABEL="Windows"', 'ASSIGN LETTER=W',
        (& $r 'CREATE PARTITION PRIMARY'), (& $r 'FORMAT QUICK FS=NTFS LABEL="Recovery"'), (& $r 'ASSIGN LETTER=R'),
        (& $r 'SET ID="de94bba4-06d1-4d40-a16a-bfd50179d6ac"'), (& $r 'GPT ATTRIBUTES=0x8000000000000001')
    }
}

# X:\pe.cmd for PEMode Generated (GetPEScript), as lines
function Get-AkariUaPEScript($C) {
    $w = [Collections.Generic.List[string]]::new()
    $add = { param([string]$t) foreach ($l in ($t -split "`r?`n")) { $w.Add($l) } }
    $include = {
        param([string]$path, [string[]]$lines, [bool]$escape)
        $echo = @(ConvertTo-AkariUaEcho $lines $escape)
        if (-not $echo.Count) { return }
        $w.Add(">$path (")
        foreach ($l in $echo) { $w.Add("    $l") }
        $w.Add(')'); $w.Add('')
    }
    $vio = Test-AkariUaOn $C 'VirtIoGuestTools'
    $lang = Get-AkariUaLanguage $C
    & $add "@echo off`n"
    if ($lang) { & $add "call :print `"Setting keyboard layout for PE session`"`nwpeutil.exe SetKeyboardLayout $($lang.Pairs[0].Locale.LCID):$($lang.Pairs[0].Keyboard.Id)`n" }
    $search = ($AkariUaLetters | Where-Object { $_ -notin 'A', 'B', 'S', 'W', 'R' }) -join ' '
    & $add (@'
for %%d in ({0}) do (
    if exist %%d:\sources\install.wim set "IMAGE_FILE=%%d:\sources\install.wim"
    if exist %%d:\sources\install.esd set "IMAGE_FILE=%%d:\sources\install.esd"
    if exist %%d:\sources\install.swm set "IMAGE_FILE=%%d:\sources\install.swm" & set "SWM_PARAM=/SWMFile:%%d:\sources\install*.swm"
    if exist %%d:\autounattend.xml set "XML_FILE=%%d:\autounattend.xml"
    if exist %%d:\$OEM$ set "OEM_FOLDER=%%d:\$OEM$"
    if exist %%d:\$WinPEDriver$ set "PEDRIVERS_FOLDER=%%d:\$WinPEDriver$"
'@ -replace '\{0\}', $search)
    # (not indented: so it is in his code)
    if ($vio) { & $add 'if exist %%d:\virtio-win-guest-tools.exe set "VIRTIO_DRIVE=%%d:"' }
    & $add @'
)
for /f "tokens=3" %%t in ('reg.exe query HKLM\System\Setup /v UnattendFile 2^>nul') do ( if exist %%t set "XML_FILE=%%t" )
if not defined IMAGE_FILE call :fail "Could not locate install.wim, install.esd or install.swm."
if not defined XML_FILE call :fail "Could not locate autounattend.xml."

set "OS_VERSION=11"
for /f "tokens=3 delims=." %%v in ('ver') do (
    if %%v LSS 20000 set "OS_VERSION=10"
)

if defined PEDRIVERS_FOLDER (
    call :print "Loading drivers from %PEDRIVERS_FOLDER%"
    for /R %PEDRIVERS_FOLDER% %%f IN (*.inf) do drvload.exe "%%f"
)

'@
    if ($vio) {
        & $add @'
if defined VIRTIO_DRIVE (
    call :print "Loading VirtIO drivers from %VIRTIO_DRIVE%"
    drvload.exe "%VIRTIO_DRIVE%\vioscsi\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\vioscsi.inf"
    drvload.exe "%VIRTIO_DRIVE%\viostor\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\viostor.inf"
    drvload.exe "%VIRTIO_DRIVE%\NetKVM\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\netkvm.inf"
)

'@
    }
    $partition = Get-AkariUaField $C 'PartitionMode' 'Unattended'
    if ($partition -eq 'Unattended') {
        $runTarget = {
            param([string[]]$lines)
            & $include 'X:\target.vbs' $lines $true
            & $add @'
call :print "Determining target disk"
(cscript.exe //E:vbscript "X:\target.vbs" //Nologo >X:\target.out) || (type X:\target.out & call :fail "Could not determine target disk. Windows Setup will halt to avoid potential data loss.")
for /f %%t in (X:\target.out) do set "TARGET_DISK=%%t"

'@
        }
        switch (Get-AkariUaField $C 'TargetDiskMode' 'Generated') {
            'Interactive' {
                & $add @'
echo list disk | diskpart.exe
echo:
:choice
set /p "CHOICE=Enter index of the disk you want to install Windows to: " || goto :choice
set "TARGET_DISK=%CHOICE%"

'@
            }
            'Script' { & $runTarget (Split-AkariUaLines (Get-AkariUaField $C 'TargetDiskScript')) }
            default { & $runTarget (Get-AkariUaTargetDiskScript $C) }
        }
    }
    $checkLetters = {
        param([string[]]$lines)
        foreach ($p in @(@('W', 'Windows'), @('S', 'system'))) {
            $rx = "^\s*ASSIGN\s+LETTER((\s+)|(\s*=\s*))(($($p[0]))|(`"$($p[0])`"))\s*$"
            if (-not @($lines | Where-Object { $_ -match $rx }).Count) {
                throw "Your diskpart script must contain a line such as 'ASSIGN LETTER=$($p[0])' to assign the drive letter '$($p[0]):' to the $($p[1]) partition."
            }
        }
    }
    $execute = {
        param([string]$path, [string]$message)
        $w.Add("call :print `"$message`"")
        if (Test-AkariUaOn $C 'PauseBeforeFormatting') { $w.Add('pause') }
        & $add "diskpart.exe /s $path || call :fail `"diskpart.exe encountered an error.`"`n"
    }
    & $add @'
wpeutil.exe UpdateBootInfo
for /f "tokens=3" %%t in ('reg.exe query HKLM\System\CurrentControlSet\Control /v PEFirmwareType') do (
    if %%t == 0x1 (
        set "LAYOUT=MBR"
        set "FIRMWARE=BIOS"
    ) else if %%t == 0x2 (
        set "LAYOUT=GPT"
        set "FIRMWARE=UEFI"
    ) else (
        call :fail "Unexpected PEFirmwareType value %%t."
    )
)
call :print "The computer is booted in %FIRMWARE% mode, hence the target disk must be configured with the %LAYOUT% partition layout"
'@
    $recovery = (Get-AkariUaField $C 'RecoveryMode' 'Partition') -eq 'Partition'
    switch ($partition) {
        'Custom' {
            $lines = Split-AkariUaLines (Get-AkariUaField $C 'DiskpartScript')
            & $checkLetters $lines
            & $include 'X:\diskpart.txt' $lines $true
            & $execute 'X:\diskpart.txt' 'diskpart will now execute your script'
        }
        'Unattended' {
            $disk = '%TARGET_DISK%'
            $sys = [int](Get-AkariUaField $C 'SystemSize' '300'); $rec = [int](Get-AkariUaField $C 'RecoverySize' '1000')
            $message = 'diskpart will now wipe, partition and format disk %TARGET_DISK%'
            $layout = Get-AkariUaField $C 'PartitionLayout' 'GPT'
            if ($layout -eq 'Automatic') {
                foreach ($l in 'GPT', 'MBR') {
                    $lines = @(Get-AkariUaDiskpartScript $disk $l $recovery $sys $rec)
                    & $checkLetters $lines
                    & $include "X:\$l.txt" $lines $false
                }
                & $execute 'X:\%LAYOUT%.txt' $message
            } else {
                $lines = @(Get-AkariUaDiskpartScript $disk $layout $recovery $sys $rec)
                & $checkLetters $lines
                & $include 'X:\diskpart.txt' $lines $false
                & $execute 'X:\diskpart.txt' $message
            }
        }
        default {
            & $add @'
call :print ^"Press Shift+F10 to open a new console window, then use diskpart to partition and format the disk manually. Make sure to assign the drive letters W and S ^
to the Windows and system partitions, respectively. When finished, continue with Windows Setup in this window.^"
pause
'@
        }
    }
    switch (Get-AkariUaField $C 'InstallFromMode' 'Edition') {
        'Index' { $w.Add("set `"IMG_PARAM=/Index:$(Get-AkariUaField $C 'InstallFromIndex' '1')`"") }
        'Name' { $w.Add("set `"IMG_PARAM=/Name:`"$(Get-AkariUaField $C 'InstallFromName')`"`"") }
        'Interactive' {
            & $add @'
dism.exe /Get-WimInfo /WimFile:"%IMAGE_FILE%"
echo:
:choice
set /p "CHOICE=Enter index of the image you want to install: " || goto :choice
set "IMG_PARAM=/Index:%CHOICE%"
'@
        }
        default { $w.Add("set `"IMG_PARAM=/Name:`"Windows %OS_VERSION% $((Get-AkariUaItem 'WindowsEdition' (Get-AkariUaField $C 'InstallFromEdition')).DisplayName)`"`"") }
    }
    $compact = if (Test-AkariUaOn $C 'CompactOs') { ' /Compact' } else { '' }
    $verify = if (Test-AkariUaOn $C 'SkipIntegrityCheck') { '' } else { ' /CheckIntegrity /Verify' }
    & $add (@'
call :print "Applying Windows image to target disk"
dism.exe /Apply-Image /ImageFile:%IMAGE_FILE% %SWM_PARAM% %IMG_PARAM% /ApplyDir:W:\{0} || call :fail "dism.exe encountered an error."

call :print "Making system partition bootable"
bcdboot.exe W:\Windows /s S: || call :fail "bcdboot.exe encountered an error."
if %LAYOUT% == GPT (
    bcdedit.exe /set {fwbootmgr} bootsequence {bootmgr} || call :fail "bcdedit.exe encountered an error."
)

'@.Replace('{0}', "$compact$verify"))
    $deleteRE = { & $add "call :print `"Deleting winre.wim file to avoid creation of recovery partition`"`ndel W:\Windows\System32\Recovery\winre.wim`n" }
    if ($partition -eq 'Unattended' -and -not $recovery) { & $deleteRE }
    if ($partition -eq 'Custom') {
        $s = Get-AkariUaField $C 'DiskpartScript'
        if (-not @('SET ID=27', 'LABEL="Recovery"', 'SET ID="de94bba4-06d1-4d40-a16a-bfd50179d6ac"' | Where-Object { $s.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count) { & $deleteRE }
    }
    & $add @'
call :print "Copying answer file to target disk"
mkdir W:\Windows\Panther
copy %XML_FILE% W:\Windows\Panther\unattend.xml

if defined PEDRIVERS_FOLDER (
    call :print "Adding drivers from %PEDRIVERS_FOLDER% to new installation"
    dism.exe /Add-Driver /Image:W:\ /Driver:"%PEDRIVERS_FOLDER%" /Recurse
)

'@
    if ($vio) {
        & $add @'
if defined VIRTIO_DRIVE (
    call :print "Adding VirtIO drivers from %VIRTIO_DRIVE% to new installation"
    dism.exe /Add-Driver /Image:W:\ /Driver:"%VIRTIO_DRIVE%\vioscsi\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\vioscsi.inf"
    dism.exe /Add-Driver /Image:W:\ /Driver:"%VIRTIO_DRIVE%\viostor\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\viostor.inf"
    dism.exe /Add-Driver /Image:W:\ /Driver:"%VIRTIO_DRIVE%\NetKVM\w%OS_VERSION%\%PROCESSOR_ARCHITECTURE%\netkvm.inf"
)

'@
    }
    if ((Get-AkariUaField $C 'TimeZoneMode') -eq 'Explicit') {
        & $add "call :print `"Setting time zone`"`ndism.exe /Image:W:\ /Set-TimeZone:`"$((Get-AkariUaItem 'TimeOffset' (Get-AkariUaField $C 'TimeZone')).Id)`"`n"
    }
    if (Test-AkariUaOn $C 'Disable8Dot3Names') {
        & $add @'
call :print "Disabling 8.3 file names"
fsutil.exe 8dot3name set W: 1
fsutil.exe 8dot3name strip /s /f W:\
reg.exe LOAD HKLM\mount W:\Windows\System32\config\SYSTEM
reg.exe ADD HKLM\mount\ControlSet001\Control\FileSystem /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f
reg.exe UNLOAD HKLM\mount

'@
    }
    if (Test-AkariUaOn $C 'DisableDefender') {
        & $add @'
call :print "Disabling Windows Defender"
reg.exe LOAD HKLM\mount W:\Windows\System32\config\SYSTEM
for %%s in (Sense WdBoot WdFilter WdNisDrv WdNisSvc WinDefend) do reg.exe ADD HKLM\mount\ControlSet001\Services\%%s /v Start /t REG_DWORD /d 4 /f
reg.exe UNLOAD HKLM\mount

'@
    }
    if (Test-AkariUaOn $C 'DisableWpbt') {
        & $add @'
call :print "Disabling WPBT"
reg.exe LOAD HKLM\mount W:\Windows\System32\config\SYSTEM
reg.exe add "HKLM\mount\ControlSet001\Control\Session Manager" /v DisableWpbtExecution /t REG_DWORD /d 1 /f
reg.exe UNLOAD HKLM\mount

'@
    }
    $paging = { param($data) & $add "call :print `"Configuring paging file`"`nreg.exe LOAD HKLM\mount W:\Windows\System32\config\SYSTEM`nreg.exe add `"HKLM\mount\ControlSet001\Control\Session Manager\Memory Management`" /v PagingFiles /t REG_MULTI_SZ /f $data`nreg.exe UNLOAD HKLM\mount`n" }
    switch (Get-AkariUaField $C 'PagingFileMode' 'Automatic') {
        'None' { & $paging '' }
        'Custom' { & $paging "/d `"C:\pagefile.sys $(Get-AkariUaField $C 'InitPagingFileSize') $(Get-AkariUaField $C 'MaxPagingFileSize')`"" }
    }
    if ($lang) {
        & $add "call :print `"Setting device setup region to $($lang.Geo.DisplayName) (GeoID $($lang.Geo.Id))`"`nreg.exe LOAD HKLM\mount W:\Windows\System32\config\SOFTWARE`nreg.exe ADD `"HKLM\mount\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion`" /v DeviceRegion /t REG_DWORD /d $($lang.Geo.Id) /f`nreg.exe UNLOAD HKLM\mount`n"
    }
    & $add (@'
set "ROBOCOPY_ARGS=/E /XX /COPY:DAT /DCOPY:DAT /R:0"
if defined OEM_FOLDER (
    call :print "Copying contents of %OEM_FOLDER%"
    if exist "%OEM_FOLDER%\$$" robocopy.exe "%OEM_FOLDER%\$$" W:\Windows %ROBOCOPY_ARGS%
    if exist "%OEM_FOLDER%\$1" robocopy.exe "%OEM_FOLDER%\$1" W:\ %ROBOCOPY_ARGS%
    for %%d in ({0}) do (
        if exist "%OEM_FOLDER%\%%d" robocopy.exe "%OEM_FOLDER%\%%d" %%d:\ %ROBOCOPY_ARGS%
    )
)

'@.Replace('{0}', (($AkariUaLetters | Where-Object { $_ -notin 'A', 'B' }) -join ' ')))
    $w.Add('call :print "Computer will now reboot"')
    if (Test-AkariUaOn $C 'PauseBeforeReboot') { $w.Add('pause') }
    & $add @'
wpeutil.exe reboot
goto :eof

:fail
echo:
echo:Fatal error: %~1
echo:
pause
exit 1

:print
echo:
echo:*** %~1 ***
echo:
goto :eof
'@
    $w
}

function Invoke-AkariUaDisk($C) {
    if ($C.PEMode -in 'Generated', 'Script') {
        foreach ($n in @($C.Doc.SelectNodes("/u:unattend/u:settings[@pass='windowsPE']/*", $C.Ns))) { Remove-AkariUaNode $n }
        if (Test-AkariUaOn $C 'UseNarrator') { Add-AkariUaCommand $C 'WindowsPE' (Get-AkariUaShell 'start X:\Windows\System32\Narrator.exe') }
    }
    $lines = switch ($C.PEMode) {
        'Script' { Split-AkariUaLines (Get-AkariUaField $C 'PEScript') }
        'Generated' { Get-AkariUaPEScript $C }
        default { @() }
    }
    $lines = @($lines)
    $copy = Select-AkariUaNode $C.Doc '//s:PEScriptCopy' $C.Ns
    if ($lines.Count) {
        Add-AkariUaCommand $C 'WindowsPE' @(@(Get-AkariUaWriteToFile 'X:\pe.cmd' $lines) + (Get-AkariUaShell 'X:\pe.cmd'))
        Add-AkariUaText $copy ($lines -join "`r`n")
    } else { Remove-AkariUaNode $copy }
}
