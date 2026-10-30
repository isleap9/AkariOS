# AppSetup: helpers for app installs and removals (Tweaks\Apps): downloads, autostart, background updaters, shortcuts,
# MSI uninstalls and self-uninstalling Windows tools. No app-specific logic here. HKCU and user folders go to the real
# user (rule 6).

# files not on winget still come from the AkariOS-Files release (plan §11 step 6 moves them to this repo's Releases)
$AkariFilesUrl = 'https://github.com/isleap9/AkariOS-Files/releases/download/Files'

# downloads $Name from AkariOS-Files to $OutFile (its folder is created); returns $OutFile
function Save-AkariFile([string]$Name, [string]$OutFile) {
    New-Item (Split-Path $OutFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Invoke-WebRequest "$AkariFilesUrl/$Name" -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    $OutFile
}

# removes autostart Run values whose name matches one of $Names (wildcards allowed): the real user's, and the
# machine's 64- and 32-bit ones ($Keys: for tests)
function Remove-AkariStartup([string[]]$Names, [string[]]$Keys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')) {
    foreach ($k in $Keys) {
        $key = Get-Item (Resolve-AkariRegPath $k) -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($v in $key.GetValueNames()) {
            if (@($Names | Where-Object { $v -like $_ }).Count) { Remove-Reg $k $v }
        }
    }
}

# sc.exe delete, behind a function (rule 12)
function Remove-AkariService([string]$Name) { & sc.exe delete $Name 2>&1 | Out-Null }

# an app's background updaters: services and scheduled tasks named like *$Name*, and Active Setup entries (they
# re-run setup at every sign-in) whose title is like *$ActiveSetup*
function Remove-AkariUpdaters([string]$Name, [string]$ActiveSetup = $Name) {
    foreach ($s in @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$Name*" })) {
        Stop-Service $s.Name -Force -ErrorAction SilentlyContinue
        Remove-AkariService $s.Name
    }
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*$Name*" } |
        Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    Get-ChildItem 'HKLM:\Software\Microsoft\Active Setup\Installed Components' -ErrorAction SilentlyContinue |
        Where-Object { "$((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).'(default)')" -like "*$ActiveSetup*" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# a Start-menu shortcut for every user (for apps that are only an .exe in a folder)
function New-AkariShortcut([string]$Name, [string]$Target) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$Name.lnk")
    $s.TargetPath = $Target
    $s.WorkingDirectory = Split-Path $Target
    $s.Save()
}

# MSI products whose display name is like $Name (both registry views): @{ Name; Code }
function Get-AkariMsi([string]$Name) {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Name } |
            ForEach-Object { [pscustomobject]@{ Name = $_.DisplayName; Code = $_.PSChildName } }
    }
}

# uninstalls every MSI product like $Name, silently, no restart (msiexec behind a function, rule 12)
function Uninstall-AkariMsi([string]$Name) {
    foreach ($p in @(Get-AkariMsi $Name)) {
        Write-Log "Uninstalling: $($p.Name)"
        Start-Process 'msiexec.exe' -ArgumentList "/x $($p.Code) /qn /norestart" -Wait -NoNewWindow
    }
}

# a Windows tool that uninstalls itself with /Uninstall (Remote Desktop Connection, Windows 10's Snipping Tool) and
# then shows a window: started, and that window closed once it appears (10 s at most)
function Invoke-AkariSelfUninstall([string]$Exe, [string]$Process) {
    if (-not (Test-Path $Exe)) { return }
    Start-Process $Exe -ArgumentList '/Uninstall' -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 100; $i++) {
        Start-Sleep -Milliseconds 100
        $p = Get-Process -Name $Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
        if ($p) { break }
    }
    Stop-Process -Name $Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# the .exe of a portable winget package (winget unpacks it under WinGet\Packages\<id>_<source>, no Start-menu entry)
function Get-AkariWingetExe([string]$Id, [string]$Filter) {
    foreach ($root in "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages") {
        $d = Get-ChildItem $root -Directory -Filter "$($Id)_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($d) {
            $f = Get-ChildItem $d.FullName -Recurse -Filter $Filter -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { return $f.FullName }
        }
    }
    $null
}

# where a program is: the portable winget copy of $Id, else the first $Exe (wildcards allowed) at most two folders
# down in Program Files ($Roots: for tests); $null when it is not there
function Find-AkariProgram([string]$Id, [string]$Exe, [string[]]$Roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    $p = Get-AkariWingetExe $Id $Exe
    if ($p) { return $p }
    foreach ($root in @($Roots | Where-Object { $_ })) {
        $f = Get-ChildItem -LiteralPath $root -Recurse -Depth 2 -Filter $Exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    $null
}

# opens a tool (a Tools check): installs winget package $Id first when its program $Exe is not on the PC
function Open-AkariWingetTool([string]$Id, [string]$Exe) {
    $path = Find-AkariProgram $Id $Exe
    if (-not $path) {
        Install-AkariWingetPackage $Id
        $path = Find-AkariProgram $Id $Exe
    }
    if (-not $path) { throw "$Id is installed, but $Exe was not found" }
    Start-Process -FilePath $path
}

# reg.exe, for what PowerShell can't do (load / unload a hive, import a .reg file with an app's own value types);
# returns the exit code. Tests mock this.
# An advanced function ([Parameter]) takes the Runner's -ErrorAction Stop, and in 5.1 that turns reg.exe's stderr
# (it prints "The operation completed successfully." there) into a thrown error: Continue here.
function Invoke-AkariRegExe {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\reg.exe" @Arguments 2>&1 | Out-Null
    $LASTEXITCODE
}

# writes a Store app's own settings (the real user's Packages\<family>\Settings\settings.dat): the hive is loaded at
# HKLM\AkariAppHive, $RegText (a .reg file whose keys start [HKEY_LOCAL_MACHINE\AkariAppHive) is imported, the hive
# unloaded. The app must not be running. $false when the app has no settings yet or the hive would not load.
function Import-AkariAppSettings([string]$Family, [string]$RegText) {
    $dat = Join-Path (Get-AkariUserFolder 'Local AppData') "Packages\$Family\Settings\settings.dat"
    if (-not (Test-Path -LiteralPath $dat)) { return $false }
    $file = Join-Path $env:TEMP "akari-$Family.reg"
    Set-Content -LiteralPath $file -Value $RegText -Encoding Unicode
    if ((Invoke-AkariRegExe load 'HKLM\AkariAppHive' $dat) -ne 0) { return $false }
    try { [void](Invoke-AkariRegExe import $file) }
    finally { [gc]::Collect(); Start-Sleep -Seconds 1; [void](Invoke-AkariRegExe unload 'HKLM\AkariAppHive') }
    Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue
    $true
}

# reads a Store app's own settings without touching them: a copy of the real user's settings.dat is loaded at
# HKLM\AkariAppRead, exported with reg.exe (it writes the app's value types as hex(...), which .NET can't read), unloaded.
# 'Key\Name' -> [byte[]]; @{} when the app has no settings yet; $null when they can't be read (the app holds the file).
function Read-AkariAppSettings([string]$Family) {
    $dat = Join-Path (Get-AkariUserFolder 'Local AppData') "Packages\$Family\Settings\settings.dat"
    if (-not (Test-Path -LiteralPath $dat)) { return @{} }
    $dir = Join-Path $env:TEMP "akari-read-$PID"
    try {
        New-Item $dir -ItemType Directory -Force | Out-Null
        try { Copy-Item -LiteralPath $dat -Destination "$dir\settings.dat" -ErrorAction Stop } catch { return $null }
        foreach ($log in 'LOG1', 'LOG2') { Copy-Item -LiteralPath "$dat.$log" -Destination "$dir\settings.dat.$log" -ErrorAction SilentlyContinue }
        if ((Invoke-AkariRegExe load 'HKLM\AkariAppRead' "$dir\settings.dat") -ne 0) { return $null }
        try { $code = Invoke-AkariRegExe export 'HKLM\AkariAppRead' "$dir\settings.reg" /y }
        finally { [void](Invoke-AkariRegExe unload 'HKLM\AkariAppRead') }
        if ($code -ne 0 -or -not (Test-Path -LiteralPath "$dir\settings.reg")) { return $null }
        ConvertFrom-AkariRegExport (Get-Content -LiteralPath "$dir\settings.reg" -Raw) 'HKEY_LOCAL_MACHINE\AkariAppRead'
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

# the hex values of .reg text (reg export) under the key $Root: 'Key\Name' (relative to $Root) -> [byte[]]. Pure.
function ConvertFrom-AkariRegExport([string]$Text, [string]$Root) {
    $values = @{}
    $key = $null
    foreach ($line in ($Text -replace '\\\r?\n\s*', '') -split '\r?\n') {
        if ($line -match '^\[(.*)\]\s*$') {
            $k = $Matches[1]
            $key = if ($k -eq $Root) { '' } elseif ($k.StartsWith("$Root\", 'OrdinalIgnoreCase')) { $k.Substring($Root.Length + 1) } else { $null }
            continue
        }
        if ($null -eq $key -or $line -notmatch '^"((?:[^"\\]|\\.)*)"=hex(?:\([0-9a-fA-F]+\))?:([0-9a-fA-F,]*)\s*$') { continue }
        $name = $Matches[1] -replace '\\(.)', '$1'
        $hex = $Matches[2]
        $bytes = ConvertFrom-AkariHex $hex
        $values[$(if ($key) { "$key\$name" } else { $name })] = $bytes
    }
    $values
}

# State of a Store app's settings from the first byte of each value. $Rows: @{ Name = 'Key\Name'; Value; Default }.
# Optimized when every value is Value; Default when every value is Default or unset (no settings yet = Default);
# else Custom. Unknown when they can't be read.
function Get-AkariAppSettingState([string]$Family, $Rows) {
    $v = Read-AkariAppSettings $Family
    if ($null -eq $v) { return 'Unknown' }
    $opt = $true; $def = $true
    foreach ($r in $Rows) {
        $b = $v[$r.Name]
        $first = if ($b -and $b.Count) { [int]$b[0] } else { $null }
        if ($first -ne $r.Value) { $opt = $false }
        if ($null -ne $first -and $first -ne $r.Default) { $def = $false }
    }
    if ($opt) { 'Optimized' } elseif ($def) { 'Default' } else { 'Custom' }
}

# imports .reg text with reg.exe; its HKEY_CURRENT_USER keys go to the real user (rule 6). Returns reg.exe's exit code.
function Import-AkariRegText([string]$Text) {
    $Text = $Text -replace '\[(-?)HKEY_CURRENT_USER\\', "[`$1HKEY_USERS\$(Get-AkariUserSid)\"
    $file = Join-Path $env:TEMP "akari-import-$PID.reg"
    Set-Content -LiteralPath $file -Value $Text -Encoding Unicode
    try { Invoke-AkariRegExe import $file } finally { Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue }
}
