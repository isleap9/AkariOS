<#
.SYNOPSIS
    Builds AkariOS/akarios.ps1 - the single self-contained AkariOS installer script.

.DESCRIPTION
    Concatenation pipeline, ported from AkariTool/Compile.ps1:

        1. scripts/start.ps1                        - elevation, taskbar identity, WPF init
        2. functions/private/*.ps1                  - internal helpers (state, logging, runspace)
        3. functions/public/*.ps1                   - UI-facing actions (checks, confirm, progress)
        4. assets/text/*                            - base64-encoded engine scripts, decoded at runtime
        5. xaml/MainWindow.xaml                     - UI, with xaml/panels/*.xaml spliced at @PANELS@
        6. scripts/main.ps1                         - XAML parse, control wiring, ShowDialog

    Order matters: start.ps1 must run first (it defines $sync and the DwmApi type),
    main.ps1 must run last (it consumes everything above).

.PARAMETER Run
    Launch the compiled output elevated after a successful build.

.EXAMPLE
    ./Compile.ps1
    ./Compile.ps1 -Run
#>
param ([switch]$Run)

$ErrorActionPreference = "Stop"

Write-Host "Compiling AkariOS..." -ForegroundColor Cyan

$nl = "`r`n"
$outFile = Join-Path $PSScriptRoot "akarios.ps1"

# Helper - read a file and append with a blank line separator
function Append-File($path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing source file: $path" }
    $content = Get-Content -Path $path -Raw -Encoding UTF8
    return $content.TrimEnd() + $nl + $nl
}

# --- Start script (init, types) ---
$script = Append-File (Join-Path $PSScriptRoot "scripts\start.ps1")

# --- Functions: private then public (one file at a time, always newline-separated) ---
Get-ChildItem -Path (Join-Path $PSScriptRoot "functions\private") -File -Filter "*.ps1" -ErrorAction SilentlyContinue |
    Sort-Object Name | ForEach-Object { $script += Append-File $_.FullName }

Get-ChildItem -Path (Join-Path $PSScriptRoot "functions\public") -File -Filter "*.ps1" -ErrorAction SilentlyContinue |
    Sort-Object Name | ForEach-Object { $script += Append-File $_.FullName }

# --- Embed engine scripts (base64) so akarios.ps1 stays self-contained ---
# Each assets/text/<name>.ps1 becomes $sync.assets.<name> as raw UTF-8 text at runtime.
# WinSux stage scripts are the payload here; they are decoded and written to disk by
# the stage runner in Phase 2. Payloads themselves (DDU, DirectX, 7-Zip) download at runtime.
$script += "`$sync.assets = @{}" + $nl
Get-ChildItem (Join-Path $PSScriptRoot "assets\text") -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq ".ps1" } | Sort-Object Name | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $script += "`$sync.assets." + $_.BaseName + " = '" + [Convert]::ToBase64String($bytes) + "'" + $nl
        Write-Host ("  embedded asset: {0}.ps1 ({1:N0} bytes)" -f $_.BaseName, $bytes.Length) -ForegroundColor DarkGray
    }
$script += $nl

# --- Embed XAML (shell + per-panel fragments injected at the @PANELS@ marker) ---
$xamlPath = Join-Path $PSScriptRoot "xaml\MainWindow.xaml"
if (-not (Test-Path -LiteralPath $xamlPath)) { throw "Missing source file: $xamlPath" }
$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8

# Stitch each xaml/panels/*.xaml (sorted by NN- prefix) into the shell where the marker sits
$panelsDir = Join-Path $PSScriptRoot "xaml\panels"
if (Test-Path $panelsDir) {
    $panels = Get-ChildItem -Path $panelsDir -File -Filter "*.xaml" | Sort-Object Name |
        ForEach-Object { (Get-Content -Path $_.FullName -Raw -Encoding UTF8).TrimEnd() }
    $panelsXaml = ($panels -join ($nl + $nl))
    $xaml = [regex]::Replace($xaml, '[^\r\n]*<!-- @PANELS@[^\r\n]*-->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $panelsXaml })
    Write-Host ("  spliced {0} panel(s) at @PANELS@" -f @($panels).Count) -ForegroundColor DarkGray
}

$script += "`$inputXML = @'" + $nl + $xaml.TrimEnd() + $nl + "'@" + $nl + $nl

# --- Main script ---
$script += Append-File (Join-Path $PSScriptRoot "scripts\main.ps1")

Set-Content -Path $outFile -Value $script -Encoding UTF8

$size = (Get-Item $outFile).Length
Write-Host ("Done -> akarios.ps1 ({0:N0} bytes)" -f $size) -ForegroundColor Green

if ($Run) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$outFile`"" -Verb RunAs
}