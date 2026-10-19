$Root = Split-Path $PSScriptRoot

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
        $apps.Count | Should Be 67
    }

    It 'installs most apps with winget' { @($apps | Where-Object { $_.Winget }).Count | Should Be 60 }

    It 'ships the files the installs copy' {
        foreach ($p in 'NotepadPlusPlus\config.xml', 'Afterburner\MSI Afterburner\Profiles\MSIAfterburner.cfg',
                       'Afterburner\RivaTuner Statistics Server\Plugins\Client\Overlays\akarios.ovl') {
            Test-Path "$Root\Tweaks\Apps\Install\Files\$p" | Should Be $true
        }
    }

    It 'has no legacy installer left' { Test-Path "$Root\Tweaks\Installers.ps1" | Should Be $false }
}
