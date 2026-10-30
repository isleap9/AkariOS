# Builds src/UI/Icons.xaml from Lucide (https://lucide.dev, ISC): one StreamGeometry per icon AkariOS uses, keyed
# Ic.<name>, so the app never parses SVG. Dev-only; run it again after changing $Names. The redesign plan
# (docs/plans/2026-10-30-redesign.md, batch 3) has the why.
#   1. download lucide-static 0.460.0 (npm: https://registry.npmjs.org/lucide-static/-/lucide-static-0.460.0.tgz)
#   2. unpack it (tar -xzf), then:  powershell -File build\Icons.ps1 -Package <folder>\package
# Shapes become path data: circle / ellipse as two arcs, rect (rx) as lines and arcs, line, polyline, polygon; a path's
# own data is re-tokenised so WPF reads SVG's packed numbers and arc flags ("a.5.5 0 011-1"). Every geometry is parsed
# by WPF before it is written. The output is ASCII.
param([Parameter(Mandatory = $true)][string]$Package, [string]$Out = '')
$ErrorActionPreference = 'Stop'
# (5.1 has no $PSScriptRoot in a param default)
if (-not $Out) { $Out = Join-Path (Split-Path $PSScriptRoot) 'src\UI\Icons.xaml' }
Add-Type -AssemblyName PresentationCore

$Version = '0.460.0'
# every icon the UI uses (New-AkariIcon '<name>', the $Pages and $AkariCategoryGlyphs tables, XAML Ic.<name>)
$Names = @(
    # pages, Home tiles, mode cards
    'house', 'zap', 'sliders-horizontal', 'download', 'trash-2', 'usb', 'info', 'activity', 'refresh-cw', 'wrench',
    'monitor', 'app-window', 'cpu', 'flask-conical', 'list-checks', 'arrow-left-right', 'history', 'settings',
    # Categories
    'gamepad-2', 'gauge', 'sliders-vertical', 'lock', 'panel-bottom', 'layout-grid', 'folder', 'palette', 'cloud-download',
    'power', 'wifi', 'bell', 'mouse', 'accessibility', 'volume-2', 'settings-2', 'shield-check', 'eraser', 'hard-drive',
    # marks, dialogs, bars
    'triangle-alert', 'rotate-ccw', 'circle-help', 'circle-x', 'shield', 'search', 'arrow-left',
    # window chrome and controls
    'menu', 'minus', 'square', 'copy', 'x', 'check', 'chevron-down',
    # the title bar menu
    'file-input', 'file-output', 'sun-moon', 'github', 'bug', 'message-circle', 'external-link', 'folder-open'
)

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
    # a path's first "m" is absolute in SVG, but not once the icon's shapes are joined into one geometry: make it
    # "M x y", and the pairs SVG reads after it as relative lines an explicit "l"
    if ($out.Count -and $out[0] -ceq 'm') {
        $out[0] = 'M'
        if ($out.Count -gt 3 -and $out[3] -notmatch '^[A-Za-z]$') { $out.Insert(3, 'l') }
    }
    $out -join ' '
}

function Get-A($a, [string]$k, [double]$def = 0) { if ($a.PSObject.Properties[$k]) { [double]$a.$k } else { $def } }

# one Lucide node ([tag, attrs]) as path data
function ConvertTo-PathData([string]$Tag, $A) {
    switch ($Tag) {
        'path' { ConvertFrom-SvgPath $A.d }
        'line' { "M $(F (Get-A $A x1)) $(F (Get-A $A y1)) L $(F (Get-A $A x2)) $(F (Get-A $A y2))" }
        { $_ -in 'circle', 'ellipse' } {
            $cx = Get-A $A cx; $cy = Get-A $A cy
            $rx = if ($Tag -eq 'circle') { Get-A $A r } else { Get-A $A rx }; $ry = if ($Tag -eq 'circle') { $rx } else { Get-A $A ry }
            "M $(F ($cx - $rx)) $(F $cy) A $(F $rx) $(F $ry) 0 1 0 $(F ($cx + $rx)) $(F $cy) A $(F $rx) $(F $ry) 0 1 0 $(F ($cx - $rx)) $(F $cy) Z"
        }
        'rect' {
            $x = Get-A $A x; $y = Get-A $A y; $w = Get-A $A width; $h = Get-A $A height
            $rx = Get-A $A rx; $ry = Get-A $A ry $rx
            if (-not $A.PSObject.Properties['rx'] -and $A.PSObject.Properties['ry']) { $rx = $ry }
            $rx = [Math]::Min($rx, $w / 2); $ry = [Math]::Min($ry, $h / 2)
            if ($rx -le 0) { return "M $(F $x) $(F $y) H $(F ($x + $w)) V $(F ($y + $h)) H $(F $x) Z" }
            "M $(F ($x + $rx)) $(F $y) H $(F ($x + $w - $rx)) A $(F $rx) $(F $ry) 0 0 1 $(F ($x + $w)) $(F ($y + $ry)) " +
            "V $(F ($y + $h - $ry)) A $(F $rx) $(F $ry) 0 0 1 $(F ($x + $w - $rx)) $(F ($y + $h)) H $(F ($x + $rx)) " +
            "A $(F $rx) $(F $ry) 0 0 1 $(F $x) $(F ($y + $h - $ry)) V $(F ($y + $ry)) A $(F $rx) $(F $ry) 0 0 1 $(F ($x + $rx)) $(F $y) Z"
        }
        { $_ -in 'polyline', 'polygon' } {
            $p = @([regex]::Matches($A.points, $num) | ForEach-Object { F ([double]::Parse($_.Value, [Globalization.CultureInfo]::InvariantCulture)) })
            $s = "M $($p[0]) $($p[1])"
            for ($i = 2; $i -lt $p.Count; $i += 2) { $s += " L $($p[$i]) $($p[$i + 1])" }
            if ($Tag -eq 'polygon') { $s += ' Z' }
            $s
        }
        default { throw "unknown shape <$Tag>" }
    }
}

$nodes = Get-Content (Join-Path $Package 'icon-nodes.json') -Raw | ConvertFrom-Json
$pkg = Get-Content (Join-Path $Package 'package.json') -Raw | ConvertFrom-Json
if ($pkg.version -ne $Version) { throw "lucide-static $($pkg.version) found, $Version expected" }
$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('<!-- Generated by build/Icons.ps1 from Lucide ' + $Version + ' (https://lucide.dev, ISC License, Copyright (c) Lucide Contributors 2022, portions Cole Bemis 2013-2022 as part of Feather, MIT). Do not edit: change $Names there and run it again. -->')
[void]$sb.AppendLine('<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"')
[void]$sb.AppendLine('                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">')
foreach ($n in ($Names | Sort-Object -Unique)) {
    $icon = $nodes.$n
    if (-not $icon) { throw "Lucide $Version has no icon '$n'" }
    $data = (@($icon | ForEach-Object { ConvertTo-PathData $_[0] $_[1] }) -join ' ')
    [void][Windows.Media.Geometry]::Parse($data)
    [void]$sb.AppendLine("  <StreamGeometry x:Key=`"Ic.$n`">$data</StreamGeometry>")
}
[void]$sb.AppendLine('</ResourceDictionary>')
$text = $sb.ToString()
if ($text -match '[^\x00-\x7F]') { throw 'the output is not ASCII' }
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::ASCII)
"$(@($Names | Sort-Object -Unique).Count) icons -> $Out"
