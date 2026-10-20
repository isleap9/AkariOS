$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# The Customize tweaks with script blocks, run against TestDrive and HKCU:\Software\AkariTest\<guid> only: the real
# user's hive, folders, ProgramData and the Windows version are mocked or redirected, and each test checks the
# redirect first (AGENTS.md rule 12). Explorer and Start are never restarted.

Describe 'Customize: Requires on version-only settings' {
    . "$Core\Loader.ps1"
    $r = Get-AkariTweaks $Tw
    $rows = foreach ($t in @($r.Tweaks | Where-Object { $_.Registry })) { foreach ($e in $t.Registry) { [pscustomobject]@{ T = $t; Path = $e.Path; Name = $e.Name } } }

    It 'marks Windows 11-only values Win11' {
        $w11 = @($rows | Where-Object { $_.Name -in 'TaskbarAl', 'HideRecommendedSection', 'TaskbarMn', 'ShowCopilotButton', 'TaskbarEndTask', 'AllAppsViewMode' -or $_.Path -like '*FeatureManagement\Overrides*' -or $_.Path -like '*\Dsh' })
        $w11.Count | Should BeGreaterThan 0
        @($w11 | Where-Object { $_.T.Requires -notcontains 'Win11' } | ForEach-Object { $_.T.Id }) -join ',' | Should Be ''
    }

    It 'marks Windows 10-only values Win10' {
        $w10 = @($rows | Where-Object { $_.Name -in 'HideSCAMeetNow', 'EnableFeeds' })
        $w10.Count | Should Be 2
        @($w10 | Where-Object { $_.T.Requires -notcontains 'Win10' } | ForEach-Object { $_.T.Id }) -join ',' | Should Be ''
    }
}

Describe 'AkariOS Start pins: one layout in Guided, One-click and Legacy' {
    $dec = { param($t) [Convert]::ToBase64String([Convert]::FromBase64String(($t -replace '-----[^-]+-----', '' -replace '\s', ''))) }
    $guided = & $dec (Get-Content (Join-Path $Tw 'Customize\Start\Files\start2.txt') -Raw)
    $legacy = [regex]::Match((Get-Content (Join-Path $Tw 'Windows.ps1') -Raw), "\`$start2 = '(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)", 'Singleline')

    It 'is the Settings + File Explorer capture (3484 bytes)' { [Convert]::FromBase64String($guided).Length | Should Be 3484 }
    It 'One-click ships the same layout' { & $dec (Get-Content (Join-Path $Root 'OneClick\start2.txt') -Raw) | Should Be $guided }
    It 'the legacy Start menu taskbar row embeds the same layout' {
        $legacy.Success | Should Be $true
        & $dec $legacy.Groups[1].Value | Should Be $guided
    }
}

Describe 'AkariOS marks match OneClick\reg.reg' {
    foreach ($f in 'Registry', 'Loader') { . "$Core\$f.ps1" }
    . "$PSScriptRoot\RegFile.ps1"
    $reg = Read-AkariRegFile (Join-Path $Root 'OneClick\reg.reg')
    # a registry tweak "is AkariOS" when reg.reg sets every one of its values to what Apply sets (a Choice: Recommended)
    $check = foreach ($t in @((Get-AkariTweaks $Tw).Tweaks | Where-Object { $_.Section -ne 'Apps' -and $_.Registry })) {
        $same = @(foreach ($e in $t.Registry) {
            $want = if ($t.Kind -eq 'Choice') { $t.Recommended } else { $e.Value }
            $v = Get-AkariRegFileValue $reg $e
            ("$v" -ne 'absent') -and (Test-AkariRegMatch $v $want)
        })
        [pscustomobject]@{ Id = $t.Id; Marked = $t.AkariOS; Same = -not ($same -contains $false) }
    }

    It 'reads reg.reg' { $reg.Count | Should BeGreaterThan 400 }
    It 'marks only tweaks whose every value reg.reg sets the same way' {
        @($check | Where-Object { $_.Marked -and -not $_.Same } | ForEach-Object { $_.Id }) -join ',' | Should Be ''
    }
    It 'marks every tweak reg.reg fully sets' {
        @($check | Where-Object { $_.Same -and -not $_.Marked } | ForEach-Object { $_.Id }) -join ',' | Should Be ''
    }
}

Describe 'Customize: tweaks with script blocks' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    function Load($rel) { Import-AkariTweakFile (Join-Path $Tw $rel) $Tw }
    # every HKCU path lands under the test key, never in the real hive
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$k\$($Matches[1])" } else { $Path } }
    Mock Get-AkariUserFolder { "$TestDrive\User\$Name" }
    Mock Restart-AkariExplorer { }
    Mock Stop-Process { }
    $realProgramData = $env:ProgramData
    $env:ProgramData = "$TestDrive\ProgramData"

    try {
        It 'redirects the user hive, the user folders and ProgramData (guard)' {
            Resolve-AkariRegPath 'HKCU:\Control Panel\NotifyIconSettings' | Should Be "$k\Control Panel\NotifyIconSettings"
            Get-AkariUserFolder 'Programs' | Should Be "$TestDrive\User\Programs"
            $env:ProgramData | Should Be "$TestDrive\ProgramData"
        }

        Context 'Show all tray icons, Windows 11' {
            Mock Get-AkariOSBuild { 26100 }
            $t = Load 'Customize\Taskbar\ShowAllTrayIcons.ps1'
            New-Item "$k\Control Panel\NotifyIconSettings\1" -Force | Out-Null
            New-Item "$k\Control Panel\NotifyIconSettings\2" -Force | Out-Null
            Set-ItemProperty "$k\Control Panel\NotifyIconSettings\2" 'IsPromoted' 0
            It 'reads Default, Applies (every icon promoted), Reverts (every icon back in the overflow)' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$k\Control Panel\NotifyIconSettings\1").IsPromoted | Should Be 1
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty "$k\Control Panel\NotifyIconSettings\2").IsPromoted | Should Be 0
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Show all tray icons, Windows 10' {
            Mock Get-AkariOSBuild { 19045 }
            $t = Load 'Customize\Taskbar\ShowAllTrayIcons.ps1'
            It 'uses EnableAutoTray' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-ItemProperty "$k\Software\Microsoft\Windows\CurrentVersion\Explorer").EnableAutoTray | Should Be 0
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty "$k\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue).EnableAutoTray | Should BeNullOrEmpty
            }
        }

        Context 'Unpin all taskbar apps' {
            $t = Load 'Customize\Taskbar\UnpinAll.ps1'
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' ([byte[]](1, 2)) 'Binary'
            New-Item "$TestDrive\User\AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" -ItemType Directory -Force | Out-Null
            It 'clears the Taskband key and the pinned shortcuts' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Test-Path "$k\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" | Should Be $false
                Test-Path "$TestDrive\User\AppData\Microsoft\Internet Explorer\Quick Launch" | Should Be $false
            }
        }

        Context 'Hide Accessibility and Accessories' {
            $t = Load 'Customize\Start\HideAccessibilityFolders.ps1'
            $mine = "$TestDrive\User\Programs\Accessibility"
            $all = "$TestDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories"
            New-Item $mine, $all -ItemType Directory -Force | Out-Null
            Set-Content "$all\Paint.lnk" 'x'
            Set-Content "$all\desktop.ini" 'x'
            (Get-Item "$all\desktop.ini" -Force).Attributes = 'Hidden, System'
            It 'hides the folders and their contents, leaves System files alone, and shows them again' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                [bool]((Get-Item "$all\Paint.lnk" -Force).Attributes -band [IO.FileAttributes]::Hidden) | Should Be $true
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                [bool]((Get-Item $mine -Force).Attributes -band [IO.FileAttributes]::Hidden) | Should Be $false
                [bool]((Get-Item "$all\desktop.ini" -Force).Attributes -band [IO.FileAttributes]::Hidden) | Should Be $true
            }
        }

        Context 'AkariOS Start pins, Windows 11' {
            Mock Get-AkariOSBuild { 26100 }
            $t = Load 'Customize\Start\AkariOSPins.ps1'
            $bin = "$TestDrive\User\Local AppData\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
            It 'writes the AkariOS start2.bin, reads it as Optimized, and Revert lets Windows rebuild its own' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-Item $bin).Length | Should Be 3484
                Get-AkariState $t | Should Be 'Optimized'
                Assert-MockCalled Stop-Process -ParameterFilter { $Name -eq 'StartMenuExperienceHost' }
                [IO.File]::WriteAllBytes($bin, [byte[]](1, 2, 3))
                Get-AkariState $t | Should Be 'Custom'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Test-Path $bin | Should Be $false
            }
        }

        Context 'AkariOS Start shortcuts' {
            $t = Load 'Customize\Start\AkariOSShortcuts.ps1'
            New-Item "$TestDrive\ProgramData\Microsoft\Windows\Start Menu\Programs" -ItemType Directory -Force | Out-Null
            It 'adds the five shortcuts, then reports Already' {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                @(Get-ChildItem "$TestDrive\ProgramData\Microsoft\Windows\Start Menu\Programs" -Filter *.lnk).Count | Should Be 5
                $s = (New-Object -ComObject WScript.Shell).CreateShortcut("$TestDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup Programs 1.lnk")
                $s.TargetPath | Should Be "$TestDrive\User\Programs\Startup"
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Already'
            }
        }
    } finally {
        $env:ProgramData = $realProgramData
        Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
    }
}
