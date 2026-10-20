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
# the AkariOS logo for the console (Assets\ascii.txt): blank rows at the top and bottom dropped, the common left margin
# trimmed, then scaled: $Scale for the height (0.7 still fits a default 80 x 30 window with the lines under it),
# $Wide for the width. Each new character is the most common one in the block of the original it covers (spaces count,
# '=' counts as '+'), which keeps the strokes' edges smooth. Empty when the file is missing. Pure.
$AkariBannerPath = Join-Path (Split-Path $PSScriptRoot) 'Assets\ascii.txt'
function Get-AkariBannerArt([string]$Path = $AkariBannerPath, [double]$Scale = 0.7, [double]$Wide = 0.8) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return @() }
    $rows = @(Get-Content -LiteralPath $Path | ForEach-Object { $_.TrimEnd() })
    $first = 0; while ($first -lt $rows.Count -and -not $rows[$first]) { $first++ }
    $last = $rows.Count - 1; while ($last -ge $first -and -not $rows[$last]) { $last-- }
    if ($first -gt $last) { return @() }
    $rows = $rows[$first..$last]
    $indent = ($rows | Where-Object { $_ } | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    $rows = @($rows | ForEach-Object { if ($_.Length -ge $indent) { $_.Substring($indent) } else { '' } })
    $w = ($rows | Measure-Object Length -Maximum).Maximum
    $rows = @($rows | ForEach-Object { $_.PadRight($w) })
    $th = [int][Math]::Ceiling($rows.Count * $Scale); $tw = [int][Math]::Ceiling($w * $Wide)
    for ($r = 0; $r -lt $th; $r++) {
        $r0 = [int][Math]::Floor($r / $Scale); $r1 = [int][Math]::Max($r0, [Math]::Min($rows.Count - 1, [Math]::Floor(($r + 1) / $Scale) - 1))
        $line = for ($c = 0; $c -lt $tw; $c++) {
            $c0 = [int][Math]::Floor($c / $Wide); $c1 = [int][Math]::Max($c0, [Math]::Min($w - 1, [Math]::Floor(($c + 1) / $Wide) - 1))
            $n = @{}
            for ($y = $r0; $y -le $r1; $y++) { for ($x = $c0; $x -le $c1; $x++) { $ch = [string]$rows[$y][$x]; if ($ch -eq '=') { $ch = '+' }; $n[$ch] = 1 + $n[$ch] } }
            # the most common; on a tie, a drawn character over a space
            ($n.GetEnumerator() | Sort-Object @{ e = { $_.Value }; Descending = $true }, @{ e = { $_.Key -eq ' ' } } | Select-Object -First 1).Key
        }
        (-join $line).TrimEnd()
    }
}

function Write-AkariBanner([string]$Line) {
    $Host.UI.RawUI.WindowTitle = 'AkariOS (Administrator) - keep this window open'
    try { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Gray'; Clear-Host } catch { }
    Write-Host ''
    $art = @(Get-AkariBannerArt)
    if ($art.Count) {
        # the logo's two strokes: dots white, + and = dark grey
        foreach ($r in $art) {
            Write-Host '  ' -NoNewline
            foreach ($m in [regex]::Matches($r, '[+=]+|[^+=]+')) {
                Write-Host $m.Value -NoNewline -ForegroundColor $(if ($m.Value -match '^[+=]') { 'DarkGray' } else { 'White' })
            }
            Write-Host ''
        }
    } else {
        Write-Host '     _    _              _  ___  ____  ' -ForegroundColor White
        Write-Host '    / \  | | ____ _ _ __(_)/ _ \/ ___| ' -ForegroundColor White
        Write-Host '   / _ \ | |/ / _` | ''__| | | | \___ \ ' -ForegroundColor White
        Write-Host '  / ___ \|   < (_| | |  | | |_| |___) |' -ForegroundColor White
        Write-Host ' /_/   \_\_|\_\__,_|_|  |_|\___/|____/ ' -ForegroundColor White
    }
    Write-Host ''
    Write-Host "  $Line" -ForegroundColor White
    Write-Host '  Keep this window open: it shows what Akari is doing.' -ForegroundColor DarkGray
    Write-Host ''
}
