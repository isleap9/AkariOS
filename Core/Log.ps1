# Logging. Write-Log goes to $LogQueue when it exists (GUI job: the GUI prints it to its console window) or straight to the console.
if (-not $AkariLogFile) { $AkariLogFile = "$env:LOCALAPPDATA\Akari\akari.log" }

function Write-Log([string]$m) {
    if (-not $m -or -not $m.Trim()) { return }
    $m = $m.TrimEnd()
    $q = Get-Variable LogQueue -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $q) { [void]$q.Enqueue($m) } else { [Console]::Out.WriteLine($m) }
}

# appends to akari.log; never throws
function Write-ErrLog([string]$m) {
    try { New-Item (Split-Path $AkariLogFile) -ItemType Directory -Force | Out-Null; Add-Content $AkariLogFile ("[{0}] {1}" -f (Get-Date -Format s), $m) } catch { }
}

# console banner (Akari's console stays open next to the window and shows the live log)
function Write-AkariBanner([string]$Line) {
    $Host.UI.RawUI.WindowTitle = 'AkariOS (Administrator) - keep this window open'
    try { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Gray'; Clear-Host } catch { }
    Write-Host ''
    Write-Host '     _    _              _  ___  ____  ' -ForegroundColor White
    Write-Host '    / \  | | ____ _ _ __(_)/ _ \/ ___| ' -ForegroundColor White
    Write-Host '   / _ \ | |/ / _` | ''__| | | | \___ \ ' -ForegroundColor White
    Write-Host '  / ___ \|   < (_| | |  | | |_| |___) |' -ForegroundColor White
    Write-Host ' /_/   \_\_|\_\__,_|_|  |_|\___/|____/ ' -ForegroundColor White
    Write-Host ''
    Write-Host "  $Line" -ForegroundColor White
    Write-Host '  Keep this window open: it shows what Akari is doing.' -ForegroundColor DarkGray
    Write-Host ''
}
