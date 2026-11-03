using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/OpenStartupApps.ps1: opens Settings › Apps › Startup (an Action: it changes
/// nothing).</summary>
[TweakCode("performance-open-startup-apps")]
public sealed class OpenStartupApps : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        FileData.Need(c.Services.Launcher, "Settings launcher").Open("ms-settings:startupapps");
}
