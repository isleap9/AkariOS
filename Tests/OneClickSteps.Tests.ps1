$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# One-click's own steps (Tweaks\OneClick) and Notepad settings: HKCU:\Software\AkariTest\<guid> and TestDrive only. Both
# hives are redirected by mocking Resolve-AkariRegPath; %SystemRoot%, %ProgramFiles% and %ProgramData% point into
# TestDrive; downloads, programs, reg.exe, TrustedInstaller and restore points are mocked (AGENTS.md rule 12).

Describe 'One-click steps' {
    $AkariLogFile = "$TestDrive\akari.log"
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup', 'Restore', 'Phases') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Get-AkariUserFolder { "$TestDrive\User\$Name" }
    Mock Save-AkariFile { $OutFile }
    Mock Invoke-AkariExe { 0 }
    Mock Invoke-AkariRegExe { 0 }
    Mock Import-AkariRegText { 0 }
    Mock Import-AkariAppSettings { $true }
    Mock Run-Trusted { }
    Mock Start-Process { }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    Mock New-AkariRestorePoint { @{ Ok = $true; Message = '' } }
    $real = @{ SystemRoot = $env:SystemRoot; ProgramFiles = $env:ProgramFiles; ProgramData = $env:ProgramData }
    $env:SystemRoot = "$TestDrive\Windows"; $env:ProgramFiles = "$TestDrive\PF"; $env:ProgramData = "$TestDrive\PD"

    try {
        It 'redirects the hives and the system folders (guard)' {
            Resolve-AkariRegPath 'HKLM:\SOFTWARE\X' | Should Be "$tk\HKLM\SOFTWARE\X"
            $env:SystemRoot | Should Be "$TestDrive\Windows"
            $env:ProgramData | Should Be "$TestDrive\PD"
        }

        It 'loads the One-click steps (Section OneClick: the Tweaks step never shows it, Tests\Steps.Tests.ps1)' {
            $loaded = Get-AkariTweaks $Tw
            @($loaded.Tweaks | Where-Object { $_.Section -eq 'OneClick' }).Count | Should BeGreaterThan 8
        }

        Context 'Get DDU ready' {
            $t = Load 'OneClick\Prepare\DduPrepare.ps1'
            It 'needs 7-Zip' { (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Failed' }
            It 'downloads DDU, unpacks it with 7-Zip, copies its config read only' {
                New-Item "$TestDrive\PF\7-Zip\7z.exe" -ItemType File -Force | Out-Null
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Save-AkariFile -Scope It -ParameterFilter { $Name -eq 'ddu.exe' }
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { $Path -like '*7-Zip\7z.exe' -and $Arguments[0] -eq 'x' -and $Arguments -contains "-o$TestDrive\Windows\Temp\ddu" }
                $cfg = Get-Item "$TestDrive\Windows\Temp\ddu\Settings\Settings.xml"
                $cfg.IsReadOnly | Should Be $true
                ([xml](Get-Content $cfg.FullName -Raw)).DisplayDriverUninstaller.Settings.CheckUpdates | Should Be 'False'
                # a second run replaces the read-only file
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            }
        }

        Context 'Remove the drivers with DDU' {
            $t = Load 'OneClick\Drivers\DduClean.ps1'
            It 'runs in Safe Mode and restarts the PC itself' {
                $t.SafeMode | Should Be $true
                Test-AkariRestarts $t 'Apply' | Should Be $true
            }
            It 'keeps the drivers when DDU is not ready' {
                $o = Invoke-AkariTweak $t Apply
                $o.Outcome | Should Be 'Applied'
                Assert-MockCalled Start-Process -Exactly 0 -Scope It
            }
            It 'starts DDU with the clean and restart switches' {
                New-Item "$TestDrive\Windows\Temp\ddu\Display Driver Uninstaller.exe" -ItemType File -Force | Out-Null
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $ArgumentList -eq '-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart' }
            }
        }

        Context 'PowerShell scripts on double-click' {
            $t = Load 'OneClick\Prepare\AllowScripts.ps1'
            It 'sets the open command and the execution policy' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariRegValue 'HKLM:\SOFTWARE\Classes\Applications\powershell.exe\shell\open\command' '(default)' | Should Match '-File "%1"$'
                Get-AkariRegValue 'HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' 'ExecutionPolicy' | Should Be 'Unrestricted'
            }
        }

        Context 'reg.reg' {
            $t = Load 'OneClick\Finish\Registry.ps1'
            It 'imports OneClick\reg.reg through Import-AkariRegText' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Import-AkariRegText -Exactly 1 -Scope It -ParameterFilter { $Text -like 'Windows Registry Editor Version 5.00*' -and $Text.Length -gt 10000 }
            }
        }

        Context 'Priority notifications' {
            $cur = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current'
            New-Item (Resolve-AkariRegPath "$cur\{1b019365-25a5-4ff1-b50a-c155229afc8f}`$windows.data.x") -Force | Out-Null
            $t = Load 'OneClick\Finish\PriorityNotifications.ps1'
            It 'writes the empty priority list for each account' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Import-AkariRegText -Exactly 1 -Scope It -ParameterFilter {
                    $Text.Contains('[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\{1b019365-25a5-4ff1-b50a-c155229afc8f}$windows.data.donotdisturb.quiethoursprofile$quiethoursprofilelist') -and
                    $Text.Contains('"Data"=hex(3):43,42,01,00') -and $Text.TrimEnd().EndsWith('00,00,00,00,00') -and -not $Text.Contains('; the Data') }
            }
        }

        Context 'App actions and Notepad' {
            It 'writes the shell''s app actions hive' {
                [void](Invoke-AkariTweak (Load 'OneClick\Finish\AppActions.ps1') Apply)
                Assert-MockCalled Import-AkariAppSettings -Exactly 1 -Scope It -ParameterFilter { $Family -eq 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' -and $RegText.Contains('[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState\DisabledApps]') }
            }
        }

        Context 'Startup entries and tasks' {
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Some App' 'x.exe' 'String'
            Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft' 'Id' 'a' 'String'
            Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\OtherUpdater' 'Id' 'b' 'String'
            New-Item "$TestDrive\Windows\System32\Tasks\Microsoft\keep" -ItemType File -Force | Out-Null
            New-Item "$TestDrive\Windows\System32\Tasks\OtherUpdater" -ItemType File -Force | Out-Null
            New-Item "$TestDrive\User\AppData\Microsoft\Windows\Start Menu\Programs\Startup\app.lnk" -ItemType File -Force | Out-Null
            $t = Load 'OneClick\Finish\StartupCleanup.ps1'
            It 'empties Run, the Startup folders and the non-Microsoft tasks' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'Some App' | Should Be $null
                Test-Path "$TestDrive\User\AppData\Microsoft\Windows\Start Menu\Programs\Startup\app.lnk" | Should Be $false
                Test-Path "$TestDrive\Windows\System32\Tasks\OtherUpdater" | Should Be $false
                Test-Path "$TestDrive\Windows\System32\Tasks\Microsoft\keep" | Should Be $true
                Assert-MockCalled Run-Trusted -Exactly 1 -Scope It -ParameterFilter { $command -like '*OtherUpdater*' }
            }
        }

        Context 'Performance counters and the restore point' {
            New-Item "$TestDrive\Windows\System32\lodctr.exe", "$TestDrive\Windows\SysWOW64\lodctr.exe" -ItemType File -Force | Out-Null
            It 'rebuilds both counter sets' {
                [void](Invoke-AkariTweak (Load 'OneClick\Finish\PerformanceCounters.ps1') Apply)
                Assert-MockCalled Invoke-AkariExe -Exactly 2 -Scope It -ParameterFilter { $Path -like '*lodctr.exe' -and $Arguments -contains '/R' }
            }
            It 'makes an "AkariOS setup" restore point' {
                (Invoke-AkariTweak (Load 'OneClick\Finish\RestorePoint.ps1') Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled New-AkariRestorePoint -Exactly 1 -Scope It -ParameterFilter { $Description -eq 'AkariOS setup' }
            }
        }
    } finally {
        foreach ($n in $real.Keys) { Set-Item "env:$n" $real[$n] }
        Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Import-AkariRegText' {
    foreach ($f in 'Log', 'Registry', 'AppSetup') { . "$Core\$f.ps1" }
    Mock Get-AkariUserSid { 'S-1-5-21-test' }
    Mock Invoke-AkariRegExe { $script:imported = Get-Content $Arguments[1] -Raw -Encoding Unicode; 0 }
    It 'sends HKEY_CURRENT_USER keys to the real user and imports the file' {
        Import-AkariRegText "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_CURRENT_USER\Software\X]`r`n[-HKEY_CURRENT_USER\Software\Y]`r`n[HKEY_LOCAL_MACHINE\Z]" | Should Be 0
        $script:imported | Should Match '\[HKEY_USERS\\S-1-5-21-test\\Software\\X\]'
        $script:imported | Should Match '\[-HKEY_USERS\\S-1-5-21-test\\Software\\Y\]'
        $script:imported | Should Match '\[HKEY_LOCAL_MACHINE\\Z\]'
        Assert-MockCalled Invoke-AkariRegExe -Exactly 1 -Scope It -ParameterFilter { $Arguments[0] -eq 'import' }
    }
}

Describe 'Notepad settings' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    Mock Get-AkariUserFolder { "$TestDrive\User\$Name" }
    Mock Import-AkariAppSettings { $true }
    # Detect reads nothing real: Unknown, so Apply and Revert both run
    Mock Read-AkariAppSettings { $null }
    Mock Invoke-AkariRegExe { 1 }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Context 'Notepad Detect' {
        Mock Read-AkariAppSettings { @{ 'LocalState\OpenFile' = [byte[]](1, 0, 0, 0, 9); 'LocalState\GhostFile' = [byte[]](0, 9); 'LocalState\RewriteEnabled' = [byte[]](0, 9) } }
        It 'reads OpenFile, GhostFile and RewriteEnabled from Notepad''s hive' {
            Get-AkariState (Load 'Customize\Apps\NotepadSettings.ps1') | Should Be 'Optimized'
            Assert-MockCalled Read-AkariAppSettings -Exactly 1 -Scope It -ParameterFilter { $Family -eq 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' }
        }
    }
    It 'Notepad: imports its settings; Revert deletes its settings file' {
        $t = Load 'Customize\Apps\NotepadSettings.ps1'
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
        Assert-MockCalled Import-AkariAppSettings -Exactly 1 -Scope It -ParameterFilter { $Family -eq 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' -and $RegText.Contains('"RewriteEnabled"=hex(5f5e10b):00,') }
        $dat = "$TestDrive\User\Local AppData\Packages\Microsoft.WindowsNotepad_8wekyb3d8bbwe\Settings\settings.dat"
        New-Item $dat -ItemType File -Force | Out-Null
        (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
        Test-Path $dat | Should Be $false
    }
}
