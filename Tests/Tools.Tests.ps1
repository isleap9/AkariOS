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
        foreach ($f in @(Get-ChildItem (Join-Path $Tw 'Tools') -Recurse -Filter *.ps1)) {
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
