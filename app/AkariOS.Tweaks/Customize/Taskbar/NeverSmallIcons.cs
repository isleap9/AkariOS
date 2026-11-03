using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Taskbar;

/// <summary>src/Tweaks/Customize/Taskbar/NeverSmallIcons.ps1: a Choice over IconSizePreference (its Value block): 1 =
/// Never, 0 = Always, none = Default (Windows'); any other value = none of its values.</summary>
[TweakCode("taskbar-never-small-icons")]
public sealed class NeverSmallIcons : ITweakCode
{
    private const string Key = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";

    public object? ChoiceValue(Tweak tweak, TweakContext c) => c.Registry.GetValue(Key, "IconSizePreference") switch
    {
        null => "Default",
        var v when PsSemantics.LooseEquals(v, 1) => "Never",
        var v when PsSemantics.LooseEquals(v, 0) => "Always",
        _ => null,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        switch (PsSemantics.Text(value))
        {
            case "Never": c.Registry.SetValue(Key, "IconSizePreference", 1, "DWord"); break;
            case "Always": c.Registry.SetValue(Key, "IconSizePreference", 0, "DWord"); break;
            case "Default": c.Registry.RemoveValue(Key, "IconSizePreference"); break;
            default: throw new ArgumentException($"unknown value {value}");
        }
    }

    public void Revert(Tweak tweak, TweakContext c, object? value) => c.Registry.RemoveValue(Key, "IconSizePreference");
}
