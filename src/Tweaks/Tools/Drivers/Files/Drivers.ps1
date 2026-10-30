# Steps the Tools > Drivers Actions share, dot-sourced inside their blocks: . "$AkariTweakDir\Files\Drivers.ps1"
# Not a tweak (the Loader reads only <Section>\<Category>\*.ps1). Ported from AkariOS-Ultimate (FR33THY Ultimate)
# 5 Graphics "Driver Clean", "Driver Updated Install" and "Driver Debloat Install & Settings".

# 7-Zip's 7z.exe, installed from winget when missing
function Get-DriverSevenZip {
    $7z = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path -LiteralPath $7z)) { Install-AkariWingetPackage '7zip.7zip' }
    if (-not (Test-Path -LiteralPath $7z)) { throw '7-Zip is not installed, and winget could not install it' }
    $7z
}

# unpacks $Archive into $Dir (emptied first)
function Expand-DriverArchive([string]$Archive, [string]$Dir) {
    Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue
    if ((Invoke-AkariExe (Get-DriverSevenZip) @('x', $Archive, "-o$Dir", '-y')) -ne 0) { throw "$(Split-Path $Archive -Leaf) could not be unpacked" }
}

# Display Driver Uninstaller in Windows\Temp\ddu with One-click's settings (no update check, no restore point, no
# driver downloads from Windows Update), read only so DDU keeps them. Needs the network: a Prepare step.
function Initialize-DriverDdu {
    $dir = "$env:SystemRoot\Temp\ddu"
    $exe = Save-AkariFile 'ddu.exe' "$env:SystemRoot\Temp\ddu.exe"
    Expand-DriverArchive $exe $dir
    $cfg = "$dir\Settings\Settings.xml"
    New-Item (Split-Path $cfg) -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $AkariTweakDir '..\..\OneClick\Prepare\Files\ddu-settings.xml') -Destination $cfg -Force
    Set-ItemProperty -LiteralPath $cfg -Name IsReadOnly -Value $true
}

# DDU's program, ready from Prepare
function Get-DriverDdu {
    $exe = "$env:SystemRoot\Temp\ddu\Display Driver Uninstaller.exe"
    if (-not (Test-Path -LiteralPath $exe)) { throw 'DDU is not ready (its download before the restart failed)' }
    $exe
}

# the latest WHQL GeForce driver: NVIDIA's own driver lookup, then its download link
function Get-DriverNvidiaUrl {
    $lookup = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=120&pfid=929&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1'
    # only IDS[0].downloadInfo.Version is needed: read with a regex (ConvertFrom-Json needs the real SystemRoot)
    $c = "$((Invoke-WebRequest -Uri $lookup -UseBasicParsing).Content)"
    $v = if ($c -match '"downloadInfo"\s*:\s*\{[^{}]*?"Version"\s*:\s*"([\d.]+)"') { $Matches[1] }
    if (-not $v) { throw 'NVIDIA''s driver lookup gave no version' }
    Write-Log "Latest NVIDIA driver: $v"
    "https://international.download.nvidia.com/Windows/$v/$v-desktop-win10-win11-64bit-international-dch-whql.exe"
}

# the newest file like $Like (and not like $NotLike) in the real user's Downloads folder, $null when there is none
function Find-DriverDownload([string]$Like, [string]$NotLike = '') {
    Get-ChildItem -LiteralPath (Get-AkariUserFolder 'Downloads') -File -Filter $Like -ErrorAction SilentlyContinue |
        Where-Object { -not $NotLike -or $_.Name -notlike $NotLike } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# a full driver package from Downloads, or the vendor's page opened and a failure that says what to do
function Get-DriverPackage([string]$Like, [string]$NotLike, [string]$Page, [string]$Vendor) {
    $f = Find-DriverDownload $Like $NotLike
    if ($f) { Write-Log "Driver package: $($f.Name)"; return $f.FullName }
    Start-Process $Page
    throw "no $Vendor driver package ($Like) in your Downloads folder: download the full driver from the page that just opened, then press again"
}

# stops and deletes driver services and services the vendor installs in the background
function Remove-DriverServices([string[]]$Names) {
    foreach ($n in $Names) {
        Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
        Remove-AkariService $n
    }
}
