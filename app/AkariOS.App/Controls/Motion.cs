using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace AkariOS.App.Controls;

/// <summary>
/// The look's motion switch: <see cref="Animated"/> = Windows' animation effects (UISettings.AnimationsEnabled).
/// <see cref="LiftProperty"/> (attached, for templates) gives an element its eased Translation (a tile's hover lift)
/// only while they are on; off, the lift is a plain 2 px step.
/// </summary>
public static class Motion
{
    public static bool Animated => new Windows.UI.ViewManagement.UISettings().AnimationsEnabled;

    public static readonly DependencyProperty LiftProperty = DependencyProperty.RegisterAttached(
        "Lift", typeof(bool), typeof(Motion), new PropertyMetadata(false, OnLift));

    public static bool GetLift(UIElement element) => (bool)element.GetValue(LiftProperty);

    public static void SetLift(UIElement element, bool value) => element.SetValue(LiftProperty, value);

    /// <summary>
    /// A row's hover fill (the design's page D: a settings row lights up under the pointer): on a Border whose
    /// <c>Tag</c> is the fill (a <c>{ThemeResource}</c> set in its style, so it follows the row's own theme) and whose
    /// Background is Transparent (so the whole row is hit-tested). Not motion: shown with animation effects off too.
    /// </summary>
    public static readonly DependencyProperty HoverFillProperty = DependencyProperty.RegisterAttached(
        "HoverFill", typeof(bool), typeof(Motion), new PropertyMetadata(false, OnHoverFill));

    public static bool GetHoverFill(Border element) => (bool)element.GetValue(HoverFillProperty);

    public static void SetHoverFill(Border element, bool value) => element.SetValue(HoverFillProperty, value);

    private static void OnHoverFill(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not Border row) return;
        row.PointerEntered -= OnRowEntered;
        row.PointerExited -= OnRowLeft;
        row.PointerCanceled -= OnRowLeft;
        row.PointerCaptureLost -= OnRowLeft;
        row.ClearValue(Border.BackgroundProperty);
        if (e.NewValue is not true) return;
        row.PointerEntered += OnRowEntered;
        row.PointerExited += OnRowLeft;
        row.PointerCanceled += OnRowLeft;
        row.PointerCaptureLost += OnRowLeft;
    }

    private static void OnRowEntered(object sender, Microsoft.UI.Xaml.Input.PointerRoutedEventArgs e)
    {
        if (sender is Border { Tag: Microsoft.UI.Xaml.Media.Brush fill } row) row.Background = fill;
    }

    // back to the style's own Background (Transparent)
    private static void OnRowLeft(object sender, Microsoft.UI.Xaml.Input.PointerRoutedEventArgs e)
    {
        if (sender is Border row) row.ClearValue(Border.BackgroundProperty);
    }

    private static void OnLift(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not UIElement element) return;
        element.TranslationTransition = e.NewValue is true && Animated
            ? new Vector3Transition { Duration = TimeSpan.FromMilliseconds(250) }
            : null;
    }
}
