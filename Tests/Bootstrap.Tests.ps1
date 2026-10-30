$Root = Split-Path $PSScriptRoot

# The one-liner's bootstrap (Build\Bootstrap.ps1): never a real download (Save-AkariBootZip is mocked to build a zip
# in TestDrive), never a real Akari start ($AkariBootNoRun).
Describe 'Bootstrap (the one-liner)' {
    $AkariBootNoRun = $true
    . "$Root\Build\Bootstrap.ps1"
    # a release zip: one AkariOS\ folder with an Akari.ps1
    New-Item "$TestDrive\src\AkariOS" -ItemType Directory -Force | Out-Null
    Set-Content "$TestDrive\src\AkariOS\Akari.ps1" '# app'
    Compress-Archive "$TestDrive\src\AkariOS" "$TestDrive\release.zip"
    $sha = (Get-FileHash "$TestDrive\release.zip" -Algorithm SHA256).Hash
    Mock Save-AkariBootZip { Copy-Item "$TestDrive\release.zip" $Out }
    $base = "$TestDrive\app"

    It 'is the source: placeholders for the workflow, ASCII only (iex reads it as text)' {
        $text = Get-Content "$Root\Build\Bootstrap.ps1" -Raw
        $text | Should Match "AkariBootVersion = '__AKARI_VERSION__'"
        $text | Should Match "AkariBootSha256 = '__AKARI_SHA256__'"
        [regex]::IsMatch($text, '[^\x00-\x7F]') | Should Be $false
        (Get-Content "$Root\.github\workflows\release.yml" -Raw) | Should Match 'Build/Bootstrap\.ps1'
    }
    It 'parses once the workflow has filled it in' {
        $text = (Get-Content "$Root\Build\Bootstrap.ps1" -Raw).Replace('__AKARI_VERSION__', '1.0.0').Replace('__AKARI_SHA256__', ('A' * 64))
        $errs = $null
        [void][Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
        @($errs).Count | Should Be 0
    }
    It 'downloads the release''s own zip' {
        Get-AkariBootZipUrl '1.2.3' | Should Be 'https://github.com/isleap9/AkariOS/releases/download/v1.2.3/AkariOS-1.2.3.zip'
    }
    It 'refuses a zip whose SHA-256 does not match, and leaves nothing behind' {
        { Install-AkariBootApp '1.0.0' ('0' * 64) $base } | Should Throw 'checksum'
        Test-Path "$base\1.0.0" | Should Be $false
        Test-Path "$base\AkariOS-1.0.0.zip" | Should Be $false
    }
    It 'unpacks a matching zip, marks it, and removes older versions' {
        New-Item "$base\0.9.0\AkariOS" -ItemType Directory -Force | Out-Null
        $p = Install-AkariBootApp '1.0.0' $sha.ToLower() $base
        $p | Should Be "$base\1.0.0\AkariOS\Akari.ps1"
        Test-Path $p | Should Be $true
        Get-Content "$base\1.0.0\AkariOS\.bootstrap" | Should Be '1.0.0'
        Test-Path "$base\0.9.0" | Should Be $false
        Test-Path "$base\AkariOS-1.0.0.zip" | Should Be $false
    }
    It 'reuses the unpacked version without downloading again' {
        Install-AkariBootApp '1.0.0' $sha $base | Should Be "$base\1.0.0\AkariOS\Akari.ps1"
        Assert-MockCalled Save-AkariBootZip -Scope It -Exactly 0
    }
    It 'Akari.ps1 offers no self-update from the bootstrap''s copy' {
        (Get-Content "$Root\Akari.ps1" -Raw) | Should Match "Test-Path -LiteralPath \(Join-Path \`$Root '\.bootstrap'\)"
    }
}
