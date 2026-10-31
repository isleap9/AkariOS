$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'
$Fixtures = Join-Path $PSScriptRoot 'Fixtures'

# Mocks only: no request reaches UUP Dump, GitHub or a file host, no converter runs
function Initialize-DownloadTest {
    $script:AkariIsoMarker = Join-Path $TestDrive 'iso-mount.json'
    $script:AkariUupRetryDelay = 0
    foreach ($f in 'Log', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Iso', 'IsoDownload') { . "$Core\$f.ps1" }
}

Describe 'UUP Dump API' {
    . Initialize-DownloadTest
    Mock Start-Sleep { }

    It 'retries a busy API and gives up with a message, never throwing' {
        $script:n = 0
        Mock Invoke-AkariUupRequest { $script:n++; throw 'The operation has timed out.' }
        $r = Invoke-AkariUupApi 'listid' @{ search = 'x' }
        $r.Ok | Should Be $false
        $r.Message | Should Match 'timed out'
        $script:n | Should Be 3
    }

    It 'passes the API''s own error on' {
        Mock Invoke-AkariUupRequest { [pscustomobject]@{ response = [pscustomobject]@{ error = 'NO_SEARCH_RESULTS' } } }
        (Invoke-AkariUupApi 'listid' @{}).Message | Should Match 'NO_SEARCH_RESULTS'
    }

    It 'picks the newest release build of a version, not a lone update or a preview' {
        Mock Invoke-AkariUupRequest {
            [pscustomobject]@{ response = [pscustomobject]@{ builds = [pscustomobject]@{
                        '0' = [pscustomobject]@{ uuid = 'kb'; build = '26100.9544'; title = 'Critical OOBE Update for Windows 11 - KB5128942 (26100.9544)'; arch = 'amd64' }
                        '1' = [pscustomobject]@{ uuid = 'old'; build = '26100.9711'; title = 'Windows 11, version 24H2 (26100.9711)'; arch = 'amd64' }
                        '2' = [pscustomobject]@{ uuid = 'new'; build = '26100.9725'; title = 'Windows 11, version 24H2 (26100.9725)'; arch = 'amd64' }
                        '3' = [pscustomobject]@{ uuid = 'pre'; build = '26100.9999'; title = 'Windows 11 Insider Preview 26100.9999'; arch = 'amd64' }
                        '4' = [pscustomobject]@{ uuid = 'arm'; build = '26100.9800'; title = 'Windows 11, version 24H2 (26100.9800)'; arch = 'arm64' }
                    } } }
        }
        $r = Get-AkariUupBuild '24H2'
        $r.Ok | Should Be $true
        $r.Build.Id | Should Be 'new'
        Assert-MockCalled Invoke-AkariUupRequest -Times 1 -Exactly -Scope It -ParameterFilter { $Query.search -eq 'windows 11 26100 amd64' }
    }

    It 'knows 23H2 to 26H2 and refuses other versions' {
        @($AkariUupVersions.Keys) -join ',' | Should Be '26H2,25H2,24H2,23H2'
        (Get-AkariUupBuild '21H2').Ok | Should Be $false
    }

    It 'lists the languages by name' {
        Mock Invoke-AkariUupRequest { [pscustomobject]@{ response = [pscustomobject]@{ langFancyNames = [pscustomobject]@{ 'it-it' = 'Italian'; 'en-us' = 'English (United States)' } } } }
        $r = Get-AkariUupLanguages 'id'
        ($r.Items | ForEach-Object { $_.Code }) -join ',' | Should Be 'en-us,it-it'
    }
}

Describe 'UUP Dump editions' {
    . Initialize-DownloadTest

    It 'offers Home, Pro and their N, then the editions made from Pro' {
        $t = Get-AkariUupTargets ([pscustomobject]@{ PROFESSIONALN = 'Windows Pro N'; PROFESSIONAL = 'Windows Pro'; COREN = 'Windows Home N'; CORE = 'Windows Home' })
        ($t | ForEach-Object { $_.Label }) -join ',' | Should Be 'Home,Home N,Pro,Pro N,Enterprise,Education,IoT Enterprise,Pro Education,Pro for Workstations'
        $iot = $t | Where-Object { $_.Label -eq 'IoT Enterprise' }
        $iot.Code | Should Be 'PROFESSIONAL'
        $iot.Virtual | Should Be 'IoTEnterprise'
    }

    It 'offers no virtual edition without Pro, and names other editions after UUP Dump' {
        $t = Get-AkariUupTargets @{ CORE = 'Windows Home'; CORECOUNTRYSPECIFIC = 'Windows Home China' }
        ($t | ForEach-Object { $_.Label }) -join ',' | Should Be 'Home,Home China'
    }

    It 'asks for a virtual edition the way zISO does' {
        $b = Get-AkariUupPackageBody 'Enterprise'
        $b.autodl | Should Be '3'
        $b['virtualEditions[]'] | Should Be 'Enterprise'
        (Get-AkariUupPackageBody '').autodl | Should Be '2'
    }

    It 'sets the converter''s options and leaves the rest of ConvertConfig.ini alone' {
        $ini = @('[convert-UUP]', 'AutoStart    =1', 'AutoExit     =0', 'NetFx3       =0', 'ResetBase    =0', '; StartVirtual=0', 'StartVirtual =0', 'vAutoEditions=', 'SkipISO      =0')
        $out = Set-AkariUupConfig $ini 'IoTEnterprise'
        $out -contains 'AutoExit=1' | Should Be $true
        $out -contains 'NetFx3=1' | Should Be $true
        $out -contains 'StartVirtual=1' | Should Be $true
        $out -contains 'vAutoEditions=IoTEnterprise' | Should Be $true
        $out -contains '; StartVirtual=0' | Should Be $true
        $out -contains 'SkipISO      =0' | Should Be $true
        (Set-AkariUupConfig $ini '') -contains 'StartVirtual =0' | Should Be $true
    }

    It 'names the ISO after version, edition and language' {
        Get-AkariUupIsoName '25H2' 'Pro for Workstations' 'en-us' | Should Be 'Windows11_25H2_Pro-for-Workstations_en-us.iso'
    }
}

Describe 'Save-AkariUupIso' {
    . Initialize-DownloadTest
    $out = Join-Path $TestDrive 'out'
    New-Item $out -ItemType Directory -Force | Out-Null
    Mock Write-Log { }
    Mock Write-ErrLog { }
    Mock Get-AkariDriveInfo { @{ Free = 60GB; Format = 'NTFS' } }
    # the package: a zip with ConvertConfig.ini
    Mock Save-AkariUupPackage {
        $src = Join-Path $TestDrive 'pkg'
        New-Item $src -ItemType Directory -Force | Out-Null
        Set-Content "$src\ConvertConfig.ini" "[convert-UUP]`r`nAutoExit     =0`r`nvAutoEditions="
        Compress-Archive -Path "$src\*" -DestinationPath $OutFile -Force
    }
    $build = @{ Id = 'abc'; Build = '26200.7000' }
    $target = @{ Label = 'IoT Enterprise'; Code = 'PROFESSIONAL'; Virtual = 'IoTEnterprise' }

    It 'builds the ISO with the patched config, moves it next to the others and cleans up' {
        Mock Invoke-AkariUupScript { $script:ini = Get-Content (Join-Path $Dir 'ConvertConfig.ini'); Set-Content (Join-Path $Dir '26200.7000.iso') 'iso'; 0 }
        $r = Save-AkariUupIso '25H2' $build 'en-us' $target $out
        $r.Ok | Should Be $true
        $r.Path | Should Be (Join-Path $out 'Windows11_25H2_IoT-Enterprise_en-us.iso')
        Test-Path $r.Path | Should Be $true
        $script:ini -contains 'vAutoEditions=IoTEnterprise' | Should Be $true
        Test-Path (Join-Path $out 'AkariUup') | Should Be $false
        Test-Path (Join-Path $out 'AkariUup.zip') | Should Be $false
        Assert-MockCalled Save-AkariUupPackage -Times 1 -Exactly -Scope It -ParameterFilter { $Url -eq 'https://uupdump.net/get.php?id=abc&pack=en-us&edition=professional' -and $Body.autodl -eq '3' }
    }

    It 'reports the converter failing, without throwing' {
        Mock Invoke-AkariUupScript { 1 }
        $r = Save-AkariUupIso '25H2' $build 'en-us' $target $out
        $r.Ok | Should Be $false
        $r.Message | Should Match 'exit code 1'
        Test-Path (Join-Path $out 'AkariUup') | Should Be $false
    }

    It 'refuses a drive that is too small before downloading' {
        Mock Get-AkariDriveInfo { @{ Free = 5GB; Format = 'NTFS' } }
        (Save-AkariUupIso '25H2' $build 'en-us' $target $out).Message | Should Match '25 GB'
        Assert-MockCalled Save-AkariUupPackage -Times 0 -Exactly -Scope It
    }
}

Describe 'Massgrave catalogue' {
    . Initialize-DownloadTest
    $md = Get-Content (Join-Path $Fixtures 'Massgrave\sample.md') -Raw

    It 'reads the Windows 11 x64 ISOs with their product, not arm64 or Windows 10' {
        $i = Read-AkariMassgrave $md
        ($i | ForEach-Object { $_.File.Substring(0, 5) + ':' + $_.Product }) -join '|' |
            Should Be 'en-us:Windows 11 Consumer 26H2|de-de:Windows 11 Consumer 26H2|en-us:Windows 11 IoT Enterprise 26H2|en-us:Windows 11 IoT Enterprise LTSC 2024'
        $i[0].Language | Should Be 'English'
        $i[0].Url | Should Be 'https://zerofs.link/f/aaa/'
    }

    It 'reads both pages, and says so when it can''t' {
        Mock Invoke-AkariWebText { $md }
        $r = Get-AkariMassgraveCatalogue
        $r.Ok | Should Be $true
        $r.Items.Count | Should Be 8
        Mock Invoke-AkariWebText { throw 'No such host is known.' }
        $r = Get-AkariMassgraveCatalogue
        $r.Ok | Should Be $false
        $r.Message | Should Match 'No such host'
    }

    It 'says so when the pages list nothing (a new layout)' {
        Mock Invoke-AkariWebText { '# nothing here' }
        (Get-AkariMassgraveCatalogue).Message | Should Match 'layout'
    }

    It 'finds the downloaded file, or the copy the browser renamed' {
        $dl = Join-Path $TestDrive 'Downloads'
        New-Item $dl -ItemType Directory -Force | Out-Null
        $f = 'en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814.iso'
        Find-AkariDownloadedIso $f $dl | Should BeNullOrEmpty
        Set-Content "$dl\$f.crdownload" 'x'
        Find-AkariDownloadedIso $f $dl | Should BeNullOrEmpty
        Set-Content "$dl\en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814 (1).iso" 'x'
        Find-AkariDownloadedIso $f $dl | Should Be "$dl\en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814 (1).iso"
    }
}
