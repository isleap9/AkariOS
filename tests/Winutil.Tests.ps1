$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# winutil W3: the tweaks AkariOS lacked (docs/plans/2026-11-13-winutil.md). Every hive is redirected to
# HKCU:\Software\AkariTest\<guid> by mocking Resolve-AkariRegPath (HKEY_USERS too: Num Lock writes .DEFAULT).

Describe 'winutil W3 tweaks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Phases', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath {
        if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" }
        elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" }
        elseif ($Path -match '^Registry::HKEY_USERS\\(.*)$') { "$tk\HKU\$($Matches[1])" }
        else { throw "not redirected: $Path" }
    }
    Mock Restart-AkariExplorer { }
    Mock Get-AkariOSBuild { 26100 }
    Mock Get-AkariChassis { 'Laptop' }
    Mock Get-AkariEdition { 'Professional' }
    Mock Run-Trusted { }

    # id, file, Risk, Guided, Requires, Reboot, Explorer (the grilled spec)
    $spec = @(
        @('privacy-consumer-features', 'Optimize\Privacy\ConsumerFeatures.ps1', 'Safe', $false, '', $false, $false),
        @('apps-edge-debloat', 'Customize\Apps\EdgeDebloat.ps1', 'Safe', $false, '', $false, $false),
        @('apps-brave-debloat', 'Customize\Apps\BraveDebloat.ps1', 'Safe', $false, '', $false, $false),
        @('security-rdp-unsigned-warning', 'Advanced\Security\RdpUnsignedWarning.ps1', 'Caution', $false, '', $false, $false),
        @('system-utc-clock', 'Customize\System\UtcClock.ps1', 'Advanced', $false, '', $true, $false),
        @('notifications-no-center', 'Customize\Notifications\NoNotificationCenter.ps1', 'Caution', $false, '', $false, $true),
        @('taskbar-battery-percentage', 'Customize\Taskbar\BatteryPercentage.ps1', 'Safe', $true, 'Win11,Laptop', $false, $true),
        @('system-verbose-logon', 'Customize\System\VerboseLogon.ps1', 'Safe', $false, '', $false, $false),
        @('apps-classic-outlook', 'Customize\Apps\ClassicOutlook.ps1', 'Safe', $false, '', $false, $false),
        @('accessibility-scrollbars-visible', 'Customize\Accessibility\ScrollbarsVisible.ps1', 'Safe', $true, '', $false, $false),
        @('input-numlock-on', 'Customize\Input\NumLockOn.ps1', 'Safe', $true, '', $false, $false),
        @('system-snap-off', 'Customize\System\SnapOff.ps1', 'Safe', $false, '', $false, $false),
        @('power-standby-no-network', 'Optimize\Power\StandbyNoNetwork.ps1', 'Caution', $false, '', $false, $false),
        @('power-s3-sleep', 'Optimize\Power\S3Sleep.ps1', 'Advanced', $false, '', $true, $false),
        @('theme-no-lock-screen', 'Customize\Theme\NoLockScreen.ps1', 'Safe', $true, 'Pro', $false, $false),
        @('privacy-powershell-telemetry', 'Optimize\Privacy\PowerShellTelemetry.ps1', 'Safe', $false, '', $false, $false)
    )

    try {
        It 'redirects every hive (guard)' {
            Resolve-AkariRegPath 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' | Should Be "$tk\HKU\.DEFAULT\Control Panel\Keyboard"
            Resolve-AkariRegPath 'HKLM:\SYSTEM\Maps' | Should Be "$tk\HKLM\SYSTEM\Maps"
        }

        Context 'Registry Toggles' {
            foreach ($s in $spec) {
                $t = Load $s[1]
                It "$($s[0]) is where the plan puts it, credited to winutil, not AkariOS" {
                    $want = "$($s[0]) Toggle $($s[2]) Guided=$($s[3]) Requires=$($s[4]) Reboot=$($s[5]) Explorer=$($s[6]) AkariOS=False"
                    "$($t.Id) $($t.Kind) $($t.Risk) Guided=$($t.Guided) Requires=$(@($t.Requires) -join ',') Reboot=$([bool]$t.Reboot) Explorer=$([bool]$t.Explorer) AkariOS=$([bool]$t.AkariOS)" | Should Be $want
                    (Get-Content (Join-Path $Tw $s[1]) -TotalCount 1) | Should Match 'Chris Titus Tech''s winutil'
                }
                It "$($s[0]) round-trips to Windows' Default" {
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Get-AkariState $t | Should Be 'Default'
                }
            }

            It 'Num Lock writes the sign-in screen and the user, back to Windows'' 2147483648' {
                $t = Load 'Customize\Input\NumLockOn.ps1'
                [void](Invoke-AkariTweak $t Apply)
                (Get-ItemProperty -LiteralPath "$tk\HKU\.DEFAULT\Control Panel\Keyboard").InitialKeyboardIndicators | Should Be '2'
                (Get-ItemProperty -LiteralPath "$tk\Control Panel\Keyboard").InitialKeyboardIndicators | Should Be '2'
                [void](Invoke-AkariTweak $t Revert)
                (Get-ItemProperty -LiteralPath "$tk\HKU\.DEFAULT\Control Panel\Keyboard").InitialKeyboardIndicators | Should Be '2147483648'
                (Get-ItemProperty -LiteralPath "$tk\Control Panel\Keyboard").InitialKeyboardIndicators | Should Be '2147483648'
            }
            It 'standby network is the machine policy, AC and DC off' {
                $t = Load 'Optimize\Power\StandbyNoNetwork.ps1'
                [void](Invoke-AkariTweak $t Apply)
                $p = Get-ItemProperty -LiteralPath "$tk\HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9"
                "$($p.ACSettingIndex) $($p.DCSettingIndex)" | Should Be '0 0'
                [void](Invoke-AkariTweak $t Revert)
            }
            It 'classic Outlook keeps the user on classic' {
                $t = Load 'Customize\Apps\ClassicOutlook.ps1'
                [void](Invoke-AkariTweak $t Apply)
                (Get-ItemProperty -LiteralPath "$tk\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences").UseNewOutlook | Should Be 0
                (Get-ItemProperty -LiteralPath "$tk\Software\Microsoft\Office\16.0\Outlook\Options\General").HideNewOutlookToggle | Should Be 1
                [void](Invoke-AkariTweak $t Revert)
            }
            It 'scroll bars and snapping go back to Windows'' own values, not to nothing' {
                foreach ($p in @(@('Customize\Accessibility\ScrollbarsVisible.ps1', 'Control Panel\Accessibility', 'DynamicScrollbars', '1'),
                                 @('Customize\System\SnapOff.ps1', 'Control Panel\Desktop', 'WindowArrangementActive', '1'))) {
                    $t = Load $p[0]
                    [void](Invoke-AkariTweak $t Apply); [void](Invoke-AkariTweak $t Revert)
                    "$((Get-ItemProperty -LiteralPath "$tk\$($p[1])").($p[2]))" | Should Be $p[3]
                }
            }
        }
        Context 'IPv6 preference' {
            Mock Invoke-AkariNetsh { }
            $t = Load 'Optimize\Network\Ipv6Preference.ps1'
            $k = "$tk\HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
            It 'is a Choice in Optimize > Network, Prefer IPv4 recommended, Windows'' own Default, restart needed' {
                "$($t.Id) $($t.Kind) $($t.Risk) $($t.Guided) $($t.Reboot) $($t.Recommended) $($t.Default)" | Should Be 'network-ipv6-preference Choice Caution False True PreferIPv4 Default'
                @($t.Choices | ForEach-Object { $_.Value }) -join ',' | Should Be 'PreferIPv4,TunnelsOff,Both,Default'
            }
            It 'reads Windows'' Default when DisabledComponents is absent' { Get-AkariChoiceValue $t | Should Be 'Default' }
            foreach ($p in @(@('PreferIPv4', 32, 'default'), @('TunnelsOff', 1, 'disabled'), @('Both', 33, 'disabled'))) {
                It "$($p[0]) writes DisabledComponents $($p[1]), Teredo $($p[2]), and reads back" {
                    (Invoke-AkariTweak $t Apply $p[0]).Outcome | Should Be 'Applied'
                    (Get-ItemProperty -LiteralPath $k).DisabledComponents | Should Be $p[1]
                    $state = $p[2]
                    Assert-MockCalled Invoke-AkariNetsh -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq "interface teredo set state $state" }
                    Get-AkariChoiceValue $t | Should Be $p[0]
                }
            }
            It 'Revert removes the value and puts Teredo back to its default' {
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue).DisabledComponents | Should BeNullOrEmpty
                Assert-MockCalled Invoke-AkariNetsh -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq 'interface teredo set state default' }
                Get-AkariChoiceValue $t | Should Be 'Default'
            }
            It 'a value set by hand is none of its picks' {
                Set-ItemProperty -LiteralPath $k -Name DisabledComponents -Value 255 -Type DWord
                Get-AkariChoiceValue $t | Should BeNullOrEmpty
                Remove-ItemProperty -LiteralPath $k -Name DisabledComponents
            }
        }

        Context 'Get-AkariDenyRule and Set-AkariDenyRule (Core\System.ps1, on TestDrive files)' {
            $file = Join-Path (Get-Item 'TestDrive:\').FullName 'acl\store.db'
            [void][IO.Directory]::CreateDirectory((Split-Path $file)); [IO.File]::WriteAllText($file, 'x')
            It 'reads 0 with no deny rule, and for a missing path' {
                Get-AkariDenyRule $file | Should Be 0
                Get-AkariDenyRule "$file.missing" | Should Be 0
            }
            It 'denies Everyone the given rights on the item alone, and reads them back' {
                Set-AkariDenyRule $file 7
                Get-AkariDenyRule $file | Should Be 7
                $r = @((Get-Item -LiteralPath $file).GetAccessControl('Access').GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]) |
                    Where-Object { $_.AccessControlType -eq 'Deny' })
                "$($r.Count) $($r[0].IdentityReference.Value) $($r[0].InheritanceFlags)" | Should Be '1 S-1-1-0 None'
            }
            It 'replaces the rule, and 0 removes it' {
                Set-AkariDenyRule $file 278
                Get-AkariDenyRule $file | Should Be 278
                Set-AkariDenyRule $file 0
                Get-AkariDenyRule $file | Should Be 0
            }
        }

        Context 'Microsoft Store: no recommended search results' {
            $local = Join-Path (Get-Item 'TestDrive:\').FullName 'Local'
            $db = "$local\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
            Mock Get-AkariUserFolder { $local } -ParameterFilter { $Name -eq 'Local AppData' }
            $t = Load 'Customize\Apps\StoreNoSearchAds.ps1'
            It 'is a Caution Toggle in Customize > Apps' { "$($t.Id) $($t.Kind) $($t.Risk) $($t.Guided)" | Should Be 'apps-store-no-search-ads Toggle Caution False' }
            It 'is Unknown, and fails, while the Store has no search database' {
                Get-AkariState $t | Should Be 'Unknown'
                $o = Invoke-AkariTweak $t Apply
                "$($o.Outcome) $($o.Message)" | Should Match '^Failed .*Microsoft Store once'
            }
            It 'denies the database''s data to Everyone, then Revert lifts it' {
                [void][IO.Directory]::CreateDirectory((Split-Path $db)); [IO.File]::WriteAllText($db, 'x')
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariDenyRule $db | Should Be 7
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariDenyRule $db | Should Be 0
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Logitech Download Assistant block' {
            $pf = Join-Path (Get-Item 'TestDrive:\').FullName 'Program Files'
            $logi = "$pf\LogiDownloadAssistant"
            Mock Stop-Process { }
            $t = Load 'Optimize\Update\BlockLogitechAssistant.ps1'
            $realPf = $env:ProgramFiles
            try {
                $env:ProgramFiles = $pf
                It 'is a Toggle in Optimize > Update' { "$($t.Id) $($t.Kind) $($t.Risk) $($t.Guided)" | Should Be 'update-block-logitech-assistant Toggle Safe False' }
                It 'reads Default with no folder' { Get-AkariState $t | Should Be 'Default' }
                It 'stops the assistant, empties its folder and denies writing to it; Revert lifts the deny, the folder stays' {
                    [void][IO.Directory]::CreateDirectory("$logi\sub"); [IO.File]::WriteAllText("$logi\logi_download_assistant.exe", 'x')
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Assert-MockCalled Stop-Process -Exactly 1 -Scope It -ParameterFilter { "$Name" -eq 'logi_download_assistant' }
                    @(Get-ChildItem -LiteralPath $logi -Force).Count | Should Be 0
                    Get-AkariDenyRule $logi | Should Be 278
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Get-AkariDenyRule $logi | Should Be 0
                    Test-Path -LiteralPath $logi | Should Be $true
                    Get-AkariState $t | Should Be 'Default'
                }
                It 'makes the folder when Logitech''s software never did' {
                    Remove-Item -LiteralPath $logi -Recurse -Force
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Get-AkariDenyRule $logi | Should Be 278
                    [void](Invoke-AkariTweak $t Revert)
                }
            } finally { $env:ProgramFiles = $realPf }
        }

        Context 'Invoke-AkariDism and Get-AkariReservedStorage (Core\System.ps1)' {
            It 'Invoke-AkariDism lives in System.ps1, so tweak blocks and the CLI have it (the ISO Builder too)' {
                (Get-Command Invoke-AkariDism).ScriptBlock.File | Should Be (Join-Path $Core 'System.ps1')
            }
            It 'reads reserved storage''s state as DISM names it' {
                Mock Get-WindowsReservedStorageState { [pscustomobject]@{ ReservedStorageState = 'Disabled' } }
                Get-AkariReservedStorage | Should Be 'Disabled'
            }
            It 'reads nothing on a Windows that has no reserved storage' {
                Mock Get-WindowsReservedStorageState { throw 'not supported' }
                Get-AkariReservedStorage | Should BeNullOrEmpty
            }
        }

        Context 'Reserved storage off' {
            $t = Load 'Advanced\System\ReservedStorageOff.ps1'
            Mock Invoke-AkariDism { 0 }
            It 'is a Caution Toggle in Advanced > System that needs a restart' {
                "$($t.Id) $($t.Kind) $($t.Risk) $($t.Guided) $($t.Reboot)" | Should Be 'system-reserved-storage-off Toggle Caution False True'
            }
            It 'reads Disabled as Optimized, Enabled as Default, nothing as Unknown' {
                Mock Get-AkariReservedStorage { 'Disabled' }
                Get-AkariState $t | Should Be 'Optimized'
                Mock Get-AkariReservedStorage { 'Enabled' }
                Get-AkariState $t | Should Be 'Default'
                Mock Get-AkariReservedStorage { }
                Get-AkariState $t | Should Be 'Unknown'
            }
            It 'turns it off through DISM, and Revert turns it back on' {
                Mock Get-AkariReservedStorage { 'Enabled' }
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariDism -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq '/Online /Set-ReservedStorageState /State:Disabled' }
                Mock Get-AkariReservedStorage { 'Disabled' }
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Invoke-AkariDism -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq '/Online /Set-ReservedStorageState /State:Enabled' }
            }
            It 'fails saying why when DISM refuses (an update in progress)' {
                Mock Get-AkariReservedStorage { 'Enabled' }
                Mock Invoke-AkariDism { -2146498187 }
                $o = Invoke-AkariTweak $t Apply
                "$($o.Outcome) $($o.Message)" | Should Be 'Failed DISM could not change reserved storage (0x800F0975): let Windows Update finish, restart, then try again.'
            }
        }

        Context 'Component store cleanup' {
            $t = Load 'Tools\Cleanup\ComponentCleanup.ps1'
            It 'is a Tools > Cleanup Action that asks first' {
                "$($t.Id) $($t.Kind) $($t.Button) $($t.Risk)" | Should Be 'tools-component-cleanup Action Run Caution'
                $t.Confirm | Should Match 'uninstall'
            }
            It 'runs DISM''s component cleanup with ResetBase; 3010 is fine' {
                Mock Invoke-AkariDism { 3010 }
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariDism -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' }
            }
            It 'fails with DISM''s exit code' {
                Mock Invoke-AkariDism { 5 }
                $o = Invoke-AkariTweak $t Apply
                "$($o.Outcome) $($o.Message)" | Should Be 'Failed DISM''s component cleanup failed (0x00000005).'
            }
        }

        Context 'DNS server' {
            $t = Load 'Optimize\Network\Dns.ps1'
            $g1 = '{11111111-1111-1111-1111-111111111111}'; $g2 = '{22222222-2222-2222-2222-222222222222}'
            $ifs = "$tk\HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            $doh = "$tk\HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters"
            Mock Get-AkariDnsAdapters { [pscustomobject]@{ Index = 12; Name = 'Ethernet'; Guid = $g1 }; [pscustomobject]@{ Index = 7; Name = 'Wi-Fi'; Guid = $g2 } }
            Mock Invoke-AkariNetsh { }
            Mock Clear-AkariDnsCache { }
            function Static($guid, $servers) { [void](New-Item -Path "$ifs\$guid" -Force); Set-ItemProperty -LiteralPath "$ifs\$guid" -Name NameServer -Value $servers }

            It 'is a Choice in Optimize > Network: winutil''s providers, Cloudflare recommended, automatic as Windows has it' {
                "$($t.Id) $($t.Kind) $($t.Risk) $($t.Guided) $($t.Recommended) $($t.Default)" | Should Be 'network-dns Choice Caution False Cloudflare Default'
                @($t.Choices | ForEach-Object { $_.Value }) -join ',' | Should Be 'Cloudflare,CloudflareMalware,CloudflareFamily,Google,Quad9,OpenDns,AdGuard,AdGuardFamily,Default'
            }
            It 'has every provider''s four addresses and DoH template in Dns.psd1, and no other' {
                $p = (Import-PowerShellDataFile "$Tw\Optimize\Network\Files\Dns.psd1").Providers
                (@($p.Keys | Sort-Object) -join ',') | Should Be 'AdGuard,AdGuardFamily,Cloudflare,CloudflareFamily,CloudflareMalware,Google,OpenDns,Quad9'
                foreach ($k in $p.Keys) { "$k $(@('Primary', 'Secondary', 'Primary6', 'Secondary6', 'Doh' | Where-Object { -not $p[$k][$_] }).Count)" | Should Be "$k 0" }
                "$($p.Cloudflare.Primary) $($p.Cloudflare.Secondary6) $($p.Quad9.Doh)" | Should Be '1.1.1.1 2606:4700:4700::1001 https://dns.quad9.net/dns-query'
            }
            It 'reads automatic (no static servers) as Windows'' Default' { Get-AkariChoiceValue $t | Should Be 'Default' }
            It 'reads the provider every adapter''s static IPv4 servers are, else none of them' {
                Static $g1 '1.1.1.1,1.0.0.1'; Static $g2 '1.1.1.1 1.0.0.1'
                Get-AkariChoiceValue $t | Should Be 'Cloudflare'
                Static $g2 '8.8.8.8,8.8.4.4'
                Get-AkariChoiceValue $t | Should BeNullOrEmpty
                Get-AkariState $t | Should Be 'Custom'
                Remove-Item -LiteralPath $ifs -Recurse
            }
            It 'sets each adapter''s IPv4 and IPv6 servers, registers the DoH template and turns DoH on for the adapter (Windows 11)' {
                $o = Invoke-AkariTweak $t Apply 'Quad9'
                "$($o.Outcome) $($o.Message)" | Should Be 'Applied '
                foreach ($c in 'interface ipv4 set dnsservers name=12 source=static address=9.9.9.9 register=primary validate=no',
                    'interface ipv4 add dnsservers name=12 address=149.112.112.112 index=2 validate=no',
                    'interface ipv6 set dnsservers name=7 source=static address=2620:fe::fe register=primary validate=no',
                    'interface ipv6 add dnsservers name=7 address=2620:fe::9 index=2 validate=no',
                    'dns delete encryption server=2620:fe::9',
                    'dns add encryption server=9.9.9.9 dohtemplate=https://dns.quad9.net/dns-query autoupgrade=yes udpfallback=yes') {
                    Assert-MockCalled Invoke-AkariNetsh -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq $c }
                }
                Assert-MockCalled Invoke-AkariNetsh -Exactly 16 -Scope It
                (Get-ItemProperty -LiteralPath "$doh\$g1\DohInterfaceSettings\Doh\9.9.9.9").DohFlags | Should Be 1
                (Get-ItemProperty -LiteralPath "$doh\$g2\DohInterfaceSettings\Doh6\2620:fe::9").DohFlags | Should Be 1
                Assert-MockCalled Clear-AkariDnsCache -Exactly 1 -Scope It
            }
            It 'Revert puts every adapter back on DHCP and removes the DoH of every provider''s addresses and the adapters'' DoH settings' {
                Static $g1 '9.9.9.9,149.112.112.112'; Static $g2 '9.9.9.9,149.112.112.112'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Invoke-AkariNetsh -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq 'interface ipv4 set dnsservers name=12 source=dhcp' }
                Assert-MockCalled Invoke-AkariNetsh -Exactly 1 -Scope It -ParameterFilter { "$Arguments" -eq 'interface ipv6 set dnsservers name=7 source=dhcp' }
                Assert-MockCalled Invoke-AkariNetsh -Exactly 32 -Scope It -ParameterFilter { "$Arguments" -like 'dns delete encryption server=*' }
                Assert-MockCalled Invoke-AkariNetsh -Exactly 36 -Scope It
                Test-Path -LiteralPath "$doh\$g1\DohInterfaceSettings" | Should Be $false
                Remove-Item -LiteralPath $ifs -Recurse
            }
            It 'sets plain DNS on Windows 10 (no DoH there)' {
                Mock Get-AkariOSBuild { 19045 }
                (Invoke-AkariTweak $t Apply 'Google').Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariNetsh -Exactly 8 -Scope It
                Assert-MockCalled Invoke-AkariNetsh -Exactly 0 -Scope It -ParameterFilter { "$Arguments" -like 'dns *' }
            }
            # last: a Mock made in an It stays for the rest of the Context (Pester 3)
            It 'is Unknown, and fails, with no physical adapter' {
                Mock Get-AkariDnsAdapters { }
                Get-AkariState $t | Should Be 'Unknown'
                $o = Invoke-AkariTweak $t Apply 'Google'
                "$($o.Outcome) $($o.Message)" | Should Be 'Failed no physical network adapter'
            }
        }

        Context 'O&O ShutUp10++' {
            Mock Open-AkariWingetTool { }
            It 'is a Tools Check button that opens the tool, installed through winget when missing' {
                $t = Load 'Tools\Check\OoShutUp10.ps1'
                "$($t.Id) $($t.Section) $($t.Category) $($t.Kind) $($t.Button) $([bool]$t.AkariOS)" | Should Be 'tools-oosu10 Tools Check Action Check False'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Open-AkariWingetTool -Exactly 1 -Scope It -ParameterFilter { $Id -eq 'OO-Software.ShutUp10' -and $Exe -eq 'OOSU10.exe' }
            }
        }
    } finally {
        Remove-Item -LiteralPath $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}
