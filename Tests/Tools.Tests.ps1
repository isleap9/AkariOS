$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# Section Tools (Optimize > Advanced batch 2) and the Open buttons that came with it. Every program start, download,
# winget call and restart is mocked (AGENTS.md rule 12): nothing opens, installs or restarts.

Describe 'Find-AkariProgram' {
    foreach ($f in 'Log', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    New-Item "$TestDrive\pf\Vendor\Tool" -ItemType Directory -Force | Out-Null
    Set-Content "$TestDrive\pf\Vendor\Tool\tool.exe" 'x'

    Context 'a portable winget package' {
        Mock Get-AkariWingetExe { 'C:\WinGet\Packages\Tool\tool.exe' }
        It 'takes the winget copy first' { Find-AkariProgram 'Vendor.Tool' 'tool.exe' @("$TestDrive\pf") | Should Be 'C:\WinGet\Packages\Tool\tool.exe' }
    }

    Context 'an installed program' {
        Mock Get-AkariWingetExe { $null }
        It 'finds it two folders down in Program Files' { Find-AkariProgram 'Vendor.Tool' 'tool.exe' @("$TestDrive\pf") | Should Be "$TestDrive\pf\Vendor\Tool\tool.exe" }
        It 'returns nothing when it is not there' { Find-AkariProgram 'Vendor.Tool' 'other.exe' @("$TestDrive\pf") | Should BeNullOrEmpty }
    }
}

Describe 'Open-AkariWingetTool' {
    foreach ($f in 'Log', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    Mock Start-Process { }
    Mock Install-AkariWingetPackage { }

    Context 'already installed' {
        Mock Find-AkariProgram { 'C:\Tool\tool.exe' }
        It 'opens it without installing' {
            Open-AkariWingetTool 'Vendor.Tool' 'tool.exe'
            Assert-MockCalled Install-AkariWingetPackage -Exactly 0 -Scope It
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'C:\Tool\tool.exe' }
        }
    }

    Context 'missing' {
        $script:found = $null
        Mock Find-AkariProgram { $script:found }
        Mock Install-AkariWingetPackage { $script:found = 'C:\Tool\tool.exe' }
        It 'installs it with winget, then opens it' {
            Open-AkariWingetTool 'Vendor.Tool' 'tool.exe'
            Assert-MockCalled Install-AkariWingetPackage -Exactly 1 -Scope It -ParameterFilter { $Id -eq 'Vendor.Tool' }
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'C:\Tool\tool.exe' }
        }
    }

    Context 'installed, but the program is not found' {
        Mock Find-AkariProgram { $null }
        It 'says so' { { Open-AkariWingetTool 'Vendor.Tool' 'tool.exe' } | Should Throw 'tool.exe was not found' }
    }
}

Describe 'Get-AkariUserFolder Downloads' {
    foreach ($f in 'Log', 'Registry') { . "$Core\$f.ps1" }
    Context 'Windows knows it' {
        Mock Get-AkariRegValue { if ($Name -eq '{374DE290-123F-4565-9164-39C4925E467B}') { 'D:\Downloads' } }
        It 'reads it under its GUID name' { Get-AkariUserFolder 'Downloads' | Should Be 'D:\Downloads' }
    }
    Context 'not set' {
        Mock Get-AkariRegValue { if ($Name -eq 'ProfileImagePath') { 'C:\Users\me' } }
        Mock Get-AkariUserSid { 'S-1-5-21-test' }
        It 'falls back to the profile''s Downloads' { Get-AkariUserFolder 'Downloads' | Should Be 'C:\Users\me\Downloads' }
    }
}

Describe 'Tools > Drivers' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    New-Item "$TestDrive\PF\7-Zip", "$TestDrive\Windows\Temp", "$TestDrive\Downloads" -ItemType Directory -Force | Out-Null
    Set-Content "$TestDrive\PF\7-Zip\7z.exe" 'x'
    Mock Get-AkariUserFolder { "$TestDrive\Downloads" }
    Mock Start-Process { }
    Mock Save-AkariFile { $OutFile }
    Mock New-AkariShortcut { }
    Mock Install-AkariWingetPackage { }
    Mock Add-AppxPackage { }
    Mock Remove-AkariStartup { }
    Mock Remove-AkariService { }
    Mock Uninstall-AkariMsi { }
    Mock Unregister-ScheduledTask { }
    Mock Stop-Process { }
    Mock Stop-Service { }
    Mock Expand-Archive { }
    Mock Get-AkariGpus { @([pscustomobject]@{ Vendor = 'NVIDIA' }, [pscustomobject]@{ Vendor = 'AMD' }, [pscustomobject]@{ Vendor = 'Intel' }) }
    # 7-Zip "unpacks" by making the folder it was given
    Mock Invoke-AkariExe { $o = @($Arguments | Where-Object { $_ -like '-o*' }); if ($o) { New-Item $o[0].Substring(2) -ItemType Directory -Force | Out-Null }; 0 }
    Mock Invoke-WebRequest {
        if ($Uri -like '*DriverManualLookup*') { [pscustomobject]@{ Content = '{"Success":"1","IDS":[{"downloadInfo":{"Success":"1","ID":"249315","Version":"581.29","Name":"GeForce Game Ready Driver"}}]}' } }
        elseif ($Uri -like 'https://www.amd.com/*') { [pscustomobject]@{ Links = @([pscustomobject]@{ href = 'https://drivers.amd.com/drivers/installer/25.10/whql/amd-software-adrenalin-edition-25.10.1-minimalsetup-251001_web.exe' }) } }
    }

    # every Windows, Program Files and drive path goes to TestDrive: the driver files the Actions unpack, strip and
    # delete are fakes there. Set after the mocks (they load their modules from the real Windows), restored in finally.
    $real = @{ SystemRoot = $env:SystemRoot; SystemDrive = $env:SystemDrive; ProgramFiles = $env:ProgramFiles; PF86 = ${env:ProgramFiles(x86)} }
    try {
        $env:SystemRoot = "$TestDrive\Windows"; $env:SystemDrive = "$TestDrive"; $env:ProgramFiles = "$TestDrive\PF"; ${env:ProgramFiles(x86)} = "$TestDrive\PF86"
        It 'are Actions in Tools > Drivers for their vendor' {
            foreach ($p in @(@('DriverNvidia', 'NVIDIA'), @('DriverNvidiaDebloat', 'NVIDIA'), @('DriverAmd', 'AMD'), @('DriverAmdDebloat', 'AMD'),
                             @('DriverIntel', 'Intel'), @('DriverIntelDebloat', 'Intel'))) {
                $t = Load "Tools\Drivers\$($p[0]).ps1"
                "$($p[0]) $($t.Kind) $($t.Requires)" | Should Be "$($p[0]) Action $($p[1])"
            }
        }

        Context 'DDU' {
            It 'clean: SafeMode, restarts itself, gets DDU ready first (Prepare), then removes GPU and audio drivers' {
                $t = Load 'Tools\Drivers\DduClean.ps1'
                "$($t.SafeMode) $($t.Restarts) $($t.Risk)" | Should Be 'True True Advanced'
                $o = Invoke-AkariPrepare $t @{ Id = $t.Id; Mode = 'Apply' }
                $o | Should BeNullOrEmpty
                Assert-MockCalled Save-AkariFile -Exactly 1 -Scope It -ParameterFilter { $Name -eq 'ddu.exe' }
                $cfg = "$TestDrive\Windows\Temp\ddu\Settings\Settings.xml"
                Get-Content $cfg -Raw | Should Match '<CheckUpdates>False</CheckUpdates>'
                (Get-Item $cfg).IsReadOnly | Should Be $true
                Set-Content "$TestDrive\Windows\Temp\ddu\Display Driver Uninstaller.exe" 'x'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*\Display Driver Uninstaller.exe' -and "$ArgumentList" -match '-CleanAllGpus' -and "$ArgumentList" -match '-Restart' }
            }
            It 'manual: SafeMode, opens DDU and waits for it' {
                $t = Load 'Tools\Drivers\DduManual.ps1'
                "$($t.SafeMode) $($t.Restarts)" | Should Be 'True False'
                $t.Prepare | Should Not BeNullOrEmpty
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*\Display Driver Uninstaller.exe' -and -not $ArgumentList -and $Wait }
            }
        }

        Context 'Install latest driver' {
            It 'NVIDIA: downloads the latest WHQL driver NVIDIA''s lookup names and starts its installer' {
                $o = Invoke-AkariTweak (Load 'Tools\Drivers\DriverNvidia.ps1') Apply
                "$($o.Outcome) $($o.Message)".Trim() | Should Be 'Applied'
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter { $Uri -eq 'https://international.download.nvidia.com/Windows/581.29/581.29-desktop-win10-win11-64bit-international-dch-whql.exe' }
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*\nvidiadriver.exe' }
            }
            It 'AMD: downloads the Adrenalin minimal setup from AMD''s page and starts it' {
                (Invoke-AkariTweak (Load 'Tools\Drivers\DriverAmd.ps1') Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter { $Uri -like '*minimalsetup*' -and $OutFile }
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*\amddriver.exe' }
            }
            It 'Intel: opens Intel''s driver page' {
                (Invoke-AkariTweak (Load 'Tools\Drivers\DriverIntel.ps1') Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like 'https://www.intel.com/*' }
            }
        }

        Context 'Install latest driver, debloated: NVIDIA' {
            It 'strips the latest driver, installs it silently and adds the NVIDIA Control Panel' {
                $t = Load 'Tools\Drivers\DriverNvidiaDebloat.ps1'
                $t.Reboot | Should Be $true
                # 7-Zip "unpacks" a driver with a part to strip and one to keep
                Mock Invoke-AkariExe { if ($Arguments -contains 'x') { New-Item "$TestDrive\Windows\Temp\nvidiadriver\NvTelemetry", "$TestDrive\Windows\Temp\nvidiadriver\Display.Driver" -ItemType Directory -Force | Out-Null }; 0 }
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Test-Path "$TestDrive\Windows\Temp\nvidiadriver\NvTelemetry" | Should Be $false
                Test-Path "$TestDrive\Windows\Temp\nvidiadriver\Display.Driver" | Should Be $true
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { $Path -like '*\nvidiadriver\setup.exe' -and ($Arguments -join ' ') -eq '-s -noreboot -noeula -clean' }
                Assert-MockCalled Save-AkariFile -Exactly 1 -Scope It -ParameterFilter { $Name -eq 'nvp.appx' }
                Assert-MockCalled Add-AppxPackage -Exactly 1 -Scope It
            }
        }

        Context 'Install latest driver, debloated: AMD and Intel with no download' {
            It 'open the vendor''s page and fail, asking to download it first' {
                foreach ($p in @(@('DriverAmdDebloat', 'https://www.amd.com/*'), @('DriverIntelDebloat', 'https://www.intel.com/*'))) {
                    $o = Invoke-AkariTweak (Load "Tools\Drivers\$($p[0]).ps1") Apply
                    $o.Outcome | Should Be 'Failed'
                    $o.Message | Should Match 'Downloads'
                    $u = $p[1]
                    Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like $u }
                }
            }
        }

        Context 'Install latest driver, debloated: AMD' {
            It 'takes the newest full package from Downloads, turns its extras off, installs it and removes AMD''s background parts' {
                Set-Content "$TestDrive\Downloads\whql-amd-software-adrenalin-edition-25.10.1-win10-win11-oct.exe" 'x'
                Set-Content "$TestDrive\Downloads\amd-software-adrenalin-edition-25.10.1-minimalsetup-251001_web.exe" 'x'
                $cfg = "$TestDrive\Windows\Temp\amddriver\Config"
                # 7-Zip "unpacks" two config files; when setup starts, what they say is kept (the Action deletes them after)
                $script:atConfig = $null
                Mock Invoke-AkariExe {
                    if ($Arguments -contains 'x') { New-Item $cfg -ItemType Directory -Force | Out-Null; Set-Content "$cfg\AMDUpdater.xml" '<Enabled>true</Enabled><Hidden>true</Hidden>' -NoNewline; Set-Content "$cfg\InstallManifest.json" '"InstallByDefault" : "Yes"' -NoNewline }
                    elseif ($Path -like '*ATISetup.exe') { $script:atConfig = (Get-Content "$cfg\AMDUpdater.xml" -Raw) + '|' + (Get-Content "$cfg\InstallManifest.json" -Raw) }
                    0
                }
                (Invoke-AkariTweak (Load 'Tools\Drivers\DriverAmdDebloat.ps1') Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { ($Arguments -join ' ') -like 'x *whql-amd-software-adrenalin-edition*' }
                $script:atConfig | Should Be '<Enabled>false</Enabled><Hidden>false</Hidden>|"InstallByDefault" : "No"'
                Test-Path "$TestDrive\Downloads\whql-amd-software-adrenalin-edition-25.10.1-win10-win11-oct.exe" | Should Be $false
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { $Path -like '*\amddriver\Bin64\ATISetup.exe' }
                Assert-MockCalled Remove-AkariService -Scope It -ParameterFilter { $Name -eq 'amdfendr' }
                Assert-MockCalled Uninstall-AkariMsi -Exactly 1 -Scope It -ParameterFilter { $Name -eq '*AMD Install Manager*' }
            }
        }

        Context 'Install latest driver, debloated: Intel' {
            It 'takes the newest package from Downloads, installs it with no extras and removes Intel''s background parts' {
                Set-Content "$TestDrive\Downloads\gfx_win_101.6130.exe" 'x'
                Mock Invoke-AkariExe { 0 }
                (Invoke-AkariTweak (Load 'Tools\Drivers\DriverIntelDebloat.ps1') Apply).Outcome | Should Be 'Applied'
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { $Path -like '*\inteldriver\Installer.exe' -and ($Arguments -join ' ') -eq '-f --noExtras --terminateProcesses -s' }
                Assert-MockCalled Remove-AkariService -Scope It -ParameterFilter { $Name -eq 'IntelGFXFWupdateTool' }
            }
        }

        Context 'Controller overclock' {
            It 'installs hidusbf''s filter driver and opens its Setup' {
                New-Item "$TestDrive\PF86\hidusbf\hidusbf (BB11.5.25)\DRIVER" -ItemType Directory -Force | Out-Null
                Mock Invoke-AkariExe { 0 }
                $t = Load 'Tools\Drivers\ControllerOverclock.ps1'
                "$($t.Kind) $($t.Risk)" | Should Be 'Action Advanced'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Test-Path "$TestDrive\PF86\hidusbf\DRIVER" | Should Be $true
                Assert-MockCalled Save-AkariFile -Exactly 1 -Scope It -ParameterFilter { $Name -eq 'hidusbf.zip' }
                Assert-MockCalled Invoke-AkariExe -Exactly 1 -Scope It -ParameterFilter { $Path -eq 'rundll32.exe' -and ($Arguments -join ' ') -like '*InstallHinfSection DefaultInstall 132 *HIDUSBF_AS.INF' }
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*\hidusbf\DRIVER\Setup.exe' }
            }
        }
    } finally {
        $env:SystemRoot = $real.SystemRoot; $env:SystemDrive = $real.SystemDrive; $env:ProgramFiles = $real.ProgramFiles; ${env:ProgramFiles(x86)} = $real.PF86
    }
}

Describe 'Update blocks (group policy)' {
    foreach ($f in 'Log', 'Registry', 'Loader') { . "$Core\$f.ps1" }
    $u = Join-Path $Tw 'Optimize\Update'
    It 'are Advanced-only Toggles for Pro and up that delete their policies on Revert' {
        foreach ($p in @(@('BlockDriverUpdatesPolicy.ps1', 9), @('BlockWindowsUpdate.ps1', 7))) {
            $t = Import-AkariTweakFile (Join-Path $u $p[0]) $Tw
            "$($p[0]) $($t.Kind) $($t.Requires) $($t.Guided) $($t.Risk) $(@($t.Registry).Count)" | Should Be "$($p[0]) Toggle Pro False Advanced $($p[1])"
            @($t.Registry | Where-Object { $null -ne $_.Default -or $_.Path -notlike 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\*' }).Count | Should Be 0
        }
    }
    It 'points Windows Update at a dead local server' {
        $t = Import-AkariTweakFile (Join-Path $u 'BlockWindowsUpdate.ps1') $Tw
        @($t.Registry | Where-Object { $_.Name -in 'WUServer', 'WUStatusServer', 'UpdateServiceUrlAlternate' } | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ',' | Should Be 'http://127.0.0.1'
    }
}

Describe 'Batch 2c' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Start-Process { }
    Mock Save-AkariFile { $OutFile }
    Mock New-AkariShortcut { }
    Mock Open-AkariWingetTool { }
    Mock Get-AkariGpus { @([pscustomobject]@{ Vendor = 'NVIDIA' }) }
    # Profile Inspector is "there", the DRS folder is not touched
    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like '*Nvidia Profile Inspector.exe' }
    Mock Unblock-File { }

    It 'Autoruns and the three Opens' {
        (Invoke-AkariTweak (Load 'Tools\Check\Autoruns.ps1') Apply).Outcome | Should Be 'Applied'
        Assert-MockCalled Open-AkariWingetTool -Exactly 1 -Scope It -ParameterFilter { $Id -eq 'Microsoft.Sysinternals.Autoruns' -and $Exe -eq 'Autoruns64.exe' }
        foreach ($p in @(@('InstalledPrograms', 'appwiz.cpl'), @('WindowsFeatures', 'optionalfeatures.exe'), @('OptionalFeatures', 'ms-settings:optionalfeatures'))) {
            (Invoke-AkariTweak (Load "Tools\Check\$($p[0]).ps1") Apply).Outcome | Should Be 'Applied'
            $u = $p[1]
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq $u }
        }
    }

    It 'the startup cleanup and the restore point are Tools buttons now' {
        "$((Load 'Tools\Cleanup\StartupCleanup.ps1').Section)/$((Load 'Tools\Cleanup\StartupCleanup.ps1').Category)" | Should Be 'Tools/Cleanup'
        "$((Load 'Tools\Setup\RestorePoint.ps1').Section)/$((Load 'Tools\Setup\RestorePoint.ps1').Category)" | Should Be 'Tools/Setup'
    }

    It 'the removed legacy apps come back in Downloads'' restore card' {
        $o = Load 'Apps\Install\OneDrive.ps1'
        "$($o.AppType) $($o.Winget)" | Should Be 'Restore removed apps Microsoft.OneDrive'
        Mock Test-Path { $false } -ParameterFilter { $Path -like '*\mstsc.exe' -or $Path -like '*\SnippingTool.exe' }
        foreach ($p in @(@('RemoteDesktopConnection', 'remotedesktopconnection.exe'), @('SnippingToolLegacy', 'snippingtool.exe'))) {
            $t = Load "Apps\Install\$($p[0]).ps1"
            $t.AppType | Should Be 'Restore removed apps'
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            $n = $p[1]
            Assert-MockCalled Save-AkariFile -Exactly 1 -Scope It -ParameterFilter { $Name -eq $n }
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like "*\$n" -and $Wait }
        }
    }

    Context 'ReBar' {
        It 'Apply merges rBAR on into the driver profile' {
            $t = Load 'Hardware\Graphics\ReBarForce.ps1'
            "$($t.Kind) $($t.Requires) $($t.Guided) $($t.Risk)" | Should Be 'Toggle NVIDIA False Advanced'
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { "$ArgumentList" -like '-silentImport -mergeImport -silent *nvidia-rebar-on.nip"' }
            Get-AkariState $t | Should Be 'Optimized'
        }
    }

    Context 'ReBar: Revert with FR33THY''s NVIDIA settings applied' {
        Mock Get-AkariRegValue { if ($Name -eq 'NvCplPhysxAuto') { 0 } elseif ($Name -eq 'NvDevToolsVisible') { 1 } }
        It 'imports FR33THY''s base profile again, without rBAR' {
            Set-AkariRememberedState 'graphics-nvidia-rebar-force' $true
            (Invoke-AkariTweak (Load 'Hardware\Graphics\ReBarForce.ps1') Revert).Outcome | Should Be 'Reverted'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { "$ArgumentList" -like '-silentImport -silent *nvidia-base-profile.nip"' }
        }
    }

    Context 'ReBar: Revert without them' {
        Mock Get-AkariRegValue { $null }
        It 'imports the empty profile (driver defaults)' {
            Set-AkariRememberedState 'graphics-nvidia-rebar-force' $true
            (Invoke-AkariTweak (Load 'Hardware\Graphics\ReBarForce.ps1') Revert).Outcome | Should Be 'Reverted'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { "$ArgumentList" -like '-silentImport -silent *nvidia-default-profile.nip"' }
            Get-AkariState (Load 'Hardware\Graphics\ReBarForce.ps1') | Should Be 'Default'
        }
    }
}

Describe 'Tools tweaks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Winget', 'AppSetup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    Mock Start-Process { }
    Mock Save-AkariFile { $OutFile }
    Mock New-AkariShortcut { }
    Mock Open-AkariWingetTool { }
    Mock Invoke-WebRequest { }
    Mock Restart-AkariFirmware { 0 }
    Mock Set-Clipboard { }
    Mock Get-AkariEdition { 'Core' }
    # the polling tools are not on this PC yet, whatever the real Program Files holds
    Mock Test-Path { $false } -ParameterFilter { $LiteralPath -like '*\Polling\*' -or $LiteralPath -like '*\Mouse Movement Recorder\*' }
    Mock Get-CimInstance { if ($ClassName -eq 'Win32_BaseBoard') { [pscustomobject]@{ Manufacturer = 'ASUSTeK'; Product = 'ROG STRIX B650E-F' } } else { [pscustomobject]@{ SMBIOSBIOSVersion = '3024'; ReleaseDate = [datetime]'2025-05-01' } } }
    Mock Get-Volume { [pscustomobject]@{ DriveLetter = 'C'; Size = 1000; SizeRemaining = 250 } }

    It 'are Actions in Section Tools with a reason for no Revert' {
        foreach ($f in @(Get-ChildItem (Join-Path $Tw 'Tools') -Recurse -Filter *.ps1 | Where-Object { $_.Directory.Name -ne 'Files' })) {
            $t = Load $f.FullName.Substring($Tw.Length + 1)
            "$($f.Name) $($t.Section) $($t.Kind)" | Should Be "$($f.Name) Tools Action"
            (Get-Content $f.FullName -Raw) -match '# Action: ' | Should Be $true
        }
    }

    Context 'Open buttons in their Category (Advanced only)' {
        It 'open their page' {
            foreach ($p in @(@('Hardware\Graphics\OpenDisplay.ps1', 'ms-settings:display'), @('Customize\System\OpenDateTime.ps1', 'ms-settings:dateandtime'),
                             @('Optimize\Performance\OpenStartupApps.ps1', 'ms-settings:startupapps'), @('Optimize\Performance\OpenStartupTaskManager.ps1', 'taskmgr.exe'))) {
                $a = Load $p[0]
                "$($p[0]) $($a.Kind) $($a.Button) $($a.Guided)" | Should Be "$($p[0]) Action Open False"
                (Invoke-AkariTweak $a Apply).Outcome | Should Be 'Applied'
                $u = $p[1]
                Assert-MockCalled Start-Process -Scope It -ParameterFilter { $FilePath -eq $u }
            }
        }
    }

    Context 'Check' {
        It 'BIOS check logs the board and BIOS, then searches for its BIOS (no restart)' {
            (Invoke-AkariTweak (Load 'Tools\Check\BiosCheck.ps1') Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like 'https://www.google.com/search?q=ASUSTeK%20ROG%20STRIX%20B650E-F%20BIOS*' }
            Assert-MockCalled Restart-AkariFirmware -Exactly 0 -Scope It
            @($LogQueue.ToArray()) -match 'ROG STRIX B650E-F.*3024' | Should Not BeNullOrEmpty
        }
        It 'storage check logs free space and opens This PC' {
            (Invoke-AkariTweak (Load 'Tools\Check\StorageCheck.ps1') Apply).Outcome | Should Be 'Applied'
            @($LogQueue.ToArray()) -match 'C: 25% free' | Should Not BeNullOrEmpty
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'explorer.exe' -and "$ArgumentList" -eq 'shell:MyComputerFolder' }
        }
        It 'RAM, GPU, OCCT and FurMark open their program, installed through winget when missing' {
            foreach ($p in @(@('RamCheck', 'CPUID.CPU-Z', 'cpuz.exe'), @('GpuCheck', 'TechPowerUp.GPU-Z', 'GPU-Z.exe'),
                             @('Occt', 'OCBase.OCCT.Personal', 'OCCT*.exe'), @('FurMark', 'Geeks3D.FurMark.2', 'FurMark_GUI.exe'))) {
                (Invoke-AkariTweak (Load "Tools\Check\$($p[0]).ps1") Apply).Outcome | Should Be 'Applied'
                $wid = $p[1]; $wexe = $p[2]
                Assert-MockCalled Open-AkariWingetTool -Exactly 1 -Scope It -ParameterFilter { $Id -eq $wid -and $Exe -eq $wexe }
            }
        }
        It 'the polling tests download their tool from AkariOS-Files, add a Start-menu shortcut and open it' {
            foreach ($p in @(@('MousePollingTest', 'mousemovementrecorder.exe', 'Mouse Movement Recorder'), @('ControllerPollingTest', 'polling.exe', 'Polling'))) {
                (Invoke-AkariTweak (Load "Tools\Check\$($p[0]).ps1") Apply).Outcome | Should Be 'Applied'
                $n = $p[1]; $s = $p[2]
                Assert-MockCalled Save-AkariFile -Exactly 1 -Scope It -ParameterFilter { $Name -eq $n }
                Assert-MockCalled New-AkariShortcut -Exactly 1 -Scope It -ParameterFilter { $Name -eq $s }
                Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like "*\$s\*.exe" }
            }
        }
        It 'the monitor and bufferbloat tests open their web page' {
            (Invoke-AkariTweak (Load 'Tools\Check\MonitorTest.ps1') Apply).Outcome | Should Be 'Applied'
            (Invoke-AkariTweak (Load 'Tools\Check\BufferbloatTest.ps1') Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like 'https://www.testufo.com/*' }
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'https://www.waveform.com/tools/bufferbloat' }
        }
    }

    Context 'Refresh' {
        It 'factory reset and local account open Windows'' own pages' {
            (Invoke-AkariTweak (Load 'Tools\Refresh\FactoryReset.ps1') Apply).Outcome | Should Be 'Applied'
            (Invoke-AkariTweak (Load 'Tools\Refresh\LocalAccount.ps1') Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'ms-settings:recovery' }
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'netplwiz.exe' }
        }
        It 'reinstall downloads Microsoft''s Media Creation Tool for each version and starts it' {
            foreach ($p in @(@('ReinstallWindows10', 'LinkId=691209'), @('ReinstallWindows11', 'linkid=2156295'))) {
                (Invoke-AkariTweak (Load "Tools\Refresh\$($p[0]).ps1") Apply).Outcome | Should Be 'Applied'
                $l = $p[1]
                Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter { $Uri -like "https://go.microsoft.com/fwlink/?$l" }
            }
            Assert-MockCalled Start-Process -Exactly 2 -Scope It -ParameterFilter { $FilePath -like '*MediaCreationTool*.exe' }
        }
        It 'network driver searches for the board''s network driver' {
            (Invoke-AkariTweak (Load 'Tools\Refresh\NetworkDriver.ps1') Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like 'https://www.google.com/search?q=ASUSTeK%20ROG%20STRIX%20B650E-F%20network%20driver*' }
        }
        It 'restart to BIOS asks first and restarts into the firmware' {
            $t = Load 'Tools\Refresh\RestartToBios.ps1'
            $t.Confirm | Should Not BeNullOrEmpty
            Test-AkariRestarts $t 'Apply' | Should Be $true
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Restart-AkariFirmware -Exactly 1 -Scope It
        }
    }

    Context 'Refresh: no UEFI' {
        Mock Restart-AkariFirmware { 1 }
        It 'fails when the PC can''t restart into its firmware' {
            (Invoke-AkariTweak (Load 'Tools\Refresh\RestartToBios.ps1') Apply).Outcome | Should Be 'Failed'
        }
    }

    Context 'Setup' {
        It 'activation opens Windows'' own activation page' {
            (Invoke-AkariTweak (Load 'Tools\Setup\Activation.ps1') Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'ms-settings:activation' }
        }
        It 'Home to Pro shows on Home only, copies the generic Pro key and opens the product key dialog' {
            $t = Load 'Tools\Setup\HomeToPro.ps1'
            $t.Requires -join ',' | Should Be 'Home'
            (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
            Assert-MockCalled Set-Clipboard -Exactly 1 -Scope It -ParameterFilter { $Value -eq 'VK7JG-NPHTM-C97JM-9MPGT-3V66T' }
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*SystemSettingsAdminFlows.exe' -and "$ArgumentList" -eq 'EnterProductKey' }
        }
    }
}
