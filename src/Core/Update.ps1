# Update: checks GitHub Releases of isleap9/AkariOS for a newer version and installs it into the folder Akari runs
# from. GitHub is only reached through Invoke-AkariGitHubApi and Save-AkariUpdateFile, and the helper process only
# started through Start-AkariUpdater, so tests mock those (AGENTS.md rule 12).

$AkariRepo = 'isleap9/AkariOS'

# GET https://api.github.com/<path>; @{ Status; Body (parsed JSON); ResetAt (local time the rate limit resets) }.
# Never throws: no connection = Status 0.
function Invoke-AkariGitHubApi([string]$Path) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try {
        $r = Invoke-WebRequest "https://api.github.com/$Path" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop `
            -Headers @{ 'User-Agent' = 'AkariOS'; Accept = 'application/vnd.github+json' }
        @{ Status = [int]$r.StatusCode; Body = ($r.Content | ConvertFrom-Json); ResetAt = $null }
    } catch {
        $resp = $_.Exception.Response
        if (-not $resp) { return @{ Status = 0; Body = $null; ResetAt = $null } }
        $reset = $null
        $h = $resp.Headers['X-RateLimit-Reset']
        if ($h) { $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$h).LocalDateTime }
        $remaining = $resp.Headers['X-RateLimit-Remaining']
        $status = [int]$resp.StatusCode
        if ($status -eq 403 -and $remaining -eq '0') { $status = 429 }
        @{ Status = $status; Body = $null; ResetAt = $reset }
    }
}

# the latest stable release: @{ Ok; Version; Notes; PageUrl; AssetUrl; Digest; Message }
function Get-AkariLatestRelease {
    $r = Invoke-AkariGitHubApi "repos/$AkariRepo/releases/latest"
    if ($r.Status -eq 0) { return @{ Ok = $false; Message = "Couldn't reach GitHub. Check the internet connection." } }
    if ($r.Status -eq 429) {
        $when = if ($r.ResetAt) { " after $(([datetime]$r.ResetAt).ToString('HH:mm'))" } else { ' later' }
        return @{ Ok = $false; Message = "GitHub's limit was reached. Try again$when." }
    }
    if ($r.Status -eq 404) { return @{ Ok = $false; Message = 'No releases yet.' } }
    if ($r.Status -ne 200) { return @{ Ok = $false; Message = "GitHub answered with error $($r.Status). Try again later." } }
    $b = $r.Body
    $v = $null
    if (-not [version]::TryParse("$($b.tag_name)".TrimStart('v'), [ref]$v)) {
        return @{ Ok = $false; Message = "The latest release ($($b.tag_name)) has no version number." }
    }
    $asset = @($b.assets | Where-Object { $_.name -like 'AkariOS-*.zip' }) | Select-Object -First 1
    @{ Ok = $true; Version = $v; Notes = "$($b.body)"; PageUrl = $b.html_url
        AssetUrl = $asset.browser_download_url; Digest = $asset.digest; Message = $null }
}

# what the About page and the launch check show: @{ Kind = Available | Latest | Newer | Blocked | Error; Message;
# Release }. Pure apart from reading the install folder and $AkariRunPath.
function Get-AkariUpdateStatus([string]$Current, $Release, [string]$InstallDir, [bool]$JobRunning) {
    if (-not $Release.Ok) { return @{ Kind = 'Error'; Message = $Release.Message; Release = $Release } }
    if (-not $InstallDir) { return @{ Kind = 'Latest'; Message = 'Running the latest version from GitHub.'; Release = $Release } }
    $mine = [version]$Current
    $new = $Release.Version
    if ($new -gt $mine) {
        # a git checkout: the repo root, or its src\ folder (where Akari.ps1 lives in the repo)
        $git = (Test-Path (Join-Path $InstallDir '.git')) -or (Test-Path (Join-Path (Split-Path $InstallDir) '.git'))
        $why = if ($git) { 'This is a developer copy: update it with git.' }
            elseif ($AkariRunPath -and (Test-Path $AkariRunPath)) { 'Update once the Run in phases has finished.' }
            elseif ($JobRunning) { 'Update once the changes being applied are done.' }
        if ($why) { return @{ Kind = 'Blocked'; Message = "AkariOS $new is available. $why"; Release = $Release } }
        return @{ Kind = 'Available'; Message = "AkariOS $new is available (you have $mine)."; Release = $Release }
    }
    if ($new -eq $mine) { return @{ Kind = 'Latest'; Message = "You have the latest version ($mine)."; Release = $Release } }
    @{ Kind = 'Newer'; Message = "This copy ($mine) is newer than the latest release ($new)."; Release = $Release }
}

# where an update is downloaded and unpacked (emptied first each time)
if (-not $AkariUpdateDir) { $AkariUpdateDir = Join-Path $env:TEMP 'Akari-update' }
# this file: the helper process runs a copy of it (the install folder is being replaced)
$AkariUpdateScript = $PSCommandPath

# downloads a release asset to $OutFile (the only download; tests mock it)
function Save-AkariUpdateFile([string]$Url, [string]$OutFile) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $Url -OutFile $OutFile -UseBasicParsing -Headers @{ 'User-Agent' = 'AkariOS' } -ErrorAction Stop
}

# starts the helper (hidden, elevated like Akari): it waits for Akari to exit, swaps the folders and starts Akari again
function Start-AkariUpdater([string]$Helper, [int]$AkariPid, [string]$Staged, [string]$InstallDir) {
    # not started in the install folder: a process's working folder can't be moved
    Start-Process powershell.exe -WindowStyle Hidden -WorkingDirectory $env:TEMP -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Helper`" -AkariPid $AkariPid -Staged `"$Staged`" -InstallDir `"$InstallDir`""
}

# downloads the release, checks it against GitHub's SHA-256, unpacks it and starts the helper. @{ Ok; Message }.
# On Ok the caller closes Akari: the helper is waiting for it.
function Install-AkariUpdate($Release, [string]$InstallDir) {
    if (-not $Release.AssetUrl) { return @{ Ok = $false; Message = 'The release has no AkariOS download.' } }
    if ("$($Release.Digest)" -notmatch '^sha256:([0-9a-fA-F]{64})$') {
        return @{ Ok = $false; Message = "GitHub gave no checksum for the download, so it can't be checked. Not installing it." }
    }
    $want = $Matches[1]
    if (Test-Path $AkariUpdateDir) { Remove-Item $AkariUpdateDir -Recurse -Force }
    New-Item $AkariUpdateDir -ItemType Directory -Force | Out-Null
    $zip = Join-Path $AkariUpdateDir 'AkariOS.zip'
    try { Save-AkariUpdateFile $Release.AssetUrl $zip } catch { return @{ Ok = $false; Message = "The download failed: $($_.Exception.Message)" } }
    if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $want) {
        return @{ Ok = $false; Message = "The download doesn't match GitHub's checksum. Not installing it." }
    }
    $unpacked = Join-Path $AkariUpdateDir 'unpacked'
    try { Expand-Archive $zip $unpacked -Force -ErrorAction Stop } catch { return @{ Ok = $false; Message = "The download couldn't be unpacked: $($_.Exception.Message)" } }
    # the zip holds one AkariOS\ folder; a flat zip works too
    $staged = @($unpacked) + @(Get-ChildItem $unpacked -Directory | ForEach-Object { $_.FullName }) |
        Where-Object { Test-Path (Join-Path $_ 'Akari.ps1') } | Select-Object -First 1
    if (-not $staged) { return @{ Ok = $false; Message = "The download isn't an AkariOS release (no Akari.ps1). Not installing it." } }
    # the helper runs copies of Log.ps1 and this file, from outside the folder it replaces
    $helperDir = Join-Path $AkariUpdateDir 'helper'
    New-Item $helperDir -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path (Split-Path $AkariUpdateScript) 'Log.ps1'), $AkariUpdateScript $helperDir
    $helper = Join-Path $helperDir 'updater.ps1'
    Set-Content $helper -Encoding UTF8 -Value @'
param([int]$AkariPid, [string]$Staged, [string]$InstallDir)
. "$PSScriptRoot\Log.ps1"
. "$PSScriptRoot\Update.ps1"
try { Wait-Process -Id $AkariPid -Timeout 120 -ErrorAction Stop } catch { }
$r = Update-AkariFolder $Staged $InstallDir
Write-ErrLog "Update: $($r.Message)"
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$InstallDir\Akari.ps1`""
'@
    Start-AkariUpdater $helper $PID $staged $InstallDir
    @{ Ok = $true; Message = "Installing AkariOS $($Release.Version). Akari will restart." }
}

# the helper's work, once Akari has exited: the install folder moves to <folder>.old, the new files are copied in
# (files a release dropped go with the old folder) and unblocked. On a failure the old folder is put back.
# @{ Ok; Message }. The user's data (%LOCALAPPDATA%\Akari) is not in the install folder.
function Update-AkariFolder([string]$Staged, [string]$InstallDir) {
    $old = "$InstallDir.old"
    if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
    try { Move-Item $InstallDir $old -ErrorAction Stop }
    catch { return @{ Ok = $false; Message = "The update failed ($($_.Exception.Message)). Nothing was changed." } }
    try {
        Copy-Item $Staged $InstallDir -Recurse -Force -ErrorAction Stop
        Get-ChildItem $InstallDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        @{ Ok = $true; Message = 'AkariOS was updated.' }
    } catch {
        $why = $_.Exception.Message
        if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item $old $InstallDir -ErrorAction SilentlyContinue
        @{ Ok = $false; Message = "The update failed ($why). The old version was put back." }
    }
}

# on launch, after an update: the old copy and the download folder go
function Remove-AkariUpdateLeftover([string]$InstallDir) {
    if (-not $InstallDir) { return }
    foreach ($d in "$InstallDir.old", $AkariUpdateDir) {
        if ($d -and (Test-Path $d)) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# release notes for the About page and the update dialog: Markdown as plain text (headings, bold, code and link marks
# dropped, list items as bullets, at most one blank line in a row)
function ConvertTo-AkariNotesText([string]$Markdown) {
    $lines = foreach ($l in ($Markdown -replace "`r", '') -split "`n") {
        $l = $l -replace '^\s*#{1,6}\s*', '' -replace '^(\s*)[-*+]\s+', "`$1$([char]0x2022) "
        $l = $l -replace '\[([^\]]*)\]\([^)]*\)', '$1' -replace '(\*\*|__)(.+?)\1', '$2' -replace '`([^`]*)`', '$1'
        $l.TrimEnd()
    }
    ((@($lines) -join "`n") -replace "`n{3,}", "`n`n").Trim()
}
