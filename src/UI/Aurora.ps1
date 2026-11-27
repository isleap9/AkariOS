# The Aurora banner's light (ADR 0011, plan docs/plans/2026-11-26-aurora-powershell.md; the native app's
# Controls\AuroraBackdrop.cs, RibbonArt.cs, BloomMark.cs): three soft glows in the page's own colours drifting behind
# the top of the content layer, and the Akari bloom (a corner glow and three ribbons) in its top right corner, faded out
# downwards. Decoration only: never hit-tested, gone in high contrast (followed live), still with motion off. The
# colours are the theme files' Aurora<Palette><A|B|C|Ribbon|RibbonLight> Colors; every animation through UI\Motion.ps1.
# Dot-sourced after UI\Motion.ps1; pure helpers first (tests dot-source this file). The backdrop itself is MainWindow.xaml's
# Aurora grid, filled by New-AkariAurora (UI\Shell.ps1) and set per page by Show-AkariPageNow.

$AkariAuroraPalettes = @('Home', 'Install', 'Optimize', 'Remove', 'Downloads', 'Usb', 'Iso', 'Settings')

# the design's glows: anchored left or right, X and Width as a share of the page's width, Top in px, Height = the
# backdrop's height less Shrink; their drift: X a share of the glow's own width, Y in px, the scale from / to, seconds
$AkariAuroraGlowSpecs = @(
    @{ Right = $false; X = -0.08; Width = 0.62; Top = -160; Shrink = 180; Opacity = 1.0; DriftX = 0.08; DriftY = 30; ScaleFrom = 1.0; ScaleTo = 1.15; Seconds = 16 }
    @{ Right = $true; X = -0.06; Width = 0.56; Top = -120; Shrink = 220; Opacity = 1.0; DriftX = -0.10; DriftY = 40; ScaleFrom = 1.1; ScaleTo = 0.95; Seconds = 19 }
    @{ Right = $false; X = 0.34; Width = 0.42; Top = 60; Shrink = 320; Opacity = 0.7; DriftX = 0.12; DriftY = -30; ScaleFrom = 1.0; ScaleTo = 1.0; Seconds = 13 }
)
# the ribbons' box (a share of the page wide; px tall), its fade (from a share of its height), the sway's overscan
$AkariAuroraRibbon = @{ Share = 0.64; Height = 230; TallHeight = 340; FadeFrom = 0.4; SwayX = 24; SwayY = 10; Seconds = 9; BreatheFrom = 0.85 }

# the backdrop's height: 640 px on Home (Tall), else 460. Pure.
function Get-AkariAuroraHeight([bool]$Tall) { if ($Tall) { 640 } else { 460 } }

# each glow's size and place for a page $Width px wide: @{ Right; Width; Height; Margin = @(left, top, right, bottom);
# Opacity; DriftX (px); DriftY; ScaleFrom; ScaleTo; Seconds }. Pure.
function Get-AkariAuroraGlows([double]$Width, [bool]$Tall) {
    $h = Get-AkariAuroraHeight $Tall
    foreach ($g in $AkariAuroraGlowSpecs) {
        $w = $g.Width * $Width
        $x = $g.X * $Width
        @{
            Right = $g.Right; Width = $w; Height = $h - $g.Shrink
            Margin = $(if ($g.Right) { @(0, $g.Top, $x, 0) } else { @($x, $g.Top, 0, 0) })
            Opacity = $g.Opacity; DriftX = $g.DriftX * $w; DriftY = $g.DriftY
            ScaleFrom = $g.ScaleFrom; ScaleTo = $g.ScaleTo; Seconds = $g.Seconds
        }
    }
}

# the ribbons' box for a page $Width px wide: @{ Width; Height; FadeFrom; SwayX; SwayY }. Pure.
function Get-AkariAuroraRibbonBox([double]$Width, [bool]$Tall) {
    $r = $AkariAuroraRibbon
    @{ Width = $r.Share * $Width; Height = $(if ($Tall) { $r.TallHeight } else { $r.Height }); FadeFrom = $r.FadeFrom; SwayX = $r.SwayX; SwayY = $r.SwayY }
}

# the layers' opacity for a theme (Dark / Light): the glows 0.55 / 0.32, the ribbons' box 0.8 / 0.55. Pure.
function Get-AkariAuroraOpacity([string]$Theme) {
    if ($Theme -eq 'Light') { @{ Glows = 0.32; Ribbons = 0.55 } } else { @{ Glows = 0.55; Ribbons = 0.8 } }
}

# a page's palette: Home; Install AkariOS = Install; Optimize, its Catalogue pages, the search and the Legacy pages =
# Optimize; Downloads = Downloads, Remove on Windows apps ($Section); Install USB = Usb; ISO Builder = Iso; Settings. Pure.
function Get-AkariPagePalette([string]$Page, [string]$Query = '', [string]$Section = '') {
    switch -Wildcard ($Page) {
        'Home' { 'Home' }
        'Install AkariOS' { 'Install' }
        'Downloads' { if ($Section -eq 'Windows') { 'Remove' } else { 'Downloads' } }
        'Install USB' { 'Usb' }
        'Unattend Generator' { 'Usb' }
        'ISO Builder' { 'Iso' }
        'Settings' { 'Settings' }
        'About' { 'Settings' }
        '' { 'Home' }
        default { 'Optimize' }
    }
}

# the bloom's drawing (the design's 560 x 280 SVG): the corner glow, then the three ribbons as @{ Data (path); Start;
# End (gradient points); Stops = @(@(part, alpha, offset)) (part: Ribbon, RibbonLight or White); Opacity }. Pure.
function Get-AkariRibbonArt {
    @{
        Width = 560; Height = 280
        Glow = @{ Center = @(0.78, 0.2); Radius = 0.6; Stops = @(@('Ribbon', 140, 0), @('Ribbon', 0, 1)) }
        Ribbons = @(
            @{ Data = 'M150,280 C250,200 330,80 560,30 L560,110 C390,130 300,210 260,280 Z'; Start = @(0, 1); End = @(1, 0)
               Stops = @(@('Ribbon', 0, 0), @('Ribbon', 230, 0.55), @('RibbonLight', 255, 1)); Opacity = 1 }
            @{ Data = 'M280,280 C350,215 430,160 560,140 L560,196 C470,205 410,240 380,280 Z'; Start = @(0, 1); End = @(1, 0.2)
               Stops = @(@('RibbonLight', 0, 0), @('RibbonLight', 217, 0.7), @('White', 230, 1)); Opacity = 0.75 }
            @{ Data = 'M200,0 C310,50 440,60 560,0 L560,34 C440,92 300,80 200,0 Z'; Start = @(0, 0); End = @(1, 1)
               Stops = @(@('Ribbon', 0, 0), @('Ribbon', 179, 1)); Opacity = 0.6 }
        )
    }
}

# ---- WPF from here on

# a palette's colour from the theme ($Part: A, B, C, Ribbon, RibbonLight, or White) with $Alpha; looked up on $window
function Get-AkariAuroraColor([string]$Palette, [string]$Part, [int]$Alpha = 255) {
    $key = if ($Part -eq 'White') { 'AuroraWhite' } else { "Aurora$Palette$Part" }
    # the window's resources (a page probe has no window: transparent)
    if ($window -isnot [Windows.FrameworkElement]) { return [Windows.Media.Colors]::Transparent }
    $c = $window.TryFindResource($key)
    if ($c -isnot [Windows.Media.Color]) { $c = $window.TryFindResource("AuroraHome$Part") }
    if ($c -isnot [Windows.Media.Color]) { return [Windows.Media.Colors]::Transparent }
    [Windows.Media.Color]::FromArgb([byte]$Alpha, $c.R, $c.G, $c.B)
}

# the bloom as a brush that covers whatever it fills from its top right corner (SVG's xMaxYMin slice), in $Palette's colours
function New-AkariRibbonBrush([string]$Palette) {
    $art = Get-AkariRibbonArt
    $grad = {
        param($stops, $brush)
        foreach ($s in $stops) { $brush.GradientStops.Add([Windows.Media.GradientStop]::new((Get-AkariAuroraColor $Palette $s[0] $s[1]), $s[2])) }
        $brush
    }
    $g = [Windows.Media.DrawingGroup]::new()
    $glow = [Windows.Media.RadialGradientBrush]::new()
    $glow.Center = [Windows.Point]::new($art.Glow.Center[0], $art.Glow.Center[1]); $glow.GradientOrigin = $glow.Center
    $glow.RadiusX = $art.Glow.Radius; $glow.RadiusY = $art.Glow.Radius
    [void](& $grad $art.Glow.Stops $glow)
    $g.Children.Add([Windows.Media.GeometryDrawing]::new($glow, $null, [Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0, 0, $art.Width, $art.Height))))
    foreach ($r in $art.Ribbons) {
        $b = [Windows.Media.LinearGradientBrush]::new()
        $b.StartPoint = [Windows.Point]::new($r.Start[0], $r.Start[1]); $b.EndPoint = [Windows.Point]::new($r.End[0], $r.End[1])
        [void](& $grad $r.Stops $b)
        $b.Opacity = $r.Opacity
        $g.Children.Add([Windows.Media.GeometryDrawing]::new($b, $null, [Windows.Media.Geometry]::Parse($r.Data)))
    }
    $brush = [Windows.Media.DrawingBrush]::new($g)
    $brush.Viewbox = [Windows.Rect]::new(0, 0, $art.Width, $art.Height); $brush.ViewboxUnits = 'Absolute'
    $brush.Stretch = 'UniformToFill'; $brush.AlignmentX = 'Right'; $brush.AlignmentY = 'Top'
    $brush.Freeze()
    $brush
}

# the fade at the bottom of a bloom: opaque down to $From (a share of the height), transparent at the bottom
function New-AkariFadeMask([double]$From) {
    $m = [Windows.Media.LinearGradientBrush]::new()
    $m.StartPoint = [Windows.Point]::new(0, 0); $m.EndPoint = [Windows.Point]::new(0, 1)
    # an opacity mask reads only the alpha: these are not colours on screen
    $m.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::Black, 0))
    $m.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::Black, $From))
    $m.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Colors]::Transparent, 1))
    $m.Freeze()
    $m
}

$script:AuroraState = $null
# fills MainWindow.xaml's Aurora grid: the glows, then the ribbons' box (still, faded at its bottom by an opacity mask,
# clipped) holding the host that breathes, holding the drawing that sways inside the overscan. Once, by UI\Shell.ps1.
# a $Width x $Height box whose top left corner is rounded by $Radius, the rest square: the content layer's inside
# (its 8 px corner less the 1 px edge). ClipToBounds ignores a Border's CornerRadius, so the light needs its own clip
function New-AkariCornerClip([double]$Width, [double]$Height, [double]$Radius = 7) {
    $f = [Windows.Media.PathFigure]::new(); $f.StartPoint = [Windows.Point]::new(0, $Radius); $f.IsClosed = $true
    $f.Segments.Add([Windows.Media.ArcSegment]::new([Windows.Point]::new($Radius, 0), [Windows.Size]::new($Radius, $Radius), 0, $false, 'Clockwise', $true))
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new($Width, 0), $true))
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new($Width, $Height), $true))
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new(0, $Height), $true))
    $g = [Windows.Media.PathGeometry]::new(); $g.Figures.Add($f)
    $g.Freeze()
    $g
}

function New-AkariAurora($Root) {
    $Root.Children.Clear()
    $Root.IsHitTestVisible = $false
    $Root.VerticalAlignment = 'Top'
    $glows = [Windows.Controls.Grid]::new()
    foreach ($i in 0..($AkariAuroraGlowSpecs.Count - 1)) {
        $e = [Windows.Shapes.Ellipse]::new()
        $e.VerticalAlignment = 'Top'
        $e.HorizontalAlignment = if ($AkariAuroraGlowSpecs[$i].Right) { 'Right' } else { 'Left' }
        $e.Opacity = $AkariAuroraGlowSpecs[$i].Opacity
        [void](Get-AkariMotionTransform $e)
        [void]$glows.Children.Add($e)
    }
    $box = [Windows.Controls.Grid]::new()
    $box.HorizontalAlignment = 'Right'; $box.VerticalAlignment = 'Top'; $box.ClipToBounds = $true
    $box.OpacityMask = New-AkariFadeMask $AkariAuroraRibbon.FadeFrom
    $hostGrid = [Windows.Controls.Grid]::new()
    $art = [Windows.Shapes.Rectangle]::new()
    # the drawing hangs past the box's right edge and above its top: the sway's room, so no edge ever shows
    $art.Margin = [Windows.Thickness]::new(0, -$AkariAuroraRibbon.SwayY, -$AkariAuroraRibbon.SwayX, 0)
    $art.RenderTransform = [Windows.Media.TranslateTransform]::new()
    [void]$hostGrid.Children.Add($art)
    [void]$box.Children.Add($hostGrid)
    [void]$Root.Children.Add($glows)
    [void]$Root.Children.Add($box)
    $script:AuroraState = @{ Root = $Root; Glows = $glows; Box = $box; Host = $hostGrid; Art = $art; Palette = ''; Tall = $false; Width = 0; Page = $null; Moving = $false }
    $Root.Add_SizeChanged({
        param($s, $e)
        # the light stays inside the layer's rounded top left corner
        $s.Clip = New-AkariCornerClip $e.NewSize.Width $e.NewSize.Height
        if ($e.WidthChanged) { Update-AkariAuroraSize $e.NewSize.Width }
    })
    # high contrast: no decoration, followed live
    [Windows.SystemParameters]::add_StaticPropertyChanged([ComponentModel.PropertyChangedEventHandler]{
        param($s, $e) if ($e.PropertyName -eq 'HighContrast') { Update-AkariAuroraContrast }
    })
    Update-AkariAuroraContrast
}

# the light for a page: its palette's colours (made again only when the palette changes), Home's taller banner, a fade in
# when the page or its palette changes (not for another step of the same page)
function Set-AkariAuroraPalette([string]$Name, [bool]$Tall = $false, [string]$Page = '') {
    $a = $script:AuroraState
    if (-not $a) { return }
    if ($Name -notin $AkariAuroraPalettes) { $Name = 'Home' }
    $fade = ($Page -ne $a.Page) -or ($Name -ne $a.Palette)
    $a.Page = $Page
    if ($Name -ne $a.Palette) {
        $a.Palette = $Name
        $parts = 'A', 'B', 'C'
        for ($i = 0; $i -lt $a.Glows.Children.Count; $i++) {
            $b = [Windows.Media.RadialGradientBrush]::new((Get-AkariAuroraColor $Name $parts[$i] 255), (Get-AkariAuroraColor $Name $parts[$i] 0))
            $b.Freeze()
            $a.Glows.Children[$i].Fill = $b
        }
        $a.Art.Fill = New-AkariRibbonBrush $Name
    }
    if ($Tall -ne $a.Tall -or -not $a.Width) {
        $a.Tall = $Tall
        Update-AkariAuroraSize $(if ($a.Root.ActualWidth -gt 0) { $a.Root.ActualWidth } else { $a.Width }) $true
    }
    Update-AkariAuroraTheme
    if ($fade -and $a.Root.Visibility -eq 'Visible') { Start-AkariFadeIn $a.Root 1.2 }
}

# the sizes for a page $Width px wide (the content layer's), and the drift worked out again for them
function Update-AkariAuroraSize([double]$Width, [bool]$Force = $false) {
    $a = $script:AuroraState
    if (-not $a -or $Width -le 0) { return }
    if (-not $Force -and [Math]::Abs($Width - $a.Width) -lt 1) { return }
    $a.Width = $Width
    $a.Root.Height = Get-AkariAuroraHeight $a.Tall
    $specs = @(Get-AkariAuroraGlows $Width $a.Tall)
    for ($i = 0; $i -lt $specs.Count; $i++) {
        $e = $a.Glows.Children[$i]; $g = $specs[$i]
        $e.Width = $g.Width; $e.Height = $g.Height
        $e.Margin = [Windows.Thickness]::new($g.Margin[0], $g.Margin[1], $g.Margin[2], $g.Margin[3])
    }
    $r = Get-AkariAuroraRibbonBox $Width $a.Tall
    $a.Box.Width = $r.Width; $a.Box.Height = $r.Height
    Start-AkariAuroraMotion
}

# the glows drift, the ribbons sway and breathe, each forever and back (UI\Motion.ps1); not while hidden, nothing with
# motion off or in software rendering (WPF's render tier 0, where every frame is drawn by the CPU)
function Start-AkariAuroraMotion {
    $a = $script:AuroraState
    if (-not $a) { return }
    $on = $script:AkariMotionOn -and $a.Root.Visibility -eq 'Visible' -and $a.Width -gt 0 -and ([Windows.Media.RenderCapability]::Tier -shr 16) -gt 0
    $specs = @(Get-AkariAuroraGlows $a.Width $a.Tall)
    for ($i = 0; $i -lt $a.Glows.Children.Count; $i++) {
        $tg = Get-AkariMotionTransform $a.Glows.Children[$i]
        $sc = $tg.Children[-2]; $tr = $tg.Children[-1]
        if ($on) {
            $g = $specs[$i]
            Start-AkariDrift $tr ([Windows.Media.TranslateTransform]::XProperty) 0 $g.DriftX $g.Seconds
            Start-AkariDrift $tr ([Windows.Media.TranslateTransform]::YProperty) 0 $g.DriftY $g.Seconds
            Start-AkariDrift $sc ([Windows.Media.ScaleTransform]::ScaleXProperty) $g.ScaleFrom $g.ScaleTo $g.Seconds
            Start-AkariDrift $sc ([Windows.Media.ScaleTransform]::ScaleYProperty) $g.ScaleFrom $g.ScaleTo $g.Seconds
        } else {
            foreach ($p in [Windows.Media.TranslateTransform]::XProperty, [Windows.Media.TranslateTransform]::YProperty) { Stop-AkariDrift $tr $p }
            foreach ($p in [Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.ScaleTransform]::ScaleYProperty) { Stop-AkariDrift $sc $p }
        }
    }
    $r = $AkariAuroraRibbon
    if ($on) {
        Start-AkariDrift $a.Art.RenderTransform ([Windows.Media.TranslateTransform]::XProperty) 0 (-$r.SwayX) $r.Seconds
        Start-AkariDrift $a.Art.RenderTransform ([Windows.Media.TranslateTransform]::YProperty) 0 $r.SwayY $r.Seconds
        Start-AkariDrift $a.Host ([Windows.UIElement]::OpacityProperty) $r.BreatheFrom 1 $r.Seconds
    } else {
        Stop-AkariDrift $a.Art.RenderTransform ([Windows.Media.TranslateTransform]::XProperty)
        Stop-AkariDrift $a.Art.RenderTransform ([Windows.Media.TranslateTransform]::YProperty)
        Stop-AkariDrift $a.Host ([Windows.UIElement]::OpacityProperty)
    }
    $a.Moving = $on
}

# the layers' opacity for the current theme ($script:Theme, UI\Shell.ps1); Set-AkariTheme calls it
function Update-AkariAuroraTheme {
    $a = $script:AuroraState
    if (-not $a) { return }
    $o = Get-AkariAuroraOpacity $script:Theme
    $a.Glows.Opacity = $o.Glows
    $a.Box.Opacity = $o.Ribbons
    # the pane logo's glow (the native app's AkariGlowOpacity): 0.33 dark, 0.25 light
    $glow = if ($window -is [Windows.FrameworkElement]) { $window.FindName('LogoGlow') }
    if ($glow) { $glow.Opacity = if ($script:Theme -eq 'Light') { 0.25 } else { 0.33 } }
}

# high contrast (SystemParameters.HighContrast): the light gone, the glass on the system's window and text colours (keys
# in the window's own resources win over the theme dictionary); back again when it ends
function Update-AkariAuroraContrast {
    $a = $script:AuroraState
    $hc = [bool][Windows.SystemParameters]::HighContrast
    if ($window) {
        # the nav icons' colours too (Shell.ps1's $AkariNavColors): the system's text colour
        $navKeys = 'NavHome', 'NavInstall', 'NavOptimize', 'NavDownloads', 'NavUsb', 'NavIso', 'NavSettings'
        if ($hc) {
            $window.Resources['Glass'] = [Windows.SystemColors]::WindowBrush
            $window.Resources['GlassStroke'] = [Windows.SystemColors]::WindowTextBrush
            foreach ($k in $navKeys) { $window.Resources[$k] = [Windows.SystemColors]::WindowTextBrush }
        } else { foreach ($k in @('Glass', 'GlassStroke') + $navKeys) { if ($window.Resources.Contains($k)) { $window.Resources.Remove($k) } } }
        # the pane logo's glow: none in high contrast
        $glow = $window.FindName('LogoGlow')
        if ($glow) { $glow.Visibility = if ($hc) { 'Collapsed' } else { 'Visible' } }
    }
    if (-not $a) { return }
    $a.Root.Visibility = if ($hc) { 'Collapsed' } else { 'Visible' }
    Start-AkariAuroraMotion
}

# the bloom in a featured card's corner (Install AkariOS' and Home's One-click tiles): the drawing in a $Width x $Height
# box at the top right at 70 %, faded out from 20 % of its height, still, its corner rounded as the card's inside
# ($Radius = the card's 8 less its 1 px border); takes no room (put it first in the card's Grid, the content over it).
# High contrast: collapsed.
function New-AkariBloom([string]$Palette = 'Home', [double]$Width = 360, [double]$Height = 180, [double]$Radius = 7) {
    $r = [Windows.Shapes.Rectangle]::new()
    $r.Width = $Width; $r.Height = $Height
    $r.HorizontalAlignment = 'Right'; $r.VerticalAlignment = 'Top'
    $r.IsHitTestVisible = $false
    $r.Opacity = 0.7
    $r.Fill = New-AkariRibbonBrush $Palette
    $r.OpacityMask = New-AkariFadeMask 0.2
    # only the top right corner meets the card's: rounded as its inside
    $f = [Windows.Media.PathFigure]::new(); $f.StartPoint = [Windows.Point]::new(0, 0); $f.IsClosed = $true
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new($Width - $Radius, 0), $true))
    $f.Segments.Add([Windows.Media.ArcSegment]::new([Windows.Point]::new($Width, $Radius), [Windows.Size]::new($Radius, $Radius), 0, $false, 'Clockwise', $true))
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new($Width, $Height), $true))
    $f.Segments.Add([Windows.Media.LineSegment]::new([Windows.Point]::new(0, $Height), $true))
    $clip = [Windows.Media.PathGeometry]::new(); $clip.Figures.Add($f)
    $r.Clip = $clip
    if ([Windows.SystemParameters]::HighContrast) { $r.Visibility = 'Collapsed' }
    $r
}
