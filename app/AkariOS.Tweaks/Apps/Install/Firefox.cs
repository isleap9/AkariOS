using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/Firefox.ps1: after the winget install, the Mozilla Maintenance Service
/// uninstalled, Firefox's updaters gone, uBlock Origin in Firefox's distribution folder (every profile), policies (no
/// auto-update, no hardware acceleration), no autostart.</summary>
[TweakCode("install-firefox")]
public sealed class Firefox : ITweakCode
{
    public const string UBlock = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    private const string Policies = @"HKLM:\SOFTWARE\Policies\Mozilla\Firefox";

    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var u = Path.Combine(AppFiles.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), @"Mozilla Maintenance Service\uninstall.exe");
        if (File.Exists(u)) TweakServices.Need(c.Services.Exe, "program runner").Run(u, "/S", wait: true, capture: false);
        AppSetup.RemoveUpdaters(c, "Firefox");
        var ext = Path.Combine(AppFiles.Folder(c.Services.ProgramFiles, "Program Files"), @"Mozilla Firefox\distribution\extensions");
        Directory.CreateDirectory(ext);
        TweakServices.Need(c.Services.Http, "web downloader").Download(UBlock, Path.Combine(ext, "uBlock0@raymondhill.net.xpi"));
        c.Registry.SetValue(Policies, "AppAutoUpdate", 0, "DWord");
        c.Registry.SetValue(Policies, "HardwareAcceleration", 0, "DWord");
        AppSetup.RemoveStartup(c, "*Firefox*");
    }
}
