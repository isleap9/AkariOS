# Builds the native app's release files (dev and release.yml):
#   dist\AkariOS-Native.exe        the portable single-file exe (self-contained, win-x64)
#   dist\AkariOS-Native-Setup.exe  its installer (build\AkariOS-Native.iss, Inno Setup 6)
# Both carry $AkariVersion (src\Core\Version.ps1); each one's ProductVersion is checked, since the updater compares it
# with the release's tag. Tests are not run here: run them first (release.yml does).
#   powershell -NoProfile -ExecutionPolicy Bypass -File build\Native.ps1 [-Iscc <ISCC.exe>] [-Out <folder>]
param(
    [string]$Iscc,
    [string]$Out
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
if (-not $Out) { $Out = Join-Path $root 'dist' }
# absolute: ISCC reads a relative /DSource or /O from the .iss file's folder
$Out = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).Path, $Out))
$ver = ([regex]::Match((Get-Content (Join-Path $root 'src\Core\Version.ps1') -Raw), "AkariVersion = '([^']+)'")).Groups[1].Value
if (-not $ver) { throw 'No $AkariVersion in src\Core\Version.ps1' }

if (-not $Iscc) {
    $Iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Iscc -or -not (Test-Path $Iscc)) { throw 'Inno Setup 6 (ISCC.exe) was not found: install it, or pass -Iscc' }

New-Item $Out -ItemType Directory -Force | Out-Null
$pub = Join-Path $Out 'native-publish'
if (Test-Path $pub) { Remove-Item $pub -Recurse -Force }

function Test-ProductVersion($file) {
    # Inno Setup pads the setup's with spaces
    $got = "$((Get-Item $file).VersionInfo.ProductVersion)".Trim()
    if ($got -ne $ver) { throw "$(Split-Path $file -Leaf) is version '$got', not $ver" }
}

# the portable exe
& dotnet publish (Join-Path $root 'app\AkariOS.App') -c Release -r win-x64 --self-contained `
    -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $pub
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }
$exe = Join-Path $pub 'AkariOS-Native.exe'
Test-ProductVersion $exe
Copy-Item $exe (Join-Path $Out 'AkariOS-Native.exe') -Force

# the installer, from the same exe
& $Iscc /Q "/DVersion=$ver" "/DSource=$exe" "/DRoot=$root" "/O$Out" (Join-Path $PSScriptRoot 'AkariOS-Native.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
$setup = Join-Path $Out 'AkariOS-Native-Setup.exe'
Test-ProductVersion $setup
Remove-Item $pub -Recurse -Force

Get-Item (Join-Path $Out 'AkariOS-Native.exe'), $setup | ForEach-Object { '{0}  {1:N1} MB' -f $_.Name, ($_.Length / 1MB) }
