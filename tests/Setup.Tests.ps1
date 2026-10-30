$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# 3 Setup port: Store and Edge settings, BitLocker, update pause; and Import-AkariAppSettings. HKCU:\Software\AkariTest\
# <guid> and TestDrive only: both hives are redirected by mocking Resolve-AkariRegPath; reg.exe, BitLocker cmdlets and
# processes are mocked (AGENTS.md rule 12).

Describe 'Import-AkariAppSettings' {
    foreach ($f in 'Log', 'Registry', 'AppSetup') { . "$Core\$f.ps1" }
    Mock Get-AkariUserFolder { "$TestDrive\User\Local" }
    Mock Start-Sleep { }
    Context 'the app has settings' {
        New-Item "$TestDrive\User\Local\Packages\Some.App_x\Settings\settings.dat" -ItemType File -Force | Out-Null
        Mock Invoke-AkariRegExe { 0 }
        It 'loads the hive, imports the text, unloads it' {
            Import-AkariAppSettings 'Some.App_x' "Windows Registry Editor Version 5.00`r`n" | Should Be $true
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'load' -and $Arguments[1] -eq 'HKLM\AkariAppHive' -and $Arguments[2] -like '*Some.App_x\Settings\settings.dat' }
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'import' }
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'unload' }
        }
    }
    Context 'the hive will not load' {
        Mock Invoke-AkariRegExe { 1 }
        It 'is $false and imports nothing' {
            New-Item "$TestDrive\User\Local\Packages\Some.App_x\Settings\settings.dat" -ItemType File -Force | Out-Null
            Import-AkariAppSettings 'Some.App_x' 'x' | Should Be $false
            Assert-MockCalled Invoke-AkariRegExe -Exactly 0 -Scope It -ParameterFilter { $Arguments[0] -eq 'import' }
        }
    }
    Context 'no settings yet' {
        Mock Invoke-AkariRegExe { 0 }
        It 'is $false' {
            Import-AkariAppSettings 'Missing.App_x' 'x' | Should Be $false
            Assert-MockCalled Invoke-AkariRegExe -Exactly 0 -Scope It
        }
    }
}

Describe 'Native tools inside a tweak block (real reg.exe / powercfg.exe, read only)' {
    # the Runner gives every cmdlet and advanced function -ErrorAction Stop; a native tool's stderr (reg.exe prints
    # "The operation completed successfully." there) must not fail the tweak. Read-only commands on a missing key / plan.
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $missing = "HKCU\Software\AkariTest\$([guid]::NewGuid())"
    It 'reg.exe: the exit code comes back, the tweak is Applied' {
        $t = ConvertTo-AkariTweak @{ Id = 'reg-probe'; Name = 'reg probe'; Description = 'D'; Section = 'Optimize'; Category = 'X'; Risk = 'Safe'; Kind = 'Action'
            Apply = [scriptblock]::Create("if ((Invoke-AkariRegExe query '$missing') -ne 1) { throw 'wrong exit code' }") } 'x' $false
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
    }
    It 'powercfg.exe: its error text comes back as output, the tweak is Applied' {
        $t = ConvertTo-AkariTweak @{ Id = 'pcfg-probe'; Name = 'powercfg probe'; Description = 'D'; Section = 'Optimize'; Category = 'X'; Risk = 'Safe'; Kind = 'Action'
            Apply = { if (-not (Invoke-AkariPowerCfg '/query' '00000000-0000-0000-0000-00000000a1a1')) { throw 'no output' } } } 'x' $false
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
    }
}

Describe 'Read-AkariAppSettings (Detect: a copy of the hive, read only)' {
    foreach ($f in 'Log', 'Registry', 'AppSetup') { . "$Core\$f.ps1" }
    Mock Get-AkariUserFolder { "$TestDrive\User\Local" }
    $export = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppRead]`r`n`"Top`"=hex:05`r`n`r`n" +
        "[HKEY_LOCAL_MACHINE\AkariAppRead\LocalState]`r`n`"VideoAutoplay`"=hex(5f5e10b):00,96,9d,69`r`n" +
        "`"Long`"=hex(5f5e10b):01,02,\`r`n  03,04`r`n`"Text`"=`"x`"`r`n`"Empty`"=hex(5f5e10b):`r`n`r`n" +
        "[HKEY_LOCAL_MACHINE\AkariAppRead\LocalState\PersistentSettings]`r`n`"PersonalizationEnabled`"=hex(5f5e10b):01,0d`r`n`r`n" +
        "[HKEY_LOCAL_MACHINE\Other]`r`n`"Nope`"=hex:01`r`n"
    $dat = "$TestDrive\User\Local\Packages\Some.App_x\Settings\settings.dat"

    It 'parses reg export text: hex values below the root, continued lines joined, others skipped' {
        $v = ConvertFrom-AkariRegExport $export 'HKEY_LOCAL_MACHINE\AkariAppRead'
        ($v.Keys | Sort-Object) -join ',' | Should Be 'LocalState\Empty,LocalState\Long,LocalState\PersistentSettings\PersonalizationEnabled,LocalState\VideoAutoplay,Top'
        $v['LocalState\VideoAutoplay'] -join ',' | Should Be '0,150,157,105'
        $v['LocalState\Long'] -join ',' | Should Be '1,2,3,4'
        $v['Top'] -join ',' | Should Be '5'
        @($v['LocalState\Empty']).Count | Should Be 0
    }

    Context 'the app has settings' {
        Mock Invoke-AkariRegExe { if ($Arguments[0] -eq 'export') { Set-Content -LiteralPath $Arguments[2] -Value $export -Encoding Unicode }; 0 }
        It 'loads a copy (never the app''s file), exports it, unloads it, cleans up' {
            New-Item $dat -ItemType File -Force | Out-Null
            $v = Read-AkariAppSettings 'Some.App_x'
            $v['LocalState\PersistentSettings\PersonalizationEnabled'] -join ',' | Should Be '1,13'
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'load' -and $Arguments[1] -eq 'HKLM\AkariAppRead' -and $Arguments[2] -notlike '*\Packages\*' }
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'export' -and $Arguments[1] -eq 'HKLM\AkariAppRead' }
            Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'unload' -and $Arguments[1] -eq 'HKLM\AkariAppRead' }
            Test-Path "$env:TEMP\akari-read-$PID" | Should Be $false
            Test-Path $dat | Should Be $true
        }
        It 'is $null while the app holds its file' {
            New-Item $dat -ItemType File -Force | Out-Null
            $lock = [IO.File]::Open($dat, 'Open', 'ReadWrite', 'None')
            try { Read-AkariAppSettings 'Some.App_x' | Should Be $null } finally { $lock.Dispose() }
            Assert-MockCalled Invoke-AkariRegExe -Exactly 0 -Scope It
        }
    }
    Context 'the copy will not load' {
        Mock Invoke-AkariRegExe { 1 }
        It 'is $null and exports nothing' {
            New-Item $dat -ItemType File -Force | Out-Null
            Read-AkariAppSettings 'Some.App_x' | Should Be $null
            Assert-MockCalled Invoke-AkariRegExe -Exactly 0 -Scope It -ParameterFilter { $Arguments[0] -eq 'export' }
        }
    }
    Context 'no settings yet' {
        Mock Invoke-AkariRegExe { 0 }
        It 'is empty' {
            @((Read-AkariAppSettings 'Missing.App_x').Keys).Count | Should Be 0
            Assert-MockCalled Invoke-AkariRegExe -Exactly 0 -Scope It
        }
    }
}

Describe 'Get-AkariAppSettingState' {
    foreach ($f in 'Log', 'Registry', 'AppSetup') { . "$Core\$f.ps1" }
    $rows = @(@{ Name = 'LocalState\A'; Value = 0; Default = 1 }, @{ Name = 'LocalState\B'; Value = 1; Default = 0 })
    Context 'all optimized' {
        Mock Read-AkariAppSettings { @{ 'LocalState\A' = [byte[]](0, 9); 'LocalState\B' = [byte[]](1, 9) } }
        It 'is Optimized' { Get-AkariAppSettingState 'X' $rows | Should Be 'Optimized' }
    }
    Context 'defaults, one value unset' {
        Mock Read-AkariAppSettings { @{ 'LocalState\A' = [byte[]](1, 9) } }
        It 'is Default' { Get-AkariAppSettingState 'X' $rows | Should Be 'Default' }
    }
    Context 'no settings yet' {
        Mock Read-AkariAppSettings { @{} }
        It 'is Default' { Get-AkariAppSettingState 'X' $rows | Should Be 'Default' }
    }
    Context 'mixed' {
        Mock Read-AkariAppSettings { @{ 'LocalState\A' = [byte[]](0, 9); 'LocalState\B' = [byte[]](0, 9) } }
        It 'is Custom' { Get-AkariAppSettingState 'X' $rows | Should Be 'Custom' }
    }
    Context 'unreadable (the app is running)' {
        Mock Read-AkariAppSettings { $null }
        It 'is Unknown' { Get-AkariAppSettingState 'X' $rows | Should Be 'Unknown' }
    }
}

Describe 'Setup tweaks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Start-Process { }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    # guard: Detect never reads the real Store hive here
    Mock Read-AkariAppSettings { $null }
    Mock Invoke-AkariRegExe { 1 }

    try {
        It 'redirects both hives (guard)' { Resolve-AkariRegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' | Should Be "$tk\HKLM\SOFTWARE\Policies\Microsoft\Edge" }

        Context 'Store settings' {
            # the Store's hive: the first byte of its three values, set by the (mocked) import
            $hive = @{ Byte = 1 }
            Mock Import-AkariAppSettings { $hive.Byte = if ($RegText -match '"VideoAutoplay"=hex\(5f5e10b\):00') { 0 } else { 1 }; $true }
            Mock Read-AkariAppSettings {
                $b = [byte[]]($hive.Byte, 9)
                @{ 'LocalState\VideoAutoplay' = $b; 'LocalState\EnableAppInstallNotifications' = $b; 'LocalState\PersistentSettings\PersonalizationEnabled' = $b }
            }
            $t = Load 'Customize\Apps\StoreSettings.ps1'
            It 'imports the Store values off on Apply and on on Revert, with the Store closed' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Stop-Process -Scope It -ParameterFilter { $Name -eq 'WinStore.App' }
                Assert-MockCalled Import-AkariAppSettings -Exactly 1 -Scope It -ParameterFilter { $Family -eq 'Microsoft.WindowsStore_8wekyb3d8bbwe' -and $RegText -match '"VideoAutoplay"=hex\(5f5e10b\):00,96' -and $RegText -match '"PersonalizationEnabled"=hex\(5f5e10b\):00,' -and $RegText -notmatch '\{0\}' }
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Import-AkariAppSettings -Exactly 1 -Scope It -ParameterFilter { $RegText -match '"EnableAppInstallNotifications"=hex\(5f5e10b\):01,36' }
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Store settings: the hive will not open' {
            Mock Import-AkariAppSettings { $false }
            $t = Load 'Customize\Apps\StoreSettings.ps1'
            It 'is Failed' { (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Failed' }
        }

        Context 'Edge settings' {
            $t = Load 'Customize\Apps\EdgeSettings.ps1'
            It 'round-trips to the Default' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Pause updates' {
            $t = Load 'Optimize\Update\PauseUpdates.ps1'
            It 'pauses until a year from now; Revert resumes' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                $end = [datetime]::Parse((Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseQualityUpdatesEndTime'))
                ($end - (Get-Date)).TotalDays | Should BeGreaterThan 364
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesStartTime' | Should Be $null
                Get-AkariState $t | Should Be 'Default'
            }
            It 'an expired pause is the Default' {
                Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime' '2020-01-01T00:00:00Z' 'String'
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'BitLocker: an encrypted drive' {
            Mock Get-BitLockerVolume { [pscustomobject]@{ MountPoint = 'C:'; ProtectionStatus = 'On'; VolumeStatus = 'FullyEncrypted' }; [pscustomobject]@{ MountPoint = 'D:'; ProtectionStatus = 'Off'; VolumeStatus = 'FullyDecrypted' } }
            Mock Disable-BitLocker { }
            $t = Load 'Optimize\Performance\BitLocker.ps1'
            It 'decrypts only the encrypted drive' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Disable-BitLocker -Exactly 1 -Scope It -ParameterFilter { $MountPoint -eq 'C:' }
            }
        }

        Context 'BitLocker: nothing encrypted' {
            Mock Get-BitLockerVolume { [pscustomobject]@{ MountPoint = 'C:'; ProtectionStatus = 'Off'; VolumeStatus = 'FullyDecrypted' } }
            Mock Disable-BitLocker { }
            $t = Load 'Optimize\Performance\BitLocker.ps1'
            It 'is Already' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Already'
                Assert-MockCalled Disable-BitLocker -Exactly 0 -Scope It
            }
        }
    } finally {
        Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}
