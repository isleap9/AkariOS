$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# Every Tweak ported from ZOICWARE (its file names ZOICWARE as the source): Advanced only, outside the AkariOS setup,
# a Default on every row, and a full Apply / Revert round trip. Both hives go to HKCU:\Software\AkariTest\<guid>.
Describe 'ZOICWARE ports' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Trusted', 'Phases', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Restart-AkariExplorer { }
    # no real powercfg, and never a real scheduled task (an Action runs once here, against this mock)
    Mock Invoke-AkariPowerCfg { }
    Mock Remove-AkariScheduledTasks { 3 }
    # TrustedInstaller writes go to the test key as admin (never a real Run-Trusted)
    Mock Invoke-AkariRegistryTrusted { Invoke-AkariRegistry $Entries $Mode }
    # a print verb Windows has (context-remove-print only touches the ones that exist)
    New-Item -Path "$tk\HKLM\SOFTWARE\Classes\batfile\shell\print" -Force | Out-Null
    Mock Get-AkariEdition { 'Professional' }
    Mock Get-AkariGpus { @{ Path = 'HKLM:\SYSTEM\AkariTestGpu'; Name = 'NVIDIA GeForce RTX 4070'; Vendor = 'NVIDIA' } }
    # the cleanup Actions run here: never a real delete, event log, Disk Cleanup, driver store or TrustedInstaller call
    Mock Remove-AkariPaths { 2 }
    Mock Grant-AkariOwnership { }
    Mock Run-Trusted { }
    Mock Invoke-AkariWevtutil { if ($Arguments[0] -eq 'el') { 'Application'; 'System' } }
    Mock Invoke-AkariCleanMgr { }
    Mock Remove-AkariDriverPackage { 0 }
    Mock Get-AkariDriverPackages {
        [pscustomobject]@{ Driver = 'oem10.inf'; OriginalFileName = 'C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_a\nv_dispi.inf'; ProviderName = 'NVIDIA'; ClassName = 'Display'; Version = '32.0.15.6094'; Date = [datetime]'2024-08-01' }
        [pscustomobject]@{ Driver = 'oem22.inf'; OriginalFileName = 'C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_b\nv_dispi.inf'; ProviderName = 'NVIDIA'; ClassName = 'Display'; Version = '32.0.15.7680'; Date = [datetime]'2025-06-01' }
        [pscustomobject]@{ Driver = 'oem5.inf'; OriginalFileName = 'C:\Windows\System32\DriverStore\FileRepository\rt640x64.inf_amd64_c\rt640x64.inf'; ProviderName = 'Realtek'; ClassName = 'Net'; Version = '10.68.0.0'; Date = [datetime]'2024-01-01' }
    }
    # Disk Cleanup categories this Windows has (the test hive's)
    foreach ($c in 'Update Cleanup', 'Temporary Files', 'Recycle Bin') { New-Item -Path "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$c" -Force | Out-Null }
    # the boot store, w32tm and the Photos app's settings hive, faked: never the real ones
    $fake = @{ BootUx = $false; Apps = @{} }
    Mock Read-AkariBcd { if ($fake.BootUx) { 'bootuxdisabled          Yes' } }
    Mock Invoke-AkariBcdEdit {
        if ($Arguments -eq '/set {globalsettings} bootuxdisabled on') { $fake.BootUx = $true }
        elseif ($Arguments -eq '/deletevalue {globalsettings} bootuxdisabled') { $fake.BootUx = $false }
        0
    }
    Mock Invoke-AkariW32tm { }
    # an app's settings hive: 'LocalState\<name>' = its bytes; the .reg text's values set ("=hex(...):") or deleted ("=-")
    Mock Read-AkariAppSettings { if ($fake.Apps.ContainsKey($Family)) { $fake.Apps[$Family] } else { @{} } }
    Mock Import-AkariAppSettings {
        if (-not $fake.Apps.ContainsKey($Family)) { $fake.Apps[$Family] = @{} }
        foreach ($m in [regex]::Matches($RegText, '"([^"]+)"=(-|hex\([0-9a-f]+\):([0-9a-f,]+))')) {
            $n = "LocalState\$($m.Groups[1].Value)"
            if ($m.Groups[2].Value -eq '-') { $fake.Apps[$Family].Remove($n) }
            else { $fake.Apps[$Family][$n] = [byte[]]($m.Groups[3].Value.Split(',') | ForEach-Object { [Convert]::ToByte($_, 16) }) }
        }
        $true
    }
    # a hosts file with a line of the user's, and the real user's Local AppData with Windows Terminal's settings
    $AkariHostsPath = "$TestDrive\hosts"
    [IO.File]::WriteAllLines($AkariHostsPath, [string[]]@('# a comment', '127.0.0.1 mine.test'))
    Mock Get-AkariUserFolder { "$TestDrive\LocalAppData" }
    $terminal = "$TestDrive\LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    New-Item -ItemType Directory -Path (Split-Path $terminal) -Force | Out-Null
    $terminalText = "{`r`n    `"`$help`": `"https://aka.ms/terminal-documentation`",`r`n    `"actions`": [],`r`n    `"profiles`": { `"list`": [] }`r`n}`r`n"
    [IO.File]::WriteAllText($terminal, $terminalText)
    $files = @(Get-ChildItem $Tw -Recurse -Filter *.ps1 | Where-Object { $_.DirectoryName -notmatch '\\Files$' -and (Get-Content $_.FullName -TotalCount 3) -match 'ZOICWARE' })

    try {
        It 'finds the ports (guard)' { $files.Count -ge 92 | Should Be $true }
        It 'redirects both hives (guard)' { Resolve-AkariRegPath 'HKLM:\SOFTWARE\X' | Should Be "$tk\HKLM\SOFTWARE\X" }
        foreach ($f in $files) {
            $t = Import-AkariTweakFile $f.FullName $Tw
            It "$($t.Id): Advanced only, not in the AkariOS setup, a Default on every row" {
                $t.Guided | Should Be $false
                [bool]$t.AkariOS | Should Be $false
                @($t.Registry | Where-Object { $_ -and -not $_.ContainsKey('Default') }).Count | Should Be 0
            }
            if ($t.Kind -eq 'Action') {
                It "$($t.Id): an Action that asks first and runs through mocked Core helpers" {
                    $t.Confirm | Should Not BeNullOrEmpty
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Skipped'
                }
                continue
            }
            It "$($t.Id): Apply makes it Optimized, Revert puts the Windows default back" {
                # start from the Windows default (a deleted key is Optimized while the test hive lacks it)
                Invoke-AkariTweak $t Revert | Out-Null
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }
        It 'removes every scheduled task but ZOICWARE''s two' {
            $t = Import-AkariTweakFile "$Tw\Advanced\System\RemoveScheduledTasks.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            Assert-MockCalled Remove-AkariScheduledTasks -Scope It -Exactly 1 -ParameterFilter { ($Keep -join ',') -eq 'SvcRestartTask,MsCtfMonitor' }
        }
        It 'hides Personalize and Display as TrustedInstaller' {
            foreach ($n in 'Personalize', 'Display') {
                $t = Import-AkariTweakFile "$Tw\Customize\Context menu\Remove$n.ps1" $Tw
                Invoke-AkariTweak $t Apply | Out-Null
            }
            Assert-MockCalled Invoke-AkariRegistryTrusted -Scope It -Exactly 2 -ParameterFilter { $Mode -eq 'Apply' -and $Entries[0].Name -eq 'ProgrammaticAccessOnly' }
        }
        It 'hides Print only on the print verbs that exist' {
            $t = Import-AkariTweakFile "$Tw\Customize\Context menu\RemovePrint.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            Test-Path "$tk\HKLM\SOFTWARE\Classes\txtfile\shell\print" | Should Be $false
            Get-AkariRegValue 'HKLM:\SOFTWARE\Classes\batfile\shell\print' 'ProgrammaticAccessOnly' | Should Be ''
            Invoke-AkariTweak $t Revert | Out-Null
            Test-Path "$tk\HKLM\SOFTWARE\Classes\batfile\shell\print" | Should Be $true
        }
        It 'keeps the user''s hosts lines and leaves no block after Revert' {
            $t = Import-AkariTweakFile "$Tw\Optimize\Network\BlockRazerAsus.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            $lines = @([IO.File]::ReadAllLines($AkariHostsPath))
            $lines[1] | Should Be '127.0.0.1 mine.test'
            @($lines | Where-Object { $_ -like '0.0.0.0 *' }).Count | Should Be 24
            Invoke-AkariTweak $t Apply | Out-Null
            @([IO.File]::ReadAllLines($AkariHostsPath) | Where-Object { $_ -like '0.0.0.0 *' }).Count | Should Be 24
            Invoke-AkariTweak $t Revert | Out-Null
            ([IO.File]::ReadAllLines($AkariHostsPath)) -join '|' | Should Be '# a comment|127.0.0.1 mine.test'
        }
        It 'puts Windows Terminal''s settings back as they were' {
            $t = Import-AkariTweakFile "$Tw\Customize\Apps\TerminalCloseTabs.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            [IO.File]::ReadAllText($terminal) | Should Match '"confirmCloseAllTabs": false,'
            Invoke-AkariTweak $t Revert | Out-Null
            [IO.File]::ReadAllText($terminal) | Should Be $terminalText
        }
        It 'turns the boot animation off through bcdedit, and Photos'' warning through its settings hive' {
            Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Customize\System\NoBootUi.ps1" $Tw) Apply | Out-Null
            Assert-MockCalled Invoke-AkariBcdEdit -Scope It -Exactly 1 -ParameterFilter { $Arguments -eq '/set {globalsettings} bootuxdisabled on' }
            Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Customize\Apps\PhotosDeleteWarning.ps1" $Tw) Apply | Out-Null
            Assert-MockCalled Import-AkariAppSettings -Scope It -Exactly 1 -ParameterFilter { $Family -eq 'Microsoft.Windows.Photos_8wekyb3d8bbwe' }
        }
        # ZOICWARE values of AkariOS Tweaks (Choices; their files name FR33THY first, so the loop above skips them)
        It 'sets ZOICWARE''s always small taskbar icons, and the AkariOS pick' {
            $t = Import-AkariTweakFile "$Tw\Customize\Taskbar\NeverSmallIcons.ps1" $Tw
            Invoke-AkariTweak $t Revert | Out-Null
            Get-AkariState $t | Should Be 'Default'
            (Invoke-AkariTweak $t Apply 'Always').Outcome | Should Be 'Applied'
            Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconSizePreference' | Should Be 0
            Get-AkariChoiceValue $t | Should Be 'Always'
            Get-AkariState $t | Should Be 'Custom'
            Invoke-AkariTweak $t Apply | Out-Null
            Get-AkariState $t | Should Be 'Optimized'
            Invoke-AkariTweak $t Revert | Out-Null
            Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconSizePreference' | Should Be $null
        }
        It 'sets ZOICWARE''s 50 Hz background mouse cap, and the AkariOS pick' {
            $t = Import-AkariTweakFile "$Tw\Hardware\Input\BackgroundPolling.ps1" $Tw
            Invoke-AkariTweak $t Revert | Out-Null
            Get-AkariState $t | Should Be 'Default'
            Invoke-AkariTweak $t Apply '50Hz' | Out-Null
            Get-AkariRegValue 'HKCU:\Control Panel\Mouse' 'RawMouseThrottleDuration' | Should Be 20
            Get-AkariChoiceValue $t | Should Be '50Hz'
            Invoke-AkariTweak $t Apply | Out-Null
            Get-AkariState $t | Should Be 'Optimized'
            Get-AkariRegValue 'HKCU:\Control Panel\Mouse' 'RawMouseThrottleDuration' | Should Be $null
            Invoke-AkariTweak $t Revert | Out-Null
            Get-AkariState $t | Should Be 'Default'
        }
        Context 'Ultimate Cleanup' {
            It 'deletes only the older of two copies of the same driver' {
                Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Tools\Cleanup\OldDrivers.ps1" $Tw) Apply | Out-Null
                Assert-MockCalled Remove-AkariDriverPackage -Scope It -Exactly 1
                Assert-MockCalled Remove-AkariDriverPackage -Scope It -Exactly 1 -ParameterFilter { $Inf -eq 'oem10.inf' }
            }
            It 'clears every event log wevtutil lists' {
                Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Tools\Cleanup\EventLogs.ps1" $Tw) Apply | Out-Null
                Assert-MockCalled Invoke-AkariWevtutil -Scope It -Exactly 2 -ParameterFilter { $Arguments[0] -eq 'cl' }
            }
            It 'runs Disk Cleanup with the categories this Windows has, never the Recycle Bin' {
                Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Tools\Cleanup\DiskCleanup.ps1" $Tw) Apply | Out-Null
                $vc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
                Get-AkariRegValue "$vc\Update Cleanup" 'StateFlags0069' | Should Be 2
                Get-AkariRegValue "$vc\Recycle Bin" 'StateFlags0069' | Should Be $null
                Test-Path "$tk\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" | Should Be $false
                Assert-MockCalled Invoke-AkariCleanMgr -Scope It -Exactly 1 -ParameterFilter { $Set -eq 69 }
            }
            It 'deletes the temp folders, the logs and the shader caches through Remove-AkariPaths' {
                foreach ($f in 'TempFiles', 'WindowsLogs', 'NvidiaShaderCache') { Invoke-AkariTweak (Import-AkariTweakFile "$Tw\Tools\Cleanup\$f.ps1" $Tw) Apply | Out-Null }
                Assert-MockCalled Remove-AkariPaths -Scope It -Exactly 1 -ParameterFilter { $Paths -contains "$TestDrive\LocalAppData\Temp\*" }
                Assert-MockCalled Remove-AkariPaths -Scope It -Exactly 1 -ParameterFilter { $Paths -contains "$env:SystemRoot\Logs\CBS\CBS.log" }
                Assert-MockCalled Remove-AkariPaths -Scope It -Exactly 1 -ParameterFilter { $Paths -contains "$TestDrive\LocalLow\NVIDIA\PerDriverVersion\DXCache" }
            }
        }
        It 'syncs the clock after setting the time servers' {
            $t = Import-AkariTweakFile "$Tw\Customize\System\TimeServer.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            Assert-MockCalled Invoke-AkariW32tm -Scope It -ParameterFilter { ($Arguments -join ' ') -eq '/config /update' }
            Assert-MockCalled Invoke-AkariW32tm -Scope It -ParameterFilter { ($Arguments -join ' ') -eq '/resync /nowait' }
        }
        It 'sets the update hold to this Windows'' version' {
            $t = Import-AkariTweakFile "$Tw\Optimize\Update\PreventUpgrade.ps1" $Tw
            Invoke-AkariTweak $t Apply | Out-Null
            $want = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
            Get-AkariRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'TargetReleaseVersionInfo' | Should Be $want
            Get-AkariRegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ProductVersion' | Should Match '^Windows 1[01]$'
            Invoke-AkariTweak $t Revert | Out-Null
        }
        It 'sets the power mode overlay through powercfg' {
            $t = Import-AkariTweakFile "$Tw\Optimize\Power\PowerMode.ps1" $Tw
            Invoke-AkariTweak $t Revert | Out-Null
            Invoke-AkariTweak $t Apply | Out-Null
            Assert-MockCalled Invoke-AkariPowerCfg -Scope It -ParameterFilter { ($Arguments -join ' ') -eq '/overlaysetactive OVERLAY_SCHEME_MAX' }
        }
    } finally {
        if (Test-Path $tk) { Remove-Item $tk -Recurse -Force }
    }
}
