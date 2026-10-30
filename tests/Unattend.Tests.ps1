$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
. "$Root\Core\Unattend.ps1"

# a document compared without its comment (the bookmark URL) and his build stamp (s:Build/s:Commit)
function Get-Canonical([string]$Xml) {
    $d = [xml]::new(); $d.LoadXml($Xml)
    $ns = [Xml.XmlNamespaceManager]::new($d.NameTable); $ns.AddNamespace('s', 'https://schneegans.de/windows/unattend-generator/')
    foreach ($n in @($d.SelectNodes('//comment()'))) { [void]$n.ParentNode.RemoveChild($n) }
    foreach ($n in @($d.SelectNodes('//s:Commit', $ns))) { [void]$n.ParentNode.RemoveChild($n) }
    foreach ($n in @($d.SelectNodes('//s:Build', $ns))) { if (-not $n.HasChildNodes) { [void]$n.ParentNode.RemoveChild($n) } }
    $d.OuterXml
}
function Get-Ours([hashtable]$Fields) { [Text.Encoding]::ASCII.GetString((New-AkariUnattend $Fields)) }

# Tests\Fixtures\Unattend\*.xml: files made on schneegans.de (commit 82d4ffd), each with its choices as its first comment
Describe 'New-AkariUnattend matches Schneegans'' generator' {
    foreach ($f in Get-ChildItem "$Root\..\tests\Fixtures\Unattend\*.xml") {
        It "makes the same file as his site: $($f.BaseName)" {
            $theirs = [IO.File]::ReadAllText($f.FullName)
            $fields = ConvertFrom-AkariUnattend $theirs
            # the site's comment has the passwords; Akari's never does
            Get-Canonical (Get-Ours $fields) | Should Be (Get-Canonical $theirs)
        }
    }
}

Describe 'the choices in the file' {
    $theirs = [IO.File]::ReadAllText("$Root\..\tests\Fixtures\Unattend\2-unattended.xml")
    $fields = ConvertFrom-AkariUnattend $theirs
    $ours = Get-Ours $fields
    It 'reads a file from his site' {
        $fields.UILanguage | Should Be 'it-IT'
        $fields.AccountName0 | Should Be 'Boss'
        $fields.WifiName | Should Be 'Home & Co'
        $fields.Keyboard3 | Should Be '0411:{03b5835f-f03c-411b-9ce2-aa23e1171e36}{a76c93d9-5523-4e90-aafa-4db112f9ac76}'
    }
    It 'writes them back as his bookmark URL, which reads back the same, without the passwords' {
        $back = ConvertFrom-AkariUnattend $ours
        foreach ($k in $fields.Keys) {
            if ($k -in $AkariUaSecretFields) { $back.ContainsKey($k) | Should Be $false } else { "$k=$(@($back[$k]) -join ',')" | Should Be "$k=$(@($fields[$k]) -join ',')" }
        }
        [regex]::Match($ours, '<!--.*?-->').Value | Should Not Match 'secret123|p%26ss|Password0='
    }
    It 'keeps every value of a multi-select' {
        $f3 = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText("$Root\..\tests\Fixtures\Unattend\3-builtin.xml"))
        @($f3.ProcessorArchitecture) -join ',' | Should Be 'amd64,arm64'
        @((ConvertFrom-AkariUnattend (Get-Ours $f3)).ProcessorArchitecture) -join ',' | Should Be 'amd64,arm64'
    }
    It 'is $null for a file made elsewhere' { ConvertFrom-AkariUnattend '<unattend xmlns="urn:schemas-microsoft-com:unattend"/>' | Should BeNullOrEmpty }
    It 'is plain ASCII with a utf-8 declaration (setup reads ASCII only)' {
        $bytes = New-AkariUnattend $fields
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should Be 0
        [Text.Encoding]::ASCII.GetString($bytes, 0, 38) | Should Be '<?xml version="1.0" encoding="utf-8"?>'
    }
}

Describe 'his checks' {
    $base = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText("$Root\..\tests\Fixtures\Unattend\2-unattended.xml"))
    function With([hashtable]$Change) { $o = $base.Clone(); foreach ($k in $Change.Keys) { $o[$k] = $Change[$k] }; $o }
    It 'refuses a bad computer name' { { New-AkariUnattend (With @{ ComputerName = '12345' }) } | Should Throw "Computer name '12345' is invalid." }
    It 'refuses a bad user name' { { New-AkariUnattend (With @{ AccountName1 = 'guest' }) } | Should Throw "Username 'guest' is invalid." }
    It 'wants an administrator' { { New-AkariUnattend (With @{ AccountGroup0 = 'Users' }) } | Should Throw 'Must have at least one administrator account.' }
    It 'refuses an account named like the PC' { { New-AkariUnattend (With @{ AccountName1 = 'gaming-pc' }) } | Should Throw "Account name 'gaming-pc' must not be the same as the computer name." }
    It 'refuses a twice-used account name' { { New-AkariUnattend (With @{ AccountName1 = 'BOSS' }) } | Should Throw "Account name(s) 'Boss' specified more than once." }
    It 'refuses an ill-formed product key' { { New-AkariUnattend (With @{ WindowsEditionMode = 'Custom'; ProductKey = 'ABC' }) } | Should Throw "Product key 'ABC' is ill-formed." }
    It 'wants an auto sign-in to delete the sensitive files' { { New-AkariUnattend (With @{ AutoLogonMode = 'None' }) } | Should Throw 'To delete sensitive files, you must let Windows log on to an administrator account.' }
    It 'wants the Windows and system letters in a custom diskpart script' {
        { New-AkariUnattend (With @{ PEMode = 'Generated'; PartitionMode = 'Custom'; DiskpartScript = "SELECT DISK=0`r`nASSIGN LETTER=S" }) } | Should Throw "Your diskpart script must contain a line such as 'ASSIGN LETTER=W'"
    }
}

Describe 'Save-AkariUnattend' {
    It 'writes autounattend.xml in the folder and returns its path' {
        $bytes = [Text.Encoding]::ASCII.GetBytes('<unattend/>')
        $p = Save-AkariUnattend $bytes 'TestDrive:\usb'
        $p | Should Be (Join-Path (Resolve-Path 'TestDrive:\usb').ProviderPath 'autounattend.xml')
        [IO.File]::ReadAllText($p) | Should Be '<unattend/>'
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

Describe 'Install USB page (no window, fake drives in TestDrive)' {
    $usb = "$TestDrive\usb"; $stick = "$TestDrive\stick"; $folder = "$TestDrive\folder"
    New-Item -ItemType Directory $usb, $stick | Out-Null
    $probe = "$TestDrive\unattend.ps1"
    Set-Content $probe -Value @'
param($Root, $Usb, $Stick, $Folder)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
. "$Root\Core\Unattend.ps1"
foreach ($f in 'Selection', 'Steps', 'UnattendForm', 'Unattend') { . "$Root\UI\$f.ps1" }
function Add-Log($m) { }
function Get-AkariUnattendDefaults { @{ UILanguage = 'it-IT'; Locale = 'it-IT'; Keyboard = '00000410'; GeoLocation = '118'; TimeZone = 'W. Europe Standard Time' } }
function Get-AkariSetupDrives { [pscustomobject]@{ Root = "$Stick\"; Label = 'STICK'; Setup = $false }; [pscustomobject]@{ Root = "$Usb\"; Label = 'WIN11'; Setup = $true } }
$script:asked = @()
function Confirm-AkariDialog($m) { $script:asked += , $m; $script:answer }
function Show-AkariMessage($m) { $script:told = $m }
function Open-AkariFolder($p) { $script:opened = $p }
function Select-AkariFolder { $Folder }
function Select-AkariUnattendFile { $script:pick }
function Canon([string]$Xml) {
    $d = [xml]::new(); $d.LoadXml($Xml)
    $ns = [Xml.XmlNamespaceManager]::new($d.NameTable); $ns.AddNamespace('s', 'https://schneegans.de/windows/unattend-generator/')
    foreach ($n in @($d.SelectNodes('//comment()'))) { [void]$n.ParentNode.RemoveChild($n) }
    foreach ($n in @($d.SelectNodes('//s:Commit', $ns))) { [void]$n.ParentNode.RemoveChild($n) }
    foreach ($n in @($d.SelectNodes('//s:Build', $ns))) { if (-not $n.HasChildNodes) { [void]$n.ParentNode.RemoveChild($n) } }
    $d.OuterXml
}
function Pick($field, $value) { @($script:UaBindings | Where-Object { $_.Field -eq $field })[0].Options[$value].IsChecked = $true }
function Box($field) { @($script:UaBindings | Where-Object { $_.Field -eq $field })[0].Control }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
[void]$res.Children.Add($StepBody)
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new()
$Heading = [Windows.Controls.TextBlock]::new(); $HeaderSub = [Windows.Controls.TextBlock]::new()
Show-AkariUnattend
"page=$($Heading.Text)|$($StepNext.Visibility)|$($StepBack.Visibility)|$($script:UaBindings.Count -gt 100)"
$f = Get-AkariUaFormFields
"start=$($f.LanguageMode)|$($f.UILanguage)|$($f.Keyboard)|$($f.TimeZone)|$($f.AccountName0)|$($f.PEMode)|$($f.ContainsKey('PartitionMode'))|$($f.ContainsKey('Locale2'))"
"samples=$($f.ContainsKey('PEScript'))|$((Box 'DiskpartScript').Text.Split("`n")[0].Trim())"
"rows=$(@($script:UaAccountRows | Where-Object { $_.Visibility -eq 'Visible' }).Count)"
# a picked branch shows its items and they count
Pick 'PEMode' 'Generated'
$g = @($script:UaBindings | Where-Object { $_.Field -eq 'PEMode' })[0].Options['Generated']
"branch=$($g.Tag.Visibility)|$((Get-AkariUaFormFields).PartitionMode)"
# it wipes a disk: asked first, No saves nothing
$script:answer = $false
Invoke-AkariUnattendUsb
"wipe=$(@($script:asked).Count)|$($script:asked[0].Substring(0, 33))|$(Test-Path "$Usb\autounattend.xml")"
Pick 'PEMode' 'Default'
"hidden=$($g.Tag.Visibility)|$((Get-AkariUaFormFields).ContainsKey('PartitionMode'))"
# no administrator: the generator's check, shown under Save
(Box 'AccountGroup0').SelectedValue = 'Users'
Invoke-AkariUnattendUsb
"noAdmin=$($script:UnattendParts.Error.Text)|$(Test-Path "$Usb\autounattend.xml")"
(Box 'AccountGroup0').SelectedValue = 'Administrators'
# saved to the setup drive without asking, then opened; it reads back
$script:asked = @(); $script:answer = $true
Invoke-AkariUnattendUsb
$back = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText("$Usb\autounattend.xml"))
"saved=$($script:UnattendParts.Error.Text)|$script:opened|$(@($script:asked).Count)|$($back.AccountName0)|$($back.UILanguage)"
# a drive without Windows setup asks first
$script:asked = @(); $script:answer = $false; $script:UnattendParts.Drive.SelectedIndex = 1
Invoke-AkariUnattendUsb
"noSetup=$(@($script:asked).Count)|$(Test-Path "$Stick\autounattend.xml")"
# a folder
$script:answer = $true
Invoke-AkariUnattendFolder
"folder=$(Test-Path "$Folder\autounattend.xml")|$script:opened"
# his site's files open, and the form saves the very same files again
foreach ($n in '4-pe-gpt', '3-builtin', '10-explorer', '11-system', '12-custom', '13-performance', '14-appearance', '15-bloatware', '16-scripts', '17-applocker-components', '2-unattended') {
    $script:pick = "$Root\..\tests\Fixtures\Unattend\$n.xml"
    Invoke-AkariUnattendOpen
    $ours = [Text.Encoding]::ASCII.GetString((New-AkariUnattend (Get-AkariUaFormFields)))
    "same-$n=$((Canon $ours) -eq (Canon ([IO.File]::ReadAllText($script:pick))))"
}
"opened=$((Box 'WifiName').Text)|$((Box 'UseKeyboard3').IsChecked)|$(@($script:UaAccountRows | Where-Object { $_.Visibility -eq 'Visible' }).Count)"
$script:pick = "$Usb\..\unattend.ps1"
Invoke-AkariUnattendOpen
"notOurs=$($script:told.Substring(0, 31))"
# reset
$script:UnattendView = $null
"reset=$((Get-AkariUaFormFields).WifiMode)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Usb $usb -Stick $stick -Folder $folder 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0 -and $l -match '^[a-z-0-9]+=') { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'opens full window with Back only, his sections built' { $out.page | Should Be 'Install USB|Collapsed|Visible|True' }
    It 'starts from the defaults and this PC; hidden branches are left out' {
        $out.start | Should Be 'Unattended|it-IT|00000410|W. Europe Standard Time|Admin|Default|False|False'
        $out.samples | Should Be 'False|SELECT DISK=0'
        $out.rows | Should Be '2'
    }
    It 'shows a picked branch and counts its fields; hides it again' {
        $out.branch | Should Be 'Visible|Unattended'
        $out.hidden | Should Be 'Collapsed|False'
    }
    It 'asks before saving a file that wipes a disk' { $out.wipe | Should Be '1|This file wipes a disk without as|False' }
    It 'shows the generator''s check and saves nothing' { $out.noAdmin | Should Be 'Must have at least one administrator account.|False' }
    It 'saves to the setup drive without asking, opens it, and the file reads back' { $out.saved | Should Be "|$usb\|0|Admin|it-IT" }
    It 'asks before a drive without Windows setup' { $out.noSetup | Should Be '1|False' }
    It 'saves to a folder' { $out.folder | Should Be "True|$folder" }
    It 'opens files from his site and saves the very same files' {
        $out['same-2-unattended'] | Should Be 'True'
        $out['same-4-pe-gpt'] | Should Be 'True'
        $out['same-3-builtin'] | Should Be 'True'
        foreach ($n in '10-explorer', '11-system', '12-custom', '13-performance', '14-appearance', '15-bloatware', '16-scripts', '17-applocker-components') { "$n=$($out["same-$n"])" | Should Be "$n=True" }
    }
    It 'fills the form from the file: Wi-Fi, the third language, both accounts and an empty row' { $out.opened | Should Be 'Home & Co|True|3' }
    It 'says so for a file it can''t read' { $out.notOurs | Should Be "This file wasn't made by Akari " }
}
