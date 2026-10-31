# Motion (plan docs/plans/2026-10-31-motion-polish.md): the tokens in UI\Motion.xaml, the XAML loader that puts them
# into every file it parses (Get-AkariXaml), and Start-AkariMotion, the only code that starts an animation.
# Dot-sourced first of the UI files by Akari.ps1. Pure helpers first (tests dot-source this file).

$AkariMotionKinds = @('Fade', 'Rise', 'Pop', 'Scale', 'Slide', 'Fill')

# Motion.xaml's entries (the text between its root tags); $On = $false writes every Duration as 0:0:0
function Get-AkariMotionEntries([string]$MotionXaml, [bool]$On = $true) {
    $m = [regex]::Match($MotionXaml, '(?s)<ResourceDictionary\b[^>]*>(.*)</ResourceDictionary>')
    if (-not $m.Success) { throw 'Motion.xaml has no ResourceDictionary' }
    $e = $m.Groups[1].Value
    if (-not $On) { $e = [regex]::Replace($e, '(<Duration\b[^>]*>)[^<]*(</Duration>)', '${1}0:0:0${2}') }
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
# Fill: the width scale alone, a bar that grows from its RenderTransformOrigin)
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
    $tg = if (@($plan | Where-Object { $_.Property -ne 'Opacity' }).Count) { Get-AkariMotionTransform $Element }
    $dur = $AkariMotion["Motion.$Speed"]
    $ease = $AkariMotion["Motion.$Easing"]
    foreach ($p in $plan) {
        $target, $dp = switch ($p.Property) {
            'Opacity' { $Element, [Windows.UIElement]::OpacityProperty }
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
        [void]$a.KeyFrames.Add([Windows.Media.Animation.EasingDoubleKeyFrame]::new([double]$p.To, [Windows.Media.Animation.KeyTime]::FromTimeSpan($Delay + $dur.TimeSpan), $ease))
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
function Start-AkariStagger($Elements, [int]$Max = 12, [string]$Kind = 'Rise', $From = 8) {
    if (-not $script:AkariMotionOn) { return }
    $gap = $AkariMotion['Motion.Stagger'].TimeSpan
    $n = 0
    foreach ($e in @($Elements)) {
        if ($n -ge $Max) { break }
        if ($e -isnot [Windows.UIElement] -or $e.Visibility -ne 'Visible') { continue }
        Start-AkariEntrance $e $Kind $From -Delay ([TimeSpan]::FromTicks($gap.Ticks * $n))
        $n++
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
