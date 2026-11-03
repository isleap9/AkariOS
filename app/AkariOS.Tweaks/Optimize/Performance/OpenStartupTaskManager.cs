using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/OpenStartupTaskManager.ps1: opens Task Manager on its Startup apps tab (an
/// Action: it changes nothing). It isn't waited for.</summary>
[TweakCode("performance-open-startup-taskmgr")]
public sealed class OpenStartupTaskManager : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Exe, "program runner").Run(Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "taskmgr.exe"), "/0 /startup", wait: false);
}
