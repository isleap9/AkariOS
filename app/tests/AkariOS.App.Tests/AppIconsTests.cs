using System.IO;
using System.Windows.Controls;
using Rectangle = System.Windows.Shapes.Rectangle;
using Path = System.IO.Path;
using AkariOS.App.Look;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Tests;

/// <summary>The app icons built into the exe (src/Assets/Apps as WPF resources): every app has one, they load, a
/// black-or-white one is a mask in the text colour, anything else falls back to a Lucide icon.</summary>
public sealed class AppIconsTests
{
    private static readonly Lazy<LoadResult> Loaded = new(() =>
        new Loader(new FolderSourceFiles(LookTests.RepoRoot()), new Dictionary<string, ITweakCode>()).Load());

    // build\AppIcons.ps1 makes them; More Clock Tool, the braille driver and five of winutil's apps (lazygit, fnm,
    // JPEGView, K-Lite, Policy Plus) have no usable logo
    [Fact]
    public void Every_app_to_install_legacy_app_and_store_app_to_restore_has_a_bundled_icon()
    {
        string[] none = ["install-more-clock-tool", "remove-brlapi", "install-lazygit", "install-fnm", "install-jpegview", "install-k-lite-codecs", "install-policy-plus"];
        var apps = Loaded.Value.Tweaks.Where(t => t.Section == "Apps" && t.Group is null || t.Group == "store").ToList();
        Assert.True(apps.Count > 80);
        Assert.Equal("", string.Join(", ", apps.Where(t => !none.Contains(t.Id) && AppIcons.File(t, null) is null).Select(t => t.Id)));
        Assert.All(apps.Where(t => !none.Contains(t.Id)), t => Assert.True(AppIcons.Bundled.Contains(Path.GetFileName(AppIcons.File(t, null)!))));
    }

    [Fact]
    public void The_bundled_icons_are_every_png_of_assets_apps() => Assert.Equal(
        Directory.GetFiles(Path.Combine(LookTests.RepoRoot(), @"src\Assets\Apps"), "*.png").Select(f => Path.GetFileName(f).ToLowerInvariant()).Order(),
        AppIcons.Bundled.Order());

    private static Tweak Entry(string group, string name) =>
        Loader.NewEntry(Loaded.Value.Groups.First(g => g.Id == group), PsHashtable.Of(("Name", name)));

    [Fact]
    public void A_bundled_icon_loads_and_a_mono_one_is_a_mask_in_the_text_colour() => LookTests.OnSta(() =>
    {
        var color = AppIcons.Make(Entry("appx", "Clipchamp.Clipchamp"), null);
        Assert.IsType<Image>(color);
        Assert.Equal(20, color.Width);
        var mono = AppIcons.Make(Entry("appx", "Microsoft.WindowsAlarms"), null);
        Assert.IsType<Rectangle>(mono);
        Assert.NotNull(mono.OpacityMask);
    });

    [Fact]
    public void Without_an_image_a_feature_gets_settings_and_an_app_a_window() => LookTests.OnSta(() =>
    {
        Assert.Equal("settings-2", AppIcons.Fallback(Entry("capability", "Some.Capability~~~~0.0.1.0")));
        Assert.Equal("app-window", AppIcons.Fallback(Entry("appx", "Contoso.Unknown")));
        Assert.IsNotType<Image>(AppIcons.Make(Entry("appx", "Contoso.Unknown"), null));
    });

    [Fact]
    public void An_installed_store_apps_own_logo_comes_first() => LookTests.OnSta(() =>
    {
        var dir = Path.Combine(Path.GetTempPath(), $"akari-logo-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        try
        {
            var logo = Path.Combine(dir, "logo.png");
            File.Copy(Path.Combine(LookTests.RepoRoot(), @"src\Assets\Apps\Clipchamp.Clipchamp.png"), logo);
            var logos = new Dictionary<string, string> { ["Microsoft.BingNews"] = logo };
            Assert.Equal(logo, AppIcons.File(Entry("appx", "Microsoft.BingNews"), logos));
            Assert.IsType<Image>(AppIcons.Make(Entry("appx", "Microsoft.BingNews"), logos));
        }
        finally { Directory.Delete(dir, recursive: true); }
    });

    [Fact]
    public void A_white_only_logo_is_found()
    {
        // 4 x 4 BGRA: a clear border around a 2 x 2 middle
        static byte[] Image(byte b, byte g, byte r)
        {
            var px = new byte[4 * 4 * 4];
            foreach (var (x, y) in new[] { (1, 1), (2, 1), (1, 2), (2, 2) })
            {
                var i = (y * 4 + x) * 4;
                (px[i], px[i + 1], px[i + 2], px[i + 3]) = (b, g, r, 255);
            }
            return px;
        }
        Assert.True(AppIcons.IsWhite(Image(255, 255, 255), 4, 4));
        Assert.True(AppIcons.IsWhite(Image(230, 235, 240), 4, 4));
        Assert.False(AppIcons.IsWhite(Image(40, 120, 220), 4, 4));
        Assert.False(AppIcons.IsWhite(new byte[64], 4, 4));
    }
}
