$Root = Join-Path (Split-Path $PSScriptRoot) 'src'

# winget.exe and App Installer are never reached: Invoke-AkariWinget, Register-AkariAppInstaller and
# Install-AkariAppInstaller are mocked in every test that could get to them (AGENTS.md rule 12). Fake package ids only.
Describe 'Winget' {
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    foreach ($f in 'Log', 'Winget') { . "$Root\Core\$f.ps1" }
    $state = @{ Version = 'v1.29.380'; Calls = [Collections.Generic.List[string]]::new() }
    Mock Invoke-AkariWinget {
        $state.Calls.Add(($Arguments -join ' '))
        switch ($Arguments[0]) {
            '--version' { if ($state.Version) { @{ Code = 0; Out = @($state.Version) } } else { throw 'winget is not available' } }
            'install' {
                switch ($Arguments[2]) {
                    'Akari.Test.Ok' { @{ Code = 0; Out = @('Successfully installed') } }
                    'Akari.Test.There' { @{ Code = -1978335135; Out = @('Found an existing package already installed.') } }
                    default { @{ Code = -1978335212; Out = @('  -  ', 'No package found matching input criteria.') } }
                }
            }
            'list' { if ($Arguments[2] -eq 'Akari.Test.There') { @{ Code = 0; Out = @('Name  Id  Version', 'There  Akari.Test.There  1.0') } } else { @{ Code = -1978335212; Out = @('No installed package found matching input criteria.') } } }
        }
    }
    Mock Register-AkariAppInstaller { }
    Mock Install-AkariAppInstaller { }

    It 'installs silently from the winget source, accepting the agreements' {
        $script:AkariWingetReady = $false
        Install-AkariWingetPackage 'Akari.Test.Ok'
        $line = $state.Calls | Where-Object { $_ -like 'install *' } | Select-Object -Last 1
        $line | Should Be 'install --id Akari.Test.Ok --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
    }

    It 'treats already installed as done' { { Install-AkariWingetPackage 'Akari.Test.There' } | Should Not Throw }

    Context 'Microsoft Store source' {
        Mock Install-AkariMicrosoftStore { }
        It 'makes sure the Store is there, then installs from the msstore source' {
            Install-AkariWingetPackage 'Akari.Test.Ok' 'msstore'
            Assert-MockCalled Install-AkariMicrosoftStore -Times 1 -Exactly -Scope It
            ($state.Calls | Where-Object { $_ -like 'install *' } | Select-Object -Last 1) | Should Match '--source msstore'
        }
        It 'does not touch the Store for a winget-source install' {
            Install-AkariWingetPackage 'Akari.Test.Ok'
            Assert-MockCalled Install-AkariMicrosoftStore -Times 0 -Exactly -Scope It
        }
    }

    It 'fails with the code and winget''s last line' {
        { Install-AkariWingetPackage 'Akari.Test.Missing' } | Should Throw '0x8A150014'
        { Install-AkariWingetPackage 'Akari.Test.Missing' } | Should Throw 'No package found'
    }

    It 'tells installed from not installed' {
        Test-AkariWingetInstalled 'Akari.Test.There' | Should Be $true
        Test-AkariWingetInstalled 'Akari.Test.Missing' | Should Be $false
    }

    # Pester 3: a Mock lasts until the end of its Describe or Context, so each override gets its own Context
    Context 'winget missing' {
        Mock Invoke-AkariWinget { throw 'winget is not available' }
        It 'is not installed when winget is missing' { Test-AkariWingetInstalled 'Akari.Test.There' | Should Be $false }
    }

    It 'leaves a recent winget alone' {
        $script:AkariWingetReady = $false; $state.Version = 'v1.29.380'
        Install-AkariWingetTool
        Assert-MockCalled Register-AkariAppInstaller -Times 0 -Exactly -Scope It
        Assert-MockCalled Install-AkariAppInstaller -Times 0 -Exactly -Scope It
    }

    Context 'registering is enough' {
        Mock Register-AkariAppInstaller { $state.Version = 'v1.29.380' }
        It 'registers App Installer first, and downloads nothing when that is enough' {
            $script:AkariWingetReady = $false; $state.Version = $null
            Install-AkariWingetTool
            Assert-MockCalled Register-AkariAppInstaller -Times 1 -Exactly -Scope It
            Assert-MockCalled Install-AkariAppInstaller -Times 0 -Exactly -Scope It
        }
    }

    Context 'too old' {
        Mock Install-AkariAppInstaller { $state.Version = 'v1.29.380' }
        It 'installs App Installer when winget is too old' {
            $script:AkariWingetReady = $false; $state.Version = 'v1.2.10'
            Install-AkariWingetTool
            Assert-MockCalled Install-AkariAppInstaller -Times 1 -Exactly -Scope It
        }
    }

    It 'fails when winget is still missing after installing App Installer' {
        $script:AkariWingetReady = $false; $state.Version = $null
        { Install-AkariWingetTool } | Should Throw 'could not be installed'
    }

    Context 'forced (tools-fix-winget)' {
        Mock Install-AkariAppInstaller { $state.Version = 'v1.29.380' }
        It 'installs App Installer again even when winget works and was checked' {
            $script:AkariWingetReady = $true; $state.Version = 'v1.29.380'
            Install-AkariWingetTool -Force
            Assert-MockCalled Install-AkariAppInstaller -Times 1 -Exactly -Scope It
            Assert-MockCalled Register-AkariAppInstaller -Times 0 -Exactly -Scope It
        }
    }
}

# winutil W4: uninstall, update all, the installed list. Invoke-AkariWinget answers from $w.Codes (by package id, or
# 'upgrade' / 'list'); nothing real is called.
Describe 'Winget: uninstall, update all and the installed list' {
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    foreach ($f in 'Log', 'Winget') { . "$Root\Core\$f.ps1" }
    $w = @{ Calls = [Collections.Generic.List[string]]::new(); Codes = @{}; Out = @{} }
    Mock Install-AkariWingetTool { }
    Mock Invoke-AkariWinget {
        $w.Calls.Add(($Arguments -join ' '))
        $key = if ($Arguments[0] -eq 'uninstall') { $Arguments[2] } else { $Arguments[0] }
        $out = if ($w.Out.ContainsKey($key)) { @($w.Out[$key]) } else { @() }
        @{ Code = $(if ($w.Codes.ContainsKey($key)) { $w.Codes[$key] } else { 0 }); Out = $out }
    }

    It 'uninstalls one package silently, by its exact id and source' {
        Uninstall-AkariWingetPackage 'Akari.Test.Ok' | Should Be 'Uninstalled'
        $w.Calls[-1] | Should Be 'uninstall --id Akari.Test.Ok --exact --source winget --silent --accept-source-agreements --disable-interactivity'
        Uninstall-AkariWingetPackage '9TESTSTOREID' 'msstore' | Should Be 'Uninstalled'
        $w.Calls[-1] | Should Match '--source msstore'
    }

    It 'tells a restart, a missing app and a per-user install apart' {
        $w.Codes = @{ 'A.Restart' = 3010; 'A.Restart2' = -1978334967; 'A.Missing' = -1978335212; 'A.User' = -1978335107 }
        Uninstall-AkariWingetPackage 'A.Restart' | Should Be 'Restart'
        Uninstall-AkariWingetPackage 'A.Restart2' | Should Be 'Restart'
        Uninstall-AkariWingetPackage 'A.Missing' | Should Be 'Missing'
        Uninstall-AkariWingetPackage 'A.User' | Should Be 'UserOnly'
    }

    It 'fails an uninstall with the code and winget''s last line' {
        $w.Codes = @{ 'A.Bad' = -1978335226 }; $w.Out = @{ 'A.Bad' = @('Uninstall failed with exit code: 1603', '  -  ') }
        { Uninstall-AkariWingetPackage 'A.Bad' } | Should Throw 'winget could not uninstall A.Bad (0x8A150006): Uninstall failed with exit code: 1603'
    }

    It 'updates every app in one call, pinned ones left to winget' {
        $w.Codes = @{}; $w.Out = @{ upgrade = @('Found Steam [Valve.Steam] Version 2', '  -  ', 'Successfully installed') }
        Update-AkariWingetPackages | Should Be 'Updated'
        $w.Calls[-1] | Should Be 'upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
        $log = $LogQueue.ToArray()
        ($log -contains 'winget: Found Steam [Valve.Steam] Version 2') | Should Be $true
        ($log -contains 'winget:   -  ') | Should Be $false
    }

    It 'counts nothing to update and a wanted restart as done' {
        $w.Out = @{}; $w.Codes = @{ upgrade = -1978335189 }
        Update-AkariWingetPackages | Should Be 'UpToDate'
        $w.Codes = @{ upgrade = 3010 }
        Update-AkariWingetPackages | Should Be 'Restart'
    }

    It 'fails the update with the code and winget''s last line' {
        $w.Codes = @{ upgrade = -1978335188 }; $w.Out = @{ upgrade = @('2 package(s) failed to upgrade.') }
        { Update-AkariWingetPackages } | Should Throw 'winget could not update every app (0x8A15002C): 2 package(s) failed to upgrade.'
    }

    It 'reads winget''s list of installed apps as lines' {
        $w.Codes = @{}; $w.Out = @{ list = @('Name  Id  Version', 'Steam  Valve.Steam  2') }
        @(Get-AkariWingetList).Count | Should Be 2
        $w.Calls[-1] | Should Be 'list --accept-source-agreements --disable-interactivity'
        $w.Codes = @{ list = -1978335212 }
        @(Get-AkariWingetList).Count | Should Be 0
    }

    It 'finds the ids that stand as a column of their own in that list' {
        $lines = 'Name                Id                    Version  Source',
                 '------------------------------------------------------',
                 'Steam               Valve.Steam           2.10     winget',
                 'Git Extensions Git  GitExtensionsTeam.Git 4.0      winget',
                 'Brave               brave.brave           1.60',
                 'WhatsApp            9NKSQGP7F2NH          2.24     msstore',
                 'Chrome Google.Chrome.EXE 120 winget'
        $found = @(Get-AkariInstalledIds $lines @('Valve.Steam', 'Git.Git', 'Brave.Brave', '9NKSQGP7F2NH', 'Google.Chrome.EXE', 'Google.Chrome', 'Mozilla.Firefox'))
        ($found -join ',') | Should Be 'Valve.Steam,Brave.Brave,9NKSQGP7F2NH,Google.Chrome.EXE'
        @(Get-AkariInstalledIds @() @('Valve.Steam')).Count | Should Be 0
    }

    Context 'winget missing' {
        Mock Invoke-AkariWinget { throw 'winget is not available' }
        It 'has an empty list when winget is missing' { @(Get-AkariWingetList).Count | Should Be 0 }
    }
}

Describe 'Uninstall-AkariApp and the installed apps' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Winget', 'Runner') { . "$Root\Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $u = @{ Calls = [Collections.Generic.List[string]]::new(); Results = @{}; List = @() }
    Mock Uninstall-AkariWingetPackage {
        $u.Calls.Add("$Id $Source")
        $r = if ($u.Results.ContainsKey($Id)) { $u.Results[$Id] } else { 'Uninstalled' }
        if ($r -like 'throw*') { throw $r.Substring(6) }
        $r
    }
    Mock Get-AkariWingetList { $u.List }
    Set-Content "$TestDrive\T.ps1" '@{}'
    function New-App([string]$Id, $More) {
        ConvertTo-AkariTweak (@{ Id = $Id; Name = $Id; Section = 'Apps'; Category = 'Install'; Kind = 'Action' } + $More) "$TestDrive\T.ps1" $false
    }

    It 'uninstalls every id of the app, last first' {
        $o = Uninstall-AkariApp (New-App 'two' @{ Winget = 'A.One', 'A.Two' })
        "$($o.Outcome) $($o.Mode) $($o.Reboot)" | Should Be 'Reverted Revert False'
        ($u.Calls -join ',') | Should Be 'A.Two winget,A.One winget'
    }

    It 'uninstalls a Store app from the msstore source' {
        $u.Calls.Clear()
        (Uninstall-AkariApp (New-App 'store' @{ Winget = '9TESTSTOREID'; WingetSource = 'msstore' })).Outcome | Should Be 'Reverted'
        $u.Calls[0] | Should Be '9TESTSTOREID msstore'
    }

    It 'asks for a restart when winget says so' {
        $u.Results = @{ 'A.One' = 'Restart' }
        (Uninstall-AkariApp (New-App 'r' @{ Winget = 'A.One' })).Reboot | Should Be $true
    }

    It 'is Already when nothing of it is installed' {
        $u.Results = @{ 'A.One' = 'Missing'; 'A.Two' = 'Missing' }
        $o = Uninstall-AkariApp (New-App 'gone' @{ Winget = 'A.One', 'A.Two' })
        "$($o.Outcome): $($o.Message)" | Should Be 'Already: not installed'
    }

    It 'skips a per-user install, pointing at Windows' {
        $u.Results = @{ 'A.One' = 'UserOnly' }
        $o = Uninstall-AkariApp (New-App 'user' @{ Winget = 'A.One' })
        "$($o.Outcome): $($o.Message)" | Should Be "Skipped: installed for this user only: uninstall it from Windows' Installed apps"
    }

    It 'goes on after an id fails, and fails with its message' {
        $u.Calls.Clear(); $u.Results = @{ 'A.Two' = 'throw winget could not uninstall A.Two (0x8A150006): no' }
        $o = Uninstall-AkariApp (New-App 'bad' @{ Winget = 'A.One', 'A.Two' })
        "$($o.Outcome): $($o.Message)" | Should Be 'Failed: winget could not uninstall A.Two (0x8A150006): no'
        $u.Calls.Count | Should Be 2
    }

    It 'never uninstalls an app with no winget id or with its own removal' {
        $u.Calls.Clear()
        $o = Uninstall-AkariApp (New-App 'file' @{ Apply = { }; Detect = { $true } })
        "$($o.Outcome): $($o.Message)" | Should Be "Skipped: not installed with winget: uninstall it from Windows' Installed apps"
        $o = Uninstall-AkariApp (New-App 'edge' @{ Winget = 'A.One'; RemoveWith = 'remove-edge' })
        "$($o.Outcome): $($o.Message)" | Should Be 'Skipped: has its own removal: use Remove apps'
        $u.Calls.Count | Should Be 0
    }

    It 'lists the installs on this PC: every winget id in the list, or its own Detect' {
        $u.List = 'Name  Id  Version', 'One  A.One  1', 'Two  A.Two  1', 'Three  A.Three  1'
        $apps = @(
            (New-App 'both' @{ Winget = 'A.One', 'A.Two' }), (New-App 'half' @{ Winget = 'A.One', 'A.Nine' }), (New-App 'none' @{ Winget = 'A.Nine' }),
            (New-App 'there' @{ Apply = { }; Detect = { $true } }), (New-App 'notthere' @{ Apply = { }; Detect = { $false } }),
            (New-App 'broken' @{ Apply = { }; Detect = { throw 'no' } }), (New-App 'blind' @{ Apply = { } })
        )
        (@(Get-AkariInstalledApps $apps) -join ',') | Should Be 'both,there'
    }

    It 'marks the installs that have their own removal, and ships Update all apps' {
        $r = Get-AkariTweaks "$Root\Tweaks"
        @($r.Problems | Where-Object { $_.Level -eq 'Error' }).Count | Should Be 0
        $with = @($r.Tweaks | Where-Object { $_.RemoveWith } | Sort-Object Id | ForEach-Object { "$($_.Id)=$($_.RemoveWith)" })
        ($with -join ',') | Should Be 'install-microsoft-edge=remove-edge,install-onedrive=remove-onedrive,install-remote-desktop-connection=remove-remote-desktop-connection,install-snipping-tool-legacy=remove-snipping-tool-legacy,install-webview2-runtime=remove-webview2'
        foreach ($id in @($r.Tweaks | Where-Object { $_.RemoveWith } | ForEach-Object { $_.RemoveWith })) { @($r.Tweaks | Where-Object { $_.Id -eq $id }).Count | Should Be 1 }
        $up = $r.Tweaks | Where-Object { $_.Id -eq 'tools-update-apps' }
        "$($up.Section)/$($up.Category) $($up.Kind) $([bool]$up.AkariOS)" | Should Be 'Tools/Setup Action False'
        "$($up.Apply)".Trim() | Should Be 'Update-AkariWingetPackages | Out-Null'
    }
}

Describe 'AppSetup' {
    foreach ($f in 'Log', 'Registry', 'AppSetup') { . "$Root\Core\$f.ps1" }
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    try {
        It 'removes matching autostart values only, wildcards included' {
            Set-Reg $k 'Steam' 'x' 'String'; Set-Reg $k 'Mozilla-Firefox-1' 'x' 'String'; Set-Reg $k 'Keep' 'x' 'String'
            Remove-AkariStartup 'Steam', '*Firefox*' -Keys $k
            Get-AkariRegValue $k 'Steam' | Should BeNullOrEmpty
            Get-AkariRegValue $k 'Mozilla-Firefox-1' | Should BeNullOrEmpty
            Get-AkariRegValue $k 'Keep' | Should Be 'x'
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }

    It 'downloads from AkariOS-Files into a new folder' {
        Mock Invoke-WebRequest { }
        Save-AkariFile 'cru.exe' "$TestDrive\x\CRU.exe" | Should Be "$TestDrive\x\CRU.exe"
        Test-Path "$TestDrive\x" | Should Be $true
        Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://github.com/isleap9/AkariOS-Files/releases/download/Files/cru.exe' }
    }

    It 'stops and deletes the matching services and tasks only' {
        Mock Get-Service { [pscustomobject]@{ Name = 'BraveUpdate' }, [pscustomobject]@{ Name = 'Spooler' } }
        Mock Stop-Service { }
        Mock Remove-AkariService { }
        Mock Get-ScheduledTask { [pscustomobject]@{ TaskName = 'BraveSoftwareUpdateTaskMachine' } }
        Mock Unregister-ScheduledTask { }
        Mock Get-ChildItem { }
        Remove-AkariUpdaters 'Brave'
        Assert-MockCalled Remove-AkariService -Times 1 -Exactly -ParameterFilter { $Name -eq 'BraveUpdate' }
        Assert-MockCalled Unregister-ScheduledTask -Times 1 -Exactly
    }
}

Describe 'Get-AkariUserFolder' {
    foreach ($f in 'Registry') { . "$Root\Core\$f.ps1" }
    It 'builds the folder from the profile when the user''s Shell Folders cannot be read' {
        $script:AkariUserSid = 'S-1-5-21-0-0-0-99999'
        try { Get-AkariUserFolder 'AppData' | Should Be "$env:USERPROFILE\AppData\Roaming" }
        finally { $script:AkariUserSid = $null }
    }
}

Describe 'Runner: files next to a tweak' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    It 'gives Apply the tweak file''s folder as $AkariTweakDir' {
        Set-Content "$TestDrive\T.ps1" '@{}'
        $env:AKARI_TEST_FILE = "$TestDrive\dir.txt"
        $t = ConvertTo-AkariTweak @{ Id = 'dir'; Name = 'Dir'; Kind = 'Action'; Apply = { Set-Content $env:AKARI_TEST_FILE $AkariTweakDir } } "$TestDrive\T.ps1" $false
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
        Get-Content "$TestDrive\dir.txt" | Should Be "$TestDrive"
    }
}

Describe 'The real app installs' {
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    $r = Get-AkariTweaks "$Root\Tweaks"
    $apps = @($r.Tweaks | Where-Object { $_.Section -eq 'Apps' -and $_.Category -eq 'Install' -and -not $_.Group })
    $store = @($r.Tweaks | Where-Object { $_.Group -eq 'store' })

    It 'puts every app in an Install-tab card' {
        @($apps | Where-Object { -not $_.AppType }).Count | Should Be 0
    }

    It 'has no single-game launcher left (Valorant, Roblox, League of Legends, Tarkov)' {
        @($apps | Where-Object { $_.Id -in 'install-valorant', 'install-roblox', 'install-league-of-legends', 'install-escape-from-tarkov' }).Count | Should Be 0
    }

    It 'never stops an installer that is still running after winget returns (Discord''s Update.exe)' {
        $d = $apps | Where-Object { $_.Id -eq 'install-discord' }
        "$($d.Apply)" | Should Not Match "Stop-Process[^\n]*'Update'"
        "$($d.Apply)" | Should Match 'Wait-Process'
    }

    It 'installs WhatsApp from the Microsoft Store through winget' {
        $w = $apps | Where-Object { $_.Id -eq 'install-whatsapp' }
        "$($w.Apply)".Trim() | Should Be "Install-AkariWingetPackage '9NKSQGP7F2NH' 'msstore'"
        "$($w.Detect)" | Should Be "(Test-AkariWingetInstalled '9NKSQGP7F2NH' 'msstore')"
    }

    It 'can download again the Store apps the debloat removes, from their Store ids' {
        $store.Count | Should BeGreaterThan 30
        $p = $store | Where-Object { $_.Package -eq 'Microsoft.Windows.Photos' }
        $p.Button | Should Be 'Install'
        $p.AppType | Should Be 'Restore removed apps'
        "$($p.Apply)" | Should Be "Install-AkariWingetPackage '9WZDNCRFJBH4' 'msstore'"
        "$($p.Detect)" | Should Be "Test-AkariAppxInstalled 'Microsoft.Windows.Photos'"
    }

    It 'loads every install with no Errors' {
        @($r.Problems | Where-Object { $_.Level -eq 'Error' }).Count | Should Be 0
        # + OneDrive, Remote Desktop Connection, Snipping Tool (Windows 10) in the restore card (batch 2c);
        # + winutil W5a's 79, W5b's 52
        $apps.Count | Should Be 201
    }

    It 'installs most apps with winget' { @($apps | Where-Object { $_.Winget }).Count | Should Be 192 }

    # winutil W5: the cards hold at most 30 rows, and every app has a named card (nothing under Other)
    . "$Root\UI\Apps.ps1"
    It 'puts every app in a named card of at most 30 rows' {
        @($apps | Where-Object { $_.AppType -notin @($AkariAppTypes) + $AkariRestoreType } | ForEach-Object { $_.Id }) -join ', ' | Should Be ''
        @($apps | Group-Object AppType | Where-Object { $_.Name -ne $AkariRestoreType -and $_.Count -gt 30 } | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ' | Should Be ''
    }

    $w5 = @(Get-ChildItem "$Root\Tweaks\Apps\Install\*.ps1" | Where-Object { (Get-Content $_.FullName -TotalCount 3) -match 'config/applications\.json' })
    It 'takes winutil''s apps as data-only winget installs, credited, Safe or Caution' {
        $w5.Count | Should Be 131
        foreach ($f in $w5) {
            $d = Import-PowerShellDataFile $f.FullName
            $bad = @()
            if (-not $d.Winget) { $bad += 'no Winget' }
            if (@($d.Keys | Where-Object { $d[$_] -is [scriptblock] }).Count) { $bad += 'a script block' }
            if ($d.Risk -notin 'Safe', 'Caution') { $bad += "Risk $($d.Risk)" }
            if ($d.AkariOS) { $bad += 'AkariOS' }
            if (((Get-Content $f.FullName -TotalCount 3) -join "`n") -notmatch 'Chris Titus Tech''s winutil \(MIT, Copyright \(c\) 2022 CT Tech Group LLC\)') { $bad += 'no credit' }
            "$($f.Name): $($bad -join ', ')" | Should Be "$($f.Name): "
        }
    }

    It 'gives every install its own id and winget id' {
        @($apps | Group-Object Id | Where-Object Count -gt 1 | ForEach-Object Name) -join ', ' | Should Be ''
        @($apps | ForEach-Object { @($_.Winget) } | Where-Object { $_ } | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name) -join ', ' | Should Be ''
    }

    It 'ships the files the installs copy' {
        foreach ($p in 'NotepadPlusPlus\config.xml', 'Afterburner\MSI Afterburner\Profiles\MSIAfterburner.cfg',
                       'Afterburner\RivaTuner Statistics Server\Plugins\Client\Overlays\akarios.ovl') {
            Test-Path "$Root\Tweaks\Apps\Install\Files\$p" | Should Be $true
        }
    }

    It 'has no legacy installer left' { Test-Path "$Root\Tweaks\Installers.ps1" | Should Be $false }
}

Describe 'Install-AkariMicrosoftStore' {
    $Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'
    foreach ($f in 'Log', 'Registry', 'Appx', 'Winget') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    Mock Add-AppxPackage { }
    Mock Install-AkariWingetTool { }
    Mock Start-Process { }
    Mock Start-Sleep { }
    Context 'already there' {
        Mock Test-AkariAppxInstalled { $true }
        Mock Invoke-AkariWinget { @{ Code = 0; Out = @() } }
        It 'does nothing' {
            Install-AkariMicrosoftStore
            Assert-MockCalled Invoke-AkariWinget -Exactly 0 -Scope It
            Assert-MockCalled Start-Process -Exactly 0 -Scope It
        }
    }
    Context 'removed for every user (no copy on the disk): winget brings it back' {
        $script:wingetRan = $false
        Mock Get-AkariAppxPackages { }
        Mock Test-AkariAppxInstalled { $script:wingetRan }
        Mock Invoke-AkariWinget { $script:wingetRan = $true; @{ Code = 0; Out = @() } }
        It 'installs product 9WZDNCRFJBMP from msstore and never needs wsreset' {
            Install-AkariMicrosoftStore
            Assert-MockCalled Invoke-AkariWinget -Exactly 1 -Scope It -ParameterFilter { ($Arguments -join ' ') -match '^install --id 9WZDNCRFJBMP --exact --source msstore ' }
            Assert-MockCalled Start-Process -Exactly 0 -Scope It
        }
    }
    Context 'winget fails too' {
        Mock Get-AkariAppxPackages { }
        Mock Test-AkariAppxInstalled { $false }
        Mock Invoke-AkariWinget { @{ Code = -1; Out = @('No applicable installer') } }
        It 'falls back to wsreset -i, then says so when it is still not there' {
            { Install-AkariMicrosoftStore } | Should Throw 'still downloading'
            Assert-MockCalled Start-Process -Exactly 1 -Scope It -ParameterFilter { $FilePath -like '*wsreset.exe' -and $ArgumentList -eq '-i' }
            ($LogQueue.ToArray() -join '|') | Should Match 'winget failed'
        }
    }
}
