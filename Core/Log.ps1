# Logging. Write-Log goes to the GUI log drawer (through $LogQueue, set by Start-AkariJob) or to the console.
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
