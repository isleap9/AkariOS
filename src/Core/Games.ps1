# Per-game settings (plan docs/plans/2026-11-26-new-features.md, X5; the list under Optimize > Gaming,
# UI\GamesPage.ps1): the games on this PC (Steam, Epic, GOG, and ones added by hand in games.json), each with three
# switches, every one a single value that Off removes (Windows' default is no value):
# - High-performance GPU: HKCU DirectX\UserGpuPreferences, <exe path> = 'GpuPreference=2;' (Settings > Graphics' own)
# - Fullscreen optimizations off: HKCU AppCompatFlags\Layers, <exe path> gets DISABLEDXMAXIMIZEDWINDOWEDMODE (other
#   layers on the value kept)
# - High CPU priority: HKLM Image File Execution Options\<exe name>\PerfOptions, CpuPriorityClass = 3 (per exe name)
# The native app's AkariOS.Core/Machine/Games.cs does the same; GamesTests compares the pure parts.

$AkariGamePaths = @{
    Gpu      = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    Layers   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    Ifeo     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
}
$AkariGameGpuValue = 'GpuPreference=2;'
$AkariGameFsoFlag = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'
$AkariGameSettings = 'Gpu', 'Fso', 'Priority'
# exes in a game folder that aren't the game (the Steam guess skips them)
$AkariGameExeSkip = 'unins*', '*crash*', '*setup*', '*install*', '*redist*', 'vc_*', 'dxsetup*', '*helper*', '*report*',
    '*updater*', '*update.exe', '*service*', 'easyanticheat*', 'beservice*', 'battleye*', '*launcherpatcher*', 'dotnet*', 'ue4prereq*', 'cefsharp*'

# (pure) Valve's KeyValues text (libraryfolders.vdf, appmanifest_*.acf) as nested hashtables, keys as written
function Read-AkariVdf([string]$Text) {
    $root = [ordered]@{}
    $stack = [Collections.Generic.Stack[object]]::new()
    $cur = $root
    $key = $null
    $i = 0
    $n = $Text.Length
    while ($i -lt $n) {
        $c = $Text[$i]
        if ($c -eq '"') {
            $sb = [Text.StringBuilder]::new()
            $i++
            while ($i -lt $n -and $Text[$i] -ne '"') {
                if ($Text[$i] -eq '\' -and $i + 1 -lt $n) { $i++; $e = $Text[$i]; [void]$sb.Append($(if ($e -eq 'n') { "`n" } elseif ($e -eq 't') { "`t" } else { $e })) }
                else { [void]$sb.Append($Text[$i]) }
                $i++
            }
            $i++
            $s = $sb.ToString()
            if ($null -eq $key) { $key = $s } else { $cur[$key] = $s; $key = $null }
        } elseif ($c -eq '{') {
            $child = [ordered]@{}
            if ($null -ne $key) { $cur[$key] = $child }
            $stack.Push($cur); $cur = $child; $key = $null; $i++
        } elseif ($c -eq '}') {
            if ($stack.Count) { $cur = $stack.Pop() }
            $key = $null; $i++
        } elseif ($c -eq '/' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '/') {
            while ($i -lt $n -and $Text[$i] -ne "`n") { $i++ }
        } else { $i++ }
    }
    $root
}

# (pure) the game's exe among a folder's: @(@{ Path (relative); Size }) -> the relative path, '' when none. Skips
# $AkariGameExeSkip; the biggest wins, then the shallowest, then by name.
function Select-AkariGameExe($Files) {
    $ok = @(foreach ($f in @($Files)) {
        if (-not $f -or "$($f.Path)" -notlike '*.exe') { continue }
        $name = [IO.Path]::GetFileName("$($f.Path)")
        $skip = $false
        foreach ($p in $AkariGameExeSkip) { if ($name -like $p) { $skip = $true; break } }
        if (-not $skip) { $f }
    })
    if (-not $ok.Count) { return '' }
    $best = $null
    foreach ($f in $ok) {
        if (-not $best) { $best = $f; continue }
        $d = ([string]$f.Path).Split('\').Count; $bd = ([string]$best.Path).Split('\').Count
        if ([long]$f.Size -gt [long]$best.Size -or ([long]$f.Size -eq [long]$best.Size -and ($d -lt $bd -or ($d -eq $bd -and [string]::Compare([string]$f.Path, [string]$best.Path, [StringComparison]::OrdinalIgnoreCase) -lt 0)))) { $best = $f }
    }
    [string]$best.Path
}

# (pure) the Layers value with $Flag on or off; other layers kept, '~' first when there are any; '' = none left
function Set-AkariLayerFlag([string]$Data, [string]$Flag, [bool]$On) {
    $parts = @("$Data".Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { $_ -ne '~' -and $_ -ne $Flag })
    if ($On) { $parts += $Flag }
    if (-not $parts.Count) { return '' }
    '~ ' + ($parts -join ' ')
}

# (pure) whether the Layers value has $Flag
function Test-AkariLayerFlag([string]$Data, [string]$Flag) { @("$Data".Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) -contains $Flag }

# an exe's files under a folder, up to three folders down: @{ Path (relative); Size }
function Get-AkariFolderExes([string]$Folder) {
    if (-not $Folder -or -not [IO.Directory]::Exists($Folder)) { return @() }
    $out = [Collections.Generic.List[object]]::new()
    $walk = { param($dir, $depth)
        try { foreach ($f in [IO.Directory]::GetFiles($dir, '*.exe')) { $out.Add(@{ Path = $f.Substring($Folder.TrimEnd('\').Length + 1); Size = ([IO.FileInfo]::new($f)).Length }) } } catch { }
        if ($depth -lt 3) { try { foreach ($d in [IO.Directory]::GetDirectories($dir)) { & $walk $d ($depth + 1) } } catch { } }
    }
    & $walk $Folder 0
    @($out)
}

# where the launchers keep their lists (tests mock this): Steam's folder, Epic's manifests, GOG's key, games.json
function Get-AkariGameSources {
    $steam = Get-AkariRegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
    @{
        Steam = $(if ($steam) { "$steam" -replace '/', '\' } else { '' })
        Epic  = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        Gog   = 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games'
        Own   = $(if ($AkariGamesPath) { $AkariGamesPath } else { Join-Path (Split-Path $AkariLogFile) 'games.json' })
    }
}

# the games added by hand: @(@{ Name; Exe })
function Get-AkariOwnGames([string]$Path) {
    if (-not $Path -or -not [IO.File]::Exists($Path)) { return @() }
    try { @([IO.File]::ReadAllText($Path) | ConvertFrom-Json | ForEach-Object { $_ } | Where-Object { $_.Exe } | ForEach-Object { @{ Name = [string]$_.Name; Exe = [string]$_.Exe } }) } catch { @() }
}

function Save-AkariOwnGames([string]$Path, $Games) {
    New-Item (Split-Path $Path) -ItemType Directory -Force | Out-Null
    $list = @(foreach ($g in @($Games)) { [ordered]@{ Name = $g.Name; Exe = $g.Exe } })
    [IO.File]::WriteAllText($Path, (ConvertTo-Json @($list) -Depth 3), [Text.UTF8Encoding]::new($false))
}

# every game found: @{ Key (the exe path, lower case); Name; Exe; Source Steam | Epic | GOG | Added }, by name; one per exe
function Get-AkariGames {
    $src = Get-AkariGameSources
    $all = [Collections.Generic.List[object]]::new()
    if ($src.Steam) {
        $libs = @($src.Steam)
        $lf = Join-Path $src.Steam 'steamapps\libraryfolders.vdf'
        if ([IO.File]::Exists($lf)) {
            $v = Read-AkariVdf ([IO.File]::ReadAllText($lf))
            $top = $v['libraryfolders']
            if ($top) { foreach ($k in @($top.Keys)) { if ($top[$k] -is [Collections.IDictionary] -and $top[$k]['path']) { $libs += $top[$k]['path'] } } }
        }
        foreach ($lib in @($libs | Select-Object -Unique)) {
            $apps = Join-Path $lib 'steamapps'
            if (-not [IO.Directory]::Exists($apps)) { continue }
            foreach ($m in [IO.Directory]::GetFiles($apps, 'appmanifest_*.acf')) {
                $st = (Read-AkariVdf ([IO.File]::ReadAllText($m)))['AppState']
                if (-not $st -or -not $st['installdir']) { continue }
                $dir = Join-Path $apps "common\$($st['installdir'])"
                $exe = Select-AkariGameExe (Get-AkariFolderExes $dir)
                if ($exe) { $all.Add(@{ Name = [string]$st['name']; Exe = (Join-Path $dir $exe); Source = 'Steam' }) }
            }
        }
    }
    if ($src.Epic -and [IO.Directory]::Exists($src.Epic)) {
        foreach ($m in [IO.Directory]::GetFiles($src.Epic, '*.item')) {
            try { $j = [IO.File]::ReadAllText($m) | ConvertFrom-Json } catch { continue }
            if ($j.InstallLocation -and $j.LaunchExecutable) { $all.Add(@{ Name = [string]$j.DisplayName; Exe = (Join-Path $j.InstallLocation $j.LaunchExecutable); Source = 'Epic' }) }
        }
    }
    if ($src.Gog) {
        $gk = Get-Item -LiteralPath (Resolve-AkariRegPath $src.Gog) -ErrorAction SilentlyContinue
        if ($gk) {
            foreach ($id in $gk.GetSubKeyNames()) {
                $p = "$($src.Gog)\$id"
                $exe = Get-AkariRegValue $p 'exe'
                if ($exe) { $all.Add(@{ Name = [string](Get-AkariRegValue $p 'gameName'); Exe = [string]$exe; Source = 'GOG' }) }
            }
        }
    }
    foreach ($g in @(Get-AkariOwnGames $src.Own)) { $all.Add(@{ Name = $g.Name; Exe = $g.Exe; Source = 'Added' }) }
    $seen = @{}
    $out = foreach ($g in $all) {
        $key = $g.Exe.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $s = Get-AkariGameSettings $g.Exe
        [pscustomobject]@{ Key = $key; Name = $(if ($g.Name) { $g.Name } else { [IO.Path]::GetFileNameWithoutExtension($g.Exe) }); Exe = $g.Exe; Source = $g.Source
            Gpu = $s.Gpu; Fso = $s.Fso; Priority = $s.Priority }
    }
    @($out | Sort-Object Name, Exe)
}

# the three switches as they are for an exe
function Get-AkariGameSettings([string]$Exe) {
    $name = [IO.Path]::GetFileName($Exe)
    @{
        Gpu      = ("$(Get-AkariRegValue $AkariGamePaths.Gpu $Exe)" -match 'GpuPreference=2;')
        Fso      = (Test-AkariLayerFlag "$(Get-AkariRegValue $AkariGamePaths.Layers $Exe)" $AkariGameFsoFlag)
        Priority = ((Get-AkariRegValue "$($AkariGamePaths.Ifeo)\$name\PerfOptions" 'CpuPriorityClass') -eq 3)
    }
}

# one switch on or off ($Setting: Gpu, Fso, Priority); throws when it stays as it was
function Set-AkariGameSetting([string]$Exe, [string]$Setting, [bool]$On) {
    switch ($Setting) {
        'Gpu' {
            if ($On) { Set-Reg $AkariGamePaths.Gpu $Exe $AkariGameGpuValue 'String' } else { Remove-Reg $AkariGamePaths.Gpu $Exe }
        }
        'Fso' {
            $d = Set-AkariLayerFlag "$(Get-AkariRegValue $AkariGamePaths.Layers $Exe)" $AkariGameFsoFlag $On
            if ($d) { Set-Reg $AkariGamePaths.Layers $Exe $d 'String' } else { Remove-Reg $AkariGamePaths.Layers $Exe }
        }
        'Priority' {
            $p = "$($AkariGamePaths.Ifeo)\$([IO.Path]::GetFileName($Exe))\PerfOptions"
            if ($On) { Set-Reg $p 'CpuPriorityClass' 3 'DWord' } else { Remove-Reg $p 'CpuPriorityClass' }
        }
        default { throw "No game setting '$Setting'" }
    }
    if ((Get-AkariGameSettings $Exe)[$Setting] -ne $On) { throw "Windows keeps it $(if ($On) { 'off' } else { 'on' })" }
}
