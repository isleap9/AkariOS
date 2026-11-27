using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace AkariOS.App.Controls;

/// <summary>
/// The Akari bloom inside a featured card (the design's page D: One-click's card): <see cref="RibbonArt"/> in a
/// 360 x 180 box in the card's top right corner (smaller when the card is), at 70 %, faded out downwards from 20 % of
/// its height, still. Put it first in a card whose padding is 0, behind the content; it takes no room of its own (it
/// fills whatever cell it is in) and its corner is rounded as the card's inside (<see cref="Radius"/>). Hidden in high
/// contrast and from screen readers, never hit-tested.
/// </summary>
public sealed partial class BloomMark : Grid
{
    private const double BoxWidth = 360;
    private const double BoxHeight = 180;

    public static readonly DependencyProperty PaletteProperty = DependencyProperty.Register(
        nameof(Palette), typeof(string), typeof(BloomMark), new PropertyMetadata("Home", (d, _) => ((BloomMark)d).Build()));

    public static readonly DependencyProperty RadiusProperty = DependencyProperty.Register(
        nameof(Radius), typeof(double), typeof(BloomMark), new PropertyMetadata(7.0, (d, _) => ((BloomMark)d).SetRadius()));

    /// <summary>The colours, as <see cref="AuroraBackdrop.Palette"/>.</summary>
    public string Palette
    {
        get => (string)GetValue(PaletteProperty);
        set => SetValue(PaletteProperty, value);
    }

    /// <summary>The card's inner corner: its CornerRadius less its border (8 - 1 for a tile).</summary>
    public double Radius
    {
        get => (double)GetValue(RadiusProperty);
        set => SetValue(RadiusProperty, value);
    }

    // the Border clips the drawing to the card's rounded corner
    private readonly Border _corner = new() { HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top, IsHitTestVisible = false };
    private RibbonArt? _art;

    public BloomMark()
    {
        IsHitTestVisible = false;
        Opacity = 0.7;
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAccessibilityView(this, Microsoft.UI.Xaml.Automation.Peers.AccessibilityView.Raw);
        Children.Add(_corner);
        SizeChanged += (_, e) => Fit(e.NewSize);
        Loaded += (_, _) =>
        {
            Contrast.Changed += OnHighContrast;
            ApplyContrast();
        };
        Unloaded += (_, _) => Contrast.Changed -= OnHighContrast;
        ActualThemeChanged += (_, _) => ApplyContrast();
        SetRadius();
        Build();
    }

    // no room of its own: the card is as big as its content, and the bloom fills what it gets
    protected override Size MeasureOverride(Size availableSize)
    {
        base.MeasureOverride(new Size(0, 0));
        return new Size(0, 0);
    }

    private void Build()
    {
        var p = AuroraBackdrop.Colours(Palette);
        _art = new RibbonArt(p.Ribbon, p.RibbonLight, 0.2, 16);
        _corner.Child = _art;
        Fit(new Size(ActualWidth, ActualHeight));
    }

    private void SetRadius() => _corner.CornerRadius = new CornerRadius(0, Math.Max(0, Radius), 0, 0);

    private void Fit(Size size)
    {
        if (_art is null || size.Width <= 0 || size.Height <= 0) return;
        var width = Math.Min(BoxWidth, size.Width);
        var height = Math.Min(BoxHeight, size.Height);
        _corner.Width = width;
        _corner.Height = height;
        _art.Layout(width, height);
    }

    private void OnHighContrast() =>
        DispatcherQueue?.TryEnqueue(ApplyContrast);

    private void ApplyContrast() =>
        Visibility = Contrast.On ? Visibility.Collapsed : Visibility.Visible;
}
