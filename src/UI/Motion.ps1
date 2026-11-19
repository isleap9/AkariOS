# Motion (plans docs/plans/2026-10-31-motion-polish.md and 2026-11-19-winui-3.md decision 9): the tokens in UI\Motion.xaml, the XAML loader that puts them
# into every file it parses (Get-AkariXaml), and Start-AkariMotion, the only code that starts an animation.
# Dot-sourced first of the UI files by Akari.ps1. Pure helpers first (tests dot-source this file).

$AkariMotionKinds = @('Fade', 'Rise', 'Pop', 'Scale', 'Slide', 'SlideY', 'Fill', 'Width', 'Height')

# Motion.xaml's entries (the text between its root tags); $On = $false writes every Duration and KeyTime as 0:0:0
function Get-AkariMotionEntries([string]$MotionXaml, [bool]$On = $true) {
    $m = [regex]::Match($MotionXaml, '(?s)<ResourceDictionary\b[^>]*>(.*)</ResourceDictionary>')
    if (-not $m.Success) { throw 'Motion.xaml has no ResourceDictionary' }
    $e = $m.Groups[1].Value
    if (-not $On) { $e = [regex]::Replace($e, '(<(Duration|KeyTime)\b[^>]*>)[^<]*(</\2>)', '${1}0:0:0${3}') }
    $e
}

# the XAML text with the motion entries put first into its resources: the root ResourceDictionary, or the first
# <X.Resources> element (MainWindow.xaml's Window.Resources); a file with neither is returned as it is
function Add-AkariMotionXaml([string]$Xaml, [string]$Entries) {
    $m = [regex]::Match($Xaml, '<ResourceDictionary\b[^>]*[^/]>|<\w+\.Resources>')
    if (-not $m.Success) { return $Xaml }
    $Xaml.Insert($m.Index + $m.Length, $Entries)
}

# Windows' "Animation effects" (Settings > Accessibility > Visual effects); $env:AKARI_MOTION = on / off overrides it
function Test-AkariMotionOn {
    if ($env:AKARI_MOTION -eq 'off') { return $false }
    if ($env:AKARI_MOTION -eq 'on') { return $true }
    try { [bool][Windows.SystemParameters]::ClientAreaAnimation } catch { $true }
}

# what Start-AkariMotion animates for a kind: @{ Property = Opacity|ScaleX|ScaleY|X|Y; From; To }
# (Fade: opacity; Rise: opacity and Y from 10 px below; Pop: opacity and scale from 0.96; Scale / Slide: scale or X only;
# Fill: the width scale alone, a bar that grows from its RenderTransformOrigin; SlideY: Y only; Width / Height: the
# element's own size, only for a small absolutely placed element (it lays out again each frame): the segmented pill)
function Get-AkariMotionPlan([string]$Kind, $From = $null, $To = $null) {
    switch ($Kind) {
        'Fade'  { @(@{ Property = 'Opacity'; From = $(if ($null -ne $From) { $From } else { 0 }); To = $(if ($null -ne $To) { $To } else { 1 }) }) }
        'Rise'  { @(@{ Property = 'Opacity'; From = 0; To = 1 }, @{ Property = 'Y'; From = $(if ($null -ne $From) { $From } else { 10 }); To = $(if ($null -ne $To) { $To } else { 0 }) }) }
        'Pop'   { $f = if ($null -ne $From) { $From } else { 0.96 }; $t = if ($null -ne $To) { $To } else { 1 }
                  @(@{ Property = 'Opacity'; From = 0; To = 1 }, @{ Property = 'ScaleX'; From = $f; To = $t }, @{ Property = 'ScaleY'; From = $f; To = $t }) }
        'Scale' { $t = if ($null -ne $To) { $To } else { 1 }
                  @(@{ Property = 'ScaleX'; From = $From; To = $t }, @{ Property = 'ScaleY'; From = $From; To = $t }) }
        'Slide' { @(@{ Property = 'X'; From = $From; To = $(if ($null -ne $To) { $To } else { 0 }) }) }
        'Fill'  { @(@{ Property = 'ScaleX'; From = $From; To = $(if ($null -ne $To) { $To } else { 1 }) }) }
        'SlideY' { @(@{ Property = 'Y'; From = $From; To = $(if ($null -ne $To) { $To } else { 0 }) }) }
        'Width'  { @(@{ Property = 'Width'; From = $From; To = $To }) }
        'Height' { @(@{ Property = 'Height'; From = $From; To = $To }) }
        default { throw "Unknown motion kind '$Kind' (one of $($AkariMotionKinds -join ', '))" }
    }
}

# ---- WPF from here on (read once WPF is loaded; without it only the pure helpers above are usable)

$script:AkariMotionOn = Test-AkariMotionOn
$script:AkariMotionText = Get-AkariMotionEntries (Get-Content "$PSScriptRoot\Motion.xaml" -Raw) $script:AkariMotionOn
# the tokens as objects (Duration, easing), for Start-AkariMotion
$AkariMotion = if ('Windows.Markup.XamlReader' -as [type]) {
    [Windows.Markup.XamlReader]::Parse('<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ' +
        'xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">' + $script:AkariMotionText + '</ResourceDictionary>')
}

# a UI XAML file, parsed, with the motion tokens in its resources: every XAML file goes through this
function Get-AkariXaml([string]$Path) {
    [Windows.Markup.XamlReader]::Parse((Add-AkariMotionXaml (Get-Content $Path -Raw) $script:AkariMotionText))
}

# the element's TransformGroup holding Akari's ScaleTransform and TranslateTransform (made once, around any transform
# it already had; centred unless the element names its own RenderTransformOrigin)
function Get-AkariMotionTransform($Element) {
    $g = $Element.RenderTransform
    if ($g -is [Windows.Media.TransformGroup] -and $g.Children.Count -ge 2 -and $g.Children[-2] -is [Windows.Media.ScaleTransform] -and
        $g.Children[-1] -is [Windows.Media.TranslateTransform] -and -not $g.IsFrozen) { return $g }
    $n = [Windows.Media.TransformGroup]::new()
    if ($g -and -not $g.Value.IsIdentity) { $n.Children.Add($g) }
    $n.Children.Add([Windows.Media.ScaleTransform]::new())
    $n.Children.Add([Windows.Media.TranslateTransform]::new())
    if ($Element.RenderTransformOrigin -eq [Windows.Point]::new(0, 0)) { $Element.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5) }
    $Element.RenderTransform = $n
    $n
}

# animates an element: Fade, Rise, Pop, Scale or Slide (Get-AkariMotionPlan), over Motion.Fast / Base / Slow, after
# -Delay (a TimeSpan, e.g. n x Motion.Stagger). Each value is set to its end first and the animation stops there
# (FillBehavior Stop), so code that sets it later is never overridden. Motion off = the end values, no animation.
function Start-AkariMotion($Element, [string]$Kind, $From = $null, $To = $null, [string]$Speed = 'Base', [TimeSpan]$Delay = [TimeSpan]::Zero, [string]$Easing = 'Ease') {
    if (-not $Element) { return }
    $plan = Get-AkariMotionPlan $Kind $From $To
    $tg = if (@($plan | Where-Object { $_.Property -notin 'Opacity', 'Width', 'Height' }).Count) { Get-AkariMotionTransform $Element }
    $dur = $AkariMotion["Motion.$Speed"]
    $ease = $AkariMotion["Motion.$Easing"]
    foreach ($p in $plan) {
        $target, $dp = switch ($p.Property) {
            'Opacity' { $Element, [Windows.UIElement]::OpacityProperty }
            'Width'   { $Element, [Windows.FrameworkElement]::WidthProperty }
            'Height'  { $Element, [Windows.FrameworkElement]::HeightProperty }
            'ScaleX'  { $tg.Children[-2], [Windows.Media.ScaleTransform]::ScaleXProperty }
            'ScaleY'  { $tg.Children[-2], [Windows.Media.ScaleTransform]::ScaleYProperty }
            'X'       { $tg.Children[-1], [Windows.Media.TranslateTransform]::XProperty }
            'Y'       { $tg.Children[-1], [Windows.Media.TranslateTransform]::YProperty }
        }
        # no From = from where it is now (mid-animation too), read before the end value is set
        $from = if ($null -ne $p.From) { [double]$p.From } else { [double]$target.GetValue($dp) }
        $target.SetValue($dp, [double]$p.To)
        if (-not $script:AkariMotionOn -or $dur.TimeSpan -le [TimeSpan]::Zero -or $from -eq [double]$p.To) { $target.BeginAnimation($dp, $null); continue }
        # key frames: the start value held through the delay (a BeginTime would show the end value until then)
        $a = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
        [void]$a.KeyFrames.Add([Windows.Media.Animation.DiscreteDoubleKeyFrame]::new($from, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::Zero)))
        if ($Delay -gt [TimeSpan]::Zero) {
            [void]$a.KeyFrames.Add([Windows.Media.Animation.DiscreteDoubleKeyFrame]::new($from, [Windows.Media.Animation.KeyTime]::FromTimeSpan($Delay)))
        }
        [void]$a.KeyFrames.Add([Windows.Media.Animation.SplineDoubleKeyFrame]::new([double]$p.To, [Windows.Media.Animation.KeyTime]::FromTimeSpan($Delay + $dur.TimeSpan), $ease))
        $a.FillBehavior = 'Stop'
        $target.BeginAnimation($dp, $a)
    }
}

# an element that comes in once it is built: hidden now, its entrance played when the dispatcher reaches Loaded
# priority (after the build and the first layout, so the first frame shows the start, not a half-built page). Kind:
# Rise, Fade, Pop, or Slide (a fade plus a slide from -From px). If the entrance fails the element is shown at once;
# motion off = nothing is hidden or played.
function Start-AkariEntrance($Element, [string]$Kind = 'Rise', $From = $null, [string]$Speed = 'Slow', [TimeSpan]$Delay = [TimeSpan]::Zero) {
    if (-not $Element -or -not $script:AkariMotionOn) { return }
    $Element.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
    $Element.Opacity = 0
    $state = @{ Element = $Element; Kind = $Kind; From = $From; Speed = $Speed; Delay = $Delay }
    [void]$Element.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Loaded, [Action[object]]{
        param($s)
        try {
            if ($s.Kind -eq 'Slide') {
                Start-AkariMotion $s.Element Fade -Speed $s.Speed -Delay $s.Delay
                Start-AkariMotion $s.Element Slide $s.From 0 -Speed $s.Speed -Delay $s.Delay
            } else { Start-AkariMotion $s.Element $s.Kind $s.From -Speed $s.Speed -Delay $s.Delay }
        } catch { $s.Element.Opacity = 1 }
    }, $state)
}

# the first $Max elements come in one after another, Motion.Stagger apart (the rest at once): cards on a page
function Start-AkariStagger($Elements, [int]$Max = 12, [string]$Kind = 'Rise', $From = 28, [string]$Speed = 'Page') {
    if (-not $script:AkariMotionOn) { return }
    $gap = $AkariMotion['Motion.Stagger'].TimeSpan
    $n = 0
    foreach ($e in @($Elements)) {
        if ($n -ge $Max) { break }
        if ($e -isnot [Windows.UIElement] -or $e.Visibility -ne 'Visible') { continue }
        Start-AkariEntrance $e $Kind $From $Speed -Delay ([TimeSpan]::FromTicks($gap.Ticks * $n))
        $n++
    }
}

# the delay of a page's child $Index (0-based) as it comes in: children 1 to 5 Motion.Stagger apart, the rest with the
# sixth (the prototype's .enter > *:nth-child(n): 0, 30, 60, 90, 120, then 150 ms). Pure.
function Get-AkariEntranceDelay([int]$Index, [double]$Gap = 30) { [Math]::Min($Index, 5) * $Gap }

# a new page: each of its visible top-level children ($Elements, in order) fades in and rises from 28 px over
# Motion.Page, staggered (Get-AkariEntranceDelay), on the decelerate curve
function Start-AkariPageEntrance($Elements) {
    if (-not $script:AkariMotionOn) { return }
    $gap = $AkariMotion['Motion.Stagger'].TimeSpan.TotalMilliseconds
    $i = 0
    foreach ($e in @($Elements)) {
        if ($e -isnot [Windows.UIElement] -or $e.Visibility -ne 'Visible') { continue }
        Start-AkariEntrance $e Rise 28 Page -Delay ([TimeSpan]::FromMilliseconds((Get-AkariEntranceDelay $i $gap)))
        $i++
    }
}

# WinUI's decelerate curve cubic-bezier(0,0,0,1) at time $T (0..1): x = s^3, y = 3s^2 - 2s^3. Pure.
function Get-AkariEaseValue([double]$T) {
    if ($T -le 0) { return 0 } elseif ($T -ge 1) { return 1 }
    $s = [Math]::Pow($T, 1 / 3)
    3 * $s * $s - 2 * $s * $s * $s
}

# the nav indicator's path from $From to $To (its top, px) over the prototype's 300 ms: @(@{ T; Y; Scale }), $Steps
# samples. It stretches over both items (|d| + 16 px tall at the halfway point, the old item's edge kept), then shrinks
# onto the new one; the whole move on cubic-bezier(0,0,0,1), as the prototype's keyframes eased as one. Pure.
function Get-AkariPillPath([double]$From, [double]$To, [int]$Steps = 24, [double]$Height = 16) {
    $d = $To - $From
    $grow = ([Math]::Abs($d) + $Height) / $Height
    foreach ($i in 0..$Steps) {
        $t = $i / $Steps
        $p = Get-AkariEaseValue $t
        if ($d -ge 0) {
            # down: the top stays on the old item while it grows, then slides to the new one as it shrinks
            $y = if ($p -le 0.5) { $From } else { $From + $d * ($p - 0.5) * 2 }
        } else {
            # up: the top slides to the new item while it grows, the bottom stays on the old one
            $y = if ($p -le 0.5) { $From + $d * $p * 2 } else { $To }
        }
        $sc = if ($p -le 0.5) { 1 + ($grow - 1) * $p * 2 } else { $grow - ($grow - 1) * ($p - 0.5) * 2 }
        @{ T = $t; Y = $y; Scale = $sc }
    }
}

# moves the nav indicator ($Pill: a 16 px Border in a Canvas, TransformGroup [ScaleTransform, TranslateTransform],
# origin at its top) to $Y: the stretch above over 300 ms, or a jump (first placement, motion off, -not $Animate)
function Move-AkariNavPill($Pill, [double]$Y, [bool]$Animate = $true) {
    $tg = $Pill.RenderTransform
    $sc = $tg.Children[0]; $tr = $tg.Children[1]
    $from = [double]$tr.Y
    $jump = (-not $Animate -or -not $script:AkariMotionOn -or $Pill.Visibility -ne 'Visible' -or [Math]::Abs($from - $Y) -lt 1)
    $Pill.Visibility = 'Visible'
    $tr.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null); $sc.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $null)
    $tr.Y = $Y; $sc.ScaleY = 1
    if ($jump) { return }
    $ay = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new(); $as = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    foreach ($k in Get-AkariPillPath $from $Y) {
        $kt = [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds(300 * $k.T))
        [void]$ay.KeyFrames.Add([Windows.Media.Animation.LinearDoubleKeyFrame]::new($k.Y, $kt))
        [void]$as.KeyFrames.Add([Windows.Media.Animation.LinearDoubleKeyFrame]::new($k.Scale, $kt))
    }
    $ay.FillBehavior = 'Stop'; $as.FillBehavior = 'Stop'
    $tr.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $ay)
    $sc.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $as)
}

# a SelectorBar's underline (a 16 x 3 Border in a Canvas under the items, .selbar .ul): centred under $Target, sliding
# there over Motion.Slow, or jumping on its first placement. $true when placed
function Move-AkariUnderline($Line, $Target, [bool]$Animate = $true) {
    if (-not $Target -or $Target.ActualWidth -le 0) { return $false }
    $p = $Target.TranslatePoint([Windows.Point]::new(0, 0), $Line.Parent)
    $x = $p.X + $Target.ActualWidth / 2 - 8
    $jump = -not $Animate -or $Line.Visibility -ne 'Visible'
    $Line.Visibility = 'Visible'
    Start-AkariMotion $Line Slide $(if ($jump) { $x }) $x -Speed Slow
    $true
}

# ADR 0008's three animated sizes (the nav pane's width, an expander's body, an InfoBar): $Element's Height (or Width)
# from where it is to $To over $Speed on the decelerate curve, then handed back: $To = 'Auto' measures the content first
# and ends on Auto (NaN). -Fade takes Opacity along (an InfoBar). Motion off, or not shown yet = the end at once.
function Set-AkariSize($Element, [string]$Axis = 'Height', $To = 'Auto', [string]$Speed = 'Base', [switch]$Fade) {
    if (-not $Element) { return }
    $dp = if ($Axis -eq 'Width') { [Windows.FrameworkElement]::WidthProperty } else { [Windows.FrameworkElement]::HeightProperty }
    $now = if ($Axis -eq 'Width') { $Element.ActualWidth } else { $Element.ActualHeight }
    $auto = ($To -eq 'Auto')
    $end = if ($auto) {
        $Element.BeginAnimation($dp, $null); $Element.SetValue($dp, [double]::NaN)
        $w = if ($Element.Parent -is [Windows.FrameworkElement] -and $Element.Parent.ActualWidth -gt 0) { $Element.Parent.ActualWidth } else { [double]::PositiveInfinity }
        $Element.Measure([Windows.Size]::new($w, [double]::PositiveInfinity))
        if ($Axis -eq 'Width') { $Element.DesiredSize.Width } else { $Element.DesiredSize.Height }
    } else { [double]$To }
    if (-not $script:AkariMotionOn -or -not $Element.IsLoaded -or [Math]::Abs($now - $end) -lt 0.5) {
        $Element.BeginAnimation($dp, $null)
        $Element.SetValue($dp, $(if ($auto) { [double]::NaN } else { $end }))
        if ($Fade) { $Element.BeginAnimation([Windows.UIElement]::OpacityProperty, $null); $Element.Opacity = $(if ($end -gt 0) { 1 } else { 0 }) }
        return
    }
    Start-AkariMotion $Element $Axis $now $end -Speed $Speed
    if ($Fade) { Start-AkariMotion $Element Fade $Element.Opacity $(if ($end -gt 0) { 1 } else { 0 }) -Speed $Speed }
    if ($auto) {
        # the animation stops on the measured height; Auto again after it, so the content can grow
        $tm = [Windows.Threading.DispatcherTimer]::new()
        $tm.Interval = $AkariMotion["Motion.$Speed"].TimeSpan
        $tm.Tag = @{ Element = $Element; Dp = $dp }
        $tm.Add_Tick({ param($s, $e) $s.Stop(); $s.Tag.Element.BeginAnimation($s.Tag.Dp, $null); $s.Tag.Element.SetValue($s.Tag.Dp, [double]::NaN) })
        $tm.Start()
    }
}

# a bar or overlay that appears: made Visible and played in (Rise from $From px, or Fade with $From = $null) only when
# it was not visible; a hide still pending on it is called off
$script:AkariHiding = @{}
function Show-AkariElement($Element, $From = -8, [string]$Speed = 'Base') {
    if (-not $Element) { return }
    $k = $Element.GetHashCode()
    if ($script:AkariHiding[$k]) { $script:AkariHiding[$k].Stop(); $script:AkariHiding.Remove($k); $Element.IsHitTestVisible = $true; $Element.Visibility = 'Hidden' }
    if ($Element.Visibility -eq 'Visible') { return }
    $Element.Visibility = 'Visible'
    if ($null -eq $From) { Start-AkariMotion $Element Fade -Speed $Speed } else { Start-AkariMotion $Element Rise $From -Speed $Speed }
}

# fades an element out, then collapses it; it stops taking clicks at once. Motion off = collapsed at once
function Hide-AkariElement($Element, [string]$Speed = 'Fast') {
    if (-not $Element -or $Element.Visibility -ne 'Visible') { return }
    $k = $Element.GetHashCode()
    if ($script:AkariHiding[$k]) { return }
    if (-not $script:AkariMotionOn) { $Element.Visibility = 'Collapsed'; return }
    $Element.IsHitTestVisible = $false
    Start-AkariMotion $Element Fade $Element.Opacity 0 -Speed $Speed
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = $AkariMotion["Motion.$Speed"].TimeSpan
    $tm.Tag = @{ Element = $Element; Key = $k }
    $script:AkariHiding[$k] = $tm
    $tm.Add_Tick({
        param($s, $e)
        $s.Stop()
        $x = $s.Tag
        $script:AkariHiding.Remove($x.Key)
        $x.Element.Visibility = 'Collapsed'; $x.Element.Opacity = 1; $x.Element.IsHitTestVisible = $true
    })
    $tm.Start()
}

# a number at time $T (0..1) of a count from $From to $To, eased out (cubic): Start-AkariCount's steps
function Get-AkariCountValue([double]$From, [double]$To, [double]$T) {
    $T = [Math]::Max([double]0, [Math]::Min([double]1, $T))
    [Math]::Round($From + ($To - $From) * (1 - [Math]::Pow(1 - $T, 3)))
}

# a TextBlock's number counts up (or down) to $Value over two Motion.Slow, from the number it shows (0 if none),
# formatted with $Format; motion off = the number at once
$script:AkariCounts = @{}
function Start-AkariCount($Text, [int]$Value, [string]$Format = '{0:N0}') {
    if (-not $Text) { return }
    $k = $Text.GetHashCode()
    if ($script:AkariCounts[$k]) { $script:AkariCounts[$k].Stop(); $script:AkariCounts.Remove($k) }
    $from = 0
    [void][int]::TryParse(($Text.Text -replace '[^\d]', ''), [ref]$from)
    if (-not $script:AkariMotionOn -or $from -eq $Value) { $Text.Text = $Format -f $Value; return }
    $tm = [Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Render)
    $tm.Interval = [TimeSpan]::FromMilliseconds(16)
    $tm.Tag = @{ Text = $Text; Key = $k; From = $from; To = $Value; Format = $Format; Start = [DateTime]::UtcNow
                 Length = 2 * $AkariMotion['Motion.Slow'].TimeSpan.TotalMilliseconds }
    $script:AkariCounts[$k] = $tm
    $tm.Add_Tick({
        param($s, $e)
        $c = $s.Tag
        $t = ([DateTime]::UtcNow - $c.Start).TotalMilliseconds / $c.Length
        $c.Text.Text = $c.Format -f [int](Get-AkariCountValue $c.From $c.To $t)
        if ($t -ge 1) { $s.Stop(); $script:AkariCounts.Remove($c.Key) }
    })
    $tm.Start()
}

# ---- smooth scrolling: a wheel notch moves a target offset and the viewer glides to it (eased, time-based, on
# CompositionTarget.Rendering only while gliding). Touchpads (deltas that are not whole notches) and inner scrollable
# parts (a list, a multi-line text box) keep WPF's own scrolling.

# the next target offset for a wheel delta: Windows' wheel lines (16 px each) per notch, kept inside 0..max
function Get-AkariScrollTarget([double]$Target, [int]$Delta, [double]$Max, [int]$Lines = 3) {
    [Math]::Max([double]0, [Math]::Min($Max, $Target - ($Delta / 120.0) * $Lines * 16))
}

# one frame of the glide: the offset after $Ms milliseconds, closing on the target exponentially (~50 ms half-way,
# settled in about a third of a second), the target itself once within half a pixel
function Get-AkariScrollStep([double]$Offset, [double]$Target, [double]$Ms) {
    $next = $Target + ($Offset - $Target) * [Math]::Exp(-[Math]::Max([double]0, $Ms) / 72.0)
    if ([Math]::Abs($Target - $next) -lt 0.5) { $Target } else { $next }
}

$script:AkariScrolls = @{}
$script:AkariScrollLast = $null
$script:AkariScrollTick = [EventHandler]{
    param($s, $e)
    $now = [DateTime]::UtcNow
    $ms = if ($script:AkariScrollLast) { ($now - $script:AkariScrollLast).TotalMilliseconds } else { 16 }
    $script:AkariScrollLast = $now
    foreach ($k in @($script:AkariScrolls.Keys)) {
        $st = $script:AkariScrolls[$k]
        if (-not $st.Active) { continue }
        $v = $st.Viewer
        $st.Target = [Math]::Min($st.Target, $v.ScrollableHeight)
        $next = Get-AkariScrollStep $v.VerticalOffset $st.Target $ms
        $v.ScrollToVerticalOffset($next)
        if ($next -eq $st.Target) { $st.Active = $false }
    }
    if (-not @($script:AkariScrolls.Values | Where-Object { $_.Active }).Count) {
        [Windows.Media.CompositionTarget]::remove_Rendering($script:AkariScrollTick)
        $script:AkariScrollLast = $null
    }
}

# makes a ScrollViewer glide on the wheel (motion off: left as it is)
function Enable-AkariSmoothScroll($Viewer) {
    if (-not $Viewer -or -not $script:AkariMotionOn) { return }
    $script:AkariScrolls[$Viewer.GetHashCode()] = @{ Viewer = $Viewer; Target = 0.0; Active = $false }
    $Viewer.Add_PreviewMouseWheel({
        param($s, $e)
        if ($e.Handled -or $e.Delta % 120 -ne 0) { return }
        # an inner part that scrolls itself (between the mouse and this viewer) keeps the wheel
        $p = $e.OriginalSource
        while ($p -and $p -ne $s) {
            if ($p -is [Windows.Controls.ScrollViewer] -and $p.ScrollableHeight -gt 0) { return }
            $p = if ($p -is [Windows.Media.Visual]) { [Windows.Media.VisualTreeHelper]::GetParent($p) } else { $null }
        }
        $st = $script:AkariScrolls[$s.GetHashCode()]
        if (-not $st -or $s.ScrollableHeight -le 0) { return }
        if (-not $st.Active) { $st.Target = $s.VerticalOffset }
        $lines = [Math]::Max(1, [Windows.SystemParameters]::WheelScrollLines)
        $st.Target = Get-AkariScrollTarget $st.Target $e.Delta $s.ScrollableHeight $lines
        $e.Handled = $true
        if (-not @($script:AkariScrolls.Values | Where-Object { $_.Active }).Count) {
            $script:AkariScrollLast = $null
            [Windows.Media.CompositionTarget]::add_Rendering($script:AkariScrollTick)
        }
        $st.Active = $true
    })
}

# stops a glide and puts the viewer at the top (a new page)
function Reset-AkariScroll($Viewer) {
    if (-not $Viewer) { return }
    $st = $script:AkariScrolls[$Viewer.GetHashCode()]
    if ($st) { $st.Active = $false; $st.Target = 0.0 }
    $Viewer.ScrollToTop()
}

# turns an icon once around its centre over $Ms on the decelerate curve (Install USB's Refresh); motion off = nothing
function Start-AkariSpin($Element, [double]$Ms = 800) {
    if (-not $Element -or -not $script:AkariMotionOn) { return }
    $Element.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    if ($Element.RenderTransform -isnot [Windows.Media.RotateTransform]) { $Element.RenderTransform = [Windows.Media.RotateTransform]::new() }
    $a = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    [void]$a.KeyFrames.Add([Windows.Media.Animation.DiscreteDoubleKeyFrame]::new(0, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::Zero)))
    [void]$a.KeyFrames.Add([Windows.Media.Animation.SplineDoubleKeyFrame]::new(360, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds($Ms)), $AkariMotion['Motion.Ease']))
    $a.FillBehavior = 'Stop'
    $Element.RenderTransform.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $a)
}

# a busy loop: $Target's $Property from $From to $To every $Seconds, forever (the progress ring, the skeletons'
# shimmer; a loop has its own duration, not a Motion token); motion off = nothing moves
function Start-AkariLoop($Target, $Property, [double]$From, [double]$To, [double]$Seconds) {
    if (-not $Target -or -not $script:AkariMotionOn) { return }
    $a = [Windows.Media.Animation.DoubleAnimation]::new($From, $To, [Windows.Duration]::new([TimeSpan]::FromSeconds($Seconds)))
    $a.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $Target.BeginAnimation($Property, $a)
}

# a RotateTransform turned to $Angle over $Speed on the decelerate curve (an expander's or the nav's chevron)
function Start-AkariTurn($Rotate, [double]$Angle, [string]$Speed = 'Base') {
    $from = $Rotate.Angle
    $Rotate.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $null)
    $Rotate.Angle = $Angle
    if (-not $script:AkariMotionOn -or $from -eq $Angle) { return }
    $a = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    [void]$a.KeyFrames.Add([Windows.Media.Animation.DiscreteDoubleKeyFrame]::new($from, [Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::Zero)))
    [void]$a.KeyFrames.Add([Windows.Media.Animation.SplineDoubleKeyFrame]::new($Angle, [Windows.Media.Animation.KeyTime]::FromTimeSpan($AkariMotion["Motion.$Speed"].TimeSpan), $AkariMotion['Motion.Ease']))
    $a.FillBehavior = 'Stop'
    $Rotate.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $a)
}

# a search hit's row flashes: it dims to 40 % and back, twice (300 ms each way)
function Start-AkariFlash($Element) {
    if (-not $Element -or -not $script:AkariMotionOn) { return }
    $a = [Windows.Media.Animation.DoubleAnimation]::new(1, 0.4, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(300)))
    $a.AutoReverse = $true; $a.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::new(2); $a.FillBehavior = 'Stop'
    $Element.BeginAnimation([Windows.UIElement]::OpacityProperty, $a)
}

# the theme's cross-fade (the prototype's setTheme veil): $Veil (a Bg Border over the window) to 60 % over 120 ms, then
# $Swap runs (the theme changes under it) and the veil fades away over 160 ms; motion off = $Swap at once
function Start-AkariVeil($Veil, [scriptblock]$Swap) {
    if (-not $script:AkariMotionOn) { & $Swap; return }
    $Veil.Visibility = 'Visible'
    $a = [Windows.Media.Animation.DoubleAnimation]::new(0, 0.6, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(120)))
    $Veil.BeginAnimation([Windows.UIElement]::OpacityProperty, $a)
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(120)
    $tm.Tag = @{ Veil = $Veil; Swap = $Swap }
    $tm.Add_Tick({
        param($s, $e)
        $s.Stop()
        & $s.Tag.Swap
        $v = $s.Tag.Veil
        $b = [Windows.Media.Animation.DoubleAnimation]::new(0.6, 0, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(160)))
        $b.Add_Completed({ $v.Visibility = 'Collapsed' }.GetNewClosure())
        $v.BeginAnimation([Windows.UIElement]::OpacityProperty, $b)
    })
    $tm.Start()
}

# glides a smooth viewer to $Offset (a SelectorBar picking a category, a search hit's row); motion off = a jump
function Start-AkariScrollTo($Viewer, [double]$Offset) {
    $st = $script:AkariScrolls[$Viewer.GetHashCode()]
    if (-not $st -or -not $script:AkariMotionOn) { $Viewer.ScrollToVerticalOffset($Offset); return }
    $st.Target = [Math]::Max(0, [Math]::Min($Offset, $Viewer.ScrollableHeight))
    if (-not @($script:AkariScrolls.Values | Where-Object { $_.Active }).Count) {
        $script:AkariScrollLast = $null
        [Windows.Media.CompositionTarget]::add_Rendering($script:AkariScrollTick)
    }
    $st.Active = $true
}

# ---- UI timing, for a debug run ($env:AKARI_UI_TIMING = 1; plan step 6): what makes the window stall goes to
# akari.log as "UI timing: ..." lines. Off (the default), these do nothing.
$script:UiTiming = [bool]$env:AKARI_UI_TIMING
$script:UiLoadWatch = [Diagnostics.Stopwatch]::StartNew()

# a timer for one piece of UI work; Stop-AkariUiTimer logs how long it took
function Start-AkariUiTimer([string]$Label) {
    if ($script:UiTiming) { @{ Label = $Label; Watch = [Diagnostics.Stopwatch]::StartNew() } }
}
function Stop-AkariUiTimer($Timer) {
    if ($Timer) { Write-ErrLog ('UI timing: {0} {1} ms' -f $Timer.Label, $Timer.Watch.ElapsedMilliseconds) }
}

# from the window's Loaded: how long the launch took (process start, and the UI files' load), then a watch on the
# UI thread: a 50 ms tick that arrives over 200 ms late means the window froze that long ($Where says on what page)
function Start-AkariStallWatch([scriptblock]$Where) {
    if (-not $script:UiTiming) { return }
    $since = try { ([DateTime]::Now - [Diagnostics.Process]::GetCurrentProcess().StartTime).TotalMilliseconds } catch { 0 }
    Write-ErrLog ('UI timing: window loaded {0:N0} ms after the process started, {1:N0} ms after the UI files' -f $since, $script:UiLoadWatch.ElapsedMilliseconds)
    $t = [Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Normal)
    $t.Interval = [TimeSpan]::FromMilliseconds(50)
    $t.Tag = @{ Last = [DateTime]::UtcNow; Where = $Where }
    $t.Add_Tick({
        param($s, $e)
        $now = [DateTime]::UtcNow
        $gap = ($now - $s.Tag.Last).TotalMilliseconds - 50
        $s.Tag.Last = $now
        if ($gap -gt 200) { Write-ErrLog ('UI timing: stalled {0:N0} ms on {1}' -f $gap, (& $s.Tag.Where)) }
    })
    $t.Start()
}

# ---- sliding pills: one pill (a Border in a Canvas behind the items) that slides and stretches to the picked item.
# Used for a row of radio buttons (Enable-AkariPillGroup).

# puts $Pill over $Target: glides there ($Animate, a pill already shown) or jumps (its first placement, a resize);
# no target, or one not laid out = hidden. $true when placed
function Move-AkariPill($Pill, $Target, [bool]$Animate = $true) {
    if (-not $Target -or $Target.ActualWidth -le 0) { $Pill.Visibility = 'Hidden'; return $false }
    $p = $Target.TranslatePoint([Windows.Point]::new(0, 0), $Pill.Parent)
    $jump = -not $Animate -or $Pill.Visibility -ne 'Visible'
    $Pill.Visibility = 'Visible'
    foreach ($m in @(@('Slide', $p.X), @('SlideY', $p.Y), @('Width', $Target.ActualWidth), @('Height', $Target.ActualHeight))) {
        Start-AkariMotion $Pill $m[0] $(if ($jump) { $m[1] }) $m[1] -Speed Base
    }
    $true
}

# a row of radio buttons ($Panel's children) with $Pill (a Border in a Canvas behind them) under the checked one: it
# slides on a check and jumps into place when the row resizes (labels or icons changing)
$script:AkariPillGroups = @{}
function Enable-AkariPillGroup($Panel, $Pill) {
    if (-not $Panel -or -not $Pill) { return }
    $script:AkariPillGroups[$Panel.GetHashCode()] = $Pill
    $Panel.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler]{ param($s, $e) Update-AkariPillGroup $s $true })
    $Panel.Add_SizeChanged({ param($s, $e) Update-AkariPillGroup $s $false })
    Update-AkariPillGroup $Panel $false
}
# (a checked button not laid out yet, the row just rebuilt: tried once more at Loaded priority, $Retry)
function Update-AkariPillGroup($Panel, [bool]$Animate = $true, [bool]$Retry = $true) {
    try {
        $pill = $script:AkariPillGroups[$Panel.GetHashCode()]
        if (-not $pill) { return }
        $c = @($Panel.Children | Where-Object { $_.IsChecked -eq $true })[0]
        if ($c -and $c.ActualWidth -le 0 -and $Retry) {
            [void]$Panel.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Loaded, [Action[object]]{
                param($s) Update-AkariPillGroup $s.Panel $s.Animate $false }, @{ Panel = $Panel; Animate = $Animate })
            return
        }
        [void](Move-AkariPill $pill $c $Animate)
    } catch { try { Write-ErrLog "Pill: $($_.Exception.Message)" } catch { } }
}

