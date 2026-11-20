using AkariOS.App.Shell;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Microsoft.UI.Xaml.Media;

namespace AkariOS.App.Views;

/// <summary>
/// A TextBlock showing a name with the search's match marked (Set-AkariCardHighlight): the match semibold in the accent
/// text colour. Set <c>views:Highlight.Text</c> to a <see cref="Highlighted"/>; the split is <see cref="TextMatch"/>'s.
/// </summary>
public static class Highlight
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.RegisterAttached(
        "Text", typeof(Highlighted), typeof(Highlight), new PropertyMetadata(null, OnText));

    public static Highlighted? GetText(TextBlock element) => (Highlighted?)element.GetValue(TextProperty);

    public static void SetText(TextBlock element, Highlighted? value) => element.SetValue(TextProperty, value);

    private static void OnText(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not TextBlock tb) return;
        tb.Inlines.Clear();
        if (e.NewValue is not Highlighted h) return;
        foreach (var part in h.Parts)
        {
            var run = new Run { Text = part.Text };
            if (part.Hit)
            {
                run.FontWeight = FontWeights.SemiBold;
                if (Application.Current.Resources.TryGetValue("AccentTextFillColorPrimaryBrush", out var brush) && brush is Brush b) run.Foreground = b;
            }
            tb.Inlines.Add(run);
        }
    }
}
