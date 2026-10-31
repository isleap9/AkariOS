$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# The Advanced tweaks (8 Advanced port), against HKCU:\Software\AkariTest\<guid> and TestDrive only. Both hives are
# redirected by mocking Resolve-AkariRegPath; bcdedit, MMAgent, takeown/icacls, processes and services are mocked
# (AGENTS.md rule 12).

Describe 'Advanced tweaks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Phases') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Invoke-AkariBcdEdit { 0 }
    Mock Read-AkariBcd { }
    Mock Grant-AkariOwnership { }
    Mock Stop-Process { }
    Mock Stop-Service { }
    Mock Start-Service { }
    Mock Start-Sleep { }
    Mock Restart-AkariExplorer { }
    Mock Get-AkariOSBuild { 26100 }
    # second guard: no test here may change a real scheduled task or write as TrustedInstaller
    Mock Set-AkariScheduledTask { $true }
    Mock Disable-ScheduledTask { }
    Mock Enable-ScheduledTask { }
    Mock Run-Trusted { }
    Mock Test-AkariSafeMode { $true }
    $realSystemRoot = $env:SystemRoot

    try {
        It 'redirects both hives (guard)' {
            Resolve-AkariRegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' | Should Be "$tk\HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy"
            Resolve-AkariRegPath 'HKCU:\System\GameConfigStore' | Should Be "$tk\System\GameConfigStore"
        }

        Context 'Registry Toggles' {
            $files = Get-ChildItem "$Tw\Advanced\Security", "$Tw\Advanced\Display", "$Tw\Advanced\System" -Filter *.ps1 -File
            foreach ($f in $files) {
                $t = Import-AkariTweakFile $f.FullName $Tw
                # pure registry Toggles only: a Toggle with an After block (scheduled tasks, ...) gets its own Context with mocks
                if (-not $t.Registry -or $t.After) { continue }
                It "$($t.Id) round-trips to the Default" {
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Get-AkariState $t | Should Be 'Default'
                }
            }
            It 'the keyboard Scancode Map is the old script''s bytes' {
                $t = Load 'Advanced\System\KeyboardShortcuts.ps1'
                $hex = ($t.Registry | Where-Object { $_.Name -eq 'Scancode Map' }).Value | ForEach-Object { '{0:x2}' -f $_ }
                ($hex -join '') | Should Be '00000000000000000700000000005be000005ce000003800000038e00000010001000d0000000000'
            }
            It 'the NVMe Safe Mode keys go away on Revert' {
                $t = Load 'Advanced\System\NvmeDriver.ps1'
                [void](Invoke-AkariTweak $t Apply)
                (Get-Item -LiteralPath "$tk\HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}").GetValue('') | Should Be 'Storage disks'
                [void](Invoke-AkariTweak $t Revert)
                Test-Path -LiteralPath "$tk\HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}" | Should Be $false
            }
        }

        Context 'Data Execution Prevention' {
            $t = Load 'Advanced\Security\DataExecutionPrevention.ps1'
            It 'reads nx from the boot entry' {
                Get-AkariState $t | Should Be 'Default'
                Mock Read-AkariBcd { 'identifier              {current}'; 'nx                      OptIn' }
                Get-AkariState $t | Should Be 'Default'
                Mock Read-AkariBcd { 'nx                      AlwaysOff' }
                Get-AkariState $t | Should Be 'Optimized'
                Mock Read-AkariBcd { 'nx                      OptOut' }
                Get-AkariState $t | Should Be 'Custom'
            }
        }

        Context 'Data Execution Prevention: Apply and Revert' {
            $t = Load 'Advanced\Security\DataExecutionPrevention.ps1'
            It 'sets nx AlwaysOff and deletes it on Revert, through Invoke-AkariBcdEdit' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariBcdEdit -Exactly 1 -Scope It -ParameterFilter { $Arguments -eq '/set {current} nx AlwaysOff' }
                Mock Read-AkariBcd { 'nx                      AlwaysOff' }
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Invoke-AkariBcdEdit -Exactly 1 -Scope It -ParameterFilter { $Arguments -eq '/deletevalue {current} nx' }
            }
        }

        Context 'Data Execution Prevention: bcdedit fails' {
            Mock Invoke-AkariBcdEdit { 1 }
            $t = Load 'Advanced\Security\DataExecutionPrevention.ps1'
            It 'is Failed' { (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Failed' }
        }

        Context 'Prefetch and app prelaunch' {
            Mock Get-MMAgent { [pscustomobject]@{ ApplicationLaunchPrefetching = $true; ApplicationPreLaunch = $true; OperationAPI = $true; MaxOperationAPIFiles = 512; PageCombining = $false } }
            Mock Disable-MMAgent { }
            Mock Enable-MMAgent { }
            Mock Set-MMAgent { }
            $t = Load 'Advanced\System\MMAgent.ps1'
            It 'turns the MMAgent features off, Prefetcher 0; Revert turns them on, Prefetcher 3, page combining stays off' {
                Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 3
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' | Should Be 0
                Assert-MockCalled Disable-MMAgent -Exactly 4 -Scope It
                Assert-MockCalled Set-MMAgent -Exactly 1 -Scope It -ParameterFilter { $MaxOperationAPIFiles -eq 1 }
                Mock Get-MMAgent { [pscustomobject]@{ ApplicationLaunchPrefetching = $false; ApplicationPreLaunch = $false; OperationAPI = $false; MaxOperationAPIFiles = 1; PageCombining = $false } }
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Enable-MMAgent -Exactly 3 -Scope It
                Assert-MockCalled Disable-MMAgent -Exactly 5 -Scope It
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' | Should Be 3
            }
        }

        Context 'Start, Search and Shell hosts' {
            $env:SystemRoot = "$TestDrive\Windows"
            $names = 'Microsoft.Windows.Search_cw5n1h2txyewy', 'ShellExperienceHost_cw5n1h2txyewy', 'Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy'
            foreach ($n in $names) { New-Item "$TestDrive\Windows\SystemApps\$n" -ItemType Directory -Force | Out-Null }
            New-Item "$TestDrive\Windows\System32\mobsync.exe" -ItemType File -Force | Out-Null
            $t = Load 'Advanced\System\StartSearchShell.ps1'
            It 'moves the hosts and mobsync into %SystemRoot%, turns off search; Revert puts them back' {
                try {
                    Get-AkariState $t | Should Be 'Default'
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    foreach ($n in $names) { Test-Path "$TestDrive\Windows\$n" | Should Be $true }
                    Test-Path "$TestDrive\Windows\mobsync.exe" | Should Be $true
                    Assert-MockCalled Grant-AkariOwnership -Exactly 4 -Scope It
                    Assert-MockCalled Stop-Process -Scope It -ParameterFilter { $Name -eq 'StartMenuExperienceHost' }
                    Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch' 'Start' | Should Be 4
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    foreach ($n in $names) { Test-Path "$TestDrive\Windows\SystemApps\$n" | Should Be $true }
                    Test-Path "$TestDrive\Windows\System32\mobsync.exe" | Should Be $true
                    Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch' 'Start' | Should Be 2
                    Get-AkariRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableSearch' | Should Be $null
                    Get-AkariState $t | Should Be 'Default'
                } finally { $env:SystemRoot = $realSystemRoot }
            }
        }

        Context 'Start, Search and Shell hosts: a folder stays in use' {
            $env:SystemRoot = "$TestDrive\Busy"
            New-Item "$TestDrive\Busy\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy" -ItemType Directory -Force | Out-Null
            Mock Move-Item { }
            $t = Load 'Advanced\System\StartSearchShell.ps1'
            It 'is Failed after five tries' {
                try {
                    $o = Invoke-AkariTweak $t Apply
                    $o.Outcome | Should Be 'Failed'
                    $o.Message | Should Match 'in use'
                    Assert-MockCalled Move-Item -Exactly 5 -Scope It
                } finally { $env:SystemRoot = $realSystemRoot }
            }
        }

        Context 'Defender scheduled tasks and SmartScreen' {
            $t = Load 'Advanced\Security\DefenderTasks.ps1'
            It 'disables the five tasks on Apply and enables them on Revert, with the SmartScreen values' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Set-AkariScheduledTask -Exactly 5 -Scope It -ParameterFilter { -not $Enabled }
                Assert-MockCalled Set-AkariScheduledTask -Exactly 1 -Scope It -ParameterFilter { $TaskName -eq 'Windows Defender Scheduled Scan' -and $TaskPath -eq '\Microsoft\Windows\Windows Defender\' }
                Get-AkariRegValue 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenEnabled' '(default)' | Should Be 0
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Set-AkariScheduledTask -Exactly 5 -Scope It -ParameterFilter { $Enabled }
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Windows Security settings (in Safe Mode)' {
            $t = Load 'Advanced\Security\DefenderSettings.ps1'
            It 'is a SafeMode Tweak' { $t.SafeMode | Should Be $true }
            It 'writes the values as TrustedInstaller and as admin, clears VBS; Revert puts the Defaults back' {
                Get-AkariState $t | Should Not Be 'Optimized'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("Windows Defender\Features' -Name 'TamperProtection' -Value 4 -PropertyType DWord") }
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("-Name 'MitigationOptions' -Value ([byte[]](34,34,34,0,0,2,0,0,0,2,") }
                Assert-MockCalled Run-Trusted -Exactly 0 -Scope It -ParameterFilter { $command.Contains('Account protection') }
                Assert-MockCalled Invoke-AkariBcdEdit -Scope It -ParameterFilter { $Arguments -eq '/deletevalue hypervisorlaunchtype' }
                Get-AkariRegValue 'HKCU:\SOFTWARE\Microsoft\Windows Defender Security Center\Account protection' 'DisableNotifications' | Should Be 1
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("-Name 'SmartScreenEnabled' -Value 'Warn' -PropertyType String") }
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("-Name 'WasEnabledBy' -ErrorAction") } -Exactly 1
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Defender off completely (in Safe Mode)' {
            $t = Load 'Advanced\Security\DefenderOff.ps1'
            # the services this test's "Windows" has (MDCoreSvc and the web threat ones are missing, like on Windows 10)
            foreach ($s in 'WdNisSvc', 'WinDefend', 'wscsvc', 'Sense', 'SecurityHealthService', 'WdBoot', 'WdFilter', 'WdNisDrv') {
                New-Item "$tk\HKLM\SYSTEM\CurrentControlSet\Services\$s" -Force | Out-Null
            }
            $env:SystemRoot = "$TestDrive\Windows"
            New-Item "$TestDrive\Windows\System32\smartscreen.exe" -ItemType File -Force | Out-Null
            # the mocked TrustedInstaller moves smartscreen.exe like cmd's move would
            Mock Run-Trusted { if ($command -match 'move /y "([^"]+)" "([^"]+)"') { Move-Item -LiteralPath $Matches[1] -Destination $Matches[2] -Force } }
            It 'is a SafeMode Tweak that asks first' {
                $t.SafeMode | Should Be $true
                $t.Confirm | Should Match 'no antivirus'
            }
            It 'turns off the services it finds as TrustedInstaller, removes the menu and tray entries, moves SmartScreen; Revert undoes it' {
                Set-Reg 'HKLM:\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\EPP' '(default)' '{09A47860-11B0-4DA5-AFA5-26D86198A780}' 'String'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("Services\WinDefend' -Name 'Start' -Value 4 -PropertyType DWord") }
                Assert-MockCalled Run-Trusted -Exactly 0 -Scope It -ParameterFilter { $command.Contains('MDCoreSvc') -or $command.Contains('ContextMenuHandlers') }
                Test-Path "$tk\HKLM\SYSTEM\CurrentControlSet\Services\MDCoreSvc" | Should Be $false
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter' 'Start' | Should Be 4
                Get-AkariRegValue 'HKLM:\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\EPP' '(default)' | Should Be $null
                Test-Path "$TestDrive\Windows\smartscreen.exe" | Should Be $true
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot' 'Start' | Should Be 0
                Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'SecurityHealth' | Should Be ([Environment]::ExpandEnvironmentVariables('%windir%\system32\SecurityHealthSystray.exe'))
                Test-Path "$TestDrive\Windows\System32\smartscreen.exe" | Should Be $true
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Services off (in Safe Mode)' {
            $t = Load 'Advanced\Services\ServicesOff.ps1'
            $data = Import-PowerShellDataFile "$Tw\Advanced\Services\Files\services.psd1"
            $list = @($data.Services)
            # four of the services exist in this test's "Windows"
            foreach ($s in 'WlanSvc', 'SysMain', 'StateRepository', 'Spooler') { New-Item "$tk\HKLM\SYSTEM\CurrentControlSet\Services\$s" -Force | Out-Null }
            It 'lists FR33THY''s 216 changed start types, none another Tweak owns' {
                @($list | Where-Object { $null -ne $_.Off }).Count | Should Be 216
                @($list | Where-Object { $_.Name -in 'CDPUserSvc', 'hidserv', 'WSearch' -or $_.Off -eq $_.Default }).Count | Should Be 0
                ($list | Where-Object { $_.Name -eq 'StateRepository' }).Off | Should Be 3
            }
            It 'lists ZOICWARE''s Light (33 services, 31 not already off by default) and Manual (38) picks, every one a row' {
                $data.Light.Count | Should Be 31
                $data.Manual.Count | Should Be 38
                @($data.Light + $data.Manual | Where-Object { $_ -notin $list.Name }).Count | Should Be 0
                # ZOICWARE's keep-list and the services an admin can't change stay as they are
                @($data.Manual | Where-Object { $_ -in 'Audiosrv', 'SysMain', 'WlanSvc', 'StateRepository', 'RpcSs', 'DcomLaunch', 'gpsvc' }).Count | Should Be 0
                @($list | Where-Object { $_.Name -in $data.Manual -and $_.Default -ne 2 }).Count | Should Be 0
            }
            It 'is a Choice: Off (Recommended), Light, Manual, Windows default' {
                $t.Kind | Should Be 'Choice'
                $t.Recommended | Should Be 'Off'
                $t.Default | Should Be 'Default'
                @($t.Choices.Value) -join ',' | Should Be 'Off,Light,Manual,Default'
            }
            It 'is a SafeMode Tweak that asks first' {
                $t.SafeMode | Should Be $true
                $t.Confirm | Should Match 'Windows Update'
            }
            It 'sets the services it finds as TrustedInstaller and as admin, skips the rest; Revert puts Windows'' start types back' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("Services\WlanSvc' -Name 'Start' -Value 4 -PropertyType DWord") }
                Assert-MockCalled Run-Trusted -Exactly 0 -Scope It -ParameterFilter { $command.Contains('Services\BITS') }
                Test-Path "$tk\HKLM\SYSTEM\CurrentControlSet\Services\BITS" | Should Be $false
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\StateRepository' 'Start' | Should Be 3
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain' 'Start' | Should Be 2
                Get-AkariState $t | Should Be 'Default'
                Get-AkariChoiceValue $t | Should Be 'Default'
            }
            It 'applies Light and Manual: their services changed, every other one at its Windows default' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Invoke-AkariTweak $t Apply 'Light').Outcome | Should Be 'Applied'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler' 'Start' | Should Be 4
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WlanSvc' 'Start' | Should Be 3
                Get-AkariChoiceValue $t | Should Be 'Light'
                Get-AkariState $t | Should Be 'Custom'
                (Invoke-AkariTweak $t Apply 'Manual').Outcome | Should Be 'Applied'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler' 'Start' | Should Be 3
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain' 'Start' | Should Be 2
                Get-AkariChoiceValue $t | Should Be 'Manual'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler' 'Start' | Should Be 2
                Get-AkariState $t | Should Be 'Default'
            }
            It 'reads a hand-changed start type as Custom' {
                Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain' 'Start' 3
                Get-AkariChoiceValue $t | Should Be $null
                Get-AkariState $t | Should Be 'Custom'
                Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain' 'Start' 2
            }
        }

        Context 'Invoke-AkariRegistryTrusted' {
            It 'batches the HKLM rows into a few Run-Trusted calls, skipping HKCU' {
                $rows = @(1..30 | ForEach-Object { @{ Path = "HKLM:\SOFTWARE\AkariTest\Key$_"; Name = "V$_"; Type = 'DWord'; Value = $_; Default = $null } }) +
                    @(@{ Path = 'HKCU:\Software\X'; Name = 'U'; Type = 'DWord'; Value = 1; Default = $null })
                Invoke-AkariRegistryTrusted $rows Apply
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Length -gt 1500 } -Exactly 0
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command -like '*HKCU*' -or $command -like '*Software\X*' } -Exactly 0
                Assert-MockCalled Run-Trusted -Scope It -ParameterFilter { $command.Contains("Key30' -Name 'V30' -Value 30 ") } -Exactly 1
            }
        }
    } finally {
        $env:SystemRoot = $realSystemRoot
        Remove-Item $tk -Recurse -Force -ErrorAction SilentlyContinue
    }
}
