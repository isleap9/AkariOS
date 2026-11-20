using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>
/// A page's content column (at most 1064 px, centred, the PowerShell app's): its width is set from the ScrollViewer's
/// own width every time that changes (the navigation pane opening or closing, the window resized). Left to MaxWidth and
/// centring alone, the Settings page kept the width and position it had before the pane collapsed: it started 220 px
/// in and ran under the scrollbar.
/// </summary>
public static class PageLayout
{
    public const double MaxWidth = 1064;

    public static void Fit(ScrollViewer scroller, FrameworkElement column)
    {
        scroller.HorizontalScrollMode = ScrollMode.Disabled;
        scroller.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled;
        column.MaxWidth = double.PositiveInfinity;
        column.HorizontalAlignment = HorizontalAlignment.Center;
        void Size(double width)
        {
            if (width > 0) column.Width = Math.Min(MaxWidth, width);
        }
        scroller.SizeChanged += (_, e) => Size(e.NewSize.Width);
        Size(scroller.ActualWidth);
    }
}
