using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.UI;

namespace AkariOS.App.Controls;

/// <summary>
/// The Aurora banner's light (the design's page D): three soft glows that drift slowly behind the top of a page and
/// the Akari bloom's ribbons (<see cref="RibbonArt"/>) in the top right corner, in the page's own colours. The design's
/// sizes: the glows 62 / 56 / 42 % of the page wide, the ribbons' box 64 % wide and 230 px tall (340 on Home), faded out
/// downwards from 40 % of its height. Decoration only: never hit-tested, hidden from screen readers, still when
/// Windows' animation effects are off, gone in high contrast.
/// </summary>
public sealed partial class AuroraBackdrop : Grid
{
    public static readonly DependencyProperty PaletteProperty = DependencyProperty.Register(
        nameof(Palette), typeof(string), typeof(AuroraBackdrop), new PropertyMetadata("Home", (d, _) => ((AuroraBackdrop)d).Build()));

    public static readonly DependencyProperty TallProperty = DependencyProperty.Register(
        nameof(Tall), typeof(bool), typeof(AuroraBackdrop), new PropertyMetadata(false, (d, _) => ((AuroraBackdrop)d).Build()));

    /// <summary>The page's colours: Home, Install, Optimize, Remove, Downloads, Usb, Iso, Settings.</summary>
    public string Palette
    {
        get => (string)GetValue(PaletteProperty);
        set => SetValue(PaletteProperty, value);
    }

    /// <summary>Home's taller banner (640 px of light, 340 px of ribbons); other pages 460 / 230.</summary>
    public bool Tall
    {
        get => (bool)GetValue(TallProperty);
        set => SetValue(TallProperty, value);
    }

    /// <summary>A page's three glows, then the ribbons' colour and its light end.</summary>
    internal static (uint A, uint B, uint C, uint Ribbon, uint RibbonLight) Colours(string? palette) =>
        Palettes.TryGetValue(palette ?? "", out var found) ? found : Palettes["Home"];

    private static readonly IReadOnlyDictionary<string, (uint A, uint B, uint C, uint Ribbon, uint RibbonLight)> Palettes =
        new Dictionary<string, (uint, uint, uint, uint, uint)>(StringComparer.OrdinalIgnoreCase)
        {
            ["Home"] = (0xE3263F, 0xA21CAF, 0xFF7A3C, 0xE3263F, 0xFF9AA6),
            ["Install"] = (0xFF4D2E, 0xE3263F, 0xFF9A3C, 0xFF4D2E, 0xFFB199),
            ["Optimize"] = (0xE3263F, 0x7C3AED, 0xFF7A3C, 0xE3263F, 0xFF9AA6),
            ["Remove"] = (0x0F9D8A, 0x2B6FFF, 0x14B8A0, 0x0F9D8A, 0x7CE0CF),
            ["Downloads"] = (0x2B6FFF, 0x0EA5E9, 0x7C3AED, 0x2B6FFF, 0x9CC4FF),
            ["Usb"] = (0x5B6B82, 0x2B6FFF, 0x94A3B8, 0x5B6B82, 0xC4CDD8),
            ["Iso"] = (0xA21CAF, 0xE3263F, 0x7C3AED, 0xA21CAF, 0xE59CF0),
            ["Settings"] = (0xE3263F, 0x64748B, 0xA21CAF, 0xE3263F, 0xFF9AA6),
        };

    // the design's glows (CSS: left / right, width as a share of the page; top and height in px) and their drift
    // (translate as a share of the glow's own width, then px; scale from, to; seconds)
    private static readonly (bool Right, double X, double Width, double Top, double Shrink, double Opacity,
        double DriftX, double DriftY, double ScaleFrom, double ScaleTo, double Seconds)[] GlowSpecs =
    [
        (false, -0.08, 0.62, -160, 180, 1.0, 0.08, 30, 1.0, 1.15, 16),
        (true, -0.06, 0.56, -120, 220, 1.0, -0.10, 40, 1.1, 0.95, 19),
        (false, 0.34, 0.42, 60, 320, 0.7, 0.12, -30, 1.0, 1.0, 13),
    ];

    private const double RibbonShare = 0.64;
    private const double RibbonFadeFrom = 0.4;
    private const int RibbonFadeBands = 24;
    // the ribbons' sway (9 s, and back): left and down, inside the drawing's overscan
    private const double SwayX = 24;
    private const double SwayY = 10;

    private readonly List<Storyboard> _stories = [];
    private readonly Grid _glows = new() { IsHitTestVisible = false };
    // the ribbons' box (the theme's opacity) holds the host that breathes (its own opacity, 0.85 to 1), which holds the art (it sways inside)
    private readonly Grid _ribbonBox = new() { IsHitTestVisible = false, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top };
    private readonly Grid _ribbonHost = new() { IsHitTestVisible = false };
    private RibbonArt? _art;
    // the page width the running drift was worked out for (0 = none yet: started before the first layout)
    private double _driftWidth;
    // high contrast: no decoration at all; followed live while the page shows (Contrast.Changed)

    public AuroraBackdrop()
    {
        IsHitTestVisible = false;
        VerticalAlignment = VerticalAlignment.Top;
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAccessibilityView(this, Microsoft.UI.Xaml.Automation.Peers.AccessibilityView.Raw);
        _ribbonBox.Children.Add(_ribbonHost);
        Children.Add(_glows);
        Children.Add(_ribbonBox);
        Loaded += (_, _) =>
        {
            Contrast.Changed += OnHighContrast;
            ApplyTheme();
            Start();
        };
        Unloaded += (_, _) =>
        {
            Contrast.Changed -= OnHighContrast;
            Stop();
            _fade?.Stop();
            _faded = false;
        };
        ActualThemeChanged += (_, _) => ApplyTheme();
        SizeChanged += (_, e) => Fit(e.NewSize.Width);
        Build();
    }

    private static Color Rgb(uint rgb, byte alpha = 255) =>
        ColorHelper.FromArgb(alpha, (byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb);

    private void Build()
    {
        Stop();
        var p = Colours(Palette);
        Height = Tall ? 640 : 460;
        _glows.Children.Clear();
        uint[] colours = [p.A, p.B, p.C];
        for (var i = 0; i < GlowSpecs.Length; i++) _glows.Children.Add(Glow(colours[i], GlowSpecs[i]));
        _ribbonHost.Children.Clear();
        _art = new RibbonArt(p.Ribbon, p.RibbonLight, RibbonFadeFrom, RibbonFadeBands, SwayX, SwayY);
        _ribbonHost.Children.Add(_art);
        Fit(ActualWidth);
        ApplyTheme();
        if (IsLoaded) Start();
    }

    // the glows' and the ribbons' sizes from the page's width
    private void Fit(double width)
    {
        if (width <= 0) return;
        for (var i = 0; i < _glows.Children.Count && i < GlowSpecs.Length; i++)
        {
            var g = GlowSpecs[i];
            var glow = (FrameworkElement)_glows.Children[i];
            glow.Width = g.Width * width;
            glow.Margin = g.Right ? new Thickness(0, g.Top, g.X * width, 0) : new Thickness(g.X * width, g.Top, 0, 0);
        }
        var boxWidth = RibbonShare * width;
        var boxHeight = Tall ? 340 : 230;
        _ribbonBox.Width = boxWidth;
        _ribbonBox.Height = boxHeight;
        _art?.Layout(boxWidth, boxHeight);
        // started before the page had a width: the glows' drift (a share of their width) is worked out again now
        if (IsLoaded && _driftWidth <= 0 && Motion.Animated) Start();
    }

    private void OnHighContrast() =>
        DispatcherQueue?.TryEnqueue(ApplyTheme);

    private void ApplyTheme()
    {
        Visibility = Contrast.On ? Visibility.Collapsed : Visibility.Visible;
        var light = ActualTheme == ElementTheme.Light;
        _glows.Opacity = light ? 0.32 : 0.55;
        _ribbonBox.Opacity = light ? 0.55 : 0.8;
    }

    // a glow: CSS's radial-gradient(closest-side, colour, transparent); the design blurs it 30-40 px, which the
    // gradient's own soft edge stands in for
    private Ellipse Glow(uint rgb, (bool Right, double X, double Width, double Top, double Shrink, double Opacity,
        double DriftX, double DriftY, double ScaleFrom, double ScaleTo, double Seconds) spec)
    {
        var brush = new RadialGradientBrush();
        brush.GradientStops.Add(new GradientStop { Color = Rgb(rgb, 255), Offset = 0 });
        brush.GradientStops.Add(new GradientStop { Color = Rgb(rgb, 0), Offset = 1 });
        return new Ellipse
        {
            Height = Height - spec.Shrink,
            Fill = brush,
            Opacity = spec.Opacity,
            HorizontalAlignment = spec.Right ? HorizontalAlignment.Right : HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
            RenderTransformOrigin = new Point(0.5, 0.5),
            // at rest (no animation) the design's glows are unscaled; the drift starts from ScaleFrom
            RenderTransform = new CompositeTransform(),
        };
    }

    // ---- motion (the design's keyframes): a 1.2 s fade in, then the glows drift (16 / 19 / 13 s) and the ribbons sway
    // (9 s), each forever and back

    private void Start()
    {
        Stop();
        var animated = Motion.Animated;
        _driftWidth = ActualWidth;
        // the fade in once per load: started again for a width that came late, it blinked
        if (!_faded)
        {
            _faded = true;
            _fade?.Stop();
            _fade = new Storyboard();
            Add(_fade, this, "Opacity", 0, 1, TimeSpan.FromMilliseconds(animated ? 1200 : 1), false, new CubicEase { EasingMode = EasingMode.EaseOut });
            _fade.Begin();
        }
        if (!animated) return;

        for (var i = 0; i < _glows.Children.Count && i < GlowSpecs.Length; i++)
        {
            if (_glows.Children[i] is not FrameworkElement glow || glow.RenderTransform is not CompositeTransform t) continue;
            var g = GlowSpecs[i];
            var s = new Storyboard();
            var span = TimeSpan.FromSeconds(g.Seconds);
            var width = double.IsNaN(glow.Width) ? 0 : glow.Width;
            Add(s, t, "TranslateX", 0, g.DriftX * width, span, true);
            Add(s, t, "TranslateY", 0, g.DriftY, span, true);
            if (g.ScaleFrom != g.ScaleTo)
            {
                Add(s, t, "ScaleX", g.ScaleFrom, g.ScaleTo, span, true);
                Add(s, t, "ScaleY", g.ScaleFrom, g.ScaleTo, span, true);
            }
            s.Begin();
            _stories.Add(s);
        }
        {
            // the drawing sways inside its still strips (RibbonArt.Sways); the host only breathes
            var s = new Storyboard();
            var span = TimeSpan.FromSeconds(9);
            foreach (var sway in _art?.Sways ?? [])
            {
                Add(s, sway, "X", 0, -SwayX, span, true);
                Add(s, sway, "Y", 0, SwayY, span, true);
            }
            Add(s, _ribbonHost, "Opacity", 0.85, 1, span, true);
            s.Begin();
            _stories.Add(s);
        }
    }

    private bool _faded;
    private Storyboard? _fade;

    private void Stop()
    {
        foreach (var s in _stories) s.Stop();
        _stories.Clear();
    }

    private static void Add(Storyboard story, DependencyObject target, string property, double from, double to, TimeSpan duration, bool loop,
        EasingFunctionBase? ease = null)
    {
        var a = new DoubleAnimation
        {
            From = from,
            To = to,
            Duration = new Duration(duration),
            EasingFunction = ease ?? new SineEase { EasingMode = EasingMode.EaseInOut },
        };
        if (loop)
        {
            a.AutoReverse = true;
            a.RepeatBehavior = new RepeatBehavior { Type = RepeatBehaviorType.Forever };
        }
        Storyboard.SetTarget(a, target);
        Storyboard.SetTargetProperty(a, property);
        story.Children.Add(a);
    }
}
