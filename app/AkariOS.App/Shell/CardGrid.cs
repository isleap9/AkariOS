namespace AkariOS.App.Shell;

/// <summary>
/// The card grid's sizes (pure; <see cref="Views.CardGridLayout"/> lays the cards out with them): as many columns of at
/// least the minimum width as fit (at most <paramref name="maxColumns"/>, 0 = no limit), the width shared out, and
/// each row as tall as its tallest card, so no card's text is cut.
/// </summary>
public static class CardGrid
{
    public static int Columns(double width, double minItemWidth, double spacing, int maxColumns, int count)
    {
        if (count <= 0) return 1;
        var fit = double.IsFinite(width) && width > 0 ? (int)Math.Floor((width + spacing) / (Math.Max(1, minItemWidth) + spacing)) : 1;
        var n = Math.Max(1, fit);
        if (maxColumns > 0) n = Math.Min(n, maxColumns);
        return n;
    }

    public static double ItemWidth(double width, double minItemWidth, double spacing, int columns) =>
        double.IsFinite(width) && width > 0 ? Math.Max(0, (width - spacing * (columns - 1)) / columns) : minItemWidth;

    /// <summary>Each row's height: the tallest card in it.</summary>
    public static IReadOnlyList<double> RowHeights(IReadOnlyList<double> heights, int columns)
    {
        var rows = new List<double>();
        for (var i = 0; i < heights.Count; i += columns)
            rows.Add(heights.Skip(i).Take(columns).DefaultIfEmpty(0).Max());
        return rows;
    }

    public static double Height(IReadOnlyList<double> rows, double rowSpacing) =>
        rows.Count == 0 ? 0 : rows.Sum() + rowSpacing * (rows.Count - 1);
}
