using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/MonitorTest.ps1: the monitor menu's checklist in the console, then TestUFO. An
/// Action: it opens a web test.</summary>
[TweakCode("tools-monitor-test")]
public sealed class MonitorTest : ITweakCode
{
    private static readonly string[] Checklist =
    [
        "In the monitor's menu:", "- turn on its overclock mode and run the highest refresh rate",
        "- turn off adaptive brightness and variable backlight",
        "- turn off variable refresh rate (adaptive sync, G-Sync) if you play with a frame cap",
        "- overdrive as high as it goes without overshoot (bright trails behind the UFO)",
        "- colour, brightness and sharpening to taste",
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var l in Checklist) c.Log.Write(l);
        ShellStart.Run(c, "https://www.testufo.com/framerates#count=6&background=none&pps=1920");
    }
}
