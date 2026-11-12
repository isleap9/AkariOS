using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/Brlapi.ps1: the brlapi service and the brltty folder (owned by TrustedInstaller:
/// taken for Administrators first). An Action: only a Windows repair brings it back.</summary>
[TweakCode("remove-brlapi")]
public sealed class Brlapi : ITweakCode
{
    private static string Folder(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "brltty");

    private static IServiceManager Services(TweakContext c) => FileData.Need(c.Services.Services, "service manager");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Services(c).StartType("brlapi") is null && !Directory.Exists(Folder(c)) ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        Services(c).Stop("brlapi");
        Services(c).Delete("brlapi");
        var folder = Folder(c);
        if (!Directory.Exists(folder)) return;
        var system32 = Path.Combine(c.Services.Windows, "System32");
        var exe = FileData.Need(c.Services.Exe, "program runner");
        exe.Run(Path.Combine(system32, "takeown.exe"), $"/f \"{folder}\" /r /d y");
        exe.Run(Path.Combine(system32, "icacls.exe"), $"\"{folder}\" /grant *S-1-5-32-544:F /t");
        Files.Delete(folder);
    }
}
