using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core.Tweaks;
using Microsoft.UI.Xaml;

namespace AkariOS.App.Tests;

/// <summary>Downloads and Remove apps (Apps.ps1) and the app icons, on the repo's Tweaks with the Store packages, the
/// features and winget faked.</summary>
public sealed class AppsTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    // ---- icons

    // build\AppIcons.ps1 makes them; these have no usable logo
    private static readonly string[] NoLogo = ["install-more-clock-tool", "remove-brlapi", "install-lazygit", "install-fnm", "install-jpegview", "install-k-lite-codecs", "install-policy-plus", "install-putty"];

    [Fact]
    public void Every_app_to_install_legacy_app_and_store_app_to_restore_has_a_bundled_icon()
    {
        var t = _h.Make();
        var apps = t.Engine.Loaded.Tweaks.Where(x => x.Section == "Apps" && x.Group is null || x.Group == "store").ToList();
        Assert.True(apps.Count > 80);
        Assert.Equal("", string.Join(", ", apps.Where(x => !NoLogo.Contains(x.Id) && t.Icons.Of(x, null).Image is null).Select(x => x.Id)));
        // every png of src/Assets/Apps is built in
        Assert.Equal(Directory.GetFiles(Path.Combine(Core.Tests.Repo.Src, "Assets", "Apps"), "*.png").Select(f => Path.GetFileName(f).ToLowerInvariant()).Order(),
            AssetFiles.Apps.Select(n => n.ToLowerInvariant()).Order());
    }

    [Fact]
    public void An_icon_is_unpacked_a_mono_one_is_a_mask_and_without_one_a_glyph()
    {
        var t = _h.Make();
        var steam = t.Icons.Of(t.Engine.Find("install-steam")!, null);
        Assert.True(steam.IsColor);
        Assert.True(File.Exists(steam.Image!.LocalPath));
        Assert.StartsWith(t.AssetDir, steam.Image.LocalPath, StringComparison.OrdinalIgnoreCase);
        Assert.True(t.Icons.Of(t.Engine.Find("appx/Microsoft.WindowsAlarms")!, null).IsMono);
        Assert.Equal(AppIcons.AppGlyph, t.Icons.Of(t.Engine.Find("appx/Contoso.Unknown")!, null).Glyph);
        Assert.Equal(AppIcons.FeatureGlyph, t.Icons.Of(t.Engine.Find("capability/Some.Capability~~~~0.0.1.0")!, null).Glyph);
    }

    [Fact]
    public void An_installed_store_apps_own_logo_comes_first_and_a_white_one_is_a_mask()
    {
        var t = _h.Make();
        Directory.CreateDirectory(_h.Dir);
        var logo = Path.Combine(_h.Dir, "logo.png");
        File.Copy(Path.Combine(Core.Tests.Repo.Src, "Assets", "Apps", "install-steam.png"), logo);
        var news = t.Icons.Of(t.Engine.Find("appx/Microsoft.BingNews")!, new Dictionary<string, string> { ["Microsoft.BingNews"] = logo });
        Assert.Equal((logo, false), (news.Image!.LocalPath, news.Mono));
        // 4 x 4 BGRA: a clear border around a 2 x 2 middle
        static byte[] Image(byte b, byte g, byte r)
        {
            var px = new byte[4 * 4 * 4];
            for (var i = 0; i < 16; i++) (px[i * 4], px[i * 4 + 1], px[i * 4 + 2], px[i * 4 + 3]) = (b, g, r, 255);
            return px;
        }
        Assert.True(AppIcons.IsWhite(Image(250, 250, 250), 4, 4));
        Assert.False(AppIcons.IsWhite(Image(40, 40, 220), 4, 4));
        Assert.False(AppIcons.IsWhite(new byte[64], 4, 4));
    }

    // ---- Remove apps

    [Fact]
    public async Task Remove_apps_lists_one_list_at_a_time_and_removes_the_picks_in_one_run()
    {
        var t = _h.Make();
        t.Packages.Add("Microsoft.WindowsAlarms", "Microsoft.BingNews");
        t.Dism.Capabilities.Add(new("Media.WindowsMediaPlayer~~~~0.0.12.0", "Installed"));
        var r = t.Remove;
        r.Shown();
        var a = r.Apps;
        Assert.Equal("Store apps", a.CurrentRemove!.Name);
        Assert.True(a.Rows["appx/Microsoft.WindowsAlarms"].Installed);
        Assert.Equal(Visibility.Collapsed, a.Rows["appx/Microsoft.Todos"].Shows);
        a.RemoveList = "Optional features";
        Assert.Equal(["Media.WindowsMediaPlayer~~~~0.0.12.0"], a.CurrentRemove!.Rows.Select(x => x.Tweak.Package ?? x.Tweak.Name));
        Assert.Equal(("0 selected", "Remove", false), (r.CountText, r.RemoveText, r.CanRemove));
        a.Rows["appx/Microsoft.WindowsAlarms"].IsChecked = true;
        a.Rows["appx/Microsoft.BingNews"].IsChecked = true;
        Assert.Equal(("2 selected", "Remove (2)", true), (r.CountText, r.RemoveText, r.CanRemove));
        // asked with the names; Cancel: nothing
        await r.RemoveAsync();
        Assert.Contains("Alarms & Clock", t.Dialogs.Asked[^1]);
        Assert.Equal(2, t.Packages.Packages.Count);
        t.Dialogs.Answers.Enqueue("Remove");
        await r.RemoveAsync();
        Assert.Empty(t.Packages.Packages);
        Assert.Single(t.Points.Points);
        Assert.Equal("Removed: 2 apps are gone.", t.Toasts[0]);
        Assert.Equal("Removed 2 apps", t.Activity.All()[0].Title);
        // read again: nothing picked, the same list shown, the removed apps no longer installed
        Assert.NotSame(a, r.Apps);
        Assert.Equal("Optional features", r.Apps.RemoveList);
        Assert.False(r.Apps.Rows["appx/Microsoft.WindowsAlarms"].Installed);
        Assert.Equal("0 selected", r.CountText);
        Assert.False(t.Shell.Locked || t.Shell.IsBusy);
    }

    // ---- Downloads

    [Fact]
    public void Downloads_lists_cards_by_category_and_search()
    {
        var t = _h.Make();
        var d = t.Downloads;
        d.Open();
        Assert.Equal(["All", "Gaming", "Browsers", "Communication", "Media", "Tools", "Development"], d.Categories);
        Assert.Equal("Gaming", d.Shown[0].Category);
        Assert.Contains(d.Shown, c => c.Tweak.Id == "install-steam");
        d.Category = "Browsers";
        Assert.All(d.Shown, c => Assert.Equal("Browsers", c.Category));
        d.Category = "All";
        d.Query = "putty";
        Assert.Equal(["install-putty"], d.Shown.Select(c => c.Tweak.Id));
        d.Query = "nothing like it";
        Assert.True(d.IsEmpty);
        Assert.Equal("No apps match \"nothing like it\"", d.EmptyText);
    }

    [Fact]
    public async Task Install_runs_one_app_at_a_time_and_its_card_says_how()
    {
        var t = _h.Make();
        var d = t.Downloads;
        d.Open();
        var putty = d.Cards["install-putty"];
        Assert.True(putty.CanInstall);
        t.Work.Hold = true;
        putty.InstallCommand.Execute(null);
        d.Cards["install-steam"].InstallCommand.Execute(null);
        Assert.Equal((CardState.Installing, CardState.Waiting), (putty.State, d.Cards["install-steam"].State));
        Assert.True(d.Busy);
        Assert.False(await t.Closing.CanCloseAsync());
        Assert.Equal(["Installing PuTTY", "1 app waiting to install"], t.Closing.Running());
        Assert.Equal("Installing PuTTY (1 of 2)", t.Shell.BusyText);
        Assert.Equal((false, 0d), (t.Shell.Indeterminate, t.Shell.ProgressValue));
        t.Work.Hold = false;
        while (t.Work.Held.TryDequeue(out var run)) run();
        Assert.Equal(CardState.Installed, putty.State);
        Assert.Contains(t.Winget.Calls, c => c.Contains("install", StringComparison.Ordinal) && c.Contains("PuTTY.PuTTY", StringComparison.Ordinal));
        Assert.Equal("Installed PuTTY", t.Activity.All()[0].Title);
        // Steam needs its C# After block, which the test engine has none of: it fails and says why
        var steam = d.Cards["install-steam"];
        Assert.Equal(CardState.Failed, steam.State);
        Assert.NotEqual("", steam.Why);
        Assert.False(d.Busy);
        // an installed winget app can be uninstalled from its card
        Assert.True(putty.CanUninstall);
        t.Dialogs.Answers.Enqueue("Uninstall");
        await putty.UninstallCommand.ExecuteAsync(null);
        Assert.Contains("- PuTTY", t.Dialogs.Asked[^1]);
        Assert.Equal(CardState.None, putty.State);
    }

    [Fact]
    public void Apps_found_installed_on_this_pc_show_as_installed()
    {
        var t = _h.Make();
        t.Winget.Answer = a => a[0] == "list" ? new(0, ["Name   Id            Version", "PuTTY  PuTTY.PuTTY   0.81"]) : null;
        t.Downloads.Open();
        Assert.Equal(CardState.Installed, t.Downloads.Cards["install-putty"].State);
        Assert.Equal(CardState.None, t.Downloads.Cards["install-steam"].State);
    }
}
