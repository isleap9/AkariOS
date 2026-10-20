$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# The Optimize / Customize tweaks of Tasks 5 and 6 that run code, against HKCU:\Software\AkariTest\<guid> and TestDrive
# only. Both hives are redirected by mocking Resolve-AkariRegPath; powercfg, Run-Trusted, services, network bindings,
# scheduled tasks, the C# compiler and file deletes are mocked (AGENTS.md rule 12). Each test checks its redirect.

Describe 'Optimize: tweaks that run code' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup') { . "$Core\$f.ps1" }
    function Run-Trusted([string]$command) { }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Run-Trusted { }
    Mock Invoke-AkariPowerCfg { }
    Mock Stop-Service { }
    Mock Start-Service { }
    Mock Restart-AkariExplorer { }
    $realSystemRoot = $env:SystemRoot

    try {
        It 'redirects both hives (guard)' {
            Resolve-AkariRegPath 'HKLM:\SYSTEM\ControlSet001\Enum\USB' | Should Be "$tk\HKLM\SYSTEM\ControlSet001\Enum\USB"
            Resolve-AkariRegPath 'HKCU:\Software\X' | Should Be "$tk\Software\X"
        }

        Context 'Block app permissions' {
            $t = Load 'Optimize\Privacy\AppPermissions.ps1'
            It 'denies the permissions, then resets Windows'' permission database through Run-Trusted, both ways' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts").Value | Should Be 'Deny'
                Assert-MockCalled Run-Trusted -Exactly 1 -Scope It -ParameterFilter { $command -like '*CapabilityConsentStorage.db*' }
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary").Value | Should Be 'Allow'
                Assert-MockCalled Run-Trusted -Exactly 2 -Scope It
            }
        }

        Context 'No scheduled drive optimization' {
            Mock Get-ScheduledTask { [pscustomobject]@{ TaskName = 'ScheduledDefrag'; TaskPath = '\Microsoft\Windows\Defrag\' }; [pscustomobject]@{ TaskName = 'Other'; TaskPath = '\' } }
            Mock Disable-ScheduledTask { }
            Mock Enable-ScheduledTask { }
            $t = Load 'Optimize\Performance\DefragSchedule.ps1'
            It 'disables the defrag task on Apply and enables it on Revert, after the values' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Disable-ScheduledTask -Exactly 1 -Scope It
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Enable-ScheduledTask -Exactly 1 -Scope It
            }
        }

        Context 'Game Bar presence writer' {
            $t = Load 'Optimize\Gaming\PresenceWriter.ps1'
            $p = "$tk\HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter"
            It 'writes through Run-Trusted and reads the value back' {
                Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter' 'ActivationType' 1
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Run-Trusted -Exactly 1 -Scope It -ParameterFilter { $command -like '*ActivationType*/d 0*' }
                Set-ItemProperty $p 'ActivationType' 0
                Get-AkariState $t | Should Be 'Optimized'
            }
        }

        Context 'Ultimate Performance power plan' {
            Mock Invoke-AkariPowerCfg { if ($Arguments[0] -eq '/list') { 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)'; 'Power Scheme GUID: 99999999-9999-9999-9999-999999999999  (Ultimate Performance) *' } elseif ($Arguments[0] -eq '/getactivescheme') { 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)' } }
            $t = Load 'Optimize\Power\UltimatePlan.ps1'
            It 'imports and activates the plan, deletes the other plans only, sets 36 settings AC and DC' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq '/duplicatescheme' -and $Arguments[2] -eq '99999999-9999-9999-9999-999999999999' }
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq '/delete' }
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 0 -Scope It -ParameterFilter { $Arguments[0] -eq '/delete' -and $Arguments[1] -like '9999*' }
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 36 -Scope It -ParameterFilter { $Arguments[0] -eq '/setacvalueindex' }
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 36 -Scope It -ParameterFilter { $Arguments[0] -eq '/setdcvalueindex' }
                (Get-ItemProperty "$tk\HKLM\SYSTEM\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583").Attributes | Should Be 0
            }
        }

        Context 'Ultimate Performance power plan, active' {
            Mock Invoke-AkariPowerCfg { if ($Arguments[0] -eq '/getactivescheme') { 'Power Scheme GUID: 99999999-9999-9999-9999-999999999999  (Ultimate Performance)' } }
            $t = Load 'Optimize\Power\UltimatePlan.ps1'
            It 'reads the active plan, and Revert restores Windows'' plans' {
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq '/restoredefaultschemes' }
            }
        }

        Context 'Hibernate off' {
            $t = Load 'Optimize\Power\Hibernate.ps1'
            It 'turns hibernation off through powercfg and the registry, and back on' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq '/hibernate' -and $Arguments[1] -eq 'off' }
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Invoke-AkariPowerCfg -Exactly 1 -Scope It -ParameterFilter { $Arguments[1] -eq 'on' }
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'No sign-in after sleep: reading the setting' {
            $t = Load 'Optimize\Power\SignInAfterSleep.ps1'
            It 'reads the AC and DC indexes from powercfg in any language' {
                Mock Invoke-AkariPowerCfg { '  Indice impostazione corrente alimentazione CA: 0x00000000'; '  Indice impostazione corrente alimentazione CC: 0x00000000' }
                Get-AkariState $t | Should Be 'Optimized'
                Mock Invoke-AkariPowerCfg { 'Current AC Power Setting Index: 0x00000001'; 'Current DC Power Setting Index: 0x00000001' }
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Device power saving and wake' {
            $t = Load 'Optimize\Power\DevicePowerSaving.ps1'
            $usb = "$tk\HKLM\SYSTEM\ControlSet001\Enum\USB\VID_1\1"
            New-Item "$usb\Device Parameters\WDF" -Force | Out-Null
            New-Item "$tk\HKLM\SYSTEM\ControlSet001\Enum\HID\VID_2\1\Device Parameters" -Force | Out-Null
            It 'turns power saving and wake off on every device found, and Revert removes the values' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$usb\Device Parameters").WaitWakeEnabled | Should Be 0
                (Get-ItemProperty "$usb\Device Parameters\WDF").IdleInWorkingState | Should Be 0
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty "$usb\Device Parameters").WaitWakeEnabled | Should BeNullOrEmpty
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Network adapter power saving' {
            $t = Load 'Optimize\Power\NetworkAdapterPowerSaving.ps1'
            $cls = "$tk\HKLM\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            New-Item "$cls\0000", "$cls\0001", "$cls\Properties" -Force | Out-Null
            It 'sets every numbered adapter key (not Properties), and Revert removes the values' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$cls\0001").PnPCapabilities | Should Be 24
                (Get-ItemProperty -LiteralPath "$cls\0000").'*EEE' | Should Be '0'
                (Get-ItemProperty "$cls\Properties").PnPCapabilities | Should BeNullOrEmpty
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Write-cache buffer flushing' {
            $t = Load 'Optimize\Performance\WriteCacheFlushing.ps1'
            $dp = "$tk\HKLM\SYSTEM\ControlSet001\Enum\NVME\Disk1\1\Device Parameters"
            New-Item $dp -Force | Out-Null
            Set-ItemProperty (New-Item "$dp\Disk" -Force).PSPath 'UserWriteCacheSetting' 1
            It 'marks every disk power-protected, and Revert removes only that value' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$dp\Disk").CacheIsPowerProtected | Should Be 1
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty "$dp\Disk").CacheIsPowerProtected | Should BeNullOrEmpty
                (Get-ItemProperty "$dp\Disk").UserWriteCacheSetting | Should Be 1
            }
        }

        Context 'IPv4 only' {
            Mock Disable-NetAdapterBinding { }
            Mock Enable-NetAdapterBinding { }
            Mock Get-NetAdapterBinding { [pscustomobject]@{ Name = 'Ethernet'; Enabled = $true } }
            $t = Load 'Optimize\Network\IPv4Only.ps1'
            It 'disables the eight non-IPv4 bindings, IPv4 itself stays' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Disable-NetAdapterBinding -Exactly 8 -Scope It
                Assert-MockCalled Disable-NetAdapterBinding -Exactly 0 -Scope It -ParameterFilter { $ComponentID -eq 'ms_tcpip' }
            }
        }

        Context 'IPv4 only, applied' {
            Mock Enable-NetAdapterBinding { }
            Mock Get-NetAdapterBinding { [pscustomobject]@{ Name = 'Ethernet'; Enabled = $false } }
            $t = Load 'Optimize\Network\IPv4Only.ps1'
            It 'reads IPv6 off as Optimized, and Revert enables all nine bindings' {
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Enable-NetAdapterBinding -Exactly 9 -Scope It
            }
        }

        Context 'Timer resolution service' {
            $env:SystemRoot = "$TestDrive\Windows"
            Mock Invoke-AkariCsc { }
            Mock New-Service { }
            Mock Get-Service { }
            Mock Remove-AkariService { }
            Mock Start-Sleep { }
            $t = Load 'Optimize\Performance\TimerResolution.ps1'
            It 'compiles One-click''s service source, installs it and sets global timer requests; Revert removes it' {
                try {
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Assert-MockCalled Invoke-AkariCsc -Exactly 1 -Scope It -ParameterFilter { $Source -like '*OneClick\settimerresolutionservice.cs' -and (Test-Path $Source) }
                    Assert-MockCalled New-Service -Exactly 1 -Scope It -ParameterFilter { $Name -eq 'Set Timer Resolution Service' }
                    (Get-ItemProperty "$tk\HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel").GlobalTimerResolutionRequests | Should Be 1
                    Mock Get-Service { [pscustomobject]@{ Name = 'Set Timer Resolution Service'; StartType = 'Automatic' } }
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Assert-MockCalled Remove-AkariService -Exactly 1 -Scope It
                } finally { $env:SystemRoot = $realSystemRoot }
            }
        }

        Context 'Clean temporary files' {
            Mock Remove-Item { }
            Mock Start-Process { }
            Mock Get-AkariUserFolder { "$TestDrive\User\$Name" }
            $t = Load 'Optimize\Performance\CleanTemp.ps1'
            It 'cleans temp and the update cache, never XboxGames or inetpub, then runs Disk Cleanup' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Remove-Item -Scope It -ParameterFilter { $Path -like '*SoftwareDistribution*' }
                Assert-MockCalled Remove-Item -Exactly 0 -Scope It -ParameterFilter { $Path -like '*XboxGames*' -or $Path -like '*inetpub*' }
                Assert-MockCalled Stop-Service -Scope It -ParameterFilter { $Name -eq 'wuauserv' }
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'cleanmgr.exe' }
            }
        }

        Context 'Loudness EQ tab' {
            $t = Load 'Customize\Sound\LoudnessEQ.ps1'
            New-Item "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{dev1}\Properties" -Force | Out-Null
            It 'unhides the tab on every playback device with the audio services stopped, then starts them again' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty -LiteralPath "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{dev1}\FxProperties").'{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3' | Should Be '{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}'
                Assert-MockCalled Stop-Service -Exactly 2 -Scope It
                Assert-MockCalled Start-Service -Exactly 2 -Scope It
            }
        }

        Context 'A generated registry Toggle (Control Panel Settings)' {
            $t = Load 'Optimize\Privacy\Telemetry.ps1'
            It 'round-trips to the Default' {
                Get-AkariState $t | Should Not Be 'Optimized'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }
    } finally {
        $env:SystemRoot = $realSystemRoot
        Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}
