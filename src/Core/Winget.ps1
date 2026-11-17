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
function Install-AkariWingetTool([switch]$Force) {
    # -Force (tools-fix-winget): App Installer installed again from winget-cli's latest release, whatever is there
    if ($Force) {
        Write-Log 'winget: installing App Installer again'
        Install-AkariAppInstaller
        $v = Get-AkariWingetVersion
        if (-not $v -or $v -lt $AkariWingetMin) { throw 'winget could not be installed' }
        Write-Log "winget: version $v installed"
        $script:AkariWingetReady = $true
        return
    }
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

# ---- uninstall, update all and the installed list (after Chris Titus Tech's winutil, MIT: Install-WinUtilProgramWinget,
# Invoke-WinUtilCurrentSystem)

# done, and Windows must restart to finish: Windows Installer's 3010 / 1641 and winget's own two
$AkariWingetRestart = 3010, 1641, -1978334967, -1978334965
# NO_APPLICATIONS_FOUND: nothing installed matches the id
$AkariWingetMissing = -1978335212
# ADMIN_CONTEXT_ACTION_PROHIBITED: installed for one user; winget run as administrator won't touch it
$AkariWingetUserOnly = -1978335107

# "(0x8A150014): winget's last line with words in it" (progress bars and spinners left out)
function Get-AkariWingetFailure($Result) {
    $last = @($Result.Out | Where-Object { $_ -match '[A-Za-z]{3}' }) | Select-Object -Last 1
    "(0x{0:X8}): {1}" -f $Result.Code, "$last".Trim()
}

# uninstalls one winget package silently: 'Uninstalled', 'Restart' (done, restart to finish), 'Missing' (not
# installed) or 'UserOnly' (a per-user install winget won't touch as administrator); throws when it fails
function Uninstall-AkariWingetPackage([string]$Id, [string]$Source = 'winget') {
    Install-AkariWingetTool
    Write-Log "winget: uninstalling $Id"
    $r = Invoke-AkariWinget @('uninstall', '--id', $Id, '--exact', '--source', $Source, '--silent', '--accept-source-agreements', '--disable-interactivity')
    if ($r.Code -eq 0) { return 'Uninstalled' }
    if ($r.Code -in $AkariWingetRestart) { return 'Restart' }
    if ($r.Code -eq $AkariWingetMissing) { return 'Missing' }
    if ($r.Code -eq $AkariWingetUserOnly) { return 'UserOnly' }
    throw "winget could not uninstall $Id $(Get-AkariWingetFailure $r)"
}

# updates every app winget can (every source; pinned ones are skipped by winget), its lines logged: 'Updated',
# 'UpToDate' or 'Restart'; throws when winget reports a failure. One call: winget's table can't be parsed safely.
function Update-AkariWingetPackages {
    Install-AkariWingetTool
    Write-Log 'winget: updating every app'
    $r = Invoke-AkariWinget @('upgrade', '--all', '--include-unknown', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    foreach ($l in @($r.Out | Where-Object { $_ -match '[A-Za-z]{3}' })) { Write-Log "winget: $("$l".Trim())" }
    if ($r.Code -eq 0) { return 'Updated' }
    if ($r.Code -eq -1978335189) { Write-Log 'winget: every app is up to date'; return 'UpToDate' }
    if ($r.Code -in $AkariWingetRestart) { Write-Log 'winget: restart Windows to finish the updates'; return 'Restart' }
    throw "winget could not update every app $(Get-AkariWingetFailure $r)"
}

# winget's table of everything installed, as its lines (read only); empty when winget is missing or fails
function Get-AkariWingetList {
    try { $r = Invoke-AkariWinget @('list', '--accept-source-agreements', '--disable-interactivity') } catch { return @() }
    if ($r.Code -ne 0) { return @() }
    @($r.Out)
}

# the ids of $Ids that stand in those lines as a column of their own (ids are never translated; one winget cuts short
# is not found). Pure.
function Get-AkariInstalledIds([string[]]$Lines, [string[]]$Ids) {
    $text = @($Lines) -join "`n"
    @($Ids | Where-Object { $_ -and $text -match "(?im)(?<=[^\S\r\n])$([regex]::Escape($_))(?=[^\S\r\n]|$)" })
}

# installed, by winget or not (winget matches what Windows lists under installed apps)
function Test-AkariWingetInstalled([string]$Id, [string]$Source = 'winget') {
    try { $r = Invoke-AkariWinget @('list', '--id', $Id, '--exact', '--source', $Source, '--accept-source-agreements', '--disable-interactivity') }
    catch { return $false }
    ($r.Code -eq 0) -and [bool]($r.Out -match [regex]::Escape($Id))
}
