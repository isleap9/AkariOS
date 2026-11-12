using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Advanced.SystemTweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/WindowsOld.ps1 (ZOICWARE): %SystemDrive%\Windows.old deleted as TrustedInstaller
/// (cmd's rd, as N7's Defender move), then taken over by the administrators and deleted. An Action: the old Windows is
/// gone for good.</summary>
[TweakCode("cleanup-windows-old")]
public sealed class WindowsOld : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var p = Path.Combine(TweakServices.Folder(c.Services.SystemDrive, "system drive"), "Windows.old");
        if (!Directory.Exists(p) && !File.Exists(p))
        {
            c.Log.Write("There is no Windows.old folder");
            return;
        }
        var cmd = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "cmd.exe");
        TweakServices.Need(c.Services.Trusted, "TrustedInstaller").Start(cmd, $"/c rd /s /q \"{p}\"");
        SystemFiles.GrantOwnership(c, p);
        SystemPaths.Remove([p]);
        c.Log.Write(Directory.Exists(p) || File.Exists(p) ? "Some of Windows.old is still in use; restart and run this again" : "Windows.old deleted");
    }
}
