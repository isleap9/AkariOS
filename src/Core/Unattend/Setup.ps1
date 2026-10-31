# Unattend Generator: the setup modifiers, ported from Schneegans' modifier\*.cs (MIT; see Engine.ps1): accessibility, computer
# name, bypasses, product key, locales, users, express settings, Wi-Fi, empty elements, lockout, password expiration,
# time zone, the four script sequences, sensitive files, order, processor architectures, pretty.

function Invoke-AkariUaAccessibility($C) {
    if (-not (Test-AkariUaOn $C 'UseNarrator')) { return }
    Add-AkariUaCommand $C 'WindowsPE' (Get-AkariUaShell 'start X:\Windows\System32\Narrator.exe')
    $C.Specialize.Commands.Add("& 'C:\Windows\System32\Narrator.exe';`r`nreg.exe ADD `"HKLM\Software\Microsoft\Windows NT\CurrentVersion\Accessibility`" /v Configuration /t REG_SZ /d narrator /f;")
    $C.UserOnce.Commands.Add("& 'C:\Windows\System32\Narrator.exe';`r`nreg.exe ADD `"HKCU\Software\Microsoft\Windows NT\CurrentVersion\Accessibility`" /v Configuration /t REG_SZ /d narrator /f;")
}

# his computer name rules: $null when fine, else why not
function Test-AkariUaComputerName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 15 -or $Name -match '\s' -or $Name -match '^[0-9]+$' -or
        $Name.IndexOfAny("{|}~[\]^':;<=>?@!`"#`$%``()+/.,*&".ToCharArray()) -gt -1) { return "Computer name '$Name' is invalid." }
    $null
}

function Invoke-AkariUaComputerName($C) {
    $set = { param($v) [void](New-AkariUaSimple $C 'ComputerName' (Get-AkariUaComponent $C 'specialize' 'Microsoft-Windows-Shell-Setup') $v) }
    switch (Get-AkariUaField $C 'ComputerNameMode' 'Random') {
        'Custom' {
            $n = Get-AkariUaField $C 'ComputerName'
            if (Test-AkariUaComputerName $n) { throw (Test-AkariUaComputerName $n) }
            & $set $n
        }
        { $_ -in 'Script', 'Prompt' } {
            & $set 'TEMPNAME'
            $script = if ($_ -eq 'Prompt') { Get-AkariUaResource 'ComputerNamePrompt.ps1' } else { Get-AkariUaField $C 'ComputerNameScript' }
            $getter = Add-AkariUaTextFile $C 'GetComputerName.ps1' $script
            $setter = Add-AkariUaTextFile $C 'SetComputerName.ps1' (Get-AkariUaResource 'SetComputerName.ps1')
            $C.Specialize.Commands.Add(@"
[string] `$newName = & '$getter';
`$newName > 'C:\Windows\Setup\Scripts\ComputerName.txt';
"Will set the computer name to '`${newName}'.";
Start-Process -FilePath ( Get-Process -Id `$PID ).Path -ArgumentList '-ExecutionPolicy "Unrestricted" -NoProfile -File "$setter"' -WindowStyle 'Hidden';
Start-Sleep -Seconds 10;
"@)
        }
    }
}

function Invoke-AkariUaBypass($C) {
    if ($C.PEMode -eq 'Default' -and (Test-AkariUaOn $C 'BypassRequirementsCheck')) {
        foreach ($v in 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck') {
            Add-AkariUaCommand $C 'WindowsPE' (Get-AkariUaReg "add `"HKLM\SYSTEM\Setup\LabConfig`" /v $v /t REG_DWORD /d 1 /f")
        }
    }
    if (Test-AkariUaOn $C 'BypassNetworkCheck') {
        $C.Specialize.Commands.Add('reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f;')
    }
}

function Test-AkariUaProductKey([string]$Key) { $Key -match '^([A-Z0-9]{5}-){4}[A-Z0-9]{5}$' }

function Invoke-AkariUaProductKey($C) {
    $key = Select-AkariUaNode $C.Doc '//u:UserData/u:ProductKey/u:Key' $C.Ns
    $ui = Select-AkariUaNode $C.Doc '//u:UserData/u:ProductKey/u:WillShowUI' $C.Ns
    $mode = Get-AkariUaField $C 'WindowsEditionMode' 'Interactive'
    if ($C.PEMode -eq 'Default') {
        switch ($mode) {
            'Generic' { $key.InnerText = (Get-AkariUaItem 'WindowsEdition' (Get-AkariUaField $C 'WindowsEdition')).ProductKey; $ui.InnerText = 'OnError' }
            'Custom' {
                $k = Get-AkariUaField $C 'ProductKey'
                if (-not (Test-AkariUaProductKey $k)) { throw "Product key '$k' is ill-formed." }
                $key.InnerText = $k.ToUpperInvariant(); $ui.InnerText = 'OnError'
            }
            'Firmware' { Remove-AkariUaNode $key; $ui.InnerText = 'Never' }
            default { $key.InnerText = '00000-00000-00000-00000-00000'; $ui.InnerText = 'Always' }
        }
    }
    # the key that activates Windows: the activation key, else the edition's own key
    $activate = if (Test-AkariUaOn $C 'UseActivationKey') { Get-AkariUaField $C 'ActivationKey' }
                elseif ($C.PEMode -eq 'Default' -and $mode -eq 'Custom') { Get-AkariUaField $C 'ProductKey' }
    if ($activate) {
        if (-not (Test-AkariUaProductKey $activate)) { throw "Product key '$activate' is ill-formed." }
        (Get-AkariUaComponentChild $C 'specialize' 'Microsoft-Windows-Shell-Setup' 'ProductKey').InnerText = $activate.ToUpperInvariant()
    }
}

# the language settings when set in the file: @{ Image; Pairs = @(@{ Locale; Keyboard } x 1-3); Geo }, else $null
function Get-AkariUaLanguage($C) {
    if ((Get-AkariUaField $C 'LanguageMode' 'Interactive') -ne 'Unattended') { return $null }
    $pairs = @(@{ Locale = Get-AkariUaItem 'UserLocale' (Get-AkariUaField $C 'Locale'); Keyboard = Get-AkariUaItem 'KeyboardIdentifier' (Get-AkariUaField $C 'Keyboard') })
    foreach ($n in 2, 3) {
        if (Test-AkariUaOn $C "UseKeyboard$n") { $pairs += @{ Locale = Get-AkariUaItem 'UserLocale' (Get-AkariUaField $C "Locale$n"); Keyboard = Get-AkariUaItem 'KeyboardIdentifier' (Get-AkariUaField $C "Keyboard$n") } }
    }
    @{ Image = Get-AkariUaItem 'ImageLanguage' (Get-AkariUaField $C 'UILanguage'); Pairs = $pairs; Geo = Get-AkariUaItem 'GeoId' (Get-AkariUaField $C 'GeoLocation') }
}

function Invoke-AkariUaLocales($C) {
    $pe = Select-AkariUaNode $C.Doc "//u:component[@name = 'Microsoft-Windows-International-Core-WinPE']" $C.Ns
    $oobe = Select-AkariUaNode $C.Doc "//u:component[@name = 'Microsoft-Windows-International-Core']" $C.Ns
    $s = Get-AkariUaLanguage $C
    if (-not $s) { Remove-AkariUaNode $pe; Remove-AkariUaNode $oobe; return }
    $keyboards = @(foreach ($p in $s.Pairs) {
        if ($p.Keyboard.Type -eq 'IME') { $p.Keyboard.Id }
        elseif ($p.Locale.LCID -eq '1000') {
            # a locale with no LCID of its own: the image language's, else the pair's
            $all = Get-AkariUaList 'UserLocale'
            $found = @($all | Where-Object { $_.Id -eq $s.Image.Id })[0]
            if (-not $found -and $s.Image.Id -eq 'zh-CN') { $found = @($all | Where-Object { $_.Id -eq 'zh' })[0] }
            if (-not $found -and $s.Image.Id -eq 'zh-TW') { $found = @($all | Where-Object { $_.Id -eq 'zh-Hant' })[0] }
            if (-not $found) { $found = $p.Locale }
            "$($found.LCID):$($p.Keyboard.Id)"
        } else { "$($p.Locale.LCID):$($p.Keyboard.Id)" }
    }) -join ';'
    (Select-AkariUaNode $pe 'u:UILanguage' $C.Ns).InnerText = $s.Image.Id
    (Select-AkariUaNode $oobe 'u:InputLocale' $C.Ns).InnerText = $keyboards
    (Select-AkariUaNode $oobe 'u:SystemLocale' $C.Ns).InnerText = $s.Pairs[0].Locale.Id
    (Select-AkariUaNode $oobe 'u:UserLocale' $C.Ns).InnerText = $s.Pairs[0].Locale.Id
    (Select-AkariUaNode $oobe 'u:UILanguage' $C.Ns).InnerText = $s.Image.Id
    if ($s.Geo.Id -ne $s.Pairs[0].Locale.GeoLocation) { $C.UserOnce.Commands.Add("Set-WinHomeLocation -GeoId $($s.Geo.Id);") }
}

# his user name rules: $null when fine, else why not
function Test-AkariUaUserName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -ne $Name.Trim() -or $Name.Length -gt 20 -or
        $Name.IndexOfAny('/\[]:;|=,+*?<>"%'.ToCharArray()) -gt -1 -or $Name.EndsWith('.') -or
        $Name -in 'administrator', 'guest', 'defaultaccount', 'system', 'network service', 'local service', 'none', 'wdagutilityaccount') { return "Username '$Name' is invalid." }
    $null
}

# the accounts of the form (rows 0-14 with a name): @(@{ Name; DisplayName; Password; Group })
function Get-AkariUaAccounts($C) {
    @(foreach ($i in 0..14) {
        $n = Get-AkariUaField $C "AccountName$i"
        if ($n) { @{ Name = $n; DisplayName = Get-AkariUaField $C "AccountDisplayName$i"; Password = Get-AkariUaField $C "AccountPassword$i"; Group = Get-AkariUaField $C "AccountGroup$i" 'Users' } }
    })
}

function Invoke-AkariUaUsers($C) {
    $logon = Select-AkariUaNode $C.Doc '//u:AutoLogon' $C.Ns
    $accountsNode = Select-AkariUaNode $C.Doc '//u:UserAccounts' $C.Ns
    $mode = Get-AkariUaField $C 'UserAccountMode' 'Interactive'
    if ($mode -ne 'Unattended') {
        Remove-AkariUaNode $logon; Remove-AkariUaNode $accountsNode
        if ($mode -eq 'InteractiveLocal') { (Select-AkariUaNode $C.Doc '//u:HideOnlineAccountScreens' $C.Ns).InnerText = 'true' }
        return
    }
    $accounts = Get-AkariUaAccounts $C
    $auto = Get-AkariUaField $C 'AutoLogonMode' 'None'
    $obscure = Test-AkariUaOn $C 'ObscurePasswords'
    foreach ($a in $accounts) { if (Test-AkariUaUserName $a.Name) { throw (Test-AkariUaUserName $a.Name) } }
    $dup = @($accounts | Group-Object { $_.Name.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 } | ForEach-Object { "'$($_.Group[0].Name)'" })
    if ($dup) { throw "Account name(s) $($dup -join ', ') specified more than once." }
    if ($auto -ne 'Builtin' -and -not @($accounts | Where-Object { $_.Group -eq 'Administrators' }).Count) { throw 'Must have at least one administrator account.' }
    if ((Get-AkariUaField $C 'ComputerNameMode') -eq 'Custom') {
        foreach ($a in $accounts) { if ($a.Name -eq (Get-AkariUaField $C 'ComputerName')) { throw "Account name '$($a.Name)' must not be the same as the computer name." } }
    }
    $password = {
        param($parent, $element, $value)
        $e = New-AkariUaElement $C $element $parent
        if ($obscure) { $value = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("$value$element")) }
        [void](New-AkariUaSimple $C 'Value' $e $value)
        [void](New-AkariUaSimple $C 'PlainText' $e $(if ($obscure) { 'false' } else { 'true' }))
    }
    if ($auto -ne 'None') {
        $user, $pw = if ($auto -eq 'Builtin') { 'Administrator', (Get-AkariUaField $C 'BuiltinAdministratorPassword') }
                     else { $first = @($accounts | Where-Object { $_.Group -eq 'Administrators' })[0]; $first.Name, $first.Password }
        [void](New-AkariUaSimple $C 'Username' $logon $user)
        [void](New-AkariUaSimple $C 'Enabled' $logon 'true')
        [void](New-AkariUaSimple $C 'LogonCount' $logon '1')
        & $password $logon 'Password' $pw
        $C.FirstLogon.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;")
    }
    if ($auto -eq 'Builtin') { & $password $accountsNode 'AdministratorPassword' (Get-AkariUaField $C 'BuiltinAdministratorPassword') }
    $local = New-AkariUaElement $C 'LocalAccounts' $accountsNode
    foreach ($a in $accounts) {
        $la = New-AkariUaElement $C 'LocalAccount' $local
        [void]$la.SetAttribute('action', $C.Ns.LookupNamespace('wcm'), 'add')
        [void](New-AkariUaSimple $C 'Name' $la $a.Name)
        [void](New-AkariUaSimple $C 'DisplayName' $la $a.DisplayName)
        [void](New-AkariUaSimple $C 'Group' $la $a.Group)
        & $password $la 'Password' $a.Password
    }
}

function Invoke-AkariUaExpressSettings($C) {
    $e = Select-AkariUaNode $C.Doc '//u:OOBE/u:ProtectYourPC' $C.Ns
    switch (Get-AkariUaField $C 'ExpressSettings' 'DisableAll') { 'Interactive' { Remove-AkariUaNode $e } 'EnableAll' { $e.InnerText = '1' } default { $e.InnerText = '3' } }
}

# the Wi-Fi profile for the Unattended mode (ParameterizedWifiSettings.ProfileXml), connecting automatically
function New-AkariUaWifiProfile([string]$Name, [string]$Password, [string]$Auth, [bool]$NonBroadcast) {
    $doc = [xml]::new(); $doc.Load((Join-Path $AkariUaData 'WLANProfile.xml'))
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable); $ns.AddNamespace('w', 'http://www.microsoft.com/networking/WLAN/profile/v1')
    $n = { param($x) Select-AkariUaNode $doc $x $ns }
    (& $n '/w:WLANProfile/w:name').InnerText = $Name
    (& $n '/w:WLANProfile/w:SSIDConfig/w:SSID/w:name').InnerText = $Name
    (& $n '/w:WLANProfile/w:SSIDConfig/w:SSID/w:hex').InnerText = -join ([Text.Encoding]::UTF8.GetBytes($Name) | ForEach-Object { $_.ToString('X2') })
    (& $n '/w:WLANProfile/w:connectionType').InnerText = 'ESS'
    (& $n '/w:WLANProfile/w:connectionMode').InnerText = 'auto'
    $addHidden = { if ($NonBroadcast) { $e = $doc.CreateElement('nonBroadcast', $ns.LookupNamespace('w')); $e.InnerText = 'true'; [void](& $n '/w:WLANProfile/w:SSIDConfig').AppendChild($e) } }
    $setAuth = { param($a, $enc) (& $n '/w:WLANProfile/w:MSM/w:security/w:authEncryption/w:authentication').InnerText = $a; (& $n '/w:WLANProfile/w:MSM/w:security/w:authEncryption/w:encryption').InnerText = $enc }
    switch ($Auth) {
        'Open' { & $setAuth 'open' 'none'; & $addHidden; Remove-AkariUaNode (& $n '/w:WLANProfile/w:MSM/w:security/w:sharedKey') }
        'WPA3SAE' {
            & $setAuth 'WPA3SAE' 'AES'; & $addHidden; (& $n '/w:WLANProfile/w:MSM/w:security/w:sharedKey/w:keyMaterial').InnerText = $Password
            $e = $doc.CreateElement('transitionMode', 'http://www.microsoft.com/networking/WLAN/profile/v4'); $e.InnerText = 'true'
            [void](& $n '/w:WLANProfile/w:MSM/w:security/w:authEncryption').AppendChild($e)
        }
        default { & $setAuth 'WPA2PSK' 'AES'; & $addHidden; (& $n '/w:WLANProfile/w:MSM/w:security/w:sharedKey/w:keyMaterial').InnerText = $Password }
    }
    $doc
}

function Invoke-AkariUaWifi($C) {
    $e = Select-AkariUaNode $C.Doc '//u:OOBE/u:HideWirelessSetupInOOBE' $C.Ns
    $mode = Get-AkariUaField $C 'WifiMode' 'Interactive'
    switch ($mode) {
        'Interactive' { $e.InnerText = 'false'; return }
        'Skip' { $e.InnerText = 'true'; return }
    }
    Remove-AkariUaNode $e
    if ($mode -eq 'FromProfile') {
        $profile = [xml]::new()
        try { $profile.LoadXml((Get-AkariUaField $C 'WifiProfileXml')) } catch { throw "WLAN profile XML is invalid: $($_.Exception.Message)" }
        $wns = [Xml.XmlNamespaceManager]::new($profile.NameTable); $wns.AddNamespace('w', 'http://www.microsoft.com/networking/WLAN/profile/v1')
        $mode = $profile.SelectSingleNode('/w:WLANProfile/w:connectionMode', $wns)
        $auto = $mode -and $mode.InnerText -eq 'auto'
        $name = (Select-AkariUaNode $profile '/w:WLANProfile/w:name' $wns).InnerText
    } else {
        $name = Get-AkariUaField $C 'WifiName'
        $profile = New-AkariUaWifiProfile $name (Get-AkariUaField $C 'WifiPassword') (Get-AkariUaField $C 'WifiAuthentication' 'WPA2PSK') (Test-AkariUaOn $C 'WifiNonBroadcast')
        $auto = $true
    }
    $file = Add-AkariUaXmlFile $C 'Wifi.xml' $profile
    $C.Specialize.Commands.Add(@'
$name = 'WlanSvc';
$start = [datetime]::Now;
$timeout = $start.AddMinutes( 1 );
$params = @{
  Id = 1;
  ParentId = 0;
  Activity = "Waiting for service '${name}' to start.";
};
while( $true ) {
	if( $service = Get-Service -Name $name -ErrorAction 'SilentlyContinue' ) {
		if( $service.Status -eq 'Running' ) {
			break;
		}
	}
	if( [datetime]::Now -gt $timeout ) {
		"Service '${name}' did not start in time." | Write-Warning;
		break;
	}
	Write-Progress @params -PercentComplete $(
		100 * ( [datetime]::Now - $start ).Ticks / ( $timeout - $start ).Ticks
	);
	Start-Sleep -Seconds 5;
}
Write-Progress @params -Completed;
'@)
    $C.Specialize.Commands.Add("netsh.exe wlan add profile filename=`"$file`" user=all;")
    if ($auto) { $C.Specialize.Commands.Add("netsh.exe wlan connect name=`"$name`" ssid=`"$name`";") }
}

# EmptyElements: drops every element with no children and no attributes, until none is left
function Invoke-AkariUaEmptyElements($C) {
    do {
        $modified = $false
        foreach ($n in @($C.Doc.SelectNodes('//*'))) {
            if (-not $n.HasChildNodes -and $n.Attributes.Count -eq 0) { Remove-AkariUaNode $n; $modified = $true }
        }
    } while ($modified)
}

function Get-AkariUaInt($C, [string]$Name, [int]$Min, [int]$Max) {
    $v = 0
    if (-not [int]::TryParse((Get-AkariUaField $C $Name), [ref]$v) -or $v -lt $Min -or $v -gt $Max) { throw "Value of '$Name' must be between $Min and $Max." }
    $v
}

function Invoke-AkariUaLockout($C) {
    switch (Get-AkariUaField $C 'LockoutMode' 'Default') {
        'Disabled' { $C.Specialize.Commands.Add('net.exe accounts /lockoutthreshold:0;') }
        'Custom' {
            $t = Get-AkariUaInt $C 'LockoutThreshold' 0 999; $d = Get-AkariUaInt $C 'LockoutDuration' 1 99999; $w = Get-AkariUaInt $C 'LockoutWindow' 1 99999
            if ($w -gt $d) { throw "Value of 'LockoutWindow' ($w) must be less than or equal to value of 'LockoutDuration' ($d)." }
            $C.Specialize.Commands.Add("net.exe accounts /lockoutthreshold:$t /lockoutduration:$d /lockoutwindow:$w;")
        }
    }
}

function Invoke-AkariUaPasswordExpiration($C) {
    switch (Get-AkariUaField $C 'PasswordExpirationMode' 'Default') {
        'Unlimited' { $C.Specialize.Commands.Add('net.exe accounts /maxpwage:UNLIMITED;') }
        'Custom' { $C.Specialize.Commands.Add("net.exe accounts /maxpwage:$(Get-AkariUaInt $C 'PasswordMaxAge' 1 999);") }
    }
}

function Invoke-AkariUaTimeZone($C) {
    if ((Get-AkariUaField $C 'TimeZoneMode' 'Implicit') -ne 'Explicit') { return }
    $tz = Get-AkariUaItem 'TimeOffset' (Get-AkariUaField $C 'TimeZone')
    [void](New-AkariUaSimple $C 'TimeZone' (Get-AkariUaComponent $C 'specialize' 'Microsoft-Windows-Shell-Setup') $tz.Id)
}

# the four sequences become embedded scripts: Specialize and DefaultUser run in specialize (the default user's hive
# loaded), UserOnce from the default user's RunOnce, FirstLogon at the first sign-in
function Invoke-AkariUaSpecialize($C) {
    if (-not $C.Specialize.Commands.Count) { return }
    Add-AkariUaCommand $C 'Specialize' (Get-AkariUaPowerShellFile $C (Add-AkariUaTextFile $C 'Specialize.ps1' (Get-AkariUaSequenceScript $C.Specialize)))
}
function Invoke-AkariUaUserOnce($C) {
    if (-not $C.UserOnce.Commands.Count) { return }
    $cmd = (Get-AkariUaPowerShellFile $C (Add-AkariUaTextFile $C 'UserOnce.ps1' (Get-AkariUaSequenceScript $C.UserOnce))).Replace('"', '\""')
    $C.DefaultUser.Commands.Add("reg.exe add `"HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"UnattendedSetup`" /t REG_SZ /d `"$cmd`" /f;")
}
function Invoke-AkariUaDefaultUser($C) {
    if (-not $C.DefaultUser.Commands.Count) { return }
    $file = Add-AkariUaTextFile $C 'DefaultUser.ps1' (Get-AkariUaSequenceScript $C.DefaultUser)
    Add-AkariUaCommand $C 'Specialize' @((Get-AkariUaReg 'load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"'), (Get-AkariUaPowerShellFile $C $file), (Get-AkariUaReg 'unload "HKU\DefaultUser"'))
}
function Invoke-AkariUaDelete($C) {
    if (Test-AkariUaOn $C 'KeepSensitiveFiles') { return }
    if ((Get-AkariUaField $C 'UserAccountMode') -eq 'Unattended' -and (Get-AkariUaField $C 'AutoLogonMode') -eq 'None') {
        throw 'To delete sensitive files, you must let Windows log on to an administrator account.'
    }
    $C.FirstLogon.Commands.Add(@"
Remove-Item -LiteralPath @(
  'C:\Windows\Panther\unattend.xml';
  'C:\Windows\Panther\unattend-original.xml';
  'C:\Windows\Setup\Scripts\Wifi.xml';
) -Force -ErrorAction 'SilentlyContinue' -Verbose;
"@)
}
function Invoke-AkariUaFirstLogon($C) {
    if (-not $C.FirstLogon.Commands.Count) { return }
    Add-AkariUaCommand $C 'Oobe' (Get-AkariUaPowerShellFile $C (Add-AkariUaTextFile $C 'FirstLogon.ps1' (Get-AkariUaSequenceScript $C.FirstLogon)))
}

# Order: numbers the commands of every RunSynchronous / RunAsynchronous / FirstLogonCommands (not in user-set components)
function Invoke-AkariUaOrder($C) {
    foreach ($container in @($C.Doc.SelectNodes('//u:RunSynchronous | //u:RunAsynchronous | //u:FirstLogonCommands', $C.Ns))) {
        if ($C.UserComponents -and $C.UserComponents.Contains($container.ParentNode)) { continue }
        $pos = 1
        foreach ($child in @($container.SelectNodes('*'))) {
            $o = $C.Doc.CreateElement('Order', $C.Ns.LookupNamespace('u'))
            $o.InnerText = "$pos"; $pos++
            [void]$child.PrependChild($o)
            [void]$child.SetAttribute('action', $C.Ns.LookupNamespace('wcm'), 'add')
        }
    }
}

# every component once per chosen processor architecture
function Invoke-AkariUaProcessorArchitecture($C) {
    $archs = @($C.Fields['ProcessorArchitecture'] | Where-Object { $_ })
    if (-not $archs.Count) { throw 'At least one processor architecture must be selected.' }
    foreach ($comp in @($C.Doc.SelectNodes('//*[@processorArchitecture]'))) {
        $comp.SetAttribute('processorArchitecture', $archs[0])
        # each copy goes right after the original (so with three, the last comes second, as in his code)
        for ($i = 1; $i -lt $archs.Count; $i++) {
            $copy = $comp.CloneNode($true); $copy.SetAttribute('processorArchitecture', $archs[$i])
            [void]$comp.ParentNode.InsertAfter($copy, $comp)
        }
    }
}

# Pretty: no self-closing tags, no whitespace-only text
function Invoke-AkariUaPretty($C) {
    foreach ($n in @($C.Doc.SelectNodes('//*'))) { $n.IsEmpty = $false }
    $C.Doc.Normalize()
    foreach ($n in @($C.Doc.SelectNodes('//text()'))) { if ($n -is [Xml.XmlWhitespace]) { Remove-AkariUaNode $n } }
}
