$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# Mocks only: no ISO is mounted, no image touched, no hive loaded, nothing downloaded
function Initialize-IsoTest {
    $script:AkariIsoMarker = Join-Path $TestDrive 'iso-mount.json'
    foreach ($f in 'Log', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Iso') { . "$Core\$f.ps1" }
}

Describe 'ISO Builder data' {
    . Initialize-IsoTest
    $d = @(Get-AkariIsoGroups | Where-Object { $_.Id -eq 'SkipHardwareChecks' })[0]
    $all = @(Get-AkariIsoGroups | ForEach-Object { @($_['Registry']) + @($_['Boot']) } | Where-Object { $_ })

    It 'starts every row with a hive the build loads' {
        foreach ($r in $all) { @('SOFTWARE', 'SYSTEM', 'NTUSER', 'DEFAULT') -contains ($r.Path -split '\\')[0] | Should Be $true }
    }

    It 'gives every value row a type the registry provider takes' {
        foreach ($r in $all | Where-Object { $_.ContainsKey('Name') -and $null -ne $_.Value }) { @('DWord', 'String', 'ExpandString', 'Binary', 'QWord', 'MultiString') -contains $r.Type | Should Be $true }
    }

    It 'skips the Windows 11 requirements (TPM, Secure Boot, CPU, RAM, storage)' {
        foreach ($n in 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassCPUCheck', 'BypassRAMCheck', 'BypassStorageCheck') {
            @($d.Registry | Where-Object { $_.Name -eq $n -and $_.Value -eq 1 }).Count | Should Be 1
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

    It 'lists the steps in build order: nothing always on but .NET 3.5 and the cleanup' {
        (New-AkariIsoPlan @{ Edition = 'Windows 11 Pro' } | ForEach-Object { $_.Id }) -join ',' |
            Should Be 'Adk,Mount,NetFx3,Cleanup,Commit,Compress,Iso,Tidy'
        $g = Get-AkariIsoGroupsPicked @('SkipHardwareChecks') (Get-AkariIsoGroups)
        (New-AkariIsoPlan @{ Edition = 'Windows 11 Pro'; Groups = @('SkipHardwareChecks') } $g | ForEach-Object { $_.Id }) -join ',' |
            Should Be 'Adk,Mount,NetFx3,Cleanup,Registry,Commit,Compress,Boot,Iso,Tidy'
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
    $c = @{ OutDir = $out; Iso = 'D:\Win11.iso'; Image = "$($w.Media)\sources\install.esd"; Index = 6; Edition = 'Windows 11 Pro'; Groups = @('SkipHardwareChecks') }
    $cg = Get-AkariIsoGroupsPicked $c.Groups (Get-AkariIsoGroups)

    It 'builds in order and returns the ISO path' {
        New-Media; $script:calls.Clear()
        $r = Invoke-AkariIsoBuild $c
        $r.Ok | Should Be $true
        $r.Path | Should Be (Join-Path $out 'Win11-Akari.iso')
        ($script:calls -join ' ') | Should Be 'Adk Export:6:fast Mount:install.wim:1 Dism:/Enable-Feature Dism:/Cleanup-Image Save Export:1:max Mount:boot.wim:2 Save Oscdimg'
    }

    It 'writes the hardware-check bypass into the image and boot.wim' {
        New-Media
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Invoke-AkariRegistry -Scope It -ParameterFilter { @($Entries | Where-Object { $_.Path -eq 'HKLM:\AkariIso_SYSTEM\Setup\LabConfig' -and $_.Name -eq 'BypassTPMCheck' }).Count -eq 1 }
        Assert-MockCalled Invoke-AkariRegistry -Scope It -ParameterFilter { @($Entries | Where-Object { $_.Path -eq 'HKLM:\AkariIso_SYSTEM\Setup\Status\ChildCompletion' }).Count -eq 1 }
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

    It 'reports each operation to the page and writes the report, size and SHA-256 next to the ISO' {
        New-Media
        # the test before left Save-AkariWim throwing (a mock lasts the Describe)
        Mock Save-AkariWim { $script:calls.Add('Save') }
        $iso = Join-Path $out 'Win11-Akari.iso'
        Mock Invoke-AkariExe { [IO.File]::WriteAllText((Join-Path $TestDrive 'out\Win11-Akari.iso'), 'iso'); 0 }
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        $r = Invoke-AkariIsoBuild $c
        Remove-Variable AkariShared
        $r.Message | Should Be ''
        $r.Ok | Should Be $true
        $sha = -join @([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes('iso')) | ForEach-Object { $_.ToString('x2') })
        $r.Report.sha256 | Should Be $sha
        $r.Report.size | Should Be 3
        $steps = New-AkariIsoPlan $c $cg
        $j = Get-Content -LiteralPath (Join-Path $out 'Win11-Akari.report.json') -Raw | ConvertFrom-Json
        $j.ok | Should Be $true
        $j.iso | Should Be $iso
        (@($j.stages | ForEach-Object { $_.id }) -join ',') | Should Be (@($steps | ForEach-Object { $_.Id }) -join ',')
        @($j.stages | Where-Object { $_.state -ne 'Done' }).Count | Should Be 0
        $clean = @($j.stages | Where-Object { $_.id -eq 'Cleanup' })[0]
        "$($clean.operations[0].name)|$($clean.operations[0].state)" | Should Be 'Component store cleanup|Done'
    }

    It 'hands the page each operation as it starts and ends' {
        New-Media
        Mock Save-AkariWim { $script:calls.Add('Save') }
        Mock Invoke-AkariExe { $script:calls.Add('Oscdimg'); 0 }
        Remove-Item (Join-Path $out 'Win11-Akari.iso') -ErrorAction SilentlyContinue
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        (Invoke-AkariIsoBuild $c).Message | Should Be ''
        $ops = @($AkariShared.IsoOps)
        Remove-Variable AkariShared
        $cleanup = [array]::IndexOf(@(New-AkariIsoPlan $c $cg | ForEach-Object { $_.Id }), 'Cleanup')
        $mine = @($ops | Where-Object { $_.Name -eq 'Component store cleanup' })
        (@($mine | ForEach-Object { "$($_.Stage)|$($_.State)" }) -join ',') | Should Be "$cleanup|Running,$cleanup|Done"
        # no ISO was made: its hash skipped
        @($ops | Where-Object { $_.Name -eq 'SHA-256 of the ISO' })[-1].State | Should Be 'Skipped'
    }

    It 'reports the failed stage, its failed operation and what did not run' {
        New-Media
        Mock Invoke-AkariDism { if ($Arguments[1] -eq '/Cleanup-Image') { throw 'DISM crashed.' }; 0 }
        $r = Invoke-AkariIsoBuild $c
        $r.Ok | Should Be $false
        $st = @($r.Report.stages)
        $fail = @($st | Where-Object { $_.id -eq 'Cleanup' })[0]
        $fail.state | Should Be 'Failed'
        "$($fail.operations[0].state)|$($fail.operations[0].note)" | Should Be 'Failed|DISM crashed.'
        @($st | Where-Object { $_.id -eq 'Tidy' })[0].state | Should Be 'Not run'
        $st.Count | Should Be (New-AkariIsoPlan $c $cg).Count
        Test-Path (Join-Path $out 'Win11-Akari.report.json') | Should Be $true
        Mock Invoke-AkariDism { $script:calls.Add('Dism:' + ($Arguments[1])); 0 }
    }

    It 'builds with the build settings: recovery ESD, Turbo, leftover data, sources\sxs left off' {
        New-Media; $script:calls.Clear()
        Remove-Item (Join-Path $out 'Win11-Akari.iso') -ErrorAction SilentlyContinue
        New-Item (Join-Path $w.Mount 'Windows\Temp\t.tmp') -ItemType File -Force | Out-Null
        Mock Get-AkariImageFeatures { @{ Name = 'Recall'; State = 'DisabledWithPayloadRemoved' }, @{ Name = 'Stuck'; State = 'Enabled' } }
        $cs = $c.Clone()
        $cs.Features = @('Recall', 'Stuck', 'Gone')
        $cs.Settings = @{ Compression = 'Recovery'; Turbo = $true; CleanLeftovers = $true; LeaveOutNetFx3Files = $true }
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        $r = Invoke-AkariIsoBuild $cs
        $ops = @($AkariShared.IsoOps | Where-Object { $_.State -ne 'Running' } | ForEach-Object { "$($_.Name)|$($_.State)|$($_.Note)" })
        Remove-Variable AkariShared
        $r.Message | Should Be ''
        $r.Ok | Should Be $true
        # the features in one call, each read back
        Assert-MockCalled Invoke-AkariDism -Times 1 -Exactly -Scope It -ParameterFilter { ($Arguments -join ' ') -eq "/Image:$($w.Mount) /Disable-Feature /FeatureName:Recall /FeatureName:Stuck /FeatureName:Gone /Remove /NoRestart" }
        Assert-MockCalled Invoke-AkariDism -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments[1] -eq '/Disable-Feature' }
        $ops -contains 'Windows feature Recall|Done|' | Should Be $true
        $ops -contains 'Windows feature Stuck|Failed|Still Enabled (DISM exit code 0)' | Should Be $true
        $ops -contains 'Windows feature Gone|Done|Not in the image any more' | Should Be $true
        # the leftovers on the allow-list, one operation each
        $ops -contains 'Windows\Temp\*|Done|1 removed' | Should Be $true
        $ops -contains 'Windows\Minidump\*|Skipped|Nothing there' | Should Be $true
        # install.esd, recovery compression; .NET 3.5 added first, then its files left off
        Assert-MockCalled Export-AkariWim -Times 1 -Exactly -Scope It -ParameterFilter { $Dest -eq (Join-Path $w.Media 'sources\install.esd') -and $Compression -eq 'recovery' }
        ($script:calls -contains 'Dism:/Enable-Feature') | Should Be $true
        $ops -contains 'sources\sxs|Done|' | Should Be $true
        $ids = @($r.Report.stages | ForEach-Object { $_.id }) -join ','
        $ids | Should Match 'Registry,Leftovers,Commit,Compress,Boot,NoSxs,Iso'
        $s = $r.Report.settings
        "$($s.compression)|$($s.turbo)|$($s.cleanLeftovers)|$($s.leaveOutNetFx3Files)" | Should Be 'Recovery|True|True|True'
    }

    It 'keeps the leftover data while the image has pending servicing' {
        New-Media
        New-Item (Join-Path $w.Mount 'Windows\Temp\t.tmp'), (Join-Path $w.Mount $AkariIsoPendingXml) -ItemType File -Force | Out-Null
        $cs = $c.Clone(); $cs.Settings = @{ CleanLeftovers = $true }
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        (Invoke-AkariIsoBuild $cs).Message | Should Be ''
        $ops = @($AkariShared.IsoOps | Where-Object { $_.State -ne 'Running' })
        Remove-Variable AkariShared
        $mine = @($ops | Where-Object { $_.Name -like '*leftover*' -or $AkariIsoLeftovers -contains $_.Name })
        @($mine | ForEach-Object { "$($_.Name)|$($_.State)" }) -join ',' | Should Be 'Leftover image data|Skipped'
        Assert-MockCalled Write-Log -Scope It -ParameterFilter { $m -eq 'The image has pending servicing (pending.xml): leftover data kept' }
    }
}

Describe 'Invoke-AkariIsoBuild from the wizard''s groups' {
    . Initialize-IsoTest
    $out = Join-Path $TestDrive 'out'
    $w = Get-AkariIsoWork $out
    function New-Media {
        Remove-Item $w.Root -Recurse -Force -ErrorAction SilentlyContinue
        New-Item "$($w.Media)\sources\sxs", "$($w.Media)\boot", "$($w.Media)\efi\microsoft\boot", $w.Mount -ItemType Directory -Force | Out-Null
        foreach ($f in 'sources\install.esd', 'sources\boot.wim', 'boot\etfsboot.com', 'efi\microsoft\boot\efisys.bin') { Set-Content (Join-Path $w.Media $f) 'x' }
        New-Item "$($w.Mount)\Windows\System32\config", "$($w.Mount)\Users\Default" -ItemType Directory -Force | Out-Null
        foreach ($h in 'Windows\System32\config\SOFTWARE', 'Windows\System32\config\SYSTEM', 'Users\Default\NTUSER.DAT') { Set-Content "$($w.Mount)\$h" 'x' }
        New-Item "$($w.Mount)\Windows\System32\OneDriveSetup.exe" -ItemType File -Force | Out-Null
    }
    $script:rows = [System.Collections.Generic.List[object]]::new()
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
    Mock Invoke-AkariRegistry { foreach ($e in $Entries) { $script:rows.Add($e) } }
    Mock Invoke-AkariRegistryTrusted { }
    Mock Grant-AkariOwnership { }
    Mock Remove-AkariPaths { 1 }
    Mock Get-AkariWimImages { @{ Index = 1 }, @{ Index = 2 } }
    Mock Invoke-AkariExe { 0 }
    Mock Read-AkariImageApps { @{ Name = 'Microsoft.BingNews'; Package = 'Microsoft.BingNews_1_x64__8wekyb3d8bbwe' }, @{ Name = 'Microsoft.WindowsCalculator'; Package = 'Microsoft.WindowsCalculator_1_x64__8wekyb3d8bbwe' } }
    Mock Copy-AkariToImage { }
    $c = @{ OutDir = $out; Iso = 'D:\Win11.iso'; Image = "$($w.Media)\sources\install.esd"; Index = 6; Edition = 'Windows 11 Pro' }

    It 'builds from the groups instead of the always-on data' {
        New-Media; $script:rows.Clear()
        $cs = $c.Clone(); $cs.Groups = @('SkipHardwareChecks', 'OneDrive'); $cs.AppPatterns = @('Microsoft.BingNews')
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        $r = Invoke-AkariIsoBuild $cs
        $ops = @($AkariShared.IsoOps | Where-Object { $_.State -ne 'Running' } | ForEach-Object { "$($_.Name)|$($_.State)" })
        Remove-Variable AkariShared
        $r.Ok | Should Be $true
        @($script:rows | Where-Object { $_.Path -like '*LabConfig' -and $_.Name -eq 'BypassTPMCheck' }).Count | Should BeGreaterThan 0
        # zISO's always-on rows and paths are not written or removed
        @($script:rows | Where-Object { $_.Name -eq 'DisableWindowsConsumerFeatures' }).Count | Should Be 0
        $ops -contains 'Windows\InboxApps|Skipped' | Should Be $false
        $ops -contains 'Windows\System32\OneDriveSetup.exe|Done' | Should Be $true
        # the app pattern matched on the image
        $ops -contains 'App Microsoft.BingNews|Done' | Should Be $true
        @($ops | Where-Object { $_ -like 'App Microsoft.WindowsCalculator*' }).Count | Should Be 0
        Assert-MockCalled Mount-AkariWim -Scope It -ParameterFilter { $Path -like '*boot.wim' }
    }

    It 'fails an unknown group before it starts' {
        $cs = $c.Clone(); $cs.Groups = @('Nope')
        $r = Invoke-AkariIsoBuild $cs
        "$($r.Ok)|$($r.Message)" | Should Be 'False|Unknown removal group: Nope'
        Assert-MockCalled Install-AkariAdk -Scope It -Times 0
    }

    It 'writes the baked Tweaks into the image and the first sign-in''s RunOnce value' {
        New-Media; $script:rows.Clear()
        $toggle = [pscustomobject]@{ Id = 't-user'; Name = 't-user'; Kind = 'Toggle'; Registry = [hashtable[]]@(
                @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed'; Type = 'DWord'; Value = 0 }
                @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\X'; Name = 'Y'; Type = 'DWord'; Value = 2 }) }
        $choice = [pscustomobject]@{ Id = 't-choice'; Name = 'A choice'; Kind = 'Choice'; Recommended = 3; Registry = [hashtable[]]@(@{ Path = 'HKLM:\SOFTWARE\Policies\Z'; Name = 'Level'; Type = 'DWord' }) }
        $nodef = [pscustomobject]@{ Id = 't-def'; Name = 'Default hive'; Kind = 'Toggle'; Registry = [hashtable[]]@(@{ Path = 'Registry::HKEY_USERS\.DEFAULT\X'; Name = 'A'; Type = 'DWord'; Value = 1 }) }
        $cs = $c.Clone(); $cs.Groups = @(); $cs.AkariDir = 'C:\src'; $cs.FirstSignIn = $true; $cs.ImageBuild = 26100
        $cs.Bake = @(@{ Tweak = $toggle; Value = $null }, @{ Tweak = $choice; Value = 5 }, @{ Tweak = $nodef; Value = $null })
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        $r = Invoke-AkariIsoBuild $cs
        $ops = @($AkariShared.IsoOps | Where-Object { $_.State -ne 'Running' } | ForEach-Object { "$($_.Name)|$($_.State)|$($_.Note)" })
        Remove-Variable AkariShared
        $r.Ok | Should Be $true
        $seen = @($script:rows | ForEach-Object { "$($_.Path)|$($_.Name)|$($_.Value)" })
        $seen -contains "$($AkariIsoRegRoot)NTUSER\Control Panel\Mouse|MouseSpeed|0" | Should Be $true
        $seen -contains "$($AkariIsoRegRoot)SYSTEM\ControlSet001\Control\X|Y|2" | Should Be $true
        $seen -contains "$($AkariIsoRegRoot)SOFTWARE\Policies\Z|Level|5" | Should Be $true
        $seen -contains "$($AkariIsoRegRoot)$AkariIsoRunOnceKey|AkariOS|$AkariIsoFirstSignIn" | Should Be $true
        $AkariIsoFirstSignIn | Should Match "-File C:\\AkariOS\\Akari\.ps1 -FirstSignIn' -Verb RunAs"
        $ops -contains 'Tweak t-user|Done|' | Should Be $true
        $ops -contains 'Tweak A choice|Done|5' | Should Be $true
        $ops -contains 'Tweak Default hive|Skipped|The image has no DEFAULT hive' | Should Be $true
        $ops -contains 'The rest of AkariOS at the first sign-in|Done|A RunOnce entry for each new account: one UAC prompt, then One-click''s console' | Should Be $true
        $ids = @($r.Report.stages | ForEach-Object { $_.id }) -join ','
        $ids | Should Match 'Cleanup,Bake,AkariOS,Commit'
    }
}

Describe 'Export-AkariWim' {
    . Initialize-IsoTest
    It 'exports a recovery-compressed install.esd through dism.exe, a split image''s parts too' {
        Mock Invoke-AkariDism { 0 }
        Export-AkariWim 'X:\s\install.swm' 6 'Y:\install.esd' 'recovery'
        Assert-MockCalled Invoke-AkariDism -Times 1 -Exactly -Scope It -ParameterFilter { ($Arguments -join ' ') -eq '/Export-Image /SourceImageFile:X:\s\install.swm /SWMFile:X:\s\install*.swm /SourceIndex:6 /DestinationImageFile:Y:\install.esd /Compress:recovery' }
        Mock Invoke-AkariDism { 2 }
        { Export-AkariWim 'X:\install.wim' 1 'Y:\install.esd' 'recovery' } | Should Throw 'DISM could not export the image (exit code 2)'
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

Describe 'ISO Builder rows and names' {
    . Initialize-IsoTest
    $groups = @(Get-AkariIsoGroups)

    It 'gives every group rows for the hives the build loads, and paths under the image' {
        foreach ($g in $groups) {
            foreach ($r in @($g['Registry']) + @($g['Boot']) + @(@($g['RemoveKeys']) | Where-Object { $_ } | ForEach-Object { @{ Path = $_ } })) {
                if (-not $r) { continue }
                @('SOFTWARE', 'SYSTEM', 'NTUSER', 'DEFAULT') -contains ($r.Path -split '\\')[0] | Should Be $true
            }
            foreach ($p in @($g['Remove'])) { if ($p) { $p | Should Not Match '^[A-Za-z]:|^\\|\.\.' } }
        }
    }

    It 'adds no root certificate to the image' {
        foreach ($g in $groups) { @($g['Registry'] | Where-Object { $_.Path -match 'SystemCertificates' }).Count | Should Be 0 }
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

    It 'adds the removal steps only when something is to be removed, and Minimal''s pruning before the image is saved' {
        $picked = Get-AkariIsoGroupsPicked @('Tiny11Core') $groups
        $plan = (New-AkariIsoPlan @{ Edition = 'x'; Packages = @('P'); AkariDir = 'C:\a'; Unattend = [byte[]](1) } $picked | ForEach-Object { $_.Id }) -join ','
        $plan | Should Be 'Adk,Mount,NetFx3,Cleanup,Capabilities,Packages,Registry,Files,AkariOS,Prune,Commit,Compress,Answer,Iso,Tidy'
    }
}

Describe 'Minimal''s component store pruning' {
    . Initialize-IsoTest
    $m = Join-Path $TestDrive 'mount'
    $sxs = Join-Path $m 'Windows\WinSxS'
    $keep = @('Manifests', 'amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0_none_1', 'amd64_microsoft.windows.gdiplus_6595b64144ccf1df_1.1_none_1',
        'amd64_microsoft-windows-servicingstack_31bf3856ad364e35_10.0_none_1')
    function New-Store([string[]]$Folders) {
        Remove-Item $m -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($f in $Folders) { New-Item (Join-Path $sxs $f) -ItemType Directory -Force | Out-Null }
    }
    Mock Write-Log { }
    Mock Grant-AkariOwnership { }
    Mock Remove-AkariPaths { 1 }

    It 'keeps the store''s metadata and the runtimes Windows loads from it' {
        foreach ($f in $keep + 'amd64_microsoft-windows-s..stack-msg.resources_31bf3856ad364e35_10.0.26100.1_en-us_1', 'x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.9635_none_1') {
            Test-AkariKeepInComponentStore $f | Should Be $true
        }
        Test-AkariKeepInComponentStore 'amd64_microsoft-windows-notepad_31bf3856ad364e35_10.0.26100.1_none_1' | Should Be $false
        Test-AkariKeepInComponentStore 'amd64_microsoft-edge-webview_31bf3856ad364e35_10.0.26100.1_none_1' | Should Be $false
    }

    It 'removes every other folder, taking ownership of the store once' {
        New-Store ($keep + 'amd64_microsoft-windows-notepad_31bf3856ad364e35_10.0_none_1')
        Remove-AkariIsoComponentStore $m
        Assert-MockCalled Grant-AkariOwnership -Times 1 -Exactly -Scope It -ParameterFilter { $Path -eq $sxs }
        Assert-MockCalled Remove-AkariPaths -Times 1 -Exactly -Scope It
        Assert-MockCalled Remove-AkariPaths -Times 1 -Exactly -Scope It -ParameterFilter { $Paths[0] -like '*notepad*' }
    }

    It 'refuses while servicing is pending, or without a runtime, removing nothing' {
        New-Store ($keep + 'amd64_microsoft-windows-notepad_31bf3856ad364e35_10.0_none_1')
        Set-Content (Join-Path $m $AkariIsoPendingXml) 'x'
        { Remove-AkariIsoComponentStore $m } | Should Throw 'pending servicing'
        New-Store ($keep | Where-Object { $_ -notlike '*gdiplus*' })
        { Remove-AkariIsoComponentStore $m } | Should Throw 'gdiplus runtime'
        Assert-MockCalled Remove-AkariPaths -Times 0 -Exactly -Scope It
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

    It 'removes with DISM before touching AppxAllUserStore''s keys (DISM finds the apps through them)' {
        $script:order = [Collections.Generic.List[string]]::new()
        Mock Invoke-AkariDism { $script:order.Add("dism $($Arguments[1])"); 0 }
        Mock Mount-AkariOfflineHives { $script:order.Add('load'); @('SOFTWARE') }
        Mock Remove-AkariIsoKeys { $script:order.Add('keys') }
        Remove-AkariImageApps 'M:\' @('Microsoft.BingNews_4.55.1.0_x64__8wekyb3d8bbwe')
        ($script:order -join ',') | Should Be 'dism /Set-NonRemovableAppPolicy,dism /Remove-ProvisionedAppxPackage,load,keys'
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

Describe 'Invoke-AkariIsoBuild with removal groups and removals' {
    . Initialize-IsoTest
    $out = Join-Path $TestDrive 'out'
    $w = Get-AkariIsoWork $out
    function New-OptMedia {
        New-Item "$($w.Media)\sources", "$($w.Media)\efi\microsoft\boot", "$($w.Mount)\Windows\System32\config" -ItemType Directory -Force | Out-Null
        foreach ($f in 'sources\install.wim', 'efi\microsoft\boot\efisys.bin') { Set-Content (Join-Path $w.Media $f) 'x' }
        foreach ($h in 'SOFTWARE', 'SYSTEM') { Set-Content "$($w.Mount)\Windows\System32\config\$h" 'x' }
        # Minimal's component store: its runtimes and one component
        foreach ($f in 'Manifests', 'amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0_none_1', 'amd64_microsoft.windows.gdiplus_6595b64144ccf1df_1.1_none_1',
            'amd64_microsoft-windows-servicingstack_31bf3856ad364e35_10.0_none_1', 'amd64_microsoft-windows-notepad_31bf3856ad364e35_10.0_none_1') {
            New-Item "$($w.Mount)\Windows\WinSxS\$f" -ItemType Directory -Force | Out-Null
        }
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
    Mock Get-AkariImageCapabilities { @{ Name = 'Language.Speech~~~en-US~0.0.1.0'; State = 'Installed' }, @{ Name = 'Language.Basic~~~en-US~0.0.1.0'; State = 'Installed' } }
    Mock Invoke-AkariExe { $script:answer = [IO.File]::ReadAllText((Join-Path $w.Media 'autounattend.xml')); 0 }
    $c = @{
        OutDir = $out; Iso = 'D:\W.iso'; Image = "$($w.Media)\sources\install.wim"; Index = 1; Edition = 'Windows 11 Pro'
        Groups = @('Tiny11Features', 'Tiny11Core'); AppPatterns = @('Microsoft.Copilot'); Apps = @('Microsoft.BingNews_1_x64__8wekyb3d8bbwe')
        Capabilities = @('Media.WindowsMediaPlayer~~~~0.0.12.0'); AkariDir = 'C:\AkariOS'; Unattend = [Text.Encoding]::ASCII.GetBytes('<unattend/>')
    }

    It 'removes the picked apps and the ones the groups'' patterns name, not the others' {
        New-OptMedia
        (Invoke-AkariIsoBuild $c).Ok | Should Be $true
        Assert-MockCalled Remove-AkariImageApps -Times 1 -Exactly -Scope It -ParameterFilter {
            ($Packages -join ',') -eq 'Microsoft.BingNews_1_x64__8wekyb3d8bbwe,Microsoft.Copilot_1_x64__8wekyb3d8bbwe'
        }
    }

    It 'removes the features and capabilities the groups match on the image, and the picked ones' {
        New-OptMedia
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Remove-AkariImageItems -Times 1 -Exactly -Scope It -ParameterFilter { $Kind -eq 'Feature' -and ($Names -join ',') -eq 'Recall' }
        Assert-MockCalled Remove-AkariImageItems -Times 1 -Exactly -Scope It -ParameterFilter { $Kind -eq 'Capability' -and ($Names -join ',') -eq 'Media.WindowsMediaPlayer~~~~0.0.12.0,Language.Speech~~~en-US~0.0.1.0' }
    }

    It 'writes the groups'' rows, Trusted ones as TrustedInstaller' {
        New-OptMedia
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Invoke-AkariRegistryTrusted -Scope It -ParameterFilter { @($Entries | Where-Object { $_.Path -like '*\Services\WinDefend' -and $_.Name -eq 'Start' }).Count -eq 1 }
    }

    It 'prunes the component store for Minimal''s group, after the leftovers and before the image is saved' {
        New-OptMedia
        $AkariShared = @{ IsoOps = [Collections.ArrayList]::new() }
        (Invoke-AkariIsoBuild $c).Ok | Should Be $true
        $ops = @($AkariShared.IsoOps)
        Remove-Variable AkariShared
        $prune = [array]::IndexOf(@(New-AkariIsoPlan $c (Get-AkariIsoGroupsPicked $c.Groups (Get-AkariIsoGroups)) | ForEach-Object { $_.Id }), 'Prune')
        "$(@($ops | Where-Object { $_.Name -eq '1 component folders' })[-1].Stage)|$(@($ops | Where-Object { $_.Name -eq '1 component folders' })[-1].Note)" | Should Be "$prune|1 removed; 4 kept"
    }

    It 'adds AkariOS and puts the answer file at the root of the ISO' {
        New-OptMedia
        $script:answer = $null
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Copy-AkariToImage -Times 1 -Exactly -Scope It -ParameterFilter { $Source -eq 'C:\AkariOS' }
        $script:answer | Should Be '<unattend/>'
    }

    It 'removes only the groups'' own Remove lists (no hashtable method as a path)' {
        New-OptMedia
        Mock Remove-AkariImagePaths { 0 }
        [void](Invoke-AkariIsoBuild $c)
        Assert-MockCalled Remove-AkariImagePaths -Scope It -ParameterFilter { @($Paths | Where-Object { $_ -like '*Remove(*' }).Count -gt 0 } -Times 0 -Exactly
        Assert-MockCalled Remove-AkariImagePaths -Scope It -ParameterFilter { $Paths -contains 'Windows\System32\Recovery\winre.wim' } -Times 1 -Exactly
    }

    It 'refuses an unknown group before touching anything' {
        $bad = $c.Clone(); $bad.Groups = @('Tiny11Core', 'Nope')
        $r = Invoke-AkariIsoBuild $bad
        $r.Ok | Should Be $false
        $r.Message | Should Be 'Unknown removal group: Nope'
        Assert-MockCalled Install-AkariAdk -Times 0 -Exactly -Scope It
    }
}

Describe 'ISO Builder wizard data (Core\Iso\Wizard)' {
    . Initialize-IsoTest
    foreach ($f in 'Loader', 'Presets') { . "$Core\$f.ps1" }
    $groups = @(Get-AkariIsoGroups)
    $modes = @(Get-AkariIsoModes)

    It 'reads the modes and the groups by Order' {
        ($modes | ForEach-Object { $_.Id }) -join ',' | Should Be 'AkariOS,Lite,Minimal'
        $groups[0].Id | Should Be 'SkipHardwareChecks'
        foreach ($m in $modes) { foreach ($g in $m.Groups) { @($groups | Where-Object { $_.Id -eq $g }).Count | Should Be 1 } }
        $modes[0].AkariOS | Should Be $true
    }

    It 'picks groups by id, in Order, and refuses an unknown one' {
        ((Get-AkariIsoGroupsPicked @('OneDrive', 'SkipHardwareChecks') $groups) | ForEach-Object { $_.Id }) -join ',' | Should Be 'SkipHardwareChecks,OneDrive'
        { Get-AkariIsoGroupsPicked @('Nope') $groups } | Should Throw 'Unknown removal group: Nope'
    }

    It 'expands the appx tokens and keeps other patterns' {
        $t = @([pscustomobject]@{ Id = 'appx/A'; Risk = 'Safe'; Keep = $false }, [pscustomobject]@{ Id = 'appx/B'; Risk = 'Caution'; Keep = $false },
            [pscustomobject]@{ Id = 'appx/C'; Risk = 'Safe'; Keep = $true }, [pscustomobject]@{ Id = 'other'; Risk = 'Safe'; Keep = $false })
        (Get-AkariIsoAppPatterns @(@{ Apps = @('appx:Safe') }) $t) -join ',' | Should Be 'A'
        (Get-AkariIsoAppPatterns @(@{ Apps = @('appx:AkariOS') }) $t) -join ',' | Should Be 'A,B'
        (Get-AkariIsoAppPatterns @(@{ Apps = @('appx:Safe', 'appx:AkariOS') }, @{ Apps = @('Edge*', 'a') }) $t) -join ',' | Should Be 'A,B,Edge*'
    }

    It 'puts a Tweak''s path in the image or nowhere' {
        $r = 'HKLM:\AkariIso_'
        Get-AkariIsoImagePath 'HKLM:\SOFTWARE\Policies\X' $r | Should Be 'HKLM:\AkariIso_SOFTWARE\Policies\X'
        Get-AkariIsoImagePath 'HKLM:\SYSTEM\CurrentControlSet\Services\X' $r | Should Be 'HKLM:\AkariIso_SYSTEM\ControlSet001\Services\X'
        Get-AkariIsoImagePath 'HKLM:\SYSTEM\Setup' $r | Should Be 'HKLM:\AkariIso_SYSTEM\Setup'
        Get-AkariIsoImagePath 'HKCU:\Control Panel\Mouse' $r | Should Be 'HKLM:\AkariIso_NTUSER\Control Panel\Mouse'
        Get-AkariIsoImagePath 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' $r | Should Be 'HKLM:\AkariIso_DEFAULT\Control Panel\Keyboard'
        Get-AkariIsoImagePath 'HKEY_CLASSES_ROOT\Directory' $r | Should Be 'HKLM:\AkariIso_SOFTWARE\Classes\Directory'
        foreach ($none in 'HKCU:\Software\Classes\CLSID\{x}', 'HKLM:\HARDWARE\X', 'Registry::HKEY_USERS\S-1-5-21-1\X', 'not a path') { Get-AkariIsoImagePath $none $r | Should BeNullOrEmpty }
    }

    It 'bakes the AkariOS preset''s registry-only Tweaks and leaves the rest for the first sign-in' {
        $loaded = Get-AkariTweaks "$Root\Tweaks"
        $preset = Find-AkariPreset 'AkariOS' "$Root\Presets"
        $b = Get-AkariIsoBake $preset $loaded.Tweaks 26100
        @($b.InImage).Count | Should BeGreaterThan 10
        foreach ($i in $b.InImage) {
            $i.Tweak.SafeMode | Should Be $false
            if ($i.Tweak.Kind -eq 'Choice') { $i.Value | Should Not BeNullOrEmpty }
        }
        $b.Later -contains 'oneclick-ddu-prepare' | Should Be $true
        $b.Later -contains 'security-defender-settings' | Should Be $true
        @($b.Later | Where-Object { $_ -like 'appx/*' }).Count | Should BeGreaterThan 0
        $all = @((Resolve-AkariPreset $preset $loaded.Tweaks).Items | ForEach-Object { $_.Id }) | Sort-Object
        (@(@($b.InImage | ForEach-Object { $_.Tweak.Id }) + @($b.Later)) | Sort-Object) -join ',' | Should Be ($all -join ',')
    }

    It 'bakes by the image''s Windows' {
        $row = @(@{ Path = 'HKLM:\SOFTWARE\X'; Name = 'A'; Type = 'DWord'; Value = 1 })
        $t = @([pscustomobject]@{ Id = 'w10'; Name = 'w10'; Kind = 'Toggle'; Requires = @('Win10'); Registry = $row }, [pscustomobject]@{ Id = 'lap'; Name = 'lap'; Kind = 'Toggle'; Requires = @('Laptop'); Registry = $row })
        $preset = @{ Name = 'p'; Entries = @(@{ Id = 'w10' }, @{ Id = 'lap' }) }
        (Get-AkariIsoBake $preset $t 19045).Later -join ',' | Should Be 'lap'
        (Get-AkariIsoBake $preset $t 26100).Later -join ',' | Should Be 'w10,lap'
    }

    It 'plans a wizard build: .NET 3.5 and the cleanup before the features; settings, files and boot.wim only for groups with them' {
        $ids = { param($c, $g) $p = New-AkariIsoPlan $c $g; @($p | ForEach-Object { $_.Id }) -join ',' }
        & $ids @{ Groups = @() } @() | Should Be 'Adk,Mount,NetFx3,Cleanup,Commit,Compress,Iso,Tidy'
        $g = Get-AkariIsoGroupsPicked @('Tiny11Features', 'OneDrive') $groups
        & $ids @{ Groups = @('Tiny11Features', 'OneDrive'); AppPatterns = @('Microsoft.BingNews') } $g | Should Be 'Adk,Mount,Apps,NetFx3,Cleanup,Features,Registry,Files,Commit,Compress,Iso,Tidy'
        & $ids @{ Groups = @(); FirstSignIn = $true } @() | Should Not Match 'Bake'
        & $ids @{ Groups = @(); FirstSignIn = $true; AkariDir = 'C:\a' } @() | Should Match 'Bake,AkariOS,Commit'
        # the user's own features after the cleanup too
        & $ids @{ Features = @('Recall') } @() | Should Be 'Adk,Mount,NetFx3,Cleanup,Features,Commit,Compress,Iso,Tidy'
        # Minimal: its pruning before the image is saved
        & $ids @{ Groups = @('Tiny11Core') } (Get-AkariIsoGroupsPicked @('Tiny11Core') $groups) | Should Match 'Files,Prune,Commit'
    }

    It 'reads an edition''s build and says the plan''s size' {
        $window = $null; . "$Root\UI\IsoBuilder.ps1"
        Get-AkariIsoBuildOf '10.0.26100.1742' | Should Be 26100
        Get-AkariIsoBuildOf '' | Should Be 0
        Get-AkariIsoPlanText 1 | Should Be '1 removal group'
        Get-AkariIsoPlanText 0 | Should Be '0 removal groups'
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

    It 'starts the work folder on the C: drive and says to pick it when Windows refuses a folder' {
        $AkariIsoDefaultOut | Should Match '^[A-Z]:\\AkariISO$'
        Get-AkariIsoOpenError 'Access to the path is denied.' 'C:\Users\me\Desktop\x' |
            Should Be "Not opened: Windows refused access to C:\Users\me\Desktop\x. Pick a folder on the C: drive, e.g. $AkariIsoDefaultOut (not the Desktop or Documents)."
        Get-AkariIsoOpenError 'This ISO isn''t Windows 11.' 'C:\AkariISO' | Should Be 'Not opened: This ISO isn''t Windows 11.'
    }

    It 'lets Next go only once a step is complete, and neither Next nor Back while the page''s job runs' {
        $f = Get-AkariIsoFooter 0 $false $false $false $false; "$($f.Next)|$($f.CanNext)|$($f.CanBack)" | Should Be 'Start|True|False'
        $f = Get-AkariIsoFooter 1 $false $false $false $false; "$($f.Hint)|$($f.CanNext)|$($f.CanBack)" | Should Be 'Open an ISO and pick an edition first.|False|True'
        $f = Get-AkariIsoFooter 1 $true $false $false $false; "$($f.Next)|$($f.CanNext)" | Should Be 'Next|True'
        $f = Get-AkariIsoFooter 2 $true $true $false $false; "$($f.CanNext)|$($f.CanBack)" | Should Be 'False|False'
        $f = Get-AkariIsoFooter 3 $true $false $false $false; $f.Next | Should Be 'Review'
        $f = Get-AkariIsoFooter 4 $true $false $false $false; "$($f.Next)|$($f.CanNext)" | Should Be 'Build ISO|True'
        $f = Get-AkariIsoFooter 5 $false $true $false $false; "$($f.Next)|$($f.CanNext)|$($f.CanBack)" | Should Be 'Build another|False|False'
        $f = Get-AkariIsoFooter 5 $false $false $true $false; "$($f.CanNext)|$($f.CanBack)" | Should Be 'True|False'
        $f = Get-AkariIsoFooter 5 $false $false $false $true; "$($f.CanNext)|$($f.CanBack)" | Should Be 'True|True'
    }

    It 'picks the first Pro edition, else the first' {
        Get-AkariIsoEditionPick @(@{ Name = 'Windows 11 Home' }, @{ Name = 'Windows 11 Pro N' }, @{ Name = 'Windows 11 Pro' }) | Should Be 2
        Get-AkariIsoEditionPick @(@{ Name = 'Windows 11 Home' }, @{ Name = 'Windows 11 Education' }) | Should Be 0
        Get-AkariIsoSummary $null | Should Be 'No image yet'
    }

    It 'follows the build''s stages and ends them' {
        (Get-AkariIsoStageStates 2 5 5) -join ',' | Should Be 'Done,Done,Running,Waiting,Waiting'
        (Get-AkariIsoStageStates 5 5 5) -join ',' | Should Be 'Done,Done,Done,Done,Done'
        (Get-AkariIsoEndStates @('Done', 'Running', 'Waiting') $false) -join ',' | Should Be 'Done,Failed,Not run'
        (Get-AkariIsoEndStates @('Done', 'Running', 'Waiting') $true) -join ',' | Should Be 'Done,Done,Done'
        Get-AkariIsoElapsedText ([TimeSpan]::FromSeconds(12.7)) | Should Be '12 s'
        Get-AkariIsoElapsedText ([TimeSpan]::FromSeconds(184)) | Should Be '3 min 4 s'
    }

    It 'follows each stage''s operations and sums them up' {
        $l = [Collections.ArrayList]::new()
        [void](Update-AkariIsoOpList $l @{ Name = 'App A'; State = 'Running' })
        [void](Update-AkariIsoOpList $l @{ Name = 'App B'; State = 'Running' })
        [void](Update-AkariIsoOpList $l @{ Name = 'App A'; State = 'Failed'; Seconds = 3.2; Note = 'DISM exit code 2' })
        [void](Update-AkariIsoOpList $l @{ Name = 'App B'; State = 'Skipped'; Seconds = 0; Note = 'Not there' })
        [void](Update-AkariIsoOpList $l @{ Name = 'App C'; State = 'Done'; Seconds = 61 })
        (@($l | ForEach-Object { "$($_.Name)|$($_.State)|$($_.Note)|$($_.Elapsed)" }) -join ';') | Should Be 'App A|Failed|DISM exit code 2|3 s;App B|Skipped|Not there|0 s;App C|Done||1 min 1 s'
        Get-AkariIsoOpSummary $l | Should Be '3 operations, 1 failed, 1 skipped'
        Get-AkariIsoOpSummary @(@{ State = 'Done' }) | Should Be '1 operation'
        Get-AkariIsoOpSummary @() | Should Be ''
    }

    It 'shows the ISO''s size, SHA-256 and the report''s path' {
        $rep = @{ iso = 'D:\Win11-Akari.iso'; size = [long](5.5 * 1GB); sha256 = 'ab12' }
        (Get-AkariIsoResultDetails $rep $true) -replace '[^ -~\n]', '.' | Should Be ("5.50 GB . SHA-256 ab12`nReport: D:\Win11-Akari.report.json" -replace '5\.50', ('{0:0.00}' -f 5.5))
        Get-AkariIsoResultDetails $rep $false | Should Be 'Report: D:\Win11-Akari.report.json'
        Get-AkariIsoResultDetails $null $true | Should Be ''
    }

    It 'reviews the image, what goes, where the ISO goes, the installation options and the build settings' {
        $cards = Get-AkariIsoReviewCards @{ Summary = 'Windows 11 Pro'; Iso = 'D:\Win11.iso'; ModeName = 'Custom'; ModeIcon = 'settings-2'
            Groups = @('Skip the hardware checks'); Custom = $true
            Lists = @(@{ Title = 'Store apps'; Ticked = 3; Count = 40 }); OutDir = 'E:\Out'; Answer = 'Local'; SkipOobe = $true; User = 'Gamer'; AkariOS = $true
            Settings = @{ Compression = 'Recovery'; Turbo = $true } }
        ($cards | ForEach-Object { $_.Title }) -join ',' | Should Be 'Windows image,Custom,Output and workspace,Installation options,Build settings'
        $cards[4].Lines | Should Be "Compression: Recovery ESD (smallest, slowest)`nTurbo feature removal: On`nRemove leftover image data: Off`n.NET 3.5's setup files on the ISO: Kept`nThis PC's drivers: Not added"
        $cards[0].Lines | Should Be "Windows 11 Pro`nD:\Win11.iso"
        $cards[1].Lines | Should Be ("1 removal group`n- Skip the hardware checks`n`nStore apps: 3 of 40")
        $cards[2].Lines | Should Be "ISO`nE:\Out\Win11-Akari.iso`n`nWork folder`nE:\Out\AkariIso"
        $cards[3].Lines | Should Be "Answer file: A local account (Gamer), setup's questions skipped`nAkariOS on the new Windows: Yes"
        $none = Get-AkariIsoReviewCards @{ Summary = 'x'; Iso = 'D:\a.iso'; ModeName = 'Custom'; Custom = $true; Lists = @(); OutDir = 'E:\'; Answer = 'None'; AkariOS = $false }
        $none[1].Lines | Should Be "0 removal groups`n`nThe image's own lists weren't read: nothing picked from them."
        # the AkariOS mode: its groups and what is baked
        $ak = Get-AkariIsoReviewCards @{ Summary = 'x'; Iso = 'D:\a.iso'; ModeName = 'AkariOS'; Groups = @('A', 'B'); Bake = @{ InImage = 40; Later = 25; FirstSignIn = $true }; OutDir = 'E:\'; Answer = 'None' }
        $ak[1].Lines | Should Be "2 removal groups`n- A`n- B`n`nAkariOS settings written into the image: 40`nThe rest at the first sign-in: 25 changes, one UAC prompt"
        (Get-AkariIsoReviewCards @{ Groups = @('A'); Bake = @{ InImage = 1; Later = 2; FirstSignIn = $false } })[1].Lines | Should Match 'The rest left out: run One-click from the Start menu later$'
        $none[3].Lines | Should Be "Answer file: None: setup asks everything as usual`nAkariOS on the new Windows: No"
    }

    It 'reads the build settings, the defaults when they are missing' {
        $d = Get-AkariIsoSettings @{}
        "$($d.Compression)|$($d.Turbo)|$($d.CleanLeftovers)|$($d.LeaveOutNetFx3Files)" | Should Be 'Maximum|False|False|False'
        # a JSON case's object, any case
        $j = Get-AkariIsoSettings @{ Settings = [pscustomobject]@{ Compression = 'fast'; LeaveOutNetFx3Files = $true } }
        "$($j.Compression)|$($j.Turbo)|$($j.LeaveOutNetFx3Files)" | Should Be 'Fast|False|True'
        (Get-AkariIsoSettings @{ Settings = @{ Compression = 'Zip' } }).Compression | Should Be 'Maximum'
        (Get-AkariIsoSettingsLines (Get-AkariIsoSettings @{ Settings = @{ CleanLeftovers = $true; LeaveOutNetFx3Files = $true } })) -join '|' |
            Should Be "Compression: Maximum WIM|Turbo feature removal: Off|Remove leftover image data: On|.NET 3.5's setup files on the ISO: Left out|This PC's drivers: Not added"
    }

    It 'plans the build settings'' steps' {
        $ids = { param($s) $p = New-AkariIsoPlan @{ Edition = 'W'; Settings = $s }; @($p | ForEach-Object { $_.Id }) -join ',' }
        $text = { param($s) $p = New-AkariIsoPlan @{ Edition = 'W'; Settings = $s }; @($p | Where-Object { $_.Id -eq 'Compress' })[0].Text }
        & $ids $null | Should Be 'Adk,Mount,NetFx3,Cleanup,Commit,Compress,Iso,Tidy'
        & $text $null | Should Be 'Compressing install.wim'
        & $ids @{ CleanLeftovers = $true; LeaveOutNetFx3Files = $true } | Should Be 'Adk,Mount,NetFx3,Cleanup,Leftovers,Commit,Compress,NoSxs,Iso,Tidy'
        & $text @{ Compression = 'Recovery' } | Should Be 'Compressing install.esd (recovery compression)'
        & $text @{ Compression = 'Fast' } | Should Be 'Compressing install.wim (fast compression)'
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
