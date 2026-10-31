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
