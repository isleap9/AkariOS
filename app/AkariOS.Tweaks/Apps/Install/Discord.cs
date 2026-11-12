using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Discord.ps1: after the winget install, Discord's own installer (Squirrel's
/// Update.exe, still running when winget returns) waited for, never stopped; then Discord closed, its settings written
/// (no hardware acceleration, no autostart) and its Run value removed.</summary>
[TweakCode("install-discord")]
public sealed class Discord : ITweakCode
{
    public const string Settings = """
        {
            "SKIP_HOST_UPDATE": true,
            "DEVELOPER_MODE": true,
            "enableHardwareAcceleration": false,
            "MINIMIZE_TO_TRAY": true,
            "OPEN_ON_STARTUP": false,
            "START_MINIMIZED": false,
            "IS_MAXIMIZED": true,
            "IS_MINIMIZED": false,
            "debugLogging": false
        }
        """;

    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var processes = TweakServices.Need(c.Services.Processes, "process list");
        c.Services.Sleep(TimeSpan.FromSeconds(5));
        processes.Wait("Update", p => (p ?? "").Contains(@"\Discord\", StringComparison.OrdinalIgnoreCase), TimeSpan.FromSeconds(300));
        c.Services.Sleep(TimeSpan.FromSeconds(5));
        processes.Stop("Discord");
        AppFiles.WriteText(Path.Combine(AppFiles.User(c, "AppData"), @"discord\settings.json"), Settings);
        AppSetup.RemoveStartup(c, "Discord");
    }
}
