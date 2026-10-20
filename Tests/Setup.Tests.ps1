$Root = Split-Path $PSScriptRoot
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

    try {
        It 'redirects both hives (guard)' { Resolve-AkariRegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' | Should Be "$tk\HKLM\SOFTWARE\Policies\Microsoft\Edge" }

        Context 'Store settings' {
            Mock Import-AkariAppSettings { $true }
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
