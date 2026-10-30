# AkariOS bootstrap: what the one-liner runs (plan section 9, M6):
#   iwr 'https://github.com/isleap9/AkariOS/releases/latest/download/Akari.ps1' -useb | iex
# The release workflow (.github/workflows/release.yml) attaches a copy of this file as Akari.ps1, with its version and
# the release zip's SHA-256 filled in. It downloads that zip once into %LOCALAPPDATA%\Akari\app\<version>, checks the
# hash, unpacks it, marks the folder (.bootstrap: Akari.ps1 then offers no self-update, the next one-liner run is the
# latest) and starts Akari from there. Older unpacked versions are removed. ASCII only: iex reads it as text.

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

# the unpacked app for $Version under $Base (downloaded and checked once, reused after) -> the path of its Akari.ps1
function Install-AkariBootApp([string]$Version, [string]$Sha256, [string]$Base) {
    $dir = Join-Path $Base $Version
    $akari = Join-Path $dir 'AkariOS\Akari.ps1'
    $mark = Join-Path $dir 'AkariOS\.bootstrap'
    if ((Test-Path -LiteralPath $mark) -and (Test-Path -LiteralPath $akari)) { return $akari }
    New-Item $Base -ItemType Directory -Force | Out-Null
    $zip = Join-Path $Base "AkariOS-$Version.zip"
    Save-AkariBootZip (Get-AkariBootZipUrl $Version) $zip
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($hash -ne $Sha256.ToUpperInvariant()) {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        throw "the download does not match AkariOS $Version's checksum; nothing was run"
    }
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
    Remove-Item -LiteralPath $zip -Force
    if (-not (Test-Path -LiteralPath $akari)) { throw "the AkariOS $Version zip has no AkariOS\Akari.ps1" }
    Get-ChildItem -LiteralPath $dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $mark -Value $Version
    # older unpacked versions (one still running stays: its files are in use)
    Get-ChildItem -LiteralPath $Base -Directory | Where-Object { $_.Name -ne $Version } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $akari
}

if (-not $AkariBootNoRun) {
    try {
        if ($AkariBootVersion -like '__*') { throw 'this is the bootstrap''s source: run the copy attached to a release' }
        Write-Host "Getting AkariOS $AkariBootVersion..."
        $akari = Install-AkariBootApp $AkariBootVersion $AkariBootSha256 "$env:LOCALAPPDATA\Akari\app"
        # Akari.ps1 asks for administrator rights itself
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $akari
    } catch { Write-Host "AkariOS could not start: $($_.Exception.Message)" -ForegroundColor Red }
}
