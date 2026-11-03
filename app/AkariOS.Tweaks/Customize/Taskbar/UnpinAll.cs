using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Taskbar;

/// <summary>src/Tweaks/Customize/Taskbar/UnpinAll.ps1: the real user's Taskband key and Quick Launch folder deleted (an
/// Action: once cleared Akari can't know what to pin back).</summary>
[TweakCode("taskbar-unpin-all")]
public sealed class UnpinAll : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.DeleteKey(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband");
        if (UserFolders.Get(c.Registry, "AppData", c.Services.UserSid) is not { } appData) return;
        var quick = Path.Combine(appData, "Microsoft", "Internet Explorer", "Quick Launch");
        try { if (Directory.Exists(quick)) Directory.Delete(quick, recursive: true); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.Write($"Warning: Quick Launch kept ({e.Message})"); }
    }
}
