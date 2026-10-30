# AkariOS bootstrap: what the one-liner runs (plan section 9, M6):
#   iwr 'https://github.com/isleap9/AkariOS/releases/latest/download/Akari.ps1' -useb | iex
# The release workflow (.github/workflows/release.yml) attaches a copy of this file as Akari.ps1, with its version and
# the release zip's SHA-256 filled in. As administrator (it asks), it downloads that zip, checks the hash, installs it
# to C:\AkariOS (an ordinary install: it updates itself from the About page; settings stay in %LOCALAPPDATA%\Akari),
# adds a Start menu shortcut and starts AkariOS.exe. An install of the same version is just started. ASCII only: iex
# reads it as text.

$AkariBootVersion = '__AKARI_VERSION__'
$AkariBootSha256 = '__AKARI_SHA256__'
$AkariBootRepo = 'isleap9/AkariOS'

function Get-AkariBootZipUrl([string]$Version) { "https://github.com/$AkariBootRepo/releases/download/v$Version/AkariOS-$Version.zip" }

# the only download (tests mock it)
function Save-AkariBootZip([string]$Url, [string]$Out) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
}

# the version an install folder holds (its Core\Version.ps1), or $null
function Get-AkariBootInstalled([string]$Dir) {
    $v = Join-Path $Dir 'Core\Version.ps1'
    if (-not (Test-Path -LiteralPath $v)) { return $null }
    $m = Select-String -LiteralPath $v -Pattern "AkariVersion = '([^']+)'" | Select-Object -First 1
    if ($m) { $m.Matches[0].Groups[1].Value }
}

# installs $Version into $Dir (downloaded once, checked, then swapped in for what was there) -> the path of its
# AkariOS.exe. The same version already there is kept as it is.
function Install-AkariBootApp([string]$Version, [string]$Sha256, [string]$Dir) {
    $exe = Join-Path $Dir 'AkariOS.exe'
    if ((Get-AkariBootInstalled $Dir) -eq $Version -and (Test-Path -LiteralPath $exe)) { return $exe }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "akari-boot-$([guid]::NewGuid().ToString('N'))"
    New-Item $tmp -ItemType Directory -Force | Out-Null
    try {
        $zip = Join-Path $tmp "AkariOS-$Version.zip"
        Save-AkariBootZip (Get-AkariBootZipUrl $Version) $zip
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $Sha256.ToUpperInvariant()) {
            throw "the download does not match AkariOS $Version's checksum; nothing was installed"
        }
        Expand-Archive -LiteralPath $zip -DestinationPath "$tmp\x" -Force
        $new = Join-Path $tmp 'x\AkariOS'
        if (-not (Test-Path -LiteralPath (Join-Path $new 'Akari.ps1'))) { throw "the AkariOS $Version zip has no AkariOS\Akari.ps1" }
        # the old install out of the way first (it fails while AkariOS runs from it: nothing is changed then)
        $old = "$Dir.old"
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
        if (Test-Path -LiteralPath $Dir) {
            try { Rename-Item -LiteralPath $Dir -NewName (Split-Path $old -Leaf) -ErrorAction Stop }
            catch { throw "close AkariOS first: $Dir is in use" }
        }
        Move-Item -LiteralPath $new -Destination $Dir
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue }
        Get-ChildItem -LiteralPath $Dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    $exe
}

# the Start menu shortcut for every user (tests mock it)
function New-AkariBootShortcut([string]$Exe) {
    $lnk = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\AkariOS.lnk'
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $s.TargetPath = $Exe
    $s.WorkingDirectory = Split-Path $Exe
    $s.Description = 'AkariOS'
    $s.Save()
}

if (-not $AkariBootNoRun) {
    try {
        if ($AkariBootVersion -like '__*') { throw 'this is the bootstrap''s source: run the copy attached to a release' }
        $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
        if (-not $admin) {
            # again as administrator, this same release's bootstrap
            $url = "https://github.com/$AkariBootRepo/releases/download/v$AkariBootVersion/Akari.ps1"
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr '$url' -useb | iex`""
        }
        else {
            Write-Host "Installing AkariOS $AkariBootVersion to $env:SystemDrive\AkariOS..."
            $exe = Install-AkariBootApp $AkariBootVersion $AkariBootSha256 "$env:SystemDrive\AkariOS"
            try { New-AkariBootShortcut $exe } catch { Write-Host "No Start menu shortcut: $($_.Exception.Message)" }
            # 1.0.0's one-liner unpacked AkariOS here; it is not used any more
            Remove-Item -LiteralPath "$env:LOCALAPPDATA\Akari\app" -Recurse -Force -ErrorAction SilentlyContinue
            Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
        }
    } catch { Write-Host "AkariOS could not be installed: $($_.Exception.Message)" -ForegroundColor Red }
}
