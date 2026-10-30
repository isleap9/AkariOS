$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Repo = Split-Path $PSScriptRoot

# The one-liner's bootstrap (build\Bootstrap.ps1) and the AkariOS.exe launcher (build\Launcher.cs). Never a real
# download (Save-AkariBootZip builds a zip in TestDrive), never a real install, shortcut or Akari start
# ($AkariBootNoRun; the install folder is in TestDrive). The launcher is compiled here, never run.
Describe 'Bootstrap (the one-liner)' {
    $AkariBootNoRun = $true
    . "$Repo\build\Bootstrap.ps1"
    # a release zip: one AkariOS\ folder with Akari.ps1, its version and the launcher
    function New-Release([string]$Version, [string]$Zip) {
        $src = "$TestDrive\src-$Version\AkariOS"
        New-Item "$src\Core" -ItemType Directory -Force | Out-Null
        Set-Content "$src\Akari.ps1" '# app'
        Set-Content "$src\AkariOS.exe" 'exe'
        Set-Content "$src\Core\Version.ps1" "`$AkariVersion = '$Version'"
        Compress-Archive $src $Zip -Force
        (Get-FileHash $Zip -Algorithm SHA256).Hash
    }
    $sha = New-Release '1.1.0' "$TestDrive\release.zip"
    Mock Save-AkariBootZip { Copy-Item "$TestDrive\release.zip" $Out }
    $dir = "$TestDrive\AkariOS"

    It 'is the source: placeholders for the workflow, ASCII only (iex reads it as text)' {
        $text = Get-Content "$Repo\build\Bootstrap.ps1" -Raw
        $text | Should Match "AkariBootVersion = '__AKARI_VERSION__'"
        $text | Should Match "AkariBootSha256 = '__AKARI_SHA256__'"
        [regex]::IsMatch($text, '[^\x00-\x7F]') | Should Be $false
        (Get-Content "$Repo\.github\workflows\release.yml" -Raw) | Should Match 'build/Bootstrap\.ps1'
    }
    It 'parses once the workflow has filled it in' {
        $text = (Get-Content "$Repo\build\Bootstrap.ps1" -Raw).Replace('__AKARI_VERSION__', '1.0.0').Replace('__AKARI_SHA256__', ('A' * 64))
        $errs = $null
        [void][Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
        @($errs).Count | Should Be 0
    }
    It 'downloads the release''s own zip' {
        Get-AkariBootZipUrl '1.2.3' | Should Be 'https://github.com/isleap9/AkariOS/releases/download/v1.2.3/AkariOS-1.2.3.zip'
    }
    It 'refuses a zip whose SHA-256 does not match, and installs nothing' {
        { Install-AkariBootApp '1.1.0' ('0' * 64) $dir } | Should Throw 'checksum'
        Test-Path $dir | Should Be $false
    }
    It 'installs a matching zip into the folder and returns its AkariOS.exe' {
        $exe = Install-AkariBootApp '1.1.0' $sha.ToLower() $dir
        $exe | Should Be "$dir\AkariOS.exe"
        Test-Path "$dir\Akari.ps1" | Should Be $true
        Get-AkariBootInstalled $dir | Should Be '1.1.0'
    }
    It 'keeps the same version as it is, without downloading' {
        Install-AkariBootApp '1.1.0' $sha $dir | Should Be "$dir\AkariOS.exe"
        Assert-MockCalled Save-AkariBootZip -Scope It -Exactly 0
    }
    It 'replaces an older install, leaving no .old folder' {
        Set-Content "$dir\Core\Version.ps1" "`$AkariVersion = '1.0.0'"
        Set-Content "$dir\stale.txt" 'old'
        Install-AkariBootApp '1.1.0' $sha $dir | Out-Null
        Get-AkariBootInstalled $dir | Should Be '1.1.0'
        Test-Path "$dir\stale.txt" | Should Be $false
        Test-Path "$dir.old" | Should Be $false
    }
}

Describe 'AkariOS.exe (build\Launcher.cs)' {
    It 'compiles with the .NET Framework compiler, the icon and the administrator manifest, as the release does' {
        $csc = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
        $out = "$TestDrive\AkariOS.exe"
        $log = & $csc -nologo -target:exe -platform:anycpu "-win32icon:$Root\Assets\AkariLogo.ico" "-win32manifest:$Repo\build\Launcher.manifest" "-out:$out" "$Repo\build\Launcher.cs" 2>&1
        ($log -join "`n") | Should BeNullOrEmpty
        Test-Path $out | Should Be $true
        (Get-Content "$Repo\build\Launcher.manifest" -Raw) | Should Match 'requireAdministrator'
        (Get-Content "$Repo\.github\workflows\release.yml" -Raw) | Should Match 'build/Launcher\.cs'
    }
    It 'starts Akari.ps1 from its own folder with the execution policy bypassed, and does not wait' {
        $cs = Get-Content "$Repo\build\Launcher.cs" -Raw
        $cs | Should Match 'Path\.Combine\(dir, "Akari\.ps1"\)'
        $cs | Should Match '-ExecutionPolicy Bypass -STA -File'
        $cs | Should Not Match 'WaitForExit'
    }
}
