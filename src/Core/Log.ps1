# Logging. Write-Log goes to $LogQueue when it exists (GUI job: the GUI prints it to its console window) or straight to the console.
if (-not $AkariLogFile) { $AkariLogFile = "$env:LOCALAPPDATA\Akari\akari.log" }

function Write-Log([string]$m) {
    if (-not $m -or -not $m.Trim()) { return }
    $m = $m.TrimEnd()
    $q = Get-Variable LogQueue -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $q) { [void]$q.Enqueue($m) } else { Write-AkariConsoleLine $m }
}

# ---- the console's look (Akari's console window: One-click, a Run in phases, the GUI's live log). Each log line gets
# a time column and a fixed-width status tag in its colour, a phase a ruled header (and the window's title), the Run's
# "Done:" line a finish block. Non-ASCII through [char] codes (this file has no BOM). The native app's
# AkariOS.Core/Runs/ConsoleLines.cs does the same; ConsoleLinesTests compares ConvertTo-AkariConsoleLine.

$AkariConsoleRule = [string][char]0x2500
$AkariConsoleWidth = 72

# (pure) one log line as the console prints it: @(@{ Text; Color }) segments, '' Text = a line break; $Time 'HH:mm:ss'
function ConvertTo-AkariConsoleLine([string]$Message, [string]$Time) {
    $m = "$Message".TrimEnd()
    $seg = [Collections.Generic.List[object]]::new()
    $add = { param($t, $c) $seg.Add(@{ Text = $t; Color = $c }) }
    $tag = {
        param($label, $color, $text, $textColor, $note)
        & $add "  $Time " 'DarkGray'; & $add '[' 'DarkGray'; & $add $label $color; & $add '] ' 'DarkGray'; & $add $text $textColor
        if ($note) { & $add "  $note" 'DarkGray' }
    }
    if ($m -match '^Phase (\d+) of (\d+): (.+)$') {
        $head = "Phase $($Matches[1]) of $($Matches[2])"
        & $add '' 'Gray'
        & $add "  $($AkariConsoleRule * 2) " 'DarkRed'; & $add $head 'White'; & $add "  $($Matches[3]) " 'Gray'
        $used = 6 + $head.Length + $Matches[3].Length + 2
        & $add ($AkariConsoleRule * [Math]::Max(3, $AkariConsoleWidth - $used)) 'DarkRed'
    }
    elseif ($m -match '^Done: (.+)$') {
        & $add '' 'Gray'
        & $add "  $($AkariConsoleRule * ($AkariConsoleWidth - 2))" 'DarkGray'; & $add '' 'Gray'
        & $add '  Finished  ' 'White'; & $add $Matches[1] $(if ($Matches[1] -match 'failed') { 'Yellow' } else { 'Green' })
    }
    elseif ($m -match '^  Failed: (.+?): (.*)$') { & $add '             ' 'Gray'; & $add ([string][char]0x00D7 + ' ') 'Red'; & $add $Matches[1] 'Red'; & $add "  $($Matches[2])" 'DarkGray' }
    elseif ($m -match '^Applied: (.+)$') { & $tag '  OK  ' 'Green' $Matches[1] 'Gray' '' }
    elseif ($m -match '^Reverted: (.+?)( \((.+)\))?$') { & $tag 'REVERT' 'Cyan' $Matches[1] 'Gray' $Matches[3] }
    elseif ($m -match '^Already: (.+)$') { & $tag ' SAME ' 'DarkGray' $Matches[1] 'DarkGray' 'already set' }
    elseif ($m -match '^Skipped: (.+?)( \((.+)\))?$') { & $tag ' SKIP ' 'Yellow' $Matches[1] 'Gray' $Matches[3] }
    elseif ($m -match '^Failed: (.+?)(: (.+))?$') { & $tag 'FAILED' 'Red' $Matches[1] 'Red' $Matches[3] }
    elseif ($m -match '^In Safe Mode: (.+)$') { & $tag ' WAIT ' 'DarkCyan' $Matches[1] 'Gray' 'in Safe Mode' }
    elseif ($m -match '^(Warning|Error): (.+)$') { & $tag $(if ($Matches[1] -eq 'Error') { 'ERROR ' } else { ' WARN ' }) $(if ($Matches[1] -eq 'Error') { 'Red' } else { 'Yellow' }) $Matches[2] 'Gray' '' }
    elseif ($m -match '^(Restarting|Stopped) ') { & $add '' 'Gray'; & $add "  $Time " 'DarkGray'; & $add ([string][char]0x25B8 + ' ') 'Yellow'; & $add $m 'Yellow' }
    else { & $add "  $Time " 'DarkGray'; & $add '         ' 'Gray'; & $add $m 'Gray' }
    @($seg)
}

# writes one log line in the console's look; a phase also goes to the window's title. Output that isn't a console
# (the CLI piped, a test) gets the plain line: -Stamp = "[HH:mm:ss] line" (the GUI's live log), else the line as it is.
# Never throws.
function Write-AkariConsoleLine([string]$Message, [switch]$Stamp) {
    if ([Console]::IsOutputRedirected) {
        try { [Console]::Out.WriteLine($(if ($Stamp) { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message } else { $Message })) } catch { }
        return
    }
    try {
        if ($Message -match '^Phase (\d+) of (\d+): (.+)$') { try { $Host.UI.RawUI.WindowTitle = "AkariOS $([char]0x00B7) phase $($Matches[1]) of $($Matches[2]) $([char]0x00B7) $($Matches[3])" } catch { } }
        foreach ($s in @(ConvertTo-AkariConsoleLine $Message (Get-Date -Format 'HH:mm:ss'))) {
            if ($s.Text -eq '') { [Console]::Out.WriteLine(); continue }
            [Console]::ForegroundColor = $s.Color
            [Console]::Out.Write($s.Text)
        }
        [Console]::ResetColor()
        [Console]::Out.WriteLine()
    } catch { try { [Console]::Out.WriteLine($Message) } catch { } }
}

# the last line of a console Run: dim, after a blank line
function Write-AkariConsoleClose {
    try { [Console]::Out.WriteLine(); [Console]::ForegroundColor = 'DarkGray'; [Console]::Out.WriteLine('  Press Enter to close this window.'); [Console]::ResetColor() } catch { }
    [void][Console]::ReadLine()
}

# appends to akari.log; never throws
function Write-ErrLog([string]$m) {
    try { New-Item (Split-Path $AkariLogFile) -ItemType Directory -Force | Out-Null; Add-Content $AkariLogFile ("[{0}] {1}" -f (Get-Date -Format s), $m) } catch { }
}

# the loader's Problems: Warnings go to akari.log only, Errors through $Show too (stderr in the CLI, the GUI's log)
function Write-AkariProblems($Problems, [scriptblock]$Show) {
    foreach ($p in $Problems) {
        $m = "$($p.Level): $($p.File): $($p.Message)"
        if ($p.Level -eq 'Error') { & $Show $m } else { Write-ErrLog $m }
    }
}

# Akari.ps1's trap: the error goes to akari.log, then to a message box when WPF is loaded (the GUI), else to the
# console (CLI, -Resume: no WPF there). -Wait keeps a console that RunOnce opened up until Enter.
function Write-AkariCrash($ErrorRecord, [switch]$Wait) {
    $m = "$($ErrorRecord.Exception.Message) $($ErrorRecord.InvocationInfo.PositionMessage)"
    Write-ErrLog $m
    $box = 'System.Windows.MessageBox' -as [type]
    if ($box) { [void]$box::Show("Akari hit an error:`n`n$m", 'Akari'); return }
    [Console]::Error.WriteLine("Akari hit an error: $m")
    if ($Wait) { [Console]::Out.WriteLine('  Press Enter to close this window.'); [void][Console]::ReadLine() }
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
    # UTF-8, so the rules and marks draw (Consolas and Cascadia have them)
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
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
    # the header: what runs and the version, a rule, what to expect
    $ver = if ($AkariVersion) { "  AkariOS $AkariVersion" } else { '' }
    Write-Host "  $Line" -ForegroundColor White -NoNewline
    Write-Host $ver -ForegroundColor DarkGray
    Write-Host "  $($AkariConsoleRule * ($AkariConsoleWidth - 2))" -ForegroundColor DarkRed
    Write-Host '  Keep this window open. Your PC may restart along the way; AkariOS carries on by itself.' -ForegroundColor DarkGray
    Write-Host ''
}
