$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# per-game settings (X5): the pure readers, the games found from fake Steam, Epic, GOG and games.json sources, and the
# three switches on a test key (Get-AkariGameSources mocked, $AkariGamePaths pointed at the test key). No real game,
# launcher or registry value is read or changed.
Describe 'Per-game settings (pure parts)' {
    foreach ($f in 'Log', 'Registry', 'Games') { . "$Core\$f.ps1" }
    . "$Root\UI\GamesPage.ps1"

    It 'reads Valve''s KeyValues: nesting, escapes, comments' {
        $v = Read-AkariVdf @'
"libraryfolders"
{
    // a comment
    "0" { "path"  "C:\\Program Files (x86)\\Steam" "apps" { "730" "123" } }
    "1"
    {
        "path"		"D:\\Games\\Steam"
    }
}
'@
        $v['libraryfolders']['0']['path'] | Should Be 'C:\Program Files (x86)\Steam'
        $v['libraryfolders']['0']['apps']['730'] | Should Be '123'
        $v['libraryfolders']['1']['path'] | Should Be 'D:\Games\Steam'
    }

    It 'guesses the game''s exe: the biggest that isn''t a helper, then the shallowest' {
        Select-AkariGameExe @(
            @{ Path = 'unins000.exe'; Size = 900 }
            @{ Path = 'UnityCrashHandler64.exe'; Size = 800 }
            @{ Path = 'Game.exe'; Size = 500 }
            @{ Path = 'bin\x64\Game-Win64.exe'; Size = 700 }
            @{ Path = 'readme.txt'; Size = 9999 }
        ) | Should Be 'bin\x64\Game-Win64.exe'
        Select-AkariGameExe @(@{ Path = 'b\Same.exe'; Size = 5 }, @{ Path = 'Same.exe'; Size = 5 }) | Should Be 'Same.exe'
        Select-AkariGameExe @(@{ Path = 'vc_redist.x64.exe'; Size = 5 }) | Should Be ''
    }

    It 'turns the fullscreen layer on and off, keeping the others' {
        Set-AkariLayerFlag '' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' $true | Should Be '~ DISABLEDXMAXIMIZEDWINDOWEDMODE'
        Set-AkariLayerFlag '~ RUNASADMIN' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' $true | Should Be '~ RUNASADMIN DISABLEDXMAXIMIZEDWINDOWEDMODE'
        Set-AkariLayerFlag '~ RUNASADMIN DISABLEDXMAXIMIZEDWINDOWEDMODE' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' $false | Should Be '~ RUNASADMIN'
        Set-AkariLayerFlag '~ DISABLEDXMAXIMIZEDWINDOWEDMODE' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' $false | Should Be ''
        Test-AkariLayerFlag '~ RUNASADMIN DISABLEDXMAXIMIZEDWINDOWEDMODE' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' | Should Be $true
        Test-AkariLayerFlag '~ RUNASADMIN' 'DISABLEDXMAXIMIZEDWINDOWEDMODE' | Should Be $false
    }

    It 'filters and counts the list' {
        $g = @([pscustomobject]@{ Name = 'Alpha'; Exe = 'C:\a.exe'; Source = 'Steam' }, [pscustomobject]@{ Name = 'Beta'; Exe = 'C:\b.exe'; Source = 'Epic' })
        @(Get-AkariGameView $g 'epic').Name | Should Be 'Beta'
        Get-AkariGameCountText $g $g | Should Be '2 games found'
        Get-AkariGameCountText $g @($g[0]) | Should Be '1 of 2 games'
    }
}

Describe 'Per-game settings (found and switched)' {
    foreach ($f in 'Log', 'Registry', 'Games') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $AkariTestKey = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $AkariGamePaths = @{ Gpu = "$AkariTestKey\Gpu"; Layers = "$AkariTestKey\Layers"; Ifeo = "$AkariTestKey\Ifeo" }
    $steam = (New-Item 'TestDrive:\Steam\steamapps\common\Alpha\bin' -ItemType Directory -Force).FullName | Split-Path | Split-Path | Split-Path | Split-Path
    [IO.File]::WriteAllText("$steam\steamapps\libraryfolders.vdf", "`"libraryfolders`" { `"0`" { `"path`" `"$($steam -replace '\\', '\\')`" } }")
    [IO.File]::WriteAllText("$steam\steamapps\appmanifest_1.acf", '"AppState" { "appid" "1" "name" "Alpha" "installdir" "Alpha" }')
    [IO.File]::WriteAllBytes("$steam\steamapps\common\Alpha\bin\alpha.exe", [byte[]]::new(64))
    [IO.File]::WriteAllBytes("$steam\steamapps\common\Alpha\unins000.exe", [byte[]]::new(128))
    $epic = (New-Item 'TestDrive:\Epic' -ItemType Directory -Force).FullName
    [IO.File]::WriteAllText("$epic\x.item", (@{ DisplayName = 'Beta'; InstallLocation = 'E:\Beta'; LaunchExecutable = 'Beta.exe' } | ConvertTo-Json))
    $own = "$TestDrive\games.json"
    Mock Get-AkariGameSources { @{ Steam = $steam; Epic = $epic; Gog = "$AkariTestKey\Gog"; Own = $own } }

    try {
        It 'finds Steam, Epic, GOG and added games, one per exe, by name' {
            Set-Reg "$AkariTestKey\Gog\1" 'gameName' 'Gamma' 'String'
            Set-Reg "$AkariTestKey\Gog\1" 'exe' 'G:\Gamma\gamma.exe' 'String'
            Save-AkariOwnGames $own @(@{ Name = 'Delta'; Exe = 'H:\delta.exe' }, @{ Name = 'Again'; Exe = 'E:\Beta\Beta.exe' })
            $g = @(Get-AkariGames)
            ($g | ForEach-Object { "$($_.Name):$($_.Source)" }) -join ',' | Should Be 'Alpha:Steam,Beta:Epic,Delta:Added,Gamma:GOG'
            $g[0].Exe | Should Be "$steam\steamapps\common\Alpha\bin\alpha.exe"
            $g[1].Key | Should Be 'e:\beta\beta.exe'
        }

        It 'turns each switch on and off as one value' {
            $exe = 'C:\Games\Zeta\zeta.exe'
            Set-Reg $AkariGamePaths.Layers $exe '~ RUNASADMIN' 'String'
            foreach ($s in 'Gpu', 'Fso', 'Priority') { Set-AkariGameSetting $exe $s $true }
            $now = Get-AkariGameSettings $exe
            "$($now.Gpu) $($now.Fso) $($now.Priority)" | Should Be 'True True True'
            Get-AkariRegValue $AkariGamePaths.Gpu $exe | Should Be 'GpuPreference=2;'
            Get-AkariRegValue $AkariGamePaths.Layers $exe | Should Be '~ RUNASADMIN DISABLEDXMAXIMIZEDWINDOWEDMODE'
            Get-AkariRegValue "$($AkariGamePaths.Ifeo)\zeta.exe\PerfOptions" 'CpuPriorityClass' | Should Be 3
            foreach ($s in 'Gpu', 'Fso', 'Priority') { Set-AkariGameSetting $exe $s $false }
            Get-AkariRegValue $AkariGamePaths.Gpu $exe | Should Be $null
            Get-AkariRegValue $AkariGamePaths.Layers $exe | Should Be '~ RUNASADMIN'
            Get-AkariRegValue "$($AkariGamePaths.Ifeo)\zeta.exe\PerfOptions" 'CpuPriorityClass' | Should Be $null
        }
    } finally {
        Remove-Item -LiteralPath (Resolve-AkariRegPath $AkariTestKey) -Recurse -Force -ErrorAction SilentlyContinue
    }
}
