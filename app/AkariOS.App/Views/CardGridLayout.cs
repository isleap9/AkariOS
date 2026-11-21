using AkariOS.App.Shell;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace AkariOS.App.Views;

/// <summary>
/// An ItemsRepeater layout for cards in place of UniformGridLayout, which sizes every card from the first one (and a
/// fixed MinItemHeight), so longer text was cut off: columns of at least <see cref="MinItemWidth"/> sharing the width,
/// each row as tall as its tallest card and every card in it stretched to that height (<see cref="CardGrid"/>).
/// </summary>
public sealed partial class CardGridLayout : NonVirtualizingLayout
{
    public double MinItemWidth { get; set; } = 220;
    public double ColumnSpacing { get; set; } = 8;
    public double RowSpacing { get; set; } = 8;

    /// <summary>At most this many columns; 0 = as many as fit.</summary>
    public int MaxColumns { get; set; }

    private int Columns(double width, int count) => CardGrid.Columns(width, MinItemWidth, ColumnSpacing, MaxColumns, count);

    protected override Size MeasureOverride(NonVirtualizingLayoutContext context, Size availableSize)
    {
        var children = context.Children;
        var columns = Columns(availableSize.Width, children.Count);
        var itemWidth = CardGrid.ItemWidth(availableSize.Width, MinItemWidth, ColumnSpacing, columns);
        var heights = new List<double>(children.Count);
        foreach (var child in children)
        {
            child.Measure(new Size(itemWidth, double.PositiveInfinity));
            heights.Add(child.DesiredSize.Height);
        }
        var height = CardGrid.Height(CardGrid.RowHeights(heights, columns), RowSpacing);
        var width = double.IsFinite(availableSize.Width) ? availableSize.Width : itemWidth * columns + ColumnSpacing * (columns - 1);
        return new Size(width, height);
    }

    protected override Size ArrangeOverride(NonVirtualizingLayoutContext context, Size finalSize)
    {
        var children = context.Children;
        var columns = Columns(finalSize.Width, children.Count);
        var itemWidth = CardGrid.ItemWidth(finalSize.Width, MinItemWidth, ColumnSpacing, columns);
        var rows = CardGrid.RowHeights([.. children.Select(c => c.DesiredSize.Height)], columns);
        var y = 0.0;
        for (var r = 0; r < rows.Count; r++)
        {
            for (var c = 0; c < columns; c++)
            {
                var i = r * columns + c;
                if (i >= children.Count) break;
                children[i].Arrange(new Rect(c * (itemWidth + ColumnSpacing), y, itemWidth, rows[r]));
            }
            y += rows[r] + RowSpacing;
        }
        return finalSize;
    }
}
