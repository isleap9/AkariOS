$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# startup apps (X2): the pure parts, then the entries read, switched and removed under a test key and TestDrive:
# (Get-AkariStartupLocations mocked: nothing real is read or changed)
Describe 'Startup apps (pure parts)' {
    foreach ($f in 'Log', 'Registry', 'Startup') { . "$Core\$f.ps1" }
    . "$Root\UI\StartupPage.ps1"

    It 'reads StartupApproved like Task Manager: missing or an even first byte = on' {
        Test-AkariStartupApproved $null | Should Be $true
        Test-AkariStartupApproved ([byte[]]@()) | Should Be $true
        Test-AkariStartupApproved ([byte[]](2, 0, 0, 0)) | Should Be $true
        Test-AkariStartupApproved ([byte[]](6, 0, 0, 0)) | Should Be $true
        Test-AkariStartupApproved ([byte[]](3, 0, 0, 0)) | Should Be $false
        Test-AkariStartupApproved ([byte[]](7, 0, 0, 0)) | Should Be $false
    }

    It 'writes Task Manager''s values: on = 02 and zeros, off = 03 and the time' {
        $when = [datetime]::new(2026, 11, 26, 10, 0, 0, [DateTimeKind]::Utc)
        (ConvertTo-AkariStartupApproved $true $when) -join ',' | Should Be '2,0,0,0,0,0,0,0,0,0,0,0'
        $off = ConvertTo-AkariStartupApproved $false $when
        $off.Count | Should Be 12
        $off[0] | Should Be 3
        [datetime]::FromFileTimeUtc([BitConverter]::ToInt64($off, 4)) | Should Be $when
    }

    It 'finds the program a command starts' {
        Get-AkariStartupProgram '"C:\Program Files\Steam\steam.exe" -silent' | Should Be 'C:\Program Files\Steam\steam.exe'
        Get-AkariStartupProgram 'C:\Program Files\App\app.EXE /background' | Should Be 'C:\Program Files\App\app.EXE'
        Get-AkariStartupProgram 'rundll32 shell32.dll,Control' | Should Be 'rundll32'
        Get-AkariStartupProgram '"C:\unclosed' | Should Be 'C:\unclosed'
        Get-AkariStartupProgram '   ' | Should Be ''
    }

    $it = { param($n, $on, $scope, $cmd = 'x.exe', $pub = '', $loc = 'L') [pscustomobject]@{ Key = "$loc|$n"; Name = $n; Enabled = $on; Scope = $scope; Command = $cmd; Publisher = $pub; Location = $loc } }
    $list = @(
        & $it 'Steam' $true 'User' 'steam.exe' 'Valve'
        & $it 'Discord' $false 'User'
        & $it 'SecurityHealth' $true 'Machine' 'SecurityHealthSystray.exe' 'Microsoft Corporation'
        & $it 'Discord' $true 'Machine' 'x.exe' '' 'A'
    )

    It 'filters on, off, this user, all users and by search, by name then location' {
        (Get-AkariStartupView $list 'All' '' | ForEach-Object { $_.Key }) -join ',' | Should Be 'A|Discord,L|Discord,L|SecurityHealth,L|Steam'
        (Get-AkariStartupView $list 'Off' '' | ForEach-Object { $_.Key }) -join ',' | Should Be 'L|Discord'
        (Get-AkariStartupView $list 'On' '' | ForEach-Object { $_.Name }) -join ',' | Should Be 'Discord,SecurityHealth,Steam'
        (Get-AkariStartupView $list 'User' '' | ForEach-Object { $_.Name }) -join ',' | Should Be 'Discord,Steam'
        (Get-AkariStartupView $list 'Machine' '' | ForEach-Object { $_.Name }) -join ',' | Should Be 'Discord,SecurityHealth'
        (Get-AkariStartupView $list 'All' 'valve' | ForEach-Object { $_.Name }) -join ',' | Should Be 'Steam'
        @(Get-AkariStartupView $list 'All' 'zzz').Count | Should Be 0
    }

    It 'counts what starts' {
        Get-AkariStartupCountText $list $list | Should Be '4 startup apps, 3 on'
        Get-AkariStartupCountText $list @($list[0]) | Should Be '1 of 4 startup apps, 3 on'
        Get-AkariStartupCountText @($list[1]) @($list[1]) | Should Be '1 startup app, 0 on'
    }
}

Describe 'Startup apps (read and change)' {
    foreach ($f in 'Log', 'Registry', 'Startup') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $AkariTestKey = "HKCU:\Software\AkariTest\$([guid]::NewGuid().ToString('N'))"
    $folder = (New-Item 'TestDrive:\Startup' -ItemType Directory -Force).FullName
    Mock Get-AkariStartupLocations {
        @(
            @{ Location = 'Registry, this user'; Scope = 'User'; Kind = 'Registry'; Path = "$AkariTestKey\Run"; Approved = "$AkariTestKey\Approved\Run" }
            @{ Location = 'Registry, missing'; Scope = 'Machine'; Kind = 'Registry'; Path = "$AkariTestKey\Missing"; Approved = "$AkariTestKey\Approved\Missing" }
            @{ Location = 'Startup folder, this user'; Scope = 'User'; Kind = 'Folder'; Path = $folder; Approved = "$AkariTestKey\Approved\StartupFolder" }
        )
    }

    BeforeEach {
        Set-Reg "$AkariTestKey\Run" 'Tool' '"C:\NoSuch\tool.exe" -min' 'String'
        Set-Reg "$AkariTestKey\Approved\Run" 'Tool' ([byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) 'Binary'
        Set-Content (Join-Path $folder 'Chat.lnk') 'x'
        Set-Content (Join-Path $folder 'desktop.ini') 'x'
    }
    AfterEach { Remove-Item -LiteralPath (Resolve-AkariRegPath $AkariTestKey) -Recurse -Force -ErrorAction SilentlyContinue }

    It 'reads the Run values and the folder''s files (not desktop.ini) with their state' {
        $items = @(Get-AkariStartupItems)
        ($items | ForEach-Object { "$($_.Key)=$($_.Enabled):$($_.Scope):$($_.Kind)" }) -join ',' |
            Should Be 'Registry, this user|Tool=False:User:Registry,Startup folder, this user|Chat.lnk=True:User:Folder'
        $items[0].Command | Should Be '"C:\NoSuch\tool.exe" -min'
        $items[0].Publisher | Should Be ''
        $items[1].File | Should Be (Join-Path $folder 'Chat.lnk')
    }

    It 'turns an entry on and off through its StartupApproved value' {
        $tool = @(Get-AkariStartupItems)[0]
        Set-AkariStartupEnabled $tool $true
        (Get-AkariRegValue "$AkariTestKey\Approved\Run" 'Tool') -join ',' | Should Be '2,0,0,0,0,0,0,0,0,0,0,0'
        $chat = @(Get-AkariStartupItems)[1]
        Set-AkariStartupEnabled $chat $false
        @(Get-AkariStartupItems)[1].Enabled | Should Be $false
        # the entry itself is left as it was
        Get-AkariRegValue "$AkariTestKey\Run" 'Tool' | Should Be '"C:\NoSuch\tool.exe" -min'
    }

    It 'removes a Run value or a folder file, and its StartupApproved value' {
        $items = @(Get-AkariStartupItems)
        Remove-AkariStartupItem $items[0]
        Remove-AkariStartupItem $items[1]
        Get-AkariRegValue "$AkariTestKey\Run" 'Tool' | Should Be $null
        Get-AkariRegValue "$AkariTestKey\Approved\Run" 'Tool' | Should Be $null
        Test-Path (Join-Path $folder 'Chat.lnk') | Should Be $false
        @(Get-AkariStartupItems).Count | Should Be 0
    }
}
