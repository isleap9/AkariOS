# Install USB (plan docs/plans/2026-10-29-usb-setup-file.md): the autounattend.xml for a Windows install USB, after
# Christoph Schneegans' unattend generator (MIT, ideas only) and AkariOS-Ultimate (FR33THY Ultimate) "2 Refresh\4
# Autounattend.ps1". Only what an answer file alone can do; Windows settings come from an AkariOS Preset at the first
# sign-in (the USB's \AkariOS\firstlogon.ps1). One builder per section adds to the parts New-AkariUnattend assembles.

$AkariUnattendReserved = 'Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount', 'defaultuser0', 'System', 'None', 'User', 'Users', 'Administrators'
# the Windows 11 checks setup skips (HKLM\SYSTEM\Setup\LabConfig, read by setup before it checks)
$AkariUnattendChecks = 'TPM', 'RAM', 'SecureBoot', 'CPU', 'Storage'
# Microsoft's generic install keys: they pick the edition and never activate Windows
$AkariGenericKeys = [ordered]@{
    Home = 'YTMG3-N6DKC-DKB77-7M9GH-8HVX7'; Pro = 'VK7JG-NPHTM-C97JM-9MPGT-3V66T'; 'Pro for Workstations' = 'DXG7C-N36C4-C4HTG-X4T3X-2YV77'
    Education = 'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY'; Enterprise = 'XGVPP-NMH47-7TTHJ-W3FW7-8HV2C'
}
# the key that means "no key here": setup shows its key page (Always), or reads the firmware's key (OnError)
$AkariNoKey = '00000-00000-00000-00000-00000'

# every option at its default. Accounts: @(@{ Name; DisplayName; Password; Group = Administrators|Users }).
# Disk: $null (the user picks it in setup) or @{ Index; Layout = GPT|MBR; Recovery = keep Windows RE }.
function New-AkariUnattendOptions {
    @{
        AskRegion = $false; Language = 'en-US'; Inputs = @('0409:00000409'); Region = 'en-US'; GeoId = 244; TimeZone = 'UTC'
        Edition = 'Ask'; EditionName = 'Pro'; ProductKey = ''
        SkipChecks = $true; NoInternet = $true; HidePowerShell = $true; Express = 'Off'; Compact = $false; Disk = $null
        Accounts = @(); Computer = ''; PasswordExpiry = 'Never'; Lockout = 'Default'
        Wifi = 'Skip'; WifiName = ''; WifiHidden = $false; WifiAuth = 'WPA2'; WifiPassword = ''
        Preset = ''
    }
}

# $null when $Name is fine as an account name ($Kind 'Account') or a PC name ('Computer': empty = Windows picks one),
# else the problem, as one line for the page
function Test-AkariUnattendName([string]$Name, [string]$Kind) {
    if ($Kind -eq 'Computer') {
        if (-not $Name) { return $null }
        if ($Name.Length -gt 15) { return 'At most 15 characters.' }
        if ($Name -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$') { return 'Letters, digits and hyphens only, no hyphen at either end.' }
        if ($Name -match '^[0-9]+$') { return 'Use at least one letter.' }
        return $null
    }
    if (-not $Name) { return 'Enter an account name.' }
    if ($Name.Length -gt 20) { return 'At most 20 characters.' }
    if ($Name -match '\s') { return 'No spaces in the account name.' }
    if ($Name -match '["/\\\[\]:;|=,+*?<>@]') { return 'These characters can''t be used: " / \ [ ] : ; | = , + * ? < > @' }
    if ($Name -notmatch '[A-Za-z0-9]') { return 'Use at least one letter or digit.' }
    if ($AkariUnattendReserved -contains $Name) { return "'$Name' is a name Windows uses itself." }
    $null
}

function ConvertTo-AkariXmlText($s) { [Security.SecurityElement]::Escape([string]$s) }

# a password in Windows' encoded form (PlainText=false): base64 of the UTF-16 text followed by the word Password
function ConvertTo-AkariUnattendPassword([string]$Password) {
    if (-not $Password) { return '<Value></Value><PlainText>true</PlainText>' }
    "<Value>$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("$($Password)Password")))</Value><PlainText>false</PlainText>"
}

# ---- the sections: each adds XML text to $P (PE = Microsoft-Windows-Setup elements, PECmd = commands before setup,
# PEIntl, Spec = specialize Shell-Setup elements, SpecCmd = specialize commands, Intl, Oobe = oobeSystem Shell-Setup
# elements, OobeFlags = elements inside <OOBE>, Logon = first sign-in commands)

function Add-AkariUnattendRegion($P, $O) {
    $P.Spec.Add("<TimeZone>$(ConvertTo-AkariXmlText $O.TimeZone)</TimeZone>")
    if ($O.AskRegion) { return }
    $l = ConvertTo-AkariXmlText $O.Language; $r = ConvertTo-AkariXmlText $O.Region
    $common = "<InputLocale>$(ConvertTo-AkariXmlText (@($O.Inputs) -join ';'))</InputLocale><SystemLocale>$r</SystemLocale><UILanguage>$l</UILanguage><UserLocale>$r</UserLocale>"
    $P.PEIntl = "<SetupUILanguage><UILanguage>$l</UILanguage></SetupUILanguage>$common"
    $P.Intl = $common
    $g = [int]$O.GeoId
    $P.SpecCmd.Add("reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion`" /v DeviceRegion /t REG_DWORD /d $g /f")
    $P.SpecCmd.Add('reg load HKU\DefaultUser C:\Users\Default\NTUSER.DAT')
    $P.SpecCmd.Add("reg add `"HKU\DefaultUser\Control Panel\International\Geo`" /v Nation /t REG_SZ /d $g /f")
    $P.SpecCmd.Add('reg unload HKU\DefaultUser')
}

function Add-AkariUnattendSetup($P, $O) {
    $key, $ui = switch ($O.Edition) {
        'Generic' { $AkariGenericKeys[[string]$O.EditionName], 'OnError' }
        'Key' { $O.ProductKey, 'OnError' }
        'Firmware' { $AkariNoKey, 'OnError' }
        default { $AkariNoKey, 'Always' }
    }
    $P.PE.Add("<UserData><AcceptEula>true</AcceptEula><ProductKey><Key>$(ConvertTo-AkariXmlText $key)</Key><WillShowUI>$ui</WillShowUI></ProductKey></UserData>")
    $P.PE.Add('<Diagnostics><OptIn>false</OptIn></Diagnostics><DynamicUpdate><Enable>false</Enable><WillShowUI>OnError</WillShowUI></DynamicUpdate>')
    if ($O.SkipChecks) { foreach ($c in $AkariUnattendChecks) { $P.PECmd.Add("reg add HKLM\SYSTEM\Setup\LabConfig /v Bypass$($c)Check /t REG_DWORD /d 1 /f") } }
    if ($O.NoInternet) { $P.SpecCmd.Add('reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f') }
    switch ($O.Express) { 'Off' { $P.OobeFlags.Add('<ProtectYourPC>3</ProtectYourPC>') } 'On' { $P.OobeFlags.Add('<ProtectYourPC>1</ProtectYourPC>') } }
    $image = ''
    if ($O.Compact) { $image += '<Compact>true</Compact>' }
    if ($O.Disk) {
        $d = $O.Disk
        $id = [int]$d.Index
        # partitions in order: @(Type, Size or 'Extend', Format, Label, extra ModifyPartition elements)
        $parts = if ($d.Layout -eq 'MBR') {
            , @('Primary', 500, 'NTFS', 'System', '<Active>true</Active>')
            , @('Primary', 'Extend', 'NTFS', 'Windows', '<Letter>C</Letter>')
        } else {
            if ($d.Recovery) { , @('Primary', 1000, 'NTFS', 'Recovery', '<TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>') }
            , @('EFI', 300, 'FAT32', 'System', '')
            , @('MSR', 16, '', '', '')
            , @('Primary', 'Extend', 'NTFS', 'Windows', '<Letter>C</Letter>')
        }
        $create = ''; $modify = ''; $i = 0
        # (never $p here: PowerShell names ignore case, it would be the parts table $P)
        foreach ($part in $parts) {
            $i++
            $size = if ($part[1] -eq 'Extend') { '<Extend>true</Extend>' } else { "<Size>$($part[1])</Size>" }
            $create += "<CreatePartition wcm:action=`"add`"><Order>$i</Order><Type>$($part[0])</Type>$size</CreatePartition>"
            if ($part[2]) { $modify += "<ModifyPartition wcm:action=`"add`"><Order>$i</Order><PartitionID>$i</PartitionID><Format>$($part[2])</Format><Label>$($part[3])</Label>$($part[4])</ModifyPartition>" }
        }
        $P.PE.Add("<DiskConfiguration><Disk wcm:action=`"add`"><DiskID>$id</DiskID><WillWipeDisk>true</WillWipeDisk><CreatePartitions>$create</CreatePartitions><ModifyPartitions>$modify</ModifyPartitions></Disk></DiskConfiguration>")
        $image += "<InstallTo><DiskID>$id</DiskID><PartitionID>$i</PartitionID></InstallTo>"
        if (-not $d.Recovery) {
            $P.SpecCmd.Add('reagentc.exe /disable')
            $P.SpecCmd.Add('cmd.exe /c del /a /f "%SystemRoot%\System32\Recovery\Winre.wim"')
        }
    }
    if ($image) { $P.PE.Add("<ImageInstall><OSImage>$image</OSImage></ImageInstall>") }
}

function Add-AkariUnattendAccounts($P, $O) {
    $P.Spec.Add("<ComputerName>$(if ($O.Computer) { ConvertTo-AkariXmlText $O.Computer } else { '*' })</ComputerName>")
    $rows = foreach ($a in @($O.Accounts)) {
        $dn = if ($a.DisplayName) { $a.DisplayName } else { $a.Name }
        "<LocalAccount wcm:action=`"add`"><Name>$(ConvertTo-AkariXmlText $a.Name)</Name><DisplayName>$(ConvertTo-AkariXmlText $dn)</DisplayName><Group>$(ConvertTo-AkariXmlText $a.Group)</Group><Password>$(ConvertTo-AkariUnattendPassword $a.Password)</Password></LocalAccount>"
    }
    $P.Oobe.Add("<UserAccounts><LocalAccounts>$($rows -join '')</LocalAccounts></UserAccounts>")
    # the first administrator signs in once by itself (the first sign-in runs the Preset), then never again
    $admin = @($O.Accounts | Where-Object { $_.Group -eq 'Administrators' })[0]
    if ($admin) {
        $P.Oobe.Add("<AutoLogon><Username>$(ConvertTo-AkariXmlText $admin.Name)</Username><Enabled>true</Enabled><LogonCount>1</LogonCount><Password>$(ConvertTo-AkariUnattendPassword $admin.Password)</Password></AutoLogon>")
        $P.Logon.Add('reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /t REG_DWORD /d 0 /f')
    }
    if ($O.PasswordExpiry -eq 'Never') { $P.SpecCmd.Add('net accounts /maxpwage:unlimited') }
    if ($O.Lockout -eq 'Off') { $P.SpecCmd.Add('net accounts /lockoutthreshold:0') }
}

# Wi-Fi and the Preset are the USB's \AkariOS\firstlogon.ps1 (a Wi-Fi profile does not fit a command line); found on
# whichever drive letter the USB has
function Add-AkariUnattendFirstLogon($P, $O) {
    $P.OobeFlags.Add("<HideWirelessSetupInOOBE>$(([string]($O.Wifi -ne 'Ask')).ToLower())</HideWirelessSetupInOOBE>")
    if ($O.Wifi -ne 'Join' -and -not $O.Preset) { return }
    $style = if ($O.HidePowerShell) { ' -WindowStyle Hidden' } else { '' }
    $P.Logon.Add("cmd.exe /c for %d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do @if exist %d:\AkariOS\firstlogon.ps1 powershell.exe$style -NoProfile -ExecutionPolicy Bypass -File %d:\AkariOS\firstlogon.ps1")
}

# ---- the file

# the XML text for $Options (New-AkariUnattendOptions' keys). The choices, without passwords, go in a comment so
# ConvertFrom-AkariUnattend can read them back.
function New-AkariUnattend([hashtable]$Options) {
    $P = @{ PE = [Collections.Generic.List[string]]::new(); PECmd = [Collections.Generic.List[string]]::new(); PEIntl = ''
        Spec = [Collections.Generic.List[string]]::new(); SpecCmd = [Collections.Generic.List[string]]::new(); Intl = ''
        Oobe = [Collections.Generic.List[string]]::new(); OobeFlags = [Collections.Generic.List[string]]::new(); Logon = [Collections.Generic.List[string]]::new() }
    Add-AkariUnattendRegion $P $Options
    Add-AkariUnattendSetup $P $Options
    Add-AkariUnattendAccounts $P $Options
    Add-AkariUnattendFirstLogon $P $Options
    $comp = 'processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"'
    $c = { param($name, $body) if ($body) { "    <component name=`"$name`" $comp>$body</component>`n" } else { '' } }
    $run = { param($list, $tag, $field)
        $i = 0
        ($list | ForEach-Object { $i++; "<$tag wcm:action=`"add`"><Order>$i</Order><$field>$(ConvertTo-AkariXmlText $_)</$field></$tag>" }) -join ''
    }
    $pe = @($P.PE)
    if ($P.PECmd.Count) { $pe = @("<RunSynchronous>$(& $run $P.PECmd 'RunSynchronousCommand' 'Path')</RunSynchronous>") + $pe }
    $spec = if ($P.SpecCmd.Count) { "<RunSynchronous>$(& $run $P.SpecCmd 'RunSynchronousCommand' 'Path')</RunSynchronous>" } else { '' }
    $oobe = "<OOBE><HideEULAPage>true</HideEULAPage><HideLocalAccountScreen>true</HideLocalAccountScreen><HideOnlineAccountScreens>true</HideOnlineAccountScreens>$($P.OobeFlags -join '')</OOBE>$($P.Oobe -join '')"
    if ($P.Logon.Count) { $oobe += "<FirstLogonCommands>$(& $run $P.Logon 'SynchronousCommand' 'CommandLine')</FirstLogonCommands>" }
    @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <!-- AkariOS: $(ConvertTo-AkariUnattendComment $Options) -->
  <settings pass="windowsPE">
$(& $c 'Microsoft-Windows-International-Core-WinPE' $P.PEIntl)$(& $c 'Microsoft-Windows-Setup' ($pe -join ''))  </settings>
  <settings pass="specialize">
$(& $c 'Microsoft-Windows-Shell-Setup' ($P.Spec -join ''))$(& $c 'Microsoft-Windows-Deployment' $spec)$(& $c 'Microsoft-Windows-UnattendedJoin' '<Identification><JoinWorkgroup>WORKGROUP</JoinWorkgroup></Identification>')  </settings>
  <settings pass="oobeSystem">
$(& $c 'Microsoft-Windows-International-Core' $P.Intl)$(& $c 'Microsoft-Windows-Shell-Setup' $oobe)  </settings>
</unattend>
"@
}

# the choices without passwords, as base64 JSON (a comment can't hold "--")
function ConvertTo-AkariUnattendComment([hashtable]$Options) {
    $o = $Options.Clone()
    $o.WifiPassword = ''
    $o.Accounts = @($Options.Accounts | ForEach-Object { $a = $_.Clone(); $a.Password = ''; $a })
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $o -Depth 5 -Compress)))
}

# the choices of a file Akari made (passwords empty), or $null
function ConvertFrom-AkariUnattend([string]$Xml) {
    if ($Xml -notmatch '<!-- AkariOS: ([A-Za-z0-9+/=]+) -->') { return $null }
    $j = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1])))
    $o = New-AkariUnattendOptions
    foreach ($k in @($j.PSObject.Properties.Name)) { $o[$k] = $j.$k }
    $o.Inputs = @($j.Inputs)
    $o.Accounts = @($j.Accounts | Where-Object { $_ } | ForEach-Object { @{ Name = $_.Name; DisplayName = $_.DisplayName; Password = ''; Group = $_.Group } })
    $o.Disk = if ($j.Disk) { @{ Index = [int]$j.Disk.Index; Layout = $j.Disk.Layout; Recovery = [bool]$j.Disk.Recovery } } else { $null }
    $o
}

# a Wi-Fi profile for netsh wlan add profile ($Auth WPA2 or WPA3)
function New-AkariWifiProfile([string]$Name, [string]$Password, [string]$Auth, [bool]$Hidden) {
    $n = ConvertTo-AkariXmlText $Name
    $a = if ($Auth -eq 'WPA3') { 'WPA3SAE' } else { 'WPA2PSK' }
    @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$n</name>
  <SSIDConfig><SSID><name>$n</name></SSID><nonBroadcast>$(([string]$Hidden).ToLower())</nonBroadcast></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM><security>
    <authEncryption><authentication>$a</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$(ConvertTo-AkariXmlText $Password)</keyMaterial></sharedKey>
  </security></MSM>
</WLANProfile>
"@
}

# this PC's language, keyboard, region, home location and time zone: the page starts from them
function Get-AkariUnattendDefaults {
    $kb = try { @((Get-WinUserLanguageList)[0].InputMethodTips)[0] } catch { $null }
    @{
        Language = [Globalization.CultureInfo]::InstalledUICulture.Name
        Keyboard = if ($kb -match '^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$') { $kb.ToUpper() } else { '0409:00000409' }
        Region   = (Get-Culture).Name
        GeoId    = $(try { (Get-WinHomeLocation).GeoId } catch { 244 })
        TimeZone = (Get-TimeZone).Id
    }
}

# the drives a setup file can go on: removable ones, and any other holding Windows setup (a USB SSD shows as fixed),
# never the system drive. @{ Root = 'E:\'; Label; Setup = holds sources\install.wim|esd|swm }
function Get-AkariSetupDrives {
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk)) {
        if ($d.DeviceID -eq $env:SystemDrive -or $d.DriveType -notin 2, 3) { continue }
        $root = "$($d.DeviceID)\"
        $setup = [bool](@('install.wim', 'install.esd', 'install.swm') | Where-Object { Test-Path -LiteralPath "$($root)sources\$_" })
        if ($d.DriveType -eq 2 -or $setup) { [pscustomobject]@{ Root = $root; Label = "$($d.VolumeName)"; Setup = $setup } }
    }
}

# writes autounattend.xml in $Folder (made if missing; an existing file is replaced: the page asks first); its path
function Save-AkariUnattend([string]$Xml, [string]$Folder) {
    $dir = (New-Item -ItemType Directory -Path $Folder -Force).FullName
    $path = Join-Path $dir 'autounattend.xml'
    [IO.File]::WriteAllText($path, $Xml, [Text.UTF8Encoding]::new($false))
    $path
}
