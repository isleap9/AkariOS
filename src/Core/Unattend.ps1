# Unattend Generator (plan docs/plans/2026-10-29-usb-setup-file.md): a full port of Christoph Schneegans' unattend generator
# (https://schneegans.de/windows/unattend-generator/, MIT), in Core\Unattend\ (Engine, Setup, Disk, ...; his data files
# and license in Core\Unattend\Data\). The choices are his form's fields; a file carries them as its first comment (his
# bookmark URL, without passwords), so a file from his site or from Akari opens again in the form.
foreach ($f in 'Engine', 'Setup', 'Disk', 'Windows', 'Extras') { . (Join-Path $PSScriptRoot "Unattend\$f.ps1") }

# the fields a password lives in: never written to the comment
$AkariUaSecretFields = @('BuiltinAdministratorPassword', 'WifiPassword') + @(0..14 | ForEach-Object { "AccountPassword$_" })

# the answer file's bytes for $Fields: the XML (ASCII, as setup reads it) with the choices as its first comment
function New-AkariUnattend([hashtable]$Fields) {
    $doc = New-AkariUnattendXml $Fields
    [void]$doc.DocumentElement.PrependChild($doc.CreateComment((ConvertTo-AkariUnattendQuery $Fields)))
    , (ConvertTo-AkariUaBytes $doc)
}

# the fields as his bookmark URL (no passwords; '--' can't be in a comment, so it is %2D%2D)
function ConvertTo-AkariUnattendQuery([hashtable]$Fields) {
    $pairs = foreach ($k in @($Fields.Keys | Sort-Object)) {
        if ($k -in $AkariUaSecretFields) { continue }
        foreach ($v in @($Fields[$k])) { if ($null -ne $v) { [uri]::EscapeDataString($k) + '=' + [uri]::EscapeDataString([string]$v).Replace('-', '%2D') } }
    }
    "$($AkariUaSite)?$($pairs -join '&')"
}

# the fields of a file made by his site or by Akari (its first comment), or $null
function ConvertFrom-AkariUnattend([string]$Xml) {
    if ($Xml -notmatch '<!--(https://schneegans\.de/windows/unattend-generator/\?[^>]*?)-->') { return $null }
    ConvertFrom-AkariUnattendQuery $Matches[1]
}
function ConvertFrom-AkariUnattendQuery([string]$Url) {
    $f = @{}
    $q = $Url.Substring($Url.IndexOf('?') + 1)
    foreach ($p in $q.Split('&')) {
        if (-not $p) { continue }
        $i = $p.IndexOf('=')
        $k = [uri]::UnescapeDataString($p.Substring(0, [Math]::Max($i, 0)).Replace('+', ' '))
        $v = if ($i -ge 0) { [uri]::UnescapeDataString($p.Substring($i + 1).Replace('+', ' ')) } else { '' }
        if (-not $k) { continue }
        if ($f.ContainsKey($k)) { $f[$k] = @($f[$k]) + $v } else { $f[$k] = $v }
    }
    $f
}

# the text areas' starting text, as his page fills them: the generated scripts for its sample settings
function Get-AkariUnattendSamples {
    $target = @{ Fields = @{ TargetDiskNoPartitions = 'true'; TargetDiskSize = 'true'; TargetDiskMinSize = '100'; TargetDiskMaxSize = '4000'; TargetDiskIndex = 'true'; TargetDisk = '0' } }
    $pe = @{ Fields = @{ PEMode = 'Generated'; PartitionMode = 'Unattended'; TargetDiskMode = 'Generated'; PartitionLayout = 'Automatic'; RecoveryMode = 'Partition'
        SystemSize = '300'; RecoverySize = '1000'; InstallFromMode = 'Edition'; InstallFromEdition = 'pro'; PagingFileMode = 'Automatic'
        Disable8Dot3Names = 'true'; DisableDefender = 'true'; LanguageMode = 'Unattended'; UILanguage = 'en-US'; Locale = 'en-US'; Keyboard = '00000409'; GeoLocation = '244' } + $target.Fields }
    @{
        TargetDiskScript   = (Get-AkariUaTargetDiskScript $target) -join "`r`n"
        DiskpartScript     = (@(Get-AkariUaDiskpartScript '0' 'GPT' $true 300 1000) | Where-Object { $_ }) -join "`r`n"
        PEScript           = (Get-AkariUaPEScript $pe) -join "`r`n"
        ComputerNameScript = "return 'DESKTOP-{0:D3}' -f ( Get-Random -Minimum 0 -Maximum 999 );"
        WifiProfileXml     = Get-AkariUaResource 'WLANProfile.xml'
        # his page's samples, as it fills them
        TaskbarIconsXml    = @'
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
        <taskbar:UWA AppUserModelID="windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
'@
        StartTilesXml      = @'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="">
          <start:Tile Size="2x2" Column="4" Row="0" AppUserModelID="windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" />
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
'@
        StartPinsJson      = @'
{
  "pinnedList": [
    {
      "desktopAppLink": "%ALLUSERSPROFILE%\\Microsoft\\Windows\\Start Menu\\Programs\\Microsoft Edge.lnk"
    },
    {
      "desktopAppLink": "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\File Explorer.lnk"
    },
    {
      "packagedAppId": "windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel"
    }
  ]
}
'@
        WallpaperScript    = @'
# Photo by Benjamin Voros on Unsplash. See https://unsplash.com/photos/snow-mountain-under-stars-phIFdC6lA4E for more info.
$url = 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=2400';
& {
    $ProgressPreference = 'SilentlyContinue';
    ( Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 ).Content;
};
'@
        LockScreenScript   = @'
foreach( $drive in [System.IO.DriveInfo]::GetDrives() ) {
    if( $found = Join-Path -Path $drive.RootDirectory -ChildPath 'lockscreen.png' -Resolve -ErrorAction 'SilentlyContinue' ) {
        return [System.IO.File]::ReadAllBytes( $found );
    }
}
'Cannot find any files that match pattern.' | Write-Warning;
'@
        AppLockerPolicyXml = @'
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
    <FilePublisherRule Id="30591721-b29c-457d-b083-243f87b3527d" Name="All signed packaged apps" Description="Allows members of the Everyone group to run packaged apps that are signed." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="921cc481-6e17-4653-8f75-050b80acca20" Name="(Default Rule) All files located in the Program Files folder" Description="Allows members of the Everyone group to run applications that are located in the Program Files folder." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="a61c8b2c-a319-4cd0-9690-d2177cad7b51" Name="(Default Rule) All files located in the Windows folder" Description="Allows members of the Everyone group to run applications that are located in the Windows folder." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="fd686d83-a829-4351-8ff4-27c7de5755d2" Name="(Default Rule) All files" Description="Allows members of the local Administrators group to run all applications." UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Msi" EnforcementMode="Enabled">
    <FilePathRule Id="5b290184-345a-4453-b184-45305f6d9a54" Name="(Default Rule) All Windows Installer files in %systemdrive%\Windows\Installer" Description="Allows members of the Everyone group to run all Windows Installer files located in %systemdrive%\Windows\Installer." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\Installer\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="64ad46ff-0d71-4fa0-a30b-3f3d30c5433d" Name="(Default Rule) All Windows Installer files" Description="Allows members of the local Administrators group to run all Windows Installer files." UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*.*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
  <RuleCollection Type="Script" EnforcementMode="Enabled">
    <FilePathRule Id="06dce67b-934c-454f-a263-2515c8796a5d" Name="(Default Rule) All scripts located in the Program Files folder" Description="Allows members of the Everyone group to run scripts that are located in the Program Files folder." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="9428c672-5fc3-47f4-808a-a0011f36dd2c" Name="(Default Rule) All scripts located in the Windows folder" Description="Allows members of the Everyone group to run scripts that are located in the Windows folder." UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="ed97d0cb-15ff-430f-b82c-8d7832957725" Name="(Default Rule) All scripts" Description="Allows members of the local Administrators group to run all scripts." UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
'@
    }
}

# this PC's display language, locale, keyboard, home location and time zone, as fields (the form starts from them)
function Get-AkariUnattendDefaults {
    $kb = try { @((Get-WinUserLanguageList)[0].InputMethodTips)[0] } catch { $null }
    @{
        UILanguage  = [Globalization.CultureInfo]::InstalledUICulture.Name
        Locale      = (Get-Culture).Name
        Keyboard    = if ($kb -match '^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$') { $Matches[1].ToLowerInvariant() } else { '00000409' }
        GeoLocation = [string]$(try { (Get-WinHomeLocation).GeoId } catch { 244 })
        TimeZone    = (Get-TimeZone).Id
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

# writes autounattend.xml ($Bytes) in $Folder (made if missing; an existing file is replaced: the page asks first); its path
function Save-AkariUnattend([byte[]]$Bytes, [string]$Folder) {
    $dir = (New-Item -ItemType Directory -Path $Folder -Force).FullName
    $path = Join-Path $dir 'autounattend.xml'
    [IO.File]::WriteAllBytes($path, $Bytes)
    $path
}
