using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>src/Tweaks/Advanced/Security/OpenCoreIsolation.ps1: opens System Information and Windows Security › Core
/// isolation (an Action: it changes nothing). Neither is waited for.</summary>
[TweakCode("security-open-core-isolation")]
public sealed class OpenCoreIsolation : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var msinfo = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "msinfo32.exe");
        FileData.Need(c.Services.Exe, "program runner").Run(msinfo, "", wait: false);
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("windowsdefender://coreisolation/");
    }
}
