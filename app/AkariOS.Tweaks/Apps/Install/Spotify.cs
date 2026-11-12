using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Spotify.ps1: Spotify refuses to install elevated, so its installer (AkariOS-Files)
/// is started through Explorer, as the signed-in user; its prefs are written first (the installer starts Spotify,
/// which reads them), then the installer alone is waited for. Done when the user's Spotify.exe is there.</summary>
[TweakCode("install-spotify")]
public sealed class Spotify : ITweakCode
{
    public const string Prefs = """
        app.autostart-configured=true
        app.autostart-mode="off"
        ui.hardware_acceleration=false
        """;

    private static string Folder(TweakContext c) => Path.Combine(AppFiles.User(c, "AppData"), "Spotify");

    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Path.Combine(Folder(c), "Spotify.exe"));

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        AppFiles.WriteText(Path.Combine(Folder(c), "prefs"), Prefs);
        // a folder every user can read: Explorer runs the installer as the signed-in user
        var exe = Download.Save(c, "spotify.exe", Path.Combine(AppFiles.Folder(c.Services.Public, "Public"), @"Downloads\SpotifySetup.exe"));
        TweakServices.Need(c.Services.Exe, "program runner").Run(Download.Windows(c, "explorer.exe"), $"\"{exe}\"", wait: false);
        c.Services.Sleep(TimeSpan.FromSeconds(10));
        TweakServices.Need(c.Services.Processes, "process list").Wait("SpotifySetup", _ => true, TimeSpan.FromSeconds(600));
    }
}
