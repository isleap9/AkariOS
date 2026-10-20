$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

# Mocks only: nothing here reaches GitHub, downloads a file or starts a process
function New-TestRelease([string]$Tag = 'v0.2.0', $Assets = @(@{ name = 'AkariOS-0.2.0.zip'; browser_download_url = 'https://example.test/AkariOS-0.2.0.zip'; digest = 'sha256:abc' })) {
    [pscustomobject]@{ tag_name = $Tag; html_url = "https://github.com/isleap9/AkariOS/releases/tag/$Tag"; body = "## What's new`n- faster"
        assets = @($Assets | ForEach-Object { [pscustomobject]$_ }) }
}

Describe 'Get-AkariLatestRelease' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()

    It 'reads the version, notes, page and the AkariOS zip asset' {
        Mock Invoke-AkariGitHubApi { @{ Status = 200; Body = New-TestRelease } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $true
        $r.Version | Should Be ([version]'0.2.0')
        $r.Notes | Should Be "## What's new`n- faster"
        $r.PageUrl | Should Be 'https://github.com/isleap9/AkariOS/releases/tag/v0.2.0'
        $r.AssetUrl | Should Be 'https://example.test/AkariOS-0.2.0.zip'
        $r.Digest | Should Be 'sha256:abc'
    }

    It 'says GitHub could not be reached when there is no connection' {
        Mock Invoke-AkariGitHubApi { @{ Status = 0; Body = $null; ResetAt = $null } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $false
        $r.Message | Should Be "Couldn't reach GitHub. Check the internet connection."
    }

    It 'says when the GitHub rate limit resets' {
        Mock Invoke-AkariGitHubApi { @{ Status = 429; Body = $null; ResetAt = [datetime]'2026-10-20 14:05' } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $false
        $r.Message | Should Be "GitHub's limit was reached. Try again after 14:05."
    }

    It 'says there are no releases yet (404)' {
        Mock Invoke-AkariGitHubApi { @{ Status = 404; Body = $null; ResetAt = $null } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $false
        $r.Message | Should Be 'No releases yet.'
    }

    It 'names any other GitHub error' {
        Mock Invoke-AkariGitHubApi { @{ Status = 502; Body = $null; ResetAt = $null } }
        (Get-AkariLatestRelease).Message | Should Be 'GitHub answered with error 502. Try again later.'
    }

    It 'refuses a release whose tag is not a version' {
        Mock Invoke-AkariGitHubApi { @{ Status = 200; Body = (New-TestRelease 'beta-test') } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $false
        $r.Message | Should Be "The latest release (beta-test) has no version number."
    }

    It 'still reads a release that has no zip (installing it is refused later)' {
        Mock Invoke-AkariGitHubApi { @{ Status = 200; Body = (New-TestRelease 'v0.3.0' @()) } }
        $r = Get-AkariLatestRelease
        $r.Ok | Should Be $true
        $r.AssetUrl | Should BeNullOrEmpty
    }
}

Describe 'Get-AkariUpdateStatus' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    $AkariRunPath = 'TestDrive:\run.json'
    $install = 'TestDrive:\AkariOS'
    New-Item $install -ItemType Directory | Out-Null
    $release = @{ Ok = $true; Version = [version]'0.2.0' }

    It 'is Available when the release is newer' {
        $s = Get-AkariUpdateStatus '0.1.0' $release $install $false
        $s.Kind | Should Be 'Available'
        $s.Message | Should Be 'AkariOS 0.2.0 is available (you have 0.1.0).'
    }

    It 'is Latest when the versions match' {
        $s = Get-AkariUpdateStatus '0.2.0' $release $install $false
        $s.Kind | Should Be 'Latest'
        $s.Message | Should Be 'You have the latest version (0.2.0).'
    }

    It 'is Newer when this copy is ahead of the latest release' {
        $s = Get-AkariUpdateStatus '0.3.0' $release $install $false
        $s.Kind | Should Be 'Newer'
        $s.Message | Should Be 'This copy (0.3.0) is newer than the latest release (0.2.0).'
    }

    It 'is Error with the check''s message when the check failed' {
        $s = Get-AkariUpdateStatus '0.1.0' @{ Ok = $false; Message = 'No releases yet.' } $install $false
        $s.Kind | Should Be 'Error'
        $s.Message | Should Be 'No releases yet.'
    }

    It 'is Latest without an install folder (run from GitHub through iex)' {
        $s = Get-AkariUpdateStatus '0.1.0' $release '' $false
        $s.Kind | Should Be 'Latest'
        $s.Message | Should Be 'Running the latest version from GitHub.'
    }

    It 'is Blocked while changes are being applied' {
        $s = Get-AkariUpdateStatus '0.1.0' $release $install $true
        $s.Kind | Should Be 'Blocked'
        $s.Message | Should Be 'AkariOS 0.2.0 is available. Update once the changes being applied are done.'
    }

    It 'is Blocked while a Run in phases is saved' {
        Set-Content $AkariRunPath '{}'
        $s = Get-AkariUpdateStatus '0.1.0' $release $install $false
        Remove-Item $AkariRunPath
        $s.Kind | Should Be 'Blocked'
        $s.Message | Should Be 'AkariOS 0.2.0 is available. Update once the Run in phases has finished.'
    }

    It 'is Blocked in a developer copy (a git checkout)' {
        New-Item "$install\.git" -ItemType Directory | Out-Null
        $s = Get-AkariUpdateStatus '0.1.0' $release $install $false
        Remove-Item "$install\.git"
        $s.Kind | Should Be 'Blocked'
        $s.Message | Should Be 'AkariOS 0.2.0 is available. This is a developer copy: update it with git.'
    }

    It 'is not Blocked when there is nothing to install' {
        New-Item "$install\.git" -ItemType Directory | Out-Null
        (Get-AkariUpdateStatus '0.2.0' $release $install $true).Kind | Should Be 'Latest'
        Remove-Item "$install\.git"
    }
}

Describe 'Install-AkariUpdate' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    $AkariLogFile = 'TestDrive:\akari.log'
    $AkariUpdateDir = (Join-Path $TestDrive 'update')
    $install = (Join-Path $TestDrive 'AkariOS')
    Mock Save-AkariUpdateFile { }
    Mock Start-AkariUpdater { }

    It 'refuses a release with no AkariOS zip, without downloading' {
        $r = Install-AkariUpdate @{ Ok = $true; Version = [version]'0.2.0'; AssetUrl = $null; Digest = $null } $install
        $r.Ok | Should Be $false
        $r.Message | Should Be 'The release has no AkariOS download.'
        Assert-MockCalled Save-AkariUpdateFile -Times 0 -Exactly -Scope It
    }

    It 'refuses a release with no SHA-256 checksum, without downloading' {
        $r = Install-AkariUpdate @{ Ok = $true; Version = [version]'0.2.0'; AssetUrl = 'https://example.test/a.zip'; Digest = $null } $install
        $r.Ok | Should Be $false
        $r.Message | Should Be "GitHub gave no checksum for the download, so it can't be checked. Not installing it."
        Assert-MockCalled Save-AkariUpdateFile -Times 0 -Exactly -Scope It
    }

    # a release zip on TestDrive: AkariOS\Akari.ps1 (unless -NoAkari) and AkariOS\Core\Version.ps1
    function New-TestZip([string]$Name, [switch]$NoAkari) {
        $src = Join-Path $TestDrive "src-$Name\AkariOS"
        New-Item "$src\Core" -ItemType Directory -Force | Out-Null
        Set-Content "$src\Core\Version.ps1" "`$AkariVersion = '0.2.0'"
        if (-not $NoAkari) { Set-Content "$src\Akari.ps1" '# new' }
        $zip = Join-Path $TestDrive "$Name.zip"
        Compress-Archive $src $zip
        $global:AkariTestZip = $zip
        @{ Ok = $true; Version = [version]'0.2.0'; AssetUrl = 'https://example.test/AkariOS-0.2.0.zip'
            Digest = 'sha256:' + (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() }
    }
    Mock Save-AkariUpdateFile { Copy-Item $global:AkariTestZip $OutFile }

    It 'refuses a download that does not match the checksum' {
        $rel = New-TestZip 'bad-hash'
        $rel.Digest = 'sha256:' + ('0' * 64)
        $r = Install-AkariUpdate $rel $install
        $r.Ok | Should Be $false
        $r.Message | Should Be "The download doesn't match GitHub's checksum. Not installing it."
        Assert-MockCalled Save-AkariUpdateFile -Times 1 -Exactly -Scope It
        Assert-MockCalled Start-AkariUpdater -Times 0 -Exactly -Scope It
    }

    It 'refuses a zip that is not an AkariOS release' {
        $r = Install-AkariUpdate (New-TestZip 'no-akari' -NoAkari) $install
        $r.Ok | Should Be $false
        $r.Message | Should Be "The download isn't an AkariOS release (no Akari.ps1). Not installing it."
        Assert-MockCalled Start-AkariUpdater -Times 0 -Exactly -Scope It
    }

    It 'unpacks a good release and starts the helper with it' {
        $r = Install-AkariUpdate (New-TestZip 'good') $install
        $r.Ok | Should Be $true
        $r.Message | Should Be 'Installing AkariOS 0.2.0. Akari will restart.'
        Assert-MockCalled Start-AkariUpdater -Times 1 -Exactly -Scope It -ParameterFilter {
            (Test-Path "$Staged\Akari.ps1") -and (Test-Path "$Staged\Core\Version.ps1") -and $InstallDir -eq $install -and
            $AkariPid -eq $PID -and (Test-Path $Helper) -and (Test-Path (Join-Path (Split-Path $Helper) 'Update.ps1'))
        }
    }

    Context 'the download fails' {
        Mock Save-AkariUpdateFile { throw 'The remote server returned an error: (404) Not Found.' }
        It 'says so and starts nothing' {
            $r = Install-AkariUpdate (New-TestZip 'gone') $install
            $r.Ok | Should Be $false
            $r.Message | Should Be 'The download failed: The remote server returned an error: (404) Not Found.'
            Assert-MockCalled Start-AkariUpdater -Times 0 -Exactly -Scope It
        }
    }
}

Describe 'Update-AkariFolder' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    # the installed copy (0.1.0, with a file the new release dropped) and the unpacked new one
    function New-TestFolders {
        $install = Join-Path $TestDrive 'AkariOS'
        $staged = Join-Path $TestDrive 'staged'
        foreach ($d in $install, $staged, "$install.old") { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
        New-Item "$install\Tweaks", "$staged\Tweaks" -ItemType Directory -Force | Out-Null
        Set-Content "$install\Akari.ps1" 'old'
        Set-Content "$install\Tweaks\dropped.ps1" 'old'
        Set-Content "$staged\Akari.ps1" 'new'
        Set-Content "$staged\Tweaks\added.ps1" 'new'
        @{ Install = $install; Staged = $staged }
    }

    It 'replaces the folder: new files in, dropped files gone, the old copy kept as .old' {
        $t = New-TestFolders
        $r = Update-AkariFolder $t.Staged $t.Install
        $r.Ok | Should Be $true
        Get-Content "$($t.Install)\Akari.ps1" | Should Be 'new'
        Test-Path "$($t.Install)\Tweaks\added.ps1" | Should Be $true
        Test-Path "$($t.Install)\Tweaks\dropped.ps1" | Should Be $false
        Get-Content "$($t.Install).old\Akari.ps1" | Should Be 'old'
    }

    Context 'copying the new files fails' {
        Mock Copy-Item { throw 'disk full' }
        It 'puts the old folder back' {
            $t = New-TestFolders
            $r = Update-AkariFolder $t.Staged $t.Install
            $r.Ok | Should Be $false
            $r.Message | Should Be 'The update failed (disk full). The old version was put back.'
            Get-Content "$($t.Install)\Akari.ps1" | Should Be 'old'
            Test-Path "$($t.Install)\Tweaks\dropped.ps1" | Should Be $true
            Test-Path "$($t.Install).old" | Should Be $false
        }
    }

    Context 'the install folder cannot be moved (a file in use)' {
        Mock Move-Item { throw 'in use' }
        It 'changes nothing' {
            $t = New-TestFolders
            $r = Update-AkariFolder $t.Staged $t.Install
            $r.Ok | Should Be $false
            $r.Message | Should Be "The update failed (in use). Nothing was changed."
            Get-Content "$($t.Install)\Akari.ps1" | Should Be 'old'
        }
    }
}

Describe 'Remove-AkariUpdateLeftover' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    It 'deletes the .old copy and the download folder' {
        $install = Join-Path $TestDrive 'AkariOS'
        $AkariUpdateDir = Join-Path $TestDrive 'update'
        New-Item $install, "$install.old", $AkariUpdateDir -ItemType Directory -Force | Out-Null
        Remove-AkariUpdateLeftover $install
        Test-Path "$install.old" | Should Be $false
        Test-Path $AkariUpdateDir | Should Be $false
        Test-Path $install | Should Be $true
    }

    It 'does nothing without an install folder (run through iex)' {
        { Remove-AkariUpdateLeftover '' } | Should Not Throw
    }
}

Describe 'ConvertTo-AkariNotesText' {
    foreach ($f in 'Log', 'Update') { . "$Core\$f.ps1" }
    It 'turns release notes Markdown into plain text' {
        $md = "## What's new`r`n`r`n- **Update** section: see [the wiki](https://example.test/wiki)`r`n* fixed ``Akari.ps1`` start`r`n`r`n`r`n`r`n### Thanks`r`n__everyone__"
        ConvertTo-AkariNotesText $md | Should Be ("What's new`n`n" + [char]0x2022 + " Update section: see the wiki`n" + [char]0x2022 + " fixed Akari.ps1 start`n`nThanks`neveryone")
    }

    It 'is empty for no notes' {
        ConvertTo-AkariNotesText '' | Should Be ''
    }
}
