using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace AkariOS.App.Look;

public enum MotionKind { Fade, Rise, Pop, Scale, Slide, SlideY, Fill, Width, Height }

public enum MotionProperty { Opacity, ScaleX, ScaleY, X, Y, Width, Height }

/// <summary>One value an animation moves: From null = from where it is now.</summary>
public sealed record MotionStep(MotionProperty Property, double? From, double To);

/// <summary>
/// Every animation in the app (src/UI/Motion.ps1, plan docs/plans/2026-10-31-motion-polish.md): the tokens of
/// Motion.xaml (Fast 120 ms, Base 200 ms, Slow 280 ms, Stagger 30 ms, the cubic Ease and the switch's Spring), only
/// Opacity and transforms (and a pill's size), never a colour. Each value is set to its end first and the animation
/// stops there, so code that sets it later is never overridden. Motion off (Windows' animation effects, or
/// AKARI_MOTION=off): the end values, no animation.
/// </summary>
public static class Motion
{
    private static ResourceDictionary? _tokens;

    public static bool On { get; private set; } = true;

    /// <summary>Once, before any window: the tokens (Motion.xaml, its Durations 0 when motion is off).</summary>
    public static void Initialize(bool on)
    {
        On = on;
        _tokens = (ResourceDictionary)AkariXaml.Load("Motion.xaml", on);
    }

    private static ResourceDictionary Tokens => _tokens ?? throw new InvalidOperationException("Motion.Initialize first");

    public static TimeSpan Duration(string speed) => ((Duration)Tokens[$"Motion.{speed}"]).TimeSpan;

    public static IEasingFunction Easing(string easing) => (IEasingFunction)Tokens[$"Motion.{easing}"];

    // ---- pure

    /// <summary>
    /// What an animation moves (Get-AkariMotionPlan): Fade opacity; Rise opacity and Y from 10 px below; Pop opacity
    /// and scale from 0.96; Scale / Slide / SlideY one transform; Fill the width scale (a bar growing from its origin);
    /// Width / Height the element's own size (a small absolutely placed element: a pill).
    /// </summary>
    public static IReadOnlyList<MotionStep> Plan(MotionKind kind, double? from = null, double? to = null) => kind switch
    {
        MotionKind.Fade => [new(MotionProperty.Opacity, from ?? 0, to ?? 1)],
        MotionKind.Rise => [new(MotionProperty.Opacity, 0, 1), new(MotionProperty.Y, from ?? 10, to ?? 0)],
        MotionKind.Pop => [new(MotionProperty.Opacity, 0, 1), new(MotionProperty.ScaleX, from ?? 0.96, to ?? 1), new(MotionProperty.ScaleY, from ?? 0.96, to ?? 1)],
        MotionKind.Scale => [new(MotionProperty.ScaleX, from, to ?? 1), new(MotionProperty.ScaleY, from, to ?? 1)],
        MotionKind.Slide => [new(MotionProperty.X, from, to ?? 0)],
        MotionKind.SlideY => [new(MotionProperty.Y, from, to ?? 0)],
        MotionKind.Fill => [new(MotionProperty.ScaleX, from, to ?? 1)],
        MotionKind.Width => [new(MotionProperty.Width, from, to ?? throw new ArgumentException("Width needs a To"))],
        MotionKind.Height => [new(MotionProperty.Height, from, to ?? throw new ArgumentException("Height needs a To"))],
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    /// <summary>A count from From to To at time t (0..1), eased out (cubic), rounded (Get-AkariCountValue).</summary>
    public static double CountValue(double from, double to, double t)
    {
        t = Math.Clamp(t, 0, 1);
        return Math.Round(from + (to - from) * (1 - Math.Pow(1 - t, 3)));
    }

    /// <summary>The next scroll target for a wheel delta: Windows' wheel lines (16 px each) per notch, inside 0..max.</summary>
    public static double ScrollTarget(double target, int delta, double max, int lines = 3) =>
        Math.Max(0, Math.Min(max, target - delta / 120.0 * lines * 16));

    /// <summary>One glide frame: the offset after ms, closing on the target exponentially; the target within half a px.</summary>
    public static double ScrollStep(double offset, double target, double ms)
    {
        var next = target + (offset - target) * Math.Exp(-Math.Max(0, ms) / 72.0);
        return Math.Abs(target - next) < 0.5 ? target : next;
    }

    // ---- animations

    /// <summary>The element's TransformGroup ending in Akari's ScaleTransform and TranslateTransform (made once,
    /// around any transform it had; centred unless it names its own RenderTransformOrigin).</summary>
    public static TransformGroup Transform(UIElement e)
    {
        if (e.RenderTransform is TransformGroup g && g.Children.Count >= 2 && g.Children[^2] is ScaleTransform && g.Children[^1] is TranslateTransform && !g.IsFrozen)
            return g;
        var n = new TransformGroup();
        if (e.RenderTransform is { } old && !old.Value.IsIdentity) n.Children.Add(old);
        n.Children.Add(new ScaleTransform());
        n.Children.Add(new TranslateTransform());
        if (e.RenderTransformOrigin == new Point(0, 0)) e.RenderTransformOrigin = new Point(0.5, 0.5);
        e.RenderTransform = n;
        return n;
    }

    /// <summary>Animates an element (Start-AkariMotion) over Fast / Base / Slow, after a delay.</summary>
    public static void Start(UIElement? e, MotionKind kind, double? from = null, double? to = null, string speed = "Base", TimeSpan delay = default, string easing = "Ease")
    {
        if (e is null) return;
        var plan = Plan(kind, from, to);
        var tg = plan.Any(p => p.Property is not (MotionProperty.Opacity or MotionProperty.Width or MotionProperty.Height)) ? Transform(e) : null;
        var duration = Duration(speed);
        var ease = Easing(easing);
        foreach (var p in plan)
        {
            (DependencyObject target, DependencyProperty dp) = p.Property switch
            {
                MotionProperty.Opacity => ((DependencyObject)e, UIElement.OpacityProperty),
                MotionProperty.Width => (e, FrameworkElement.WidthProperty),
                MotionProperty.Height => (e, FrameworkElement.HeightProperty),
                MotionProperty.ScaleX => (tg!.Children[^2], ScaleTransform.ScaleXProperty),
                MotionProperty.ScaleY => (tg!.Children[^2], ScaleTransform.ScaleYProperty),
                MotionProperty.X => (tg!.Children[^1], TranslateTransform.XProperty),
                _ => (tg!.Children[^1], TranslateTransform.YProperty),
            };
            var animatable = (IAnimatable)target;
            // no From = from where it is now (mid-animation too), read before the end value is set
            var start = p.From ?? (double)target.GetValue(dp);
            if (double.IsNaN(start)) start = p.To;
            target.SetValue(dp, p.To);
            if (!On || duration <= TimeSpan.Zero || start == p.To) { animatable.BeginAnimation(dp, null); continue; }
            // key frames: the start value held through the delay (a BeginTime would show the end value until then)
            var a = new DoubleAnimationUsingKeyFrames { FillBehavior = FillBehavior.Stop };
            a.KeyFrames.Add(new DiscreteDoubleKeyFrame(start, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            if (delay > TimeSpan.Zero) a.KeyFrames.Add(new DiscreteDoubleKeyFrame(start, KeyTime.FromTimeSpan(delay)));
            a.KeyFrames.Add(new EasingDoubleKeyFrame(p.To, KeyTime.FromTimeSpan(delay + duration), ease));
            animatable.BeginAnimation(dp, a);
        }
    }

    /// <summary>
    /// An element that comes in once it is built (Start-AkariEntrance): hidden now, played at Loaded priority (after
    /// the build and the first layout). Slide = a fade plus a slide from From px. Shown at once if it fails.
    /// </summary>
    public static void Entrance(UIElement? e, MotionKind kind = MotionKind.Rise, double? from = null, string speed = "Slow", TimeSpan delay = default)
    {
        if (e is null || !On) return;
        e.BeginAnimation(UIElement.OpacityProperty, null);
        e.Opacity = 0;
        e.Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>
        {
            try
            {
                if (kind == MotionKind.Slide)
                {
                    Start(e, MotionKind.Fade, speed: speed, delay: delay);
                    Start(e, MotionKind.Slide, from, 0, speed, delay);
                }
                else Start(e, kind, from, speed: speed, delay: delay);
            }
            catch (Exception) { e.Opacity = 1; }
        });
    }

    /// <summary>The first max visible elements come in one after another, Stagger apart (Start-AkariStagger).</summary>
    public static void Stagger(IEnumerable<UIElement> elements, int max = 12, MotionKind kind = MotionKind.Rise, double? from = 8)
    {
        if (!On) return;
        var gap = Duration("Stagger");
        var n = 0;
        foreach (var e in elements)
        {
            if (n >= max) break;
            if (e.Visibility != Visibility.Visible) continue;
            Entrance(e, kind, from, delay: TimeSpan.FromTicks(gap.Ticks * n));
            n++;
        }
    }

    private static readonly Dictionary<UIElement, DispatcherTimer> Hiding = [];

    /// <summary>A bar or overlay that appears: made Visible and played in only when it was not visible (Rise from
    /// From px, or Fade with From null); a hide still pending on it is called off.</summary>
    public static void Show(UIElement? e, double? from = -8, string speed = "Base")
    {
        if (e is null) return;
        if (Hiding.Remove(e, out var t)) { t.Stop(); e.IsHitTestVisible = true; e.Visibility = Visibility.Hidden; }
        if (e.Visibility == Visibility.Visible) return;
        e.Visibility = Visibility.Visible;
        if (from is null) Start(e, MotionKind.Fade, speed: speed);
        else Start(e, MotionKind.Rise, from, speed: speed);
    }

    /// <summary>Fades an element out, then collapses it; it stops taking clicks at once. Motion off = collapsed now.</summary>
    public static void Hide(UIElement? e, string speed = "Fast")
    {
        if (e is null || e.Visibility != Visibility.Visible || Hiding.ContainsKey(e)) return;
        if (!On) { e.Visibility = Visibility.Collapsed; return; }
        e.IsHitTestVisible = false;
        Start(e, MotionKind.Fade, e.Opacity, 0, speed);
        var t = new DispatcherTimer { Interval = Duration(speed) };
        Hiding[e] = t;
        t.Tick += (_, _) =>
        {
            t.Stop();
            Hiding.Remove(e);
            e.Visibility = Visibility.Collapsed;
            e.Opacity = 1;
            e.IsHitTestVisible = true;
        };
        t.Start();
    }

    private static readonly Dictionary<TextBlock, DispatcherTimer> Counts = [];

    /// <summary>A TextBlock's number counts to value over two Slow, from the number it shows (Start-AkariCount).</summary>
    public static void Count(TextBlock? text, int value, string format = "{0:N0}")
    {
        if (text is null) return;
        if (Counts.Remove(text, out var old)) old.Stop();
        _ = int.TryParse(new string(text.Text.Where(char.IsDigit).ToArray()), out var from);
        if (!On || from == value) { text.Text = string.Format(format, value); return; }
        var started = DateTime.UtcNow;
        var length = 2 * Duration("Slow").TotalMilliseconds;
        var t = new DispatcherTimer(DispatcherPriority.Render) { Interval = TimeSpan.FromMilliseconds(16) };
        Counts[text] = t;
        t.Tick += (_, _) =>
        {
            var f = (DateTime.UtcNow - started).TotalMilliseconds / length;
            text.Text = string.Format(format, (int)CountValue(from, value, f));
            if (f >= 1) { t.Stop(); Counts.Remove(text); }
        };
        t.Start();
    }

    // ---- smooth scrolling: a wheel notch moves a target offset and the viewer glides to it (CompositionTarget.Rendering
    // only while gliding). Touchpads (deltas that aren't whole notches) and inner scrollable parts keep WPF's own.

    private sealed class Glide(ScrollViewer viewer)
    {
        public ScrollViewer Viewer { get; } = viewer;
        public double Target;
        public bool Active;
    }

    private static readonly Dictionary<ScrollViewer, Glide> Glides = [];
    private static DateTime? _lastFrame;

    private static void Frame(object? sender, EventArgs e)
    {
        var now = DateTime.UtcNow;
        var ms = _lastFrame is { } last ? (now - last).TotalMilliseconds : 16;
        _lastFrame = now;
        foreach (var g in Glides.Values.Where(g => g.Active))
        {
            g.Target = Math.Min(g.Target, g.Viewer.ScrollableHeight);
            var next = ScrollStep(g.Viewer.VerticalOffset, g.Target, ms);
            g.Viewer.ScrollToVerticalOffset(next);
            if (next == g.Target) g.Active = false;
        }
        if (!Glides.Values.Any(g => g.Active)) { CompositionTarget.Rendering -= Frame; _lastFrame = null; }
    }

    /// <summary>Makes a ScrollViewer glide on the wheel (motion off: left as it is).</summary>
    public static void SmoothScroll(ScrollViewer? viewer)
    {
        if (viewer is null || !On || Glides.ContainsKey(viewer)) return;
        var glide = new Glide(viewer);
        Glides[viewer] = glide;
        viewer.PreviewMouseWheel += (s, e) =>
        {
            if (e.Handled || e.Delta % 120 != 0) return;
            // an inner part that scrolls itself (between the mouse and this viewer) keeps the wheel
            for (var p = e.OriginalSource as DependencyObject; p != null && p != viewer; p = p is Visual ? VisualTreeHelper.GetParent(p) : null)
                if (p is ScrollViewer inner && inner.ScrollableHeight > 0) return;
            if (viewer.ScrollableHeight <= 0) return;
            if (!glide.Active) glide.Target = viewer.VerticalOffset;
            glide.Target = ScrollTarget(glide.Target, e.Delta, viewer.ScrollableHeight, Math.Max(1, SystemParameters.WheelScrollLines));
            e.Handled = true;
            if (!Glides.Values.Any(g => g.Active)) { _lastFrame = null; CompositionTarget.Rendering += Frame; }
            glide.Active = true;
        };
    }

    /// <summary>Stops a glide and puts the viewer at the top (a new page).</summary>
    public static void ResetScroll(ScrollViewer? viewer)
    {
        if (viewer is null) return;
        if (Glides.TryGetValue(viewer, out var g)) { g.Active = false; g.Target = 0; }
        viewer.ScrollToTop();
    }

    // ---- sliding pills: one pill (a Border in a Canvas behind the items) slides and stretches to the picked item

    /// <summary>Puts the pill over the target: glides there, or jumps (its first placement, a resize). No target,
    /// or one not laid out = hidden. True when placed.</summary>
    public static bool MovePill(FrameworkElement pill, FrameworkElement? target, bool animate = true)
    {
        if (target is null || target.ActualWidth <= 0 || pill.Parent is not Visual parent) { pill.Visibility = Visibility.Hidden; return false; }
        var p = target.TranslatePoint(new Point(0, 0), (UIElement)parent);
        var jump = !animate || pill.Visibility != Visibility.Visible;
        pill.Visibility = Visibility.Visible;
        foreach (var (kind, to) in new[] { (MotionKind.Slide, p.X), (MotionKind.SlideY, p.Y), (MotionKind.Width, target.ActualWidth), (MotionKind.Height, target.ActualHeight) })
            Start(pill, kind, jump ? to : null, to);
        return true;
    }

    /// <summary>The segmented list's Pill (its template's) over the picked segment; a segment not laid out yet is
    /// tried once more at Loaded priority.</summary>
    public static void UpdateSegmentPill(ListBox list, bool animate = true, bool retry = true)
    {
        try
        {
            if (list.Template?.FindName("Pill", list) is not FrameworkElement pill) return;
            var c = list.SelectedItem is null ? null : list.ItemContainerGenerator.ContainerFromItem(list.SelectedItem) as FrameworkElement;
            if ((c is null || c.ActualWidth <= 0) && list.SelectedItem != null && retry)
            {
                list.Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () => UpdateSegmentPill(list, animate, false));
                return;
            }
            MovePill(pill, c, animate);
        }
        catch (Exception e) when (e is InvalidOperationException or ArgumentException) { }
    }

    private static bool _segmentsHooked;

    /// <summary>Once: every ListBox's segment pill follows its pick and its size (no page code calls it).</summary>
    public static void HookSegmentPills()
    {
        if (_segmentsHooked) return;
        _segmentsHooked = true;
        EventManager.RegisterClassHandler(typeof(ListBox), Selector.SelectionChangedEvent,
            new SelectionChangedEventHandler((s, e) => { if (e.OriginalSource == s) UpdateSegmentPill((ListBox)s, true); }));
        EventManager.RegisterClassHandler(typeof(ListBox), FrameworkElement.SizeChangedEvent,
            new SizeChangedEventHandler((s, e) => { if (e.OriginalSource == s) UpdateSegmentPill((ListBox)s, false); }));
        EventManager.RegisterClassHandler(typeof(ListBoxItem), FrameworkElement.SizeChangedEvent,
            new SizeChangedEventHandler((s, e) =>
            {
                if (e.OriginalSource == s && ItemsControl.ItemsControlFromItemContainer((DependencyObject)s) is ListBox l) UpdateSegmentPill(l, false);
            }));
    }

    /// <summary>A row of radio buttons with a pill under the checked one: it slides on a check and jumps into place
    /// when the row resizes (Enable-AkariPillGroup: the top bar's tabs, Optimize's chips).</summary>
    public static void PillGroup(Panel panel, FrameworkElement pill)
    {
        void Update(bool animate, bool retry)
        {
            var c = panel.Children.OfType<ToggleButton>().FirstOrDefault(b => b.IsChecked == true);
            if (c is { ActualWidth: <= 0 } && retry)
            {
                panel.Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () => Update(animate, false));
                return;
            }
            MovePill(pill, c, animate);
        }
        panel.AddHandler(ToggleButton.CheckedEvent, new RoutedEventHandler((_, _) => Update(true, true)));
        panel.SizeChanged += (_, _) => Update(false, true);
        Update(false, true);
    }

    // ---- UI timing, for a debug run (AKARI_UI_TIMING=1): "UI timing: ..." lines in akari.log; off, nothing

    public static bool Timing { get; } = Environment.GetEnvironmentVariable("AKARI_UI_TIMING") == "1";

    /// <summary>Times one piece of UI work; dispose it to log how long it took.</summary>
    public static IDisposable Timer(string label, Core.IAkariLog log) => new UiTimer(label, log);

    private sealed class UiTimer(string label, Core.IAkariLog log) : IDisposable
    {
        private readonly Stopwatch _watch = Stopwatch.StartNew();
        public void Dispose()
        {
            if (Timing) log.WriteFile($"UI timing: {label} {_watch.ElapsedMilliseconds} ms");
        }
    }

    /// <summary>From the window's Loaded: the launch time, then every UI-thread stall over 200 ms, and where.</summary>
    public static void StallWatch(Func<string> where, Core.IAkariLog log)
    {
        if (!Timing) return;
        var since = (DateTime.Now - Process.GetCurrentProcess().StartTime).TotalMilliseconds;
        log.WriteFile($"UI timing: window loaded {since:N0} ms after the process started");
        var last = DateTime.UtcNow;
        var t = new DispatcherTimer(DispatcherPriority.Normal) { Interval = TimeSpan.FromMilliseconds(50) };
        t.Tick += (_, _) =>
        {
            var now = DateTime.UtcNow;
            var gap = (now - last).TotalMilliseconds - 50;
            last = now;
            if (gap > 200) log.WriteFile($"UI timing: stalled {gap:N0} ms on {where()}");
        };
        t.Start();
    }
}
