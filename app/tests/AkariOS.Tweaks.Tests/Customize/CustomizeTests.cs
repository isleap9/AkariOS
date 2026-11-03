using System.Drawing;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tests.Customize;

/// <summary>Customize's script-block Tweaks (g4: Taskbar, Start, Explorer, Theme) on a test key, temp folders and fakes.
/// Their code-built rows are checked against PowerShell's in OptimizeTests (every RowsAreCode class).</summary>
public sealed class CustomizeTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    // the real user's folders, in the test's temp folder
    private string UserFolder(string name, string sub)
    {
        var p = _h.Folder(sub);
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", name, p, "String");
        return p;
    }

    [Fact]
    public void Every_g4_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Customize" && t.Category is "Taskbar" or "Start" or "Explorer" or "Theme"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    // ---- Taskbar

    [Fact]
    public void Unpinning_clears_the_users_taskband_and_quick_launch()
    {
        var appData = UserFolder("AppData", "AppData");
        var quick = Directory.CreateDirectory(Path.Combine(appData, @"Microsoft\Internet Explorer\Quick Launch\User Pinned")).FullName;
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband", "Favorites", new byte[] { 1 }, "Binary");
        Assert.Equal(OutcomeKind.Applied, _h.Run("taskbar-unpin-all", TweakMode.Apply).Kind);
        Assert.False(_h.Engine.Registry.KeyExists(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"));
        Assert.False(Directory.Exists(Path.GetDirectoryName(quick)));
    }

    [Fact]
    public void Never_small_icons_is_a_choice_of_three()
    {
        const string key = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";
        var t = _h.Tweak("taskbar-never-small-icons");
        Assert.Equal(TweakState.Default, _h.State(t.Id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        Assert.Equal((1u, TweakState.Optimized), ((uint)_h.Get(key, "IconSizePreference")!, _h.State(t.Id)));
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply, "Always").Kind);
        Assert.Equal((0u, "Always", TweakState.Custom), ((uint)_h.Get(key, "IconSizePreference")!, _h.Engine.States.ChoiceValue(t), _h.State(t.Id)));
        _h.Set(key, "IconSizePreference", 7, "DWord");
        Assert.Null(_h.Engine.States.ChoiceValue(t));
        Assert.Equal(OutcomeKind.Reverted, _h.Run(t.Id, TweakMode.Revert).Kind);
        Assert.Null(_h.Get(key, "IconSizePreference"));
    }

    [Fact]
    public void Quick_settings_tiles_are_unpinned_with_empty_markers()
    {
        const string key = @"HKCU:\Control Panel\Quick Actions\Control Center\Unpinned";
        Assert.Equal(TweakState.Default, _h.State("taskbar-quick-settings-unpin"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("taskbar-quick-settings-unpin", TweakMode.Apply).Kind);
        Assert.Equal(["Microsoft.QuickAction.Accessibility", "Microsoft.QuickAction.BlueLightReduction", "Microsoft.QuickAction.Cast", "Microsoft.QuickAction.NearShare", "Microsoft.QuickAction.ProjectL2"],
            _h.Engine.Registry.ValueNames(key).Order());
        Assert.Equal(Microsoft.Win32.RegistryValueKind.None, _h.Engine.Registry.GetKind(key, "Microsoft.QuickAction.Cast"));
        Assert.Equal(TweakState.Optimized, _h.State("taskbar-quick-settings-unpin"));
        _h.Engine.Registry.RemoveValue(key, "Microsoft.QuickAction.Cast");
        Assert.Equal(TweakState.Custom, _h.State("taskbar-quick-settings-unpin"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("taskbar-quick-settings-unpin", TweakMode.Revert).Kind);
        Assert.Empty(_h.Engine.Registry.ValueNames(key));
    }

    [Fact]
    public void Tray_icons_are_promoted_one_by_one_on_windows_11_and_by_one_switch_on_10()
    {
        const string icons = @"HKCU:\Control Panel\NotifyIconSettings";
        Assert.Equal(TweakState.Unknown, _h.State("taskbar-show-all-tray-icons"));
        _h.Set($@"{icons}\111", "ExecutablePath", "a.exe", "String");
        _h.Set($@"{icons}\222", "IsPromoted", 1, "DWord");
        Assert.Equal(TweakState.Custom, _h.State("taskbar-show-all-tray-icons"));
        _h.Run("taskbar-show-all-tray-icons", TweakMode.Apply);
        Assert.Equal((1u, TweakState.Optimized), ((uint)_h.Get($@"{icons}\111", "IsPromoted")!, _h.State("taskbar-show-all-tray-icons")));
        _h.Run("taskbar-show-all-tray-icons", TweakMode.Revert);
        Assert.Equal(TweakState.Default, _h.State("taskbar-show-all-tray-icons"));

        _h.Pc.Build = 19045;
        Assert.Equal(TweakState.Default, _h.State("taskbar-show-all-tray-icons"));
        _h.Run("taskbar-show-all-tray-icons", TweakMode.Apply);
        Assert.Equal((0u, TweakState.Optimized), ((uint)_h.Get(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer", "EnableAutoTray")!, _h.State("taskbar-show-all-tray-icons")));
        _h.Run("taskbar-show-all-tray-icons", TweakMode.Revert);
        Assert.Null(_h.Get(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer", "EnableAutoTray"));
    }

    // ---- Start

    [Fact]
    public void Start_pins_write_and_read_back_start2_bin_on_windows_11()
    {
        var local = UserFolder("Local AppData", @"User\AppData\Local");
        var bin = Path.Combine(local, @"Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin");
        var t = _h.Tweak("start-akarios-pins");
        Assert.Equal(TweakState.Default, _h.State(t.Id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        Assert.Equal(Tweaks.Customize.Start.AkariOSPins.Ours(t, _h.Engine.Context), File.ReadAllBytes(bin));
        Assert.True(File.ReadAllBytes(bin).Length > 100);
        Assert.Equal((TweakState.Optimized, "StartMenuExperienceHost"), (_h.State(t.Id), string.Join(",", _h.Processes.Stopped)));
        File.WriteAllBytes(bin, [1, 2, 3]);
        Assert.Equal(TweakState.Custom, _h.State(t.Id));
        Assert.Equal(OutcomeKind.Reverted, _h.Run(t.Id, TweakMode.Revert).Kind);
        Assert.False(File.Exists(bin));
    }

    [Fact]
    public void Start_pins_on_windows_10_load_a_layout_once_through_explorer()
    {
        _h.Pc.Build = 19045;
        var t = _h.Tweak("start-akarios-pins");
        Assert.Equal(TweakState.Unknown, _h.State(t.Id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(t.Id, TweakMode.Apply).Kind);
        Assert.Equal(1, _h.Explorer.Restarts);
        // unlocked again, the layout file gone
        Assert.Equal((0u, (object?)null), ((uint)_h.Get(@"HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer", "LockedStartLayout")!, _h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer", "StartLayoutFile")));
        Assert.False(File.Exists(Path.Combine(_h.Engine.Services.Windows, "StartMenuLayout.xml")));
    }

    [Fact]
    public void Start_shortcuts_are_made_in_all_apps()
    {
        var programs = UserFolder("Programs", @"User\Programs");
        var all = Directory.CreateDirectory(Path.Combine(_h.Engine.Services.ProgramData, @"Microsoft\Windows\Start Menu\Programs")).FullName;
        Assert.Equal(OutcomeKind.Applied, _h.Run("start-akarios-shortcuts", TweakMode.Apply).Kind);
        Assert.Equal(5, _h.Shortcuts.Made.Count);
        Assert.Equal(Path.Combine(programs, "Startup"), _h.Shortcuts.Made[Path.Combine(all, "Startup Programs 1.lnk")]);
        Assert.Equal("::{645ff040-5081-101b-9f08-00aa002f954e}", _h.Shortcuts.Made[Path.Combine(all, "Recycle Bin.lnk")]);
        Assert.Equal(OutcomeKind.Already, _h.Run("start-akarios-shortcuts", TweakMode.Apply).Kind);
    }

    [Fact]
    public void Accessibility_folders_are_hidden_and_desktop_ini_keeps_its_attributes()
    {
        var programs = UserFolder("Programs", @"User\Programs");
        var mine = Directory.CreateDirectory(Path.Combine(programs, "Accessibility")).FullName;
        var acc = Directory.CreateDirectory(Path.Combine(_h.Engine.Services.ProgramData, @"Microsoft\Windows\Start Menu\Programs\Accessories")).FullName;
        File.WriteAllText(Path.Combine(acc, "Notepad.lnk"), "");
        var ini = Path.Combine(acc, "desktop.ini");
        File.WriteAllText(ini, "");
        File.SetAttributes(ini, FileAttributes.System);
        Assert.Equal(TweakState.Default, _h.State("start-hide-accessibility-folders"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("start-hide-accessibility-folders", TweakMode.Apply).Kind);
        Assert.True(new DirectoryInfo(mine).Attributes.HasFlag(FileAttributes.Hidden));
        Assert.True(File.GetAttributes(Path.Combine(acc, "Notepad.lnk")).HasFlag(FileAttributes.Hidden));
        Assert.Equal(FileAttributes.System, File.GetAttributes(ini));
        Assert.Equal(TweakState.Optimized, _h.State("start-hide-accessibility-folders"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("start-hide-accessibility-folders", TweakMode.Revert).Kind);
        Assert.False(File.GetAttributes(Path.Combine(acc, "Notepad.lnk")).HasFlag(FileAttributes.Hidden));
        Assert.Equal(TweakState.Default, _h.State("start-hide-accessibility-folders"));
        File.SetAttributes(ini, FileAttributes.Normal);
    }

    // ---- Theme

    [Fact]
    public void The_akarios_wallpaper_is_copied_set_and_shown()
    {
        var ours = Path.Combine(_h.Engine.Services.Windows, @"Web\AkariOS\img.jpg");
        var img0 = Path.Combine(_h.Engine.Services.Windows, @"Web\Wallpaper\Windows\img0.jpg");
        _h.Set(@"HKCU:\Control Panel\Desktop", "Wallpaper", img0, "String");
        Assert.Equal(TweakState.Default, _h.State("theme-akarios-wallpaper"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("theme-akarios-wallpaper", TweakMode.Apply).Kind);
        Assert.Equal(File.ReadAllBytes(Path.Combine(Core.Tests.Repo.Src, "OneClick", "img.jpg")), File.ReadAllBytes(ours));
        Assert.Equal((ours, "10", TweakState.Optimized), ((string)_h.Get(@"HKCU:\Control Panel\Desktop", "Wallpaper")!, (string)_h.Get(@"HKCU:\Control Panel\Desktop", "WallpaperStyle")!, _h.State("theme-akarios-wallpaper")));
        // an older AkariOS wallpaper (another size) reads Custom
        File.WriteAllBytes(ours, [1, 2, 3]);
        Assert.Equal(TweakState.Custom, _h.State("theme-akarios-wallpaper"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("theme-akarios-wallpaper", TweakMode.Revert).Kind);
        Assert.Equal([ours, img0], _h.Desktop.Wallpapers);
        Assert.Equal((TweakState.Default, false), (_h.State("theme-akarios-wallpaper"), File.Exists(ours)));
    }

    [Fact]
    public void Account_pictures_are_painted_black_and_put_back()
    {
        var dir = Directory.CreateDirectory(Path.Combine(_h.Engine.Services.ProgramData, @"Microsoft\User Account Pictures")).FullName;
        using (var b = new Bitmap(4, 3))
        {
            b.SetPixel(1, 1, Color.Red);
            b.Save(Path.Combine(dir, "user.png"), System.Drawing.Imaging.ImageFormat.Png);
        }
        var original = File.ReadAllBytes(Path.Combine(dir, "user.png"));
        Assert.Equal(TweakState.Default, _h.State("theme-black-account-pictures"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("theme-black-account-pictures", TweakMode.Apply).Kind);
        using (var b = new Bitmap(Path.Combine(dir, "user.png")))
            Assert.Equal((4, 3, Color.Black.ToArgb()), (b.Width, b.Height, b.GetPixel(1, 1).ToArgb()));
        Assert.Equal(original, File.ReadAllBytes(Path.Combine(_h.Engine.Services.ProgramData, "User Account Pictures", "user.png")));
        Assert.Equal(TweakState.Optimized, _h.State("theme-black-account-pictures"));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("theme-black-account-pictures", TweakMode.Revert).Kind);
        Assert.Equal(original, File.ReadAllBytes(Path.Combine(dir, "user.png")));
        Assert.Equal(TweakState.Default, _h.State("theme-black-account-pictures"));
    }

    [Fact]
    public void The_lock_screen_turns_black_at_the_screens_size()
    {
        const string key = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP";
        var file = Path.Combine(_h.Engine.Services.Windows, "Black.jpg");
        Assert.Equal(TweakState.Default, _h.State("theme-black-lock-screen"));
        Assert.Equal(OutcomeKind.Applied, _h.Run("theme-black-lock-screen", TweakMode.Apply).Kind);
        using (var b = new Bitmap(file)) Assert.Equal((64, 36), (b.Width, b.Height));
        Assert.Equal((file, 1u, TweakState.Optimized), ((string)_h.Get(key, "LockScreenImagePath")!, (uint)_h.Get(key, "LockScreenImageStatus")!, _h.State("theme-black-lock-screen")));
        Assert.Equal(OutcomeKind.Reverted, _h.Run("theme-black-lock-screen", TweakMode.Revert).Kind);
        Assert.Equal(((object?)null, false), (_h.Get(key, "LockScreenImagePath"), File.Exists(file)));
    }

    [Fact]
    public void The_real_desktop_parts_cant_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new Core.Machine.Processes());
        Assert.Throws<InvalidOperationException>(() => new Core.Machine.Shortcuts());
        Assert.Throws<InvalidOperationException>(() => new Core.Machine.Desktop());
    }
}
