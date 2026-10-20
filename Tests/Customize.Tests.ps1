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
        $w11 = @($rows | Where-Object { $_.Name -in 'TaskbarAl', 'HideRecommendedSection', 'TaskbarMn', 'ShowCopilotButton', 'TaskbarEndTask', 'AllAppsViewMode' -or $_.Path -like '*FeatureManagement\Overrides*' -or $_.Path -like '*Policies\Microsoft\Dsh' })
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
    # registry tweaks One-click sets in a script instead of reg.reg (checked by hand against OneClick\steptwo.ps1)
    $byScript = @(
        'explorer-trim-context-menu'   # steptwo.ps1 "remove context menu items", lines ~797-829
        'system-no-windows-backup'     # its CDPUserSvc Start = 4 row: steptwo.ps1 line ~410
        'power-fast-startup-off'       # steptwo.ps1 power plan part, line ~1004
        'power-throttling-off'         # steptwo.ps1 power plan part, line ~1007
    )

    It 'marks only tweaks whose every value reg.reg sets the same way' {
        @($check | Where-Object { $_.Marked -and -not $_.Same -and $_.Id -notin $byScript } | ForEach-Object { $_.Id }) -join ',' | Should Be ''
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
    # every HKCU and HKLM path lands under the test key, never in the real hives
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$k\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$k\HKLM\$($Matches[1])" } else { $Path } }
    Mock Get-AkariUserFolder { "$TestDrive\User\$Name" }
    Mock Restart-AkariExplorer { }
    Mock Stop-Process { }
    Mock Set-AkariDesktopWallpaper { }
    $realProgramData = $env:ProgramData
    $env:ProgramData = "$TestDrive\ProgramData"
    $realSystemRoot = $env:SystemRoot

    try {
        It 'redirects the user hive, the machine hive, the user folders and ProgramData (guard)' {
            Resolve-AkariRegPath 'HKCU:\Control Panel\NotifyIconSettings' | Should Be "$k\Control Panel\NotifyIconSettings"
            Resolve-AkariRegPath 'HKLM:\SOFTWARE\Classes\*\shell' | Should Be "$k\HKLM\SOFTWARE\Classes\*\shell"
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
        Context 'Trim the right-click menu, Windows 11' {
            Mock Get-AkariOSBuild { 26100 }
            $t = Load 'Customize\Explorer\TrimContextMenu.ps1'
            $fav = "$k\HKLM\SOFTWARE\Classes\*\shell\pintohomefile"
            # siblings of the '*' key that a wildcard would also hit
            New-Item "$k\HKLM\SOFTWARE\Classes\txtfile\shell\pintohomefile" -Force | Out-Null
            It 'Revert builds Windows'' entries, Apply removes them (only under *), Revert brings them back' {
                Invoke-AkariRegistry $t.Registry Revert
                Get-AkariState $t | Should Be 'Default'
                (Get-ItemProperty -LiteralPath $fav).MUIVerb | Should Be '@shell32.dll,-51608'
                (Get-Item -LiteralPath "$k\HKLM\SOFTWARE\Classes\exefile\shellex\ContextMenuHandlers\Compatibility").GetValue('') | Should Be '{1d27f844-3a1f-4410-85ac-14651078412d}'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Test-Path -LiteralPath $fav | Should Be $false
                Test-Path -LiteralPath "$k\HKLM\SOFTWARE\Classes\Folder\shell\pintohome" | Should Be $false
                Test-Path -LiteralPath "$k\HKLM\SOFTWARE\Classes\txtfile\shell\pintohomefile" | Should Be $true
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                (Get-ItemProperty -LiteralPath "$fav\command").DelegateExecute | Should Be '{b455f46e-e4af-4035-b0a4-cf18d2f6f28e}'
                Get-AkariState $t | Should Be 'Default'
            }
        }

        Context 'Trim the right-click menu, Windows 10' {
            Mock Get-AkariOSBuild { 19045 }
            Mock Resolve-AkariDefault { if ($Default -is [hashtable] -and $Default.ContainsKey('Win10')) { $Default['Win10'] } else { $Default } }
            $t = Load 'Customize\Explorer\TrimContextMenu.ps1'
            It 'Revert does not create Add to Favorites (Windows 11 only)' {
                Remove-Item "$k\HKLM\SOFTWARE\Classes\*" -Recurse -Force -ErrorAction SilentlyContinue
                Invoke-AkariRegistry $t.Registry Revert
                Test-Path -LiteralPath "$k\HKLM\SOFTWARE\Classes\*\shell\pintohomefile" | Should Be $false
                Test-Path -LiteralPath "$k\HKLM\SOFTWARE\Classes\Folder\shell\pintohome" | Should Be $true
            }
        }

        Context 'Classic right-click menu' {
            $t = Load 'Customize\Explorer\ClassicContextMenu.ps1'
            $clsid = "$k\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
            It 'writes an empty (default) under InprocServer32, and Revert deletes the whole key' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                (Get-Item -LiteralPath "$clsid\InprocServer32").GetValue('') | Should Be ''
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Test-Path -LiteralPath $clsid | Should Be $false
            }
        }

        Context 'Black lock screen' {
            $env:SystemRoot = "$TestDrive\Windows"
            New-Item $env:SystemRoot -ItemType Directory -Force | Out-Null
            $t = Load 'Customize\Theme\BlackLockScreen.ps1'
            It 'makes a black image, points the lock screen at it, and Revert removes both' {
                try {
                    Get-AkariState $t | Should Be 'Default'
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    Test-Path "$TestDrive\Windows\Black.jpg" | Should Be $true
                    (Get-ItemProperty "$k\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP").LockScreenImagePath | Should Be "$TestDrive\Windows\Black.jpg"
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    Test-Path "$TestDrive\Windows\Black.jpg" | Should Be $false
                    Get-AkariState $t | Should Be 'Default'
                } finally { $env:SystemRoot = $realSystemRoot }
            }
        }

        Context 'AkariOS wallpaper' {
            $env:SystemRoot = "$TestDrive\Windows"
            $t = Load 'Customize\Theme\AkariOSWallpaper.ps1'
            It 'copies the AkariOS image, sets it for the real user, refreshes the desktop; Revert = img0.jpg' {
                try {
                    (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                    (Get-Item "$TestDrive\Windows\Web\AkariOS\img.jpg").Length | Should Be (Get-Item (Join-Path $Root 'OneClick\img.jpg')).Length
                    (Get-ItemProperty "$k\Control Panel\Desktop").Wallpaper | Should Be "$TestDrive\Windows\Web\AkariOS\img.jpg"
                    Assert-MockCalled Set-AkariDesktopWallpaper -ParameterFilter { $Path -like '*\Web\AkariOS\img.jpg' }
                    Get-AkariState $t | Should Be 'Optimized'
                    (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                    (Get-ItemProperty "$k\Control Panel\Desktop").Wallpaper | Should Be "$TestDrive\Windows\Web\Wallpaper\Windows\img0.jpg"
                    Test-Path "$TestDrive\Windows\Web\AkariOS" | Should Be $false
                    Get-AkariState $t | Should Be 'Default'
                } finally { $env:SystemRoot = $realSystemRoot }
            }
        }

        Context 'Black account pictures' {
            $t = Load 'Customize\Theme\BlackAccountPictures.ps1'
            $dir = "$TestDrive\ProgramData\Microsoft\User Account Pictures"
            New-Item $dir -ItemType Directory -Force | Out-Null
            Add-Type -AssemblyName System.Drawing
            $b = New-Object System.Drawing.Bitmap 8, 8
            $b.SetPixel(1, 1, [System.Drawing.Color]::Red); $b.Save("$dir\user.png", [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
            It 'saves the originals, paints them black, and Revert puts the originals back' {
                Get-AkariState $t | Should Be 'Default'
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Test-Path "$TestDrive\ProgramData\User Account Pictures\user.png" | Should Be $true
                $p = [System.Drawing.Bitmap]::FromFile("$dir\user.png"); $px = $p.GetPixel(1, 1).ToArgb(); $p.Dispose()
                $px | Should Be ([System.Drawing.Color]::Black.ToArgb())
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }
    } finally {
        $env:ProgramData = $realProgramData
        $env:SystemRoot = $realSystemRoot
        Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
    }
}
