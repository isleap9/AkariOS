# Winget: the engine side of a Tweak with a Winget field (an app installed with winget). winget.exe is only ever
# called through Invoke-AkariWinget, and App Installer is only changed through Register- / Install-AkariAppInstaller,
# so tests mock those functions (AGENTS.md rule 12).

# oldest winget Akari trusts (--disable-interactivity, reliable exit codes)
$AkariWingetMin = [version]'1.6.0'
# exit codes that mean the app is there: 0, PACKAGE_ALREADY_INSTALLED, UPDATE_NOT_APPLICABLE
$AkariWingetOk = 0, -1978335135, -1978335189

# winget.exe: on PATH (the user's App Execution Alias), else the newest App Installer package folder
function Get-AkariWingetPath {
    $c = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    $d = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Directory -Filter 'Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\winget.exe" } |
        Sort-Object { try { [version]($_.Name -split '_')[1] } catch { [version]'0.0' } } -Descending | Select-Object -First 1
    if ($d) { return "$($d.FullName)\winget.exe" }
    $null
}

# runs winget.exe; @{ Code; Out }. Throws when winget is not there.
function Invoke-AkariWinget([string[]]$Arguments) {
    $exe = Get-AkariWingetPath
    if (-not $exe) { throw 'winget is not available' }
    $out = & $exe @Arguments 2>&1 | ForEach-Object { "$_" }
    @{ Code = $LASTEXITCODE; Out = @($out) }
}

function Get-AkariWingetVersion {
    try { $r = Invoke-AkariWinget @('--version') } catch { return $null }
    $v = "$(@($r.Out) | Select-Object -First 1)".Trim().TrimStart('v') -replace '[^0-9.].*$', ''
    try { [version]$v } catch { $null }
}

# a working winget, once per Run: registers App Installer for the user, else installs it (and its VCLibs / UI.Xaml
# dependencies) from Microsoft's winget-cli GitHub release. Throws when that fails.
function Install-AkariWingetTool {
    if ($script:AkariWingetReady) { return }
    $v = Get-AkariWingetVersion
    if (-not $v -or $v -lt $AkariWingetMin) {
        Write-Log "winget: $(if ($v) { "version $v is too old" } else { 'not found' }), installing App Installer"
        Register-AkariAppInstaller
        $v = Get-AkariWingetVersion
    }
    if (-not $v -or $v -lt $AkariWingetMin) {
        Install-AkariAppInstaller
        $v = Get-AkariWingetVersion
        if (-not $v -or $v -lt $AkariWingetMin) { throw 'winget could not be installed' }
        Write-Log "winget: version $v installed"
    }
    $script:AkariWingetReady = $true
}

# App Installer is on the PC but not registered for this user yet (a fresh install before the Store updates it)
function Register-AkariAppInstaller {
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop } catch { }
}

# App Installer and its dependencies (VCLibs, UI.Xaml) from Microsoft's winget-cli GitHub release
function Install-AkariAppInstaller {
    $tmp = Join-Path $env:TEMP 'akari-winget'
    New-Item $tmp -ItemType Directory -Force | Out-Null
    $base = 'https://github.com/microsoft/winget-cli/releases/latest/download'
    Invoke-WebRequest "$base/DesktopAppInstaller_Dependencies.zip" -OutFile "$tmp\deps.zip" -UseBasicParsing
    Invoke-WebRequest "$base/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "$tmp\AppInstaller.msixbundle" -UseBasicParsing
    Expand-Archive "$tmp\deps.zip" "$tmp\deps" -Force
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) { 'ARM64' { 'arm64' } 'x86' { 'x86' } default { 'x64' } }
    Get-ChildItem "$tmp\deps" -Recurse -Filter *.appx | Where-Object { $_.FullName -match "\\$arch\\" } |
        ForEach-Object { Add-AppxPackage $_.FullName -ErrorAction SilentlyContinue }
    Add-AppxPackage "$tmp\AppInstaller.msixbundle" -ErrorAction Stop
}

# the Microsoft Store, for 'msstore' installs and its own restore row (the debloat removes it for every user, so its
# files are usually gone). In order, until it is there: registered again from a copy still on the disk; winget from the
# msstore source (product 9WZDNCRFJBMP: Windows' install service downloads it, the Store app isn't needed); Windows'
# own reinstall (wsreset -i), waited for up to 5 minutes. Each step is logged.
$AkariStoreProductId = '9WZDNCRFJBMP'
function Install-AkariMicrosoftStore {
    if (Test-AkariAppxInstalled 'Microsoft.WindowsStore') { return }
    Write-Log 'Microsoft Store: registering it again'
    Get-AkariAppxPackages | Where-Object { $_.Name -like '*WindowsStore*' -and $_.InstallLocation -and (Test-Path -LiteralPath "$($_.InstallLocation)\AppxManifest.xml") } | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
    }
    if (Test-AkariAppxInstalled 'Microsoft.WindowsStore') { return }
    Write-Log 'Microsoft Store: not on the disk any more, downloading it with winget'
    try {
        Install-AkariWingetTool
        $r = Invoke-AkariWinget @('install', '--id', $AkariStoreProductId, '--exact', '--source', 'msstore', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        if ($r.Code -notin $AkariWingetOk) { Write-Log ("Microsoft Store: winget failed (0x{0:X8}): {1}" -f $r.Code, "$(@($r.Out | Where-Object { $_ -match '[A-Za-z]{3}' }) | Select-Object -Last 1)".Trim()) }
    } catch { Write-Log "Microsoft Store: winget failed: $($_.Exception.Message)" }
    if (Test-AkariAppxInstalled 'Microsoft.WindowsStore') { return }
    Write-Log 'Microsoft Store: asking Windows to reinstall it (wsreset -i), this can take a few minutes'
    Start-Process "$env:SystemRoot\System32\wsreset.exe" -ArgumentList '-i' -WindowStyle Hidden
    for ($i = 0; $i -lt 60 -and -not (Test-AkariAppxInstalled 'Microsoft.WindowsStore'); $i++) { Start-Sleep -Seconds 5 }
    if (-not (Test-AkariAppxInstalled 'Microsoft.WindowsStore')) { throw 'the Microsoft Store is still downloading: try again in a few minutes' }
}
# installs one winget package silently; throws with winget's last line when it fails.
# $Source 'msstore': a Microsoft Store product id (the Store is installed first when it is missing)
function Install-AkariWingetPackage([string]$Id, [string]$Source = 'winget') {
    Install-AkariWingetTool
    if ($Source -eq 'msstore') { Install-AkariMicrosoftStore }
    Write-Log "winget: installing $Id"
    $r = Invoke-AkariWinget @('install', '--id', $Id, '--exact', '--source', $Source, '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($r.Code -notin $AkariWingetOk) {
        $last = @($r.Out | Where-Object { $_ -match '[A-Za-z]{3}' }) | Select-Object -Last 1
        throw ("winget could not install {0} (0x{1:X8}): {2}" -f $Id, $r.Code, "$last".Trim())
    }
}

# installed, by winget or not (winget matches what Windows lists under installed apps)
function Test-AkariWingetInstalled([string]$Id, [string]$Source = 'winget') {
    try { $r = Invoke-AkariWinget @('list', '--id', $Id, '--exact', '--source', $Source, '--accept-source-agreements', '--disable-interactivity') }
    catch { return $false }
    ($r.Code -eq 0) -and [bool]($r.Out -match [regex]::Escape($Id))
}
