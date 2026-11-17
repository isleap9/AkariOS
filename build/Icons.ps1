# Builds src/UI/Icons.xaml from Fluent System Icons (Microsoft, MIT, https://github.com/microsoft/fluentui-system-icons):
# one StreamGeometry per icon AkariOS uses, keyed Ic.<name> (the names the UI used with Lucide, so no call site changes),
# plus Ic.<name>.Filled for the icons in $Filled. Dev-only; run it again after changing $Icons or $Filled. The plan
# (docs/plans/2026-11-17-windows-11-style.md, batch 3) has the mapping and the why.
#   1. download @fluentui/svg-icons 1.1.344 (npm: https://registry.npmjs.org/@fluentui/svg-icons/-/svg-icons-1.1.344.tgz)
#   2. unpack it (tar -xzf), then:  powershell -File build\Icons.ps1 -Package <folder>\package
# Each icon is the 20px size (a 20 x 20 viewBox) of its regular or filled style: plain filled paths, drawn with Fill
# (Nonzero, the "F1" prefix), never Stroke. A path's data is re-tokenised so WPF reads SVG's packed numbers and arc flags
# ("a.5.5 0 011-1"). Every geometry is parsed by WPF before it is written. The output is ASCII.
param([Parameter(Mandatory = $true)][string]$Package, [string]$Out = '')
$ErrorActionPreference = 'Stop'
# (5.1 has no $PSScriptRoot in a param default)
if (-not $Out) { $Out = Join-Path (Split-Path $PSScriptRoot) 'src\UI\Icons.xaml' }
Add-Type -AssemblyName PresentationCore

$Version = '1.1.344'
# Ic key (what the UI names: New-AkariIcon '<name>', the $Pages and $AkariCategoryGlyphs tables, XAML Ic.<name>) -> Fluent
$Icons = [ordered]@{
    # pages, Home tiles, mode cards
    'house' = 'home'; 'zap' = 'flash'; 'sliders-horizontal' = 'options'; 'download' = 'arrow_download'; 'trash-2' = 'delete'
    'usb' = 'usb_stick'; 'disc-3' = 'storage'; 'info' = 'info'; 'activity' = 'pulse'; 'refresh-cw' = 'arrow_sync'
    'wrench' = 'wrench'; 'monitor' = 'desktop'; 'app-window' = 'window'; 'cpu' = 'developer_board'; 'flask-conical' = 'beaker'
    'list-checks' = 'task_list_ltr'; 'arrow-left-right' = 'arrow_swap'; 'history' = 'history'; 'settings' = 'settings'
    # Categories
    'gamepad-2' = 'games'; 'gauge' = 'top_speed'; 'sliders-vertical' = 'slide_settings'; 'lock' = 'lock_closed'
    'panel-bottom' = 'panel_bottom'; 'layout-grid' = 'grid'; 'folder' = 'folder'; 'palette' = 'color'
    'cloud-download' = 'cloud_arrow_down'; 'power' = 'power'; 'wifi' = 'wifi_1'; 'bell' = 'alert'; 'mouse' = 'cursor'
    'accessibility' = 'accessibility'; 'volume-2' = 'speaker_2'; 'settings-2' = 'options'; 'shield-check' = 'shield_checkmark'
    'eraser' = 'eraser'; 'hard-drive' = 'hard_drive'; 'blocks' = 'apps_add_in'
    # marks, dialogs, bars
    'triangle-alert' = 'warning'; 'rotate-ccw' = 'arrow_counterclockwise'; 'circle-help' = 'question_circle'
    'circle-x' = 'dismiss_circle'; 'shield' = 'shield'; 'search' = 'search'; 'arrow-left' = 'arrow_left'
    'arrow-right' = 'arrow_right'; 'circle-check' = 'checkmark_circle'; 'circle-minus' = 'subtract_circle'
    'circle-slash' = 'prohibited'; 'undo-2' = 'arrow_undo'
    # window chrome and controls
    'menu' = 'navigation'; 'minus' = 'subtract'; 'square' = 'maximize'; 'copy' = 'copy'; 'x' = 'dismiss'
    'check' = 'checkmark'; 'chevron-down' = 'chevron_down'
    # the title bar menu (About's cards from batch 5); github: Fluent has no brand icons, code stands in
    'file-input' = 'arrow_import'; 'file-output' = 'arrow_export_ltr'; 'sun-moon' = 'dark_theme'; 'github' = 'code'
    'bug' = 'bug'; 'message-circle' = 'chat'; 'external-link' = 'open'; 'folder-open' = 'folder_open'
}
# Ic.<key>.Filled too: the navigation pages (the selected item), the InfoBar severities, the check box tick
$Filled = @('house', 'zap', 'sliders-horizontal', 'download', 'trash-2', 'usb', 'info', 'triangle-alert', 'circle-x', 'circle-check', 'check')

$num = '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?'
function F([double]$v) { $v.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture) }

# an SVG path's data with every number and arc flag separated (WPF does not split "1.5.5" or "011" itself)
function ConvertFrom-SvgPath([string]$d) {
    $out = [Collections.Generic.List[string]]::new()
    $i = 0; $cmd = ''; $argn = 0
    while ($i -lt $d.Length) {
        $c = $d[$i]
        if ($c -match '[MmLlHhVvCcSsQqTtAaZz]') { $out.Add([string]$c); $cmd = [string]$c; $argn = 0; $i++; continue }
        if ($c -match '[\s,]') { $i++; continue }
        # arc flags (the 4th and 5th of each 7 arguments) are one digit each
        if ($cmd -in 'A', 'a' -and ($argn % 7) -in 3, 4) { $out.Add([string]$c); $argn++; $i++; continue }
        $m = [regex]::Match($d.Substring($i), "^$num")
        if (-not $m.Success) { throw "path data: can't read '$($d.Substring($i))'" }
        $out.Add((F ([double]::Parse($m.Value, [Globalization.CultureInfo]::InvariantCulture))))
        $argn++; $i += $m.Length
    }
    # a path's first "m" is absolute in SVG, but not once an icon's paths are joined into one geometry: make it
    # "M x y", and the pairs SVG reads after it as relative lines an explicit "l"
    if ($out.Count -and $out[0] -ceq 'm') {
        $out[0] = 'M'
        if ($out.Count -gt 3 -and $out[3] -notmatch '^[A-Za-z]$') { $out.Insert(3, 'l') }
    }
    $out -join ' '
}

# one icon file as path data: every <path d>, nothing else (a coloured or clipped icon is refused)
function Get-IconData([string]$Name, [string]$Style) {
    $file = Join-Path $Package "icons\$($Name)_20_$Style.svg"
    if (-not (Test-Path -LiteralPath $file)) { throw "Fluent $Version has no icon '$($Name)_20_$Style'" }
    $svg = ([xml][IO.File]::ReadAllText($file)).svg
    if ($svg.viewBox -ne '0 0 20 20') { throw "$file : viewBox $($svg.viewBox)" }
    $parts = foreach ($n in $svg.ChildNodes) {
        if ($n.LocalName -ne 'path' -or @($n.Attributes | Where-Object Name -ne 'd').Count) { throw "$file : <$($n.LocalName)> with attributes is not a plain path" }
        ConvertFrom-SvgPath $n.d
    }
    'F1 ' + (@($parts) -join ' ')
}

$pkg = Get-Content (Join-Path $Package 'package.json') -Raw | ConvertFrom-Json
if ($pkg.version -ne $Version) { throw "@fluentui/svg-icons $($pkg.version) found, $Version expected" }
foreach ($k in $Filled) { if (-not $Icons.Contains($k)) { throw "Filled '$k' is not in Icons" } }
$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('<!-- Generated by build/Icons.ps1 from Fluent System Icons ' + $Version + ' (@fluentui/svg-icons, https://github.com/microsoft/fluentui-system-icons, MIT License, Copyright (c) 2020 Microsoft Corporation), 20px regular; .Filled = filled. Do not edit: change $Icons there and run it again. -->')
[void]$sb.AppendLine('<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"')
[void]$sb.AppendLine('                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">')
$count = 0
foreach ($k in ($Icons.Keys | Sort-Object)) {
    $styles = @(@{ Key = "Ic.$k"; Style = 'regular' })
    if ($k -in $Filled) { $styles += @{ Key = "Ic.$k.Filled"; Style = 'filled' } }
    foreach ($s in $styles) {
        $data = Get-IconData $Icons[$k] $s.Style
        [void][Windows.Media.Geometry]::Parse($data)
        [void]$sb.AppendLine("  <StreamGeometry x:Key=`"$($s.Key)`">$data</StreamGeometry>")
        $count++
    }
}
[void]$sb.AppendLine('</ResourceDictionary>')
$text = $sb.ToString()
if ($text -match '[^\x00-\x7F]') { throw 'the output is not ASCII' }
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::ASCII)
"$count geometries -> $Out"
