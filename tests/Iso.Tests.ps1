$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# Mocks only: no ISO is mounted, no image touched, no hive loaded, nothing downloaded
function Initialize-IsoTest {
    $script:AkariIsoMarker = Join-Path $TestDrive 'iso-mount.json'
    foreach ($f in 'Log', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Iso') { . "$Core\$f.ps1" }
}

Describe 'ISO Builder data' {
    . Initialize-IsoTest
    $d = Get-AkariIsoData 'Always'
    $all = @($d.Requirements) + @($d.Boot) + @($d.Registry)

    It 'starts every row with a hive the build loads' {
        foreach ($r in $all) { @('SOFTWARE', 'SYSTEM', 'NTUSER', 'DEFAULT') -contains ($r.Path -split '\\')[0] | Should Be $true }
    }

    It 'gives every value row a type the registry provider takes' {
        foreach ($r in $all | Where-Object { $_.ContainsKey('Name') -and $null -ne $_.Value }) { @('DWord', 'String', 'ExpandString', 'Binary', 'QWord', 'MultiString') -contains $r.Type | Should Be $true }
    }

    It 'skips the Windows 11 requirements (TPM, Secure Boot, CPU, RAM, storage)' {
        foreach ($n in 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassCPUCheck', 'BypassRAMCheck', 'BypassStorageCheck') {
            @($d.Requirements | Where-Object { $_.Name -eq $n -and $_.Value -eq 1 }).Count | Should Be 1
        }
    }

    It 'patches setup in boot.wim' {
        @($d.Boot | Where-Object { $_.Name -eq 'setup.exe' -and $_.Value -eq 3 }).Count | Should Be 1
    }

    It 'only removes paths inside the image (relative, no ..)' {
        foreach ($p in $d.Remove) { $p | Should Not Match '^[A-Za-z]:|^\\|\.\.' }
    }

    It 'maps rows onto the loaded hives' {
        $r = @(ConvertTo-AkariIsoRows @(@{ Path = 'NTUSER\Control Panel\X'; Name = 'A'; Type = 'DWord'; Value = 1 }))
        $r[0].Path | Should Be 'HKLM:\AkariIso_NTUSER\Control Panel\X'
        $r[0].Hive | Should Be 'NTUSER'
    }

    It 'refuses a row for a hive it does not load' {
        { ConvertTo-AkariIsoRows @(@{ Path = 'HKCU\Software\X'; Name = 'A'; Value = 1 }) } | Should Throw
    }
}

Describe 'ISO Builder helpers' {
    . Initialize-IsoTest

    It 'names the ISO after its source' {
        Get-AkariIsoOutName 'D:\isos\Win11_25H2_English_x64.iso' | Should Be 'Win11_25H2_English_x64-Akari.iso'
        Get-AkariIsoOutName '' | Should Be 'Windows11-Akari.iso'
    }

    It 'boots BIOS and UEFI when the media has both boot files' {
        $m = Join-Path $TestDrive 'media2'
        New-Item "$m\boot", "$m\efi\microsoft\boot" -ItemType Directory -Force | Out-Null
        Set-Content "$m\boot\etfsboot.com" 'x'; Set-Content "$m\efi\microsoft\boot\efisys.bin" 'x'
        $a = Get-AkariOscdimgArgs $m 'D:\o.iso'
        ($a -contains "-bootdata:2#p0,e,b$m\boot\etfsboot.com#pEF,e,b$m\efi\microsoft\boot\efisys.bin") | Should Be $true
        $a[-2] | Should Be $m
        $a[-1] | Should Be 'D:\o.iso'
    }

    It 'boots UEFI only without etfsboot.com, and refuses media with no EFI boot file' {
        $m = Join-Path $TestDrive 'media1'
        New-Item "$m\efi\microsoft\boot" -ItemType Directory -Force | Out-Null
        { Get-AkariOscdimgArgs $m 'D:\o.iso' } | Should Throw
        Set-Content "$m\efi\microsoft\boot\efisys.bin" 'x'
        ((Get-AkariOscdimgArgs $m 'D:\o.iso') -contains "-bootdata:1#pEF,e,b$m\efi\microsoft\boot\efisys.bin") | Should Be $true
    }

    It 'wants an NTFS drive with 25 GB free' {
        Mock Get-AkariDriveInfo { @{ Free = 100GB; Format = 'FAT32' } }
        Test-AkariIsoSpace 'E:\out' | Should Match 'NTFS'
        Mock Get-AkariDriveInfo { @{ Free = 10GB; Format = 'NTFS' } }
        Test-AkariIsoSpace 'E:\out' | Should Match '25 GB'
        Mock Get-AkariDriveInfo { @{ Free = 60GB; Format = 'NTFS' } }
        Test-AkariIsoSpace 'E:\out' | Should BeNullOrEmpty
    }

    It 'marks editions older than Windows 11 as not supported' {
        Mock Get-AkariWimImages { @{ Index = 1; Name = 'Windows 10 Pro'; Version = '10.0.19045.2965' }, @{ Index = 2; Name = 'Windows 11 Pro'; Version = '10.0.26100.1' } }
        $e = Get-AkariIsoEditions 'x.wim'
        $e[0].Supported | Should Be $false
        $e[1].Supported | Should Be $true
    }

    It 'lists the steps in build order' {
        (New-AkariIsoPlan @{ Edition = 'Windows 11 Pro' } | ForEach-Object { $_.Id }) -join ',' |
            Should Be 'Adk,Mount,Registry,Files,NetFx3,Cleanup,Commit,Compress,Boot,Iso,Tidy'
    }
}

Describe 'Open-AkariIsoSource' {
    . Initialize-IsoTest
    $disc = Join-Path $TestDrive 'disc'
    New-Item "$disc\sources" -ItemType Directory -Force | Out-Null
    Set-Content "$disc\setup.exe" 'x'
    Mock Get-AkariDriveInfo { @{ Free = 60GB; Format = 'NTFS' } }
    Mock Mount-AkariDiskImage { "$disc\" }
    Mock Dismount-AkariDiskImage { }
    Mock Write-Log { }

    It 'refuses an ISO without an install image, and still unmounts it' {
        { Open-AkariIsoSource 'C:\w.iso' (Join-Path $TestDrive 'o1') } | Should Throw 'Windows setup ISO'
        Assert-MockCalled Dismount-AkariDiskImage -Times 1 -Exactly -Scope It
    }

    It 'copies the files, clears read-only and reads the editions' {
        Set-Content "$disc\sources\install.esd" 'x'
        (Get-Item "$disc\sources\install.esd").IsReadOnly = $true
        Mock Get-AkariWimImages { @{ Index = 6; Name = 'Windows 11 Pro'; Version = '10.0.26200.1' } }
        $r = Open-AkariIsoSource 'C:\w.iso' (Join-Path $TestDrive 'o2')
        $r.Image | Should Be (Join-Path $TestDrive 'o2\AkariIso\Media\sources\install.esd')
        (Get-Item $r.Image).IsReadOnly | Should Be $false
        Test-Path (Join-Path $TestDrive 'o2\AkariIso\Media\setup.exe') | Should Be $true
        $r.Editions[0].Index | Should Be 6
    }

    It 'refuses an ISO with no Windows 11 edition' {
        Mock Get-AkariWimImages { @{ Index = 1; Name = 'Windows 10 Pro'; Version = '10.0.19045.1' } }
        { Open-AkariIsoSource 'C:\w.iso' (Join-Path $TestDrive 'o3') } | Should Throw 'Windows 11'
    }

    It 'refuses a drive that is too small before copying' {
        Mock Get-AkariDriveInfo { @{ Free = 5GB; Format = 'NTFS' } }
        { Open-AkariIsoSource 'C:\w.iso' (Join-Path $TestDrive 'o4') } | Should Throw '25 GB'
        Assert-MockCalled Mount-AkariDiskImage -Times 0 -Exactly -Scope It
    }
}

Describe 'Write-AkariIsoRegistry' {
    . Initialize-IsoTest
    Mock Invoke-AkariRegistryTrusted { }
    Mock Write-Log { }

    It 'skips rows of hives that did not load' {
        Mock Invoke-AkariRegistry { }
        Write-AkariIsoRegistry @(@{ Path = 'SOFTWARE\A'; Name = 'x'; Type = 'DWord'; Value = 1 }, @{ Path = 'NTUSER\B'; Name = 'y'; Type = 'DWord'; Value = 1 }) @('SOFTWARE')
        Assert-MockCalled Invoke-AkariRegistry -Times 1 -Exactly -Scope It -ParameterFilter { $Entries[0].Path -eq 'HKLM:\AkariIso_SOFTWARE\A' }
        Assert-MockCalled Invoke-AkariRegistry -Times 0 -Exactly -Scope It -ParameterFilter { $Entries[0].Path -like '*NTUSER*' }
    }

    It 'writes Trusted rows and rows an admin cannot write as TrustedInstaller' {
        Mock Invoke-AkariRegistry { if ($Entries[0].Name -eq 'denied') { throw 'Requested registry access is not allowed.' } }
        Write-AkariIsoRegistry @(
            @{ Path = 'SOFTWARE\A'; Name = 'ok'; Type = 'DWord'; Value = 1 }
            @{ Path = 'SOFTWARE\A'; Name = 'denied'; Type = 'DWord'; Value = 1 }
            @{ Path = 'SOFTWARE\B'; Name = 'ti'; Type = 'String'; Value = 'v'; Trusted = $true }
        ) @('SOFTWARE')
        Assert-MockCalled Invoke-AkariRegistryTrusted -Times 1 -Exactly -Scope It -ParameterFilter { ($Entries | ForEach-Object { $_.Name }) -join ',' -eq 'denied,ti' }
        Assert-MockCalled Invoke-AkariRegistry -Times 0 -Exactly -Scope It -ParameterFilter { $Entries[0].Name -eq 'ti' }
    }

    It 'loads only the hives the image has, under HKLM\AkariIso_<hive>' {
        $m = Join-Path $TestDrive 'img'
        New-Item "$m\Windows\System32\config" -ItemType Directory -Force | Out-Null
        Set-Content "$m\Windows\System32\config\SYSTEM" 'x'
        Mock Invoke-AkariRegExe { 0 }
        Mount-AkariOfflineHives $m | Should Be 'SYSTEM'
        Assert-MockCalled Invoke-AkariRegExe -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments[0] -eq 'load' -and $Arguments[1] -eq 'HKLM\AkariIso_SYSTEM' }
    }
}

Describe 'Invoke-AkariIsoBuild' {
    . Initialize-IsoTest
    $out = Join-Path $TestDrive 'out'
    $w = Get-AkariIsoWork $out
    function New-Media {
        Remove-Item $w.Root -Recurse -Force -ErrorAction SilentlyContinue
        New-Item "$($w.Media)\sources\sxs", "$($w.Media)\boot", "$($w.Media)\efi\microsoft\boot", $w.Mount -ItemType Directory -Force | Out-Null
        foreach ($f in 'sources\install.esd', 'sources\boot.wim', 'boot\etfsboot.com', 'efi\microsoft\boot\efisys.bin') { Set-Content (Join-Path $w.Media $f) 'x' }
        # the mounted image's hives (Invoke-AkariRegExe is mocked: they are never really loaded)
        New-Item "$($w.Mount)\Windows\System32\config" -ItemType Directory -Force | Out-Null
        foreach ($h in 'SOFTWARE', 'SYSTEM') { Set-Content "$($w.Mount)\Windows\System32\config\$h" 'x' }
    }
    $script:calls = [System.Collections.Generic.List[string]]::new()
    Mock Write-Log { }
    Mock Write-ErrLog { }
    Mock Set-AkariProgress { }
    Mock Install-AkariAdk { $script:calls.Add('Adk'); 'C:\adk\oscdimg.exe' }
    Mock Export-AkariWim { $script:calls.Add("Export:$Index`:$Compression") }
    Mock Mount-AkariWim { $script:calls.Add("Mount:$(Split-Path $Path -Leaf):$Index") }
    Mock Save-AkariWim { $script:calls.Add('Save') }
    Mock Undo-AkariWim { $script:calls.Add('Undo') }
    Mock Invoke-AkariDism { $script:calls.Add('Dism:' + ($Arguments[1])); 0 }
    Mock Invoke-AkariRegExe { 0 }
    Mock Invoke-AkariRegistry { }
    Mock Invoke-AkariRegistryTrusted { }
    Mock Grant-AkariOwnership { }
    Mock Remove-AkariPaths { 1 }
    Mock Get-AkariWimImages { @{ Index = 1 }, @{ Index = 2 } }
    Mock Invoke-AkariExe { $script:calls.Add('Oscdimg'); 0 }
    $c = @{ OutDir = $out; Iso = 'D:\Win11.iso'; Image = "$($w.Media)\sources\install.esd"; Index = 6; Edition = 'Windows 11 Pro' }

    It 'builds in order and returns the ISO path' {
        New-Media; $script:calls.Clear()
        $r = Invoke-AkariIsoBuild $c
        $r.Ok | Should Be $true
        $r.Path | Should Be (Join-Path $out 'Win11-Akari.iso')
        ($script:calls -join ' ') | Should Be 'Adk Export:6:fast Mount:install.wim:1 Dism:/Enable-Feature Dism:/Cleanup-Image Save Export:1:max Mount:boot.wim:2 Save Oscdimg'
    }

    It 'writes the requirements and the always-on settings into the image' {
        New-Media
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Invoke-AkariRegistry -Scope It -ParameterFilter { $Entries[0].Path -eq 'HKLM:\AkariIso_SYSTEM\Setup\LabConfig' -and $Entries[0].Name -eq 'BypassTPMCheck' }
        Assert-MockCalled Invoke-AkariRegistry -Scope It -ParameterFilter { $Entries[0].Path -eq 'HKLM:\AkariIso_SYSTEM\Setup\Status\ChildCompletion' }
    }

    It 'replaces the source install image with the compressed one and removes the work folder' {
        New-Media
        [void](Invoke-AkariIsoBuild $c)
        Test-Path $w.Root | Should Be $false
        Test-Path $AkariIsoMarker | Should Be $false
    }

    It 'leaves .NET 3.5 out when the ISO has no sources\sxs' {
        New-Media; Remove-Item "$($w.Media)\sources\sxs" -Recurse; $script:calls.Clear()
        (Invoke-AkariIsoBuild $c).Ok | Should Be $true
        ($script:calls -contains 'Dism:/Enable-Feature') | Should Be $false
    }

    It 'discards the image and unloads the hives when a step fails' {
        New-Media; $script:calls.Clear()
        Mock Save-AkariWim { throw 'The image is in use.' }
        $r = Invoke-AkariIsoBuild $c
        $r.Ok | Should Be $false
        $r.Message | Should Match 'in use'
        ($script:calls -contains 'Undo') | Should Be $true
        Test-Path $AkariIsoMarker | Should Be $false
        Assert-MockCalled Invoke-AkariRegExe -Scope It -ParameterFilter { $Arguments[0] -eq 'unload' }
    }
}

Describe 'Clear-AkariIsoLeftover' {
    . Initialize-IsoTest
    Mock Write-ErrLog { }
    Mock Invoke-AkariRegExe { 0 }
    Mock Undo-AkariWim { }

    It 'does nothing when no build was left mounted' {
        Remove-Item $AkariIsoMarker -ErrorAction SilentlyContinue
        Clear-AkariIsoLeftover
        Assert-MockCalled Undo-AkariWim -Times 0 -Exactly -Scope It
    }

    It 'discards the image a build left mounted' {
        Set-AkariIsoMarker 'E:\out\AkariIso\Mount'
        Clear-AkariIsoLeftover
        Assert-MockCalled Undo-AkariWim -Times 1 -Exactly -Scope It -ParameterFilter { $Mount -eq 'E:\out\AkariIso\Mount' }
        Test-Path $AkariIsoMarker | Should Be $false
    }
}

Describe 'ISO Builder options' {
    . Initialize-IsoTest
    $all = Get-AkariIsoOptions
    $ids = @($all | ForEach-Object { $_.Id })

    It 'has zISO''s ten options, in page order' {
        ($ids -join ',') | Should Be 'DisableUpdates,SecurityOnly,DisableVersionUpgrade,RemoveDefender,RemoveBitLocker,DisableMitigations,DisableTelemetry,RemoveEdge,RemoveOneDrive,RemoveAI'
    }

    It 'gives every option a name, a description and rows for the hives the build loads' {
        foreach ($o in $all) {
            $o.Name | Should Not BeNullOrEmpty
            $o.Description | Should Not BeNullOrEmpty
            foreach ($r in @($o.Registry) + @(@($o.RemoveKeys) | Where-Object { $_ } | ForEach-Object { @{ Path = $_ } })) {
                if (-not $r) { continue }
                @('SOFTWARE', 'SYSTEM', 'NTUSER', 'DEFAULT') -contains ($r.Path -split '\\')[0] | Should Be $true
            }
            foreach ($p in @($o.Remove)) { if ($p) { $p | Should Not Match '^[A-Za-z]:|^\\|\.\.' } }
            foreach ($x in @($o.Excludes)) { if ($x) { $ids -contains $x | Should Be $true } }
        }
    }

    It 'adds no root certificate to the image (zISO''s Windows AI .cab is left out)' {
        foreach ($o in $all) { @($o.Registry | Where-Object { $_.Path -match 'SystemCertificates' }).Count | Should Be 0 }
    }

    It 'keeps WebView2 when Edge goes' {
        $edge = $all | Where-Object { $_.Id -eq 'RemoveEdge' }
        @($edge.Remove | Where-Object { $_ -match 'WebView|EdgeUpdate|Edge\*' }).Count | Should Be 0
    }

    It 'brings zISO''s Defender .reg files over (services deleted, SmartScreen off)' {
        $d = $all | Where-Object { $_.Id -eq 'RemoveDefender' }
        @($d.Registry | Where-Object { $_.Path -eq 'SYSTEM\ControlSet001\Services\WinDefend' -and -not $_.ContainsKey('Name') }).Count | Should BeGreaterThan 0
        @($d.Registry | Where-Object { $_.Name -eq 'SmartScreenEnabled' -and $_.Value -eq 'Off' }).Count | Should Be 2
        $d.Features | Should Be '*Defender*'
    }

    It 'refuses options that exclude each other, and unknown ones' {
        Test-AkariIsoOptions @('DisableUpdates', 'SecurityOnly') $all | Should Match "can't be picked together"
        Test-AkariIsoOptions @('DisableVersionUpgrade', 'DisableUpdates') $all | Should Match "can't be picked together"
        Test-AkariIsoOptions @('Nope') $all | Should Match 'Unknown'
        Test-AkariIsoOptions @('SecurityOnly', 'DisableVersionUpgrade', 'RemoveAI') $all | Should BeNullOrEmpty
    }

    It 'merges the Settings pages Defender and AI hide' {
        $rows = Merge-AkariIsoRows @(
            @{ Path = 'SOFTWARE\P'; Name = 'SettingsPageVisibility'; Type = 'String'; Value = 'hide:windowsdefender;' }
            @{ Path = 'SOFTWARE\A'; Name = 'x'; Type = 'DWord'; Value = 1 }
            @{ Path = 'SOFTWARE\P'; Name = 'SettingsPageVisibility'; Type = 'String'; Value = 'hide:aicomponents;' }
        )
        $rows.Count | Should Be 2
        $rows[0].Value | Should Be 'hide:windowsdefender;aicomponents;'
    }

    It 'resolves names once each, from picks and patterns' {
        (Resolve-AkariIsoNames @('A', 'B') @('*Defender*') @('Windows-Defender-Default', 'B', 'Printing')) -join ',' | Should Be 'A,B,Windows-Defender-Default'
    }

    It 'gets an app''s family from its package name' {
        Get-AkariAppFamily 'Microsoft.BingNews_4.55.62231.0_x64__8wekyb3d8bbwe' | Should Be 'Microsoft.BingNews_8wekyb3d8bbwe'
        Get-AkariAppFamily 'MicrosoftWindows.Client.WebExperience_524.1.0.0_neutral_~_cw5n1h2txyewy' | Should Be 'MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy'
    }

    It 'adds the removal steps only when something is to be removed' {
        $picked = Get-AkariIsoPicked @{ Options = @('RemoveDefender') } $all
        $plan = (New-AkariIsoPlan @{ Edition = 'x'; Packages = @('P'); AkariDir = 'C:\a'; Unattend = [byte[]](1) } $picked | ForEach-Object { $_.Id }) -join ','
        $plan | Should Be 'Adk,Mount,Apps,Features,Packages,Registry,Files,AkariOS,NetFx3,Cleanup,Commit,Compress,Boot,Answer,Iso,Tidy'
    }
}

Describe 'ISO registry writes (a test key stands in for the image''s hives)' {
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $script:AkariIsoRegRoot = "$k\"
    . Initialize-IsoTest
    Mock Write-Log { }
    Mock Run-Trusted { }
    New-Item "$($k)\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Force | Out-Null
    Set-ItemProperty "$($k)\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -Value '25H2'

    It 'writes binary hex rows as bytes and the image''s own version for {DisplayVersion}' {
        Write-AkariIsoRegistry @(
            @{ Path = 'SYSTEM\K'; Name = 'MitigationOptions'; Type = 'Binary'; Value = '22,22,22' }
            @{ Path = 'SOFTWARE\WU'; Name = 'TargetReleaseVersionInfo'; Type = 'String'; Value = '{DisplayVersion}' }
        ) @('SOFTWARE', 'SYSTEM')
        $b = (Get-ItemProperty "$($k)\SYSTEM\K").MitigationOptions
        ($b -join ',') | Should Be '34,34,34'
        (Get-ItemProperty "$($k)\SOFTWARE\WU").TargetReleaseVersionInfo | Should Be '25H2'
    }

    It 'creates and deletes keys' {
        New-Item "$($k)\SOFTWARE\Gone\Sub" -Force | Out-Null
        Write-AkariIsoRegistry @(@{ Path = 'SOFTWARE\Gone'; Value = $null }, @{ Path = 'SOFTWARE\Deprovisioned\App_x'; Value = 'Key' }) @('SOFTWARE')
        Test-Path "$($k)\SOFTWARE\Gone" | Should Be $false
        Test-Path "$($k)\SOFTWARE\Deprovisioned\App_x" | Should Be $true
    }

    It 'deletes only the keys whose name matches the pattern' {
        foreach ($n in 'Microsoft.Foo_1.0_x64__8w', 'Microsoft.FooBar_1.0_x64__8w', 'Microsoft.Bar_1.0_x64__8w') { New-Item "$($k)\SOFTWARE\Inbox\$n" -Force | Out-Null }
        Remove-AkariIsoKeys @('SOFTWARE\Inbox\Microsoft.Foo_*') @('SOFTWARE')
        (Get-ChildItem "$($k)\SOFTWARE\Inbox" | ForEach-Object { $_.PSChildName }) -join ',' | Should Be 'Microsoft.Bar_1.0_x64__8w,Microsoft.FooBar_1.0_x64__8w'
    }

    It 'leaves keys alone in a hive that did not load' {
        New-Item "$($k)\NTUSER\Keep" -Force | Out-Null
        Remove-AkariIsoKeys @('NTUSER\Keep*') @('SOFTWARE')
        Test-Path "$($k)\NTUSER\Keep" | Should Be $true
    }

    Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
    $script:AkariIsoRegRoot = $null
}

Describe 'Remove-AkariImageApps' {
    . Initialize-IsoTest
    Mock Write-Log { }
    Mock Mount-AkariOfflineHives { @('SOFTWARE') }
    Mock Dismount-AkariOfflineHives { }
    Mock Write-AkariIsoRegistry { }
    Mock Remove-AkariIsoKeys { }
    Mock Invoke-AkariDism { 0 }
    Mock Remove-AkariImagePaths { 1 }

    It 'deprovisions the app, removes it with DISM and deletes its folders' {
        Remove-AkariImageApps 'M:\' @('Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe')
        Assert-MockCalled Write-AkariIsoRegistry -Times 1 -Exactly -Scope It -ParameterFilter { $Rows[0].Path -like '*\Deprovisioned\Microsoft.BingNews_8wekyb3d8bbwe' -and $Rows[0].Value -eq 'Key' }
        Assert-MockCalled Remove-AkariIsoKeys -Times 1 -Exactly -Scope It -ParameterFilter { $Patterns[0] -like '*\InboxApplications\Microsoft.BingNews_*' }
        Assert-MockCalled Invoke-AkariDism -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments -contains '/PackageFamily:Microsoft.BingNews_8wekyb3d8bbwe' }
        Assert-MockCalled Invoke-AkariDism -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments -contains '/PackageName:Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe' }
        Assert-MockCalled Remove-AkariImagePaths -Times 1 -Exactly -Scope It -ParameterFilter { $Paths -contains 'Program Files\WindowsApps\Microsoft.BingNews_*' }
        Assert-MockCalled Dismount-AkariOfflineHives -Times 1 -Exactly -Scope It
    }

    It 'leaves the frameworks out of the app list' {
        Mock Read-AkariImageApps { @{ Name = 'Microsoft.VCLibs.140.00'; Package = 'v' }, @{ Name = 'Microsoft.BingNews'; Package = 'b' }, @{ Name = 'Microsoft.DesktopAppInstaller'; Package = 'd' } }
        (@(Get-AkariImageApps 'M:\') | ForEach-Object { $_.Name }) -join ',' | Should Be 'Microsoft.BingNews'
    }
}

Describe 'Copy-AkariToImage' {
    . Initialize-IsoTest
    $src = Join-Path $TestDrive 'akari'
    New-Item "$src\Assets" -ItemType Directory -Force | Out-Null
    Set-Content "$src\Akari.ps1" 'x'; Set-Content "$src\Assets\AkariLogo.ico" 'x'
    $mount = Join-Path $TestDrive 'mnt'
    Mock New-AkariShortcutFile { }

    It 'copies AkariOS to C:\AkariOS with Start menu and desktop shortcuts that run Akari.ps1' {
        Copy-AkariToImage $mount $src
        Test-Path "$mount\AkariOS\Akari.ps1" | Should Be $true
        Test-Path "$mount\AkariOS\Assets\AkariLogo.ico" | Should Be $true
        Assert-MockCalled New-AkariShortcutFile -Times 2 -Exactly -Scope It -ParameterFilter { $Target -like '*powershell.exe' -and $Arguments -like '*C:\AkariOS\Akari.ps1*' }
        Assert-MockCalled New-AkariShortcutFile -Times 1 -Exactly -Scope It -ParameterFilter { $Lnk -eq "$mount\Users\Public\Desktop\AkariOS.lnk" }
    }

    It 'points the shortcuts at AkariOS.exe when the copy has it' {
        Set-Content "$src\AkariOS.exe" 'x'
        Copy-AkariToImage $mount $src
        Assert-MockCalled New-AkariShortcutFile -Times 2 -Exactly -Scope It -ParameterFilter { $Target -eq 'C:\AkariOS\AkariOS.exe' }
    }
}

Describe 'Invoke-AkariIsoBuild with options and removals' {
    . Initialize-IsoTest
    $out = Join-Path $TestDrive 'out'
    $w = Get-AkariIsoWork $out
    function New-OptMedia {
        New-Item "$($w.Media)\sources", "$($w.Media)\efi\microsoft\boot", "$($w.Mount)\Windows\System32\config" -ItemType Directory -Force | Out-Null
        foreach ($f in 'sources\install.wim', 'efi\microsoft\boot\efisys.bin') { Set-Content (Join-Path $w.Media $f) 'x' }
        foreach ($h in 'SOFTWARE', 'SYSTEM') { Set-Content "$($w.Mount)\Windows\System32\config\$h" 'x' }
    }
    Mock Write-Log { }
    Mock Write-ErrLog { }
    Mock Set-AkariProgress { }
    Mock Install-AkariAdk { 'C:\adk\oscdimg.exe' }
    Mock Export-AkariWim { }
    Mock Mount-AkariWim { }
    Mock Save-AkariWim { }
    Mock Undo-AkariWim { }
    Mock Invoke-AkariDism { 0 }
    Mock Invoke-AkariRegExe { 0 }
    Mock Invoke-AkariRegistry { }
    Mock Invoke-AkariRegistryTrusted { }
    Mock Grant-AkariOwnership { }
    Mock Remove-AkariPaths { 1 }
    Mock Get-AkariWimImages { @{ Index = 1 } }
    Mock Remove-AkariImageApps { }
    Mock Remove-AkariImageItems { }
    Mock Remove-AkariIsoKeys { }
    Mock Copy-AkariToImage { }
    Mock Read-AkariImageApps { @{ Name = 'Microsoft.SecHealthUI'; Package = 'Microsoft.SecHealthUI_1_x64__8wekyb3d8bbwe' }, @{ Name = 'Microsoft.Copilot'; Package = 'Microsoft.Copilot_1_x64__8wekyb3d8bbwe' }, @{ Name = 'Microsoft.Windows.Photos'; Package = 'Microsoft.Windows.Photos_1_x64__8wekyb3d8bbwe' } }
    Mock Get-AkariImageFeatures { @{ Name = 'Windows-Defender-Default-Definitions' }, @{ Name = 'Recall' }, @{ Name = 'Printing-PrintToPDFServices-Features' } }
    Mock Invoke-AkariExe { $script:answer = [IO.File]::ReadAllText((Join-Path $w.Media 'autounattend.xml')); 0 }
    $c = @{
        OutDir = $out; Iso = 'D:\W.iso'; Image = "$($w.Media)\sources\install.wim"; Index = 1; Edition = 'Windows 11 Pro'
        Options = @('RemoveDefender', 'RemoveAI', 'DisableMitigations'); Apps = @('Microsoft.BingNews_1_x64__8wekyb3d8bbwe')
        Capabilities = @('Media.WindowsMediaPlayer~~~~0.0.12.0'); AkariDir = 'C:\AkariOS'; Unattend = [Text.Encoding]::ASCII.GetBytes('<unattend/>')
    }

    It 'removes the picked apps and the ones the options name, not the others' {
        New-OptMedia
        (Invoke-AkariIsoBuild $c).Ok | Should Be $true
        Assert-MockCalled Remove-AkariImageApps -Times 1 -Exactly -Scope It -ParameterFilter {
            ($Packages -join ',') -eq 'Microsoft.BingNews_1_x64__8wekyb3d8bbwe,Microsoft.SecHealthUI_1_x64__8wekyb3d8bbwe,Microsoft.Copilot_1_x64__8wekyb3d8bbwe'
        }
    }

    It 'removes the features the options match and the picked capabilities' {
        New-OptMedia
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Remove-AkariImageItems -Times 1 -Exactly -Scope It -ParameterFilter { $Kind -eq 'Feature' -and ($Names -join ',') -eq 'Windows-Defender-Default-Definitions,Recall' }
        Assert-MockCalled Remove-AkariImageItems -Times 1 -Exactly -Scope It -ParameterFilter { $Kind -eq 'Capability' -and $Names[0] -eq 'Media.WindowsMediaPlayer~~~~0.0.12.0' }
    }

    It 'writes the options'' rows (Trusted ones as TrustedInstaller) and deletes their wildcard keys' {
        New-OptMedia
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Invoke-AkariRegistryTrusted -Scope It -ParameterFilter { @($Entries | Where-Object { $_.Name -eq 'MitigationOptions' }).Count -eq 1 }
        Assert-MockCalled Remove-AkariIsoKeys -Scope It -ParameterFilter { $Patterns -contains 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications\MicrosoftWindows.Client.CoreAI*' }
    }

    It 'adds AkariOS and puts the answer file at the root of the ISO' {
        New-OptMedia
        $script:answer = $null
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Copy-AkariToImage -Times 1 -Exactly -Scope It -ParameterFilter { $Source -eq 'C:\AkariOS' }
        $script:answer | Should Be '<unattend/>'
    }

    It 'refuses options that exclude each other before touching anything' {
        $bad = $c.Clone(); $bad.Options = @('DisableUpdates', 'SecurityOnly')
        $r = Invoke-AkariIsoBuild $bad
        $r.Ok | Should Be $false
        $r.Message | Should Match "can't be picked together"
        Assert-MockCalled Install-AkariAdk -Times 0 -Exactly -Scope It
    }
}

Describe 'ISO Builder page helpers (UI\IsoBuilder.ps1)' {
    . Initialize-IsoTest
    . "$Core\Unattend.ps1"
    $window = $null
    . "$Root\UI\IsoBuilder.ps1"
    $defaults = (Import-PowerShellDataFile "$Root\UI\Unattend.psd1").Defaults

    It 'makes a local account answer file that creates the administrator and wipes no disk' {
        $xml = [Text.Encoding]::UTF8.GetString((New-AkariUnattend (Get-AkariIsoAnswerFields $defaults 'Gamer' 'pw' $true)))
        $xml | Should Match '<Name>Gamer</Name>'
        $xml | Should Not Match 'diskpart'
        $xml | Should Not Match '<DiskConfiguration>'
    }

    It 'leaves the account to setup when the setup questions stay' {
        $f = Get-AkariIsoAnswerFields $defaults 'Gamer' 'pw' $false
        $f.UserAccountMode | Should Be 'InteractiveLocal'
        $xml = [Text.Encoding]::UTF8.GetString((New-AkariUnattend $f))
        $xml | Should Not Match '<Name>Gamer</Name>'
    }

    It 'calls the account Admin when no name is given, and drops the partitioning fields' {
        $f = Get-AkariIsoAnswerFields $defaults '  ' '' $true
        $f.AccountName0 | Should Be 'Admin'
        $f.PEMode | Should Be 'Default'
        @($f.Keys | Where-Object { $_ -match '^(Partition|TargetDisk|InstallFrom)' }).Count | Should Be 0
    }

    It 'recommends the image''s apps Win11Debloat marks Safe, not the keep-list or the rest' {
        $tweaks = @(
            @{ Id = 'appx/Microsoft.BingNews'; Risk = 'Safe' }
            @{ Id = 'appx/Microsoft.WindowsCalculator'; Risk = 'Safe'; Keep = $true }
            @{ Id = 'appx/Microsoft.XboxApp'; Risk = 'Caution' }
        )
        $apps = @(
            @{ Name = 'Microsoft.BingNews'; Package = 'news' }, @{ Name = 'Microsoft.WindowsCalculator'; Package = 'calc' },
            @{ Name = 'Microsoft.XboxApp'; Package = 'xbox' }, @{ Name = 'Microsoft.Unknown'; Package = 'u' }
        )
        (Get-AkariIsoRecommendedApps $apps $tweaks) -join ',' | Should Be 'news'
    }

    It 'rules out the options a picked one excludes' {
        $all = Get-AkariIsoOptions
        (Get-AkariIsoBlocked @('DisableUpdates') $all) -join ',' | Should Be 'DisableVersionUpgrade,SecurityOnly'
        (Get-AkariIsoBlocked @('SecurityOnly', 'DisableVersionUpgrade') $all) -join ',' | Should Be 'DisableUpdates'
        @(Get-AkariIsoBlocked @('RemoveAI') $all).Count | Should Be 0
    }

    It 'lists Massgrave''s products in page order and a product''s languages' {
        $items = @(@{ Product = 'B'; Language = 'English' }, @{ Product = 'A'; Language = 'English' }, @{ Product = 'B'; Language = 'German' })
        (Get-AkariMassgraveProducts $items) -join ',' | Should Be 'B,A'
        (Get-AkariMassgraveFiles $items 'B' | ForEach-Object { $_.Language }) -join ',' | Should Be 'English,German'
    }
}

Describe 'Mount-AkariIsoEdition' {
    . Initialize-IsoTest
    $w = Get-AkariIsoWork (Join-Path $TestDrive 'out')
    Mock Export-AkariWim { }
    Mock Mount-AkariWim { }
    Mock Undo-AkariWim { }
    Mock Invoke-AkariRegExe { 0 }
    Mock Write-ErrLog { }

    It 'mounts an edition once' {
        Clear-AkariIsoMarker
        Mount-AkariIsoEdition $w 'X:\install.wim' 6
        Mount-AkariIsoEdition $w 'X:\install.wim' 6
        Assert-MockCalled Mount-AkariWim -Times 1 -Exactly -Scope It
        Assert-MockCalled Undo-AkariWim -Times 0 -Exactly -Scope It
    }

    It 'discards the edition mounted to read its apps when another one is picked' {
        Clear-AkariIsoMarker
        Mount-AkariIsoEdition $w 'X:\install.wim' 6
        Mount-AkariIsoEdition $w 'X:\install.wim' 1
        Assert-MockCalled Undo-AkariWim -Times 1 -Exactly -Scope It
        Assert-MockCalled Mount-AkariWim -Times 2 -Exactly -Scope It
        Test-AkariIsoMounted $w 'X:\install.wim' 1 | Should Be $true
    }
}
