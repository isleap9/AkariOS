$Root = Split-Path $PSScriptRoot
. "$Root\Core\Unattend.ps1"

# the XML read back: a node list by XPath (prefix u = the unattend namespace)
function Get-Nodes([string]$Xml, [string]$Path) {
    $doc = [xml]$Xml
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
    @($doc.SelectNodes($Path, $ns))
}
function Get-Text([string]$Xml, [string]$Path) { @(Get-Nodes $Xml $Path | ForEach-Object { $_.InnerText }) -join '|' }
function Count([string]$Xml, [string]$Path) { @(Get-Nodes $Xml $Path).Count }
function Pass([string]$Name) { "//u:settings[@pass='$Name']" }
function B64([string]$s) { [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s)) }
$pe = Pass 'windowsPE'; $sp = Pass 'specialize'; $oobe = Pass 'oobeSystem'

# one admin with no password, Italian, everything else at its default
function Opt([hashtable]$Change) {
    $o = New-AkariUnattendOptions
    $o.Language = 'it-IT'; $o.Inputs = @('0410:00000410'); $o.Region = 'it-IT'; $o.GeoId = 118; $o.TimeZone = 'W. Europe Standard Time'
    $o.Accounts = @(@{ Name = 'Gamer'; DisplayName = ''; Password = ''; Group = 'Administrators' })
    foreach ($k in $Change.Keys) { $o[$k] = $Change[$k] }
    $o
}

Describe 'Test-AkariUnattendName' {
    It 'takes a plain account name' { Test-AkariUnattendName 'Gamer_1' 'Account' | Should BeNullOrEmpty }
    It 'refuses an empty, spaced, too long or reserved account name' {
        Test-AkariUnattendName '' 'Account' | Should Be 'Enter an account name.'
        Test-AkariUnattendName 'My Name' 'Account' | Should Be 'No spaces in the account name.'
        Test-AkariUnattendName ('a' * 21) 'Account' | Should Be 'At most 20 characters.'
        Test-AkariUnattendName 'a@b' 'Account' | Should Be 'These characters can''t be used: " / \ [ ] : ; | = , + * ? < > @'
        Test-AkariUnattendName 'administrator' 'Account' | Should Be '''administrator'' is a name Windows uses itself.'
        Test-AkariUnattendName '...' 'Account' | Should Be 'Use at least one letter or digit.'
    }
    It 'takes an empty or valid PC name' {
        Test-AkariUnattendName '' 'Computer' | Should BeNullOrEmpty
        Test-AkariUnattendName 'GAMING-PC2' 'Computer' | Should BeNullOrEmpty
    }
    It 'refuses a PC name that is too long, all digits, hyphen-ended or has other characters' {
        Test-AkariUnattendName ('a' * 16) 'Computer' | Should Be 'At most 15 characters.'
        Test-AkariUnattendName '1234' 'Computer' | Should Be 'Use at least one letter.'
        Test-AkariUnattendName '-pc' 'Computer' | Should Be 'Letters, digits and hyphens only, no hyphen at either end.'
        Test-AkariUnattendName 'my_pc' 'Computer' | Should Be 'Letters, digits and hyphens only, no hyphen at either end.'
    }
}

Describe 'New-AkariUnattend: region' {
    Context 'set in the file' {
        $x = New-AkariUnattend (Opt @{ Inputs = @('0410:00000410', '0409:00000409', '0407:00000407') })
        It 'is an unattend file' { Count $x '/u:unattend' | Should Be 1 }
        It 'sets the display language, up to three keyboards and the region format, in setup and in Windows' {
            Get-Text $x "$pe//u:SetupUILanguage/u:UILanguage" | Should Be 'it-IT'
            foreach ($p in $pe, $oobe) {
                Get-Text $x "$p//u:UILanguage[not(parent::u:SetupUILanguage)]" | Should Be 'it-IT'
                Get-Text $x "$p//u:InputLocale" | Should Be '0410:00000410;0409:00000409;0407:00000407'
                Get-Text $x "$p//u:SystemLocale" | Should Be 'it-IT'
                Get-Text $x "$p//u:UserLocale" | Should Be 'it-IT'
            }
        }
        It 'sets the time zone' { Get-Text $x "$sp//u:TimeZone" | Should Be 'W. Europe Standard Time' }
        It 'sets the home location for the PC and new users' {
            $c = Get-Text $x "$sp//u:RunSynchronousCommand/u:Path"
            $c | Should Match ([regex]::Escape('reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion" /v DeviceRegion /t REG_DWORD /d 118 /f'))
            $c | Should Match ([regex]::Escape('reg add "HKU\DefaultUser\Control Panel\International\Geo" /v Nation /t REG_SZ /d 118 /f'))
        }
    }
    Context 'asked during setup' {
        $x = New-AkariUnattend (Opt @{ AskRegion = $true })
        It 'leaves language, keyboard, region and home location to setup' {
            Count $x '//u:component[starts-with(@name, ''Microsoft-Windows-International-Core'')]' | Should Be 0
            Get-Text $x "$sp//u:RunSynchronousCommand/u:Path" | Should Not Match 'DeviceRegion|Nation'
        }
        It 'still sets the time zone' { Get-Text $x "$sp//u:TimeZone" | Should Be 'W. Europe Standard Time' }
    }
}

Describe 'New-AkariUnattend: Windows setup' {
    Context 'the defaults' {
        $x = New-AkariUnattend (Opt @{})
        It 'asks for the edition (product key page)' {
            Get-Text $x "$pe//u:ProductKey/u:Key" | Should Be '00000-00000-00000-00000-00000'
            Get-Text $x "$pe//u:ProductKey/u:WillShowUI" | Should Be 'Always'
        }
        It 'skips the five Windows 11 hardware checks before setup' {
            Get-Text $x "$pe//u:RunSynchronousCommand/u:Path" | Should Be (@('TPM', 'RAM', 'SecureBoot', 'CPU', 'Storage' | ForEach-Object { "reg add HKLM\SYSTEM\Setup\LabConfig /v Bypass$($_)Check /t REG_DWORD /d 1 /f" }) -join '|')
            Get-Text $x "$pe//u:RunSynchronousCommand/u:Order" | Should Be '1|2|3|4|5'
        }
        It 'lets setup go on without internet' {
            Get-Text $x "$sp//u:RunSynchronousCommand/u:Path" | Should Match ([regex]::Escape('reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f'))
        }
        It 'turns the express (privacy) settings off and skips the setup questions' {
            Get-Text $x "$oobe//u:OOBE/u:ProtectYourPC" | Should Be '3'
            foreach ($n in 'HideEULAPage', 'HideLocalAccountScreen', 'HideOnlineAccountScreens', 'AcceptEula') { Get-Text $x "//u:$n" | Should Be 'true' }
            Get-Text $x '//u:DynamicUpdate/u:Enable' | Should Be 'false'
            Get-Text $x '//u:Diagnostics/u:OptIn' | Should Be 'false'
        }
        It 'leaves the disk to the user, applies the image normally' {
            Count $x '//u:DiskConfiguration' | Should Be 0
            Count $x '//u:ImageInstall' | Should Be 0
        }
    }
    Context 'an edition by generic key, express settings on, checks kept, internet needed, compact' {
        $x = New-AkariUnattend (Opt @{ Edition = 'Generic'; EditionName = 'Pro'; SkipChecks = $false; NoInternet = $false; Express = 'On'; Compact = $true })
        It 'installs Pro with Microsoft''s generic key (picks the edition, never activates)' {
            Get-Text $x "$pe//u:ProductKey/u:Key" | Should Be 'VK7JG-NPHTM-C97JM-9MPGT-3V66T'
            Get-Text $x "$pe//u:ProductKey/u:WillShowUI" | Should Be 'OnError'
        }
        It 'runs nothing before setup and keeps the internet requirement' {
            Count $x "$pe//u:RunSynchronous" | Should Be 0
            Get-Text $x "$sp//u:RunSynchronousCommand/u:Path" | Should Not Match 'BypassNRO'
        }
        It 'turns the express settings on' { Get-Text $x "$oobe//u:ProtectYourPC" | Should Be '1' }
        It 'applies Windows in compact mode' { Get-Text $x "$pe//u:ImageInstall/u:OSImage/u:Compact" | Should Be 'true' }
    }
    Context 'my own key, express settings asked' {
        $x = New-AkariUnattend (Opt @{ Edition = 'Key'; ProductKey = 'ABCDE-12345-ABCDE-12345-ABCDE'; Express = 'Ask' })
        It 'uses the key' { Get-Text $x "$pe//u:ProductKey/u:Key" | Should Be 'ABCDE-12345-ABCDE-12345-ABCDE' }
        It 'asks the express settings' { Count $x '//u:ProtectYourPC' | Should Be 0 }
    }
    Context 'the firmware''s key' {
        $x = New-AkariUnattend (Opt @{ Edition = 'Firmware' })
        It 'lets setup read the key from the firmware' {
            Get-Text $x "$pe//u:ProductKey/u:Key" | Should Be '00000-00000-00000-00000-00000'
            Get-Text $x "$pe//u:ProductKey/u:WillShowUI" | Should Be 'OnError'
        }
    }
    Context 'wipe disk 1, GPT, Windows RE on its partition' {
        $x = New-AkariUnattend (Opt @{ Disk = @{ Index = 1; Layout = 'GPT'; Recovery = $true } })
        It 'wipes disk 1' {
            Get-Text $x "$pe//u:DiskConfiguration/u:Disk/u:DiskID" | Should Be '1'
            Get-Text $x "$pe//u:DiskConfiguration/u:Disk/u:WillWipeDisk" | Should Be 'true'
        }
        It 'makes recovery, EFI, MSR and Windows partitions' {
            Get-Text $x "$pe//u:CreatePartition/u:Type" | Should Be 'Primary|EFI|MSR|Primary'
            Get-Text $x "$pe//u:CreatePartition/u:Size" | Should Be '1000|300|16'
            Get-Text $x "$pe//u:CreatePartition/u:Extend" | Should Be 'true'
            Get-Text $x "$pe//u:ModifyPartition/u:Format" | Should Be 'NTFS|FAT32|NTFS'
            Get-Text $x "$pe//u:ModifyPartition/u:TypeID" | Should Be 'DE94BBA4-06D1-4D40-A16A-BFD50179D6AC'
            Get-Text $x "$pe//u:ModifyPartition/u:Letter" | Should Be 'C'
        }
        It 'installs Windows on the last partition' {
            Get-Text $x "$pe//u:ImageInstall/u:OSImage/u:InstallTo/u:DiskID" | Should Be '1'
            Get-Text $x "$pe//u:ImageInstall/u:OSImage/u:InstallTo/u:PartitionID" | Should Be '4'
        }
    }
    Context 'wipe disk 0, MBR, Windows RE removed' {
        $x = New-AkariUnattend (Opt @{ Disk = @{ Index = 0; Layout = 'MBR'; Recovery = $false } })
        It 'makes an active system partition and the Windows partition' {
            Get-Text $x "$pe//u:CreatePartition/u:Type" | Should Be 'Primary|Primary'
            Get-Text $x "$pe//u:ModifyPartition/u:Active" | Should Be 'true'
            Get-Text $x "$pe//u:ImageInstall/u:OSImage/u:InstallTo/u:PartitionID" | Should Be '2'
        }
        It 'removes Windows RE once Windows is installed' {
            Get-Text $x "$sp//u:RunSynchronousCommand/u:Path" | Should Match ([regex]::Escape('reagentc.exe /disable'))
        }
    }
}

Describe 'New-AkariUnattend: accounts' {
    Context 'one administrator with no password, random PC name, defaults' {
        $x = New-AkariUnattend (Opt @{})
        It 'adds the administrator with an empty password' {
            Get-Text $x "$oobe//u:LocalAccount/u:Name" | Should Be 'Gamer'
            Get-Text $x "$oobe//u:LocalAccount/u:Group" | Should Be 'Administrators'
            Get-Text $x "$oobe//u:LocalAccount/u:Password/u:Value" | Should Be ''
        }
        It 'signs in to it once by itself' {
            Get-Text $x "$oobe//u:AutoLogon/u:Username" | Should Be 'Gamer'
            Get-Text $x "$oobe//u:AutoLogon/u:Enabled" | Should Be 'true'
            Get-Text $x "$oobe//u:AutoLogon/u:LogonCount" | Should Be '1'
            Get-Text $x "$oobe//u:FirstLogonCommands/u:SynchronousCommand/u:CommandLine" | Should Match 'AutoLogonCount /t REG_DWORD /d 0'
        }
        It 'lets Windows pick the PC name' { Get-Text $x "$sp//u:ComputerName" | Should Be '*' }
        It 'makes passwords never expire and keeps the lockout policy' {
            $c = Get-Text $x "$sp//u:RunSynchronousCommand/u:Path"
            $c | Should Match 'net accounts /maxpwage:unlimited'
            $c | Should Not Match 'lockoutthreshold'
        }
    }
    Context 'two accounts with passwords, a PC name, expiry and lockout at the Windows default / off' {
        $accounts = @(
            @{ Name = 'Boss'; DisplayName = 'The Boss'; Password = 'p&ss<1'; Group = 'Administrators' }
            @{ Name = 'Kid'; DisplayName = ''; Password = 'k1d'; Group = 'Users' }
        )
        $x = New-AkariUnattend (Opt @{ Accounts = $accounts; Computer = 'GAMING-PC'; PasswordExpiry = 'Default'; Lockout = 'Off' })
        It 'adds both, each in its group, with its display name' {
            Get-Text $x "$oobe//u:LocalAccount/u:Name" | Should Be 'Boss|Kid'
            Get-Text $x "$oobe//u:LocalAccount/u:Group" | Should Be 'Administrators|Users'
            Get-Text $x "$oobe//u:LocalAccount/u:DisplayName" | Should Be 'The Boss|Kid'
        }
        It 'writes the passwords base64-encoded (Windows'' PlainText=false form)' {
            Get-Text $x "$oobe//u:LocalAccount/u:Password/u:Value" | Should Be "$(B64 'p&ss<1Password')|$(B64 'k1dPassword')"
            Get-Text $x "$oobe//u:LocalAccount/u:Password/u:PlainText" | Should Be 'false|false'
        }
        It 'signs in once to the first administrator, with its password' {
            Get-Text $x "$oobe//u:AutoLogon/u:Username" | Should Be 'Boss'
            Get-Text $x "$oobe//u:AutoLogon/u:Password/u:Value" | Should Be (B64 'p&ss<1Password')
        }
        It 'names the PC' { Get-Text $x "$sp//u:ComputerName" | Should Be 'GAMING-PC' }
        It 'keeps the expiry and turns the lockout off' {
            $c = Get-Text $x "$sp//u:RunSynchronousCommand/u:Path"
            $c | Should Not Match 'maxpwage'
            $c | Should Match 'net accounts /lockoutthreshold:0'
        }
    }
}

Describe 'New-AkariUnattend: network and first sign-in' {
    It 'skips the Wi-Fi page by default and runs nothing from the USB' {
        $x = New-AkariUnattend (Opt @{})
        Get-Text $x "$oobe//u:HideWirelessSetupInOOBE" | Should Be 'true'
        Get-Text $x "$oobe//u:FirstLogonCommands//u:CommandLine" | Should Not Match 'firstlogon'
    }
    It 'shows the Wi-Fi page when asked' {
        Get-Text (New-AkariUnattend (Opt @{ Wifi = 'Ask' })) "$oobe//u:HideWirelessSetupInOOBE" | Should Be 'false'
    }
    It 'with a network or a preset, runs the USB''s first sign-in script (found on any drive)' {
        foreach ($o in @{ Wifi = 'Join'; WifiName = 'Home' }, @{ Preset = 'AkariOS' }) {
            $c = Get-Text (New-AkariUnattend (Opt $o)) "$oobe//u:FirstLogonCommands//u:CommandLine"
            $c | Should Match ([regex]::Escape('if exist %d:\AkariOS\firstlogon.ps1 powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File %d:\AkariOS\firstlogon.ps1'))
        }
    }
}

Describe 'New-AkariWifiProfile' {
    It 'writes a WPA2 profile' {
        $p = [xml](New-AkariWifiProfile 'Home & Co' 'pa<ss' 'WPA2' $false)
        $p.WLANProfile.name | Should Be 'Home & Co'
        $p.WLANProfile.SSIDConfig.SSID.name | Should Be 'Home & Co'
        $p.WLANProfile.SSIDConfig.nonBroadcast | Should Be 'false'
        $p.WLANProfile.MSM.security.authEncryption.authentication | Should Be 'WPA2PSK'
        $p.WLANProfile.MSM.security.sharedKey.keyMaterial | Should Be 'pa<ss'
    }
    It 'writes a hidden WPA3 profile' {
        $p = [xml](New-AkariWifiProfile 'Lab' 'x' 'WPA3' $true)
        $p.WLANProfile.SSIDConfig.nonBroadcast | Should Be 'true'
        $p.WLANProfile.MSM.security.authEncryption.authentication | Should Be 'WPA3SAE'
    }
}

Describe 'ConvertFrom-AkariUnattend' {
    $o = Opt @{ Inputs = @('0410:00000410', '0409:00000409'); Edition = 'Generic'; EditionName = 'Home'; Computer = 'PC1'; Preset = 'AkariOS'
        Accounts = @(@{ Name = 'Boss'; DisplayName = 'B'; Password = 'secret'; Group = 'Administrators' }); Wifi = 'Join'; WifiName = 'Home'; WifiPassword = 'wpass'
        Disk = @{ Index = 2; Layout = 'MBR'; Recovery = $false } }
    $xml = New-AkariUnattend $o
    $back = ConvertFrom-AkariUnattend $xml
    It 'reads the choices back' {
        $back.Language | Should Be 'it-IT'
        $back.Inputs -join ';' | Should Be '0410:00000410;0409:00000409'
        $back.GeoId | Should Be 118
        "$($back.Edition)/$($back.EditionName)" | Should Be 'Generic/Home'
        $back.Computer | Should Be 'PC1'
        $back.Preset | Should Be 'AkariOS'
        "$($back.Accounts[0].Name)/$($back.Accounts[0].DisplayName)/$($back.Accounts[0].Group)" | Should Be 'Boss/B/Administrators'
        "$($back.Disk.Index)/$($back.Disk.Layout)/$($back.Disk.Recovery)" | Should Be '2/MBR/False'
        $back.WifiName | Should Be 'Home'
        $back.SkipChecks | Should Be $true
    }
    It 'never keeps a password in the comment' {
        $back.Accounts[0].Password | Should BeNullOrEmpty
        $back.WifiPassword | Should BeNullOrEmpty
        $xml | Should Not Match 'secret|wpass'
    }
    It 'is $null for a file Akari did not make' { ConvertFrom-AkariUnattend '<unattend xmlns="urn:schemas-microsoft-com:unattend"/>' | Should BeNullOrEmpty }
}

Describe 'Save-AkariUnattend' {
    It 'writes autounattend.xml in the folder, UTF-8 without a BOM, and returns its path' {
        $p = Save-AkariUnattend (New-AkariUnattend (Opt @{})) 'TestDrive:\usb'
        $p | Should Be (Join-Path (Resolve-Path 'TestDrive:\usb').ProviderPath 'autounattend.xml')
        $bytes = [IO.File]::ReadAllBytes($p)
        $bytes[0] | Should Be 0x3C
        ([xml][IO.File]::ReadAllText($p)).unattend | Should Not BeNullOrEmpty
    }
}

Describe 'Get-AkariSetupDrives' {
    Mock Get-CimInstance {
        [pscustomobject]@{ DeviceID = 'C:'; DriveType = 3; VolumeName = 'System' }
        [pscustomobject]@{ DeviceID = 'D:'; DriveType = 2; VolumeName = 'STICK' }
        [pscustomobject]@{ DeviceID = 'E:'; DriveType = 2; VolumeName = 'CCCOMA_X64' }
        [pscustomobject]@{ DeviceID = 'F:'; DriveType = 3; VolumeName = 'USB SSD' }
        [pscustomobject]@{ DeviceID = 'G:'; DriveType = 3; VolumeName = 'Data' }
    }
    Mock Test-Path { $LiteralPath -in 'E:\sources\install.esd', 'F:\sources\install.wim', 'C:\sources\install.wim' }
    $d = @(Get-AkariSetupDrives)
    It 'lists removable drives and other drives holding Windows setup, never the system drive' {
        ($d | ForEach-Object { $_.Root }) -join ',' | Should Be 'D:\,E:\,F:\'
    }
    It 'marks the drives with Windows setup' { ($d | ForEach-Object { "$($_.Label):$($_.Setup)" }) -join ',' | Should Be 'STICK:False,CCCOMA_X64:True,USB SSD:True' }
}

Describe 'USB setup file page (no window, fake drives in TestDrive)' {
    $usb = "$TestDrive\usb"; $stick = "$TestDrive\stick"; $folder = "$TestDrive\folder"
    New-Item -ItemType Directory $usb, $stick | Out-Null
    $probe = "$TestDrive\unattend.ps1"
    Set-Content $probe -Value @'
param($Root, $Usb, $Stick, $Folder)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
. "$Root\Core\Unattend.ps1"
foreach ($f in 'Selection', 'Steps', 'Unattend') { . "$Root\UI\$f.ps1" }
function Add-Log($m) { $script:log += , $m }
function Get-AkariUnattendDefaults { @{ Language = 'it-IT'; Keyboard = '0409:0000FFFF'; Region = 'it-IT'; GeoId = 118; TimeZone = 'W. Europe Standard Time' } }
function Get-AkariSetupDrives { [pscustomobject]@{ Root = "$Stick\"; Label = 'STICK'; Setup = $false }; [pscustomobject]@{ Root = "$Usb\"; Label = 'WIN11'; Setup = $true } }
$script:asked = @()
function Confirm-AkariDialog($m) { $script:asked += , $m; $script:answer }
function Show-AkariMessage($m) { $script:told = $m }
function Open-AkariFolder($p) { $script:opened = $p }
function Select-AkariFolder { $Folder }
function Read-Back($p) { $o = ConvertFrom-AkariUnattend (Get-Content $p -Raw); "$($o.Accounts[0].Name)|$($o.Computer)|$($o.Inputs[0])" }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new()
$Heading = [Windows.Controls.TextBlock]::new(); $HeaderSub = [Windows.Controls.TextBlock]::new()
Show-AkariUnattend
$u = $script:UnattendParts
"page=$($Heading.Text)|$($StepNext.Visibility)|$($StepBack.Visibility)"
"prefill=$($u.Language.SelectedItem.Tag)|$($u.Keyboard.SelectedItem.Tag)|$($u.Region.SelectedItem.Tag)|$($u.TimeZone.SelectedItem.Tag)|$($u.SkipChecks.IsChecked)"
"languages=$($u.Language.Items.Count)"
# a language change moves the keyboard to its default
$u.Language.SelectedItem = @($u.Language.Items | Where-Object { $_.Tag -eq 'fr-FR' })[0]
"kbFollows=$($u.Keyboard.SelectedItem.Tag)"
# the drive with Windows setup comes first
"drives=$(($u.Drive.Items | ForEach-Object { $_.Content }) -join ',')|$($u.Drive.SelectedIndex)"
# no account name: nothing saved
$script:answer = $true
Invoke-AkariUnattendUsb
"noName=$($u.Error.Text)|$(Test-Path "$Usb\autounattend.xml")"
$u.Account.Text = 'Gamer'; $u.Computer.Text = '-bad'
Invoke-AkariUnattendUsb
"badPc=$($u.Error.Text)"
$u.Computer.Text = 'GAMING-PC'
"warnHidden=$($u.PasswordWarn.Visibility)"
$u.Password.Password = 'secret'
"warnShown=$($u.PasswordWarn.Visibility)"
Invoke-AkariUnattendUsb
"saved=$($u.Error.Text)|$($script:opened)|$(@($script:asked).Count)"
"content=$(Read-Back "$Usb\autounattend.xml")"
# again: the file exists, so it asks; No leaves it alone
$script:asked = @(); $script:answer = $false; $u.Account.Text = 'Other'
Invoke-AkariUnattendUsb
"replaceNo=$(@($script:asked).Count)|$(Read-Back "$Usb\autounattend.xml")"
# a drive without Windows setup asks first; No saves nothing
$script:asked = @(); $u.Drive.SelectedIndex = 1
Invoke-AkariUnattendUsb
"noSetup=$(@($script:asked).Count)|$(Test-Path "$Stick\autounattend.xml")"
# a folder of the user's choice
Invoke-AkariUnattendFolder
"folder=$(Test-Path "$Folder\autounattend.xml")|$script:opened"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Usb $usb -Stick $stick -Folder $folder 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'opens full window with Back only' { $out.page | Should Be 'USB setup file|Collapsed|Visible' }
    It 'starts from this PC: language, keyboard (added when not listed), region, time zone; checks skipped' {
        $out.prefill | Should Be 'it-IT|0409:0000FFFF|it-IT|W. Europe Standard Time|True'
        $out.languages | Should Be '38'
    }
    It 'moves the keyboard to the language''s default' { $out.kbFollows | Should Be '040C:0000040C' }
    It 'lists the drives, the one with Windows setup first and picked' { $out.drives | Should Be 'WIN11 (Windows setup),STICK|0' }
    It 'saves nothing until the names are right' {
        $out.noName | Should Be 'Enter an account name.|False'
        $out.badPc | Should Be 'PC name: Letters, digits and hyphens only, no hyphen at either end.'
    }
    It 'warns about the password only once there is one' {
        $out.warnHidden | Should Be 'Collapsed'
        $out.warnShown | Should Be 'Visible'
    }
    It 'saves to the setup drive without asking, then opens it' {
        $out.saved | Should Be "|$usb\|0"
        $out.content | Should Be 'Gamer|GAMING-PC|040C:0000040C'
    }
    It 'asks before replacing a file, and No keeps it' { $out.replaceNo | Should Be '1|Gamer|GAMING-PC|040C:0000040C' }
    It 'asks before a drive without Windows setup, and No saves nothing' { $out.noSetup | Should Be '1|False' }
    It 'saves to a folder of the user''s choice' { $out.folder | Should Be "True|$folder" }
}
