using AkariOS.App.Shell;

namespace AkariOS.App.Tests;

/// <summary>The card grid's sizes: columns that fit, the width shared, each row as tall as its tallest card (no card's
/// text cut, as UniformGridLayout cut it).</summary>
public sealed class CardGridTests
{
    [Theory]
    [InlineData(1000, 220, 8, 0, 4, 4)]
    [InlineData(1000, 220, 8, 0, 9, 4)]
    [InlineData(1000, 340, 4, 2, 5, 2)]
    [InlineData(100, 220, 8, 0, 4, 1)]
    [InlineData(double.PositiveInfinity, 220, 8, 0, 4, 1)]
    public void Fits_as_many_columns_as_the_minimum_width_allows(double width, double min, double spacing, int max, int count, int columns) =>
        Assert.Equal(columns, CardGrid.Columns(width, min, spacing, max, count));

    [Fact]
    public void Shares_the_width_between_the_columns() => Assert.Equal(244, CardGrid.ItemWidth(1000, 220, 8, 4));

    [Fact]
    public void Makes_each_row_as_tall_as_its_tallest_card()
    {
        var rows = CardGrid.RowHeights([150, 210, 180, 160, 90], 4);
        Assert.Equal([210, 90], rows);
        Assert.Equal(308, CardGrid.Height(rows, 8));
        Assert.Equal(0, CardGrid.Height([], 8));
    }
}
