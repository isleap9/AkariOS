using AkariOS.Core.Runs;
using AkariOS.Core.Sources;

namespace AkariOS.Core.Tests;

/// <summary>The console banner's logo (Get-AkariBannerArt): src/Assets/ascii.txt scaled down the same way.</summary>
public sealed class BannerTests
{
    [Fact]
    public void The_logo_is_scaled_as_the_PowerShell_app_scales_it()
    {
        var ps = Oracle.Run("Export-Banner.ps1", "-Src", Repo.Src).GetProperty("Rows").EnumerateArray().Select(r => r.GetString()).ToList();
        var text = new FolderSourceFiles(Repo.Root).ReadText(Banner.ArtFile);
        Assert.NotEmpty(ps);
        Assert.Equal(string.Join("\n", ps), string.Join("\n", Banner.Art(text)));
    }

    [Fact]
    public void No_art_gives_no_rows_and_strokes_split_dots_from_lines()
    {
        Assert.Empty(Banner.Art("\n  \n"));
        Assert.Equal([("..", false), ("++=", true), (" .", false)], Banner.Strokes("..++= ."));
    }
}
