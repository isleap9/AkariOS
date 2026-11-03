using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Taskbar;

/// <summary>src/Tweaks/Customize/Taskbar/ShowAllTrayIcons.ps1: Windows 10's one switch (EnableAutoTray), or on Windows
/// 11 IsPromoted on every tray icon's key (Control Panel\NotifyIconSettings). Revert: icons wait in the overflow menu.</summary>
[TweakCode("taskbar-show-all-tray-icons")]
public sealed class ShowAllTrayIcons : ITweakCode
{
    private const string Explorer = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer";
    private const string Icons = @"HKCU:\Control Panel\NotifyIconSettings";

    private static IReadOnlyList<string> Keys(TweakContext c) => c.Registry.SubKeys(Icons).Select(k => $@"{Icons}\{k}").ToList();

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        if (c.System.Build < 22000)
            return c.Registry.GetValue(Explorer, "EnableAutoTray") switch
            {
                null => TweakState.Default,
                var v when PsSemantics.LooseEquals(v, 0) => TweakState.Optimized,
                _ => TweakState.Custom,
            };
        var keys = Keys(c);
        if (keys.Count == 0) return TweakState.Unknown;
        var on = keys.Count(k => c.Registry.GetValue(k, "IsPromoted") is { } v && PsSemantics.LooseEquals(v, 1));
        return on == keys.Count ? TweakState.Optimized : on == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (c.System.Build < 22000) { c.Registry.SetValue(Explorer, "EnableAutoTray", 0, "DWord"); return; }
        foreach (var k in Keys(c)) c.Registry.SetValue(k, "IsPromoted", 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        if (c.System.Build < 22000) { c.Registry.RemoveValue(Explorer, "EnableAutoTray"); return; }
        foreach (var k in Keys(c)) c.Registry.SetValue(k, "IsPromoted", 0, "DWord");
    }
}
