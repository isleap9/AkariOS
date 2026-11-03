using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Taskbar;

/// <summary>src/Tweaks/Customize/Taskbar/QuickSettingsUnpin.ps1: Windows marks an unpinned quick settings tile with an
/// empty REG_NONE value, which reads back like a missing one, so the State is which value names are there. The tile
/// names are the file's ($names, read from it), each "Microsoft.QuickAction.&lt;name&gt;".</summary>
[TweakCode("taskbar-quick-settings-unpin")]
public sealed class QuickSettingsUnpin : ITweakCode
{
    private const string Key = @"HKCU:\Control Panel\Quick Actions\Control Center\Unpinned";

    public static IReadOnlyList<string> Names(Tweak t, TweakContext c) =>
        FileData.AssignedList(c.Files, t.Source, "names").Select(n => $"Microsoft.QuickAction.{n}").ToList();

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var names = Names(tweak, c);
        var have = c.Registry.ValueNames(Key);
        var n = names.Count(have.Contains);
        return n == names.Count ? TweakState.Optimized : n == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var n in Names(tweak, c)) c.Registry.SetValue(Key, n, Array.Empty<byte>(), "None");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        foreach (var n in Names(tweak, c)) c.Registry.RemoveValue(Key, n);
    }
}
